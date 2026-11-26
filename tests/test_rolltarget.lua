-- Whisper and Target on the roll lists (UI/RollTarget.lua): full names on each row, Whisper opens our
-- whisper box ("You won" filled in for the winner), Target is a secure button outside our window, only
-- for someone in my group, hidden in a fight and back after it.
math.randomseed(13)
YeahNahMateDB = nil
FAKE.myRank = 0
local ns = LoadAddon("YeahNahMate", "YeahNahMate")
LOGGED_IN = true
FireEvent("PLAYER_LOGIN")
local Ser = LibStub("AceSerializer-3.0")
local function Msg(t) return Ser:Serialize(t) end
local R, L, UI, T = ns.ClanRoll, ns.L, ns.UI, ns.RollTarget
ns.settings.sharePosition, ns.settings.shareProfessions = false, false
RANDOM_ROLL_RESULT = "%s rolls %d (%d-%d)"
function UnitRace() return "Orc", "Orc", 2 end
Tick(15)
INJECT("YNM", Msg({ v = 1, t = "HI", ver = ns.VERSION, ra = "Orc", ro = "t" }), "GUILD", "Bluey Heeler")
INJECT("YNM", Msg({ v = 1, t = "HI", ver = ns.VERSION, ra = "Orc", ro = "h" }), "GUILD", "Bingo Heeler")
Tick(2)
FAKE.group, FAKE.party = 3, { "Bluey Heeler", "Bingo Heeler" }
local function Roll(name, n) FireEvent("CHAT_MSG_SYSTEM", string.format(RANDOM_ROLL_RESULT, name, n, 1, 100)) end

check(T.UnitFor("Bingo Heeler") == "party2" and T.UnitFor(ns.me) == "player" and T.UnitFor("Nobody Here") == nil,
    "unit tokens: party members by key, me = player, outsiders none")

ns.settings.clanView = "mine"
UI.Open("clans")
Tick(1)
local cp
for _, o in ipairs(CREATED) do if o.cols and o.roleBtns then cp = o end end
local p = cp.roll
check(p.res[1].targetBtn and p.res[1].targetBtn._parent == UIParent and p.res[1].targetBtn._template:find("SecureActionButtonTemplate", 1, true),
    "Target is a secure button parented to UIParent, not to our window")
-- Anchored to a row it would make the whole window protected: pass-through for keys can't then be set and
-- / and Enter never reach chat while the window is open. Only ever placed against UIParent.


p.start:Click(); Tick(1)
Roll("Bluey Heeler", 40)
Roll("Bingo Heeler", 88)
Tick(1)
local top = p.res[1]
check(top.left:GetText():find("Bingo Heeler", 1, true), "the list shows the full name (first and second)")
check(top.key == "Bingo Heeler" and top.whisperBtn:IsShown() and top.targetBtn:IsShown(), "Whisper and Target on Bingo's row")

local opened
local real = ns.Whisper.Open
ns.Whisper.Open = function(m, text) opened = { m = m, text = text } end
top.whisperBtn:Click()
check(opened and opened.m.name == "Bingo Heeler" and opened.text == nil, "Whisper opens the box to Bingo, empty while the roll runs")

R.Stop(); Tick(1)
check(R.cur.winner == "Bingo Heeler", "Bingo won")
opened = nil
top.whisperBtn:Click()
check(opened and opened.text == R.WhisperLine(R.cur), "after the roll, the winner's whisper has You won filled in")
opened = nil
p.res[2].whisperBtn:Click()
check(opened and opened.m.name == "Bluey Heeler" and opened.text == nil, "a non-winner's whisper starts empty")
ns.Whisper.Open = real

-- Someone not in my group (left the party): no Target, Whisper stays.
FAKE.party = { "Bluey Heeler" }
FAKE.group = 2
FireEvent("GROUP_ROSTER_UPDATE"); UI.Dirty(); Tick(1)
check(top.targetBtn:IsShown() and not top.targetBtn:IsEnabled() and top.whisperBtn:IsShown(), "Bingo left the group: Target greyed out, Whisper still there")
FAKE.party, FAKE.group = { "Bluey Heeler", "Bingo Heeler" }, 3
UI.Dirty(); Tick(1)
check(top.targetBtn:IsShown() and top.targetBtn:IsEnabled(), "back in the group: Target works again")

-- A fight: every Target hides at the start; nothing secure is touched during it; back after.
FireEvent("PLAYER_REGEN_DISABLED")
FAKE.combat = true
check(not top.targetBtn:IsShown(), "a fight starts: Target hidden")
UI.Dirty(); Tick(1)
check(not top.targetBtn:IsShown(), "a redraw in the fight doesn't bring it back")
FAKE.combat = nil
FireEvent("PLAYER_REGEN_ENABLED"); Tick(1)
UI.Dirty(); Tick(1)
check(top.targetBtn:IsShown(), "after the fight: Target back")

