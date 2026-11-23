-- The leveling guide's data and the lists it shows. Our own short tables of game facts.
-- Zones: name, familiar level range, then the levels most of that faction's quests sit at
-- ({ Alliance }, { Horde }; false = not suggested for that faction).
local _, ns = ...

local G = {}
ns.LevelGuide = G

-- Quest lists come live from QuestieDB (Data/LiveQuests.lua), read when asked for.
-- Without it the guide still works and just has no quest lists.
local QUEST_DATA = { QUESTS = "QUESTS", QUEST_VARIANTS = "VARIANTS", QUEST_EARLIER = "EARLIER", QUEST_STEPS = "STEPS",
                     QUEST_LEADS = "LEADS", QUEST_BAGS = "BAGS",
                     QUEST_BAG_VARIANTS = "BAG_VARIANTS" }
setmetatable(G, { __index = function(_, key)
    local field = QUEST_DATA[key]
    if not field then return nil end
    local data = ns.LiveQuests.Data()
    return data and data[field] or nil
end })

function G.HasQuestData() return ns.LiveQuests.Data() ~= nil end

-- What to tell the player when there are no quest lists to show (heading, text, steps); nil when there are.
function G.QuestDataNote()
    if G.HasQuestData() then return nil end
    local L = ns.L
    if ns.LiveQuests.Status() == "missing" then
        return L.GUIDE_NO_QUEST_DATA, L.GUIDE_NO_QUEST_DATA_TEXT, L.GUIDE_NO_QUEST_DATA_STEPS
    end
    return L.GUIDE_QUEST_DATA_OLD, L.GUIDE_QUEST_DATA_OLD_TEXT, L.GUIDE_QUEST_DATA_OLD_STEPS
end

G.ZONES = {
    { "Durotar", 1, 10, false, { 5, 10 } },
    { "Elwynn Forest", 1, 10, { 4, 10 }, false },
    { "Mulgore", 1, 10, false, { 2, 10 } },
    { "Teldrassil", 1, 11, { 4, 11 }, false },
    { "Dun Morogh", 1, 12, { 2, 11 }, false },
    { "Tirisfal Glades", 1, 12, false, { 5, 12 } },
    { "Zephras Isle", 1, 12, { 6, 12 }, { 5, 12 } },
    { "Westfall", 9, 18, { 10, 18 }, false },
    { "Loch Modan", 10, 18, { 10, 18 }, false },
    { "Silverpine Forest", 10, 20, false, { 10, 18 } },
    { "The Barrens", 10, 25, { 13, 20 }, { 10, 21 } },
    { "Darkshore", 11, 19, { 13, 19 }, false },
    { "Redridge Mountains", 15, 25, { 15, 24 }, false },
    { "Stonetalon Mountains", 15, 25, { 21, 25 }, { 18, 25 } },
    { "Ashenvale", 19, 30, { 21, 30 }, { 24, 30 } },
    { "Duskwood", 19, 30, { 24, 30 }, { 26, 28 } },
    { "Wetlands", 20, 30, { 21, 30 }, false },
    { "Hillsbrad Foothills", 20, 31, { 29, 31 }, { 22, 31 } },
    { "Thousand Needles", 24, 35, { 30, 35 }, { 26, 35 } },
    { "Alterac Mountains", 27, 39, { 33, 39 }, false },
    { "Desolace", 30, 39, { 33, 39 }, { 33, 39 } },
    { "Arathi Highlands", 30, 40, { 37, 40 }, { 34, 40 } },
    { "Stranglethorn Vale", 30, 50, { 31, 43 }, { 33, 45 } },
    { "Dustwallow Marsh", 36, 43, { 36, 40 }, { 36, 43 } },
    { "Swamp of Sorrows", 36, 43, { 36, 39 }, { 36, 43 } },
    { "Riverglades", 36, 44, { 37, 42 }, { 38, 43 } },
    { "Badlands", 36, 45, { 37, 43 }, { 37, 43 } },
    { "Tanaris", 40, 50, { 48, 50 }, { 48, 50 } },
    { "Shen'dralas", 41, 45, { 41, 43 }, { 41, 43 } },
    { "Feralas", 41, 49, { 43, 48 }, { 43, 48 } },
    { "The Hinterlands", 41, 56, { 43, 48 }, { 47, 51 } },
    { "Azshara", 42, 55, { 52, 55 }, { 52, 55 } },
    { "Searing Gorge", 43, 56, { 48, 50 }, { 48, 50 } },
    { "Blasted Lands", 46, 55, { 53, 55 }, { 50, 55 } },
    { "Western Plaguelands", 46, 57, { 55, 57 }, { 55, 57 } },
    { "Felwood", 47, 54, { 52, 54 }, { 51, 54 } },
    { "Un'Goro Crater", 48, 55, { 52, 55 }, { 52, 55 } },
    { "Burning Steppes", 50, 59, { 52, 54 }, { 52, 54 } },
    { "Eastern Plaguelands", 54, 59, { 56, 59 }, { 56, 59 } },
    { "Silithus", 55, 59, { 57, 59 }, { 57, 59 } },
    { "Mount Hyjal", 55, 60, { 57, 59 }, { 57, 59 } },
    { "Winterspring", 55, 60, { 56, 60 }, { 56, 60 } },
}

