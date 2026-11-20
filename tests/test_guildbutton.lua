-- Our tab on Blizzard's Guild & Communities window (UI/GuildButton.lua; on by default, Settings turns
-- it off): made only when their window is loaded by the game, placed under their lowest shown tab, a
-- click closes theirs (never in combat) and opens ours; the probe reports what it found.
YeahNahMateDB = nil
local ns = LoadAddon("YeahNahMate", "YeahNahMate")
LOGGED_IN = true
FireEvent("PLAYER_LOGIN")
Tick(15)
local GB = ns.GuildButton

check(GB.On() and ns.settings.guildButton == true, "on by default")
check(GB.Button() == nil, "but their window isn't loaded yet: no button (we never load it ourselves)")

-- Settings has the tick.
ns.UI.Open("settings")
local tick
for _, o in ipairs(CREATED) do if o._text == ns.L.SET_GUILDBTN then tick = o end end
check(tick ~= nil, "Settings shows the guild window button tick")

-- The game loads their window (the first J): a fake one with four tabs, 32 high, 17 apart.
CommunitiesFrame = CreateFrame("Frame", "CommunitiesFrame", UIParent)
local tops = { ChatTab = 600, RosterTab = 551, GuildBenefitsTab = 502, GuildInfoTab = 453 }
for key, top in pairs(tops) do
    local t = CreateFrame("CheckButton", nil, CommunitiesFrame)
    t.GetTop = function() return top end
    t.GetBottom = function() return top - 32 end
    t:Show()
    CommunitiesFrame[key] = t
end
-- Forever has a fifth tab under Guild info (a settings tab) that we don't know by name: only found by
-- being in the same column.
local kids = {}
for key in pairs(tops) do kids[#kids + 1] = CommunitiesFrame[key] end
for _, t in ipairs(kids) do t.GetLeft = function() return 900 end; t.GetWidth = function() return 32 end end
local settingsTab = CreateFrame("CheckButton", nil, CommunitiesFrame)
settingsTab.GetTop = function() return 404 end
settingsTab.GetBottom = function() return 372 end
settingsTab.GetLeft = function() return 900 end
settingsTab.GetWidth = function() return 32 end
settingsTab:Show()
CommunitiesFrame.SettingsTabWeDontKnow = settingsTab
kids[#kids + 1] = settingsTab
-- Something else of theirs, not in the column: ignored.
local other = CreateFrame("Button", nil, CommunitiesFrame)
other.GetTop = function() return 100 end; other.GetBottom = function() return 10 end
other.GetLeft = function() return 300 end; other.GetWidth = function() return 32 end
other:Show()
kids[#kids + 1] = other
CommunitiesFrame.GetChildren = function()
    local out = {}
    for _, k in ipairs(kids) do out[#out + 1] = k end
    if GB.Button() then out[#out + 1] = GB.Button() end
    return unpack(out)
end
CommunitiesFrame:Show()
FireEvent("ADDON_LOADED", "Blizzard_Communities")
local b = GB.Button()
check(b ~= nil, "their window loaded: our button is made")
check(b and b:GetParent() == CommunitiesFrame, "parented to their window (shows and hides with it)")
check(b and b._pt and b._pt[2] == settingsTab and b._pt[5] == -17,
    "placed under their lowest tab (the unnamed fifth one), same gap", b and b._pt and tostring(b._pt[5]))
settingsTab:Hide()
b:GetScript("OnUpdate")(b, 0.6)
check(b._pt[2] == CommunitiesFrame.GuildInfoTab, "fifth tab hidden: under Guild info")
settingsTab:Show()
b:GetScript("OnUpdate")(b, 0.6)

-- A tab goes (another community): it moves up under the new lowest.
settingsTab:Hide(); CommunitiesFrame.GuildInfoTab:Hide()
Tick(0.6)
b:GetScript("OnUpdate")(b, 0.6)
check(b._pt[2] == CommunitiesFrame.GuildBenefitsTab, "a tab hidden: our button moves up under the new lowest")
CommunitiesFrame.GuildInfoTab:Show(); settingsTab:Show()
b:GetScript("OnUpdate")(b, 0.6)

-- Click: theirs closes, ours opens.
if YeahNahMateFrame then YeahNahMateFrame:Hide() end
b:Click()
check(not CommunitiesFrame:IsShown(), "click: their window closes")
check(YeahNahMateFrame and YeahNahMateFrame:IsShown(), "and ours opens")
check(GB.last == "their window closed, ours opened", "last click noted", tostring(GB.last))

-- In combat: theirs is left alone.
CommunitiesFrame:Show()
FAKE.combat = true
b:Click()
check(CommunitiesFrame:IsShown() and GB.last:find("in combat", 1, true), "in combat: their window is left open")
FAKE.combat = false

-- The probe.
local lines = GB.Probe()
local all = table.concat(lines, "\n")
check(all:find("Tabs found: 4 of 4 named, 1 more", 1, true) and all:find("goes under: SettingsTabWeDontKnow", 1, true) and all:find("ChatTab: shown", 1, true), "probe: finds their four tabs", all)
check(ns.db.dev.guildProbe and #ns.db.dev.guildProbe.lines == #lines, "probe saved for after /reload")

-- Switched off: our button hides.
GB.Set(false)
check(not b:IsShown() and not GB.On(), "switched off: our button is hidden")

CommunitiesFrame = nil
check(#ns.db.errors == 0, "no errors " .. tostring(ns.db.errors[1] and ns.db.errors[1].msg))
