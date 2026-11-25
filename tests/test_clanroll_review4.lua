-- Clan roll review fixes (fourth review, before 0.28.0):
--   1. after a roll a manager asked me to run, my own setup comes back (theirs isn't saved as mine);
--   2. an ask opens the pop-out on the asked clan, even with an old closed roll of another clan;
--   3. a roll of a clan my My Clan panel isn't showing still opens the pop-out;
--   4. Start works while I'm only following another clan's roll;
--   5. a roll the manager cancelled says Cancelled, with no Announce;
--   and: a winner with no roll number doesn't break the panel, the roll view isn't lost before the
--   roster loads, Announce is throttled.
math.randomseed(17)
YeahNahMateDB = nil
FAKE.myRank = 0                 -- I'm the guild master (Ned Jones), an Orc
local ns = LoadAddon("YeahNahMate", "YeahNahMate")
LOGGED_IN = true
FireEvent("PLAYER_LOGIN")
local Ser = LibStub("AceSerializer-3.0")
local function Msg(t) t.v = 1; return Ser:Serialize(t) end
local R, L, UI, CU = ns.ClanRoll, ns.L, ns.UI, ns.ClanRollUI
ns.settings.sharePosition, ns.settings.shareProfessions = false, false
RANDOM_ROLL_RESULT = "%s rolls %d (%d-%d)"
function UnitRace() return "Orc", "Orc", 2 end
Tick(15)
INJECT("YNM", Msg({ t = "HI", ver = ns.VERSION, ra = "Orc", ro = "t" }), "GUILD", "Bluey Heeler")
INJECT("YNM", Msg({ t = "HI", ver = ns.VERSION, ra = "Orc", ro = "h" }), "GUILD", "Bingo Heeler")
INJECT("YNM", Msg({ t = "HI", ver = ns.VERSION, ra = "Troll", ro = "d" }), "GUILD", "Chilli Heeler")
Tick(2)
ns.Board.SetManager("Bluey Heeler", true); Tick(1)
FAKE.group, FAKE.party = 4, { "Bluey Heeler", "Bingo Heeler", "Chilli Heeler" }
local function Roll(name, n) FireEvent("CHAT_MSG_SYSTEM", string.format(RANDOM_ROLL_RESULT, name, n, 1, 100)) end
local function Ask(id, extra)
    local m = { t = "CRA", id = id, r = "Orc", m = "Gold for", i = "Axe", tm = 20 }
    for k, v in pairs(extra or {}) do m[k] = v end
    INJECT("YNM", Msg(m), "WHISPER", "Bluey Heeler"); Tick(1)
end

ns.settings.clanView = "mine"
UI.Open("clans"); Tick(1)
local p = CU.panel
local prefs = CU.Prefs()
prefs.msg = "My own"
p.msg:SetText("My own")

-- 1. Bluey asks; I run it from the panel; afterwards my own setup is back, and my next roll is mine.
Ask("R4-1")
check(p.msg:GetText() == "Gold for" and p.item:GetText() == "Axe", "1: the panel shows Bluey's setup")
CU.Start(p); Tick(1)
check(R.cur and R.cur.open and R.cur.ask and R.cur.msg == "Gold for", "1: my roll runs for Bluey's ask")
Roll("Bingo Heeler", 40)
Tick(21)
UI.Dirty(); Tick(1)
check(not R.cur.open and p.msg:GetText() == "My own" and p.item:GetText() == "", "1: once it's over, my own message is back and the item is empty")
CU.Start(p); Tick(1)
check(prefs.msg == "My own" and R.cur.msg == "My own", "1: my next roll uses my own message (Bluey's wasn't saved as mine)")
R.Stop(); Tick(1)
CU.ClosePop()

-- 2. An old closed roll of another clan (one I followed); then Bluey asks me to run the Orcs': the
--    pop-out shows the Orcs, with Start.
R.cur = { id = "old", race = "Troll", by = "Chilli Heeler", follower = true, open = false, rolls = {}, n = 0,
    timer = 0, msg = "Roll for" }
Ask("R4-2")
local pop = CU.Pop()
check(pop:IsShown() and pop.title:GetText():find("Orc", 1, true) and not pop.title:GetText():find("Troll", 1, true),
    "2: the pop-out shows the clan I was asked for, not the old Troll roll")
check(pop.setup:IsShown() and pop.start:IsEnabled(), "2: with Start")
R.asked = nil
CU.ClosePop()

-- 3. My Clan shows the Orcs; a Troll roll I follow isn't on screen, so the pop-out opens.
UI.Dirty(); Tick(1)
check(p.race == "Orc" and CU.RollVisible("Orc") and not CU.RollVisible("Troll"), "3: My Clan counts as seeing the Orcs' roll only")
ns.Fire("CLANROLL_FOLLOW", { race = "Troll" }); Tick(1)
check(CU.Pop():IsShown(), "3: another clan's roll opens the pop-out")
CU.ClosePop()

-- 4. Following an open Troll roll; Start for my own clan still works.
R.cur = { id = "f1", race = "Troll", by = "Chilli Heeler", follower = true, open = true, rolls = {}, n = 0,
    timer = 0, msg = "Roll for" }
CU.Start(p); Tick(1)
check(R.cur.race == "Orc" and R.cur.by == ns.me and R.cur.open, "4: Start runs my roll while I was following another clan's")
local mineR = R.cur
CU.Start(p); Tick(1)
check(R.cur == mineR, "4: a second click on my own open roll still does nothing")
R.Stop(); Tick(1)

-- 5. Bluey cancels the roll I'm running for them: Cancelled, no Announce.
Ask("R4-5")
CU.Start(p); Tick(1)
Roll("Bingo Heeler", 77)
INJECT("YNM", Msg({ t = "CRX", id = "R4-5", r = "Orc" }), "WHISPER", "Bluey Heeler"); Tick(1)
UI.Dirty(); Tick(1)
check(R.cur.cancelled and not R.cur.open, "5: the roll stopped")
check(p.result:GetText():find(L.CLANROLL_ALL_CANCELLED, 1, true) and not p.result:GetText():find(L.CLANROLL_NOBODY_SHORT, 1, true),
    "5: the panel says Cancelled, not Nobody rolled")
check(not p.announce:IsEnabled() and not p.whisper:IsEnabled(), "5: Announce is off")
CU.OpenPop(false, "Orc"); Tick(1)
check(CU.Pop().result:GetText():find(L.CLANROLL_ALL_CANCELLED, 1, true) and not CU.Pop().announce:IsShown(), "5: the pop-out too")
CU.ClosePop()
local w0 = #WHISPERS
check(not R.Announce(R.cur) and #WHISPERS == w0, "5: Announce sends nothing for a cancelled roll")

-- A finished roll with a winner but no roll number (a follower's end message without one): no error.
local e0 = #ERRORS
R.cur = { id = "w1", race = "Orc", by = ns.me, open = false, rolls = {}, n = 0, timer = 0, msg = "Roll for", winner = "Bingo Heeler" }
UI.Dirty(); Tick(1)
CU.OpenPop(false, "Orc"); Tick(1)
check(#ERRORS == e0 and p.result:GetText():find("Bingo", 1, true), "a winner with no roll number: shown, no error (" .. tostring(ERRORS[e0 + 1]) .. ")")
CU.ClosePop()

-- Announce: a second click straight away does nothing; after the gap it goes.
R.cur = { id = "a1", race = "Orc", by = ns.me, open = false, rolls = {}, n = 0, timer = 0, msg = "Roll for",
    winner = "Bingo Heeler", winRoll = 50, clicked = true }
Tick(R.ANNOUNCE_GAP)
w0 = #WHISPERS
check(R.Announce(R.cur) and not R.Announce(R.cur) and #WHISPERS == w0 + 1, "Announce: a quick second click is ignored")
Tick(R.ANNOUNCE_GAP + 0.1)
check(R.Announce(R.cur) and #WHISPERS == w0 + 2, "Announce: fine again after a moment")

-- The roll view, before my rank is known (right after a /reload): All clans shows, the setting stays.
ns.settings.clanView = "roll"
local realCan = R.CanStartAll
R.CanStartAll = function() return false end
UI.Dirty(); Tick(1)
check(ns.settings.clanView == "roll", "the roll view isn't lost while the roster loads")
R.CanStartAll = realCan
ns.settings.clanView = "mine"
UI.Dirty(); Tick(1)

-- Second pass (review of the fixes above).
-- a. /ynm roll (no clan given) shows the latest roll, not the clan the window showed last time.
CU.OpenPop(true, "Troll"); Tick(1)
CU.ClosePop()
R.cur = { id = "o1", race = "Orc", by = ns.me, open = false, rolls = {}, n = 0, timer = 0, msg = "Roll for",
    winner = "Bingo Heeler", winRoll = 61 }
CU.TogglePop(); Tick(1)
check(CU.Pop().title:GetText():find("Orc", 1, true) and CU.Pop().result:GetText():find("Bingo", 1, true),
    "a: /ynm roll shows my latest Orc result, not the old Troll window")
CU.ClosePop()

-- b. A failed Announce (not in a group) can be tried again straight away.
Tick(R.ANNOUNCE_GAP + 0.1)
FAKE.group, FAKE.party = 0, {}
w0 = #WHISPERS
check(not R.Announce(R.cur) and #WHISPERS == w0, "b: Announce out of a group fails")
FAKE.group, FAKE.party = 4, { "Bluey Heeler", "Bingo Heeler", "Chilli Heeler" }
check(R.Announce(R.cur) and #WHISPERS == w0 + 1, "b: and works at once when tried again in a group")

-- c. Followers of a cancelled roll see Cancelled; a followed roll's result waits for the starter's word.
R.cur = nil
INJECT("YNM", Msg({ t = "CRS", r = "Orc", id = "C-1", m = "Roll for", tm = 0, rd = 1 }), "GUILD", "Bluey Heeler"); Tick(1)
check(R.cur and R.cur.follower and R.cur.open, "c: following Bluey's roll")
R.cur.open = false                              -- closed on my screen, Bluey's word not in yet
check(CU.ResultText(R.cur) == "", "c: no result until the starter's word")
R.cur.open = true
INJECT("YNM", Msg({ t = "CRE", r = "Orc", id = "C-1", x = true }), "GUILD", "Bluey Heeler"); Tick(1)
UI.Dirty(); Tick(1)
check(R.cur.cancelled and p.result:GetText():find(L.CLANROLL_ALL_CANCELLED, 1, true), "c: a follower's panel says Cancelled")
INJECT("YNM", Msg({ t = "CRS", r = "Orc", id = "C-2", m = "Roll for", tm = 0, rd = 1 }), "GUILD", "Bluey Heeler"); Tick(1)
INJECT("YNM", Msg({ t = "CRE", r = "Orc", id = "C-2" }), "GUILD", "Bluey Heeler"); Tick(1)
check(CU.ResultText(R.cur):find(L.CLANROLL_NOBODY_SHORT, 1, true), "c: no winner from the starter: Nobody rolled")

-- d. An ask for my clan while I follow another clan's open roll: the pop-out shows my clan's setup and Start.
R.cur = { id = "t9", race = "Troll", by = "Chilli Heeler", follower = true, open = true, rolls = {}, n = 0, timer = 0, msg = "Roll for" }
Ask("R4-D")
pop = CU.Pop()
check(pop.title:GetText():find("Orc", 1, true) and pop.setup:IsShown() and pop.start:IsEnabled(), "d: the asked clan's setup and Start")
pop.start:Click(); Tick(1)
check(R.cur.race == "Orc" and R.cur.by == ns.me and R.cur.open and R.cur.ask, "d: Start in the pop-out runs it")
R.Stop(); Tick(1)
CU.ClosePop()

-- e. My Clan on History doesn't count as seeing the roll.
UI.Dirty(); Tick(1)
p.history = true
check(not CU.RollVisible("Orc"), "e: History showing: the pop-out would open")
p.history = false

-- f. My own roll for another clan is open: Start on this clan's panel is greyed out, and a click does nothing.
R.cur = { id = "t8", race = "Troll", by = ns.me, open = true, rolls = {}, n = 0, timer = 0, msg = "Roll for" }
UI.Dirty(); Tick(1)
check(p.start:IsShown() and not p.start:IsEnabled(), "f: Start greyed out while my Troll roll runs")
CU.Start(p); Tick(1)
check(R.cur.race == "Troll" and R.cur.open, "f: a click on it doesn't throw my open roll away")
R.cur.open = false
UI.Dirty(); Tick(1)

check(#ERRORS == 0, "no errors (" .. tostring(ERRORS[1]) .. ")")