-- Each zone's map id. Ids, because the game's own zone names change with the client's language.
local ZONE_MAPS = {
    ["Durotar"] = 1411, ["Elwynn Forest"] = 1429, ["Mulgore"] = 1412, ["Teldrassil"] = 1438, ["Dun Morogh"] = 1426,
    ["Tirisfal Glades"] = 1420, ["Zephras Isle"] = 2521, ["Westfall"] = 1436, ["Loch Modan"] = 1432,
    ["Silverpine Forest"] = 1421, ["The Barrens"] = 1413, ["Darkshore"] = 1439, ["Redridge Mountains"] = 1433,
    ["Stonetalon Mountains"] = 1442, ["Ashenvale"] = 1440, ["Duskwood"] = 1431, ["Wetlands"] = 1437,
    ["Hillsbrad Foothills"] = 1424, ["Thousand Needles"] = 1441, ["Alterac Mountains"] = 1416, ["Desolace"] = 1443,
    ["Arathi Highlands"] = 1417, ["Stranglethorn Vale"] = 1434, ["Dustwallow Marsh"] = 1445, ["Swamp of Sorrows"] = 1435,
    ["Riverglades"] = 2548, ["Badlands"] = 1418, ["Tanaris"] = 1446, ["Shen'dralas"] = 2652, ["Feralas"] = 1444,
    ["The Hinterlands"] = 1425, ["Azshara"] = 1447, ["Searing Gorge"] = 1427, ["Blasted Lands"] = 1419,
    ["Western Plaguelands"] = 1422, ["Felwood"] = 1448, ["Un'Goro Crater"] = 1449, ["Burning Steppes"] = 1428,
    ["Eastern Plaguelands"] = 1423, ["Silithus"] = 1451, ["Mount Hyjal"] = 2482, ["Winterspring"] = 1452,
}

-- A zone's map id, if the game has that map.
function G.ZoneMap(name)
    local id = ZONE_MAPS[name]
    if not id or not (C_Map and C_Map.GetMapInfo) then return nil end
    local ok, info = pcall(C_Map.GetMapInfo, id)
    return ok and type(info) == "table" and id or nil
end

-- A map's name from the game, for the quest lists' Location column. Nil if it doesn't know it.
local mapNames = {}
function G.MapName(mapID)
    if not mapID then return nil end
    if mapNames[mapID] then return mapNames[mapID] end
    if not (C_Map and C_Map.GetMapInfo) then return nil end
    local ok, info = pcall(C_Map.GetMapInfo, mapID)
    local name = ok and type(info) == "table" and info.name
    if type(name) ~= "string" or name == "" then return nil end
    mapNames[mapID] = name
    return name
end

