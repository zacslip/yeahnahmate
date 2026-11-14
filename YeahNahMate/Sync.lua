-- Catching up when an author comes online. Copies and whispers on log-in cover guildies who log in
-- AFTER an author; this covers the other way round: I was already online (or I logged in while the
-- author was away and got an older copy from someone else), and the author changed something while
-- I wasn't around to hear it.
--
-- Every log-in hello carries, per kind (events, requests, guild board), the newest version of the
-- things I wrote and how many of them changed in the last 30 days (the newest alone misses one
-- thing skipped while a later one arrived). Anyone online who's behind on either asks me for them
-- (REQ w = "SYNC"). I gather the asks for a few seconds: from 3 askers up the update goes to the guild
-- once (with the whole guild on the addon, one log-in could otherwise mean 250 whispers), fewer get
-- a whisper each. Found by tests/multi.py (several real copies of the addon talking to each other).
local ADDON, ns = ...

local Sync = {}
ns.Sync = Sync

local WAIT, TO_GUILD = 4, 3
local WINDOW = 30 * 86400       -- things changed this recently are counted
local kinds = {}                -- name -> { versions = fn(author) -> { v, ... }, messages = fn() -> list }
local order = {}

-- versions(author): the versions of that author's things of this kind that I hold.
-- messages(): my own things as messages, the same ones a guildie who logs in gets from me.
-- What a kind counts for an author (for tests and /ynm dev).
function Sync.Versions(name, author) return kinds[name] and kinds[name].versions(author) or {} end

function Sync.Register(name, versions, messages)
    if not kinds[name] then order[#order + 1] = name end
    kinds[name] = { versions = versions, messages = messages }
end

-- Newest version, how many changed since `since`, and a checksum of those versions (0.10.0).
-- The newest and the count miss an old copy: I was offline when the author edited something, then
-- online for their next new thing, so both numbers match while I still hold the old one. The sum
-- of the versions differs. Found by tests/multi.py once questions (often-edited posts) were added.
local SUM_MOD = 2147483647
local function Summary(name, author, since)
    local top, n, h = 0, 0, 0
    for _, v in ipairs(kinds[name].versions(author) or {}) do
        if type(v) == "number" then
            if v > top then top = v end
            if v >= since then n = n + 1; h = (h + v) % SUM_MOD end
        end
    end
    return top, n, h
end

ns.Listen("HI_OUT", function(msg)
    if msg.ask ~= true then return end             -- only the log-in hello carries it
    local since = GetServerTime() - WINDOW
    local sv
    for _, name in ipairs(order) do
        local top, n, h = Summary(name, ns.me, since)
        if top > 0 then sv = sv or {}; sv[name] = { v = top, n = n, s = since, h = h } end
    end
    msg.sv = sv
end)

-- An author logged in: am I behind on anything of theirs?
ns.Listen("HI_IN", function(msg, from)
    if msg.ask ~= true or type(msg.sv) ~= "table" or (ns.Sim and ns.Sim.IsFake(from)) then return end
    local want
    local now = GetServerTime()
    for _, name in ipairs(order) do
        local sv = msg.sv[name]
        if type(sv) == "table" and type(sv.v) == "number" and type(sv.n) == "number" and type(sv.s) == "number"
            and not ns.Future(sv.v, false) and sv.s <= now and sv.s > now - 2 * WINDOW then
            local top, n, h = Summary(name, from, sv.s)
            -- Behind: older newest, fewer, or the same count with different versions (an old copy).
            -- Holding more than they count (things they no longer send) isn't a reason to ask.
            local stale = type(sv.h) == "number" and h ~= sv.h and n <= sv.n
            if top < sv.v or n < sv.n or stale then
                want = want or {}
                want[#want + 1] = name
            end
        end
    end
    if not want then return end
    -- A short random wait, so the asks don't all land on them at the same moment.
    C_Timer.After(1 + math.random() * 3, function()
        ns.Comm.Send({ t = "REQ", w = "SYNC", k = want }, "WHISPER", from)
    end)
end)

-- Answering: gather the asks per kind, then one guild copy or a few whispers.
local askers, timer = {}, nil

local function Answer()
    timer = nil
    for name, who in pairs(askers) do
        local list = {}
        for n in pairs(who) do list[#list + 1] = n end
        local k = kinds[name]
        local msgs = k and k.messages() or {}
        if #msgs > 0 then
            if #list >= TO_GUILD then
                for _, m in ipairs(msgs) do ns.Comm.Send(m, "GUILD", nil, "BULK") end
                ns.Log(string.format("%d guildies were behind on your %s: sent them to the guild once", #list, name))
            else
                for _, n in ipairs(list) do
                    for _, m in ipairs(msgs) do ns.Comm.Send(m, "WHISPER", n, "BULK") end
                end
            end
        end
    end
    askers = {}
end

local asked = {}                -- requester -> GetTime() of their last ask (one per minute each)
ns.Comm.On("REQ", function(msg, from, channel, isSelf)
    if msg.w ~= "SYNC" or isSelf or channel ~= "WHISPER" or type(msg.k) ~= "table" then return end
    local now = GetTime()
    if asked[from] and now - asked[from] < 60 then return end
    asked[from] = now
    for i = 1, math.min(#msg.k, #order) do
        local name = msg.k[i]
        if type(name) == "string" and kinds[name] then
            askers[name] = askers[name] or {}
            askers[name][from] = true
        end
    end
    if not timer and next(askers) then timer = C_Timer.NewTimer(WAIT, function() ns.Safe(Answer) end) end
end)
