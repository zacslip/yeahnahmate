-- Speed at guild size (The Good Sorts is about 500 members): a 500-member roster, 120 online, 40 with
-- the addon sending positions, statuses, recipe lists, events and requests. Times the busy parts
-- and counts messages. (Lua here is the plain interpreter, like the game's, so the numbers are a fair
-- guide; the limits are generous so the test isn't flaky.)
math.randomseed(11)
YeahNahMateDB = nil
local CLASSES = { "WARRIOR", "MAGE", "PRIEST", "ROGUE", "HUNTER", "SHAMAN", "WARLOCK", "DRUID" }
local ZONES = { "The Barrens", "Durotar", "Ashenvale", "Orgrimmar", "Stonetalon Mountains", "Hillsbrad Foothills" }
local MAPS = { 1413, 1411, 1440, 1454, 1442, 1424 }
local FIRST = { "Bluey", "Bingo", "Chilli", "Bandit", "Muffin", "Socks", "Rusty", "Calypso", "Lucky", "Indy" }
FAKE.roster = { { "Ned Jones", "Guild Master", 0, 22, "Shaman", "The Barrens", "", "", true, 0, "SHAMAN", 0, 0, false, false, 3, "Player-6797-0000NED1" } }
for i = 1, 499 do
    local online = i <= 119
    FAKE.roster[#FAKE.roster + 1] = { FIRST[i % 10 + 1] .. " Member" .. i, i <= 5 and "Officer" or "Member", i <= 5 and 1 or 3,
        1 + (i * 7) % 60, "x", ZONES[i % 6 + 1], "", "", online, 0, CLASSES[i % 8 + 1] }
end
local ns = LoadAddon("YeahNahMate", "YeahNahMate")
LOGGED_IN = true
FireEvent("PLAYER_LOGIN")
ns.settings.sharePosition, ns.settings.shareProfessions = true, true
Tick(2)
local Ser = LibStub("AceSerializer-3.0")
local function Msg(t) return Ser:Serialize(t) end
local function Time(fn, reps)
    reps = reps or 1
    local t0 = os.clock()
    for _ = 1, reps do fn() end
    return (os.clock() - t0) * 1000 / reps
end
local results = {}
local function Report(name, ms, limit)
    results[#results + 1] = string.format("%-44s %7.2f ms  (limit %d)", name, ms, limit)
    check(ms < limit, string.format("%s: %.2f ms", name, ms))
end

check(#ns.Guild.list == 500, "500 members read")
Report("roster read (500 members)", Time(ns.Guild.Scan, 10), 60)

-- 40 guildies with the addon: hello (with status and recipe-list version), a position, a recipe list.
local users = {}
for i = 1, 40 do users[i] = FAKE.roster[i + 1][1] end
local now = GetServerTime()
local receive = Time(function()
    for i, name in ipairs(users) do
        INJECT("YNM", Msg({ v = 1, t = "HI", ver = "0.8.1", l = 20 + i % 30, z = ZONES[i % 6 + 1], st = "g", n = 3 }), "GUILD", name)
        INJECT("YNM", Msg({ v = 1, t = "POS", m = MAPS[i % 6 + 1], x = (i % 10) / 10 + 0.05, y = 0.5 }), "GUILD", name)
        local ids = {}
        for j = 1, 120 do ids[j] = 1000 + i * 200 + j end
        INJECT("YNM", Msg({ v = 1, t = "PROF", pv = now - i, p = { [197] = { r = 150, m = 225, i = ids } } }), "GUILD", name)
    end
    Deliver()
end)
Report("receive 120 messages (40 hellos, positions, recipe lists)", receive, 400)
check(ns.Comm.OthersOnline() == 40, "40 others online with the addon")

-- Events and requests in the store.
for i = 1, 30 do
    INJECT("YNM", Msg({ v = 1, t = "EVT", id = 5000 + i, ti = "Event " .. i, at = now + i * 3600, k = "s", nt = 0, nh = 0, nd = 0, note = "", ev = now }), "GUILD", users[i])
end
for i = 1, 40 do
    INJECT("YNM", Msg({ v = 1, t = "RQ", id = 7000 + i, it = "Thing " .. i, n = 1, u = now + 86400, ev = now }), "GUILD", users[i])
end
Tick(1)

local R = ns.Roster
Report("roster sort, Everyone (500)", Time(function() R.Get(R.ALL) end, 20), 20)
Report("roster sort by name (500)", Time(function() R.Get(R.ALL, "name") end, 20), 25)
Report("near me (positions, distances)", Time(function() R.NearMe() end, 20), 20)
Report("recipe search 'member' over 4800 recipes", Time(function() ns.Prof.Search(nil, "12") end, 10), 60)

-- Each tab's redraw with all of that in.
ns.UI.Open("home")
for _, tab in ipairs({ "home", "roster", "dungeons", "calendar", "professions", "streamers", "info", "settings" }) do
    Report("redraw " .. tab .. " tab", Time(function() ns.UI.Select(tab) end, 5), 16)
end

-- Messages I send per minute while moving around with 40 others online (positions slow down as
-- more guildies have the addon). Nobody near me: the usual pace.
local function MyPositions(fn)
    local before = #SENT
    fn()
    local mine = 0
    for i = before + 1, #SENT do
        local ok, m = Ser:Deserialize(SENT[i].text)
        if ok and type(m) == "table" and m.t == "POS" then mine = mine + 1 end
    end
    return mine
end
local saved = ns.Map.pos
ns.Map.pos = {}
local mine = MyPositions(function() for i = 1, 60 do FAKE.x = 0.3 + i * 0.005; Tick(1) end end)
check(mine <= 4, "positions I send per minute while moving, nobody near: " .. mine .. " (every " .. ns.Map.Interval() .. " s)")
-- One guildie with the addon within 400 yd: the near lane, every 3 s while I move.
ns.Map.pos = { [users[1]] = { m = 1413, x = 0.62, y = 0.5, at = GetTime() } }
mine = MyPositions(function()
    for i = 1, 60 do FAKE.x = 0.6 + i * 0.0005; ns.Map.pos[users[1]].at = GetTime(); Tick(1) end
end)
check(mine >= 15 and mine <= 21, "with a guildie near: every 3 s (" .. mine .. " a minute)")
ns.Map.pos = saved

-- A busy evening: 20 roster events in a burst make one scan.
local scans = 0
ns.Listen("ROSTER", function() scans = scans + 1 end)
for i = 1, 20 do FireEvent("GUILD_ROSTER_UPDATE") end
Tick(2)
check(scans == 1, "20 roster events -> 1 scan")

for _, line in ipairs(results) do io.write("    " .. line .. "\n") end
io.flush()
check(#ERRORS == 0, "no errors (" .. (ERRORS[1] or "none") .. ")")