-- Dungeons, by the keys in Dungeons.lua. where: how to find it. top: the boss level is the highest
-- boss's, as the fight order isn't certain. tag + note: what you need. enemy: whose land it's in.
local SCARLET_KEY = "The Scarlet Key opens this wing, or Lockpicking 175."
local CRESCENT_KEY = "The Crescent Key opens this wing, or Lockpicking 300."
G.DUNGEONS = {
    rfc = { where = "Orgrimmar" },
    hot = { where = "Beneath Ironforge", top = true, enemy = "Alliance" },
    rol = { where = "Above the Undercity", top = true, enemy = "Horde" },
    wc = { where = "The Barrens" },
    dm = { where = "Westfall" },
    sfk = { where = "Silverpine Forest" },
    bfd = { where = "Ashenvale" },
    stocks = { where = "Stormwind City" },
    exc = { where = "Wetlands", top = true },
    dal = { where = "Alterac Mountains", top = true, tag = "attune",
            Alliance = "Attunement: start with An Alarming Request from Emissary Jacques in Southshore.",
            Horde = "Attunement: start with Key to the City and Prison Break-In from Magus Wordeen Voidglare in Tarren Mill." },
    gnomer = { where = "Dun Morogh" },
    rfk = { where = "The Barrens" },
    smgy = { where = "Tirisfal Glades" },
    smlib = { where = "Tirisfal Glades" },
    drown = { where = "Off Stranglethorn Vale", top = true },
    smarm = { where = "Tirisfal Glades", tag = "key", note = SCARLET_KEY },
    rfd = { where = "The Barrens" },
    smcath = { where = "Tirisfal Glades", tag = "key", note = SCARLET_KEY },
    krol = { where = "Riverglades", top = true },
    ulda = { where = "Badlands" },
    zf = { where = "Tanaris" },
    mara = { where = "Desolace" },
    alcaz = { where = "Dustwallow Marsh", top = true },
    st = { where = "Swamp of Sorrows" },
    brd = { where = "Blackrock Mountain" },
    dme = { where = "Feralas" },
    lbrs = { where = "Blackrock Mountain" },
    blackmaw = { where = "Azshara", top = true },
    dmw = { where = "Feralas", tag = "key", note = CRESCENT_KEY },
    dmn = { where = "Feralas", tag = "key", note = CRESCENT_KEY },
    scholo = { where = "Western Plaguelands", tag = "key", note = "The Skeleton Key opens the front door, in Caer Darrow." },
    strat = { where = "Eastern Plaguelands" },
    stratsg = { where = "Eastern Plaguelands" },
    shaper = { where = "Un'Goro Crater", top = true, tag = "item", note = "Bring power crystals from Un'Goro to use on the consoles inside." },
    ubrs = { where = "Blackrock Mountain", tag = "key", note = "The Seal of Ascension gets you in." },
}

-- Wings of one place share their quests (Data/LiveQuests.lua). Other dungeons use their own key.
local QUEST_GROUP = { smgy = "scarlet", smlib = "scarlet", smarm = "scarlet", smcath = "scarlet",
                      dme = "diremaul", dmw = "diremaul", dmn = "diremaul", lbrs = "spire", ubrs = "spire",
                      stratsg = "strat" }

-- Dire Maul's wings each have their own door (QuestieDB's area for each).
local WING_AREA = { dme = 10026, dmw = 10023, dmn = 10022 }

-- A dungeon's entrance as something the map pin can show, or nil if we don't know it.
function G.Entrance(key)
    local d = ns.Dungeons.BY_KEY[key]
    if not d then return nil end
    local map, x, y = ns.LiveQuests.Entrance(QUEST_GROUP[key] or key, key == "stratsg" and 2 or 1, WING_AREA[key])
    if not map then return nil end
    return { id = "entrance:" .. key, name = string.format(ns.L.GUIDE_ENTRANCE_OF, d.name),
             map = map, x = x, y = y, entrance = true }
end

function G.DungeonMap(key)
    return ns.LiveQuests.DungeonMap(QUEST_GROUP[key] or key)
end

local function HasRace(races, id)
    for _, r in ipairs(races) do if r == id then return true end end
    return false
end

-- Who I am, for working out which quests are mine.
local function Me()
    local D = ns.Dungeons
    local mine = D.Faction()
    local _, _, classID = UnitClass("player")
    local raceID
    if not D.pretendFaction and UnitRace then raceID = select(3, UnitRace("player")) end
    return { side = (mine == "Alliance" and "A") or (mine == "Horde" and "H") or nil,
             classBit = classID and 2 ^ (classID - 1), race = raceID }
end

