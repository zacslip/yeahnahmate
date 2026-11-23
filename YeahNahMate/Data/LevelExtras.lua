-- The Leveling tab's guide pages: the Cozy Sleeping Bag chain, dungeon keys, and riding. Ids are the game's.
-- Positions are read live from QuestieDB (Data/LiveQuests.lua), so without it the steps still read and tick
-- off, but have no map pin. Progress comes from the game: quests handed in, items held, spells known.
-- Where guides disagree, the wording only says what they agree on.
local _, ns = ...

local E = {}
ns.LevelExtras = E

local function Side()
    local f = ns.Dungeons.Faction()
    return f == "Horde" and "H" or "A"
end

local function ForSide(v)
    if type(v) == "table" and (v.A or v.H) then return v[Side()] end
    return v
end

local function AnyDone(ids)
    for _, id in ipairs(ids or {}) do
        if ns.LevelGuide.TurnedIn(id) then return true end
    end
    return false
end

local function NpcPlace(id, name)
    local map, x, y = ns.LiveQuests.NpcSpot(id)
    if not map then return nil end
    return { id = "npc:" .. id, name = name or ns.LiveQuests.NpcName(id) or "?", map = map, x = x, y = y }
end

local function ObjectPlace(id, name)
    local map, x, y = ns.LiveQuests.ObjectSpot(id)
    if not map then return nil end
    return { id = "object:" .. id, name = name, map = map, x = x, y = y }
end

---------------------------------------------------------------------------------------------------
-- The Cozy Sleeping Bag: six quests. Each faction starts on its own continent and hands in on the other.

local REMAINS = "Burned-Out Remains"
local PLANK = "Nailed Plank"
local SLEEPING = {
    { quest = { A = 79008, H = 79007 }, name = "... and that note you found",
      start = { A = { 415107, REMAINS }, H = { 415106, REMAINS } },
      finish = { A = { 415106, REMAINS }, H = { 415107, REMAINS } },
      tip = { A = "Click the remains at Alexston Farmstead, Westfall. Hand in at the burned tower in The Barrens, south of Camp Taurajo.",
              H = "Click the remains in the burned tower in The Barrens, south of Camp Taurajo. Hand in at Alexston Farmstead, Westfall." },
      reward = "Swiftness Potion and a Lesser Troll's Blood." },
    { quest = 79192, name = "Stepping Stones",
      start = { A = { 417072, PLANK }, H = { 424010, PLANK } }, finish = { 424005, "Pocket Litter" },
      tip = "Take it from the Nailed Plank by the remains. Hand in at the Pocket Litter, abandoned camp in Stonetalon Mountains.",
      reward = "12-slot bag, Flint and Tinder, Simple Wood, and a Mining Pick or Farmer's Shovel." },
    { quest = 79980, name = "Scramble",
      start = { 424005, "Pocket Litter" }, finish = { 424012, "Mound of Dirt" },
      tip = "Climb the hill north of the camp and jump the gap to the Mound of Dirt. Don't fall.",
      reward = "Student Fodder, ammo, and a Silver Star, Moonsight Rifle or Precision Bow." },
    { quest = 79974, name = "Wet Job",
      start = { 424012, "Mound of Dirt" }, finish = { 424007, "Carved Figurine" },
      tip = "Stonewrought Dam, Loch Modan: drop from the middle of the dam onto the carved heads. Guards patrol here.",
      reward = "Hickory Pipe and Rumsey Rum Light." },
    { quest = 79975, name = "Eagle's Fist",
      start = { 424007, "Carved Figurine" }, finish = { 406918, "Messenger Bag" },
      tip = "Start at the fallen cart at 87, 49 in Hillsbrad and climb onto Thoradin's Wall. The pin marks the bag, just over the Arathi border." },
    { quest = 79976, name = "This Must Be The Place",
      start = { 406918, "Messenger Bag" }, finish = { 424006, "Hastily Rolled-Up Satchel" },
      tip = "Click the Hastily Rolled-Up Satchel underneath the Messenger Bag. That's the one that gives you the bag.",
      reward = "Cozy Sleeping Bag and Student Fodder." },
}

