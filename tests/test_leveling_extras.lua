-- The Leveling tab's newer pages: Bag quests, the Cozy Sleeping Bag chain, Keys, and Mounts.
math.randomseed(26)
YeahNahMateDB = nil
dofile("tests/fake_questiedb.lua")
LibQuestieDB = FakeQuestieDB()
local ns = LoadAddon("YeahNahMate", "YeahNahMate")
LOGGED_IN = true
FireEvent("PLAYER_LOGIN")
Tick(3)
ns.settings.sharePosition, ns.settings.shareProfessions = false, false
local UI, L, G, E, D = ns.UI, ns.L, ns.LevelGuide, ns.LevelExtras, ns.Dungeons

local done, inLog, have, known = {}, {}, {}, {}
C_QuestLog = C_QuestLog or {}
C_QuestLog.IsQuestFlaggedCompleted = function(id) return done[id] == true end
local realInLog = ns.Questions.InMyLog
ns.Questions.InMyLog = function(id) return inLog[id] == true end
C_Item = C_Item or {}
C_Item.GetItemCount = function(id) return have[id] or 0 end
C_SpellBook = C_SpellBook or {}
C_SpellBook.IsSpellKnown = function(id) return known[id] == true end
local race, class = "Tauren", "WARRIOR"
UnitRace = function() return race, race, 6 end
UnitClass = function() return class, class, class == "WARLOCK" and 9 or (class == "PALADIN" and 2 or 1) end
local opened
C_Map.OpenWorldMap = function(id) opened = id end

UI.Open("leveling")
Tick(1)
local p
for _, o in ipairs(CREATED) do if o.viewButtons then p = o end end
local g = p.guide

-- Every view's button fits the page.
local count, widest = 0, 0
for _, b in pairs(p.viewButtons) do
    count = count + 1
    widest = math.max(widest, b._pt[2] + 100)
end
check(count == 7 and widest <= 736, "seven views fit the row (" .. widest .. ")")

