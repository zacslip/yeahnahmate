-- Review fixes (v0.17.2): every kind of pop-up can be switched off, and the main window comes to the
-- front when it opens.
YeahNahMateDB = nil
local ns = LoadAddon("YeahNahMate", "YeahNahMate")
LOGGED_IN = true
FireEvent("PLAYER_LOGIN")
Tick(2)
local UI = ns.UI

UI.Open("settings")
Tick(0.5)

-- 1. Every pop-up kind has a switch: in Settings, or (voice) in the voice drawer.
local inSettings = {}
for _, k in ipairs(UI.POP_KINDS) do inSettings[k[1]] = true end
local missing = {}
for kind in pairs(ns.DEFAULTS.settings.pop) do
    if not inSettings[kind] and not UI.POP_ELSEWHERE[kind] then missing[#missing + 1] = kind end
end
table.sort(missing)
check(#missing == 0, "every pop-up kind has a switch (missing: " .. table.concat(missing, ", ") .. ")")

-- The voice one is in the drawer, and it works.
local panel = UI.voicePanel
check(panel and panel.popCheck ~= nil and panel.popCheck:GetChecked() == true, "the drawer has the group voice pop-up tick, on by default")
panel.popCheck:SetChecked(false); panel.popCheck:Click()
check(ns.settings.pop.voice == false and not ns.Toast.Allowed("voice"), "unticking it stops group voice pop-ups")
panel.popCheck:SetChecked(true); panel.popCheck:Click()
check(ns.settings.pop.voice == true and ns.Toast.Allowed("voice"), "ticking it again lets them through")

-- 2. Opening the window lifts it above other windows (an OnShow hook was replaced by a later script).
local frame = YeahNahMateFrame
UI.Toggle()                     -- shut
Tick(0.5)
local raised = 0
frame.Raise = function() raised = raised + 1 end
UI.Toggle()                     -- open again
Tick(0.5)
check(frame:IsShown() and raised == 1, "opening the window raises it (" .. raised .. ")")

check(#ERRORS == 0, "no errors (" .. tostring(ERRORS[1]) .. ")")
