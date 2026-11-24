-- The Clan roll panel on the Clans tab's My Clan view, driven by clicks: drag an item in, step the
-- timer, Start (posts the Start line), live results and Who hasn't rolled, the time left and the big
-- countdown, Stop, Announce with Whisper winner, Reroll ties, History, and a member's read-only view.
math.randomseed(11)
YeahNahMateDB = nil
FAKE.myRank = 0
local ns = LoadAddon("YeahNahMate", "YeahNahMate")
LOGGED_IN = true
FireEvent("PLAYER_LOGIN")
local Ser = LibStub("AceSerializer-3.0")
local function Msg(t) return Ser:Serialize(t) end
local R, L, UI = ns.ClanRoll, ns.L, ns.UI
ns.settings.sharePosition, ns.settings.shareProfessions = false, false
RANDOM_ROLL_RESULT = "%s rolls %d (%d-%d)"
function UnitRace() return "Orc", "Orc", 2 end
Tick(15)
INJECT("YNM", Msg({ v = 1, t = "HI", ver = ns.VERSION, ra = "Orc", ro = "t" }), "GUILD", "Bluey Heeler")
INJECT("YNM", Msg({ v = 1, t = "HI", ver = ns.VERSION, ra = "Orc", ro = "h" }), "GUILD", "Bingo Heeler")
INJECT("YNM", Msg({ v = 1, t = "HI", ver = ns.VERSION, ra = "Troll", ro = "d" }), "GUILD", "Chilli Heeler")
Tick(2)
FAKE.group, FAKE.party = 4, { "Bluey Heeler", "Bingo Heeler", "Chilli Heeler" }
local function Roll(name, n) FireEvent("CHAT_MSG_SYSTEM", string.format(RANDOM_ROLL_RESULT, name, n, 1, 100)) end

ns.settings.clanView = "mine"
UI.Open("clans")
Tick(1)
local cp
for _, o in ipairs(CREATED) do if o.cols and o.roleBtns then cp = o end end
local p = cp.roll
check(p:IsShown() and p.title:GetText():find("Orc", 1, true), "the Clan roll panel shows for my clan")
check(p.start:IsShown() and p.start:IsEnabled() and p.msg:GetText() == "Roll for", "Start ready, message 'Roll for'")

-- Drag an item from the bags onto the item box.
local link = "|cff0070dd|Hitem:2244::::::::22:::::::|h[Krol Blade]|h|r"
FAKE.cursor = { "item", 2244, link }
p.item._scripts.OnReceiveDrag(p.item)
check(p.item:GetText() == link and FAKE.cursor == nil, "the dragged item fills the box")

-- The timer: 30 by default; > to 60 (and no further); < back to 30.
check(p.timer:GetText() == "30s", "timer 30 s by default")
p.up:Click(); Tick(1)
check(p.timer:GetText() == "60s" and not p.up:IsEnabled(), "> steps to 60, the most")
p.down:Click(); Tick(1)
check(p.timer:GetText() == "30s", "< back to 30")

-- Start.
local chat0 = #WHISPERS
p.start:Click(); Tick(1)
check(R.cur and R.cur.open and R.cur.timer == 30 and R.cur.item == link, "Start opens a 30 s roll for the item")
check(WHISPERS[chat0 + 1].kind == "PARTY" and WHISPERS[chat0 + 1].text == "Roll for " .. link .. " - type /roll, 30 seconds",
    "Start posts its line to party chat")
check(p.stop:IsShown() and not p.start:IsShown() and not p.msg:IsEnabled() and not p.item:IsEnabled(),
    "while rolling: Stop, the setup locked")
check(p.missTitle:GetText() == string.format(L.CLANROLL_MISSING, 3), "3 haven't rolled")

Roll("Bluey Heeler", 40)
Roll("Bingo Heeler", 88)
Roll("Bingo Heeler", 99)
Tick(1)
check(p.res[1].left:GetText():find("Bingo", 1, true) and p.res[1].right:GetText():find("88", 1, true)
    and p.res[2].left:GetText():find("Bluey", 1, true) and not p.res[3]:IsShown(), "results highest first, the repeat left out")
check(p.res[1].right:GetText():find(ns.GOLD, 1, true), "the highest in gold")
check(p.missTitle:GetText() == string.format(L.CLANROLL_MISSING, 1) and p.miss[1].left:GetText():find("Ned", 1, true),
    "only I haven't rolled")
check(p.status:GetText():find("s left", 1, true), "time left shown")