-- Bag quests: the shared quest list, with the bag in place of the quest giver.
p.viewButtons.bags:Click()
Tick(1)
check(UI.LevelingView() == "bags" and g.questPanel:IsShown(), "Bag quests uses the shared quest list")
check(not g.questPanel.back:IsShown() and not g.questPanel.entrance:IsShown(), "no Back or entrance buttons on it")
local roots, quests = G.QuestTree("bags")
check(#roots == 4 and quests == 7, "four storylines, lead-ins included, the four turn-ins as one", #roots .. "," .. quests)
local supply
for _, r in ipairs(roots) do if r.id == 9221 then supply = r end end
check(supply and supply.name == "Superior Armaments of Battle" and #supply.ids == 4, "the Supply Bag is one row")
check(G.BagFor(supply).slots == 18 and G.BagFor(supply).name == "Supply Bag", "and knows its bag")
-- A lead-in joins its bag quest's storyline; the closed row shows the bag, the lead-in itself doesn't have one.
local stepping, riddle
for _, r in ipairs(roots) do
    if r.ids[1] == 79007 then stepping = r end
    if r.name == "Cortello's Riddle" then riddle = r end
end
check(stepping and #stepping.chain == 2 and stepping.chain[2].id == 79192, "Stepping Stones hangs under its lead-in")
check(G.BagFor(stepping).name == "Old Toolbox" and G.BagFor(stepping, true) == nil, "the storyline has the bag, its first step doesn't")
-- A chain with one name throughout stays three steps, each with its own status.
check(riddle and #riddle.chain == 3 and riddle.chain[1].id == 624 and riddle.chain[3].id == 626, "same-named steps stay separate, in order")
done[624] = true
check(G.QuestState(riddle.chain[1]) == "done" and G.QuestState(riddle.chain[2]) == nil, "only the step handed in is done")
local chainDone, chainTotal = G.ChainProgress(riddle)
check(chainDone == 1 and chainTotal == 3, "the storyline says 1 of 3")
check(G.QuestPlan(riddle.chain[3]).target.id == 625, "the last step points at the next one to do")
done[624] = nil
local dungeonRiddle, riddleRows
riddleRows = 0
for _, q in ipairs(G.Quests("zf")) do
    if q.name == "Cortello's Riddle" then dungeonRiddle, riddleRows = q, riddleRows + 1 end
end
check(riddleRows == 1 and #dungeonRiddle.ids == 3, "the dungeon list still shows that chain as one row")
done[624] = true
check(G.QuestState(dungeonRiddle) == nil, "and only its final step finishes it")
done[624] = nil
done[9226] = true
check(G.QuestState(supply) == "done", "any rank's turn-in marks it done")
done[9226] = nil
local head
for _, h in ipairs(g.questPanel.heads) do if h.key == "giver" then head = h end end
check(head.label:GetText() == L.GUIDE_BAG_COL, "the column is the bag")
local shown = false
for _, r in ipairs(g.quests.rows) do
    if r:IsShown() and r.giver:GetText():find("12  Old Toolbox", 1, true) then shown = true end
end
check(shown, "a row shows slots and bag")
head:GetScript("OnClick")(head)     -- sort by bag size, smallest first
Tick(1)
check(g.quests.rows[1].giver:GetText():find("Old Toolbox", 1, true), "sorting by bag goes by slots")
head:GetScript("OnClick")(head)
Tick(1)
check(g.quests.rows[1].giver:GetText():find("Supply Bag", 1, true), "biggest first when reversed")
head:GetScript("OnClick")(head)
Tick(1)
local classNames = {}
for _, r in ipairs(G.QuestTree("class")) do classNames[r.name] = true end
check(not classNames["Superior Armaments of Battle"], "a bag turn-in doesn't join the class list")

-- A closed storyline with a fork points at the quest in my log, not just the first branch.
do
    local a, b = { id = 90001, ids = { 90001 }, name = "Branch A", children = {} }, { id = 90002, ids = { 90002 }, name = "Branch B", children = {} }
    local root = { id = 90000, ids = { 90000 }, name = "Fork", children = { a, b } }
    root.chain = { root, a, b }
    done[90000], inLog[90002] = true, true
    local _, _, focus, furthest = G.ChainProgress(root)
    check(focus == b and furthest == "log", "a fork's closed row follows the branch in my log")
    inLog[90002] = nil
    _, _, focus = G.ChainProgress(root)
    check(focus == a, "nothing in my log: the first unfinished branch")
    done[90000] = nil
end

-- The sleeping bag: each faction starts on its own continent and hands in on the other.
D.pretendFaction = "Horde"
local rows, n, total = E.SleepingBag()
check(total == 6 and n == 0 and rows[1].state == "next" and rows[2].state == nil, "Horde: step 1 is next")
check(rows[1].place.map == 1413, "Horde starts in The Barrens")
inLog[79007] = true
rows = E.SleepingBag()
check(rows[1].state == "log" and rows[1].place.map == 1436, "in the log: go and hand in at Westfall")
inLog[79007], done[79007] = nil, true
rows, n = E.SleepingBag()
check(n == 1 and rows[1].state == "done" and rows[1].place == nil and rows[2].state == "next", "handed in: on to step 2")
check(rows[2].place.map == 1436 and rows[2].place.name == "Nailed Plank", "Horde's plank is in Westfall")
done[79007] = nil
D.pretendFaction = "Alliance"
rows = E.SleepingBag()
check(rows[1].place.map == 1436 and rows[1].detail:find("Click the remains at Alexston Farmstead, Westfall", 1, true), "Alliance starts in Westfall")
inLog[79008] = true
rows = E.SleepingBag()
check(rows[1].place.map == 1413, "and hands in at The Barrens")
inLog[79008] = nil
done[79008] = true
rows = E.SleepingBag()
check(rows[2].place.map == 1413, "Alliance's plank is in The Barrens")
done[79008] = nil
D.pretendFaction = "Horde"
done[79976] = true
rows, n = E.SleepingBag()
check(n == 6 and rows[1].state == "done" and rows[6].state == "done", "the last quest done means the whole chain is")
p.viewButtons.sleeping:Click()
Tick(1)
check(g.sleeping.title:GetText() == string.format(L.GUIDE_SLEEP_TITLE, 6, 6) and g.sleeping.hint:GetText() == L.GUIDE_SLEEP_DONE, "the page says you've got it")
done[79976] = nil
Tick(1)
UI.Dirty()
Tick(1)
local row = g.sleeping.list.rows[1]
check(row:IsShown() and row.state:GetText():find(L.GUIDE_NEXT, 1, true) and row.map:GetText() == L.GUIDE_SHOW_MAP, "the next step offers the map")
row:GetScript("OnEnter")(row); row:GetScript("OnLeave")(row)
opened = nil
row:Click()
Tick(1)
check(opened == 1413 and UI.LevelingPinnedQuest().id == "object:415106", "clicking pins it and opens the map")
Tick(3)
g.sleeping.clear:Click()
Tick(1)
check(UI.LevelingPinnedQuest() == nil, "the pin clears")

-- Keys: what you hold, by item or by the quest that gave it, and per faction.
local keys, got, all = E.Keys()
check(all == 12 and got == 0, "twelve keys, none yet")
local function Key(name)
    for _, k in ipairs(E.Keys()) do if k.tipName == name then return k end end
end
have[7146] = 1
check(Key("The Scarlet Key").state == "done" and Key("The Scarlet Key").place == nil, "holding a key ticks it")
done[5511] = true
check(Key("Skeleton Key").state == "done", "the quest that gave it counts, even if the key's in the bank or used")
done[5511], have[7146] = nil, nil
check(Key("Dalaran Sewer Key").detail:find("Tarren Mill", 1, true), "Horde's Dalaran route")
D.pretendFaction = "Alliance"
check(Key("Dalaran Sewer Key").detail:find("Southshore", 1, true), "Alliance's Dalaran route")
D.pretendFaction = "Horde"
p.viewButtons.keys:Click()
Tick(1)
check(g.keys.title:GetText() == string.format(L.GUIDE_KEYS_TITLE, 0, 12), "the Keys page shows the count")

-- Mounts: for my race and class.
local function Mount(list, name)
    for _, m in ipairs(list) do if m.name == name then return m end end
end
local m = E.Mounts(30)
check(Mount(m, L.GUIDE_MOUNT_APPRENTICE).stateText == string.format(L.GUIDE_FROM_LEVEL, 40), "under 40: says the level")
m = E.Mounts(40)
local app = Mount(m, L.GUIDE_MOUNT_APPRENTICE)
check(app.state == "next" and app.detail:find("Kar Stormsinger", 1, true) and app.place.map == 1412, "at 40: my race's trainer, on the map")
check(Mount(m, L.GUIDE_MOUNT_JOURNEYMAN).state == nil, "Journeyman waits for 60")
known[33388] = true
m = E.Mounts(60)
check(Mount(m, L.GUIDE_MOUNT_APPRENTICE).state == "done" and Mount(m, L.GUIDE_MOUNT_JOURNEYMAN).state == "next", "Apprentice known, Journeyman next")
known[33388], known[33391] = nil, true
m = E.Mounts(60)
check(Mount(m, L.GUIDE_MOUNT_APPRENTICE).state == "done" and Mount(m, L.GUIDE_MOUNT_JOURNEYMAN).state == "done", "Journeyman implies Apprentice")
known[33391] = nil
class = "WARLOCK"
m = E.Mounts(40)
check(Mount(m, "Summon Felsteed") and Mount(m, L.GUIDE_MOUNT_APPRENTICE).detail == L.GUIDE_MOUNT_APPRENTICE_CLASS, "Warlocks get their quest")
done[4490] = true
check(Mount(E.Mounts(40), "Summon Felsteed").state == "done", "and it ticks off")
done[4490] = nil
class = "PALADIN"
check(Mount(E.Mounts(40), "A Paladin's Steed"), "a Horde Paladin's quest")
D.pretendFaction = "Alliance"
race = "Human"
check(Mount(E.Mounts(40), "The Tome of Nobility"), "an Alliance Paladin's quest")
D.pretendFaction, class = "Horde", "WARRIOR"
race = "Dwarf"
app = Mount(E.Mounts(40), L.GUIDE_MOUNT_APPRENTICE)
check(app.place == nil and app.zone == 1426, "no exact spot: opens the zone instead")
race = "Pandaren"
check(Mount(E.Mounts(40), L.GUIDE_MOUNT_APPRENTICE).detail == L.GUIDE_MOUNT_NO_RACE, "a race we don't list doesn't error")
race = "Tauren"
p.viewButtons.mounts:Click()
Tick(1)
check(g.mounts.title:GetText() == L.GUIDE_MOUNTS_TITLE and g.mounts.list.rows[1]:IsShown(), "the Mounts page draws")

-- Every race and every key's data is complete.
for token, r in pairs(E.RACES) do
    check(E.NPC_NAMES[r.trainer] and E.NPC_NAMES[r.vendor] and r.where, token .. " has a trainer and vendor")
end

-- Without QuestieDB: the guides still read and tick off, with no map pins.
LibQuestieDB = nil
ns.LiveQuests.Reset()
rows, n, total = E.SleepingBag()
check(total == 6 and rows[1].state == "next" and rows[1].place == nil and rows[1].detail ~= "", "no QuestieDB: steps still read")
done[79007] = true
check(select(2, E.SleepingBag()) == 1, "and still tick off")
done[79007] = nil
check(E.Keys()[3].place == nil, "keys have no pin")
check(Mount(E.Mounts(40), L.GUIDE_MOUNT_APPRENTICE).place == nil, "mounts have no pin")
p.viewButtons.sleeping:Click()
Tick(1)
p.viewButtons.keys:Click()
Tick(1)
p.viewButtons.mounts:Click()
Tick(1)
p.viewButtons.bags:Click()
Tick(1)
check(g.questPanel.notice:IsShown(), "Bag quests shows the QuestieDB notice")
LibQuestieDB = FakeQuestieDB()
ns.LiveQuests.Reset()
p.viewButtons.zones:Click()
Tick(1)

ns.Questions.InMyLog = realInLog
D.pretendFaction = nil
check(#UISpecialFrames == 0 and PanelManagerCalls == 0, "no taint tripwires touched")
check(#ERRORS == 0, "no errors (" .. (ERRORS[1] or "none") .. ")")
