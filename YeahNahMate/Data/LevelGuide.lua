-- The leveling guide's data and the lists it shows. Our own short tables of game facts.
-- Zones: name, familiar level range, then the levels most of that faction's quests sit at
-- ({ Alliance }, { Horde }; false = not suggested for that faction).
local _, ns = ...

local G = {}
ns.LevelGuide = G

-- Quest lists come live from QuestieDB (Data/LiveQuests.lua), read when asked for.
-- Without it the guide still works and just has no quest lists.
local QUEST_DATA = { QUESTS = "QUESTS", QUEST_VARIANTS = "VARIANTS", QUEST_EARLIER = "EARLIER", QUEST_STEPS = "STEPS" }
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
            local row = seen[q[2]]
            if not row then
                -- A quest both factions can take may have a quest giver in each one's city.
                local own = q[12] and me.side and q[12][me.side]
                local giver = own and own[1] or q[8]
                row = { id = q[1], name = q[2], level = q[3], req = q[4], giver = giver ~= "" and giver or nil,
                        map = own and own[2] or q[9] or nil, x = own and own[3] or q[10] or nil,
                        y = own and own[4] or q[11] or nil, ids = {} }
                seen[q[2]] = row
                list[#list + 1] = row
            end
            row.ids[#row.ids + 1] = q[1]
            for _, id in ipairs(G.QUEST_VARIANTS and G.QUEST_VARIANTS[q[1]] or {}) do
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
        if not (G.QUEST_EARLIER and G.QUEST_EARLIER[id]) and StepDone(id) then return "done" end
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
        if not (G.QUEST_EARLIER and G.QUEST_EARLIER[id]) and StepForMe(me, id) then
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

-- Zones my faction should see at this level: the ones at their best for me first, then nearest.
function G.Zones(level)
    local mine = ns.Dungeons.Faction()
    local list = {}
    for _, z in ipairs(G.ZONES) do
        local band
        if mine == "Alliance" then band = z[4] elseif mine == "Horde" then band = z[5] else band = z[4] or z[5] end
        if band and level >= z[2] and level <= z[3] then
            list[#list + 1] = { name = z[1], min = z[2], max = z[3], bestMin = band[1], bestMax = band[2],
                                best = level >= band[1] and level <= band[2],
                                away = math.abs(level - (band[1] + band[2]) / 2) }
        end
    end
    table.sort(list, function(a, b)
        if a.best ~= b.best then return a.best end
        if a.away ~= b.away then return a.away < b.away end
        return a.name < b.name
    end)
    return list
end

-- Dungeons in range for my level and faction: ready ones first, closest to my level on top, then
-- the ones whose boss is still a tough fight.
function G.Dungeons(level)
    local mine = ns.Dungeons.Faction()
    local list = {}
    for _, row in ipairs(ns.Dungeons.MyList()) do
        if level >= row[3] and level <= row[4] then
            local d, info = ns.Dungeons.BY_KEY[row[1]], G.DUNGEONS[row[1]] or {}
            local tag, note = info.tag, info[mine] or info.note
            if info.enemy and mine and info.enemy ~= mine then tag = "enemy" end
            list[#list + 1] = { key = d.key, name = d.name, min = d.min, max = d.max, boss = d.boss, best = d.best,
                                ready = level >= d.best, where = info.where, top = info.top, tag = tag, note = note,
                                enemy = tag == "enemy" and info.enemy or nil }
        end
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
