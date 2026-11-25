-- The all-clans roll: the guild master or a manager asks each clan's leader (an online one with the
-- addon, a new enough one first) to run the roll in their own group. The leader's addon checks the
-- sender is the guild master or a manager, says it got it, opens the roll filled in with a pop-up;
-- the leader clicks Start; the start and the winner go back by themselves. Reports count only from
-- the person asked. The starter sees one row per clan.
math.randomseed(3)
YeahNahMateDB = nil
FAKE.myRank = 0                 -- I'm the guild master (Ned Jones)
local ns = LoadAddon("YeahNahMate", "YeahNahMate")
LOGGED_IN = true
FireEvent("PLAYER_LOGIN")
local Ser = LibStub("AceSerializer-3.0")
local function Msg(t) t.v = 1; return Ser:Serialize(t) end
local function Sent(t, from)
    local list = {}
    for i = (from or 1), #SENT do
        local ok, m = Ser:Deserialize(SENT[i].text)
        if ok and type(m) == "table" and m.t == t then m._channel = SENT[i].channel; m._target = SENT[i].target; list[#list + 1] = m end
    end
    return list
end
local R, L, UI = ns.ClanRoll, ns.L, ns.UI
ns.settings.sharePosition, ns.settings.shareProfessions = false, false
RANDOM_ROLL_RESULT = "%s rolls %d (%d-%d)"
function UnitRace() return "Orc", "Orc", 2 end
Tick(15)
-- Bluey (Officer) leads the Orcs; rank 3 (Member) leads the Trolls: Bingo (an old version), Chilli
-- (new), Bandit (offline). Bandit is a Tauren: no rank leads the Taurens.
INJECT("YNM", Msg({ t = "HI", ver = "0.28.0", ra = "Orc", ro = "t" }), "GUILD", "Bluey Heeler")
INJECT("YNM", Msg({ t = "HI", ver = "0.27.1", ra = "Orc", ro = "h" }), "GUILD", "Bingo Heeler")
INJECT("YNM", Msg({ t = "HI", ver = "0.28.0", ra = "Troll", ro = "d" }), "GUILD", "Chilli Heeler")
INJECT("YNM", Msg({ t = "ME", ra = "Tauren", ro = "" }), "GUILD", "Bandit Heeler")
Tick(2)
ns.Clans.SetRank("Orc", 1)
ns.Clans.SetRank("Troll", 3)
Tick(2)

-- Who runs each clan's roll.
check(R.PickLeader("Orc") == "Bluey Heeler", "the Orcs: Bluey, their leader")
check(R.PickLeader("Troll") == "Chilli Heeler", "the Trolls: Chilli (new enough) before Bingo (old) and Bandit (offline)")
check(select(2, R.PickLeader("Tauren")) == "noleader", "the Taurens: no leader rank set")
ns.Comm.users["Chilli Heeler"].ver = "0.27.1"
local who, old = R.PickLeader("Troll")
check(who ~= nil and old == true, "only old versions online: one of them, marked old")
ns.Comm.users["Chilli Heeler"].ver = "0.28.0"

-- Only the guild master or a manager may start one.
check(R.CanStartAll(), "the guild master may start an all-clans roll")

-- Start: asks go by whisper to each clan's pick.
local before = #SENT
local all = R.StartAll({ msg = "Roll for", item = "Wolf", timer = 30, countdown = true })
local asks = Sent("CRA", before + 1)
local to = {}
for _, a in ipairs(asks) do to[a.r] = a._target; check(a._channel == "WHISPER" and a.id == all.id and a.m == "Roll for" and a.i == "Wolf" and a.tm == 30, "ask for " .. a.r) end
check(to.Orc == "Bluey Heeler" and to.Troll == "Chilli Heeler" and to.Tauren == nil, "asked Bluey and Chilli")
check(all.clans.Orc.status == "waiting" and all.clans.Tauren.status == "noleader", "Orcs waiting, Taurens no leader")
-- Orc is my clan too, but I'm not its leader here: Bluey still runs it.

-- Reports: a forged one from Bingo is ignored; Bluey's count.
INJECT("YNM", Msg({ t = "CRP", id = all.id, r = "Orc" }), "WHISPER", "Bingo Heeler"); Tick(1)
check(all.clans.Orc.status == "waiting", "a report from someone not asked is ignored")
INJECT("YNM", Msg({ t = "CRK", id = all.id, r = "Orc", g = true }), "WHISPER", "Bluey Heeler"); Tick(1)
check(all.clans.Orc.status == "waiting" and all.clans.Orc.acked, "Bluey's addon got it")
-- Chilli's addon answers that he isn't in a group: the Trolls' roll is handed to the next who could
-- run it, Bingo (an old version, last in line); Chilli's ask is withdrawn as "handed on".
before = #SENT
INJECT("YNM", Msg({ t = "CRK", id = all.id, r = "Troll" }), "WHISPER", "Chilli Heeler"); Tick(1)
local cx0, ca0 = Sent("CRX", before + 1), Sent("CRA", before + 1)
check(#cx0 == 1 and cx0[1]._target == "Chilli Heeler" and cx0[1].h == true and #ca0 == 1 and ca0[1]._target == "Bingo Heeler"
    and all.clans.Troll.to == "Bingo Heeler" and all.clans.Troll.status == "waiting", "Chilli isn't in a group: handed on to Bingo")
-- Bingo's old addon never answers, and nobody's left: Needs an update after 20 s.
Tick(20)
check(all.clans.Troll.status == "update" and all.clans.Orc.status == "waiting", "Bingo: Needs an update; Bluey still waiting")
INJECT("YNM", Msg({ t = "CRP", id = "wrong-id", r = "Orc" }), "WHISPER", "Bluey Heeler"); Tick(1)
check(all.clans.Orc.status == "waiting", "a report for another roll is ignored")
INJECT("YNM", Msg({ t = "CRP", id = all.id, r = "Orc" }), "WHISPER", "Bluey Heeler"); Tick(1)
check(all.clans.Orc.status == "rolling", "Bluey started: Rolling")
INJECT("YNM", Msg({ t = "CRW", id = all.id, r = "Orc", w = "Bingo Heeler", n = 88 }), "WHISPER", "Bluey Heeler"); Tick(1)
check(all.clans.Orc.status == "won" and all.clans.Orc.winner == "Bingo Heeler" and all.clans.Orc.roll == 88, "the Orcs' winner: Bingo, 88")

-- The starter's screen: All clans roll beside the view switch opens its own view, laid out like My
-- Clan: the clans on the left (tick box, who's asked, how it's going), the roll on the right (Winners,
-- Still waiting on, Announce with Guild chat, Clear, History).
ns.settings.clanView = "mine"
UI.Open("clans"); Tick(1)
local cp
for _, o in ipairs(CREATED) do if o.cols and o.roleBtns then cp = o end end
local CA = ns.ClanRollAllUI
check(cp.rollBtn:IsShown(), "All clans roll on the bar for the guild master")
cp.rollBtn:Click(); Tick(1)
local col, ap = cp.allCol, cp.allPanel
check(ns.settings.clanView == "roll" and col:IsShown() and ap:IsShown() and not cp.roll:IsShown(), "its own view")
local block = {}
for _, b in ipairs(col.blocks) do if b:IsShown() then block[b.race] = b end end
check(block.Orc and block.Troll and block.Orc.tick:GetChecked() and block.Troll.tick:GetChecked(), "a block per clan, all ticked")
check(block.Orc.who:GetText():find("Bluey", 1, true) and block.Orc.status:GetText():find("88", 1, true), "the Orcs: Bluey asked, Bingo won with 88")
check(block.Troll.status:GetText():find(L.CLANROLL_ALL_UPDATE, 1, true) and block.Troll.who:GetText():find("Bingo", 1, true),
    "the Trolls: Bingo asked, Needs an update")
local noLeader = false
for _, b in pairs(block) do if b.status:GetText():find(L.CLANROLL_ALL_NOLEADER, 1, true) then noLeader = true end end
check(noLeader, "a clan with no leader set says so")
local shown = {}
for _, r in ipairs(ap.res) do if r:IsShown() then shown[#shown + 1] = r.left:GetText() .. " " .. r.right:GetText() end end
check(#shown >= 1 and shown[1]:find("Bingo", 1, true) and shown[1]:find("88", 1, true), "Winners: Bingo, 88 first")
local waiting = {}
for _, r in ipairs(ap.miss) do if r:IsShown() then waiting[#waiting + 1] = r.right:GetText() end end
check(table.concat(waiting, " "):find(L.CLANROLL_ALL_UPDATE, 1, true), "Still waiting on: the Trolls, needs an update")
-- Announce: guild chat (ticked to start with: I'm rarely in every clan's group), or untick it for
-- party or raid chat; one line with each winner.
FAKE.group, FAKE.party = 2, { "Bingo Heeler" }
local w0 = #WHISPERS
check(ap.guild:GetChecked(), "Guild chat is ticked to start with")
ap.announce:Click(); Tick(1)
check(#WHISPERS == w0 + 1 and WHISPERS[#WHISPERS].kind == "GUILD" and WHISPERS[#WHISPERS].text:find("Bingo Heeler (88)", 1, true), "Announce: the winners to guild chat")
ap.guild:SetChecked(false); ap.guild:Click(); Tick(1)
ap.announce:Click(); Tick(1)
check(#WHISPERS == w0 + 1, "a second Announce within 3 s does nothing (throttled)")
Tick(ns.ClanRoll.ANNOUNCE_GAP)
ap.announce:Click(); Tick(1)
check(#WHISPERS == w0 + 2 and WHISPERS[#WHISPERS].kind == "PARTY", "Guild chat unticked: to party chat")
-- A long one splits into lines that fit, never cutting a clan.
local long = { order = {}, clans = {}, msg = "Roll for", item = string.rep("x", 60) }
for i = 1, 30 do
    local race = "Orc" .. i
    long.order[i] = race
    long.clans[race] = { status = "won", winner = "Bartholomew-Realm", roll = 99 }
end
local realName = ns.Clans.RaceName
ns.Clans.RaceName = function(r) return r end
local lines = R.AllLines(long)
ns.Clans.RaceName = realName
local fits = true
for _, line in ipairs(lines) do if #line > 255 or line:find(", $") then fits = false end end
check(#lines >= 2 and fits and lines[2]:find(L.CLANROLL_ALL_LINE_MORE, 1, true) == 1, "a long announce: " .. #lines .. " lines that fit")
-- The first roll is over: the Orcs won, and the Trolls can't take part, which doesn't hold it up.
check(not R.AllBusy() and ap.start:GetText() == L.CLANROLL_ALL_START and ap.start:IsEnabled(),
    "over (one clan can't take part): Start roll is back, not Cancel")
check(ap.others == nil, "no Let non-clan members roll on the all-clans roll")
-- Untick the Trolls; every control goes to the leaders.
block.Troll.tick:SetChecked(false); block.Troll.tick:Click(); Tick(1)
check(not CA.Ticked("Troll") and CA.Ticked("Orc"), "the Trolls unticked")
ap.skip:SetChecked(true); ap.skip:Click(); Tick(1)
before = #SENT
ap.start:Click(); Tick(1)
local asks = Sent("CRA", before + 1)
check(R.all ~= all and #asks == 1 and asks[1].r == "Orc" and R.all.clans.Troll == nil, "Ask ticked clans: only the Orcs asked")
check(asks[1].o == nil and asks[1].s == true and asks[1].tm == CA.Prefs().timer, "with every control (skip past winners, timer), never non-clan members")
check(ap.status:GetText() == string.format(L.CLANROLL_ALL_ASKED, #R.all.order) and not ap.clear:IsShown(), "how many were asked; no Clear while it's going")
check(block.Orc.status:GetText():find(L.CLANROLL_ALL_WAITING, 1, true), "the Orcs: Waiting")
-- While it's going, Ask turns into Cancel; once a clan rolls, the time left shows beside it.
check(ap.start:GetText():find(L.CLANROLL_ALL_CANCEL, 1, true) and ap.start:IsEnabled() and R.AllBusy(), "going: Ask turns into Cancel")
local again = #SENT
CA.Ask(ap); Tick(1)
check(#Sent("CRA", again + 1) == 0, "a second Ask while it's going does nothing")
INJECT("YNM", Msg({ t = "CRK", id = R.all.id, r = "Orc", g = true }), "WHISPER", "Bluey Heeler")
INJECT("YNM", Msg({ t = "CRP", id = R.all.id, r = "Orc" }), "WHISPER", "Bluey Heeler"); Tick(1)
check(R.all.clans.Orc.status == "rolling" and ap.status:GetText():find(" s left", 1, true)
    and block.Orc.status:GetText():find("%ds"), "rolling: the time left beside Cancel and in the clan's line (" .. ap.status:GetText() .. ")")
before = #SENT
ap.start:Click(); Tick(1)
local cx = Sent("CRX", before + 1)
check(#cx == 1 and cx[1]._target == "Bluey Heeler" and R.all.clans.Orc.status == "cancelled" and not R.AllBusy(),
    "Cancel: Bluey is told, the Orcs show Cancelled")
INJECT("YNM", Msg({ t = "CRW", id = R.all.id, r = "Orc", w = "Bingo Heeler", n = 90 }), "WHISPER", "Bluey Heeler"); Tick(1)
check(R.all.clans.Orc.status == "cancelled" and ap.start:GetText() == L.CLANROLL_ALL_START, "a late winner is ignored; Ask is back")
-- A tie inside a clan: "Tie, rerolling" keeps it going; the reroll starts (Rolling again, with its
-- time) and its winner ends it.
before = #SENT
ap.start:Click(); Tick(1)
local tieAll = R.all
INJECT("YNM", Msg({ t = "CRK", id = tieAll.id, r = "Orc", g = true }), "WHISPER", "Bluey Heeler")
INJECT("YNM", Msg({ t = "CRP", id = tieAll.id, r = "Orc" }), "WHISPER", "Bluey Heeler")
INJECT("YNM", Msg({ t = "CRW", id = tieAll.id, r = "Orc", tie = { "Bingo Heeler", "Chilli Heeler" }, n = 97 }), "WHISPER", "Bluey Heeler"); Tick(1)
check(tieAll.clans.Orc.status == "tie" and R.AllBusy() and block.Orc.status:GetText():find(L.CLANROLL_ALL_TIE, 1, true),
    "a tie: Tie, rerolling, and it's still going")
INJECT("YNM", Msg({ t = "CRP", id = tieAll.id, r = "Orc", rd = 2 }), "WHISPER", "Bluey Heeler"); Tick(1)
check(tieAll.clans.Orc.status == "rolling" and tieAll.clans.Orc.endsAt ~= nil, "the reroll starts: Rolling, with its time")
INJECT("YNM", Msg({ t = "CRW", id = tieAll.id, r = "Orc", w = "Chilli Heeler", n = 41 }), "WHISPER", "Bluey Heeler"); Tick(1)
check(tieAll.clans.Orc.status == "won" and tieAll.clans.Orc.winner == "Chilli Heeler" and not R.AllBusy()
    and ap.start:GetText() == L.CLANROLL_ALL_START, "the reroll's winner ends it: Ask is back")
-- The overall winner: the highest roll among the clans' winners (both, if they tie on it).
local top, topRoll = R.TopOf({ Orc = { status = "won", winner = "Bingo Heeler", roll = 88 },
    Troll = { status = "won", winner = "Chilli Heeler", roll = 93 }, Tauren = { status = "none" } })
check(#top == 1 and top[1].winner == "Chilli Heeler" and top[1].race == "Troll" and topRoll == 93, "overall: the Trolls' Chilli, 93")
local tt, tr = R.TopOf({ Orc = { status = "won", winner = "Bingo Heeler", roll = 93 }, Troll = { status = "won", winner = "Chilli Heeler", roll = 93 } })
check(#tt == 2 and tr == 93, "a tie on the top roll: both named")
check(R.TopOf({ Orc = { status = "none" } }) == nil, "no winners: no overall winner")
check(ap.result:GetText():find("Chilli", 1, true) and ap.result:GetText():find("41", 1, true)
    and ap.resTitle:GetText():find("1 of", 1, true), "the panel: the overall winner, and how many are done")
check(ap.res[1].left:GetText():find("LeaderIcon", 1, true), "the top row is crowned")
local tl = R.AllLines(tieAll)
check(tl[#tl]:find(string.format(L.CLANROLL_ALL_LINE_TOP, "Chilli Heeler", 41), 1, true), "Announce ends with the overall winner")
-- A leader who reloads or drops mid-roll: 30 s past the timer with no word, the clan shows "No result"
-- and stops holding things up (the guild master starts it again when they're back).
ap.start:Click(); Tick(1)
local lost = R.all
INJECT("YNM", Msg({ t = "CRK", id = lost.id, r = "Orc", g = true }), "WHISPER", "Bluey Heeler")
INJECT("YNM", Msg({ t = "CRP", id = lost.id, r = "Orc" }), "WHISPER", "Bluey Heeler"); Tick(1)
check(lost.clans.Orc.status == "rolling" and R.AllBusy(), "the Orcs are rolling")
check(not ap.clear:IsShown() and R.ClearAll() == false and R.all == lost, "while it's going there's no Clear (Cancel is the way)")
Tick(lost.timer + R.LOST_AFTER + 2)
check(lost.clans.Orc.status == "noresult" and not R.AllBusy() and block.Orc.status:GetText():find(L.CLANROLL_ALL_NORESULT, 1, true)
    and ap.start:GetText() == L.CLANROLL_ALL_START, "no word 30 s after the timer: No result, and Start roll is back")
-- A new all-clans roll first withdraws the asks still out there (Bluey's lost one), then asks again.
-- A leader who doesn't answer at all is passed over for the next one in line after 20 s.
before = #SENT
local quiet = R.StartAll({ msg = "Roll for", timer = 10, only = { Orc = true, Troll = true } })
local wx = Sent("CRX", before + 1)
check(#wx == 1 and wx[1]._target == "Bluey Heeler" and wx[1].id == lost.id and not wx[1].h, "a new roll withdraws Bluey's leftover ask")
check(quiet.clans.Troll.to == "Chilli Heeler", "the Trolls: Chilli asked first")
before = #SENT
Tick(21)
local qx, qa = Sent("CRX", before + 1), Sent("CRA", before + 1)
check(#qx == 1 and qx[1]._target == "Chilli Heeler" and qx[1].h == true and #qa == 1 and qa[1]._target == "Bingo Heeler"
    and quiet.clans.Troll.to == "Bingo Heeler", "Chilli never answers: handed on to Bingo after 20 s")
INJECT("YNM", Msg({ t = "CRK", id = quiet.id, r = "Troll", g = true }), "WHISPER", "Chilli Heeler"); Tick(1)
check(quiet.clans.Troll.to == "Bingo Heeler" and quiet.clans.Troll.status == "waiting", "Chilli's late answer doesn't count any more")
R.CancelAll(); Tick(1)
-- Clear withdraws asks still out there too (here: none left, the Cancel told them).
before = #SENT
check(R.ClearAll() and R.all == nil and #Sent("CRX", before + 1) == 0, "Clear after Cancel: nothing more to tell anyone")
-- History keeps each all-clans roll; Clear takes the results off the screen.
local h = R.AllHistory()
check(#h == 5 and h[#h].id == quiet.id and h[1].clans.Orc.w == "Bingo Heeler", "History: every all-clans roll, with each clan's winner (" .. #h .. ")")
ap.clear:Click(); Tick(1)
check(R.all == nil and not ap.clear:IsShown() and not block.Orc.status:GetText():find(L.CLANROLL_ALL_WAITING, 1, true), "Clear")
ap.histBtn:Click(); Tick(1)
check(ap.hist[1]:IsShown() and ap.hist[2]:IsShown() and ap.hist[1].entry == h[#h], "History: newest first")
ap.histBtn:Click(); Tick(1)
-- Nothing ticked: nothing to ask.
col.none:Click(); Tick(1)
check(not ap.start:IsEnabled() and R.StartAll({ msg = "x", only = {} }) == nil, "None: Ask is off")
col.all:Click(); Tick(1)
check(ap.start:IsEnabled() and CA.Ticked("Troll"), "All: every clan ticked again")
CA.Prefs().others, CA.Prefs().skip, CA.Prefs().guild = false, false, false
cp.rollBtn:Click(); Tick(1)
check(ns.settings.clanView == "mine", "All clans roll again: back to My Clan")

-- The leader's side: Bluey (a manager now) asks me to run the Orcs' roll.
ns.Board.SetManager("Bluey Heeler", true); Tick(1)
local toasts = {}
local realToast = ns.Toast.Show
ns.Toast.Show = function(title, text, ...) toasts[#toasts + 1] = { title, text }; return realToast(title, text, ...) end
-- A member's ask is dropped.
INJECT("YNM", Msg({ t = "CRA", id = "A1-1", r = "Orc", m = "Roll for", i = "Axe", tm = 20, cd = true }), "WHISPER", "Bingo Heeler"); Tick(1)
check(R.asked == nil and #toasts == 0, "an ask from a member is dropped")
FAKE.group, FAKE.party = 3, { "Bluey Heeler", "Bingo Heeler" }
local mine0 = ns.ClanRollUI.Prefs()
mine0.msg, mine0.timer, mine0.others, mine0.skip = "My own", 60, false, false
before = #SENT
INJECT("YNM", Msg({ t = "CRA", id = "A1-1", r = "Orc", m = "Gold for", i = "Axe", tm = 20, cd = true, o = true, s = true }), "WHISPER", "Bluey Heeler"); Tick(1)
check(R.asked and R.asked.from == "Bluey Heeler" and R.asked.timer == 20, "Bluey's ask taken")
local ack = Sent("CRK", before + 1)
check(#ack == 1 and ack[1]._target == "Bluey Heeler" and ack[1].g == true, "my addon says got it (in a group), by itself")
check(#toasts == 1 and toasts[1][1]:find("Bluey", 1, true), "a pop-up: Bluey asks me to run a clan roll")
local pop = ns.ClanRollUI.Pop()
check(pop:IsShown() and pop.msg:GetText() == "Gold for" and pop.item:GetText() == "Axe" and pop.timer:GetText() == "20s"
    and pop.title:GetText():find("asked by Bluey", 1, true), "the roll window, filled in")
check(not pop.msg:IsEnabled() and not pop.item:IsEnabled() and not pop.down:IsEnabled() and not pop.up:IsEnabled(),
    "the guild master's setup can't be changed")
check(mine0.msg == "My own" and mine0.timer == 60, "my own setup is left alone")
local panel = ns.ClanRollUI.panel
ns.settings.clanView = "mine"; UI.Open("clans"); Tick(1)
check(panel.msg:GetText() == "Gold for" and not panel.msg:IsEnabled() and not panel.others:GetChecked() and panel.skip:GetChecked()
    and not panel.others:IsEnabled(), "the panel too: filled in, locked (never non-clan members, even if asked)")
check(#Sent("CRP", before + 1) == 0 and (R.cur == nil or not R.cur.open), "nothing starts until I click Start")
pop.start:Click(); Tick(1)
check(R.cur.open and R.cur.ask and R.cur.ask.id == "A1-1" and R.asked == nil, "Start: my roll runs for Bluey's ask")
check(R.cur.msg == "Gold for" and R.cur.timer == 20 and not R.cur.others and R.cur.skip, "with every control Bluey set (never non-clan members)")
check(mine0.msg == "My own", "and my own message stays mine")
local crp = Sent("CRP", before + 1)
check(#crp == 1 and crp[1]._target == "Bluey Heeler" and crp[1].id == "A1-1", "Bluey told it started")
FireEvent("CHAT_MSG_SYSTEM", "Bingo Heeler rolls 61 (1-100)")
Tick(21)
local crw = Sent("CRW", before + 1)
check(#crw == 1 and crw[1].w == "Bingo Heeler" and crw[1].n == 61 and crw[1].id == "A1-1", "the winner goes back to Bluey by itself")

-- A tie in the roll I'm running for Bluey: the reroll tells Bluey it started (round 2), and its winner goes back.
INJECT("YNM", Msg({ t = "CRA", id = "A1-T", r = "Orc", m = "Roll for", tm = 20 }), "WHISPER", "Bluey Heeler"); Tick(1)
R.Start({ race = "Orc" }); Tick(1)
FireEvent("CHAT_MSG_SYSTEM", "Bingo Heeler rolls 90 (1-100)")
FireEvent("CHAT_MSG_SYSTEM", "Bluey Heeler rolls 90 (1-100)")
before = #SENT
Tick(21)
local tw = Sent("CRW", before + 1)
check(#tw == 1 and tw[1].tie and #tw[1].tie == 2 and tw[1].id == "A1-T", "a tie goes back to Bluey")
R.Reroll(); Tick(1)
local rp = Sent("CRP", before + 1)
check(#rp == 1 and rp[1].rd == 2 and rp[1].id == "A1-T", "Reroll ties: Bluey is told round 2 started")
FireEvent("CHAT_MSG_SYSTEM", "Bluey Heeler rolls 12 (1-100)")
FireEvent("CHAT_MSG_SYSTEM", "Bingo Heeler rolls 70 (1-100)")
Tick(21)
tw = Sent("CRW", before + 1)
check(#tw == 2 and tw[2].w == "Bingo Heeler" and tw[2].n == 70, "and the reroll's winner goes back")

-- Start can't run twice from a quick second click.
R.Start({ race = "Orc", msg = "Roll for" }); Tick(1)
local first = R.cur
ns.ClanRollUI.Start(ns.ClanRollUI.panel); Tick(1)
check(R.cur == first and first.open, "a second Start click while it's open does nothing")
R.Stop(); Tick(1)

-- Bluey cancels. An ask I haven't started is dropped; only Bluey can cancel it.
INJECT("YNM", Msg({ t = "CRA", id = "A1-2", r = "Orc", m = "Roll for", tm = 20 }), "WHISPER", "Bluey Heeler"); Tick(1)
check(R.asked and R.asked.id == "A1-2", "a new ask from Bluey")
INJECT("YNM", Msg({ t = "CRX", id = "A1-2", r = "Orc" }), "WHISPER", "Bingo Heeler"); Tick(1)
check(R.asked and R.asked.id == "A1-2", "a cancel from someone else is ignored")
local t0 = #toasts
INJECT("YNM", Msg({ t = "CRX", id = "A1-2", r = "Orc" }), "WHISPER", "Bluey Heeler"); Tick(1)
check(R.asked == nil and #toasts == t0 + 1 and toasts[#toasts][1]:find("cancelled", 1, true), "Bluey's cancel: the ask is gone, a pop-up says so")
-- A roll I'm running for Bluey's ask stops: no winner, no history, no Roll over line, nothing sent back.
INJECT("YNM", Msg({ t = "CRA", id = "A1-3", r = "Orc", m = "Roll for", tm = 20 }), "WHISPER", "Bluey Heeler"); Tick(1)
R.Start({ race = "Orc" }); Tick(1)
check(R.cur.open and R.cur.ask and R.cur.ask.id == "A1-3", "my roll runs for Bluey's ask")
FireEvent("CHAT_MSG_SYSTEM", "Bingo Heeler rolls 77 (1-100)")
local h0, w0 = #R.History(), #WHISPERS
before = #SENT
INJECT("YNM", Msg({ t = "CRX", id = "A1-3", r = "Orc" }), "WHISPER", "Bluey Heeler"); Tick(1)
check(not R.cur.open and R.cur.winner == nil and #R.History() == h0 and #Sent("CRW", before + 1) == 0 and #WHISPERS == w0,
    "Bluey's cancel stops my roll: no winner, no history, no lines, no report")
-- Handed on (I said I'm not in a group): the ask is gone, and the pop-up says why.
INJECT("YNM", Msg({ t = "CRA", id = "A1-H", r = "Orc", m = "Roll for", tm = 20 }), "WHISPER", "Bluey Heeler"); Tick(1)
INJECT("YNM", Msg({ t = "CRX", id = "A1-H", r = "Orc", h = true }), "WHISPER", "Bluey Heeler"); Tick(1)
check(R.asked == nil and toasts[#toasts][1] == L.TOAST_ROLL_HANDED, "handed on: the ask is gone, the pop-up says it went to someone in a group")
-- An ask lapses after 30 minutes: "(asked by Bluey)" goes, and my own setup is back.
INJECT("YNM", Msg({ t = "CRA", id = "A1-E", r = "Orc", m = "Gold for", tm = 20 }), "WHISPER", "Bluey Heeler"); Tick(1)
UI.Dirty(); Tick(1)
check(panel.title:GetText():find("asked by Bluey", 1, true) and not panel.msg:IsEnabled(), "asked: the title says so, the setup is locked")
Tick(R.ASK_FOR + 5, 5)
UI.Dirty(); Tick(1)
check(R.AskedFor("Orc") == nil and not panel.title:GetText():find("asked by", 1, true), "30 minutes on: the ask has lapsed, the title is back to normal")
R.asked = nil
ns.ClanRollUI.ClosePop()

-- The guild master is a clan's second in command (no leader rank set): their own ask stays on their
-- screen (no messages), and the reports reach their own all-clans view.
ns.Clans.SetRank("Orc", nil); Tick(1)
ns.ClanChallenge.deputies.Orc = { who = "Ned Jones", un = GetServerTime() + 600 }
FAKE.group, FAKE.party = 2, { "Bingo Heeler" }
before = #SENT
local mine = R.StartAll({ msg = "Roll for", timer = 0 })
local cra = Sent("CRA", before + 1)
local toMe = false
for _, a in ipairs(cra) do if a.r == "Orc" then toMe = true end end
check(not toMe and mine.clans.Orc.to == "Ned Jones" and R.asked and R.asked.race == "Orc", "my own clan: asked on my screen, nothing sent")
check(mine.clans.Orc.status == "waiting" and mine.clans.Orc.acked, "and it answered itself")
R.Start({ race = "Orc", msg = "Roll for" })
check(mine.clans.Orc.status == "rolling", "my Start shows as Rolling")
FireEvent("CHAT_MSG_SYSTEM", "Bingo Heeler rolls 33 (1-100)")
R.Stop()
check(mine.clans.Orc.status == "won" and mine.clans.Orc.winner == "Bingo Heeler", "and my winner comes back to my own view")
check(#Sent("CRP", before + 1) == 0 and #Sent("CRW", before + 1) == 0, "no reports sent to myself")
ns.ClanRollUI.ClosePop()

-- Alone (fake guildies): the fake clan leaders answer, start and report a winner; one isn't in a group.
ns.ClanChallenge.deputies.Orc = nil       -- (from above) so nobody else can take the Orcs' roll
SlashCmdList.YEAHNAHMATE("dev sim on"); Tick(20)
check(R.StartAll({ msg = "x" }) == nil, "one all-clans roll at a time: a new one waits for Cancel")
R.CancelAll(); Tick(1)
local sim = R.StartAll({ msg = "Roll for", item = "Lucky coin", timer = 10 })
Tick(1)
local fakes = 0
for _, row in pairs(sim.clans) do if row.to and ns.Sim.IsFake(row.to) then fakes = fakes + 1 end end
check(fakes >= 3, "fake leaders asked (" .. fakes .. ")")
Tick(15)
local tied = 0
for _, row in pairs(sim.clans) do if row.status == "tie" then tied = tied + 1 end end
check(tied == 1 and R.AllBusy(), "one fake clan ties first: Tie, rerolling")
Tick(15)
Tick(40)                                  -- (the real Troll leader never answers: a fake one takes it over)
local won, group = 0, 0
for _, row in pairs(sim.clans) do
    if row.status == "won" then won = won + 1 end
    if row.status == "group" then group = group + 1 end
end
check(sim.clans.Troll.status == "won" and ns.Sim.IsFake(sim.clans.Troll.to), "the Trolls' real leader never answered: a fake one took it and won")
check(won >= 2 and group == 1 and not R.AllBusy(), "fake leaders report winners (" .. won .. "), one not in a group; then it's over")
SlashCmdList.YEAHNAHMATE("dev sim off"); Tick(1)

-- /ynm dev rollreset: everything fresh.
R.Start({ race = "Orc", msg = "Gold for" }); Tick(1)
R.StartAll({ msg = "Roll for", timer = 0 }); Tick(1)
ns.ClanRollUI.Prefs().timer, ns.ClanRollUI.Prefs().others = 60, true
ns.ClanRollAllUI.SetTicked("Troll", false)
ns.ClanRollAllUI.Prefs().timer = 10
check(#R.History() > 0 or R.cur ~= nil, "something to reset")
SlashCmdList.YEAHNAHMATE("dev rollreset"); Tick(1)
local pr = ns.ClanRollUI.Prefs()
check(R.cur == nil and R.all == nil and R.asked == nil and #R.History() == 0, "reset: no roll, no all-clans roll, no history")
check(pr.timer == 30 and pr.countdown == true and not pr.others and pr.msg == L.CLANROLL_DEFAULT and ns.ClanRollAllUI.Ticked("Troll")
    and ns.ClanRollAllUI.Prefs().timer == 30 and #R.AllHistory() == 0,
    "reset: the setup back to the defaults, every clan ticked")
check(not R.PastWinner("Bingo Heeler", "Orc"), "reset: no past winners")
