-- Memory churn: how much short-lived memory (garbage) the addon makes per minute in a busy evening.
-- 500 members, 100 online with the addon sending positions and statuses, the game's roster updates
-- every few seconds. The game shows an addon's memory including garbage it hasn't swept yet, so a
-- high churn rate is what makes the number in Settings climb between sweeps (4.6 -> 12 MB was seen).
math.randomseed(7)
YeahNahMateDB = nil
local CLASSES = { "WARRIOR", "MAGE", "PRIEST", "ROGUE", "HUNTER", "SHAMAN", "WARLOCK", "DRUID" }
local ZONES = { "The Barrens", "Durotar", "Ashenvale", "Orgrimmar", "Stonetalon Mountains", "Hillsbrad Foothills" }
local MAPS = { 1413, 1411, 1440, 1454, 1442, 1424 }
local FIRST = { "Bluey", "Bingo", "Chilli", "Bandit", "Muffin", "Socks", "Rusty", "Calypso", "Lucky", "Indy" }
FAKE.roster = { { "Ned Jones", "Guild Master", 0, 22, "Shaman", "The Barrens", "", "", true, 0, "SHAMAN", 0, 0, false, false, 3, "Player-6797-0000NED1" } }
for i = 1, 499 do
    FAKE.roster[#FAKE.roster + 1] = { FIRST[i % 10 + 1] .. " Member" .. i, i <= 5 and "Officer" or "Member", i <= 5 and 1 or 3,
        1 + (i * 7) % 60, "x", ZONES[i % 6 + 1], "", "", i <= 119, 0, CLASSES[i % 8 + 1] }
end
local ns = LoadAddon("YeahNahMate", "YeahNahMate")
LOGGED_IN = true
FireEvent("PLAYER_LOGIN")
ns.settings.sharePosition, ns.settings.shareProfessions = true, true
Tick(2)
local Ser = LibStub("AceSerializer-3.0")
local function Msg(t) return Ser:Serialize(t) end
local users = {}
for i = 1, 100 do users[i] = FAKE.roster[i + 1][1] end
for i, name in ipairs(users) do
    INJECT("YNM", Msg({ v = 1, t = "HI", ver = ns.VERSION, l = 20 + i % 30, z = ZONES[i % 6 + 1], st = "g", n = 3 }), "GUILD", name)
end
Deliver()
Tick(30)

-- One game minute of a busy evening: every guildie's position every 15 s, a status now and then,
-- and a roster update from the game every 5 s (logins, levels, zones in a 500-member guild).
local function Minute()
    for s = 1, 60 do
        for i, name in ipairs(users) do
            if (i + s) % 15 == 0 then
                INJECT("YNM", Msg({ v = 1, t = "POS", m = MAPS[i % 6 + 1], x = math.random(), y = math.random() }), "GUILD", name)
            end
            if (i + s) % 60 == 0 then
                INJECT("YNM", Msg({ v = 1, t = "ST", l = 20 + i % 30, z = ZONES[math.random(6)], st = "g", n = 3 }), "GUILD", name)
            end
        end
        if s % 5 == 0 then FireEvent("GUILD_ROSTER_UPDATE") end
        Deliver()
        Tick(1)
    end
end
-- KB allocated per game minute (the sweeper is paused while measuring, so nothing is hidden).
local function Churn(minutes)
    collectgarbage("collect")
    collectgarbage("stop")
    local before = collectgarbage("count")
    for _ = 1, minutes do Minute() end
    local kb = (collectgarbage("count") - before) / minutes
    collectgarbage("restart")
    collectgarbage("collect")
    return kb
end

-- The test's own cost (building messages, the fake game's event calls, the message library) is
-- measured by running the same minute with the addon's receiving switched off, and taken away.
local realReceive = ns.Comm.Receive
ns.Comm.Receive = function() end
local harness = Churn(2)
ns.Comm.Receive = realReceive

-- One roster read on its own: members are updated in place, so (almost) nothing is thrown away.
collectgarbage("collect"); collectgarbage("stop")
local b = collectgarbage("count")
for _ = 1, 10 do ns.Guild.Scan() end
local scan = (collectgarbage("count") - b) / 10
collectgarbage("restart")
check(scan < 40, string.format("a 500-member roster read makes under 40 KB of garbage (%.0f KB; was 340)", scan))

local closed = Churn(3) - harness
ns.UI.Open("roster")
local roster = Churn(2) - harness
ns.UI.Select("home")
local home = Churn(2) - harness
ns.UI.Toggle()
-- (Limits are about 1.5x today's numbers, which include the fake game's own overhead. Before 0.8.9
-- the window-shut number was about 6 MB a minute.)
-- 0.20.0 added 200 KB to each: nearby guildies' minimap dots glide (Map.Glide), and here about eight
-- of them are near and moving all the time. Moving a dot makes the map library redraw every minimap
-- dot; in the game that happens every frame anyway while I move myself.
check(closed < 1700, string.format("window shut: under 1.7 MB of garbage a minute (%.0f KB)", closed))
check(roster < 1700, string.format("roster tab open: under 1.7 MB of garbage a minute (%.0f KB)", roster))
check(home < 2200, string.format("home tab open: under 2.2 MB of garbage a minute (%.0f KB)", home))
