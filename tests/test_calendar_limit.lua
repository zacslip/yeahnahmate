-- Calendar limit (25 Nov): one guildie can have at most 15 upcoming events. A weekly event counts once
-- (it never runs out, so it keeps its place until cancelled). Edits to events they have still go
-- through; past and cancelled ones don't count. Mine: Save says why (and the new-event form shows it).
-- Others': a 16th straight from them is kept (their addon keeps the limit; an older one may not, and my
-- count can be stale); a 16th that comes only as a copy is not (test_calendar_limit_copies.lua).
math.randomseed(25)
YeahNahMateDB = nil
local ns = LoadAddon("YeahNahMate", "YeahNahMate")
LOGGED_IN = true
FireEvent("PLAYER_LOGIN")
local Ser = LibStub("AceSerializer-3.0")
local function Msg(t) t.v = 1; return Ser:Serialize(t) end
local C, L = ns.Calendar, ns.L
ns.settings.sharePosition, ns.settings.shareProfessions = false, false
Tick(15)
local now = GetServerTime()
local store = C.Store()
check(C.MAX_OWN == 15, "the limit is 15")

-- Mine: 14 one-offs and a weekly one fill it.
local keys = {}
for i = 1, 14 do keys[i] = C.Save(nil, { title = "Run " .. i, at = now + i * 3600, k = "s" }) end
keys[15] = C.Save(nil, { title = "Weekly raid", at = now + 86400, k = "s", w = true })
check(keys[15] and C.OwnCount(ns.me) == 15 and C.Full(), "15 upcoming events (a weekly one counts once)")
local key, why = C.Save(nil, { title = "One too many", at = now + 7200, k = "s" })
check(key == nil and why == "full", "the 16th is refused: full")
-- An edit still goes through, the weekly one too.
check(C.Save(keys[3], { title = "Run 3 (moved)", at = now + 50000, k = "s" }) == keys[3], "editing one I have still works")
check(C.Save(keys[15], { title = "Weekly raid", at = now + 90000, k = "s", w = true }) == keys[15], "editing the weekly one still works")
-- Cancelling one frees a place.
C.Cancel(keys[1])
check(not C.Full() and C.Save(nil, { title = "Now there's room", at = now + 7200, k = "s" }) ~= nil, "a cancel makes room")
check(C.Full(), "full again")
-- A one-off that has been and gone frees a place (3 hours after it starts).
Tick(2 * 3600 + 3 * 3600 + 60)     -- Run 2 and "Now there's room" (both now + 2h) are over
check(C.OwnCount(ns.me) == 13, "past events don't count (" .. C.OwnCount(ns.me) .. ")")
-- The weekly one never runs out.
C.Save(nil, { title = "Fill", at = GetServerTime() + 3600, k = "s" })
check(C.Save(nil, { title = "Fill 2", at = GetServerTime() + 3600, k = "s" }) ~= nil and C.Full(), "full again")
now = GetServerTime()

-- The new-event form says why up front; Save says it in chat.
ns.UI.Open("calendar")
local cal
for _, o in ipairs(CREATED) do if o.form and o.dayPager then cal = o end end
local f = cal.form
cal.mode, cal.editKey, cal.formLoaded = "new", nil, false
ns.UI.Select("calendar")
Tick(1)
local msg = string.format(L.EVENT_FULL, 15)
check(f.tip:IsShown() and f.tip:GetText():find(msg, 1, true), "the form shows why")
f.title:SetText("Sixteen")
local printed = #PRINTED
f.save:Click()
Tick(1)
local said = false
for i = printed + 1, #PRINTED do if tostring(PRINTED[i]):find(msg, 1, true) then said = true end end
check(said, "Save says why in chat")
check(C.OwnCount(ns.me) == 15, "and nothing was added")
-- Editing one of mine: the normal tip.
cal.mode, cal.editKey, cal.formLoaded = "edit", keys[4], false
ns.UI.Dirty(); Tick(1)
check(f.tip:GetText() == L.EVENT_TIP, "editing: the normal tip")
cal.mode = nil
ns.UI.Dirty(); Tick(1)

-- Another guildie's, straight from them: all kept, the 16th too; an edit still goes through.
for i = 1, 15 do
    INJECT("YNM", Msg({ t = "EVT", id = 100 + i, ti = "Bluey " .. i, at = now + i * 3600, k = "s", ev = now }), "GUILD", "Bluey Heeler")
end
INJECT("YNM", Msg({ t = "EVT", id = 200, ti = "Bluey 16", at = now + 99000, k = "s", ev = now }), "GUILD", "Bluey Heeler")
Tick(1)
check(C.OwnCount("Bluey Heeler") == 16 and store["Bluey Heeler:200"] ~= nil, "a guildie's 16th straight from them is kept (their word)")
INJECT("YNM", Msg({ t = "EVT", id = 105, ti = "Bluey 5 (moved)", at = now + 80000, k = "s", ev = now + 1 }), "GUILD", "Bluey Heeler")
Tick(1)
check(store["Bluey Heeler:105"].title == "Bluey 5 (moved)", "their edit still goes through")
-- A past one from them is harmless (it doesn't add an upcoming one), so it's kept.
INJECT("YNM", Msg({ t = "EVT", id = 201, ti = "Last week", at = now - 5 * 86400, k = "s", ev = now }), "GUILD", "Bluey Heeler")
Tick(1)
check(store["Bluey Heeler:201"] ~= nil, "a past event from them is kept")
-- They cancel one and make another: both heard.
INJECT("YNM", Msg({ t = "EVT", id = 101, x = true, ev = now + 2 }), "GUILD", "Bluey Heeler")
INJECT("YNM", Msg({ t = "EVT", id = 202, ti = "Bluey new", at = now + 7200, k = "s", ev = now + 2 }), "GUILD", "Bluey Heeler")
Tick(1)
check(store["Bluey Heeler:202"] ~= nil and store["Bluey Heeler:101"].x and C.OwnCount("Bluey Heeler") == 16, "after a cancel, a new one is kept")

check(#ERRORS == 0, "no errors (" .. tostring(ERRORS[1]) .. ")")
