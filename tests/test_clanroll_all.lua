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

-- The starter's screen: the panel's All clans roll view, one row per clan.
ns.settings.clanView = "mine"
UI.Open("clans"); Tick(1)
local cp
for _, o in ipairs(CREATED) do if o.cols and o.roleBtns then cp = o end end
local p = cp.roll
check(p.allBtn:IsShown(), "All clans roll button for the guild master")
p.allBtn:Click(); Tick(1)
check(p.mode == "all" and p.start:GetText() == L.CLANROLL_ALL_START and not p.others:IsShown() and not p.announce:IsShown(), "All clans view")
local rows = {}
for _, row in ipairs(p.allRows) do if row:IsShown() then rows[#rows + 1] = row.left:GetText() .. " = " .. row.right:GetText() end end
local text = table.concat(rows, " | ")
check(text:find("Bingo", 1, true) and text:find("88", 1, true) and text:find(L.CLANROLL_ALL_GROUP, 1, true)
    and text:find(L.CLANROLL_ALL_NOLEADER, 1, true) and text:find("Bluey", 1, true), "rows: winner, not in a group, no leader")
-- Ask every clan from the panel: a new round of asks.
before = #SENT
p.start:Click(); Tick(1)
check(R.all ~= all and #Sent("CRA", before + 1) == 2, "Ask every clan from the panel")
p.allBtn:Click(); Tick(1)
check(p.mode == nil and p.start:GetText() == L.CLANROLL_START_BTN and p.others:IsShown(), "One clan: back to my clan's roll")

-- The leader's side: Bluey (a manager now) asks me to run the Orcs' roll.
ns.Board.SetManager("Bluey Heeler", true); Tick(1)
local toasts = {}
local realToast = ns.Toast.Show
ns.Toast.Show = function(title, text, ...) toasts[#toasts + 1] = { title, text }; return realToast(title, text, ...) end
-- A member's ask is dropped.
INJECT("YNM", Msg({ t = "CRA", id = "A1-1", r = "Orc", m = "Roll for", i = "Axe", tm = 20, cd = true }), "WHISPER", "Bingo Heeler"); Tick(1)
check(R.asked == nil and #toasts == 0, "an ask from a member is dropped")
FAKE.group, FAKE.party = 3, { "Bluey Heeler", "Bingo Heeler" }
before = #SENT
INJECT("YNM", Msg({ t = "CRA", id = "A1-1", r = "Orc", m = "Gold for", i = "Axe", tm = 20, cd = true }), "WHISPER", "Bluey Heeler"); Tick(1)
check(R.asked and R.asked.from == "Bluey Heeler" and R.asked.timer == 20, "Bluey's ask taken")
local ack = Sent("CRK", before + 1)
check(#ack == 1 and ack[1]._target == "Bluey Heeler" and ack[1].g == true, "my addon says got it (in a group), by itself")
check(#toasts == 1 and toasts[1][1]:find("Bluey", 1, true), "a pop-up: Bluey asks me to run a clan roll")
local pop = ns.ClanRollUI.Pop()
check(pop:IsShown() and pop.msg:GetText() == "Gold for" and pop.item:GetText() == "Axe" and pop.timer:GetText() == "20s"
    and pop.title:GetText():find("asked by Bluey", 1, true), "the roll window, filled in")
check(#Sent("CRP", before + 1) == 0 and (R.cur == nil or not R.cur.open), "nothing starts until I click Start")
pop.start:Click(); Tick(1)
check(R.cur.open and R.cur.ask and R.cur.ask.id == "A1-1" and R.asked == nil, "Start: my roll runs for Bluey's ask")
local crp = Sent("CRP", before + 1)
check(#crp == 1 and crp[1]._target == "Bluey Heeler" and crp[1].id == "A1-1", "Bluey told it started")
FireEvent("CHAT_MSG_SYSTEM", "Bingo Heeler rolls 61 (1-100)")
Tick(21)
local crw = Sent("CRW", before + 1)
check(#crw == 1 and crw[1].w == "Bingo Heeler" and crw[1].n == 61 and crw[1].id == "A1-1", "the winner goes back to Bluey by itself")
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
