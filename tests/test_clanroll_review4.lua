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

check(#ERRORS == 0, "no errors (" .. tostring(ERRORS[1]) .. ")")