-- The countdown shows big on screen near the end.
Tick(24)
check(ns.ClanRollUI.Big() and ns.ClanRollUI.Big():IsShown() and ns.ClanRollUI.Big().text:GetText() == "Ending in 5", "'Ending in 5'")
Tick(3)
check(ns.ClanRollUI.Big().text:GetText() == "3" or ns.ClanRollUI.Big().text:GetText() == "2", "then 3, 2 ...")
Tick(4)
check(not R.cur.open and p.result:GetText():find("Bingo", 1, true), "the timer closes it: Bingo wins")
check(WHISPERS[#WHISPERS].text == "Roll over: Roll for " .. link, "Roll over posted by the timer")
check(p.start:IsShown() and p.announce:IsEnabled() and p.whisper:IsEnabled() and not p.reroll:IsEnabled(),
    "after: Announce and Whisper winner on, nothing to reroll")

-- Announce with Whisper winner ticked.
p.whisper:SetChecked(true); p.whisper:Click()      -- the game ticks it, then OnClick
check(ns.settings.clanRoll.whisper == true, "Whisper winner ticked (kept)")
local chat1 = #WHISPERS
p.announce:Click(); Tick(1)
check(#WHISPERS == chat1 + 2 and WHISPERS[chat1 + 1].text:find("winner: Bingo Heeler (88)", 1, true)
    and WHISPERS[chat1 + 2].kind == "WHISPER" and WHISPERS[chat1 + 2].target == "Bingo Heeler", "Announce posts and whispers Bingo")

-- A tie, then Reroll ties (posts the reroll's Start line).
p.up:Click(); p.down:Click(); p.down:Click(); p.down:Click(); p.down:Click(); Tick(1)
check(p.timer:GetText() == L.CLANROLL_TIMER_OFF and not p.countdown:IsEnabled(), "timer Off: no countdown")
p.start:Click(); Tick(1)
Roll("Bluey Heeler", 70)
Roll("Bingo Heeler", 70)
p.stop:Click(); Tick(1)
check(p.result:GetText():find("Tie at 70", 1, true) and p.reroll:IsEnabled(), "a tie: Reroll ties on")
local chat2 = #WHISPERS
p.reroll:Click(); Tick(1)
check(R.cur.open and R.cur.round == 2 and WHISPERS[chat2 + 1].text:find("^Tie reroll: "), "Reroll ties opens round 2 and says so")
Roll("Bluey Heeler", 3)
p.stop:Click(); Tick(1)

-- History: newest first, with date and time.
p.histBtn:Click(); Tick(1)
check(p.histBtn:GetText() == L.CLANROLL_BACK and p.hist[1]:IsShown() and not p.res[1]:IsShown(), "History shows instead of the rolls")
check(p.hist[1].left:GetText():find(L.CLANROLL_HIST_REROLL, 1, true) and p.hist[3].right:GetText():find("Bingo", 1, true)
    and p.hist[1].left:GetText():find("%d%d:%d%d"), "newest first, with the time, the reroll marked")
p.histBtn:Click(); Tick(1)
check(p.res[1]:IsShown(), "Back to the rolls")

-- A member sees the panel but can't run it.
FAKE.myRank = 4
ns.Guild.myRank = 4
for _, m in ipairs(ns.Guild.list) do if m.name == "Ned Jones" then m.rankIndex = 4 end end
UI.Dirty(); Tick(1)
check(not p.start:IsEnabled() and not p.msg:IsEnabled() and p.status:GetText():find(L.CLANROLL_WHO_CAN, 1, true),
    "a member: Start off, 'The clan's leader runs the rolls'")

-- Dev: fake rollers for testing alone (fake guildies on, a roll open).
FAKE.myRank = 0
ns.Guild.myRank = 0
for _, m in ipairs(ns.Guild.list) do if m.name == "Ned Jones" then m.rankIndex = 0 end end
SlashCmdList.YEAHNAHMATE("dev sim on"); Tick(20)
local race = ns.Clans.MyRace()
local fakes = 0
for _, m in ipairs(ns.Guild.list) do if m.sim and m.online and m.race == race then fakes = fakes + 1 end end
check(fakes > 0, "fake guildies in my clan (" .. fakes .. ")")
local r = R.Start({ race = race })
SlashCmdList.YEAHNAHMATE("dev rollfakes tie")
Tick(10)
local res = R.Results(r)
check(#res == math.min(fakes, 5), "each fake clan member's first roll counted, the repeat, 100-100 and other clan left out")
check(res[1].roll == 100 and res[2].roll == 100, "tie: two fakes on 100")
R.Stop()
check(r.ties and #r.ties == 2, "a tie to reroll")
SlashCmdList.YEAHNAHMATE("dev sim off"); Tick(1)

-- The pop-out and the countdown sit over the main window (DIALOG), under pop-ups (FULLSCREEN_DIALOG).
local ORDER = { LOW = 1, MEDIUM = 2, HIGH = 3, DIALOG = 4, FULLSCREEN = 5, FULLSCREEN_DIALOG = 6 }
ns.ClanRollUI.OpenPop(false)
ns.ClanRollUI.CountShow("3")
local popS, bigS = ns.ClanRollUI.Pop():GetFrameStrata(), ns.ClanRollUI.Big():GetFrameStrata()
check(ORDER[popS] and ORDER[popS] > ORDER.DIALOG and ORDER[popS] < ORDER.FULLSCREEN_DIALOG, "the pop-out is over the main window (" .. tostring(popS) .. ")")
check(ORDER[bigS] and ORDER[bigS] > ORDER.DIALOG, "the countdown is over the main window (" .. tostring(bigS) .. ")")
ns.ClanRollUI.ClosePop()
