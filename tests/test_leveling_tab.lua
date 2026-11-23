-- The Settings gear and the combined Leveling / Raids tab.
math.randomseed(24)
YeahNahMateDB = nil
dofile("tests/fake_questiedb.lua")
LibQuestieDB = nil
local ns = LoadAddon("YeahNahMate", "YeahNahMate")
LOGGED_IN = true
FireEvent("PLAYER_LOGIN")
Tick(3)
ns.settings.sharePosition, ns.settings.shareProfessions = false, false
local UI, L = ns.UI, ns.L

UI.Open("home")
Tick(1)

-- Find the tab by what it says.
local function TabNamed(text)
    for _, o in ipairs(CREATED) do
        if o.sel and o.GetText and o:GetText() == text then return o end
    end
end
local function Page()
    for _, o in ipairs(CREATED) do if o.viewButtons and o.soon then return o end end
end

-- Settings: no tab now, the gear opens it and a second click goes back.
check(TabNamed(L.TAB_SETTINGS) == nil, "Settings isn't in the tab row")
local gear = UI.settingsButton
check(gear ~= nil and gear:IsShown(), "the gear is in the header")
UI.Select("roster")
gear:Click()
Tick(1)
local settingsShown = false
for _, o in ipairs(CREATED) do if o.memory and o:IsShown() then settingsShown = true end end
check(settingsShown and gear.sel:IsShown(), "the gear opens Settings and shows it's open")
gear:Click()
Tick(1)
check(not gear.sel:IsShown() and TabNamed(L.TAB_ROSTER).sel:IsShown(), "a second click goes back to the page I was on")
UI.Open("settings")
Tick(1)
check(gear.sel:IsShown(), "UI.Open('settings') still works")

-- Before 60: the tab says Leveling and opens on Zones.
FAKE.level = 40
UI.Open("leveling")
Tick(1)
local tab = TabNamed(L.TAB_LEVELING)
local p = Page()
local zonesBtn, dungeonsBtn, raidBtn = p.viewButtons.zones, p.viewButtons.dungeons, p.viewButtons.raids
-- Exactly this view's page is open and exactly its button is marked.
local function Showing(key)
    for k, panel in pairs(p.panels) do
        if panel:IsShown() ~= (k == key) or p.viewButtons[k].viewSel:IsShown() ~= (k == key) then return false end
    end
    return p.panels[key] ~= nil
