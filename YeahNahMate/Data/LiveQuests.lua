-- The leveling guide's dungeon and class quests, read live from QuestieDB (an optional dependency) through its
-- public API. We keep none of its data in this addon: only which zones and bosses belong to which
-- dungeon, and a few quests to leave out. Without QuestieDB the guide still works, with no quest lists.
-- Read once, the first time a list is needed. Ids, not names, so it works in every game language.
local _, ns = ...

local Live = {}
ns.LiveQuests = Live

local CONTRACT = 4      -- the QuestieDB API version this was written against

-- The zones of each dungeon. Wings of one place share their quests.
local GROUPS = {
    rfc = { 2437 }, hot = { 16919 }, rol = { 16611 }, wc = { 718 }, dm = { 1581, 10029 },
    sfk = { 209, 10014, 10015, 10016, 10017, 10018, 10019 }, bfd = { 719, 10020, 10021 }, stocks = { 717 },
    exc = { 16732, 16877, 16878, 16879, 16880 }, dal = { 16544, 16558, 16559, 16560, 16562 },
    gnomer = { 721, 133, 10030, 10031, 10032 }, rfk = { 491, 1717 }, scarlet = { 796, 6109, 6386, 10008, 10009, 10010 },
    drown = {}, rfd = { 722 }, krol = { 17780 }, ulda = { 1337, 1517, 10033 }, zf = { 1176, 978 }, mara = { 2100, 10000 },
    alcaz = { 2079 }, st = { 1477, 1417 }, brd = { 1584, 1585 }, spire = { 1583, 10003, 10004, 10005, 10006, 10007 },
    diremaul = { 2557, 10022, 10023, 10024, 10025, 10026, 10027 }, blackmaw = {}, scholo = { 2057, 10011, 10012, 10013 },
    strat = { 2017, 10001 }, shaper = { 16985 },
}

-- The new dungeons' bosses have no spawn data, so quests are linked to them by creature id.
local BOSSES = {
    drown = { 258905, 258924, 260042, 260202, 260243, 260274, 263886, 264177, 267852, 269466, 269586, 270882, 270883,
              270884, 270885, 270886, 270887, 270888, 273738 },
    krol = { 258964, 258966, 258968, 258972, 259281, 262716, 264773 },
    alcaz = { 255391, 255702, 255997, 256236, 257016 },
    blackmaw = { 247195, 247198, 247206, 247207, 247209, 247231, 247234, 250034, 269104, 269111 },
    shaper = { 253201, 253218, 261809, 261811, 261812, 261813, 261974, 262081, 262127, 262297, 272561 },
}

-- Level range of each group: quests far outside it only share a zone or a drop with the dungeon.
local LEVELS = {
    rfc = { 13, 18 }, hot = { 13, 20 }, rol = { 15, 22 }, wc = { 15, 24 }, dm = { 17, 26 }, sfk = { 20, 30 },
    bfd = { 24, 32 }, stocks = { 24, 32 }, exc = { 26, 33 }, dal = { 28, 35 }, gnomer = { 29, 38 }, rfk = { 29, 38 },
    scarlet = { 30, 46 }, drown = { 35, 42 }, rfd = { 37, 46 }, krol = { 40, 47 }, ulda = { 41, 51 }, zf = { 44, 54 },
    mara = { 46, 55 }, alcaz = { 48, 55 }, st = { 50, 60 }, brd = { 52, 60 }, spire = { 55, 60 }, diremaul = { 54, 60 },
    blackmaw = { 55, 60 }, scholo = { 58, 60 }, strat = { 58, 60 }, shaper = { 58, 60 },
}

local function Set(ids)
    local out = {}
    for _, id in ipairs(ids) do out[id] = true end
    return out
end

-- Crafting and tier turn-ins that only need something a dungeon happens to drop.
local NOT_DUNGEON = Set({
    2848, 2855, 5166, 5167, 5306, 8905, 8906, 8907, 8908, 8909, 8910, 8911, 8912, 8913, 8914, 8915, 8916, 8917, 8918,
    8919, 8920, 8926, 8927, 8931, 8932, 8933, 8934, 8935, 8936, 8937, 8938, 8939, 8940, 8941, 8942, 8943, 8944, 8951,
    8952, 8953, 8954, 8955, 8956, 8957, 8958, 8959, 8999, 9000, 9001, 9002, 9003, 9004, 9005, 9006, 9007, 9008, 9009,
    9010, 9011, 9012, 9013, 9014, 9016, 9017, 9018, 9019, 9020, 9021, 9022, 84147, 84148, 84149, 84150, 84151, 84154,
    84155, 84156, 84157, 84158, 84159, 84160, 84161, 84162, 97411, 97447,
})

