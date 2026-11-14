-- Gather: getting the guild together for an event (a guild meeting, a levelling night) - and onto one
-- layer. The game moves everyone who joins a group onto the leader's layer, so the organiser forms a
-- raid and invites people; this helps with the asking and the inviting:
--   * The organiser (the event's creator, or an officer/editor rank) starts gathering on the day.
--   * Guildies get "Bazza is gathering" (a pop-up if they said Going/Maybe) and click "Ask for an
--     invite", which tells the organiser by addon whisper (not chat).
--   * The organiser's Gather list: who asked, who's going and online, who's already in the group;
--     Invite on each, "Invite next" (one invite per click), "Make it a raid".
-- Nothing invites, accepts or leaves by itself (no automation), and nothing works out anyone's layer
-- (Blizzard scrambles that on Forever on purpose; no workarounds, see CONTRIBUTING.md).
--
-- Messages
--   GTH { o, id, at, on }   gathering for event o:id (occurrence at) is on / off (GUILD; or WHISPER to a
--                           guildie who just logged in). Only from the event's owner or an editor rank.
--   GAK { o, id, at }       please invite me (WHISPER to the organiser)
local ADDON, ns = ...

local G = {}
ns.Gather = G

local LIVE = 3 * 3600           -- a gathering ends by itself 3 hours after the event's start
local INVITE_GAP = 60           -- "Invite next" skips someone invited in the last minute

G.active = {}                   -- "owner:id@at" -> { organiser, key, at, since }
G.asked = {}                    -- same id -> true once I've asked for an invite
local pending = {}              -- gatherings heard before their event arrived
local mine = nil                -- my gathering: { key, at, asks = { name = t }, invited = { name = t } }

local function Id(key, at) return key .. "@" .. at end

local function Event(key)
    local store = ns.Calendar.Store()
    local e = store and store[key]
    if e and not e.x then return e end
end

-- May this guildie gather for this event? Its owner, or an editor rank (Board.lua).
function G.CanGather(name, e)
    return e ~= nil and (e.owner == name or ns.Board.CanModerate(name, "cal"))
end

-- Is this occurrence today (local) and not over?
function G.Today(at)
    local now = GetServerTime()
    if at < now - LIVE or at > now + 86400 then return false end
    return date("%Y-%m-%d", at) == date("%Y-%m-%d", now) or at - now < 3 * 3600
end

function G.Mine() return mine end

function G.ActiveFor(key, at)
    if not key or not at then return nil end
    local a = G.active[Id(key, at)]
    if a and GetServerTime() < a.at + LIVE then return a end
    return nil
end

local function Changed() ns.Fire("GATHER") end

---------------------------------------------------------------------------------------------------
-- Who's in my group (by key), plus fake guildies who "joined" in sim mode.

function G.GroupKeys()
    local keys = {}
    local n = GetNumGroupMembers and GetNumGroupMembers() or 0
    local prefix = (IsInRaid and IsInRaid()) and "raid" or "party"
    for i = 1, math.max(n, 4) do
        local k = ns.UnitKey(prefix .. i)
        if k and k ~= ns.me then keys[k] = true end
    end
    if ns.Sim and ns.Sim.Joined then for k in pairs(ns.Sim.Joined()) do keys[k] = true end end
    return keys
end

---------------------------------------------------------------------------------------------------
-- Organiser

local function Announce(on, channel, target)
    if not mine then return end
    local e = Event(mine.key)
    if not e then return end
    ns.Comm.Send({ t = "GTH", o = e.owner, id = e.id, at = mine.at, on = on or nil }, channel or "GUILD", target)
end

function G.Start(key, at)
    if not key or not at then return false end
    local e = Event(key)
    if not e or not G.CanGather(ns.me, e) or not G.Today(at) then return false end
    if mine and (mine.key ~= key or mine.at ~= at) then G.Stop() end
    mine = { key = key, at = at, asks = {}, invited = {}, since = GetServerTime() }
    G.active[Id(key, at)] = { organiser = ns.me, key = key, at = at, since = mine.since }
    Announce(true)
    Changed()
    return true
end

function G.Stop()
    if not mine then return end
    Announce(false)
    G.active[Id(mine.key, mine.at)] = nil
    mine = nil
    Changed()
end

-- The Gather list: who asked (first), who's going and online, who's in the group, who's going but offline.
-- { name, state = "asked" | "going" | "ingroup" | "offline", t }
function G.List()
    local list = {}
    if not mine then return list end
    local e = Event(mine.key)
    local group = G.GroupKeys()
    local seen = {}
    local function Add(name, state, t)
        if seen[name] or name == ns.me then return end
        seen[name] = true
        list[#list + 1] = { name = name, state = state, t = t or 0 }
    end
    for name in pairs(group) do Add(name, "ingroup") end
    for name, t in pairs(mine.asks) do
        local m = ns.Guild.Get(name)
        if m and m.online then Add(name, "asked", t) end
    end
    if e then
        local answers = ns.Calendar.Answers(e, mine.at)
        for _, k in ipairs({ "y", "m" }) do
            for _, name in ipairs(answers[k]) do
                local m = ns.Guild.Get(name)
                Add(name, (m and m.online) and "going" or "offline")
            end
        end
    end
    local ORDER = { asked = 1, going = 2, ingroup = 3, offline = 4 }
    table.sort(list, function(a, b)
        if ORDER[a.state] ~= ORDER[b.state] then return ORDER[a.state] < ORDER[b.state] end
        if a.state == "asked" and a.t ~= b.t then return a.t < b.t end
        return a.name < b.name
    end)
    return list
end

function G.InGroupCount()
    local n = 0
    for _ in pairs(G.GroupKeys()) do n = n + 1 end
    return n + 1                                 -- and me
end

-- One invite (the organiser's click): the game's own invite.
function G.Invite(name)
    local m = ns.Guild.Get(name)
    if not m or not mine then return end
    mine.invited[name] = GetTime()
    ns.UI.Invite(m)
    Changed()
end

-- "Invite next": the first one waiting (asked, then going and online) not invited in the last minute.
function G.Next()
    if not mine then return nil end
    local now = GetTime()
    for _, row in ipairs(G.List()) do
        if (row.state == "asked" or row.state == "going")
            and not (mine.invited[row.name] and now - mine.invited[row.name] < INVITE_GAP) then
            return row.name
        end
    end
    return nil
end

function G.InviteNext()
    local name = G.Next()
    if name then G.Invite(name) end
    return name
end

-- Can I turn my party into a raid? (Leading a party, not a raid yet.)
function G.CanMakeRaid()
    local inGroup = IsInGroup and IsInGroup()
    local raid = IsInRaid and IsInRaid()
    local leader = UnitIsGroupLeader and UnitIsGroupLeader("player")
    return inGroup and not raid and leader and true or false
end

function G.MakeRaid()
    if not G.CanMakeRaid() then return end
    if C_PartyInfo and C_PartyInfo.ConvertToRaid then pcall(C_PartyInfo.ConvertToRaid)
    elseif ConvertToRaid then pcall(ConvertToRaid) end
end

---------------------------------------------------------------------------------------------------
-- Everyone else

function G.AskInvite(key, at)
    if not key or not at then return false end
    local a = G.ActiveFor(key, at)
    if not a or a.organiser == ns.me then return false end
    local e = Event(key)
    if not e then return false end
    G.asked[Id(key, at)] = true
    if ns.Sim and ns.Sim.IsFake(a.organiser) then
        ns.Log("(sim) would ask " .. a.organiser .. " for an invite")
        ns.Sim.AskedForInvite(a.organiser)
    else
        ns.Comm.Send({ t = "GAK", o = e.owner, id = e.id, at = at }, "WHISPER", a.organiser)
    end
    Changed()
    return true
end

function G.HaveAsked(key, at) return key ~= nil and at ~= nil and G.asked[Id(key, at)] == true end

---------------------------------------------------------------------------------------------------
-- Receiving

local function OnGather(msg, from, channel, isSelf)
    if isSelf then return end
    local owner = type(msg.o) == "string" and ns.Key(msg.o) or nil
    if not owner or type(msg.id) ~= "number" or type(msg.at) ~= "number" then return end
    local key = owner .. ":" .. msg.id
    local e = Event(key)
    if not e then
        local hid = Id(key, msg.at)
        if msg.on == true then
            -- We haven't got the event yet (it's on its way to a guildie who just logged in): hold this
            -- for a few minutes and take it once the event arrives.
            pending[hid] = { from = from, msg = msg, until_ = GetTime() + 300 }
            return
        elseif pending[hid] and pending[hid].from == from then
            -- Stopped before the event arrived: forget the start we were holding.
            pending[hid] = nil
            return
        end
    end
    if not e or not G.CanGather(from, e) then
        ns.Log("dropped: a gathering from " .. from .. " for an event they can't gather for")
        return
    end
    local id = Id(key, msg.at)
    if msg.on == true then
        if not G.Today(msg.at) then return end
        local isNew = G.active[id] == nil
        G.active[id] = { organiser = from, key = key, at = msg.at, since = GetServerTime() }
        if isNew then ns.Fire("GATHER_STARTED", G.active[id], e) end
    else
        if G.active[id] and G.active[id].organiser == from then G.active[id] = nil end
    end
    Changed()
end
ns.Comm.On("GTH", OnGather)

ns.Comm.On("GAK", function(msg, from, channel, isSelf)
    if isSelf or channel ~= "WHISPER" or not mine then return end
    local e = Event(mine.key)
    local owner = type(msg.o) == "string" and ns.Key(msg.o) or nil
    if not e or owner ~= e.owner or msg.id ~= e.id or msg.at ~= mine.at then return end
    local isNew = mine.asks[from] == nil
    mine.asks[from] = mine.asks[from] or GetServerTime()
    if isNew then ns.Fire("GATHER_ASKED", from) end
    Changed()
end)

-- An event arrived: a gathering we were holding for it goes through now.
ns.Listen("CALENDAR", function()
    local now = GetTime()
    for id, p in pairs(pending) do
        if now > p.until_ then
            pending[id] = nil
        elseif Event(ns.Key(p.msg.o) .. ":" .. p.msg.id) then
            pending[id] = nil
            OnGather(p.msg, p.from, "WHISPER", false)
        end
    end
end)

-- A guildie who just logged in hears about my gathering.
ns.Listen("HI_IN", function(msg, from)
    if msg.ask ~= true or not mine or (ns.Sim and ns.Sim.IsFake(from)) then return end
    C_Timer.After(3 + math.random() * 3, function() Announce(true, "WHISPER", from) end)
end)

-- Gatherings end by themselves: 3 hours after the start, or when the organiser goes offline.
local function Tidy()
    local now = GetServerTime()
    local changed = false
    -- Held starts whose event never came.
    local t = GetTime()
    for hid, p in pairs(pending) do if t > p.until_ then pending[hid] = nil end end
    for id, a in pairs(G.active) do
        local m = ns.Guild.Get(a.organiser)
        if now >= a.at + LIVE or (a.organiser ~= ns.me and (not m or not m.online)) then
            G.active[id] = nil; changed = true
        end
    end
    if mine and now >= mine.at + LIVE then mine = nil; changed = true end
    if changed then Changed() end
end
ns.Listen("ROSTER", function() ns.Safe(Tidy) end)
ns.Listen("LOGIN", function() C_Timer.NewTicker(30, function() ns.Safe(Tidy) end) end)
ns.OnEvent("GROUP_ROSTER_UPDATE", Changed)

-- Dev only: the CurseForge build leaves this out (BigWigs packager's do-not-package markers).
-- A copy installed from source keeps it.
--@do-not-package@
-- For testing alone: /ynm dev gather makes a fake officer start gathering for one of their events today.
ns.devCommands.gather = function()
    if ns.Sim and ns.Sim.IsOn() then ns.Sim.FakeGather() else ns.Print("/ynm dev sim on first") end
end
--@end-do-not-package@