local function Spot(v)
    v = v[1] and v or ForSide(v)
    return ObjectPlace(v[1], v[2])
end

-- The steps in order, how many are done. A later quest done means the earlier ones are too.
function E.SleepingBag()
    local out, last = {}, 0
    for i, s in ipairs(SLEEPING) do
        if ns.LevelGuide.TurnedIn(ForSide(s.quest)) then last = i end
    end
    local nextShown = false
    for i, s in ipairs(SLEEPING) do
        local id = ForSide(s.quest)
        local state
        if i <= last then state = "done"
        elseif ns.Questions.InMyLog(id) then state = "log"
        elseif not nextShown then state = "next" end
        if state == "log" or state == "next" then nextShown = true end
        local where = state == "log" and s.finish or s.start
        local tip = { ForSide(s.tip) }
        if s.reward then tip[#tip + 1] = string.format(ns.L.GUIDE_REWARD, s.reward) end
        out[i] = { key = "sleep" .. i, name = i .. ". " .. s.name, state = state, detail = ForSide(s.tip),
                   place = state ~= "done" and Spot(where) or nil, tip = tip }
    end
    return out, last, #SLEEPING
end

---------------------------------------------------------------------------------------------------
-- Keys and attunements: what opens what, and how to get it. Lockpicking from the game's lock data.

E.KEYS = {
    { item = 6893, name = "Workshop Key", opens = "Gnomeregan: Workshop doors", dungeon = "gnomer", lock = 150,
      how = "Drops from Electrocutioner 6000 in Gnomeregan." },
    { item = 7146, name = "The Scarlet Key", opens = "Scarlet Monastery: Armory and Cathedral", dungeon = "smlib", lock = 175,
      how = "In Doan's Strongbox, next to Arcanist Doan in the Library wing." },
    { item = 277507, name = "Dalaran Sewer Key", opens = "City of Dalaran (one per group)", quests = { 92458, 96984 },
      npc = { A = 247264, H = 2410 },
      how = { A = "An Alarming Request from Emissary Jacques, Southshore, then Heart of Disruption at the sewer gate.",
              H = "Start with Magus Wordeen Voidglare, Tarren Mill. The chain ends with Heart of Disruption at the sewer gate." } },
    { item = 9240, name = "Mallet of Zul'Farrak", opens = "Zul'Farrak gong: summons Gahz'rilla (optional)", npc = 7996,
      how = "Get the Sacred Mallet from Qiaga the Keeper in The Hinterlands, then use it at the altar atop Jintha'Alor." },
    { item = 17191, name = "Scepter of Celebras", opens = "Maraudon: shortcut to the inner falls", quests = { 7046 }, npc = 13697,
      how = "Legends of Maraudon from Cavindra in Desolace, then The Scepter of Celebras." },
    { item = 11000, name = "Shadowforge Key", opens = "Blackrock Depths: Shadowforge gates", quests = { 3802 }, npc = 8888, lock = 250,
      how = "Dark Iron Legacy from Franclorn Forgewright, Burning Steppes." },
    { item = 11140, name = "Prison Cell Key", opens = "Blackrock Depths: Detention Block cells", dungeon = "brd",
      how = "Drops from High Interrogator Gerstahn, but not every time." },
    { item = 12344, name = "Seal of Ascension", opens = "Upper Blackrock Spire (one per group)", quests = { 4743 }, dungeon = "lbrs",
      how = "From the Scarshield Infiltrator (Vaelan) in Lower Blackrock Spire. Guides aren't sure Forever's door still needs it." },
    { item = 18249, name = "Crescent Key", opens = "Dire Maul: West and North", dungeon = "dme", lock = 300,
      how = "Drops from Pusillin in Dire Maul East." },
    { item = 13704, name = "Skeleton Key", opens = "Scholomance (one per group)", quests = { 5505, 5511 },
      npc = { A = 11056, H = 10837 }, lock = 280,
      how = { A = "A long chain ending with The Key to Scholomance from Alchemist Arbington, Western Plaguelands.",
              H = "A long chain ending with The Key to Scholomance from High Executor Derrington, Tirisfal Glades." } },
    { item = 12382, name = "Key to the City", opens = "Stratholme: Service Gate", dungeon = "strat", lock = 300,
      how = "Drops from Magistrate Barthilas in Stratholme." },
    { item = 16309, name = "Drakefire Amulet", opens = "Onyxia's Lair (raid)", quests = { 6502, 6602 },
      npc = { A = 9562, H = 9077 },
      how = { A = "A long chain from Helendis Riverhorn, Burning Steppes, ending with Haleh in Winterspring.",
              H = "A long chain from Warlord Goretooth in Kargath, Badlands, ending with Rexxar in Desolace." } },
}

local function HasItem(id)
    local count = (C_Item and C_Item.GetItemCount) or GetItemCount
    if not count then return false end
    local ok, n = pcall(count, id, true)
    n = ok and ns.Public(n, "number") or 0
    return n > 0
end

function E.Keys()
    local out, have = {}, 0
    for _, k in ipairs(E.KEYS) do
        local got = HasItem(k.item) or AnyDone(k.quests)
        if got then have = have + 1 end
        local how = ForSide(k.how)
        local place
        local npc = ForSide(k.npc)
        if npc then place = NpcPlace(npc) end
        if not place and k.dungeon then place = ns.LevelGuide.Entrance(k.dungeon) end
        local tip = { k.opens, how }
        if k.lock then tip[#tip + 1] = string.format(ns.L.GUIDE_KEY_LOCK, k.lock) end
        out[#out + 1] = { key = "key" .. k.item, name = k.name .. ns.GREY .. "  " .. k.opens .. "|r", tipName = k.name,
                          state = got and "done" or nil, stateText = got and ns.L.GUIDE_HAVE or nil,
                          detail = how, place = not got and place or nil, tip = tip }
    end
    return out, have, #E.KEYS
end

---------------------------------------------------------------------------------------------------
-- Mounts and riding: for my race and class. Forever's own riding spells (as in Milestones.lua).

local APPRENTICE = { 33388, 824, 825, 826, 828, 10861, 10906, 10907, 18995, 1285849 }
local JOURNEYMAN = 33391
-- Riding trainer, mount vendor, and where. map = open this zone when the data has no exact spot.
E.RACES = {
    Human = { trainer = 4732, vendor = 384, where = "Eastvale Logging Camp, Elwynn Forest" },
    Dwarf = { trainer = 4772, vendor = 1261, where = "Amberstill Ranch, Dun Morogh", map = 1426 },
    Gnome = { trainer = 7954, vendor = 7955, where = "Steelgrill's Depot, near Kharanos, Dun Morogh", map = 1426 },
    NightElf = { trainer = 4753, vendor = 4730, where = "Cenarion Enclave, Darnassus" },
    Orc = { trainer = 4752, vendor = 3362, where = "Valley of Honor, Orgrimmar" },
    Scourge = { trainer = 4773, vendor = 4731, where = "Brill, Tirisfal Glades" },
    Tauren = { trainer = 3690, vendor = 3685, where = "Bloodhoof Village, Mulgore" },
    Troll = { trainer = 7953, vendor = 7952, where = "Sen'jin Village, Durotar" },
    Skyborne = { trainer = 265756, vendor = 265756, where = "Fairweather Stables, Zephras Isle" },
}
E.NPC_NAMES = {
    [4732] = "Randal Hunter", [384] = "Katie Hunter", [4772] = "Ultham Ironhorn", [1261] = "Veron Amberstill",
    [7954] = "Binjy Featherwhistle", [7955] = "Milli Featherwhistle", [4753] = "Jartsam", [4730] = "Lelanai",
    [4752] = "Kildar", [3362] = "Ogunaro Wolfrunner", [4773] = "Velma Warnam", [4731] = "Zachariah Post",
    [3690] = "Kar Stormsinger", [3685] = "Harb Clawhoof", [7953] = "Xar'Ti", [7952] = "Zjolnir",
    [265756] = "Genn Fairweather",
}

local function Knows(id)
    local known = (C_SpellBook and C_SpellBook.IsSpellKnown) or IsSpellKnown
    if not known then return false end
    local ok, yes = pcall(known, id)
    return ok and yes == true
end

local function KnowsAny(ids)
    for _, id in ipairs(ids) do
        if Knows(id) then return true end
    end
    return false
end

-- The class mount quest at level 40, if my class has one: name, quests that finish it, who to see.
local function ClassMount(class, race)
    if class == "WARLOCK" then
        return { name = "Summon Felsteed", quests = { 4490 }, npc = 6251,
                 how = "Your warlock trainer starts it, and it leads to Strahad Farsan in Ratchet." }
    end
    if class ~= "PALADIN" then return nil end
    if Side() == "A" then
        return { name = "The Tome of Nobility", quests = { 1661 }, npc = race == "Human" and 6171 or 6179,
                 how = "Start with your paladin trainer in Stormwind or Ironforge. It ends with Duthorian Rall in Stormwind." }
    end
    return { name = "A Paladin's Steed", quests = { 94971 }, npc = race == "Scourge" and 260093 or 246344,
             how = "Report to Danitha, then A Paladin's Steed with Danitha Morr at Bandarion Keep, Tirisfal Glades." }
end

-- The checklist for my level, race and class.
function E.Mounts(level)
    local L = ns.L
    local _, race = UnitRace("player")
    local _, class = UnitClass("player")
    local r = E.RACES[race]
    local out = {}
    local function Add(item) out[#out + 1] = item; item.key = "mount" .. #out end
    local function WhenReady(done, need)
        if done then return "done", L.GUIDE_DONE end
        if level >= need then return "next", L.GUIDE_NEXT end
        return nil, string.format(L.GUIDE_FROM_LEVEL, need)
    end
    local function Npc(id) return id and NpcPlace(id, E.NPC_NAMES[id]) or nil end

    local journeyman = Knows(JOURNEYMAN)
    local apprentice = journeyman or KnowsAny(APPRENTICE)
    local trainer = r and E.NPC_NAMES[r.trainer]
    local mount = ClassMount(class, race)
    local aState, aText = WhenReady(apprentice, 40)
    Add({ name = L.GUIDE_MOUNT_APPRENTICE, state = aState, stateText = aText, zone = r and r.map,
          place = not apprentice and r and Npc(r.trainer) or nil,
          detail = mount and L.GUIDE_MOUNT_APPRENTICE_CLASS
              or (r and string.format(L.GUIDE_MOUNT_APPRENTICE_TEXT, trainer, r.where) or L.GUIDE_MOUNT_NO_RACE),
          tip = { L.GUIDE_MOUNT_APPRENTICE_TIP, L.GUIDE_MOUNT_DISCOUNT } })
    if mount then
        local done = AnyDone(mount.quests)
        local state, text = WhenReady(done, 40)
        Add({ name = mount.name, state = state, stateText = text, place = not done and NpcPlace(mount.npc) or nil,
              detail = mount.how, tip = { mount.how } })
    end
    if r then
        Add({ name = string.format(L.GUIDE_MOUNT_VENDOR, E.NPC_NAMES[r.vendor]), zone = r.map, place = Npc(r.vendor),
              detail = string.format(L.GUIDE_MOUNT_VENDOR_TEXT, r.where), tip = { L.GUIDE_MOUNT_VENDOR_TIP, L.GUIDE_MOUNT_DISCOUNT } })
    end
    local jState, jText = WhenReady(journeyman, 60)
    Add({ name = L.GUIDE_MOUNT_JOURNEYMAN, state = jState, stateText = jText, zone = r and r.map,
          place = not journeyman and r and Npc(r.trainer) or nil,
          detail = r and string.format(L.GUIDE_MOUNT_JOURNEYMAN_TEXT, trainer) or L.GUIDE_MOUNT_NO_RACE,
          tip = { L.GUIDE_MOUNT_JOURNEYMAN_TIP, L.GUIDE_MOUNT_DISCOUNT } })
    Add({ name = L.GUIDE_MOUNT_EPIC, zone = r and r.map, place = r and Npc(r.vendor) or nil,
          stateText = level < 60 and string.format(L.GUIDE_FROM_LEVEL, 60) or nil,
          detail = mount and L.GUIDE_MOUNT_EPIC_CLASS or L.GUIDE_MOUNT_EPIC_TEXT, tip = { L.GUIDE_MOUNT_EPIC_TEXT } })
    return out
end