-- Listed in the database but not quests a player can pick up.
local NOT_AVAILABLE = Set({ 1318, 4601, 4602, 4605, 4606, 7462, 7668, 8869 })

local ZONE_GROUP, BOSS_GROUP = {}, {}
for group, zones in pairs(GROUPS) do
    for _, zone in ipairs(zones) do ZONE_GROUP[zone] = group end
end
for group, npcs in pairs(BOSSES) do
    for _, npc in ipairs(npcs) do BOSS_GROUP[npc] = group end
end

-- A table's numbered values in order, holes skipped.
local function Seq(t)
    if type(t) ~= "table" then return {} end
    local keys, out = {}, {}
    for k in pairs(t) do
        if type(k) == "number" then keys[#keys + 1] = k end
    end
    table.sort(keys)
    for i, k in ipairs(keys) do out[i] = t[k] end
    return out
end

local function HasBit(mask, b) return math.floor(mask / 2 ^ b) % 2 == 1 end

-- A class quest is limited to a few classes. A mask naming most of them is just a general quest.
local CLASS_KEY, MOST_CLASSES = "class", 4
local function IsClassMask(mask)
    local count = 0
    for b = 0, 11 do
        if HasBit(mask, b) then count = count + 1 end
    end
    return count > 0 and count <= MOST_CLASSES
end

-- The game's own quest category for each class (QuestSort id -> class id).
local CLASS_SORT = { [-61] = 9, [-81] = 1, [-82] = 7, [-141] = 2, [-161] = 8, [-162] = 4, [-261] = 3, [-262] = 5, [-263] = 11 }

-- In its class's category, or a class-only quest out in a zone while leveling. That leaves out
-- level 60 raid and gear turn-ins, and profession quests.
local function IsClassQuest(mask, level, sort, skill)
    if not IsClassMask(mask) then return false end
    local class = CLASS_SORT[sort]
    if class and HasBit(mask, class - 1) then return true end
    local needsSkill = type(skill) == "table" and (tonumber(skill[1]) or 0) > 0
    return level < 60 and sort > 0 and not needsSkill
end

local function Overlaps(a, b)
    for i = 0, 39 do
        if HasBit(a, i) and HasBit(b, i) then return true end
    end
    return false
end

local function Contains(mask, whole)
    for i = 0, 39 do
        if HasBit(whole, i) and not HasBit(mask, i) then return false end
    end
    return true
end

local function Round(v) return math.floor(v * 10 + 0.5) / 10 end

-- QuestieDB publishes its area-to-map tables as text. We never run text as code, so the
-- "[area] = map" pairs are read out of it. The override table goes first and wins.
local function ZoneMaps(lib)
    local zone = lib.Support and lib.Support.Get and lib.Support.Get("ZoneDB")
    local private = zone and zone.private
    local out = {}
    if not private then return out end
    local function Add(v)
        if type(v) == "table" then
            for k, m in pairs(v) do
                if out[k] == nil then out[k] = m end
            end
        elseif type(v) == "string" then
            for k, m in v:gmatch("%[(%d+)%]%s*=%s*(%d+)") do
                local area = tonumber(k)
                if out[area] == nil then out[area] = tonumber(m) end
            end
        end
    end
    Add(private.areaIdToUiMapIdOverride)
    Add(private.areaIdToUiMapId)
    return out
end

local function Build(lib)
    local Quest, Npc, Object, Item = lib.Quest, lib.Npc, lib.Object, lib.Item
    local masks = lib.Enum.factionRaceMasks
    local A, H = masks.Alliance, masks.Horde
    local maps = ZoneMaps(lib)
    local raceByBit = {}
    for id, mask in pairs(lib.Enum.raceMaskById or {}) do
        for b = 0, 39 do
            if mask == 2 ^ b then raceByBit[b] = id end
        end
    end

    local function SideOf(races)
        local a, h = races == 0 or Overlaps(races, A), races == 0 or Overlaps(races, H)
        if a == h then return "B", a end
        return a and "A" or "H", true
    end

    local function RaceList(races, side)
        local whole = (side == "A" and A) or (side == "H" and H) or (A + H)
        if races == 0 or Contains(races, whole) then return false end
        local out = {}
        for b = 0, 39 do
            if HasBit(races, b) then out[#out + 1] = raceByBit[b] or (b + 1) end
        end
        return out
    end

    -- Which dungeon a creature lives in: all its spawns in one group, or a known boss.
    local homes = {}
    local function Home(npc)
        if npc == nil then return nil end
        local known = homes[npc]
        if known ~= nil then return known or nil end
        local group, spawned, mixed = nil, false, false
        for zone in pairs(Npc.spawns(npc) or {}) do
            if type(zone) == "number" then
                spawned = true
                local g = ZONE_GROUP[zone]
                if not g or (group and g ~= group) then mixed = true end
                group = g or group
            end
        end
        local found = (spawned and not mixed and group) or (not spawned and BOSS_GROUP[npc]) or false
        homes[npc] = found
        return found or nil
    end

    local function OnlyHome(npcs)
        local group
        if #npcs == 0 then return nil end
        for _, npc in ipairs(npcs) do
            local g = Home(npc)
            if not g or (group and g ~= group) then return nil end
            group = g
        end
        return group
    end

    -- The first outdoor spawn: map, x, y.
    local function Spot(db, id)
        local spawns, zones = db.spawns(id), {}
        if type(spawns) ~= "table" then return nil end
        for zone in pairs(spawns) do
            if type(zone) == "number" then zones[#zones + 1] = zone end
        end
        table.sort(zones)
        for _, zone in ipairs(zones) do
            if not ZONE_GROUP[zone] and maps[zone] and maps[zone] ~= 0 then
                local p = Seq(Seq(spawns[zone])[1])
                if type(p[1]) == "number" and p[1] > 0 and type(p[2]) == "number" then
                    return maps[zone], Round(p[1]), Round(p[2])
                end
                return nil
            end
        end
        return nil
    end

    -- Who starts it and where, plus { A = ..., H = ... } when each faction has its own quest giver.
    local function Starter(id, side)
        local by = Quest.startedBy(id)
        local npcs = Seq(type(by) == "table" and by[1])
        local placed, bySide = {}, {}
        for _, npc in ipairs(npcs) do
            local map, x, y = Spot(Npc, npc)
            if map then
                local entry = { Npc.name(npc), map, x, y }
                placed[#placed + 1] = entry
                local friendly = tostring(Npc.friendlyToFaction(npc) or "")
                for _, f in ipairs({ "A", "H" }) do
                    if friendly:find(f, 1, true) and not bySide[f] then bySide[f] = entry end
                end
            end
        end
        if placed[1] then
            local main = bySide[side] or placed[1]
            local a, h = bySide.A, bySide.H
            local both = side == "B" and a and h and (a[1] ~= h[1] or a[2] ~= h[2] or a[3] ~= h[3] or a[4] ~= h[4])
            return main[1], main[2], main[3], main[4], both and { A = a, H = h } or nil
        end
        if npcs[1] then return Npc.name(npcs[1]) end
        local objects = Seq(type(by) == "table" and by[2])
        for _, object in ipairs(objects) do
            local map, x, y = Spot(Object, object)
            if map then return Object.name(object), map, x, y end
        end
        if objects[1] then return Object.name(objects[1]) end
        local items = Seq(type(by) == "table" and by[3])
        if items[1] then return Item.name(items[1]) end
        return nil
    end

    local function GroupOf(id, zone)
        if ZONE_GROUP[zone] then return ZONE_GROUP[zone] end
        local objectives = Quest.objectives(id)
        if type(objectives) ~= "table" then return nil end
        for _, e in ipairs(Seq(objectives[1])) do
            local g = Home(Seq(e)[1])
            if g then return g end
        end
        for _, e in ipairs(Seq(objectives[3])) do
            local item = Seq(e)[1]
            local g = item and OnlyHome(Seq(Item.npcDrops(item)))
            if g then return g end
        end
        return nil
    end

    -- Each dungeon's quests, and the class quests. One quest can be in both lists.
    local found, leads = {}, {}
    for _, id in ipairs(Quest.GetAllIds()) do
        -- "This quest leads to that one", which prerequisites don't always say (optional lead-ins).
        for _, target in ipairs({ Quest.nextQuestInChain(id) or 0, Quest.breadcrumbForQuestId(id) or 0 }) do
            if type(target) == "number" and target > 0 then
                leads[target] = leads[target] or {}
                table.insert(leads[target], id)
            end
        end
        local level, special = Quest.questLevel(id) or 0, Quest.specialFlags(id) or 0
        if not NOT_AVAILABLE[id] and not NOT_DUNGEON[id] and level >= 1 and level <= 60 and special % 2 == 0 then
            local cls = Quest.requiredClasses(id) or 0
            local sort = Quest.zoneOrSort(id) or 0
            local group = GroupOf(id, sort)
            local range = group and LEVELS[group]
            local inDungeon = range and level >= range[1] - 8 and level <= range[2] + 3
            local isClass = IsClassQuest(cls, level, sort, cls ~= 0 and Quest.requiredSkill(id) or nil)
            if inDungeon or isClass then
                local races = Quest.requiredRaces(id) or 0
                local side, usable = SideOf(races)
                if usable then
                    local giver, map, x, y, places = Starter(id, side)
                    local pre = Seq(Quest.preQuestGroup(id))
                    for _, p in ipairs(Seq(Quest.preQuestSingle(id))) do pre[#pre + 1] = p end
                    local entry = {
                        id = id, name = Quest.name(id), level = level, req = Quest.requiredLevel(id) or 0, side = side,
                        cls = cls, races = RaceList(races, side),
                        giver = giver, map = map, x = x, y = y, places = places, pre = pre,
                    }
                    if inDungeon then
                        found[group] = found[group] or {}
                        table.insert(found[group], entry)
                    end
                    if isClass then
                        found[CLASS_KEY] = found[CLASS_KEY] or {}
                        table.insert(found[CLASS_KEY], entry)
                    end
                end
            end
        end
    end

    -- The lists the guide reads: one row per version, the other versions noted.
    local out = { QUESTS = {}, VARIANTS = {}, EARLIER = {}, STEPS = {}, LEADS = {} }
    local listKeys = { CLASS_KEY }
    for group in pairs(GROUPS) do listKeys[#listKeys + 1] = group end
    for _, group in ipairs(listKeys) do
        local quests, rows, seen, named = found[group] or {}, {}, {}, {}
        for _, q in ipairs(quests) do
            named[q.name] = named[q.name] or {}
            named[q.name][q.id] = true
        end
        for _, q in ipairs(quests) do
            for _, p in ipairs(q.pre) do
                if p ~= q.id and named[q.name][p] then out.EARLIER[p] = true end
            end
        end
        table.sort(quests, function(a, b)
            if a.level ~= b.level then return a.level < b.level end
            if a.name ~= b.name then return a.name < b.name end
            return a.id < b.id
        end)
        for _, q in ipairs(quests) do
            local key = q.name .. "|" .. q.side .. "|" .. (q.races and table.concat(q.races, ",") or "") .. "|" .. q.cls
            if seen[key] then
                local list = out.VARIANTS[seen[key]] or {}
                out.VARIANTS[seen[key]] = list
                list[#list + 1] = q.id
            else
                seen[key] = q.id
                rows[#rows + 1] = { q.id, q.name, q.level, q.req, q.side, q.cls, q.races, q.giver or "",
                                    q.map or false, q.x or false, q.y or false, q.places }
            end
        end
        out.QUESTS[group] = rows
    end

    -- Every quest on the way to a listed one, outdoor lead-ins included.
    local raw = {}
    local function AddStep(id)
        if raw[id] ~= nil then return end
        raw[id] = false             -- guards against a loop in the data
        if NOT_AVAILABLE[id] or not Quest.Exists(id) then return end
        local races = Quest.requiredRaces(id) or 0
        local side = SideOf(races)
        local function Positive(t)
            local kept = {}
            for _, p in ipairs(Seq(t)) do
                if p > 0 then kept[#kept + 1] = p end
            end
            return kept
        end
        local all, any = Positive(Quest.preQuestGroup(id)), Positive(Quest.preQuestSingle(id))
        local giver, map, x, y, places = Starter(id, side)
        for _, p in ipairs(all) do AddStep(p) end
        for _, p in ipairs(any) do AddStep(p) end
        raw[id] = { name = Quest.name(id), level = Quest.questLevel(id) or 0, side = side, cls = Quest.requiredClasses(id) or 0,
                    races = RaceList(races, side), giver = giver, map = map, x = x, y = y, places = places,
                    all = all, any = any, alt = Positive(Quest.exclusiveTo(id)) }
    end
    for _, quests in pairs(found) do
        for _, q in ipairs(quests) do AddStep(q.id) end
    end
    -- The quest trees also follow lead-ins, through quests that aren't on their list.
    local walked, toWalk = {}, {}
    for _, quests in pairs(found) do
        for _, q in ipairs(quests) do toWalk[#toWalk + 1] = q.id end
    end
    while #toWalk > 0 do
        local id = table.remove(toWalk)
        if not walked[id] then
            walked[id] = true
            AddStep(id)
            local s = raw[id]
            for _, list in ipairs({ s and s.all or {}, s and s.any or {}, leads[id] or {} }) do
                for _, p in ipairs(list) do toWalk[#toWalk + 1] = p end
            end
        end
    end
    for id in pairs(walked) do
        local kept = {}
        for _, p in ipairs(leads[id] or {}) do
            if raw[p] then kept[#kept + 1] = p end
        end
        if kept[1] then out.LEADS[id] = kept end
    end
    local function Kept(list)
        local out2 = {}
        for _, p in ipairs(list) do
            if raw[p] then out2[#out2 + 1] = p end
        end
        return out2[1] and out2 or false
    end
    for id, s in pairs(raw) do
        if s then
            out.STEPS[id] = { s.name, s.level, s.side, s.cls, s.races, s.giver or "", s.map or false, s.x or false, s.y or false,
                              Kept(s.all), Kept(s.any), Kept(s.alt), s.places }
        end
    end
    return out
end

local data, failed

-- "ok", "missing" (not installed or switched off), "old" (a version we can't read) or "failed".
function Live.Status()
    local lib = LibQuestieDB
    if type(lib) ~= "table" then return "missing" end
    if failed then return "failed" end
    local called, fits = pcall(lib.RequireContract, CONTRACT)
    if not (called and fits) then return "old" end
    if not (lib.Quest and lib.Npc and lib.Object and lib.Item and lib.Enum and lib.Enum.factionRaceMasks) then return "old" end
    return "ok", lib
end

-- The lists, read the first time they're asked for. Nil if QuestieDB can't give them.
function Live.Data()
    if data then return data end
    if failed then return nil end
    local status, lib = Live.Status()
    if status ~= "ok" then return nil end
    local start = debugprofilestop and debugprofilestop()
    local ok, result = pcall(Build, lib)
    if not ok then
        failed = true
        ns.Log("QuestieDB: couldn't read the quest lists: " .. tostring(result))
        return nil
    end
    data = result
    Live.buildMs = start and (debugprofilestop() - start) or nil
    return data
end

-- Entrances QuestieDB doesn't list yet: the game's map id, x, y (public guide positions, so approximate).
local OWN_ENTRANCES = {
    drown = { 1434, 21.4, 27.9 }, krol = { 2548, 37.5, 37.5 }, alcaz = { 1445, 75, 15 },
    blackmaw = { 1447, 38.7, 33.4 }, shaper = { 1449, 48.1, 6.1 },
}
local MAP_TYPE_DUNGEON = 4

local function ZoneData()
    local status, lib = Live.Status()
    if status ~= "ok" or not (lib.Support and lib.Support.Get) then return nil end
    local ok, zone = pcall(lib.Support.Get, "ZoneDB")
    if not ok or type(zone) ~= "table" or type(zone.private) ~= "table" then return nil end
    return zone.private, lib
end

local liveMaps
local function AreaMaps(lib)
    if not liveMaps then
        local ok, maps = pcall(ZoneMaps, lib)
        liveMaps = ok and maps or {}
    end
    return liveMaps
end

-- Where a dungeon group's entrance is: map, x, y. which = 2 for a second door (Stratholme's Service Gate).
function Live.Entrance(group, which)
    local own = OWN_ENTRANCES[group]
    if own then return own[1], own[2], own[3] end
    local private, lib = ZoneData()
    local area = GROUPS[group] and GROUPS[group][1]
    local entry = private and area and type(private.dungeons) == "table" and private.dungeons[area]
    local spots = type(entry) == "table" and entry[4]
    local spot = type(spots) == "table" and (spots[which or 1] or spots[1])
    if type(spot) ~= "table" or type(spot[2]) ~= "number" or type(spot[3]) ~= "number" then return nil end
    local map = AreaMaps(lib)[spot[1]]
    if not map or map == 0 then return nil end
    return map, spot[2], spot[3]
end

-- The game's own inside map of a dungeon group, if it has one.
function Live.DungeonMap(group)
    local private, lib = ZoneData()
    if not private or not GROUPS[group] or not (C_Map and C_Map.GetMapInfo) then return nil end
    local maps = AreaMaps(lib)
    for _, area in ipairs(GROUPS[group]) do
        local map = maps[area]
        if map and map ~= 0 then
            local ok, info = pcall(C_Map.GetMapInfo, map)
            if ok and type(info) == "table" and info.mapType == MAP_TYPE_DUNGEON then return map end
        end
    end
    return nil
end

-- Forget what was read (the dev console, and tests).
function Live.Reset() data, failed, Live.buildMs, liveMaps = nil, nil, nil, nil end
