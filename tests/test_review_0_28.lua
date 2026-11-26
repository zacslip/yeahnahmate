-- Fixes from the full code review before the 0.28.0 release (26 Nov):
--   1. the pop-out lets go of the keyboard when its roll starts and when it closes (a hidden Message box
--      kept / and Enter, so the leader couldn't type /roll);
--   2. my own roll that ended in a tie isn't replaced by another clan's roll (Reroll ties stays);
--   3. someone following a tied roll is told a reroll is coming, not to click a button they don't have;
--   4. the item boxes take a whole long item link;
--   5. a roll number over a head only runs every frame while it pulses (the winner's die);
--   6. the fishing skill is still known with Secondary Skills collapsed in the Skills panel.
math.randomseed(28)
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
FAKE.group, FAKE.party = 4, { "Bluey Heeler", "Bingo Heeler", "Chilli Heeler" }
local function Roll(name, n) FireEvent("CHAT_MSG_SYSTEM", string.format(RANDOM_ROLL_RESULT, name, n, 1, 100)) end

-- 1. Typing a message in the pop-out, then Start roll: the keyboard is free for /roll.
CU.OpenPop(false, "Orc"); Tick(1)
local pop = CU.Pop()
check(pop:IsShown() and pop.setup:IsShown(), "1: the pop-out with its setup")
pop.msg:SetFocus()
check(GetCurrentKeyBoardFocus() == pop.msg, "1: typing in the pop-out's Message box")
pop.start:Click(); Tick(1)
check(R.cur and R.cur.open and R.cur.by == ns.me, "1: my roll started from the pop-out")
check(GetCurrentKeyBoardFocus() == nil, "1: Start roll lets go of the keyboard (/ and Enter reach chat)")
-- 2. It ends in a tie.
Roll("Bluey Heeler", 77)
Roll("Bingo Heeler", 77)
R.Stop(); Tick(1)
check(R.cur and not R.cur.open and R.cur.ties and R.cur.by == ns.me, "2: my roll ended in a tie")
local mine = R.cur
-- Bluey (an officer) starts the Trolls' roll in the same group, open to everyone: mine stays, Reroll ties with it.
INJECT("YNM", Msg({ t = "CRS", r = "Troll", id = "T-1", m = "Roll for", tm = 10, rd = 1, o = true }), "GUILD", "Bluey Heeler"); Tick(1)
check(R.cur == mine, "2: another clan's roll doesn't replace my tied roll")
check(pop.reroll:IsShown(), "2: Reroll ties is still there")
check(pop.result:GetText() == string.format(L.CLANROLL_TIE, 77), "3: my own tie says Reroll ties")
-- 3. Someone following a tie: no button to click, just a reroll coming.
local followed = { id = "F-1", race = "Orc", by = "Bluey Heeler", follower = true, open = false, ties = { "Bingo Heeler" },
    winRoll = 77, rolls = {}, n = 0, timer = 0 }
check(CU.ResultText(followed) == string.format(L.CLANROLL_TIE_FOLLOW, 77), "3: following a tie: a reroll is coming")
-- Closing the pop-out while typing lets go too.
R.cur = nil
CU.RefreshPop(); Tick(1)
pop.item:SetFocus()
CU.ClosePop()
check(GetCurrentKeyBoardFocus() == nil and not pop:IsShown(), "1: closing the pop-out lets go of the keyboard")
CU.OpenPop(false, "Orc"); Tick(1)
pop.msg:SetFocus()
pop:Hide()
check(GetCurrentKeyBoardFocus() == nil, "1: however it hides, it lets go")

-- 4. A long item link fits whole in the item boxes.
local link = "|cffa335ee|Hitem:19019:0:0:0:0:0:0:0:60:0:0:0:0:0:0:0:0|h[Thunderfury, Blessed Blade of the Windseeker]|h|r"
check(#link > 80 and CU.ITEM_LETTERS >= #link, "4: the item boxes take " .. CU.ITEM_LETTERS .. " letters (this link is " .. #link .. ")")
check(R.Item(link) == link, "4: and a whole link is kept as a link")

-- 5. Roll numbers over heads: only the winner's die runs every frame.
local units = { nameplate1 = { "Bluey", "Heeler" }, nameplate2 = { "Bingo", "Heeler" } }
local plates = {}
C_NamePlate = { GetNamePlateForUnit = function(u)
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
ns.Plates.SetRolls({ ["Bluey Heeler"] = { n = 40 }, ["Bingo Heeler"] = { n = 88, top = true } })
local m1, m2 = ns.Plates.RollMarkFor("nameplate1"), ns.Plates.RollMarkFor("nameplate2")
check(m1 and m2 and m1:IsShown() and not m1:GetScript("OnUpdate") and not m2:GetScript("OnUpdate"),
    "5: plain roll numbers don't run every frame")
ns.Plates.ShowWinner("Bingo Heeler", 88)
check(m2:GetScript("OnUpdate") ~= nil and not m1:GetScript("OnUpdate"), "5: the winner's die pulses")
Tick(ns.Plates.WINNER_SECS + 1)
check(not (ns.Plates.RollMarkFor("nameplate2") and ns.Plates.RollMarkFor("nameplate2"):GetScript("OnUpdate")),
    "5: after its 10 s, nothing runs every frame")
ns.Plates.SetRolls({})

-- 6. Fishing: seen once, still known with the header collapsed.
local G = ns.LevelGuide
local skills = { { "Secondary Skills", true, true }, { "Fishing", false, false, 150 } }
GetNumSkillLines = function() return #skills end
GetSkillLineInfo = function(i) local s = skills[i]; return s[1], s[2], s[3], s[4] end
check(G.MyFishing() == 150, "6: fishing 150 from the skill list")
skills = { { "Secondary Skills", true, false } }          -- collapsed: Fishing isn't listed
check(G.MyFishing() == 150, "6: Secondary Skills collapsed: still 150 (the last seen)")
skills = { { "Secondary Skills", true, true } }           -- open, and no Fishing: not learned
check(G.MyFishing() == nil, "6: no Fishing under an open header: none")

check(#ERRORS == 0, "no errors (" .. tostring(ERRORS[1]) .. ")")
