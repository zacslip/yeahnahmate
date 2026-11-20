-- The Recruiters drawer (UI/Recruit.lua): the handshake tab on the window's right edge with a "!" until
-- I've answered; Share rows open the whisper box; answering by a suggestion or "Someone else"; the
-- leaderboard (All time / This month); a manager's right-click to take a claim off; the Settings line.
math.randomseed(17)
YeahNahMateDB = nil
FAKE.myRank = 0                 -- Ned Jones, the guild master
local ns = LoadAddon("YeahNahMate", "YeahNahMate")
LOGGED_IN = true
FireEvent("PLAYER_LOGIN")
local Ser = LibStub("AceSerializer-3.0")
local function Msg(t) t.v = 1; return Ser:Serialize(t) end
local UI, L, R = ns.UI, ns.L, ns.Recruit
ns.settings.sharePosition, ns.settings.shareProfessions = false, false
Tick(15)
INJECT("YNM", Msg({ t = "HI", ver = ns.VERSION }), "GUILD", "Bluey Heeler")
local now = GetServerTime()
INJECT("YNM", Msg({ t = "RSH", to = "Ned Jones", at = now - 600 }), "GUILD", "Bluey Heeler")
Tick(2)

UI.Open("home")
local tab, drawer = UI.recruitTab, UI.recruitPanel
local panel = drawer.addon
check(tab and panel and UI.recruitTabs.guild == nil, "the window has the addon recruiting tab (no guild tab) and the drawer")
check(tab._pt and tab._pt[5] == -14, "the tab sits up by the version")
check(UI.recruitHolder._pt and UI.recruitHolder._pt[2] == YeahNahMateFrame and tostring(UI.recruitHolder._pt[3]):find("RIGHT", 1, true),
    "on the window's right edge")
check(tab.bang:IsShown(), "a ! on the tab: I haven't answered")
check(not UI.RecruitOpen(), "shut at first")
tab:Click()
Tick(0.5)
check(UI.RecruitOpen() and drawer:IsShown() and panel:IsShown(), "click: it slides open")

-- The question, with Bluey suggested (he shared with me).
check(panel.question:IsShown() and not panel.answer:IsShown(), "the question shows")
check(panel.body.top == -150, "Share sits under the question")
local sug = panel.question.suggest[1]
check(sug:IsShown() and sug.name == "Bluey Heeler", "Bluey is suggested")

-- Share rows: Bingo and Chilli (online, no addon).
local rows = {}
for _, r in ipairs(panel.shareRows) do if r:IsShown() then rows[#rows + 1] = r.c.name end end
check(table.concat(rows, ",") == "Bingo Heeler,Chilli Heeler", "share list", table.concat(rows, ","))
panel.shareRows[1].share:Click()
local wbox = _G.YeahNahMateWhisper
check(wbox and wbox:IsShown() and wbox.edit:GetText() == L.RECRUIT_MSG_DEFAULT, "Share: the whisper box, with the message")
wbox.edit._scripts.OnEnterPressed(wbox.edit)
Tick(1)
check(#WHISPERS == 1 and WHISPERS[1].target == "Bingo Heeler", "Enter sends it to Bingo")
check(panel.shareRows[1].share:GetText() == L.RECRUIT_SHARED and not panel.shareRows[1].share:IsEnabled(), "now Shared (once a week)")

-- "Someone else": the picker lists guildies with the addon; picking answers.
local other
for _, o in ipairs(CREATED) do if o._text == L.RECRUIT_SOMEONE_ELSE then other = o end end
other:Click()
check(panel.picker:IsShown(), "the picker opens")
local first = panel.picker.rows[1]
check(first:IsShown() and first.who == "Bluey Heeler", "it lists Bluey (has the addon)")
first:Click()
Tick(1)
check(not panel.picker:IsShown() and R.MyClaim() and R.MyClaim().by == "Bluey Heeler", "picked: Bluey got me onto it")
check(not tab.bang:IsShown() and panel.answer:IsShown() and not panel.question:IsShown(), "answered: no !, my answer shows")

-- The leaderboard.
check(panel.boardRows[1]:IsShown() and panel.boardRows[1].e.name == "Bluey Heeler" and panel.boardRows[1].count:GetText() == "1",
    "Bluey 1 on the leaderboard")
local s = R.Store()
s.claims["Bandit Heeler"] = { by = "Bluey Heeler", at = now - 40 * 86400 }
UI.RecruitRefresh()
check(panel.boardRows[1].count:GetText() == "2", "all time: 2")
local monthBtn
for _, o in ipairs(CREATED) do if o._text == L.RECRUIT_THIS_MONTH then monthBtn = o end end
monthBtn:Click()
check(panel.boardRows[1].count:GetText() == "1", "this month: 1")

-- A manager takes a claim off: right-click, then click twice.
panel.boardRows[1]._scripts.OnClick(panel.boardRows[1], "RightButton")
local menu = panel.hideMenu
check(menu:IsShown() and menu.rows[1]:IsShown(), "right-click: the take-off menu")
menu.rows[1]:Click()
check(menu:IsShown(), "first click asks Sure?")
menu.rows[1]:Click()
check(not menu:IsShown() and R.IsHidden(ns.Alts.Person(menu.rows[1].who)), "second click takes it off")

-- Settings: the recruitment message line.
UI.Select("settings")
local edit
for _, o in ipairs(CREATED) do if o._template == "InputBoxTemplate" and o._scripts.OnEditFocusLost and o._text == L.RECRUIT_MSG_DEFAULT then edit = o end end
check(edit ~= nil, "Settings shows the message (the default)")
edit:SetText("G'day mate, get the addon")
edit._scripts.OnEditFocusLost(edit)
check(ns.settings.recruitMsg == "G'day mate, get the addon" and R.Message() == "G'day mate, get the addon", "a new message is saved")
edit:SetText("")
edit._scripts.OnEditFocusLost(edit)
check(ns.settings.recruitMsg == nil and edit:GetText() == L.RECRUIT_MSG_DEFAULT, "emptied: back to the default")

check(#ns.db.errors == 0, "no errors " .. tostring(ns.db.errors[1] and ns.db.errors[1].msg))

-- The layout: once answered, Share moves up into the question's space (no gap); the tab opens and shuts.
check(panel.body.top == -82, "answered: Share moved up into the question's space (no gap)")
UI.Open("home")
if UI.RecruitOpen() then tab:Click() end
check(not UI.RecruitOpen(), "clicking the open tab shuts it")
tab:Click()
check(UI.RecruitOpen() and panel:IsShown(), "and again opens it")

-- The open tab glows (its icon stays); the shut one doesn't.
check(tab.sel == true, "the open tab glows")

-- Settings: the Welcome button at the top; the recruiting messages at the bottom; no Privacy box.
UI.Select("settings")
local welcome, privacyBox
for _, o in ipairs(CREATED) do
    if o._text == L.SET_WELCOME and o.Click then welcome = o end
    if type(o._text) == "string" and o._text:find(L.PRIVACY .. "|r", 1, true) then privacyBox = o end
end
check(welcome and welcome._pt and welcome._pt[3] == -388, "the Welcome page button sits at the bottom, under the share message")
check(privacyBox == nil, "no Privacy box any more")