end
check(tab ~= nil and tab.sel:IsShown(), "before 60 the tab is Leveling, and lit")
check(Showing("zones"), "before 60 it opens on Zones, its button marked")
check(zonesBtn:GetText() == "Zones" and dungeonsBtn:GetText() == "Dungeons" and raidBtn:GetText() == L.RAID_ROSTER, "each view has a button")
dungeonsBtn:Click()
Tick(1)
check(Showing("dungeons"), "the Dungeons button shows only the dungeons")
FireEvent("PLAYER_LEVEL_UP", 41)
Tick(1)
check(Showing("dungeons") and p.guide.dungeonTitle:GetText() == string.format(L.GUIDE_DUNGEONS_FOR, 41), "a level-up redraws Dungeons and stays there")
FireEvent("PLAYER_LEVEL_UP", 40)
zonesBtn:Click()
Tick(1)
check(Showing("zones"), "the Zones button goes back")
Tick(5)
local before = #SENT
raidBtn:Click()
check(#SENT == before, "switching sends nothing")
Tick(1)
check(Showing("raids") and p.text:GetText() == L.RAID_SOON_TEXT, "the Raid roster button shows the raid roster")
check(TabNamed(L.TAB_LEVELING) ~= nil, "looking at the raids doesn't rename the tab")
raidBtn:Click()
Tick(1)
check(Showing("raids"), "clicking the open view again leaves it open")
UI.Select("home")
UI.Select("leveling")
Tick(1)
check(Showing("zones"), "coming back opens the view for my level")

-- Reaching 60 while it's open: the tab and the view change straight away.
FireEvent("PLAYER_LEVEL_UP", 60)
Tick(1)
check(TabNamed(L.TAB_RAIDS) ~= nil and TabNamed(L.TAB_LEVELING) == nil, "at 60 the tab is Raids")
check(Showing("raids"), "at 60 it opens on the raid roster")
zonesBtn:Click()
Tick(1)
check(Showing("zones") and TabNamed(L.TAB_RAIDS) ~= nil, "at 60 the guide is still there")

-- The dev console's pretend level.
UI.SetLevelingPretend(30)
Tick(1)
check(TabNamed(L.TAB_LEVELING) ~= nil and Showing("zones"), "pretend 30: Leveling, on Zones")
UI.SetLevelingPretend(60)
Tick(1)
check(TabNamed(L.TAB_RAIDS) ~= nil and Showing("raids"), "pretend 60: Raids")
UI.SetLevelingPretend(nil)
Tick(1)

-- The guide's data.
local G, D = ns.LevelGuide, ns.Dungeons
FAKE.level = 40
check(#G.ZONES == 42, "42 zones")
for _, z in ipairs(G.ZONES) do
    local ok = z[2] <= z[3] and z[3] <= 60 and (z[4] or z[5])
    for _, band in ipairs({ z[4] or { z[2], z[3] }, z[5] or { z[2], z[3] } }) do
        ok = ok and band[1] <= band[2] and band[1] >= z[2] and band[2] <= z[3]
    end
    check(ok, "sensible levels for " .. z[1])
end
for _, row in ipairs(D.LIST) do check(G.DUNGEONS[row[1]] and G.DUNGEONS[row[1]].where, "knows where " .. row[1] .. " is") end
local function Named(list, name)
    for _, x in ipairs(list) do if x.name == name then return x end end
end
-- Zones follow my level and faction, best ones first.
local z = G.Zones(15)
check(Named(z, "The Barrens") and Named(z, "The Barrens").best and Named(z, "The Barrens").bestMin == 10, "Horde 15: The Barrens, best 10-21")
check(not Named(z, "Westfall") and not Named(z, "Loch Modan"), "Horde 15: no Alliance zones")
local seenOther = false
for _, x in ipairs(z) do
    if not x.best then seenOther = true end
    check(x.best or seenOther, "best zones come first")
end
D.pretendFaction = "Alliance"
z = G.Zones(15)
check(Named(z, "Westfall") and Named(z, "The Barrens").bestMin == 13 and not Named(z, "Silverpine Forest"), "Alliance 15: its own zones and bands")
D.pretendFaction = nil
-- Dungeons: in range for my level, ready ones first, faction filtered.
local d40 = G.Dungeons(40)
check(Named(d40, "Razorfen Downs").ready and not Named(d40, "Krol'dok Stronghold").ready, "level 40: Downs ready, Krol'dok a tough one")
check(Named(d40, "Krol'dok Stronghold").top and Named(d40, "Razorfen Downs").top == nil, "new dungeons say top boss")
check(Named(d40, "SM: Armory").tag == "key" and Named(d40, "SM: Armory").note:find("Scarlet Key", 1, true), "Armory needs a key")
local tough = false
for _, x in ipairs(d40) do
    if not x.ready then tough = true end
    check(x.ready or tough, "ready dungeons come first")
    check(40 >= x.min and 40 <= x.max, x.name .. " is in range at 40")
end
check(not Named(G.Dungeons(25), "The Stockade"), "Horde: no Stockade in the guide")
check(not Named(G.Dungeons(15), "Hall of Thanes") and Named(G.Dungeons(15), "Ruins of Lordaeron").tag == nil, "Horde: no Hall of Thanes in the guide")
check(Named(G.Dungeons(30), "City of Dalaran").note:find("Tarren Mill", 1, true), "Horde gets the Horde attunement")
D.pretendFaction = "Alliance"
check(Named(G.Dungeons(25), "The Stockade") and not Named(G.Dungeons(15), "Ragefire Chasm"), "Alliance: Stockade, no Ragefire")
check(Named(G.Dungeons(15), "Ruins of Lordaeron").tag == "enemy", "Alliance: Ruins are enemy land")
check(Named(G.Dungeons(15), "Hall of Thanes").tag == nil, "Alliance: Hall of Thanes is home ground")
check(Named(G.Dungeons(30), "City of Dalaran").note:find("Southshore", 1, true), "Alliance gets the Alliance attunement")
check(#G.Dungeons(15, true) == 34 and Named(G.Dungeons(15, true), "The Stockade"), "Alliance Show all: its 34 dungeons")
D.pretendFaction = nil
-- Show all: everything my faction can use, in level order, with what's out of range marked.
local allD, allZ = G.Dungeons(40, true), G.Zones(40, true)
check(#allD == 33 and not Named(allD, "Hall of Thanes") and not Named(allD, "The Stockade"), "Horde Show all: still hides Alliance-only dungeons")
check(Named(allD, "Ragefire Chasm").outside and not Named(allD, "Razorfen Downs").outside, "Show all marks dungeons outside my level")
check(#allZ > #G.Zones(40) and Named(allZ, "Durotar").outside, "Show all lists every Horde zone")
for _, list in ipairs({ allD, allZ }) do
    for i = 2, #list do check(list[i].min >= list[i - 1].min, "Show all is in level order") end
end

-- The page: rows, tooltip, pagers, and an empty level.
UI.SetLevelingPretend(40)
UI.Select("home"); UI.Select("leveling")
Tick(1)
local g = p.guide
check(g.zoneTitle:GetText() == string.format(L.GUIDE_ZONES_FOR, 40), "the Zones title says my level")
check(g.zones.rows[1]:IsShown() and g.zones.rows[1].item.best, "a best zone on top")
dungeonsBtn:Click()
Tick(1)
check(g.dungeonTitle:GetText() == string.format(L.GUIDE_DUNGEONS_FOR, 40), "the Dungeons title says my level")
check(g.dungeons.rows[1]:IsShown() and g.dungeons.rows[1].info:GetText():find("best from", 1, true), "dungeon rows show the boss line")
g.dungeons.rows[1]:GetScript("OnEnter")(g.dungeons.rows[1])
g.dungeons.rows[1]:GetScript("OnLeave")(g.dungeons.rows[1])
UI.SetLevelingPretend(59)
Tick(1)
check(#g.dungeons.items > 9 and g.dungeons.pager.down:IsShown(), "more dungeons than fit: the pager shows")
local firstKey = g.dungeons.rows[1].item.key
g.dungeons.pager.down:Click()
check(g.dungeons.offset == #g.dungeons.items - 9 and g.dungeons.rows[1].item.key ~= firstKey, "the pager moves the list, stopping at the end")
UI.SetLevelingPretend(5)
Tick(1)
check(g.dungeons.offset == 0 and g.noDungeons:IsShown() and g.noDungeons:GetText():find("13", 1, true), "level 5: says when dungeons start")
UI.SetLevelingPretend(nil)
Tick(1)

-- QuestieDB is optional. Without it the guide still works, with no quest lists.
check(not G.HasQuestData() and G.QUESTS == nil and #G.Quests("rfd") == 0, "no QuestieDB: no quests, no error")
check(G.QuestState({ id = 1, ids = { 1 } }) == nil and G.QuestPlan({ id = 1, name = "x", ids = { 1 } }).locked == false, "no QuestieDB: status and chain are safe")
UI.SetLevelingPretend(40)
UI.Select("home"); UI.Select("leveling")
Tick(1)
UI.LevelingOpenDungeon("rfd")
Tick(1)
do
    local q = g.questPanel
    check(q.notice:IsShown() and q.notice.heading:GetText() == L.GUIDE_NO_QUEST_DATA and q.notice.icon ~= nil, "no QuestieDB: a notice with a warning icon")
    check(q.notice.text:GetText() == L.GUIDE_NO_QUEST_DATA_TEXT and q.notice.steps:GetText():find("Install QuestieDB", 1, true), "and it says what to do")
    check(q.notice.footer:GetText() == L.GUIDE_QUEST_DATA_FOOTER, "and that everything else still works")
    check(not q.empty:IsShown() and not q.hint:IsShown() and not q.heads[1]:IsShown(), "the empty list's headings and hint make way for it")
end
-- A version we can't read, or one that fails while reading: a clear note, never an error.
LibQuestieDB = FakeQuestieDB({ old = true })
ns.LiveQuests.Reset()
check(ns.LiveQuests.Status() == "old" and #G.Quests("rfd") == 0 and G.QuestDataNote() == L.GUIDE_QUEST_DATA_OLD, "a QuestieDB we can't read: says to update")
LibQuestieDB = FakeQuestieDB({ broken = true })
ns.LiveQuests.Reset()
check(#G.Quests("rfd") == 0 and ns.LiveQuests.Status() == "failed" and G.QuestDataNote() == L.GUIDE_QUEST_DATA_OLD, "QuestieDB fails while reading: no error, a note")
g.questPanel.back:Click()
Tick(1)
UI.SetLevelingPretend(nil)
Tick(1)
LibQuestieDB = FakeQuestieDB()
ns.LiveQuests.Reset()
check(G.HasQuestData() and G.QUESTS ~= nil and G.QUEST_STEPS ~= nil and G.QuestDataNote() == nil, "QuestieDB's quests are picked up")
-- It's a listed optional dependency, and none of its data ships with us.
local function ReadFile(path)
    local f = io.open(path, "rb")
    if not f then return "" end
    local s = f:read("*a")
    f:close()
    return s
end
local mainToc = ReadFile("YeahNahMate/YeahNahMate.toc")
check(mainToc:find("## OptionalDeps: QuestieDB", 1, true), "QuestieDB is listed as optional")
check(not mainToc:find("## RequiredDeps", 1, true) and not mainToc:find("## Dependencies", 1, true), "and isn't required")
check(ReadFile("YeahNahMate_Quests/DungeonQuests.lua") == "" and ReadFile("tools/gen_dungeon_quests.py") == "", "no copied quest data or its generator")
check(not ReadFile(".pkgmeta"):find("YeahNahMate_Quests", 1, true), "the release has no quest data folder")
check(ReadFile(".pkgmeta"):find("optional%-dependencies:%s+%- questiedb"), "CurseForge lists QuestieDB as optional")
-- Quests a player can't get stay out, and a giver in zone 1 keeps its map pin.
local function InData(id)
    for _, list in pairs(G.QUESTS) do
        for _, q in ipairs(list) do if q[1] == id then return q end end
    end
end
check(not InData(7668) and not G.QUEST_STEPS[7668], "quests not in the game are left out")
check(InData(2926) and InData(2926)[9] == 1426, "a quest giver in Dun Morogh has a map place")
check(InData(97000) ~= nil, "a quest for a new dungeon's boss is linked by the boss's id")

-- Quest data: every group is known, every line well formed.
local groups = 0
for key, list in pairs(G.QUESTS) do
    groups = groups + 1
    for _, q in ipairs(list) do
        local fine = type(q[1]) == "number" and type(q[2]) == "string" and q[3] >= 1 and q[3] <= 60
            and (q[5] == "A" or q[5] == "H" or q[5] == "B") and type(q[6]) == "number"
        if q[9] then fine = fine and q[10] > 0 and q[10] <= 100 and q[11] >= 0 and q[11] <= 100 end
        check(fine, "well-formed quest in " .. key .. ": " .. tostring(q[2]))
    end
end
check(groups == 29, "28 dungeon quest groups and the class quests (" .. groups .. ")")
local function QuestNamed(key, name)
    for _, q in ipairs(G.Quests(key)) do if q.name == name then return q end end
end
-- Faction, wings, class, and one line per quest.
check(QuestNamed("smcath", "Into The Scarlet Monastery") and QuestNamed("smlib", "Into The Scarlet Monastery"), "Scarlet wings share quests")
check(QuestNamed("rfd", "An Unholy Alliance") and not QuestNamed("rfd", "Bring the Light"), "Horde: Horde quests only")
check(#G.Quests("stocks") == 0, "Horde: nothing for The Stockade")
local names = {}
for _, q in ipairs(G.Quests("ulda")) do
    check(not names[q.name], "one line per quest: " .. q.name)
    names[q.name] = true
end
check(QuestNamed("rfk", "Elemental Aid") ~= nil, "my class's quest shows (Shaman)")
check(QuestNamed("rfk", "Brutal Armor") == nil, "another class's quest doesn't")
check(QuestNamed("strat", "Just Compensation") == nil and QuestNamed("mara", "Rite of Vision") == nil, "turn-ins and strays are left out")
D.pretendFaction = "Alliance"
check(QuestNamed("rfd", "Bring the Light") and not QuestNamed("rfd", "Bring the End"), "Alliance: Alliance quests only")
D.pretendFaction = nil

-- In log / Done, including a quest with two steps under one name (An Unholy Alliance: 6521 then 6522).
do
    local inLog, handedIn = {}, {}
    local realIndex, realDone = C_QuestLog and C_QuestLog.GetLogIndexForQuestID, C_QuestLog and C_QuestLog.IsQuestFlaggedCompleted
    C_QuestLog = C_QuestLog or {}
    C_QuestLog.GetLogIndexForQuestID = function(id) return inLog[id] and 1 or nil end
    C_QuestLog.IsQuestFlaggedCompleted = function(id) return handedIn[id] == true end
    local q = QuestNamed("rfd", "An Unholy Alliance")
    local both = {}
    for _, id in ipairs(q.ids) do both[id] = true end
    check(both[6521] and both[6522], "both steps belong to the one line")
    check(G.QUEST_EARLIER[6521] or G.QUEST_EARLIER[6522], "one is the earlier step")
    local first = G.QUEST_EARLIER[6521] and 6521 or 6522
    local last = first == 6521 and 6522 or 6521
    check(G.QuestState(q) == nil, "not started: no status")
    inLog[first] = true
    check(G.QuestState(q) == "log", "first step in my log: In log")
    inLog[first] = nil; handedIn[first] = true
    check(G.QuestState(q) == nil, "first step handed in: not Done yet")
    inLog[last] = true
    check(G.QuestState(q) == "log", "second step in my log: In log")
    inLog[last] = nil; handedIn[last] = true
    check(G.QuestState(q) == "done", "last step handed in: Done")
    C_QuestLog.IsQuestFlaggedCompleted = function() error("game says no") end
    C_QuestLog.GetLogIndexForQuestID = function() error("game says no") end
    check(G.QuestState(q) == nil, "a failing game call just shows no status")
    C_QuestLog.GetLogIndexForQuestID, C_QuestLog.IsQuestFlaggedCompleted = realIndex, realDone
end

-- Quest chains, on a made-up chain: A -> B (or its other version) -> C and D -> E.
do
    local S = G.QUEST_STEPS
    local function Step(name, side, all, any, alt)
        return { name, 20, side or "B", 0, false, name .. " giver", 1413, 50, 50, all or false, any or false, alt or false }
    end
    S[900001] = Step("Chain A")
    S[900002] = Step("Chain B", "B", { 900001 }, false, { 900003 })
    S[900003] = Step("Chain B other")
    S[900004] = Step("Chain C", "B", false, { 900002 })
    S[900005] = Step("Chain D", "B", false, { 900009, 900001 })     -- 900009: the other faction's version
    S[900009] = Step("Chain D Alliance way", "A")
    S[900006] = Step("Chain E", "B", { 900004, 900005 })
    S[900007] = Step("Loop one", "B", { 900008 })
    S[900008] = Step("Loop two", "B", { 900007 })
    local inLog, handedIn = {}, {}
    local realIndex, realDone = C_QuestLog and C_QuestLog.GetLogIndexForQuestID, C_QuestLog and C_QuestLog.IsQuestFlaggedCompleted
    C_QuestLog = C_QuestLog or {}
    C_QuestLog.GetLogIndexForQuestID = function(id) return inLog[id] and 1 or nil end
    C_QuestLog.IsQuestFlaggedCompleted = function(id) return handedIn[id] == true end
    local q = { id = 900006, name = "Chain E", level = 20, req = 15, ids = { 900006 } }
    local function Target() return G.QuestPlan(q).target.id end
    check(G.QuestPlan(q).locked and Target() == 900001, "locked: the next quest is the start of the chain")
    local order = {}
    for _, s in ipairs(G.QuestChain(G.QuestPlan(q))) do order[#order + 1] = s.id end
    check(#order == 5 and order[1] == 900001 and order[2] == 900002 and order[3] == 900004 and order[4] == 900005 and order[5] == 900006,
        "the chain reads in the order you do it, without the other faction's version")
    check(G.QuestChain(G.QuestPlan(q))[1].state == "next", "the first step is marked next")
    handedIn[900001] = true
    check(Target() == 900002, "after A, B is next")
    handedIn[900003] = true
    check(Target() == 900004, "doing B's other version counts as B")
    check(G.QuestChain(G.QuestPlan(q))[2].state == "done", "and shows B as done")
    inLog[900004] = true
    check(Target() == 900004 and G.QuestChain(G.QuestPlan(q))[3].state == "log", "a step in my log stays next and shows In log")
    inLog[900004] = nil; handedIn[900004] = true
    check(Target() == 900005, "D is open next: its one-of was met by A")
    handedIn[900005] = true
    check(Target() == 900006 and not G.QuestPlan(q).locked, "everything before it done: unlocked")
    -- A loop in the data can't hang it.
    local loop = { id = 900007, name = "Loop one", level = 20, req = 15, ids = { 900007 } }
    check(G.QuestPlan(loop).target ~= nil and #G.QuestChain(G.QuestPlan(loop)) == 2, "a loop in the data is survived")
    -- Real data: a second step under one name isn't "locked"; a real chain unlocks step by step.
    local ua = QuestNamed("rfd", "An Unholy Alliance")
    check(not G.QuestPlan(ua).locked and G.QuestPlan(ua).target.id == 6522, "An Unholy Alliance: its first step is next, not 'locked'")
    local nara = QuestNamed("wc", "Nara Wildmane")
    check(G.QuestPlan(nara).locked, "Nara Wildmane starts locked")
    for _ = 1, 20 do
        local plan = G.QuestPlan(nara)
        if not plan.locked then break end
        handedIn[plan.target.id] = true
    end
    check(not G.QuestPlan(nara).locked, "handing in each step unlocks it")
    C_QuestLog.GetLogIndexForQuestID, C_QuestLog.IsQuestFlaggedCompleted = realIndex, realDone
    for i = 900001, 900009 do S[i] = nil end
end

-- Every chain in the shipped data ends somewhere, for both factions.
for _, faction in ipairs({ "Horde", "Alliance" }) do
    D.pretendFaction = faction
    for _, row in ipairs(D.LIST) do
        for _, q in ipairs(G.Quests(row[1])) do
            local plan = G.QuestPlan(q)
            check(plan.target and plan.target.name and type(G.QuestChain(plan)) == "table", "chain for " .. q.name)
        end
    end
end
D.pretendFaction = nil

-- The quest panel: open, list, pin and map, back.
UI.SetLevelingPretend(40)     -- this test already "reached" 60 above
UI.Select("home"); UI.Select("leveling")
Tick(1)
local openedMap
C_Map.OpenWorldMap = function(id) openedMap = id end
dungeonsBtn:Click()
Tick(1)
local rfdRow
for _, r in ipairs(g.dungeons.rows) do if r.item and r.item.key == "rfd" then rfdRow = r end end
rfdRow:Click()
Tick(1)
check(g.questPanel:IsShown() and not g.lists:IsShown() and g.questPanel.title:GetText():find("Razorfen Downs", 1, true), "clicking a dungeon opens its quests")
check(not g.questPanel.notice:IsShown() and g.questPanel.heads[1]:IsShown() and g.questPanel.hint:IsShown(), "with QuestieDB: no notice, the normal list")
local mapRow, noMapRow
for _, r in ipairs(g.quests.rows) do
    if r.item and r.place.map and not mapRow then mapRow = r end
    if r.item and not r.place.map and not noMapRow then noMapRow = r end
end
check(mapRow and (mapRow.map:GetText() == L.GUIDE_SHOW_MAP or mapRow.map:GetText() == L.GUIDE_SHOW_NEXT), "a quest with a place offers the map")
check(noMapRow and noMapRow.map:GetText():find(L.GUIDE_NO_MAP, 1, true), "one starting in the dungeon says so")
check(g.questPanel.heads[5].label:GetText() == L.GUIDE_LOCATION, "the quest list has a Location column")
check(mapRow.location:GetText() == "Map " .. mapRow.place.map, "a quest's Location is the zone it starts in")
check(noMapRow.location:GetText() == L.GUIDE_NO_LOCATION, "no map spot: a dash")
check(G.MapName(nil) == nil, "no map, no name")
do
    local realInfo = C_Map.GetMapInfo
    C_Map.GetMapInfo = function() error("game says no") end
    check(G.MapName(987654) == nil, "a failing map lookup is safe")
    C_Map.GetMapInfo = function() return { name = "" } end
    check(G.MapName(987654) == nil, "and so is an empty name")
    C_Map.GetMapInfo = realInfo
end
Tick(5)
local sentBefore = #SENT
noMapRow:Click()
check(openedMap == nil and UI.LevelingPinnedQuest() == nil, "no place: no pin, no map")
mapRow:GetScript("OnEnter")(mapRow); mapRow:GetScript("OnLeave")(mapRow)
local wanted = mapRow.place
mapRow:Click()
Tick(1)
check(openedMap == wanted.map and UI.LevelingPinnedQuest().id == wanted.id, "clicking pins it and opens the map there")
check(#SENT == sentBefore, "the map click sends nothing")
-- The window waits behind the map, leaves Escape to the map, and comes back when it closes.
local win
for _, o in ipairs(CREATED) do if o._name == "YeahNahMateFrame" then win = o end end
check(win:IsShown() and UI.IsBehindMap() and win:GetFrameStrata() == "LOW", "Show on map: the window stays open, behind the map")
check(g.questPanel:IsShown() and mapRow.map:GetText():find(L.GUIDE_PINNED, 1, true) and g.questPanel.clear:IsShown(), "same list behind it, marked Pinned")
WorldMapFrame:Show()
Tick(1)
win:GetScript("OnKeyDown")(win, "ESCAPE")
check(win:IsShown() and UI.IsBehindMap(), "Escape is left to the map")
Tick(5)
check(UI.IsBehindMap(), "it stays behind while the map is open")
WorldMapFrame:Hide()
Tick(1)
check(not UI.IsBehindMap() and win:IsShown() and win:GetFrameStrata() == "DIALOG", "the map closes: the window is back in front")
win:GetScript("OnKeyDown")(win, "ESCAPE")
check(not win:IsShown(), "and Escape closes it again as normal")
UI.Open()
Tick(1)
check(g.questPanel:IsShown(), "reopened on the same quest list")
-- /ynm while it's behind an open map brings it to the front.
WorldMapFrame:Show()
check(UI.SendBehindMap() and win:GetFrameStrata() == "LOW", "behind the map again")
UI.Toggle()
check(win:IsShown() and not UI.IsBehindMap() and win:GetFrameStrata() == "DIALOG", "/ynm brings it to the front")
Tick(2)
check(win:GetFrameStrata() == "DIALOG", "and the old check doesn't push it back")
-- Closing it while behind the map leaves it normal next time.
UI.SendBehindMap()
win:Hide()
check(not UI.IsBehindMap() and win:GetFrameStrata() == "DIALOG", "hidden while behind: back to normal")
WorldMapFrame:Hide()
UI.Open()
Tick(1)
-- A map that never appears doesn't leave the window stuck behind.
UI.SendBehindMap()
Tick(2)
check(not UI.IsBehindMap() and win:GetFrameStrata() == "DIALOG", "the map never opened: the window comes back")
-- In combat: the pin goes in, the map isn't touched.
openedMap = nil
local realCombat = InCombatLockdown
InCombatLockdown = function() return true end
local other
for _, r in ipairs(g.quests.rows) do if r.item and r.place.map and r.place.id ~= wanted.id then other = r end end
local otherId = other.place.id
other:Click()
Tick(1)
InCombatLockdown = realCombat
check(openedMap == nil and UI.LevelingPinnedQuest().id == otherId and g.questPanel.hint:GetText() == L.GUIDE_PINNED_PRESS_M, "in combat: pinned, press M")
g.questPanel.clear:Click()
Tick(1)
check(UI.LevelingPinnedQuest() == nil and not g.questPanel.clear:IsShown(), "Clear map pin removes it")
g.questPanel.back:Click()
Tick(1)
check(Showing("dungeons") and g.lists:IsShown() and not g.questPanel:IsShown(), "Back returns to the dungeon list")
C_Map.OpenWorldMap = nil
UI.LevelingOpenDungeon("rfd")
Tick(1)
mapRow:Click()
Tick(1)
check(UI.LevelingPinnedQuest() ~= nil and g.questPanel.hint:GetText() == L.GUIDE_PINNED_PRESS_M, "no map call on this client: pinned, press M")
g.questPanel.clear:Click()
UI.Select("home"); UI.Select("leveling")
Tick(1)
check(Showing("zones") and g.questKey == nil, "leaving the tab goes back to Zones, with no quest list open")
UI.SetLevelingPretend(nil)
Tick(1)

-- Clicking a zone opens it on the map.
do
    local function ZoneRow(name)
        for _, r in ipairs(g.zones.rows) do if r.item and r.item.name == name then return r end end
    end
    local realInfo = C_Map.GetMapInfo
    C_Map.GetMapInfo = nil
    check(G.ZoneMap("The Barrens") == nil, "no map call on this client: no map, no error")
    -- A German client: the game's names differ, the ids don't. Silverpine is a map it doesn't have.
    C_Map.GetMapInfo = function(id)
        if id == 1421 then return nil end
        return { mapID = id, name = id == 1413 and "Brachland" or ("Karte " .. id), mapType = 3 }
    end
    check(G.ZoneMap("The Barrens") == 1413 and G.ZoneMap("Zephras Isle") == 2521, "zones are found by id, in any language")
    check(G.ZoneMap("Nowhere") == nil, "an unknown zone has no map")
    for _, z in ipairs(G.ZONES) do
        check(z[1] == "Silverpine Forest" or G.ZoneMap(z[1]) ~= nil, z[1] .. " has a map id")
    end
    C_Map.OpenWorldMap = function(id) openedMap = id end
    UI.SetLevelingPretend(15)
    UI.Select("home"); UI.Select("leveling")
    Tick(5)
    local barrens, silverpine = ZoneRow("The Barrens"), ZoneRow("Silverpine Forest")
    check(barrens and silverpine and g.zoneKey:GetText():find(L.GUIDE_ZONE_CLICK, 1, true), "the page says zones can be clicked")
    barrens:GetScript("OnEnter")(barrens); barrens:GetScript("OnLeave")(barrens)
    silverpine:GetScript("OnEnter")(silverpine); silverpine:GetScript("OnLeave")(silverpine)
    openedMap = nil
    local sent, pinned = #SENT, UI.LevelingPinnedQuest()
    silverpine:Click()
    check(openedMap == nil, "a zone the game doesn't list does nothing")
    barrens:Click()
    Tick(1)
    check(openedMap == 1413 and UI.IsBehindMap() and win:IsShown(), "clicking a zone opens it on the map, the window waiting behind")
    check(#SENT == sent and UI.LevelingPinnedQuest() == pinned, "it sends nothing and leaves the quest pin alone")
    Tick(2)
    check(not UI.IsBehindMap(), "the window comes back")
    openedMap = nil
    local combat = InCombatLockdown
    InCombatLockdown = function() return true end
    barrens:Click()
    Tick(1)
    InCombatLockdown = combat
    check(openedMap == nil and g.zoneKey:GetText() == L.GUIDE_ZONE_MAP_FAILED, "in combat: the map is left alone and it says why")
    barrens:Click()
    Tick(1)
    check(openedMap == 1413 and g.zoneKey:GetText():find(L.GUIDE_ZONE_CLICK, 1, true), "out of combat it works again")
    Tick(2)
    C_Map.OpenWorldMap, C_Map.GetMapInfo = nil, realInfo
    UI.SetLevelingPretend(nil)
    Tick(1)
end

-- Class quests: my class and faction, with the same status, chain and map as a dungeon's.
do
    local function Has(name) return QuestNamed("class", name) ~= nil end
    check(Has("Call of Earth") and Has("Call of Fire") and Has("Elemental Aid"), "my class's quests, in the world or a dungeon")
    check(not Has("Warrior's Trial") and not Has("Brutal Armor"), "not another class's")
    check(not Has("Call of Water"), "not the other faction's")
    check(not Has("Everyone's Errand"), "a quest naming every class isn't a class quest")
    check(not Has("Daily Totem"), "repeatable quests are left out")
    check(not Has("Raid Turn-in") and Has("Shaman Capstone"), "level 60: the class's own quests, not raid turn-ins")
    check(not Has("Totem Smithing") and not Has("Guild Recipe"), "profession quests are left out")
    check(QuestNamed("rfk", "Elemental Aid") ~= nil, "a class quest in a dungeon stays on the dungeon's list too")
    D.pretendFaction = "Alliance"
    check(Has("Call of Water") and not Has("Call of Earth"), "Alliance: its own class quests")
    D.pretendFaction = nil

    local inLog, handedIn = {}, {}
    local realIndex, realDone = C_QuestLog.GetLogIndexForQuestID, C_QuestLog.IsQuestFlaggedCompleted
    C_QuestLog.GetLogIndexForQuestID = function(id) return inLog[id] and 1 or nil end
    C_QuestLog.IsQuestFlaggedCompleted = function(id) return handedIn[id] == true end
    local function ClassRow(name)
        for _, r in ipairs(g.quests.rows) do if r.item and r.item.name == name then return r end end
    end
    local classBtn = p.viewButtons.class
    check(classBtn:GetText() == "Class quests", "Class quests has a button")
    UI.Select("home"); UI.Select("leveling")
    Tick(1)
    check(not g.questPanel:IsShown(), "the quest list stays closed on Zones")
    classBtn:Click()
    Tick(1)
    local q = g.questPanel
    check(Showing("class") and q:IsShown() and not q.back:IsShown(), "the button opens the list, with nothing to go back to")
    check(q.title:GetText():find("Shaman quests", 1, true) and q.heads[1]:IsShown(), "titled with my class")
    check(q.title:GetText():find(string.format(L.GUIDE_CLASS_COUNT, 19, 17), 1, true), "it counts quests and storylines")
    local word = g.quests.rows[1]
    check(g.quests.offset == 0 and word.item.name == "Word From The Elder", "lowest level first, the lead-in on top")
    check(word.toggle:IsShown() and word.toggle:GetText() == "+" and word.state:GetText():find("0/3", 1, true), "a closed storyline shows + and its progress")
    check(word.status == nil and not word.tint:IsShown(), "nothing started: no colour")
    check(not ClassRow("Call of Earth") and not ClassRow("Call of Fire"), "its steps are tucked away")
    check(not ClassRow("Shaman Lesson 1").toggle:IsShown(), "a single quest has no +")
    word:GetScript("OnEnter")(word); word:GetScript("OnLeave")(word)
    check(word.place.name == "Call of Earth", "a closed storyline points at the quest to do next")
    word.toggle:Click()
    Tick(1)
    check(word.toggle:GetText() == "-" and g.quests.rows[2].item.name == "Call of Earth" and g.quests.rows[3].item.name == "Call of Fire", "+ opens it, steps in order")
    check(g.quests.rows[2].item.depth == 1 and g.quests.rows[3].item.depth == 1, "a straight chain stays at one indent")
    check(not g.quests.rows[2].toggle:IsShown(), "steps have no + of their own")
    local fire = ClassRow("Call of Fire")
    check(fire.locked and fire.state:GetText():find(L.GUIDE_LOCKED, 1, true) and fire.place.name == "Call of Earth", "a chain step says Locked and points at what's next")
    check(fire.status == "locked" and fire.tint:IsShown(), "a locked step has the locked colour")
    check(fire.location:GetText() == "Map 1456", "a locked step's Location is where to go next")
    check(g.quests.rows[1].status == nil, "and the top row isn't locked: the storyline can be started")
    fire:GetScript("OnEnter")(fire); fire:GetScript("OnLeave")(fire)
    openedMap = nil
    C_Map.OpenWorldMap = function(id) openedMap = id end
    local sent = #SENT
    fire:Click()
    Tick(1)
    check(openedMap == 1456 and UI.LevelingPinnedQuest().name == "Call of Earth", "Show next step pins the next quest and opens the map")
    check(#SENT == sent, "it sends nothing")
    Tick(2)
    q.clear:Click()
    Tick(1)
    inLog[9950] = true
    FireEvent("QUEST_LOG_UPDATE")
    Tick(3)
    check(ClassRow("Call of Earth").state:GetText():find(L.GUIDE_IN_LOG, 1, true), "a quest in my log says In log")
    check(ClassRow("Call of Earth").status == "log" and g.quests.rows[1].status == "log", "the step and the top row take the In log colour")
    check(g.quests.rows[1].state:GetText():find("0/3", 1, true), "an open storyline's top row still shows its progress")
    inLog[9950], handedIn[9950] = nil, true
    FireEvent("QUEST_TURNED_IN", 9950)
    Tick(3)
    check(ClassRow("Call of Earth").state:GetText():find(L.GUIDE_DONE, 1, true) and not ClassRow("Call of Fire").locked, "handed in: Done, and the next one unlocks")
    check(ClassRow("Call of Earth").status == "done" and ClassRow("Call of Earth").tint:IsShown(), "a done quest is green")
    check(ClassRow("Call of Fire").status == nil and not ClassRow("Call of Fire").tint:IsShown(), "the open next step has no colour")
    check(g.quests.rows[1].status == "done", "the top row shows the furthest progress: done")
    inLog[9951] = true
    FireEvent("QUEST_LOG_UPDATE")
    Tick(3)
    check(g.quests.rows[1].status == "log", "a later step in my log is further: the top row goes to In log")
    inLog[9951] = nil
    FireEvent("QUEST_LOG_UPDATE")
    Tick(3)
    g.quests.rows[1].toggle:Click()
    Tick(1)
    check(g.quests.rows[1].toggle:GetText() == "+" and g.quests.rows[1].state:GetText():find("2/3", 1, true), "- closes it, and a skipped lead-in counts as done")
    check(g.quests.rows[1].place.name == "Call of Fire", "the closed row now points at the next step")
    handedIn[9951] = true
    FireEvent("QUEST_TURNED_IN", 9951)
    Tick(3)
    check(g.quests.rows[1].state:GetText():find("3/3", 1, true) and g.quests.rows[1].status == "done", "the whole storyline done, and green")
    -- Sorting: by any column, reversed, then back to the usual order. Storylines move as a whole.
    local function Top() return g.quests.rows[1].item.name end
    local function Sort(col)
        q.heads[col]:Click()
        Tick(1)
    end
    g.quests.pager.down:Click()
    Sort(2)
    check(Top() == "Elemental Aid" and g.quests.offset == 0 and q.heads[2].label:GetText() ~= L.GUIDE_QUEST, "Quest: A to Z, back at the top, with an arrow")
    Sort(2)
    check(Top() == "Word From The Elder", "again: Z to A")
    g.quests.rows[1].toggle:Click()
    Tick(1)
    check(Top() == "Word From The Elder" and g.quests.rows[2].item.name == "Call of Earth" and g.quests.rows[3].item.name == "Call of Fire", "an open storyline keeps its steps in order")
    g.quests.rows[1].toggle:Click()
    Tick(1)
    Sort(2)
    check(Top() == "Word From The Elder" and q.heads[2].label:GetText() == L.GUIDE_QUEST and g.sortKey == nil, "a third click: the usual order")
    Sort(1)
    check(Top() == "Word From The Elder", "Level: lowest first")
    Sort(1)
    check(Top() == "Shaman Capstone" and q.heads[2].label:GetText() == L.GUIDE_QUEST, "highest first, one arrow only")
    Sort(1); Sort(3)
    inLog[9965] = true
    FireEvent("QUEST_LOG_UPDATE")
    Tick(3)
    check(Top() == "Shaman Lesson 5", "Status: in my log first")
    Sort(3)
    check(Top() == "Word From The Elder", "reversed: finished first")
    inLog[9965] = nil
    Sort(3)
    -- Empty cells stay at the bottom in both directions; sorting carries over to a dungeon.
    UI.LevelingOpenDungeon("rfd")
    Tick(1)
    Sort(5)
    local function Last()
        local last
        for _, r in ipairs(g.quests.rows) do if r.item and r:IsShown() then last = r end end
        return last.item.name
    end
    check(Last() == "Starts Inside", "Location: no place goes last")
    Sort(5)
    check(Last() == "Starts Inside", "and still last reversed")
    Sort(5)
    Sort(4)
    check(q.heads[4].label:GetText() ~= L.GUIDE_STARTS and Top() == "Bring the End", "Starts with sorts by quest giver")
    q.heads[4]:GetScript("OnEnter")(q.heads[4]); q.heads[4]:GetScript("OnLeave")(q.heads[4])
    Sort(4); Sort(4)
    check(g.sortKey == nil, "back to the usual order")
    classBtn:Click()
    Tick(1)
    -- Coming back to it starts at the first storyline I haven't finished.
    zonesBtn:Click()
    Tick(1)
    check(not q:IsShown(), "another view closes the list")
    classBtn:Click()
    Tick(1)
    check(g.quests.offset == 1 and g.quests.rows[1].item.name == "Shaman Lesson 1", "it opens at the first storyline not done")
    check(g.quests.rows[1].name:GetText() == "Shaman Lesson 1", "rows reused from the tree still draw")
    UI.LevelingOpenDungeon("rfd")
    Tick(1)
    -- A dungeon's quests are the same tree.
    local bring = ClassRow("Bring the End")
    check(not g.quests.rows[1].toggle:IsShown() and g.quests.rows[1].item.depth == 0, "a single dungeon quest has no +")
    check(bring and bring.toggle:IsShown() and bring.state:GetText():find("0/2", 1, true) and not ClassRow("Bring the End Again"), "a dungeon chain is one closed row")
    bring.toggle:Click()
    Tick(1)
    bring = ClassRow("Bring the End")
    check(bring.toggle:GetText() == "-" and ClassRow("Bring the End Again").item.depth == 1, "+ opens it")
    handedIn[3341] = true
    FireEvent("QUEST_TURNED_IN", 3341)
    Tick(3)
    check(ClassRow("Bring the End").status == "done" and ClassRow("Bring the End").state:GetText():find("1/2", 1, true), "its top row shows the furthest progress")
    check(ClassRow("Bring the End Again").status == nil, "and the next step is open")
    handedIn[3341] = nil
    ClassRow("Bring the End").toggle:Click()
    Tick(1)
    classBtn:Click()
    Tick(1)
    check(g.quests.rows[1].toggle:GetText() ~= "-", "each list keeps its own open storylines")
    -- Dungeons keeps its own quest list and Back.
    UI.LevelingOpenDungeon("rfd")
    Tick(1)
    check(Showing("dungeons") and q:IsShown() and q.back:IsShown() and q.title:GetText():find("Razorfen Downs", 1, true), "a dungeon's list still opens, with Back")
    classBtn:Click()
    Tick(1)
    check(Showing("class") and q.title:GetText():find("Shaman quests", 1, true), "switching shows the class list")
    dungeonsBtn:Click()
    Tick(1)
    check(q:IsShown() and q.title:GetText():find("Razorfen Downs", 1, true), "and back to the dungeon I had open")
    q.back:Click()
    Tick(1)
    -- Without QuestieDB: the same clear notice.
    LibQuestieDB = nil
    ns.LiveQuests.Reset()
    classBtn:Click()
    Tick(1)
    check(q.notice:IsShown() and q.notice.heading:GetText() == L.GUIDE_NO_QUEST_DATA and not q.empty:IsShown(), "no QuestieDB: the notice, no error")
    LibQuestieDB = FakeQuestieDB()
    ns.LiveQuests.Reset()
    zonesBtn:Click()
    Tick(1)
    C_Map.OpenWorldMap = nil
    C_QuestLog.GetLogIndexForQuestID, C_QuestLog.IsQuestFlaggedCompleted = realIndex, realDone
end

-- Entrances and inside maps, read live from QuestieDB's zone data; a few new dungeons are our own.
do
    local Guide, q2 = ns.LevelGuide, p.guide.questPanel
    local realLib, realInfo, realOpen = LibQuestieDB, C_Map.GetMapInfo, C_Map.OpenWorldMap
    local opened
    LibQuestieDB = setmetatable({ Support = { Get = function() return { private = {
        areaIdToUiMapId = { [17] = 1413, [139] = 1423, [357] = 1444, [718] = 279 },
        dungeons = { [718] = { "Wailing Caverns", nil, 17, { { 17, 46, 36.5 } } },
                     [2557] = { "Dire Maul", nil, 357, { { 357, 59.2, 45.1 } } },
                     [10022] = { "Dire Maul", nil, 357, { { 357, 62.5, 24.9 } } },
                     [10023] = { "Dire Maul", nil, 357, { { 357, 60.3, 30.2 } } },
                     [10026] = { "Dire Maul", nil, 357, { { 357, 64.8, 30.2 } } },
                     [2017] = { "Stratholme", nil, 139, { { 139, 26.5, 10.4 }, { 139, 41.5, 17.7 } } } },
    } } end } }, { __index = realLib })
    ns.LiveQuests.Reset()
    C_Map.GetMapInfo = function(id) return { mapID = id, name = "Map " .. id, mapType = id == 279 and 4 or 3 } end
    C_Map.OpenWorldMap = function(id) opened = id end

    local wc = Guide.Entrance("wc")
    check(wc and wc.map == 1413 and wc.x == 46 and wc.y == 36.5 and wc.entrance, "an entrance comes from QuestieDB")
    check(Guide.Entrance("strat").x == 26.5 and Guide.Entrance("stratsg").x == 41.5, "each Stratholme gate has its own door")
    check(Guide.Entrance("dme").y == 30.2 and Guide.Entrance("dme").x == 64.8 and Guide.Entrance("dmw").x == 60.3
        and Guide.Entrance("dmn").y == 24.9, "each Dire Maul wing has its own door")
    check(Guide.Entrance("krol").map == 2548, "a dungeon QuestieDB lacks uses our own position")
    check(Guide.Entrance("zf") == nil, "an unknown entrance is nil")
    check(Guide.DungeonMap("wc") == 279 and Guide.DungeonMap("strat") == nil, "only a real dungeon map counts")

    UI.Select("leveling")
    UI.LevelingOpenDungeon("wc")
    Tick(1)
    check(q2.entrance:IsShown() and q2.dungeonMap:IsShown(), "both map buttons show on a dungeon")
    q2.entrance:Click()
    Tick(1)
    check(opened == 1413 and UI.LevelingPinnedQuest().id == "entrance:wc", "Show entrance pins it and opens the zone")
    q2.dungeonMap:Click()
    check(opened == 279, "Dungeon map opens the inside map")
    q2.clear:Click()
    Tick(1)
    check(UI.LevelingPinnedQuest() == nil, "the entrance pin clears")
    UI.LevelingOpenDungeon("zf")
    Tick(1)
    check(not q2.entrance:IsShown() and not q2.dungeonMap:IsShown(), "no data: no buttons")

    LibQuestieDB, C_Map.GetMapInfo, C_Map.OpenWorldMap = realLib, realInfo, realOpen
    ns.LiveQuests.Reset()
    UI.LevelingShow("zones")
    Tick(1)
end

-- An either-or quest that isn't on any list still counts: handing it in finishes this one.
do
    local Quest = LibQuestieDB.Quest
    local realEx, realDone = Quest.exclusiveTo, C_QuestLog.IsQuestFlaggedCompleted
    Quest.exclusiveTo = function(id)
        if id == 3341 then return { 99435 } end
        return realEx(id)
    end
    ns.LiveQuests.Reset()
    local step = ns.LevelGuide.QUEST_STEPS[3341]
    check(step and step[12] and step[12][1] == 99435, "the alternative is kept, even though it isn't a step")
    C_QuestLog.IsQuestFlaggedCompleted = function(id) return id == 99435 end
    check(ns.LevelGuide.QuestState({ id = 3341, ids = { 3341 } }) == "done", "handing in the alternative marks this quest done")
    Quest.exclusiveTo, C_QuestLog.IsQuestFlaggedCompleted = realEx, realDone
    ns.LiveQuests.Reset()
end

-- The Bosses column: all time per character, main bosses in the total, optional and secret as a bonus.
do
    local B = ns.Bosses
    for _, d in ipairs(D.LIST) do
        check(B.LIST[d[1]] and #B.LIST[d[1]].main > 0, d[2] .. " has a boss list")
    end
    B.Clear()
    check(select(2, B.Count("rfc")) == 4 and B.Count("rfc") == 0, "Ragefire starts at 0 of 4")
    FireEvent("ENCOUNTER_END", 2732, "Oggleflint", 1, 5, 0)
    check(B.Count("rfc") == 0, "a wipe doesn't count")
    FireEvent("ENCOUNTER_END", 2732, "Oggleflint", 1, 5, 1)
    FireEvent("ENCOUNTER_END", 2732, "Oggleflint", 1, 5, 1)
    check(B.Count("rfc") == 1, "a kill counts once, and repeats don't add")
    FireEvent("ENCOUNTER_END", 999999, "Someone else", 1, 5, 1)
    check(B.Count("rfc") == 1, "an unknown boss is ignored")
    FireEvent("ENCOUNTER_END", 2767, "Aku'mai", 1, 5, 1)
    check(B.Rows("bfd")[7].done, "another difficulty's id ticks the same boss")
    FireEvent("ENCOUNTER_END", 3644, "Highland Horror", 1, 5, 1)
    local done, total, bonus = B.Count("exc")
    check(done == 0 and total == 3 and bonus == 1, "an optional boss is a bonus, not in the total")
    local _, extra = B.Rows("exc")
    check(extra[1].done and extra[1].name == "Highland Horror", "the hover lists it under the extras")
    -- The game hiding my id mid-fight doesn't lose the kill: it's kept from login.
    local realGuid = UnitGUID
    UnitGUID = function() return nil end
    FireEvent("ENCOUNTER_END", 3480, "Saltspine", 1, 5, 1)
    UnitGUID = realGuid
    check(B.Count("exc") == 1, "a kill still saves if the game hides my id during the fight")

    UI.SetLevelingPretend(15)
    UI.Select("leveling")
    UI.LevelingShow("dungeons")
    p.guide.showAll = true
    Tick(1)
    local function RowFor(key)
        for _, r in ipairs(p.guide.dungeons.rows) do
            if r.item and r.item.key == key then return r end
        end
    end
    local rfc = RowFor("rfc")
    check(rfc and rfc.bosses:GetText():find("1/4", 1, true) and rfc.bossState == "progress", "some killed: in progress")
    for _, id in ipairs({ 2733, 2734, 2735 }) do FireEvent("ENCOUNTER_END", id, "Boss", 1, 5, 1) end
    Tick(1)
    rfc = RowFor("rfc")
    check(rfc.bosses:GetText():find("4/4", 1, true) and rfc.bossState == "complete", "all killed: complete")
    B.Clear()
    p.guide.showAll = nil
    UI.SetLevelingPretend(nil)
    UI.LevelingShow("zones")
    Tick(1)
end

check(#UISpecialFrames == 0 and PanelManagerCalls == 0, "no taint tripwires touched")
check(#ERRORS == 0, "no errors (" .. (ERRORS[1] or "none") .. ")")
