-- 0.8.5: one switch per kind of pop-up. An old save with the single "popups" tick off carries over as
-- every kind off; the Gather pop-up (it used to ignore the setting) now has a switch of its own.
math.randomseed(85)
YeahNahMateDB = { settings = { popups = false, popupSound = true } }
local ns = LoadAddon("YeahNahMate", "YeahNahMate")
LOGGED_IN = true
FireEvent("PLAYER_LOGIN")
local s = ns.settings
check(s.popups == nil, "the old popups setting is gone")
local allOff = true
for _, on in pairs(s.pop) do if on then allOff = false end end
check(allOff and s.pop.gather == false, "old 'pop-ups off' carried over: every kind off")
check(s.remind == true, "reminders keep their own switch (still on)")

local Toast = ns.Toast
Toast.Show("Gather", "x", "gather")
check(not Toast.IsShown(), "gather pop-up switched off: nothing shows")
s.pop.gather = true
Toast.Show("Gather", "x", "gather")
check(Toast.IsShown(), "gather switched on: it shows")
check(Toast.Allowed(nil) and Toast.Allowed("remind"), "no kind always shows; reminders follow their own switch")
s.remind = false
check(not Toast.Allowed("remind"), "reminders off")

-- A fresh save: every kind on but requests I can make (opt in since 0.13.0).
YeahNahMateDB = nil
FireEvent("ADDON_LOADED", "YeahNahMate")
local fresh = true
for k, on in pairs(ns.settings.pop) do if not on and k ~= "request" then fresh = false end end
check(fresh and ns.settings.pop.request == false and ns.settings.popups == nil, "fresh save: every pop-up on, request alerts off")
-- A save from before 0.13.0 with request pop-ups on: off once (opt in), then left as the player sets it.
YeahNahMateDB = { schema = 2, settings = { pop = { request = true } } }
FireEvent("ADDON_LOADED", "YeahNahMate")
check(ns.settings.pop.request == false and ns.settings.reqOptIn == true, "an older save: request alerts turned off once")
YeahNahMateDB = { schema = 2, settings = { reqOptIn = true, pop = { request = true } } }
FireEvent("ADDON_LOADED", "YeahNahMate")
check(ns.settings.pop.request == true, "turned back on, they stay on")
check(#ERRORS == 0, "no errors (" .. (ERRORS[1] or "none") .. ")")

-- 0.8.6: Settings shows our memory use (a guildie asked); checked when the tab is shown, not on redraws.
ns.UI.Open("settings")
local set
for _, o in ipairs(CREATED) do if o.memory and o.pops then set = o end end
check(set and set.memory:GetText():find("1.2 MB", 1, true), "Settings shows the memory line (" .. tostring(set and set.memory:GetText()) .. ")")
local updates = MEMORY_UPDATES
for _ = 1, 5 do ns.UI.Dirty(); Tick(1) end
check(MEMORY_UPDATES == updates, "redraws don't re-check memory")
FAKE.memoryKB = 300
Tick(11)
ns.UI.Select("home"); ns.UI.Select("settings")
check(MEMORY_UPDATES == updates + 1 and set.memory:GetText():find("300 KB", 1, true), "showing the tab again re-checks it")
FAKE.combat = true
Tick(11)
ns.UI.Select("home"); ns.UI.Select("settings")
check(MEMORY_UPDATES == updates + 1, "not in combat")
FAKE.combat = false
check(#ERRORS == 0, "no errors after the memory line (" .. (ERRORS[1] or "none") .. ")")
