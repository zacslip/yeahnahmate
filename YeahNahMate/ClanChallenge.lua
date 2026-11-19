-- Clan challenges and second in command.
--
-- Challenges: a clan member says "I'm challenging for the leadership" (not against a named person:
-- at the weekly guild meeting challengers go in sign-up order, each against whoever leads at that
-- moment). The challenger can withdraw (two clicks on the tab). The guild master, a manager or a Clan
-- moderator rank marks each one Won or Lost; that result is final. A win doesn't change any rank: the
-- guild master promotes the winner in the game's roster, and the addon follows the rank (Clans.lua).
-- Open challenges drop after 14 days; results are kept 30 days.
--
-- Second in command: the guild master, a manager or a Clan moderator rank gives a clan member the
-- leader's meeting buttons for a while (30 minutes), or ends it early.
--
-- Messages
--   CHG { id, r, st, at, ev }            my challenge: st "o" open / "w" withdrawn (GUILD)
--   CHG { o, id, r, st, sb, at, ev }     a result: st "won" / "lost", sb = who settled it (GUILD from
--                                        them; copies carry the same fields)
--   DEP { r, who, un }                   who is second in command of clan r until server time un
--                                        (un = 0 ends it). GUILD, or WHISPER to a guildie logging in.
--   REQ { w = "CHG" }                    send me the challenges you hold (after log-in, one guildie)
local ADDON, ns = ...

local X = {}
ns.ClanChallenge = X

local OPEN_FOR = 14 * 86400
local KEEP = 30 * 86400
local WITHDRAWN_KEEP = 86400
local ASK_WINDOW = 300
X.DEPUTY_FOR = 30 * 60
local ST = { o = true, w = true, won = true, lost = true }
local FINAL = { won = true, lost = true }

local function Changed() ns.Fire("CLANS") end

function X.Store()
    local g = ns.GuildData()
    if not g then return nil end
    if type(g.chal) ~= "table" then g.chal = {} end
    return g.chal
end

-- May this guildie settle challenges and give second in command? Guild master, managers, Clan
-- moderator ranks (on my roster).
function X.CanSettle(name) return ns.Board.CanModerate(name, "clan") end

---------------------------------------------------------------------------------------------------
-- Reading

