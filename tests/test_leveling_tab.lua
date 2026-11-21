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

-- Before 60: the tab says Leveling and opens on the guide.
FAKE.level = 40
UI.Open("leveling")
Tick(1)
local tab = TabNamed(L.TAB_LEVELING)
local p = Page()
local guideBtn, raidBtn = p.viewButtons.leveling, p.viewButtons.raids
local function Showing(key)
    local other = key == "raids" and guideBtn or raidBtn
    local mine = key == "raids" and raidBtn or guideBtn
    return p.box:IsShown() == (key == "raids") and p.guide:IsShown() == (key == "leveling")
        and mine.viewSel:IsShown() and not other.viewSel:IsShown()
end
check(tab ~= nil and tab.sel:IsShown(), "before 60 the tab is Leveling, and lit")
check(Showing("leveling"), "before 60 it opens on the leveling guide, its button marked")
check(guideBtn:GetText() == L.LEVELING_GUIDE and raidBtn:GetText() == L.RAID_ROSTER, "both views have a button")
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
check(Showing("leveling"), "coming back opens the view for my level")

-- Reaching 60 while it's open: the tab and the view change straight away.
FireEvent("PLAYER_LEVEL_UP", 60)
Tick(1)
check(TabNamed(L.TAB_RAIDS) ~= nil and TabNamed(L.TAB_LEVELING) == nil, "at 60 the tab is Raids")
check(Showing("raids"), "at 60 it opens on the raid roster")
guideBtn:Click()
Tick(1)
check(Showing("leveling") and TabNamed(L.TAB_RAIDS) ~= nil, "at 60 the guide is still there")

-- The dev console's pretend level.
UI.SetLevelingPretend(30)
Tick(1)
check(TabNamed(L.TAB_LEVELING) ~= nil and Showing("leveling"), "pretend 30: Leveling")
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
check(Named(G.Dungeons(15), "Hall of Thanes").tag == "enemy" and Named(G.Dungeons(15), "Ruins of Lordaeron").tag == nil, "Horde: Hall of Thanes is enemy land")
check(Named(G.Dungeons(30), "City of Dalaran").note:find("Tarren Mill", 1, true), "Horde gets the Horde attunement")
D.pretendFaction = "Alliance"
check(Named(G.Dungeons(25), "The Stockade") and not Named(G.Dungeons(15), "Ragefire Chasm"), "Alliance: Stockade, no Ragefire")
check(Named(G.Dungeons(15), "Ruins of Lordaeron").tag == "enemy", "Alliance: Ruins are enemy land")
check(Named(G.Dungeons(30), "City of Dalaran").note:find("Southshore", 1, true), "Alliance gets the Alliance attunement")
D.pretendFaction = nil

-- The page: rows, tooltip, pagers, and an empty level.
UI.SetLevelingPretend(40)
UI.Select("home"); UI.Select("leveling")
Tick(1)
local g = p.guide
check(g.zoneTitle:GetText() == string.format(L.GUIDE_ZONES_FOR, 40) and g.dungeonTitle:GetText() == string.format(L.GUIDE_DUNGEONS_FOR, 40), "titles say my level")
check(g.zones.rows[1]:IsShown() and g.zones.rows[1].item.best, "a best zone on top")
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
check(groups == 28, "28 quest groups (" .. groups .. ")")
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
check(g.lists:IsShown() and not g.questPanel:IsShown(), "Back returns to zones and dungeons")
C_Map.OpenWorldMap = nil
UI.LevelingOpenDungeon("rfd")
Tick(1)
mapRow:Click()
Tick(1)
check(UI.LevelingPinnedQuest() ~= nil and g.questPanel.hint:GetText() == L.GUIDE_PINNED_PRESS_M, "no map call on this client: pinned, press M")
g.questPanel.clear:Click()
UI.Select("home"); UI.Select("leveling")
Tick(1)
check(g.lists:IsShown(), "leaving the tab goes back to the lists")
UI.SetLevelingPretend(nil)
Tick(1)

check(#UISpecialFrames == 0 and PanelManagerCalls == 0, "no taint tripwires touched")
check(#ERRORS == 0, "no errors (" .. (ERRORS[1] or "none") .. ")")
