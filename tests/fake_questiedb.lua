-- A tiny stand-in for QuestieDB's public API, for the leveling guide's tests. Made-up rows shaped like
-- the real ones: none of QuestieDB's data lives in this repository.
-- opts.old = a version we can't read, opts.broken = reading it raises an error.
function FakeQuestieDB(opts)
    opts = opts or {}
    local ALLIANCE, HORDE = 77 + 2 ^ 32, 178 + 2 ^ 33
    local UNDERCITY, STORMWIND, IRONFORGE, BLUFF, MOROGH = 1497, 1519, 1537, 1638, 1

    local NPCS = {
        [101] = { "Varimathras", { [UNDERCITY] = { { 56.2, 92.2 } } }, "H" },
        [102] = { "Andrew Brownell", { [UNDERCITY] = { { 74.0, 33.3 } } }, "H" },
        [103] = { "Alliance Priest", { [STORMWIND] = { { 40.0, 30.0 } } }, "A" },
        [104] = { "Anastasia Hartwell", { [UNDERCITY] = { { 85.1, 10.0 } } }, "H" },
        [105] = { "Bink", { [IRONFORGE] = { { 27.2, 8.3 } } }, "A" },
        [106] = { "Someone Inside", nil, "AH" },
        [107] = { "Bluff Elder", { [BLUFF] = { { 75.0, 31.0 } } }, "H" },
        [108] = { "Ozzie Togglevolt", { [MOROGH] = { { 45.9, 49.4 } } }, "A" },
        [258964] = { "A New Boss", nil, "" },
    }

    local function Q(name, level, req, zone, races, cls, starter, single, objectives)
        return { name = name, questLevel = level, requiredLevel = req, zoneOrSort = zone, requiredRaces = races,
                 requiredClasses = cls, specialFlags = 0, startedBy = starter and { starter } or nil,
                 preQuestSingle = single, objectives = objectives }
    end
    local QUESTS = {
        [6521] = Q("An Unholy Alliance", 36, 28, 722, HORDE, 0, { 101 }, { 6522 }),
        [6522] = Q("An Unholy Alliance", 36, 28, 722, HORDE, 0, { 101 }),
        [3341] = Q("Bring the End", 42, 37, 722, HORDE, 0, { 102 }),
        [3636] = Q("Bring the Light", 42, 37, 722, ALLIANCE, 0, { 103 }),
        [3342] = Q("Starts Inside", 40, 35, 722, HORDE, 0, { 106 }),
        [96001] = Q("Skyborne Errand", 40, 35, 722, 2 ^ 33, 0, { 101 }),
        [96002] = Q("Skyborne Errand", 40, 35, 722, 2 ^ 32, 0, { 103 }),
        [1048] = Q("Into The Scarlet Monastery", 42, 33, 796, HORDE, 0, { 101 }),
        [386] = Q("What Comes Around", 25, 20, 717, ALLIANCE, 0, { 103 }),
        [2278] = Q("The Platinum Discs", 47, 40, 1337, HORDE, 0, { 101 }),
        [2280] = Q("The Platinum Discs", 47, 40, 1337, 0, 0, { 101 }),
        [1144] = Q("Elemental Aid", 30, 25, 491, 0, 64, { 107 }),
        [1838] = Q("Brutal Armor", 30, 25, 491, 0, 1, { 107 }),
        [5166] = Q("Just Compensation", 60, 55, 2017, 0, 0, { 107 }),   -- a turn-in, always left out
        [7668] = Q("Not In The Game", 60, 55, 2057, 0, 0, { 107 }),     -- never available
        [9901] = Q("Rite of Vision", 30, 25, 2100, 0, 0, { 107 }),      -- far below Maraudon's levels
        [5045] = Q("Nara Wildmane", 20, 15, 718, HORDE, 0, { 107 }, { 5046 }),
        [5046] = Q("Chain Middle", 18, 15, 215, HORDE, 0, { 107 }, { 5047 }),
        [5047] = Q("Chain Start", 16, 15, 215, HORDE, 0, { 107 }),
        [2861] = Q("Tabetha's Task", 46, 40, 1176, 0, 0, { 105, 104 }),
        [2926] = Q("Gnogaine", 27, 20, 721, ALLIANCE, 0, { 108 }),
        [97000] = Q("Boss Hunt", 44, 38, 400, 0, 0, { 107 }, nil, { { { 258964 } } }),
        [9950] = Q("Call of Earth", 4, 4, 215, HORDE, 64, { 107 }),             -- class quests, out in the world
        [9951] = Q("Call of Fire", 10, 10, 215, HORDE, 64, { 107 }, { 9950 }),
        [9952] = Q("Call of Water", 20, 20, 215, ALLIANCE, 64, { 103 }),        -- the other faction's
        [9953] = Q("Warrior's Trial", 10, 10, 215, HORDE, 1, { 107 }),          -- another class's
        [9954] = Q("Everyone's Errand", 12, 10, 215, HORDE, 1503, { 107 }),     -- names every class: not a class quest
        [9955] = Q("Daily Totem", 15, 15, 215, HORDE, 64, { 107 }),             -- repeatable: left out
    }
    QUESTS[9955].specialFlags = 1
    QUESTS[3343] = Q("Bring the End Again", 43, 37, 722, HORDE, 0, { 102 }, { 3341 })    -- a chain inside a dungeon
    QUESTS[9949] = Q("Word From The Elder", 3, 1, -82, HORDE, 64, { 107 })       -- an optional lead-in to Call of Earth
    QUESTS[9949].breadcrumbForQuestId = 9950
    QUESTS[9956] = Q("Raid Turn-in", 60, 60, 1977, 0, 64, { 107 })               -- endgame gear: not a class quest
    QUESTS[9957] = Q("Shaman Capstone", 60, 58, -82, HORDE, 64, { 107 })         -- level 60, but in the class's category
    QUESTS[9958] = Q("Totem Smithing", 30, 25, 215, 0, 64, { 107 })              -- needs a profession
    QUESTS[9958].requiredSkill = { 164, 100 }
    QUESTS[9959] = Q("Guild Recipe", 30, 25, -121, 0, 64, { 107 })               -- a profession's category
    for i = 1, 14 do    -- enough class quests to need scrolling
        QUESTS[9960 + i] = Q("Shaman Lesson " .. i, 20 + i, 20, 215, HORDE, 64, { 107 })
    end

    local function Entity(rows, fields)
        local e = {}
        for _, f in ipairs(fields) do
            e[f] = function(id) return rows[id] and rows[id][f] end
        end
        e.Exists = function(id) return rows[id] ~= nil end
        e.GetAllIds = function()
            if opts.broken then error("database fell over") end
            local ids = {}
            for id in pairs(rows) do ids[#ids + 1] = id end
            table.sort(ids)
            return ids
        end
        return e
    end

    local npcRows = {}
    for id, n in pairs(NPCS) do npcRows[id] = { name = n[1], spawns = n[2], friendlyToFaction = n[3] } end
    local maps = "return {\n[1497] = 1458,\n[1519] = 1453,\n[1537] = 1455,\n[1638] = 1456,\n[1] = 1426,\n}"
    return {
        RequireContract = function(n)
            if opts.old then return false, "QuestieDB contract mismatch" end
            return n == 4
        end,
        Quest = Entity(QUESTS, { "name", "questLevel", "requiredLevel", "zoneOrSort", "requiredRaces", "requiredClasses",
                                 "specialFlags", "startedBy", "preQuestGroup", "preQuestSingle", "exclusiveTo", "objectives",
                                 "nextQuestInChain", "breadcrumbForQuestId", "requiredSkill" }),
        Npc = Entity(npcRows, { "name", "spawns", "friendlyToFaction" }),
        Object = Entity({}, { "name", "spawns" }),
        Item = Entity({}, { "name", "npcDrops" }),
        Enum = { factionRaceMasks = { Alliance = ALLIANCE, Horde = HORDE }, raceMaskById = { [95] = 2 ^ 32, [96] = 2 ^ 33 } },
        Support = { Get = function() return { private = { areaIdToUiMapId = maps } } end },
    }
end
