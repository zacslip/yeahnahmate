-- Bugs from the 0.24.0 code review: each one stays fixed.
math.randomseed(241)
YeahNahMateDB = nil
dofile("tests/fake_questiedb.lua")
LibQuestieDB = FakeQuestieDB()
local ns = LoadAddon("YeahNahMate", "YeahNahMate")
LOGGED_IN = true
FireEvent("PLAYER_LOGIN")
Tick(3)
ns.settings.sharePosition, ns.settings.shareProfessions = false, false
local Ser = LibStub("AceSerializer-3.0")
local function Msg(t) return Ser:Serialize(t) end
local G, D, Comm = ns.LevelGuide, ns.Dungeons, ns.Comm
INJECT("YNM", Msg({ v = 1, t = "HI", ver = "0.24.0" }), "GUILD", "Bluey Heeler")
Tick(15)

local function Quest(key, name)
    for _, q in ipairs(G.Quests(key)) do if q.name == name then return q end end
end

-- 1. Each faction goes to its own quest giver.
D.pretendFaction = "Alliance"
local tabetha = Quest("zf", "Tabetha's Task")
check(tabetha and tabetha.map ~= 1458 and tabetha.giver ~= "Anastasia Hartwell", "Alliance isn't sent to Undercity for Tabetha's Task")
check(G.QuestPlan(tabetha).target.map ~= 1458, "nor by the map pin")
D.pretendFaction = "Horde"
tabetha = Quest("zf", "Tabetha's Task")
check(tabetha and tabetha.giver == "Anastasia Hartwell" and tabetha.map == 1458, "Horde keeps the Undercity quest giver")
D.pretendFaction = nil
-- Every faction-specific place in the data is well formed.
local function GoodPlace(p)
    return type(p) == "table" and type(p[1]) == "string" and type(p[2]) == "number" and p[3] > 0 and p[3] <= 100 and p[4] >= 0 and p[4] <= 100
end
local places = 0
for key, list in pairs(G.QUESTS) do
    for _, q in ipairs(list) do
        if q[12] then
            places = places + 1
            check(GoodPlace(q[12].A) and GoodPlace(q[12].H), "own quest givers well formed: " .. key .. " " .. q[2])
        end
    end
end
for id, s in pairs(G.QUEST_STEPS) do
    if s[13] then check(GoodPlace(s[13].A) and GoodPlace(s[13].H), "own quest givers well formed: step " .. id) end
end
check(places > 0, "some quests have a giver per faction (" .. places .. ")")

-- 2. Skyborne race ids are the game's (95 and 96), never the bit position plus one.
local bad = 0
local function CheckRaces(races)
    for _, r in ipairs(races or {}) do if r == 33 or r == 34 then bad = bad + 1 end end
end
for _, list in pairs(G.QUESTS) do for _, q in ipairs(list) do CheckRaces(q[7]) end end
for _, s in pairs(G.QUEST_STEPS) do CheckRaces(s[5]) end
check(bad == 0, "no quest uses the wrong Skyborne race id (" .. bad .. ")")
local skyborne = 0
for _, s in pairs(G.QUEST_STEPS) do
    for _, r in ipairs(s[5] or {}) do if r == 95 or r == 96 then skyborne = skyborne + 1 end end
end
check(skyborne > 0, "Skyborne-only quests are in the data")
local realRace = UnitRace
UnitRace = function() return "Skyborne", "Skyborne", 96 end
local steps = 0
for _, s in pairs(G.QUEST_STEPS) do
    if s[5] and s[3] == "H" then
        for _, r in ipairs(s[5]) do if r == 96 then steps = steps + 1 end end
    end
end
check(steps > 0, "a Horde Skyborne has their own steps")
UnitRace = realRace

-- 3. A guildie who stopped sharing recipes: the copy says so.
INJECT("YNM", Msg({ v = 1, t = "PROF", pv = GetServerTime() - 100, p = false }), "GUILD", "Bandit Heeler")
Tick(1)
local before = #SENT
INJECT("YNM", Msg({ v = 1, t = "REQ", w = "PROFS", n = { "Bandit Heeler" } }), "WHISPER", "Bluey Heeler")
Tick(5)
local copy
for i = before + 1, #SENT do
    local ok, m = Ser:Deserialize(SENT[i].text)
    if ok and type(m) == "table" and m.t == "PROF" and m.o == "Bandit Heeler" then copy = m end
end
check(copy and copy.p == false, "the copy of an opted-out guildie carries 'not shared'")

-- 4. Junk in a message's logged fields doesn't raise an error or stop it.
local errorsBefore = #ERRORS
INJECT("YNM", Msg({ v = 1, t = "PROF", o = {} }), "GUILD", "Bluey Heeler")
INJECT("YNM", Msg({ v = 1, t = "RQ", x = "done", mk = { {} } }), "GUILD", "Bluey Heeler")
INJECT("YNM", Msg({ v = 1, t = "BRD", o = {} }), "GUILD", "Bluey Heeler")
INJECT("YNM", Msg({ v = 1, t = "EVT", o = {}, x = true }), "GUILD", "Bluey Heeler")
INJECT("YNM", Msg({ v = 1, t = "ALT", o = {} }), "GUILD", "Bluey Heeler")
Tick(1)
check(#ERRORS == errorsBefore, "malformed messages cause no error (" .. tostring(ERRORS[errorsBefore + 1]) .. ")")

-- 5. Someone who just logged in, with a roster that still says offline, keeps their catch-up.
local m = ns.Guild.Get("Chilli Heeler") or ns.Guild.list[2]
local name = m.name
m.online = false
INJECT("YNM", Msg({ v = 1, t = "HI", ver = "0.24.0" }), "GUILD", name)
Tick(1)
check(Comm.Reachable(name), "just heard from them: reachable")
Tick(40)
m.online = false
check(Comm.Reachable(name), "40 s on, a stale 'offline' roster still doesn't count")
Tick(40)
m.online = false
check(not Comm.Reachable(name), "well past a roster refresh, offline means offline")

-- 6. A new organiser clears "Asked".
local M = ns.ClanMeet
local race = next(M.active) or "Orc"
M.asked[race] = true
M.active[race] = { organiser = "Somebody Else", since = GetServerTime() }
local realCan = M.CanRun
M.CanRun = function() return true end
INJECT("YNM", Msg({ v = 1, t = "CMT", r = race, on = true }), "GUILD", "Bluey Heeler")
Tick(1)
M.CanRun = realCan
check(M.active[race] and M.active[race].organiser == "Bluey Heeler", "the new organiser's meeting is on")
check(M.asked[race] == nil, "and I can ask them for an invite")

check(#ERRORS == errorsBefore, "no errors (" .. tostring(ERRORS[errorsBefore + 1]) .. ")")
