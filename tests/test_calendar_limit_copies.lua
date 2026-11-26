-- Calendar limit for copies (26 Nov review): a guildie's 16th upcoming event that reaches me only as a
-- copy (relayed by another guildie) is not kept; their own word always is (test_calendar_limit.lua).
math.randomseed(13)
YeahNahMateDB = nil
local ns = LoadAddon("YeahNahMate", "YeahNahMate")
LOGGED_IN = true
FireEvent("PLAYER_LOGIN")
local Ser = LibStub("AceSerializer-3.0")
local function Msg(t) t.v = 1; return Ser:Serialize(t) end
local C = ns.Calendar
ns.settings.sharePosition, ns.settings.shareProfessions = false, false
INJECT("YNM", Msg({ t = "HI", ver = "0.28.0" }), "GUILD", "Bluey Heeler")
Tick(15)
local now = GetServerTime()
local store = C.Store()
local A = "Chilli Heeler"
for i = 1, 15 do
    INJECT("YNM", Msg({ t = "EVT", id = 100 + i, ti = "Chilli " .. i, at = now + i * 3600, k = "s", ev = now - 100 }), "GUILD", A)
end
Tick(1)
check(C.OwnCount(A) == 15, "Chilli's 15 heard straight from Chilli")
Tick(30)                                     -- 40 s after login: a guildie is asked for the calendar
local peer
for i = #SENT, 1, -1 do
    local ok, m = Ser:Deserialize(SENT[i].text)
    if ok and type(m) == "table" and m.t == "REQ" and m.w == "CAL" then peer = SENT[i].target; break end
end
check(peer == "Bluey Heeler", "asked Bluey for the calendar")
INJECT("YNM", Msg({ o = A, t = "EVT", id = 200, ti = "Copy 16", at = now + 99000, k = "s", ev = now - 10 }), "WHISPER", peer)
INJECT("YNM", Msg({ o = A, t = "EVT", id = 105, ti = "Chilli 5 (moved)", at = now + 80000, k = "s", ev = now - 10 }), "WHISPER", peer)
Tick(1)
check(store[A .. ":200"] == nil and C.OwnCount(A) == 15, "a 16th that only comes as a copy isn't kept")
check(store[A .. ":105"].title == "Chilli 5 (moved)", "a copy of an edit to one of the 15 still is")
INJECT("YNM", Msg({ t = "EVT", id = 200, ti = "Copy 16", at = now + 99000, k = "s", ev = now }), "GUILD", A)
Tick(1)
check(store[A .. ":200"] ~= nil, "the same one straight from Chilli is kept")
check(#ERRORS == 0, "no errors (" .. tostring(ERRORS[1]) .. ")")