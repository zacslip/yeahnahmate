-- The roll probe (/ynm dev rollprobe): reads game roll lines with the game's own pattern, gives each
-- the clan roll's verdict (counts, wrong range, repeat), calls look-alikes typed in chat fakes, and
-- sends only its test lines: party/raid plus a whisper from a click, party/raid from the 10 s timer.
YeahNahMateDB = nil
local ns = LoadAddon("YeahNahMate", "YeahNahMate")
LOGGED_IN = true
FireEvent("PLAYER_LOGIN")
Tick(5)

RANDOM_ROLL_RESULT = "%s rolls %d (%d-%d)"
local P = ns.RollProbe

-- The pattern and the parser.
check(P.Pattern() == "^(.+) rolls (%d+) %((%d+)%-(%d+)%)$", "the game's roll line becomes a pattern")
local name, roll, lo, hi = P.Parse("Bluey Heeler rolls 42 (1-100)")
check(name == "Bluey Heeler" and roll == 42 and lo == 1 and hi == 100, "a surname roll line is read")
check(P.Parse("Bluey Heeler says rolls 42") == nil, "other lines aren't rolls")
check(P.Pattern("%1$s rolls %2$d (%3$d-%4$d)") == "^(.+) rolls (%d+) %((%d+)%-(%d+)%)$", "numbered formats too")
local clean, had = P.Clean("|cffff0000Bluey|r rolls |Hitem:1|h[99]|h (1-100)")
check(clean == "Bluey rolls [99] (1-100)" and had, "colour codes and links taken out")

-- In a party with Bluey, nameplates on.
FAKE.group, FAKE.party = 2, { "Bluey Heeler" }
local plate = CreateFrame("Frame")
-- Like Forever: group unit tokens are refused with an error; Bluey's plate is nameplate3.
local realUnitName = UnitName
UnitName = function(u) if u == "nameplate3" then return "Bluey", "Heeler" end return realUnitName(u) end
C_NamePlate = { GetNamePlateForUnit = function(u)
    if u:find("^party") or u:find("^raid") then error("Raid<n>/Party<n> unit tokens are not allowed for this call.") end
    if u == "nameplate3" then return plate end
end }
check(P.UnitFor("Bluey Heeler") == "party1" and P.UnitFor("Ned Jones") == "player" and P.UnitFor("Some Stranger") == nil,
    "group units found by name")

local sentBefore, chatBefore = #SENT, #WHISPERS
SlashCmdList.YEAHNAHMATE("dev rollprobe")
local s = YeahNahMateDB.rollprobe
check(s.watch and s.pattern:find("rolls", 1, true), "probe on, the game's pattern saved")

