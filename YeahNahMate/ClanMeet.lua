-- Clan meetings: a clan's leader (or the guild master, a manager or a Clan moderator rank) gets the
-- clan together, and onto one layer: the game moves everyone who joins a group onto the leader's layer.
--   * The organiser clicks Start meeting. Clan members with the addon get a pop-up and click Ask for
--     an invite (an addon whisper to the organiser). Any guildie can also just whisper the organiser
--     "inv" (INV, invite, inv pls, can I get an inv ...): read from the organiser's own whispers,
--     nothing is sent back.
--   * The organiser's list, top to bottom: Was here (in the group before the last Disband), Asked,
--     Close by (guildies sharing their position, nearest first), Same zone, Online elsewhere, then In
--     the group and Offline. Clicking a name invites them (one invite per click); Invite next too.
--   * Disband (two clicks) takes everyone out of the group, for layer trouble. Who was in it is kept
--     for 30 minutes and put at the top again.
-- Nothing invites, accepts or leaves by itself (no automation), and nothing works out anyone's layer.
--
-- Messages
--   CMT { r, on }   the clan meeting for race r is on / off (GUILD; or WHISPER to a guildie who just
--                   logged in). Only from someone who may run that clan's meetings, on the reader's
--                   own roster.
--   CAK { r }       please invite me (WHISPER to the organiser)
local ADDON, ns = ...

local M = {}
ns.ClanMeet = M

local LIVE = 2 * 3600           -- a meeting ends by itself after 2 hours
local INVITE_GAP = 60           -- Invite next skips someone invited in the last minute
local WAS_HERE = 1800           -- Disband remembers who was in the group for 30 minutes
local CLOSE = 200               -- yards: "close by"

M.active = {}                   -- race -> { organiser, since }
M.asked = {}                    -- race -> true once I've asked for an invite
local mine = nil                -- my meeting: { race, since, asks = { name = t }, invited = { name = t } }
local wasHere = {}              -- name -> { t, race }

local function Changed() ns.Fire("CLANMEET") end

-- May this guildie run this clan's meetings? Its leader, the guild master, a manager or a Clan
-- moderator rank (Board.lua), or the clan's second in command while that lasts (Clans.lua).
function M.CanRun(name, race)
    if not name or not race then return false end
    if ns.Clans.IsLeader(name, race) or ns.Board.CanModerate(name, "clan") then return true end
    return ns.Clans.IsDeputy ~= nil and ns.Clans.IsDeputy(name, race) or false
end

-- On this screen, may I run this clan's meetings? Also in test mode (/ynm dev editor, gm, rank N),
-- where the meeting stays on this screen unless my real rank could run it (Announce).
function M.ICanRun(race)
    if M.CanRun(ns.me, race) then return true end
    if race == nil or not ns.Board.Testing() then return false end
    return ns.Board.Moderates("clan") or ns.Clans.IShownLeader(race)
end

function M.Mine() return mine end

function M.ActiveFor(race)
    local a = race and M.active[race]
    if a and GetServerTime() < a.since + LIVE then return a end
    return nil
end

-- Would this whisper count as asking for an invite? The whole message has to be a request, in any
-- case and with any punctuation: inv, INV, invite, inv pls, inv me mate, can I get an inv, can you
-- invite me, need an inv ... Lines that only mention one don't count: "can I inv you", "inv Bob",
-- "can I get an inv later", "got an inv, cheers". A match only puts the name on the organiser's Asked list.
local INV_SPELLINGS = { inv = true, invite = true, invit = true, invte = true, inivte = true, ivn = true }
local POLITE = { hey = true, hi = true, hiya = true, yo = true, oi = true, gday = true, mate = true,
    bro = true, bud = true, dude = true, man = true, boss = true, legend = true, pls = true, plz = true,
    plss = true, plzz = true, please = true, thanks = true, thx = true, ty = true, ta = true, cheers = true }
local SAME_MEANING = { could = "can", may = "can", would = "can", will = "can", u = "you", ya = "you",
    a = "an", grab = "get", want = "need" }
