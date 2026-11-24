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
-- Chilli's addon never answers: No answer after 20 s.
Tick(20)
check(all.clans.Troll.status == "noanswer" and all.clans.Orc.status == "waiting", "Chilli: No answer; Bluey still waiting")
INJECT("YNM", Msg({ t = "CRP", id = "wrong-id", r = "Orc" }), "WHISPER", "Bluey Heeler"); Tick(1)
check(all.clans.Orc.status == "waiting", "a report for another roll is ignored")
INJECT("YNM", Msg({ t = "CRP", id = all.id, r = "Orc" }), "WHISPER", "Bluey Heeler"); Tick(1)
check(all.clans.Orc.status == "rolling", "Bluey started: Rolling")
INJECT("YNM", Msg({ t = "CRW", id = all.id, r = "Orc", w = "Bingo Heeler", n = 88 }), "WHISPER", "Bluey Heeler"); Tick(1)
check(all.clans.Orc.status == "won" and all.clans.Orc.winner == "Bingo Heeler" and all.clans.Orc.roll == 88, "the Orcs' winner: Bingo, 88")
-- An answer saying "not in a group".
INJECT("YNM", Msg({ t = "CRK", id = all.id, r = "Troll" }), "WHISPER", "Chilli Heeler"); Tick(1)
check(all.clans.Troll.status == "group", "Chilli's addon answered late: Not in a group")

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
check(block.Troll.status:GetText():find(L.CLANROLL_ALL_GROUP, 1, true), "the Trolls: Not in a group")
local noLeader = false
for _, b in pairs(block) do if b.status:GetText():find(L.CLANROLL_ALL_NOLEADER, 1, true) then noLeader = true end end
check(noLeader, "a clan with no leader set says so")
local shown = {}
for _, r in ipairs(ap.res) do if r:IsShown() then shown[#shown + 1] = r.left:GetText() .. " " .. r.right:GetText() end end
check(#shown >= 1 and shown[1]:find("Bingo", 1, true) and shown[1]:find("88", 1, true), "Winners: Bingo, 88 first")
local waiting = {}
for _, r in ipairs(ap.miss) do if r:IsShown() then waiting[#waiting + 1] = r.right:GetText() end end
check(table.concat(waiting, " "):find(L.CLANROLL_ALL_GROUP, 1, true), "Still waiting on: the Trolls, not in a group")
-- Announce: party or raid chat, or guild chat with Guild chat ticked; one line with each winner.
FAKE.group, FAKE.party = 2, { "Bingo Heeler" }
local w0 = #WHISPERS
ap.announce:Click(); Tick(1)
check(#WHISPERS == w0 + 1 and WHISPERS[#WHISPERS].kind == "PARTY" and WHISPERS[#WHISPERS].text:find("Bingo Heeler (88)", 1, true), "Announce: the winners to party chat")
ap.guild:SetChecked(true); ap.guild:Click(); Tick(1)
ap.announce:Click(); Tick(1)
check(#WHISPERS == w0 + 2 and WHISPERS[#WHISPERS].kind == "GUILD", "Guild chat ticked: to guild chat")
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
-- The first roll is still going (the Trolls might group up yet): Cancel it before asking again.
check(R.AllBusy() and ap.start:GetText():find(L.CLANROLL_ALL_CANCEL, 1, true), "still going: Cancel")
ap.start:Click(); Tick(1)
check(not R.AllBusy() and R.all.clans.Orc.status == "won" and R.all.clans.Troll.status == "cancelled",
    "Cancel: finished clans keep their winner, the rest are cancelled")
-- Untick the Trolls; every control goes to the leaders.
block.Troll.tick:SetChecked(false); block.Troll.tick:Click(); Tick(1)
check(not CA.Ticked("Troll") and CA.Ticked("Orc"), "the Trolls unticked")
ap.skip:SetChecked(true); ap.skip:Click()
ap.others:SetChecked(true); ap.others:Click(); Tick(1)
before = #SENT
ap.start:Click(); Tick(1)
local asks = Sent("CRA", before + 1)
check(R.all ~= all and #asks == 1 and asks[1].r == "Orc" and R.all.clans.Troll == nil, "Ask ticked clans: only the Orcs asked")
check(asks[1].o == true and asks[1].s == true and asks[1].tm == CA.Prefs().timer, "with every control: non-clan members, skip past winners, timer")
check(ap.status:GetText() == string.format(L.CLANROLL_ALL_ASKED, #R.all.order) and ap.clear:IsShown(), "how many were asked; Clear")
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
-- History keeps each all-clans roll; Clear takes the results off the screen.
local h = R.AllHistory()
check(#h == 2 and h[#h].id == R.all.id and h[1].clans.Orc.w == "Bingo Heeler", "History: every all-clans roll, with each clan's winner")
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
check(panel.msg:GetText() == "Gold for" and not panel.msg:IsEnabled() and panel.others:GetChecked() and panel.skip:GetChecked()
    and not panel.others:IsEnabled(), "the panel too: filled in, locked")
check(#Sent("CRP", before + 1) == 0 and (R.cur == nil or not R.cur.open), "nothing starts until I click Start")
pop.start:Click(); Tick(1)
check(R.cur.open and R.cur.ask and R.cur.ask.id == "A1-1" and R.asked == nil, "Start: my roll runs for Bluey's ask")
check(R.cur.msg == "Gold for" and R.cur.timer == 20 and R.cur.others and R.cur.skip, "with every control Bluey set")
check(mine0.msg == "My own", "and my own message stays mine")
local crp = Sent("CRP", before + 1)
check(#crp == 1 and crp[1]._target == "Bluey Heeler" and crp[1].id == "A1-1", "Bluey told it started")
FireEvent("CHAT_MSG_SYSTEM", "Bingo Heeler rolls 61 (1-100)")
Tick(21)
local crw = Sent("CRW", before + 1)
check(#crw == 1 and crw[1].w == "Bingo Heeler" and crw[1].n == 61 and crw[1].id == "A1-1", "the winner goes back to Bluey by itself")

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
SlashCmdList.YEAHNAHMATE("dev sim on"); Tick(20)
local sim = R.StartAll({ msg = "Roll for", item = "Lucky coin", timer = 10 })
Tick(1)
local fakes = 0
for _, row in pairs(sim.clans) do if row.to and ns.Sim.IsFake(row.to) then fakes = fakes + 1 end end
check(fakes >= 3, "fake leaders asked (" .. fakes .. ")")
Tick(20)
local won, group = 0, 0
for _, row in pairs(sim.clans) do
    if row.status == "won" then won = won + 1 end
    if row.status == "group" then group = group + 1 end
end
check(won >= 2 and group == 1, "fake leaders report winners (" .. won .. "), one not in a group")
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
