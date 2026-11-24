-- The clan roll's rules: only the game's own roll lines, only 1-100, first roll stands, only my group,
-- clan members (non-clan members only when allowed), ties and rerolls, skipping past winners, the
-- timer and countdown, history, cleaning what the leader types, and the chat it sends: Start and
-- Announce from a click, Roll over exactly once when the roll closes, the winner whisper on request.
math.randomseed(7)
YeahNahMateDB = nil
FAKE.myRank = 0                 -- I'm the guild master here (Ned Jones): I may run any clan's roll
local ns = LoadAddon("YeahNahMate", "YeahNahMate")
LOGGED_IN = true
FireEvent("PLAYER_LOGIN")
local Ser = LibStub("AceSerializer-3.0")
local function Msg(t) return Ser:Serialize(t) end
local R, L = ns.ClanRoll, ns.L
ns.settings.sharePosition, ns.settings.shareProfessions = false, false
RANDOM_ROLL_RESULT = "%s rolls %d (%d-%d)"
function UnitRace() return "Orc", "Orc", 2 end
Tick(15)
-- Bluey and Bingo are Orcs, Chilli a Troll. All three in my party.
INJECT("YNM", Msg({ v = 1, t = "HI", ver = ns.VERSION, ra = "Orc", ro = "t" }), "GUILD", "Bluey Heeler")
INJECT("YNM", Msg({ v = 1, t = "HI", ver = ns.VERSION, ra = "Orc", ro = "h" }), "GUILD", "Bingo Heeler")
INJECT("YNM", Msg({ v = 1, t = "HI", ver = ns.VERSION, ra = "Troll", ro = "d" }), "GUILD", "Chilli Heeler")
Tick(2)
FAKE.group, FAKE.party = 4, { "Bluey Heeler", "Bingo Heeler", "Chilli Heeler" }

local function Roll(name, n, lo, hi)
    FireEvent("CHAT_MSG_SYSTEM", string.format(RANDOM_ROLL_RESULT, name, n, lo or 1, hi or 100))