-- The bit test is plain maths: no bit library.
local function ForMe(me, side, classMask, races)
    return (not me.side or side == "B" or side == me.side)
        and (classMask == 0 or not me.classBit or math.floor(classMask / me.classBit) % 2 == 1)
        and (not races or not me.race or HasRace(races, me.race))
end

-- A dungeon's quests that I could take: my faction and race, and class quests for my class only.
-- A quest with one version per faction or race shows once.
function G.Quests(key)
    local me = Me()
    local list, seen = {}, {}
    for _, q in ipairs(G.QUESTS and G.QUESTS[QUEST_GROUP[key] or key] or {}) do
        if ForMe(me, q[5], q[6], q[7]) then
            -- Bag storylines (q[13] = the step) keep same-named steps apart.
            local rowKey = q[13] and (q[2] .. "|" .. q[13]) or q[2]
            local row = seen[rowKey]
            if not row then
                -- A quest both factions can take may have a quest giver in each one's city.
                local own = q[12] and me.side and q[12][me.side]
                local giver = own and own[1] or q[8]
                row = { id = q[1], name = q[2], level = q[3], req = q[4], giver = giver ~= "" and giver or nil,
                        map = own and own[2] or q[9] or nil, x = own and own[3] or q[10] or nil,
                        y = own and own[4] or q[11] or nil, ids = {}, exact = q[13] ~= nil }
                seen[rowKey] = row
                list[#list + 1] = row
            end
            row.ids[#row.ids + 1] = q[1]
            local variants = q[13] and G.QUEST_BAG_VARIANTS or G.QUEST_VARIANTS   -- a bag step's own versions
            for _, id in ipairs(variants and variants[q[1]] or {}) do
                row.ids[#row.ids + 1] = id
            end
        end
    end
    return list
end

local function TurnedIn(id)
    if not (C_QuestLog and C_QuestLog.IsQuestFlaggedCompleted) then return false end
    local ok, done = pcall(C_QuestLog.IsQuestFlaggedCompleted, id)
    return ok and done == true
end

G.TurnedIn = TurnedIn

-- The bag a quest row rewards: { name, slots }. ownOnly = this step alone, not its whole storyline.
function G.BagFor(q, ownOnly)
    local bags = G.QUEST_BAGS
    if not bags then return nil end
    for _, id in ipairs(q.ids or {}) do
        if bags[id] then return bags[id] end
    end
    if ownOnly then return nil end
    for _, node in ipairs(q.chain or {}) do
        for _, id in ipairs(node.ids) do
            if bags[id] then return bags[id] end
        end
    end
    return nil
end

-- Handed in, or handed in one of the quests that replace it (you can only ever do one of those).
local function StepDone(id)
    if TurnedIn(id) then return true end
    local s = G.QUEST_STEPS and G.QUEST_STEPS[id]
    for _, other in ipairs(s and s[12] or {}) do
        if TurnedIn(other) then return true end
    end
    return false
end

-- "log" = in my quest log, "done" = handed in, nil = neither. A quest with several ids counts as in
-- my log if any of them is. It's done when a final step is: an earlier step of the same name isn't enough.
function G.QuestState(q)
    for _, id in ipairs(q.ids) do
        if ns.Questions.InMyLog(id) then return "log" end
    end
    for _, id in ipairs(q.ids) do
        if (q.exact or not (G.QUEST_EARLIER and G.QUEST_EARLIER[id])) and StepDone(id) then return "done" end
    end
    return nil
end

local function StepForMe(me, id)
    local s = G.QUEST_STEPS and G.QUEST_STEPS[id]
    return s and ForMe(me, s[3], s[4], s[5])
end

-- What this quest still needs handed in first. "Needs one of" asks for just one that's mine.
local function Missing(me, id)
    local s, out = G.QUEST_STEPS and G.QUEST_STEPS[id], {}
    if not s then return out end
    for _, p in ipairs(s[10] or {}) do
        if StepForMe(me, p) and not StepDone(p) then out[#out + 1] = p end
    end
    local first, anyDone
    for _, p in ipairs(s[11] or {}) do
        if StepForMe(me, p) then
            first = first or p
            if StepDone(p) then anyDone = true end
        end
    end
    if first and not anyDone then out[#out + 1] = first end
    return out
end

-- The quest to do now on the way to this one: follows what's missing back to the start.
local function NextStep(me, id, seen)
    seen[id] = true
    for _, p in ipairs(Missing(me, id)) do
        if not seen[p] then return NextStep(me, p, seen) end
    end
    return id
end

local function StepPlace(me, id, fallback)
    local s = G.QUEST_STEPS and G.QUEST_STEPS[id]
    if not s then return fallback end
    local own = s[13] and me.side and s[13][me.side]    -- this faction's own quest giver
    local giver = own and own[1] or s[6]
    return { id = id, name = s[1], level = s[2], giver = giver ~= "" and giver or nil,
             map = own and own[2] or s[7] or nil, x = own and own[3] or s[8] or nil, y = own and own[4] or s[9] or nil }
end

-- Where this quest stands: final = its last step, target = the quest to go and get now,
-- locked = that's a different quest. Of several versions, one I can take now wins.
function G.QuestPlan(q)
    local me = Me()
    local final, nextId
    for _, id in ipairs(q.ids) do
        if (q.exact or not (G.QUEST_EARLIER and G.QUEST_EARLIER[id])) and StepForMe(me, id) then
            local step = NextStep(me, id, {})
            if step == id then
                final, nextId = id, step
                break
            end
            if not final then final, nextId = id, step end
        end
    end
    if not final then return { final = q.id, target = q, locked = false } end
    local target = StepPlace(me, nextId, q)
    return { final = final, target = target, locked = target.name ~= q.name }
end

-- The whole chain in the order you do it, each step marked done, log, next or later.
function G.QuestChain(plan)
    local me, out, seen = Me(), {}, {}
    local function Walk(id)
        if seen[id] then return end
        seen[id] = true
        local s = G.QUEST_STEPS and G.QUEST_STEPS[id]
        if not s then return end
        for _, p in ipairs(s[10] or {}) do
            if StepForMe(me, p) then Walk(p) end
        end
        local pick
        for _, p in ipairs(s[11] or {}) do
            if StepForMe(me, p) then
                pick = pick or p
                if StepDone(p) then pick = p; break end
            end
        end
        if pick then Walk(pick) end
        local state = "later"
        if StepDone(id) then state = "done"
        elseif ns.Questions.InMyLog(id) then state = "log"
        elseif id == plan.target.id then state = "next" end
        out[#out + 1] = { id = id, name = s[1], level = s[2], state = state }
    end
    Walk(plan.final)
    return out
end

-- A quest list (a dungeon's key, or "class") as a tree: one root per storyline. Each quest hangs under
-- the nearest quest that leads to it, looking through any steps that aren't on the list. Adds to each
-- row: parent, children and depth (indent: a straight chain stays level, a fork steps in); roots also
-- get chain (in order).
function G.QuestTree(key)
    local me, list, byId = Me(), G.Quests(key), {}
    local steps, leads = G.QUEST_STEPS or {}, G.QUEST_LEADS or {}
    for _, row in ipairs(list) do
        row.children = {}
        for _, id in ipairs(row.ids) do byId[id] = row end
    end
    local function Parent(row)
        local best, seen = nil, {}
        local Visit
        local function Check(links)
            for _, p in ipairs(links or {}) do
                local other = byId[p]
                if other and other ~= row then
                    if not best or other.level > best.level or (other.level == best.level and other.name > best.name) then
                        best = other
                    end
                elseif other == row or StepForMe(me, p) then
                    Visit(p)
                end
            end
        end
        Visit = function(id)
            if seen[id] then return end
            seen[id] = true
            local s = steps[id]
            if s then
                Check(s[10])
                Check(s[11])
            end
            Check(leads[id])
        end
        for _, id in ipairs(row.ids) do Visit(id) end
        return best
    end
    for _, row in ipairs(list) do
        local p = Parent(row)
        local up = p
        while up and up ~= row do up = up.parent end    -- a loop in the data stays two separate rows
        if p and up ~= row then
            row.parent = p
            table.insert(p.children, row)
        end
    end
    local function Walk(node, depth, root)
        node.depth = depth
        root.chain[#root.chain + 1] = node
        local fork = #node.children > 1
        for _, child in ipairs(node.children) do
            Walk(child, node == root and 1 or math.min(3, depth + (fork and 1 or 0)), root)
        end
    end
    local roots = {}
    for _, row in ipairs(list) do
        if not row.parent then
            row.chain = {}
            Walk(row, 0, row)
            roots[#roots + 1] = row
        end
    end
    return roots, #list
end

-- How far through a storyline I am: done, total, the quest to work towards, and the status of the
-- furthest I've got: "done" (all of it, or nothing newer), "log" (a step in my log), "locked" (can't
-- start it yet) or nil. A quest counts as done once anything after it is: lead-ins can be skipped.
function G.ChainProgress(root)
    local isDone, count, inLog = {}, 0, false
    local function Check(node)
        local state = G.QuestState(node)
        local done = state == "done"
        if state == "log" then inLog = true end
        for _, child in ipairs(node.children) do
            if Check(child) then done = true end
        end
        isDone[node] = done
        if done then count = count + 1 end
        return done
    end
    Check(root)
    local total, focus, found = #root.chain, root, false
    -- A quest in my log is what I'm working on, even on another branch of a fork.
    for _, node in ipairs(root.chain) do
        if G.QuestState(node) == "log" then
            focus, found = node, true
            break
        end
    end
    for _, node in ipairs(found and {} or root.chain) do
        if not isDone[node] and #node.children == 0 then
            focus = node
            break
        end
    end
    local furthest = (count == total and "done") or (inLog and "log") or (count > 0 and "done")
        or (G.QuestPlan(root).locked and "locked") or nil
    return count, total, focus, furthest
end

-- Show all: lowest level first, then highest, then by name.
local function ByLevelRange(a, b)
    if a.min ~= b.min then return a.min < b.min end
    if a.max ~= b.max then return a.max < b.max end
    return a.name < b.name
end

-- Zones my faction should see at this level: the ones at their best for me first, then nearest.
-- all = every zone for my faction, in level order; outside = not in range for my level.
function G.Zones(level, all)
    local mine = ns.Dungeons.Faction()
    local list = {}
    for _, z in ipairs(G.ZONES) do
        local band
        if mine == "Alliance" then band = z[4] elseif mine == "Horde" then band = z[5] else band = z[4] or z[5] end
        local inRange = level >= z[2] and level <= z[3]
        if band and (all or inRange) then
            list[#list + 1] = { name = z[1], min = z[2], max = z[3], bestMin = band[1], bestMax = band[2],
                                best = level >= band[1] and level <= band[2], outside = not inRange,
                                away = math.abs(level - (band[1] + band[2]) / 2) }
        end
    end
    if all then
        table.sort(list, ByLevelRange)
        return list
    end
    table.sort(list, function(a, b)
        if a.best ~= b.best then return a.best end
        if a.away ~= b.away then return a.away < b.away end
        return a.name < b.name
    end)
    return list
end

-- Dungeons in range for my level and faction: ready ones first, closest to my level on top, then
-- the ones whose boss is still a tough fight. all = every dungeon my faction can use, in level order.
function G.Dungeons(level, all)
    local mine = ns.Dungeons.Faction()
    local list = {}
    for _, row in ipairs(ns.Dungeons.MyList()) do
        local inRange = level >= row[3] and level <= row[4]
        if all or inRange then
            local d, info = ns.Dungeons.BY_KEY[row[1]], G.DUNGEONS[row[1]] or {}
            local tag, note = info.tag, info[mine] or info.note
            if info.enemy and mine and info.enemy ~= mine then tag = "enemy" end
            list[#list + 1] = { key = d.key, name = d.name, min = d.min, max = d.max, boss = d.boss, best = d.best,
                                ready = level >= d.best, where = info.where, top = info.top, tag = tag, note = note,
                                enemy = tag == "enemy" and info.enemy or nil, outside = not inRange }
        end
    end
    if all then
        table.sort(list, ByLevelRange)
        return list
    end
    table.sort(list, function(a, b)
        if a.ready ~= b.ready then return a.ready end
        if a.best ~= b.best then
            if a.ready then return a.best > b.best end
            return a.best < b.best
        end
        return a.name < b.name
    end)
    return list
end