-- History hides the rows, and their Target buttons with them.
p.histBtn:Click(); Tick(1)
check(not top.targetBtn:IsShown(), "History: the Target buttons go with the rows")
p.histBtn:Click(); Tick(1)
check(top.targetBtn:IsShown(), "back from History: Target again")

-- Someone not in my group (like the sim's fake guildies, who are never real group members): Target
-- shows greyed out.
local fake = "Bandit Heeler"
local row = p.res[3]
row:Show()
T.Set(row, fake)
check(row.targetBtn:IsShown() and not row.targetBtn:IsEnabled(), "not in my group: Target greyed out")
T.Set(row, ns.me)
check(not row.targetBtn:IsShown() and not row.whisperBtn:IsShown(), "my own row: no Whisper or Target")

-- Typing in the roll panel, then the window closes or the view changes: the keyboard is let go, so
-- / and Enter open the game's chat again.
p.histBtn:Click(); Tick(1)
p.histBtn:Click(); Tick(1)
p.msg:SetFocus()
check(GetCurrentKeyBoardFocus() == p.msg, "typing in the Message box")
UI.Select("home"); Tick(1)
check(GetCurrentKeyBoardFocus() == nil, "another tab: the hidden box lets go of the keyboard")
UI.Select("clans"); Tick(1)
p.item:SetFocus()
UI.Toggle(); Tick(1)
check(GetCurrentKeyBoardFocus() == nil, "the window closed: the keyboard is let go")

do  -- after everything above has shown and placed them
    local placed, bad = 0, 0
    for _, t in ipairs(ns.RollTarget.Buttons()) do
        if t._pt then placed = placed + 1; if t._pt[2] ~= UIParent then bad = bad + 1 end end
    end
    check(placed > 0 and bad == 0, "Target buttons are placed against UIParent, never anchored to our window's rows ("
        .. placed .. " placed, " .. bad .. " anchored to a row)")
end

-- The pop-out has the same buttons: full names, Whisper ("You won" for the winner), Target placed against
-- UIParent; dragging it moves its Target buttons with it every frame; closing it takes them away.
do
    if InCombatLockdown() then FAKE.combat = false; FireEvent("PLAYER_REGEN_ENABLED") end
    FAKE.group, FAKE.party = 3, { "Bluey Heeler", "Bingo Heeler" }
    p.start:Click(); Tick(1)
    Roll("Bluey Heeler", 30)
    Roll("Bingo Heeler", 77)
    R.Stop(); Tick(1)
    ns.ClanRollUI.OpenPop(false, "Orc"); Tick(1)
    local pop
    for _, o in ipairs(CREATED) do if o.rows and o.missText then pop = o end end
    check(pop and pop:IsShown(), "the pop-out is open")
    local row = pop.rows[1]
    check(row.left:GetText():find("Bingo Heeler", 1, true), "pop-out: full names")
    check(row.whisperBtn and row.whisperBtn:IsShown() and row.targetBtn and row.targetBtn:IsShown()
        and row.targetBtn:IsEnabled(), "pop-out: Whisper and Target on the winner's row, Target working (in my group)")
    check(row.targetBtn._parent == UIParent and row.targetBtn._pt and row.targetBtn._pt[2] == UIParent,
        "pop-out: Target placed against UIParent, not anchored to the pop-out")
    local opened2
    local real2 = ns.Whisper.Open
    ns.Whisper.Open = function(m, text) opened2 = { m = m, text = text } end
    row.whisperBtn:Click()
    ns.Whisper.Open = real2
    check(opened2 and opened2.m.name == "Bingo Heeler" and opened2.text == R.WhisperLine(R.cur), "pop-out: the winner's Whisper has You won filled in")
    -- Dragged while the roll list keeps redrawing: Target follows the window every frame, not every redraw.
    local t = row.targetBtn
    pop:GetScript("OnDragStart")(pop)
    check(ns.RollTarget.Dragging() == pop and t:IsShown(), "pop-out dragged: its Target buttons stay up and follow it")
    for _, r in ipairs(pop.rows) do r._left = 640 end    -- the window has moved
    Tick(0.1)
    check(t._pt and t._pt[2] == UIParent and math.abs(t._pt[4] - (640 + t.dx)) < 0.01,
        "pop-out dragged: Target moved with it on the next frame (x " .. tostring(t._pt and t._pt[4]) .. ")")
    pop:GetScript("OnDragStop")(pop)
    check(ns.RollTarget.Dragging() == nil and t:IsShown(), "pop-out dropped: Target stays, following stops")
    for _, r in ipairs(pop.rows) do r._left = nil end
    ns.ClanRollUI.ClosePop(); Tick(1)
    check(not row.targetBtn:IsShown(), "pop-out closed: its Target buttons go too")
end