local PLEASE = { pls = true, plz = true, plss = true, plzz = true, please = true }
-- "got an inv" can be a question or news, so these need a ? or a please to count as asking.
local ONLY_IF_ASKING = { ["got inv"] = true, ["got an inv"] = true, ["have inv"] = true, ["have an inv"] = true }
local INV_REQUESTS = {}
for _, phrase in ipairs({ "inv", "inv me", "can you inv", "can you inv me", "can you get me an inv",
    "can you give me an inv", "can i get inv", "can i get an inv", "can i have inv", "can i have an inv", "get inv", "get an inv", "get me an inv",
    "give me an inv", "gimme inv", "gimme an inv", "need inv", "need an inv", "i need inv", "i need an inv",
    "id like an inv", "any chance of an inv" }) do
    INV_REQUESTS[phrase] = true
end

local function IsInvSpelling(word)
    return INV_SPELLINGS[word] == true or word:match("^inv+$") ~= nil
end

-- "inv", "invvv", and the same run together with please: "invpls", "inviteplz".
local function IsInv(word)
    if IsInvSpelling(word) then return true end
    local stem = word:match("^(.-)please$") or word:match("^(.-)p?l[sz]e?$")
    return stem ~= nil and IsInvSpelling(stem)
end

function M.IsInvWord(text)
    if type(text) ~= "string" then return false end
    local words, asking = {}, text:find("?", 1, true) ~= nil
    for word in text:lower():gsub("'", ""):gmatch("%a+") do
        if PLEASE[word] or (IsInv(word) and not IsInvSpelling(word)) then asking = true end
        if IsInv(word) then
            words[#words + 1] = "inv"
        elseif not POLITE[word] then
            words[#words + 1] = SAME_MEANING[word] or word
        end
    end
    local phrase = table.concat(words, " ")
    if ONLY_IF_ASKING[phrase] then return asking end
    return INV_REQUESTS[phrase] == true
end

---------------------------------------------------------------------------------------------------
-- The organiser

local function Announce(on, channel, target)
    if not mine then return end
    local msg = { t = "CMT", r = mine.race, on = on or nil }
    if not M.CanRun(ns.me, mine.race) then
        -- Test mode only: not sent. SENT still fires, so sim fakes react as if it had gone.
        ns.Log("(dev) clan meeting kept on this screen: your guild rank can't run it")
        ns.Fire("SENT", msg, channel or "GUILD", target)
        return
    end
    ns.Comm.Send(msg, channel or "GUILD", target)
end

function M.Start(race)
    if not race or not M.ICanRun(race) then return false end
    if mine and mine.race ~= race then M.Stop() end
    if mine then return true end
    mine = { race = race, since = GetServerTime(), asks = {}, invited = {} }
    M.active[race] = { organiser = ns.me, since = mine.since }
    Announce(true)
    Changed()
    return true
end

function M.Stop()
    if not mine then return end
    Announce(false)
    if M.active[mine.race] and M.active[mine.race].organiser == ns.me then M.active[mine.race] = nil end
    mine = nil
    Changed()
end

-- Someone asked for an invite (addon button "b", or a whisper "w").
local function Asked(name, how)
    if not mine or name == ns.me then return end
    local isNew = mine.asks[name] == nil
    mine.asks[name] = mine.asks[name] or { t = GetServerTime(), how = how }
    if isNew then ns.Fire("CLANMEET_ASKED", name, how) end
    Changed()
end

-- A whisper to me (CHAT_MSG_WHISPER, or a fake guildie's in sim mode).
function M.Whispered(text, sender)
    if not mine then return end
    text, sender = ns.Public(text, "string"), ns.Public(sender, "string")
    if not text or not sender then return end
    local name = ns.Key(sender)
    if not name or name == ns.me or not ns.Guild.IsMember(name) then return end
    if M.IsInvWord(text) then Asked(name, "w") end
end
ns.OnEvent("CHAT_MSG_WHISPER", function(text, sender) M.Whispered(text, sender) end)

-- Who's in my group (Gather.lua has it: party or raid, plus fakes who "joined" in sim mode).
local function Group() return ns.Gather.GroupKeys() end

-- The meeting list: { name, state, t, d, other } where state is
-- "here" | "asked" | "close" | "zone" | "online" | "ingroup" | "offline"; other = not in this clan.
local ORDER = { here = 1, asked = 2, close = 3, zone = 4, online = 5, ingroup = 6, offline = 7 }
M.ORDER = ORDER
function M.List()
    local list = {}
    if not mine then return list end
    local group = Group()
    local now = GetServerTime()
    local myZone = ns.Roster and ns.Roster.MyZone and ns.Roster.MyZone() or ""
    local seen = {}
    local function Add(m, other)
        if seen[m.name] or m.name == ns.me then return end
        seen[m.name] = true
        local row = { name = m.name, m = m, other = other or nil, t = 0 }
        local ask = mine.asks[m.name]
        local was = wasHere[m.name]
        if group[m.name] then row.state = "ingroup"
        elseif not m.online then row.state = "offline"
        elseif was and was.race == mine.race and now - was.t < WAS_HERE then row.state = "here"; row.t = was.t
        elseif ask then row.state = "asked"; row.t = ask.t; row.how = ask.how
        else
            local d = ns.Map and ns.Map.Distance(m.name)
            if d and d <= CLOSE then row.state = "close"; row.d = d
            elseif myZone ~= "" and m.zone == myZone then row.state = "zone"
            else row.state = "online" end
        end
        list[#list + 1] = row
    end
    for _, m in ipairs(ns.Clans.Members(mine.race)) do Add(m) end
    -- Guildies from other clans who asked (the organiser decides).
    for name in pairs(mine.asks) do
        local m = ns.Guild.Get(name)
        if m then Add(m, true) end
    end
    table.sort(list, function(a, b)
        if ORDER[a.state] ~= ORDER[b.state] then return ORDER[a.state] < ORDER[b.state] end
        if a.state == "asked" and a.t ~= b.t then return a.t < b.t end
        if a.state == "close" and a.d ~= b.d then return a.d < b.d end
        return a.name < b.name
    end)
    return list
end

-- Counts for the list's title: in my group (with me), asked and waiting.
function M.Counts()
    local inGroup, asked = 1, 0
    for _, row in ipairs(M.List()) do
        if row.state == "ingroup" then inGroup = inGroup + 1
        elseif row.state == "asked" or row.state == "here" then asked = asked + 1 end
    end
    return inGroup, asked
end

local INVITABLE = { here = true, asked = true, close = true, zone = true, online = true }
function M.Invitable(state) return INVITABLE[state] == true end

-- One invite (the organiser's click): the game's own invite.
function M.Invite(name)
    local m = ns.Guild.Get(name)
    if not m or not mine or not m.online then return end
    mine.invited[name] = GetTime()
    ns.UI.Invite(m)
    Changed()
end

-- Invite next: the first one on the list not in the group and not invited in the last minute.
function M.Next()
    if not mine then return nil end
    local now = GetTime()
    for _, row in ipairs(M.List()) do
        if INVITABLE[row.state] and not (mine.invited[row.name] and now - mine.invited[row.name] < INVITE_GAP) then
            return row.name
        end
    end
    return nil
end

function M.InviteNext()
    local name = M.Next()
    if name then M.Invite(name) end
    return name
end

-- Disband: everyone out of my group (the leader's one click, after "Sure?"). Who was in it goes to
-- the top of the list for the next 30 minutes.
function M.CanDisband()
    local inGroup = IsInGroup and IsInGroup()
    local leader = UnitIsGroupLeader and UnitIsGroupLeader("player")
    if ns.Sim and ns.Sim.IsOn() and next(ns.Sim.Joined()) then return true end
    return inGroup and leader and true or false
end

function M.Disband()
    if not mine or not M.CanDisband() then return 0 end
    local now, n = GetServerTime(), 0
    for name in pairs(Group()) do
        wasHere[name] = { t = now, race = mine.race }
        mine.invited[name] = nil
        n = n + 1
        local m = ns.Guild.Get(name)
        if m and m.sim then
            if ns.Sim then ns.Sim.Leave(name) end
        elseif UninviteUnit then
            pcall(UninviteUnit, name)
        elseif C_PartyInfo and C_PartyInfo.UninviteUnit then
            pcall(C_PartyInfo.UninviteUnit, name)
        end
    end
    ns.Log("disbanded the clan meeting group (" .. n .. ")")
    Changed()
    return n
end

---------------------------------------------------------------------------------------------------
-- Everyone else

function M.AskInvite(race)
    local a = M.ActiveFor(race)
    if not a or a.organiser == ns.me then return false end
    M.asked[race] = true
    if ns.Sim and ns.Sim.IsFake(a.organiser) then
        ns.Log("(sim) would ask " .. a.organiser .. " for an invite")
        ns.Sim.AskedForInvite(a.organiser)
    else
        ns.Comm.Send({ t = "CAK", r = race }, "WHISPER", a.organiser)
    end
    Changed()
    return true
end

function M.HaveAsked(race) return race ~= nil and M.asked[race] == true end

---------------------------------------------------------------------------------------------------
-- Receiving

ns.Comm.On("CMT", function(msg, from, channel, isSelf)
    if isSelf then return end
    local race = ns.Clans.CleanRace(msg.r)
    if not race then return end
    if not M.CanRun(from, race) then
        ns.Log("dropped: a clan meeting from " .. from .. ", who can't run the " .. race .. " clan's meetings")
        return
    end
    if msg.on == true then
        local isNew = M.active[race] == nil or M.active[race].organiser ~= from
        M.active[race] = { organiser = from, since = GetServerTime() }
        if isNew then
            M.asked[race] = nil         -- a new organiser: I can ask them
            ns.Fire("CLANMEET_STARTED", race, from)
        end
    elseif M.active[race] and M.active[race].organiser == from then
        M.active[race] = nil
        M.asked[race] = nil
    end
    Changed()
end)

ns.Comm.On("CAK", function(msg, from, channel, isSelf)
    if isSelf or channel ~= "WHISPER" or not mine or msg.r ~= mine.race then return end
    Asked(from, "b")
end)

-- A guildie who just logged in hears about my meeting.
ns.Listen("HI_IN", function(msg, from)
    if msg.ask ~= true or not mine or (ns.Sim and ns.Sim.IsFake(from)) then return end
    C_Timer.After(3 + math.random() * 3, function() Announce(true, "WHISPER", from) end)
end)

-- Meetings end by themselves: after 2 hours, or when the organiser goes offline.
local function Tidy()
    local now = GetServerTime()
    local changed = false
    for race, a in pairs(M.active) do
        local m = ns.Guild.Get(a.organiser)
        if now >= a.since + LIVE or (a.organiser ~= ns.me and (not m or not m.online)) then
            M.active[race] = nil; M.asked[race] = nil; changed = true
        end
    end
    if mine and now >= mine.since + LIVE then M.Stop() end
    for name, w in pairs(wasHere) do if now - w.t >= WAS_HERE then wasHere[name] = nil; changed = true end end
    if changed then Changed() end
end
ns.Listen("ROSTER", function() ns.Safe(Tidy) end)
ns.Listen("LOGIN", function() C_Timer.NewTicker(30, function() ns.Safe(Tidy) end) end)
ns.OnEvent("GROUP_ROSTER_UPDATE", Changed)

-- Dev only: the CurseForge build leaves this out (BigWigs packager's do-not-package markers).
--@do-not-package@
-- For testing alone (sim mode):
--   /ynm dev clanmeet        my clan's fake leader starts a meeting (I see the pop-up and Ask).
--   /ynm dev clanmeet start  I start my clan's meeting (test editor on if my rank can't), Clans tab.
--   /ynm dev clanmeet stop   I stop mine.
ns.devCommands.clanmeet = function(arg)
    if not (ns.Sim and ns.Sim.IsOn()) then ns.Print("/ynm dev sim on first") return end
    if arg == "stop" then
        if mine then M.Stop(); ns.Print("(dev) clan meeting stopped") else ns.Print("(dev) no clan meeting of mine to stop") end
        return
    end
    if arg ~= "start" then ns.Sim.FakeClanMeet() return end
    local race = ns.Clans.MyRace()
    if not race then ns.Print("(dev) your clan (race) isn't known yet") return end
    if not M.ICanRun(race) then ns.devCommands.editor("on") end
    if M.Start(race) then
        ns.Print("(dev) clan meeting started for " .. ns.Clans.RaceName(race) .. ": the fakes ask over the next 10 s")
        if ns.UI and ns.UI.Open then ns.UI.Open("clans") end
    else
        ns.Print("(dev) couldn't start the clan meeting")
    end
end
--@end-do-not-package@
