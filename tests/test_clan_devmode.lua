-- Clans in dev test mode (/ynm dev editor, gm, rank N): a member can try the leader's and moderator's
-- buttons (start a meeting, Won / Lost, second in command) on this screen, but nothing their real
-- rank couldn't send goes out. /ynm dev clanmeet start | stop (sim mode) for the dev console.
math.randomseed(43)
YeahNahMateDB = nil
FAKE.myRank = 4                 -- an ordinary member (Ned Jones)
local ns = LoadAddon("YeahNahMate", "YeahNahMate")
LOGGED_IN = true
FireEvent("PLAYER_LOGIN")
local Ser = LibStub("AceSerializer-3.0")
local function Msg(t) return Ser:Serialize(t) end
local function Sent(t, from)
    local list = {}
    for i = (from or 1), #SENT do
        local ok, m = Ser:Deserialize(SENT[i].text)
        if ok and type(m) == "table" and m.t == t then list[#list + 1] = m end
    end
    return list
end
local X, CM = ns.ClanChallenge, ns.ClanMeet
ns.settings.sharePosition, ns.settings.shareProfessions = false, false
function UnitRace() return "Orc", "Orc", 2 end
Tick(15)
INJECT("YNM", Msg({ v = 1, t = "HI", ver = ns.VERSION, ra = "Orc", ro = "t" }), "GUILD", "Bluey Heeler")
INJECT("YNM", Msg({ v = 1, t = "HI", ver = ns.VERSION, ra = "Orc", ro = "h" }), "GUILD", "Bingo Heeler")
Tick(2)
local now = GetServerTime()
local heard = {}
ns.Listen("SENT", function(msg) heard[#heard + 1] = msg.t end)

-- A member, no test mode: no meeting, no settling.
check(not CM.ICanRun("Orc") and not CM.Start("Orc"), "a member can't start a meeting")
check(not X.ICanSettle(), "a member can't settle")

-- Test editor on: the buttons work on this screen; nothing goes out.
SlashCmdList.YEAHNAHMATE("dev editor on")
check(CM.ICanRun("Orc") and X.ICanSettle(), "test editor: may run meetings and settle on this screen")
check(not CM.CanRun(ns.me, "Orc") and not X.CanSettle(ns.me), "the real rank check is unchanged")
local before = #SENT
check(CM.Start("Orc") and CM.Mine() ~= nil, "test editor: the meeting starts on this screen")
check(#Sent("CMT", before + 1) == 0, "no CMT sent to the guild")
check(heard[#heard] == "CMT", "SENT still fires (sim fakes react to it)")
CM.Stop()
check(CM.Mine() == nil and #Sent("CMT", before + 1) == 0, "stopped; still nothing sent")

INJECT("YNM", Msg({ v = 1, t = "CHG", id = now, r = "Orc", st = "o", at = now, ev = now }), "GUILD", "Bingo Heeler")
Tick(1)
before = #SENT
check(X.Settle("Bingo Heeler", now, "lost"), "test editor: Lost on this screen")
check(X.Recent("Orc")[1] and X.Recent("Orc")[1].st == "lost", "shown as Lost")
check(#Sent("CHG", before + 1) == 0, "no CHG result sent")
check(X.SetDeputy("Bingo Heeler", true) and ns.Clans.IsDeputy("Bingo Heeler", "Orc"), "test editor: second in command on this screen")
check(#Sent("DEP", before + 1) == 0, "no DEP sent")
X.SetDeputy("Bingo Heeler", false)

-- Seeing the addon as the guild master (dev rank 0) works the same way.
SlashCmdList.YEAHNAHMATE("dev editor off")
check(not CM.ICanRun("Orc"), "test editor off: back to a member")
SlashCmdList.YEAHNAHMATE("dev rank 0")
check(CM.ICanRun("Orc"), "dev rank 0: may run meetings on this screen")
SlashCmdList.YEAHNAHMATE("dev rank off")

-- Seeing the addon as a clan's leader rank (0.20.5: Shadowhunter for the Trolls showed no Start
-- meeting, because someone else really holds that rank). Rank 2 leads the Orcs here.
local realRaceFor = ns.Clans.RaceForRank
ns.Clans.RaceForRank = function(i) if i == 2 then return "Orc" end return realRaceFor(i) end
check(X.CanChallenge(), "a member may challenge")
SlashCmdList.YEAHNAHMATE("dev rank 2")
check(CM.ICanRun("Orc") and not CM.ICanRun("Troll"), "dev rank 2 (the Orc leader rank): may run the Orc meeting, not the Trolls'")
check(not CM.CanRun(ns.me, "Orc"), "the real rank check is unchanged")
check(not X.CanChallenge(), "as the leader: no Challenge button for my own clan")
before = #SENT
check(CM.Start("Orc") and CM.Mine() ~= nil, "the meeting starts on this screen")
check(#Sent("CMT", before + 1) == 0, "no CMT sent to the guild")
CM.Stop()
SlashCmdList.YEAHNAHMATE("dev rank off")
check(not CM.ICanRun("Orc") and X.CanChallenge(), "rank off: a member again")
ns.Clans.RaceForRank = realRaceFor

-- /ynm dev clanmeet start | stop: needs sim; turns the test editor on; the fakes ask; nothing sent.
SlashCmdList.YEAHNAHMATE("dev clanmeet start")
check(CM.Mine() == nil, "dev clanmeet start needs sim mode")
SlashCmdList.YEAHNAHMATE("dev sim on")
Tick(16)
before = #SENT
SlashCmdList.YEAHNAHMATE("dev clanmeet start")
check(CM.Mine() and CM.Mine().race == "Orc" and ns.Board.devEditor, "dev clanmeet start: my clan's meeting, test editor on")
Tick(20)
local asks = 0
for _ in pairs(CM.Mine().asks) do asks = asks + 1 end
check(asks > 0, "the fakes ask", asks)
check(#Sent("CMT", before + 1) == 0, "no CMT sent")
SlashCmdList.YEAHNAHMATE("dev clanmeet stop")
check(CM.Mine() == nil, "dev clanmeet stop")
SlashCmdList.YEAHNAHMATE("dev sim off")
SlashCmdList.YEAHNAHMATE("dev editor off")
Tick(1)

check(#ns.db.errors == 0, "no errors", ns.db.errors[1] and ns.db.errors[1].msg)
