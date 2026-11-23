-- Every dungeon's bosses, for the Leveling tab's Bosses column. Encounter ids and names are the game's own
-- (Forever's public DungeonEncounter table, build 1.60.1.71037). main = counted in the total. extra =
-- optional or secret, shown as a bonus (+1). Rare spawns are left out on purpose.
-- Kills are kept per character, for good: if you've killed a boss, it counts. Nothing is sent to anyone.
local _, ns = ...

local B = {}
ns.Bosses = B

-- Each list is id, name, id, name...
B.LIST = {
    rfc = { main = {
            2732, "Oggleflint", 2733, "Taragaman the Hungerer", 2734, "Jergosh the Invoker", 2735, "Bazzalan" },
        extra = {} },
    hot = { main = {
            3493, "Faldrim Anvilmar", 3495, "Infurnus", 3494, "Plunder", 3496, "Durgen Dirgehammer" },
        extra = {} },
    rol = { main = {
            3353, "Witherfang", 3355, "The Butcher", 3412, "Bjork", 3354, "Rath'mael" },
        extra = {
            3357, "The Abandoned", 3411, "Viktor the Vile" } },
    wc = { main = {
            585, "Lady Anacondra", 586, "Lord Cobrahn", 587, "Kresh", 588, "Lord Pythas", 589, "Skum",
            590, "Lord Serpentis", 591, "Verdan the Everliving", 592, "Mutanus the Devourer" },
        extra = {} },
    dm = { main = {
            2741, "Rhahk'Zor", 2742, "Sneed", 2743, "Gilnid", 2744, "Captain Greenskin", 2745, "Mr. Smite",
            2746, "Cookie", 2747, "Edwin VanCleef" },
        extra = {} },
    sfk = { main = {
            2748, "Rethilgore", 2749, "Razorclaw the Butcher", 2750, "Baron Silverlaine",
            2751, "Commander Springvale", 2752, "Odo the Blindwatcher", 2753, "Fenrus the Devourer",
            2754, "Wolf Master Nandos", 2755, "Archmage Arugal" },
        extra = {} },
    bfd = { main = {
            2916, "Ghamoo-ra", 2915, "Lady Sarevess", 2914, "Geilhast", 2913, "Lorgus Jett", 2912, "Old Serra'kis",
            2911, "Twilight Lord Kelris", 2910, "Aku'mai" },
        extra = {} },
    stocks = { main = {
            2756, "Targorr the Dread", 2757, "Kam Deepfury", 2758, "Hamhock", 2759, "Dextren Ward",
            2760, "Bazil Thredd" },
        extra = {} },
    exc = { main = {
            3480, "Saltspine", 3481, "Shadetooth", 3482, "Relic Guardian" },
        extra = {
            3644, "Highland Horror" } },
    dal = { main = {
            3311, "Atrexis the Grave Knight", 3300, "Mana Devourer", 3298, "Arcane Anomaly", 3299, "Fel Ancient",
            3302, "Unstable Sentinel", 3303, "Shade of the Archmage" },
        extra = {
            3310, "Lyn the Ignored", 3301, "Mana Elemental", 3312, "Mana Wraith" } },
    gnomer = { main = {
            2768, "Grubbis", 2769, "Viscous Fallout", 2770, "Electrocutioner 6000", 2771, "Crowd Pummeler 9-60",
            2772, "Mekgineer Thermaplugg" },
        extra = {} },
    rfk = { main = {
            2773, "Roogug", 2774, "Aggem Thorncurse", 2775, "Death Speaker Jargba", 2776, "Overlord Ramtusk",
            2777, "Agathelos the Raging", 2778, "Charlga Razorflank" },
        extra = {} },
    smgy = { main = {
            444, "Interrogator Vishas", 2779, "Bloodmage Thalnos" },
        extra = {} },
    smlib = { main = {
            446, "Houndmaster Loksey", 447, "Arcanist Doan" },
        extra = {} },
    drown = { main = {
            3474, "Zul'Alai", 3475, "Var'Taka", 3476, "Captain Dreadrise", 3478, "Deathless Guardians",
            3511, "Primeval Elemental", 3479, "Min'loth the Serpent" },
        extra = {} },
    smarm = { main = {
            448, "Herod" },
        extra = {} },
    rfd = { main = {
            2780, "Tuten'kash", 2782, "Mordresh Fire Eye", 2784, "Glutton", 2785, "Amnennar the Coldbringer" },
        extra = {} },
    smcath = { main = {
            449, "High Inquisitor Fairbanks", 450, "High Inquisitor Whitemane" },
        extra = {} },
    krol = { main = {
            3450, "Slavecrusher Grox", 3452, "Twilight Commander Zarmok", 3453, "Handler Ashka", 3449, "Nar'gurk",
            3451, "Overseer Mugg" },
        extra = {} },
    ulda = { main = {
            547, "Revelosh", 548, "The Lost Dwarves", 549, "Ironaya", 1887, "Obsidian Sentinel",
            551, "Ancient Stone Keeper", 552, "Galgann Firehammer", 553, "Grimlok", 554, "Archaedas" },
        extra = {} },
    zf = { main = {
            593, "Hydromancer Velratha", 595, "Antu'sul", 596, "Theka the Martyr", 597, "Witch Doctor Zum'rah",
            598, "Nekrum Gutchewer", 599, "Shadowpriest Sezz'ziz", 600, "Chief Ukorz Sandscalp" },
        extra = {
            594, "Gahz'rilla" } },
    mara = { main = {
            422, "Noxxion", 423, "Razorlash", 427, "Tinkerer Gizlock", 424, "Lord Vyletongue",
            425, "Celebras the Cursed", 426, "Landslide", 428, "Rotgrip", 429, "Princess Theradras" },
        extra = {} },
    alcaz = { main = {
            3410, "Tidemistress Ca'zass", 3403, "Overseer Wrex", 3418, "Katerina the Cleaner", 3409, "Blazeroar",
            3415, "The Questioner" },
        extra = {} },
    st = { main = {
            3588, "Dreamscythe", 3587, "Weaver", 3585, "Hazzas", 3586, "Morphaz", 3589, "Jammal'an the Prophet",
            3583, "Avatar of Hakkar", 3584, "Shade of Eranikus" },
        extra = {
            3582, "Atal'alarion" } },
    brd = { main = {
            227, "High Interrogator Gerstahn", 228, "Lord Roccor", 229, "Houndmaster Grebmar", 230, "Ring of Law",
            231, "Pyromancer Loregrain", 232, "Lord Incendius", 235, "Bael'Gar", 236, "General Angerforge",
            237, "Golem Lord Argelmach", 239, "Phalanx", 242, "Ambassador Flamelash", 243, "The Seven",
            244, "Magmus", 2790, "Emperor Dagran Thaurissan" },
        extra = {
            233, "Warder Stilgiss", 234, "Fineous Darkvire", 238, "Hurley Blackbreath", 240, "Ribbly Screwspigot",
            241, "Plugger Spazzring", 2791, "The Vault", 2789, "Princess Moira Bronzebeard" } },
    dme = { main = {
            343, "Zevrim Thornhoof", 344, "Hydrospawn", 345, "Lethtendris", 346, "Alzzin the Wildshaper" },
        extra = {
            2792, "Pusillin" } },
    lbrs = { main = {
            267, "Highlord Omokk", 268, "Shadow Hunter Vosh'gajin", 269, "War Master Voone",
            270, "Mother Smolderweb", 272, "Quartermaster Zigris", 273, "Gizrul the Slavener", 274, "Halycon",
            275, "Overlord Wyrmthalak" },
        extra = {
            271, "Urok Doomhowl" } },
    blackmaw = { main = {
            3315, "Withermaw", 3322, "Bonesnout the Unbroken", 3316, "Impaan the Imprisoner",
            3327, "Elder Shaman Bloodmane", 3323, "Blackmaw Behemoth", 3334, "Varrox Bleakhoof" },
        extra = {
            3336, "Unbound Spirit" } },
    dmw = { main = {
            350, "Tendris Warpwood", 347, "Illyanna Ravenoak", 348, "Magister Kalendris", 349, "Immol'thar",
            361, "Prince Tortheldrin" },
        extra = {
            2793, "Lord Hel'nurath" } },
    dmn = { main = {
            362, "Guard Mol'dar", 363, "Stomper Kreeg", 364, "Guard Fengus", 365, "Guard Slip'kik",
            366, "Captain Kromcrush", 367, "Cho'Rush the Observer", 368, "King Gordok" },
        extra = {} },
    scholo = { main = {
            2804, "Jandice Barov", 2811, "Rattlegore", 2809, "Marduk Blackpool", 2813, "Vectus",
            2810, "Ras Frostwhisperer", 2803, "Instructor Malicia", 2802, "Doctor Theolen Krastinov",
            2808, "Lorekeeper Polkelt", 2812, "The Ravenian", 2807, "Lord Alexei Barov",
            2806, "Lady Illucia Barov", 2801, "Darkmaster Gandling" },
        extra = {
            2805, "Kirtonos", 3055, "Kormok" } },
    strat = { main = {
            474, "Timmy the Cruel", 476, "Malor the Zealous", 475, "Cannon Master Willey",
            477, "Archivist Galford", 478, "Balnazzar", 472, "The Unforgiven" },
        extra = {
            2796, "Crimson Hammersmith", 2798, "Postmaster Malown" } },
    stratsg = { main = {
            479, "Baroness Anastari", 480, "Nerub'enkan", 481, "Maleki the Pallid", 482, "Magistrate Barthilas",
            483, "Ramstein the Gorger", 484, "Baron Rivendare" },
        extra = {
            2795, "Black Guard Swordsmith" } },
    shaper = { main = {
            3498, "Titanosaur", 3500, "Thunderhoof", 3501, "Venomridge", 3507, "Direhorn Matriarch",
            3502, "Nanaya" },
        extra = {
            3499, "Ravasaur Hunters", 3503, "Cinder", 3504, "King Op", 3597, "Snowtalon", 3505, "Bolt",
            3600, "Vitrix" } },
    ubrs = { main = {
            3062, "Pyroguard Emberseer", 3063, "Warchief Rend Blackhand", 3068, "The Beast",
            3069, "General Drakkisath" },
        extra = {
            3070, "Lord Valthalak" } },
}

-- The same boss under another difficulty's id.
local ALIAS = {
    [2761] = 2916, [2762] = 2915, [2763] = 2914, [2764] = 2913, [2765] = 2912, [2766] = 2911, [2767] = 2910,
    [492] = 3583, [488] = 3589, [486] = 3588, [487] = 3587, [490] = 3586, [491] = 3585, [493] = 3584,
    [2814] = 3582,
}

local KNOWN = {}
for _, d in pairs(B.LIST) do
    for _, part in ipairs({ d.main, d.extra }) do
        for i = 1, #part, 2 do KNOWN[part[i]] = true end
    end
end

-- This character's kills: encounter id -> the name the game gave it.
-- Nil if there's nowhere safe to keep it yet. The id is kept from login, in case the game hides it later.
local myGuid
local function MyGuid()
    if not myGuid then myGuid = ns.Public(UnitGUID and UnitGUID("player"), "string") end
    return myGuid
end
ns.OnEvent("PLAYER_LOGIN", MyGuid)

function B.Kills()
    if not ns.db then return nil end
    local guid = MyGuid()
    if not guid then return nil end
    if type(ns.db.bossKills) ~= "table" then ns.db.bossKills = {} end
    local mine = ns.db.bossKills[guid]
    if type(mine) ~= "table" then
        mine = {}
        ns.db.bossKills[guid] = mine
    end
    return mine
end

-- True if this was a new tick.
function B.Record(id, name)
    id = ALIAS[id] or id
    if not KNOWN[id] then return false end
    local kills = B.Kills()
    if not kills or kills[id] then return false end
    kills[id] = type(name) == "string" and name or true
    if ns.UI and ns.UI.Dirty then ns.UI.Dirty() end
    return true
end

-- Forget this character's kills (the dev console).
function B.Clear()
    if ns.db and type(ns.db.bossKills) == "table" then
        local guid = MyGuid()
        if guid then ns.db.bossKills[guid] = nil end
    end
    if ns.UI and ns.UI.Dirty then ns.UI.Dirty() end
end

ns.OnEvent("ENCOUNTER_END", function(id, name, _, _, success)
    success = ns.Public(success)
    if success ~= 1 and success ~= true then return end
    id = ns.Public(id, "number")
    if id then B.Record(id, ns.Public(name, "string")) end
end)

local function Part(list, kills)
    local rows, done = {}, 0
    for i = 1, #list, 2 do
        local got = kills[list[i]]
        if got then done = done + 1 end
        rows[#rows + 1] = { id = list[i], name = type(got) == "string" and got or list[i + 1], done = got ~= nil }
    end
    return rows, done
end

-- Main bosses killed, how many main bosses, bonus kills.
function B.Count(key)
    local d = B.LIST[key]
    if not d then return 0, 0, 0 end
    local kills = B.Kills() or {}
    local main, done = Part(d.main, kills)
    local _, bonus = Part(d.extra, kills)
    return done, #main, bonus
end

-- The rows for the hover: main bosses, then the optional and secret ones.
function B.Rows(key)
    local d = B.LIST[key]
    if not d then return {}, {} end
    local kills = B.Kills() or {}
    return (Part(d.main, kills)), (Part(d.extra, kills))
end
