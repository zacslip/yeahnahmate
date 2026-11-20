-- The About panel (UI/About.lua): an "i" button right of the version in the banner opens a panel with
-- the version (and a newer one a guildie has), the slash commands, and how to report a problem.
YeahNahMateDB = nil
local ns = LoadAddon("YeahNahMate", "YeahNahMate")
LOGGED_IN = true
FireEvent("PLAYER_LOGIN")
Tick(15)
local UI, L = ns.UI, ns.L

UI.Open("home")
local b = UI.aboutButton
check(b ~= nil, "the window has the i button")
check(b and b._pt and b._pt[1] == "LEFT" and b._pt[3] == "RIGHT" and b._w == 20, "placed just right of the version text, 20 px")
check(UI.AboutPanel() == nil, "no panel until it's clicked")

b:Click()
local p = UI.AboutPanel()
check(p and p:IsShown(), "click: the panel opens")

-- Everything written on it.
local texts = {}
for _, o in ipairs(CREATED) do
    local par = o._parent
    while par and par ~= p do par = par._parent end
    if par == p and o._text then texts[#texts + 1] = o._text end
end
local all = table.concat(texts, "\n")
check(all:find(ns.VERSION, 1, true), "shows my version")
check(all:find(L.ABOUT_UPTODATE, 1, true), "nobody newer: says so")
for _, c in ipairs(UI.ABOUT_COMMANDS) do
    check(all:find(c[1], 1, true) and all:find(L[c[2]], 1, true), "lists " .. c[1])
end
check(all:find(L.ABOUT_PROBLEM, 1, true), "says how to report a problem")

-- Every command listed is one the addon really handles (not the help line).
local printed = {}
local realPrint = ns.Print
ns.Print = function(s) printed[#printed + 1] = s end
for _, c in ipairs(UI.ABOUT_COMMANDS) do
    local first = c[1]:match("^/ynm%s*(%S*)")
    if first ~= "" and first ~= "voice" then
        printed = {}
        ns.Slash(first)
        check(printed[1] ~= L.HELP, c[1] .. " is a real command")
    end
end
ns.Print = realPrint

-- A guildie has a newer version: shown when the panel opens again.
b:Click()
check(not p:IsShown(), "click again: closes")
ns.Comm.newest = "9.9.9"
b:Click()
check(p.version:GetText():find("9.9.9", 1, true), "a newer version in the guild: says so")
ns.Comm.newest = nil

-- Closing the window closes the panel, so it isn't open next time.
YeahNahMateFrame:Hide()
check(not p:IsShown(), "window closed: panel closed")

check(#ns.db.errors == 0, "no errors " .. tostring(ns.db.errors[1] and ns.db.errors[1].msg))
