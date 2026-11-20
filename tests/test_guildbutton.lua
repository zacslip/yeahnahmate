-- Our tab on Blizzard's Guild & Communities window (UI/GuildButton.lua, dev only for now): made only
-- when their window is loaded by the game, placed under their lowest shown tab, a click closes theirs
-- (never in combat) and opens ours; the probe reports what it found.
YeahNahMateDB = nil
local ns = LoadAddon("YeahNahMate", "YeahNahMate")
LOGGED_IN = true
FireEvent("PLAYER_LOGIN")
Tick(15)
local GB = ns.GuildButton

check(GB.Button() == nil, "off by default: no button")
check(not GB.On(), "the dev switch is off by default")

-- Switched on before their window has loaded: nothing made yet, and we never load it ourselves.
GB.Set(true)
check(GB.On() and GB.Button() == nil, "on, but their window isn't loaded: no button yet")

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
CommunitiesFrame:Show()
FireEvent("ADDON_LOADED", "Blizzard_Communities")
local b = GB.Button()
check(b ~= nil, "their window loaded: our button is made")
check(b and b:GetParent() == CommunitiesFrame, "parented to their window (shows and hides with it)")
check(b and b._pt and b._pt[2] == CommunitiesFrame.GuildInfoTab and b._pt[5] == -17,
    "placed under their lowest tab, same gap", b and b._pt and tostring(b._pt[5]))

-- A tab goes (another community): it moves up under the new lowest.
CommunitiesFrame.GuildInfoTab:Hide()
Tick(0.6)
b:GetScript("OnUpdate")(b, 0.6)
check(b._pt[2] == CommunitiesFrame.GuildBenefitsTab, "a tab hidden: our button moves up under the new lowest")
CommunitiesFrame.GuildInfoTab:Show()
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
check(all:find("Tabs found: 4 of 4", 1, true) and all:find("ChatTab: shown", 1, true), "probe: finds their four tabs", all)
check(ns.db.dev.guildProbe and #ns.db.dev.guildProbe.lines == #lines, "probe saved for after /reload")

-- Switched off: our button hides.
GB.Set(false)
check(not b:IsShown() and not GB.On(), "switched off: our button is hidden")

CommunitiesFrame = nil
check(#ns.db.errors == 0, "no errors " .. tostring(ns.db.errors[1] and ns.db.errors[1].msg))