end
local function Names(list) local out = {} for _, e in ipairs(list) do out[#out + 1] = e.name .. "=" .. e.roll end return table.concat(out, " ") end
local function Chat(from) local out = {} for i = from + 1, #WHISPERS do out[#out + 1] = WHISPERS[i] end return out end

-- Reading and cleaning.
local name, roll = R.Parse("Bluey Heeler rolls 42 (1-100)")
check(name == "Bluey Heeler" and roll == 42, "a First Surname roll line is read")
check(R.Plain("|cffff0000Free|r |Hitem:1|h[stuff]|h\nnow  ok") == "Free [stuff] now ok", "colour codes, links and line breaks taken out")
check(ns.Letters(R.Plain(string.rep("a", 100))) == 40, "the message is cut to 40 letters")
local link = "|cff0070dd|Hitem:2244::::::::22:::::::|h[Krol Blade]|h|r"
check(R.Item(link) == link and R.ItemName(link) == "[Krol Blade]", "a whole item link is kept")
check(R.Item("|cff0070dd|Hitem:2244|h[Krol Blade") == "[Krol Blade", "a broken link becomes plain text")
check(R.Item("  ") == nil and R.Item("Krol Blade") == "Krol Blade", "a typed name is fine, blank is no item")

-- Timer and countdown.
check(R.StepTimer(0, 1) == 10 and R.StepTimer(30, 1) == 60 and R.StepTimer(60, 1) == 60 and R.StepTimer(0, -1) == 0
    and R.StepTimer(30, -1) == 20, "the timer steps Off, 10, 20, 30, 60 and stops at the ends")
check(#R.CountMarks(0) == 0 and table.concat(R.CountMarks(10), ",") == "3,2,1" and table.concat(R.CountMarks(30), ",") == "5,3,2,1",
    "countdown: 3, 2, 1 for 10 s; 5, 3, 2, 1 for longer")

-- Who may start: not a member's screen.
check(R.CanStart("Orc") and not R.CanStart(nil), "the guild master may start a roll")

-- Rolling before Start counts for nothing.
Roll("Bluey Heeler", 99)
check(R.cur == nil, "a roll before Start is ignored")

-- A roll with no timer.
local chat0 = #WHISPERS
local r = R.Start({ race = "Orc", msg = "Roll for", item = link })
check(r and r.open and r.msg == "Roll for", "roll started")
check(R.PostStart(r) and Chat(chat0)[1].kind == "PARTY" and Chat(chat0)[1].text == "Roll for " .. link .. " - type /roll now",
    "Start posts one party line with the item link")
check(#R.Missing() == 3, "Bluey, Bingo and I haven't rolled (Chilli's a Troll)")

check(R.OnRollLine("Bluey Heeler rolls 100 (100-100)") == "range", "/roll 100 100 ignored")
check(R.OnRollLine("Bluey Heeler rolls 95 (90-100)") == "range", "/roll 90 100 ignored")
check(R.OnRollLine("Bluey Heeler rolls 500 (1-1000)") == "range", "/roll 1000 ignored")
Roll("Bluey Heeler", 40)
check(r.rolls["Bluey Heeler"].roll == 40, "Bluey's normal roll counts")
Roll("Bluey Heeler", 99)
check(r.rolls["Bluey Heeler"].roll == 40 and r.n == 1, "Bluey's repeat is left out, her first roll stands")
Roll("Chilli Heeler", 98)
check(r.rolls["Chilli Heeler"] == nil, "Chilli (not in the clan) left out completely")
Roll("Some Stranger", 97)
check(r.rolls["Some Stranger"] == nil, "someone outside my group left out")
check(R.OnRollLine("Bingo Heeler says rolls 100 (1-100)") ~= "counts", "a made-up line doesn't count")
-- My own repeat: told once.
local printed = #PRINTED
Roll("Ned Jones", 12)
Roll("Ned Jones", 90)
Roll("Ned Jones", 91)
local notices = 0
for i = printed + 1, #PRINTED do if PRINTED[i]:find("your first roll stands", 1, true) then notices = notices + 1 end end
check(r.rolls["Ned Jones"].roll == 12 and notices == 1, "my repeat: first roll stands, told once")
check(table.concat(R.Missing(), ",") == "Bingo Heeler", "only Bingo still to roll")
-- Leaving and rejoining keeps the first roll.
FAKE.party = { "Bingo Heeler", "Chilli Heeler" }
FAKE.party[3] = "Bluey Heeler"
Roll("Bluey Heeler", 77)
check(r.rolls["Bluey Heeler"].roll == 40, "rejoining doesn't give a new roll")
Roll("Bingo Heeler", 63)
check(Names(R.Results()) == "Bingo Heeler=63 Bluey Heeler=40 Ned Jones=12", "results highest first")
check(R.Results()[1].top and not R.Results()[2].top, "the highest is marked")

-- Stop: winner, history, Roll over once.
local chat1 = #WHISPERS
R.Stop()
check(not r.open and r.winner == "Bingo Heeler" and r.winRoll == 63, "Bingo wins with 63")
local over = Chat(chat1)
check(#over == 1 and over[1].kind == "PARTY" and over[1].text == "Roll over: Roll for " .. link, "Roll over posted once, to party")
R.Stop()
check(#Chat(chat1) == 1, "stopping again posts nothing")
Roll("Bluey Heeler", 100)
check(r.rolls["Bluey Heeler"].roll == 40, "a roll after Stop is ignored")
local h = R.History()
check(#h == 1 and h[1].winner == "Bingo Heeler" and h[1].item == "[Krol Blade]" and #h[1].results == 3 and h[1].at, "history saved")

-- Announce: party line, and the whisper only when asked.
local chat2 = #WHISPERS
check(R.Announce(r, false), "Announce")
local a = Chat(chat2)
check(#a == 1 and a[1].text == "Roll for " .. link .. " - winner: Bingo Heeler (63)", "Announce posts the winner")
chat2 = #WHISPERS
R.Announce(r, true)
a = Chat(chat2)
check(#a == 2 and a[2].kind == "WHISPER" and a[2].target == "Bingo Heeler" and a[2].text:find("(you rolled 63)", 1, true),
    "Whisper winner: the same click whispers Bingo")

-- A tie, and the reroll for only the tied players.
r = R.Start({ race = "Orc", msg = "Roll for", item = "Lucky coin" })
Roll("Bluey Heeler", 80)
Roll("Bingo Heeler", 80)
Roll("Ned Jones", 10)
R.Stop()
check(r.winner == nil and table.concat(r.ties, ",") == "Bingo Heeler,Bluey Heeler" and r.winRoll == 80, "a tie at 80")
local chat3 = #WHISPERS
R.Announce(r)
check(Chat(chat3)[1].text:find("tie between Bingo Heeler, Bluey Heeler (80)", 1, true), "Announce says it's a tie")
local rr = R.Reroll()
check(rr and rr.round == 2 and R.StartLine(rr):find("^Tie reroll: "), "reroll opens round 2")
Roll("Ned Jones", 100)
check(rr.rolls["Ned Jones"] == nil, "someone not tied can't roll in the reroll")
check(table.concat(R.Missing(), ",") == "Bingo Heeler,Bluey Heeler", "only the tied players are waited on")
Roll("Bluey Heeler", 30)
Roll("Bingo Heeler", 31)
R.Stop()
check(rr.winner == "Bingo Heeler", "Bingo wins the reroll")

-- Skip past winners: Bingo already won twice this session.
r = R.Start({ race = "Orc", item = "Wolf", skip = true })
Roll("Bingo Heeler", 99)
Roll("Bluey Heeler", 50)
check(r.rolls["Bingo Heeler"].past and not R.Results()[1].top and R.Results()[2].top, "Bingo's 99 shown but can't win")
R.Stop()
check(r.winner == "Bluey Heeler", "Bluey wins instead")
-- After 4 hours with no meeting, Bingo can win again.
Tick(4 * 3600 + 10)
check(not R.PastWinner("Bingo Heeler", "Orc"), "past wins older than 4 hours don't count")
-- During a meeting: only wins since it started.
ns.ClanMeet.Start("Orc")
check(not R.PastWinner("Bluey Heeler", "Orc"), "a new meeting starts the session again")
ns.ClanMeet.Stop()

-- Non-clan members allowed: Chilli rolls, shown as an outsider, and can win.
r = R.Start({ race = "Orc", others = true })
Roll("Chilli Heeler", 70)
Roll("Bluey Heeler", 20)
check(r.rolls["Chilli Heeler"].outsider, "Chilli counts as an outsider")
check(table.concat(R.Missing(), ",") == "Bingo Heeler,Ned Jones", "with non-clan members on, anyone in the group is waited on")
R.Stop()
check(r.winner == "Chilli Heeler", "an outsider can win when allowed")

-- The timer: countdown events, then it closes by itself and posts Roll over once.
local counts = {}
ns.Listen("CLANROLL_COUNT", function(n) counts[#counts + 1] = n end)
local chat4 = #WHISPERS
r = R.Start({ race = "Orc", timer = 30, countdown = true })
check(R.StartLine(r) == "Roll for - type /roll, 30 seconds", "the Start line says how long")
Tick(26)
check(r.open and table.concat(counts, ",") == "5", "'Ending in 5' with 5 s left")
Tick(5)
check(not r.open and table.concat(counts, ",") == "5,3,2,1", "3, 2, 1 then closed by the timer")
local o = Chat(chat4)
check(#o == 1 and o[1].text == "Roll over: Roll for", "the timer posts Roll over once")
r = R.Start({ race = "Orc", timer = 10, countdown = false })
counts = {}
Tick(11)
check(not r.open and #counts == 0, "no countdown when it's off")
check(R.Start({ race = "Orc", timer = 15 }).timer == 0, "only the listed timer settings")
R.Stop()

-- Starting a new roll closes the open one (once).
local chat5 = #WHISPERS
local first = R.Start({ race = "Orc" })
R.Start({ race = "Orc" })
check(not first.open and #Chat(chat5) == 1, "a new roll closes the open one, posting its Roll over")

-- History keeps the last 20.
for _ = 1, 25 do R.Start({ race = "Orc" }); R.Stop() end
check(#R.History() == 20, "history keeps 20")

-- Secret roll lines: the screen is told, nothing counted.
r = R.Start({ race = "Orc" })
local SECRET = {}
local realSecret = issecretvalue
issecretvalue = function(v) return v == SECRET end
FireEvent("CHAT_MSG_SYSTEM", SECRET)
check(R.unreadable and r.n == 0, "a secret roll line: 'rolls can't be read here'")
issecretvalue = realSecret
R.Stop()

-- Alone: nothing posted.
FAKE.group, FAKE.party = 0, {}
local chat6 = #WHISPERS
r = R.Start({ race = "Orc" })
R.PostStart(r)
R.Stop()
check(#Chat(chat6) == 0, "not in a group: nothing posted")

-- Chat locked: told, nothing sent.
FAKE.group, FAKE.party = 2, { "Bluey Heeler" }
local realLock = C_ChatInfo.InChatMessagingLockdown
C_ChatInfo.InChatMessagingLockdown = function() return true end
local chat7 = #WHISPERS
r = R.Start({ race = "Orc" })
check(not R.PostStart(r) and #Chat(chat7) == 0, "chat locked: not posted")
C_ChatInfo.InChatMessagingLockdown = realLock
R.Stop()

-- A member may not start a roll; test mode keeps lines on this screen.
FAKE.myRank = 4
ns.Guild.myRank = 4
for _, m in ipairs(ns.Guild.list) do if m.name == "Ned Jones" then m.rankIndex = 4 end end
check(not R.CanStart("Orc") and R.Start({ race = "Orc" }) == nil, "a member can't start a roll")
ns.Board.devEditor = true
local chat8 = #WHISPERS
r = R.Start({ race = "Orc" })
check(r ~= nil, "test editor: the roll runs on this screen")
R.PostStart(r)
R.Stop()
check(#Chat(chat8) == 0, "test editor: nothing really posted")
ns.Board.devEditor = false
