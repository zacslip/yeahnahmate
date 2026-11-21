-- 13 Nov: Yeah Nah Mate runs on WoW Forever, not Classic Era. Forever has 9 dungeons Classic doesn't,
-- its own riding spells and a level cap of 60. These checks stop the Classic lists creeping back.
math.randomseed(13)
YeahNahMateDB = nil
local ns = LoadAddon("YeahNahMate", "YeahNahMate")
LOGGED_IN = true
FireEvent("PLAYER_LOGIN")
Tick(3)
local D = ns.Dungeons

-- Dungeons: Forever's 35, the 9 new ones included, keys unique, sorted by level.
check(#D.LIST == 35, "35 dungeons, as Forever launched with (" .. #D.LIST .. ")")
local NEW = { hot = "Hall of Thanes", rol = "Ruins of Lordaeron", exc = "Excavation Site: Wetlands",
              dal = "City of Dalaran", drown = "The Drowned City", krol = "Krol'dok Stronghold",
              alcaz = "Alcaz Prison", blackmaw = "Blackmaw Hold", shaper = "Shaper's Terrace" }
local missing = {}
for key, name in pairs(NEW) do
    if not (D.BY_KEY[key] and D.BY_KEY[key].name == name) then missing[#missing + 1] = name end
end
check(#missing == 0, "all 9 Forever dungeons listed (missing: " .. table.concat(missing, ", ") .. ")")
local seen, dup, sorted, badLevels = {}, false, true, false
for i, d in ipairs(D.LIST) do
    if seen[d[1]] then dup = true end
    seen[d[1]] = true
    if i > 1 and d[3] < D.LIST[i - 1][3] then sorted = false end
    if d[3] > d[4] or d[4] > 60 then badLevels = true end
end
check(not dup, "dungeon keys are unique")
check(sorted, "dungeons sorted by their lowest level")
check(not badLevels, "every range is sensible and within Forever's level cap")
-- Keys that older versions already send still work.
for _, k in ipairs({ "rfc", "wc", "dm", "strat", "ubrs", "smgy" }) do
    check(D.BY_KEY[k] ~= nil, "old key still known: " .. k)
end
-- A level 15 sees the Forever low-level dungeons near the top.
local top = {}
for i = 1, 4 do top[D.ForLevel(15)[i].key] = true end
check(top.hot and top.rol, "at level 15, Hall of Thanes and Ruins of Lordaeron are suggested")
-- The picker's list: level order, and the first that fits a level 22 (Shadowfang Keep, 22-30?) is
-- the first whose range holds 22.
local list, first = D.ByLevel(22)
local ordered = true
for i = 2, #list do if list[i].min < list[i - 1].min then ordered = false end end
check(ordered and #list == 34, "ByLevel keeps level order, without what Horde can't use")
check(first and list[first].dist == 0 and list[first].min <= 22 and list[first].max >= 22, "ByLevel finds the first one for my level")
for i = 1, (first or 1) - 1 do if list[i].dist == 0 then first = nil end end
check(first ~= nil, "nothing earlier fits")
-- The game's Group Finder ranges, the boss levels, and "best from" (2 under the boss, at most 60).
local GAME = { hot = { 13, 20 }, rol = { 15, 22 }, wc = { 15, 24 }, sfk = { 20, 30 }, exc = { 26, 33 }, dal = { 28, 35 },
               smgy = { 30, 38 }, smlib = { 33, 41 }, drown = { 35, 42 }, smarm = { 36, 44 }, smcath = { 38, 46 },
               krol = { 40, 47 }, zf = { 44, 54 }, alcaz = { 48, 55 }, st = { 50, 60 }, dme = { 54, 60 },
               dmw = { 56, 60 }, dmn = { 56, 60 }, ubrs = { 59, 60 } }
for k, r in pairs(GAME) do
    check(D.BY_KEY[k].min == r[1] and D.BY_KEY[k].max == r[2], "game range for " .. k)
end
check(D.BY_KEY.rfd.boss == 41 and D.BY_KEY.rfd.best == 39, "Razorfen Downs: boss 41, best from 39")
check(D.BY_KEY.ubrs.boss == 62 and D.BY_KEY.ubrs.best == 60, "best from stops at the level cap")
for _, d in ipairs(D.LIST) do
    check(type(d[5]) == "number" and D.BY_KEY[d[1]].best <= 60, "boss level for " .. d[1])
end
-- Faction: hidden from what I can pick, but a key from a message or old save still reads.
local function Lists(key)
    for _, d in ipairs(D.MyList()) do if d[1] == key then return true end end
    return false
end
check(not Lists("stocks") and Lists("rfc") and #D.MyList() == 34, "Horde: no Stockade, Ragefire listed")
check(D.BY_KEY.stocks ~= nil and D.Name("stocks") == "The Stockade", "a hidden dungeon's key still reads")
D.pretendFaction = "Alliance"
check(Lists("stocks") and not Lists("rfc") and #D.MyList() == 34, "Alliance: Stockade listed, no Ragefire")
check(Lists("hot") and Lists("rol"), "Hall of Thanes and Ruins of Lordaeron are for both")
D.pretendFaction = nil
-- A group for a new dungeon can be posted and is accepted from a guildie.
check(D.Post("dal", "t", { t = 1, h = 1, d = 3 }, ""), "a City of Dalaran group can be posted")

-- Milestones: Forever's level cap.
check(ns.Milestones.MAX_LEVEL == 60, "level milestones stop at 60")

check(#ERRORS == 0, "no errors (" .. (ERRORS[1] or "none") .. ")")