local function Last() return s.rows[#s.rows] end
FireEvent("CHAT_MSG_SYSTEM", "Bluey Heeler rolls 42 (1-100)")
check(Last().verdict == "counts" and Last().roll == 42 and Last().inGroup and Last().plate == "shown (by name)", "Bluey's roll counts, number over her nameplate")
check(s.checks.read_party:find("^PASS") and s.checks.surname:find("^PASS") and s.checks.pattern == "PASS", "read, surname and pattern pass")
FireEvent("CHAT_MSG_SYSTEM", "Bluey Heeler rolls 97 (1-100)")
check(Last().verdict == "ignored: repeat (first was 42)", "a second roll is a repeat")
FireEvent("CHAT_MSG_SYSTEM", "Ned Jones rolls 100 (100-100)")
check(Last().verdict == "ignored: range 100-100" and Last().me, "/roll 100 100 ignored")
FireEvent("CHAT_MSG_SYSTEM", "Ned Jones rolls 95 (90-100)")
check(Last().verdict == "ignored: range 90-100", "/roll 90 100 ignored")
FireEvent("CHAT_MSG_SYSTEM", "Ned Jones rolls 7 (1-100)")
check(Last().verdict == "counts" and Last().plate == "me", "my own normal roll counts (no nameplate for me)")

-- Fakes typed in chat.
local n = #s.rows
FireEvent("CHAT_MSG_EMOTE", "rolls 100 (1-100)", "Bluey Heeler")
FireEvent("CHAT_MSG_PARTY", "Bluey Heeler rolls 100 (1-100)", "Bluey Heeler")
FireEvent("CHAT_MSG_SAY", "|cffffff00Bluey Heeler rolls 100 (1-100)|r", "Bluey Heeler")
FireEvent("CHAT_MSG_WHISPER", "i rolls 99", "Bluey Heeler")
FireEvent("CHAT_MSG_PARTY", "good roll mate", "Bluey Heeler")
check(#s.rows == n + 4, "four fakes noted, ordinary chat not")
check(s.fakes.emote == 1 and s.fakes.party == 1 and s.fakes.say == 1 and s.fakes.whisper == 1, "fakes counted by channel")
check(Last().verdict:find("^ignored: typed in whisper") and s.rows[n + 3].codes, "fakes ignored, colour codes noticed")

-- No names saved.
local leaked = false
for _, row in ipairs(s.rows) do for _, v in pairs(row) do
    if type(v) == "string" and (v:find("Bluey", 1, true) or v:find("Ned", 1, true)) then leaked = true end
end end
check(not leaked, "no names saved in the rows")

-- A new round: everyone may roll again.
SlashCmdList.YEAHNAHMATE("dev rollprobe round")
FireEvent("CHAT_MSG_SYSTEM", "Bluey Heeler rolls 5 (1-100)")
check(Last().verdict == "counts", "new round: Bluey's next roll counts")

-- The click test: one party line, one whisper to the last roller, and hearing them come back.
check(#SENT == sentBefore and #WHISPERS == chatBefore, "nothing sent while just watching")
SlashCmdList.YEAHNAHMATE("dev rollprobe post")
check(#WHISPERS == chatBefore + 2, "the click sent two lines")
local line, wh = WHISPERS[chatBefore + 1], WHISPERS[chatBefore + 2]
check(line.kind == "PARTY" and wh.kind == "WHISPER" and wh.target == "Bluey Heeler", "party line, whisper to Bluey")
FireEvent("CHAT_MSG_PARTY", line.text, "Ned Jones")
FireEvent("CHAT_MSG_WHISPER_INFORM", wh.text, "Bluey Heeler")
check(s.checks.post == "PASS: seen in party chat" and s.checks.whisper == "PASS: whisper went", "both came back")

-- The timer test: nothing for 10 s, then one party line with no click.
SlashCmdList.YEAHNAHMATE("dev rollprobe timer")
Tick(9)
check(#WHISPERS == chatBefore + 2, "nothing before 10 s")
Tick(2)
check(#WHISPERS == chatBefore + 3 and WHISPERS[#WHISPERS].kind == "PARTY", "the Roll over test line went to party")
FireEvent("CHAT_MSG_PARTY", WHISPERS[#WHISPERS].text, "Ned Jones")
check(s.checks.timer == "PASS: seen in party chat", "and came back")

-- In a raid it's raid chat; alone it won't send.
FAKE.raid = true
SlashCmdList.YEAHNAHMATE("dev rollprobe post")
check(WHISPERS[#WHISPERS - 1].kind == "RAID", "raid chat in a raid")
FAKE.raid, FAKE.group, FAKE.party = false, 0, {}
local before = #WHISPERS
SlashCmdList.YEAHNAHMATE("dev rollprobe post")
SlashCmdList.YEAHNAHMATE("dev rollprobe timer")
Tick(11)
check(#WHISPERS == before and s.checks.post:find("^not run") and s.checks.timer:find("^not run"), "alone: nothing sent")

-- Nameplate test.
FAKE.group, FAKE.party = 2, { "Bluey Heeler" }
SlashCmdList.YEAHNAHMATE("dev rollprobe plates")
check(s.checks.plates:find("^PASS: shown %(by name%) 1"), "test die over Bluey's nameplate, found by name")
-- A nameplate error is noted, and the roll is still recorded.
local okPlates = C_NamePlate
C_NamePlate = { GetNamePlateForUnit = function() error("boom") end }
SlashCmdList.YEAHNAHMATE("dev rollprobe round")
FireEvent("CHAT_MSG_SYSTEM", "Bluey Heeler rolls 33 (1-100)")
check(Last().verdict == "counts" and Last().plate:find("^error: "), "a nameplate error doesn't lose the roll")
C_NamePlate = okPlates
UnitName = realUnitName
C_NamePlate = nil
SlashCmdList.YEAHNAHMATE("dev rollprobe plates")
check(s.checks.plates:find("^FAIL: no plate 1"), "no nameplate: fails, says why")

-- Secret roll lines fail the read check, not crash.
local SECRET = {}
local realSecret = issecretvalue
issecretvalue = function(v) return v == SECRET end
FireEvent("CHAT_MSG_SYSTEM", SECRET)
check(s.checks.read_party:find("^FAIL"), "secret roll lines fail the read check")
issecretvalue = realSecret

-- Off: nothing more noted. The console lines read.
SlashCmdList.YEAHNAHMATE("dev rollprobe off")
n = #s.rows
FireEvent("CHAT_MSG_SYSTEM", "Bluey Heeler rolls 50 (1-100)")
check(#s.rows == n and not s.watch, "off: nothing noted")
check(#P.Lines() == 9 and #P.Recent(3) == 3, "results and recent verdicts for the console")
-- The addon's own hello (it notices the fake group) may go out; nothing of the probe's does.
local probeSent = false
for i = sentBefore + 1, #SENT do
    if not SENT[i].text:find("^SHI^", 1, true) then probeSent = true end
end
check(not probeSent, "the probe sends no addon messages")