-- Open challenges for a clan, in sign-up order.
function X.Open(race)
    local out = {}
    local store = X.Store()
    if not store then return out end
    local now = GetServerTime()
    for _, c in pairs(store) do
        if c.r == race and c.st == "o" and now - c.at < OPEN_FOR and (c.owner == ns.me or ns.Guild.IsMember(c.owner)) then
            out[#out + 1] = c
        end
    end
    table.sort(out, function(a, b) if a.at ~= b.at then return a.at < b.at end return a.owner < b.owner end)
    return out
end

-- Settled in the last 30 days, newest first.
function X.Recent(race)
    local out = {}
    local store = X.Store()
    if not store then return out end
    for _, c in pairs(store) do
        if c.r == race and FINAL[c.st] then out[#out + 1] = c end
    end
    table.sort(out, function(a, b) return a.ev > b.ev end)
    return out
end

function X.OpenOf(name, race)
    for _, c in ipairs(X.Open(race)) do if c.owner == name then return c end end
    return nil
end

-- Can I challenge for my clan's leadership? In the clan, not its leader, nothing open already.
function X.CanChallenge()
    local race = ns.Clans.MyRace()
    if not race or ns.Clans.IsLeader(ns.me, race) then return false end
    return X.OpenOf(ns.me, race) == nil
end

---------------------------------------------------------------------------------------------------
-- Sending

local function Message(c)
    local m = { t = "CHG", id = c.id, r = c.r, st = c.st, at = c.at, ev = c.ev, sb = c.sb }
    if c.owner ~= ns.me then m.o = c.owner end
    return m
end

local function NextVersion(old) return math.max(GetServerTime(), (old or 0) + 1) end

function X.Challenge()
    local store = X.Store()
    if not store or not X.CanChallenge() then return false end
    local now = GetServerTime()
    local id = now
    while store[ns.me .. ":" .. id] do id = id + 1 end
    local c = { owner = ns.me, id = id, r = ns.Clans.MyRace(), st = "o", at = now, ev = now, direct = true }
    store[ns.me .. ":" .. id] = c
    ns.Comm.Send(Message(c), "GUILD")
    Changed()
    return true
end

function X.Withdraw()
    local c = X.OpenOf(ns.me, ns.Clans.MyRace())
    if not c then return false end
    c.st, c.ev, c.direct = "w", NextVersion(c.ev), true
    ns.Comm.Send(Message(c), "GUILD")
    Changed()
    return true
end

-- A moderator's result: "won" or "lost".
function X.Settle(owner, id, result)
    local store = X.Store()
    local c = store and store[owner .. ":" .. tostring(id)]
    if not c or c.st ~= "o" or not FINAL[result] or not X.CanSettle(ns.me) then return false end
    c.st, c.sb, c.ev, c.direct = result, ns.me, NextVersion(c.ev), true
    ns.Comm.Send(Message(c), "GUILD")
    Changed()
    return true
end

---------------------------------------------------------------------------------------------------
-- Receiving

local asked = {}

-- Take a challenge (direct from the guildie who changed it, or a copy). Returns true if it changed.
local function Take(from, msg, direct)
    local store = X.Store()
    if not store then return false end
    local owner = msg.o and ns.Key(msg.o) or from
    if type(msg.id) ~= "number" or type(msg.at) ~= "number" or not ST[msg.st] or ns.Future(msg.ev, not direct) then return false end
    if owner ~= ns.me and not ns.Guild.IsMember(owner) then return false end
    local race = ns.Clans.CleanRace(msg.r)
    if not race then return false end
    local sb = msg.sb and ns.Key(msg.sb) or nil
    if FINAL[msg.st] then
        -- A result: from (or relayed for) someone who may settle on MY roster.
        if not sb or not X.CanSettle(sb) or (direct and sb ~= from) then
            ns.Log("dropped: a challenge result from " .. tostring(sb or from) .. ", who can't settle challenges")
            return false
        end
    else
        -- Open or withdrawn: only the challenger, for their own clan.
        if direct and owner ~= from then return false end
        if ns.Clans.Race(owner) and ns.Clans.Race(owner) ~= race then
            ns.Log("dropped: " .. owner .. "'s challenge for a clan that isn't theirs")
            return false
        end
        sb = nil
    end
    local key = owner .. ":" .. msg.id
    local old = store[key]
    if old and FINAL[old.st] then
        -- A result is final; a later result only if it's newer (two moderators: newest wins).
        if not FINAL[msg.st] or msg.ev <= old.ev then return false end
    elseif old and msg.ev <= old.ev then
        return false
    end
    store[key] = { owner = owner, id = msg.id, r = race, st = msg.st, at = msg.at, ev = msg.ev, sb = sb,
                   direct = direct or nil }
    return true
end
X.Take = Take

ns.Comm.On("CHG", function(msg, from, channel, isSelf)
    if isSelf then return end
    local direct = msg.o == nil or (FINAL[msg.st] and msg.sb ~= nil and ns.Key(msg.sb) == from)
    if not direct then
        -- A copy: only by whisper from a guildie we asked.
        if channel ~= "WHISPER" or not asked[from] or GetTime() - asked[from] > ASK_WINDOW then return end
    end
    if Take(from, msg, direct) then
        local key = (msg.o and ns.Key(msg.o) or from) .. ":" .. msg.id
        local c = X.Store()[key]
        if c and c.st == "o" and direct then ns.Fire("CLAN_CHALLENGE", c) end
        Changed()
    end
end)

-- Everything I hold, as messages (copies for a guildie who asks).
local function Everything()
    local out = {}
    local store = X.Store()
    if not store then return out end
    for _, c in pairs(store) do out[#out + 1] = Message(c) end
    return out
end

local answered = {}
ns.Comm.On("REQ", function(msg, from, channel, isSelf)
    if isSelf or channel ~= "WHISPER" or msg.w ~= "CHG" then return end
    local now = GetTime()
    if answered[from] and now - answered[from] < 60 then return end
    answered[from] = now
    for _, m in ipairs(Everything()) do ns.Comm.Send(m, "WHISPER", from, "BULK") end
end)

-- What I wrote last: my own challenges (open or withdrawn), and the results I gave.
local function MineToSend()
    local out = {}
    local store = X.Store()
    if not store then return out end
    for _, c in pairs(store) do
        if (c.owner == ns.me and not FINAL[c.st]) or c.sb == ns.me then out[#out + 1] = Message(c) end
    end
    return out
end

ns.Sync.Register("challenges", function(author)
    local list = {}
    local store = X.Store()
    if not store then return list end
    for _, c in pairs(store) do
        if (c.owner == author and not FINAL[c.st]) or c.sb == author then list[#list + 1] = c.ev end
    end
    return list
end, MineToSend)

-- A guildie who just logged in gets what I wrote.
ns.Listen("HI_IN", function(msg, from)
    if msg.ask ~= true or (ns.Sim and ns.Sim.IsFake(from)) then return end
    local list = MineToSend()
    if #list == 0 then return end
    C_Timer.After(4 + math.random() * 4, function()
        for _, m in ipairs(list) do ns.Comm.Send(m, "WHISPER", from, "BULK") end
    end)
end)

-- After log-in, ask one online guildie for all the challenges they hold.
local function AskAll()
    local peers = {}
    for name, u in pairs(ns.Comm.users) do
        local m = ns.Guild.Get(name)
        if name ~= ns.me and not u.sim and m and m.online then peers[#peers + 1] = name end
    end
    if #peers == 0 then return end
    local peer = peers[math.random(#peers)]
    asked[peer] = GetTime()
    ns.Comm.Send({ t = "REQ", w = "CHG" }, "WHISPER", peer)
end
ns.Listen("LOGIN", function() C_Timer.After(58, function() ns.Safe(AskAll) end) end)
X.AskAll = AskAll

-- Tidying: open ones after 14 days, withdrawn after a day, results after 30 days, departed guildies.
local function Tidy()
    local store = X.Store()
    if not store then return end
    local now = GetServerTime()
    for key, c in pairs(store) do
        local age = now - (c.ev or 0)
        if (c.st == "o" and now - c.at >= OPEN_FOR) or (c.st == "w" and age >= WITHDRAWN_KEEP) or age >= KEEP
            or (ns.Guild.complete and c.owner ~= ns.me and not ns.Guild.IsMember(c.owner)) then
            store[key] = nil
        end
    end
end
ns.Listen("ROSTER", function() ns.Safe(Tidy) end)

---------------------------------------------------------------------------------------------------
-- Second in command

X.deputies = {}                 -- race -> { who, un, by }

function ns.Clans.IsDeputy(name, race)
    local d = race and X.deputies[race]
    return d ~= nil and d.who == name and GetServerTime() < d.un
end

function X.Deputy(race)
    local d = race and X.deputies[race]
    if d and GetServerTime() < d.un then return d end
    return nil
end

local function SendDeputy(race, d, channel, target)
    ns.Comm.Send({ t = "DEP", r = race, who = d.who, un = d.un }, channel or "GUILD", target)
end

-- Give (or end, with on = false) second in command of their clan to a guildie.
function X.SetDeputy(name, on)
    local race = ns.Clans.Race(name)
    if not race or not X.CanSettle(ns.me) or name == ns.me then return false end
    local un = on and (GetServerTime() + X.DEPUTY_FOR) or 0
    local d = { who = name, un = un, by = ns.me }
    if on then X.deputies[race] = d
    elseif X.deputies[race] and X.deputies[race].who == name then X.deputies[race] = nil
    else return false end
    SendDeputy(race, d)
    Changed()
    ns.Fire("CLANMEET")
    return true
end

ns.Comm.On("DEP", function(msg, from, channel, isSelf)
    if isSelf then return end
    local race = ns.Clans.CleanRace(msg.r)
    local who = type(msg.who) == "string" and ns.Key(msg.who) or nil
    if not race or not who or type(msg.un) ~= "number" then return end
    if not X.CanSettle(from) then
        ns.Log("dropped: second in command from " .. from .. ", who can't give it")
        return
    end
    if msg.un == 0 then
        if X.deputies[race] and X.deputies[race].who == who then X.deputies[race] = nil end
    elseif msg.un > GetServerTime() and msg.un <= GetServerTime() + 4 * 3600 then
        X.deputies[race] = { who = who, un = msg.un, by = from }
        if who == ns.me then ns.Fire("CLAN_DEPUTY", race, from) end
    end
    Changed()
    ns.Fire("CLANMEET")
end)

-- A guildie who logs in hears about second in commands I gave that still last.
ns.Listen("HI_IN", function(msg, from)
    if msg.ask ~= true or (ns.Sim and ns.Sim.IsFake(from)) then return end
    for race, d in pairs(X.deputies) do
        if d.by == ns.me and GetServerTime() < d.un then
            C_Timer.After(3 + math.random() * 3, function() SendDeputy(race, d, "WHISPER", from) end)
        end
    end
end)

-- Ended ones go.
ns.Listen("LOGIN", function()
    C_Timer.NewTicker(30, function()
        local now, changed = GetServerTime(), false
        for race, d in pairs(X.deputies) do if now >= d.un then X.deputies[race] = nil; changed = true end end
        if changed then Changed(); ns.Fire("CLANMEET") end
    end)
end)

-- Dev only: the CurseForge build leaves this out (BigWigs packager's do-not-package markers).
--@do-not-package@
-- /ynm dev challenge: (sim mode) two fake guildies in my clan challenge for the leadership; a fake
-- moderator settles the first one 20 s later.
ns.devCommands.challenge = function()
    if ns.Sim and ns.Sim.IsOn() then ns.Sim.FakeChallenges() else ns.Print("/ynm dev sim on first") end
end
--@end-do-not-package@
