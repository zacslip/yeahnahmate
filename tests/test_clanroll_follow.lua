-- The clan roll seen by the group: the starter's addon tells the guild (CRS / CRE); group members'
-- addons follow the roll only when the sender may run that clan's rolls and is in their group. They
-- count rolls for the screen, show numbers over heads (the highest gold), the countdown and their
-- own "first roll stands" notice; the winner comes from the starter. The winner's crowned die shows
-- over their head for 10 s, and the winner gets a pop-up. Forged and stray messages do nothing.
math.randomseed(5)
YeahNahMateDB = nil
FAKE.myRank = 4                 -- I'm a member (Ned Jones); Bluey is an officer
local ns = LoadAddon("YeahNahMate", "YeahNahMate")
LOGGED_IN = true
FireEvent("PLAYER_LOGIN")
local Ser = LibStub("AceSerializer-3.0")
local function Msg(t) t.v = 1; return Ser:Serialize(t) end
local function Sent(t, from)
    local list = {}
    for i = (from or 1), #SENT do
        local ok, m = Ser:Deserialize(SENT[i].text)
        if ok and type(m) == "table" and m.t == t then m._channel = SENT[i].channel; list[#list + 1] = m end
    end
    return list
end
local R, Plates = ns.ClanRoll, ns.Plates
ns.settings.sharePosition, ns.settings.shareProfessions = false, false
RANDOM_ROLL_RESULT = "%s rolls %d (%d-%d)"
function UnitRace() return "Orc", "Orc", 2 end
Tick(15)
INJECT("YNM", Msg({ t = "HI", ver = ns.VERSION, ra = "Orc", ro = "t" }), "GUILD", "Bluey Heeler")
INJECT("YNM", Msg({ t = "HI", ver = ns.VERSION, ra = "Orc", ro = "h" }), "GUILD", "Bingo Heeler")
Tick(2)
FAKE.group, FAKE.party = 3, { "Bluey Heeler", "Bingo Heeler" }
local function Roll(name, n, lo, hi) FireEvent("CHAT_MSG_SYSTEM", string.format(RANDOM_ROLL_RESULT, name, n, lo or 1, hi or 100)) end

-- Nameplates on screen (found by name: the game refuses party tokens for nameplates).
local units = { nameplate1 = { "Bluey", "Heeler" }, nameplate2 = { "Bingo", "Heeler" } }
local plates = {}
C_NamePlate = { GetNamePlateForUnit = function(u)
    if u:find("^party") or u:find("^raid") then error("Raid<n>/Party<n> unit tokens are not allowed for this call.") end
    if not units[u] then return nil end
    plates[u] = plates[u] or CreateFrame("Frame")
    return plates[u]
end }
local realUnitName = UnitName
UnitName = function(u) if units[u] then return units[u][1], units[u][2] end return realUnitName(u) end
function UnitIsPlayer(u) return units[u] ~= nil end
function UnitIsUnit() return false end
FireEvent("NAME_PLATE_UNIT_ADDED", "nameplate1")
FireEvent("NAME_PLATE_UNIT_ADDED", "nameplate2")

local toasts = {}
local realToast = ns.Toast.Show
ns.Toast.Show = function(title, text, ...) toasts[#toasts + 1] = { title, text }; return realToast(title, text, ...) end

local START = { t = "CRS", r = "Orc", id = "100-1234", m = "Roll for", i = "Lucky coin", tm = 10, cd = true, rd = 1 }
-- Forged: Bingo (a member) can't start a roll; nothing follows.
INJECT("YNM", Msg(START), "GUILD", "Bingo Heeler"); Tick(1)
check(R.cur == nil, "a member's roll start is dropped")
-- Bluey not in my group: not my roll.
FAKE.party = { "Bingo Heeler" }; FAKE.group = 2
INJECT("YNM", Msg(START), "GUILD", "Bluey Heeler"); Tick(1)
check(R.cur == nil, "a roll in another group is ignored")
FAKE.group, FAKE.party = 3, { "Bluey Heeler", "Bingo Heeler" }

-- Bluey starts it in my group: I follow.
local counts = {}
ns.Listen("CLANROLL_COUNT", function(n) counts[#counts + 1] = n end)
INJECT("YNM", Msg(START), "GUILD", "Bluey Heeler"); Tick(1)
local r = R.cur
check(r and r.follower and r.open and r.by == "Bluey Heeler" and r.timer == 10 and r.item == "Lucky coin", "following Bluey's roll")
local sentBefore, chatBefore = #SENT, #WHISPERS

Roll("Bingo Heeler", 50)
Roll("Bluey Heeler", 20)
local printed = #PRINTED
Roll("Ned Jones", 30)
Roll("Ned Jones", 90)
local notices = 0
for i = printed + 1, #PRINTED do if PRINTED[i]:find("your first roll stands", 1, true) then notices = notices + 1 end end
check(r.rolls["Ned Jones"].roll == 30 and notices == 1, "my repeat: told once, on my screen")
Tick(1)
local m2, m1 = Plates.RollMarkFor("nameplate2"), Plates.RollMarkFor("nameplate1")
check(m2 and m2:IsShown() and m2.num:GetText():find("50", 1, true) and m2.num:GetText():find(ns.GOLD, 1, true),
    "Bingo's 50 over her head, in gold (highest)")
check(m1 and m1:IsShown() and m1.num:GetText():find("20", 1, true) and not m1.num:GetText():find(ns.GOLD, 1, true), "Bluey's 20, white")

-- The Settings switch takes them down and puts them back.
ns.settings.rollPlates = false; ns.Fire("SETTINGS"); Tick(1)
check(not Plates.RollMarkFor("nameplate2"), "Show rolls above heads off: no numbers")
ns.settings.rollPlates = true; ns.Fire("SETTINGS"); Tick(1)
check(Plates.RollMarkFor("nameplate2") ~= nil, "back on")
-- Brackets off doesn't matter.
ns.settings.guildPlates = false; ns.Fire("SETTINGS"); Tick(1)
check(Plates.RollMarkFor("nameplate2") ~= nil, "numbers show with the guild brackets off")
ns.settings.guildPlates = true

-- The timer: my screen counts down, then closes; no winner until Bluey says.
Tick(9)
check(table.concat(counts, ",") == "3,2,1" and not r.open and r.winner == nil, "countdown 3, 2, 1; closed, waiting for Bluey's result")
check(not Plates.RollMarkFor("nameplate2") or not Plates.RollMarkFor("nameplate2"):IsShown(), "numbers taken down when it closes")
check(#Sent("CRS", sentBefore + 1) == 0 and #Sent("CRE", sentBefore + 1) == 0 and #WHISPERS == chatBefore, "a follower sends nothing")

-- Forged result from Bingo: ignored. Bluey's: Bingo won.
INJECT("YNM", Msg({ t = "CRE", r = "Orc", id = "100-1234", w = "Ned Jones", n = 99 }), "GUILD", "Bingo Heeler"); Tick(1)
check(r.winner == nil, "a result from someone else is ignored")
INJECT("YNM", Msg({ t = "CRE", r = "Orc", id = "100-1234", w = "Bingo Heeler", n = 50 }), "GUILD", "Bluey Heeler"); Tick(1)
check(r.winner == "Bingo Heeler" and r.winRoll == 50, "Bluey's result: Bingo won with 50")
local w = Plates.RollMarkFor("nameplate2")
check(w and w:IsShown() and w.pulse and w.winning and w.num:GetText():find("50", 1, true),
    "the crowned die and 50 over Bingo's head, pulsing")
check(#toasts == 0, "no pop-up: I didn't win")
Tick(11)
check(not Plates.RollMarkFor("nameplate2"), "gone after 10 s")

-- A second roll that I win: the pop-up.
INJECT("YNM", Msg({ t = "CRS", r = "Orc", id = "200-1", m = "Roll for", tm = 0, rd = 1 }), "GUILD", "Bluey Heeler"); Tick(1)
Roll("Ned Jones", 77)
INJECT("YNM", Msg({ t = "CRE", r = "Orc", id = "200-1", w = "Ned Jones", n = 77 }), "GUILD", "Bluey Heeler"); Tick(1)
check(#toasts == 1 and toasts[1][1] == ns.L.TOAST_ROLL_WON and toasts[1][2]:find("77", 1, true), "I won: a pop-up")

-- A tie reroll: only the tied players' rolls count on my screen too.
INJECT("YNM", Msg({ t = "CRS", r = "Orc", id = "300-1", m = "Roll for", tm = 0, rd = 2, tie = { "Bingo Heeler", "Bluey Heeler" } }), "GUILD", "Bluey Heeler"); Tick(1)
Roll("Ned Jones", 99)
Roll("Bingo Heeler", 12)
check(R.cur.rolls["Ned Jones"] == nil and R.cur.rolls["Bingo Heeler"].roll == 12, "a reroll: only the tied players")
INJECT("YNM", Msg({ t = "CRE", r = "Orc", id = "300-1", w = "Bingo Heeler", n = 12 }), "GUILD", "Bluey Heeler"); Tick(11)

-- The starter's side: I'm the guild master now. CRS on Start, CRE with the winner on Stop.
FAKE.myRank = 0
ns.Guild.myRank = 0
for _, m in ipairs(ns.Guild.list) do if m.name == "Ned Jones" then m.rankIndex = 0 end end
local before = #SENT
local mine = R.Start({ race = "Orc", msg = "Roll for", item = "Wolf", timer = 20, countdown = true })
local crs = Sent("CRS", before + 1)
check(#crs == 1 and crs[1]._channel == "GUILD" and crs[1].id == mine.id and crs[1].tm == 20 and crs[1].cd == true and crs[1].i == "Wolf",
    "Start tells the guild's addons (CRS)")
Roll("Bluey Heeler", 64)
R.Stop()
local cre = Sent("CRE", before + 1)
check(#cre == 1 and cre[1].w == "Bluey Heeler" and cre[1].n == 64 and cre[1].id == mine.id, "Stop sends the result (CRE)")
-- My own CRS coming back doesn't turn my roll into a followed one.
Deliver(); Tick(1)
check(R.cur == mine and not mine.follower, "my own messages coming back are ignored")

-- Test mode (a rank I don't really have): nothing sent.
FAKE.myRank = 4
ns.Guild.myRank = 4
for _, m in ipairs(ns.Guild.list) do if m.name == "Ned Jones" then m.rankIndex = 4 end end
ns.Board.devEditor = true
before = #SENT
R.Start({ race = "Orc" }); R.Stop()
check(#Sent("CRS", before + 1) == 0 and #Sent("CRE", before + 1) == 0, "test editor: nothing sent")
ns.Board.devEditor = false
UnitName = realUnitName

-- The pop-out window for members: opens by itself when a roll starts and I can't see one already,
-- closes itself 15 s after the result; stays shut when the main window shows My Clan.
local CU = ns.ClanRollUI
CU.ClosePop()
INJECT("YNM", Msg({ t = "CRS", r = "Orc", id = "400-1", m = "Roll for", tm = 0, rd = 1 }), "GUILD", "Bluey Heeler"); Tick(1)
local pop = CU.Pop()
check(pop and pop:IsShown() and pop.auto and pop.head:GetText():find("Bluey", 1, true), "a roll starts: the roll window opens by itself, Bluey's roll")
check(not pop.setup:IsShown() and not pop.announce:IsShown() and not pop.stop:IsShown() and not pop.whisperText:IsShown(),
    "a member's window has no buttons (not even the Whisper label)")
Roll("Bingo Heeler", 41); Tick(1)
check(pop.rows[1]:IsShown() and pop.rows[1].left:GetText():find("Bingo", 1, true) and pop.rows[1].right:GetText():find("41", 1, true), "rolls listed")
INJECT("YNM", Msg({ t = "CRE", r = "Orc", id = "400-1", w = "Bingo Heeler", n = 41 }), "GUILD", "Bluey Heeler"); Tick(1)
check(pop:IsShown() and pop.result:GetText():find("Bingo", 1, true), "the result shows")
Tick(16)
check(not pop:IsShown(), "and it closes itself 15 s later")
-- Opened by me (/ynm roll): it stays after a result.
SlashCmdList.YEAHNAHMATE("roll"); Tick(1)
check(pop:IsShown() and not pop.auto, "/ynm roll opens it")
INJECT("YNM", Msg({ t = "CRS", r = "Orc", id = "500-1", m = "Roll for", tm = 0, rd = 1 }), "GUILD", "Bluey Heeler"); Tick(1)
INJECT("YNM", Msg({ t = "CRE", r = "Orc", id = "500-1", w = "Bluey Heeler", n = 5 }), "GUILD", "Bluey Heeler"); Tick(20)
check(pop:IsShown(), "opened by me: stays open")
SlashCmdList.YEAHNAHMATE("roll"); Tick(1)
check(not pop:IsShown(), "/ynm roll again closes it")
-- The main window on Clans > My Clan: no pop-up.
ns.settings.clanView = "mine"
ns.UI.Open("clans"); Tick(1)
INJECT("YNM", Msg({ t = "CRS", r = "Orc", id = "600-1", m = "Roll for", tm = 0, rd = 1 }), "GUILD", "Bluey Heeler"); Tick(1)
check(not pop:IsShown(), "the roll's already on screen (My Clan): no pop-up")
INJECT("YNM", Msg({ t = "CRE", r = "Orc", id = "600-1" }), "GUILD", "Bluey Heeler"); Tick(1)
-- The main window on another tab: the pop-up comes.
ns.UI.Open("home"); Tick(1)
INJECT("YNM", Msg({ t = "CRS", r = "Orc", id = "700-1", m = "Roll for", tm = 0, rd = 1 }), "GUILD", "Bluey Heeler"); Tick(1)
check(pop:IsShown() and pop.auto, "main window on another tab: the pop-up comes")
INJECT("YNM", Msg({ t = "CRE", r = "Orc", id = "700-1" }), "GUILD", "Bluey Heeler"); Tick(16)
check(not pop:IsShown(), "closed again after")

-- The leader's pop-out: set up and start from it.
FAKE.myRank = 0
ns.Guild.myRank = 0
for _, m in ipairs(ns.Guild.list) do if m.name == "Ned Jones" then m.rankIndex = 0 end end
CU.OpenPop(false, "Orc"); Tick(1)
check(pop.setup:IsShown() and pop.start:IsEnabled(), "the leader's window: setup and Start")
pop.item:SetText("Shiny pebble")
pop.up:Click(); Tick(1)
check(pop.timer:GetText() == "60s", "the timer steps here too")
local chat = #WHISPERS
pop.start:Click(); Tick(1)
check(R.cur.open and R.cur.by == "Ned Jones" and R.cur.item == "Shiny pebble" and R.cur.timer == 60 and WHISPERS[chat + 1].kind == "PARTY",
    "Start from the window: the roll opens and posts")
check(not pop.setup:IsShown() and pop.stop:IsShown() and pop.status:GetText():find("s left", 1, true), "Stop and the time left")
Roll("Bingo Heeler", 70)
pop.stop:Click(); Tick(1)
check(pop.result:GetText():find("Bingo", 1, true) and pop.announce:IsShown() and pop.whisper:IsShown(), "after: winner, Announce, Whisper")
CU.ClosePop()

-- Several clans in one raid (an all-clans roll at a guild event): I follow only my own clan's roll.
R.cur = nil
FAKE.group, FAKE.party = 3, { "Bluey Heeler", "Bingo Heeler" }
local function Crs(id, race, o)
    INJECT("YNM", Msg({ t = "CRS", r = race, id = id, m = "Roll for", tm = 10, rd = 1, o = o }), "GUILD", "Bluey Heeler"); Tick(1)
end
Crs("200-1", "Troll")
check(R.cur == nil, "another clan's roll (no non-clan members): not followed")
Crs("200-2", "Orc")
check(R.cur and R.cur.id == "200-2" and R.cur.open, "my own clan's roll: followed")
Crs("200-3", "Troll", true)
check(R.cur.id == "200-2" and R.cur.open, "another clan's roll, even open to everyone, doesn't take over my clan's")
Tick(11)
Crs("200-4", "Troll", true)
check(R.cur.id == "200-4", "another clan's roll open to everyone, with mine not running: followed")
CU.ClosePop()
