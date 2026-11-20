-- Phase 5: events (make, edit, cancel; only the owner), answers per occurrence, weekly events,
-- late joiners and copies, reminders, tidying, Home's next up, the tab, and sim events.
math.randomseed(6)
YeahNahMateDB = nil
local ns = LoadAddon("YeahNahMate", "YeahNahMate")
LOGGED_IN = true
FireEvent("PLAYER_LOGIN")
local Ser = LibStub("AceSerializer-3.0")
local function Msg(t) return Ser:Serialize(t) end
local function Sent(t, from, filter)
    local list = {}
    for i = (from or 1), #SENT do
        local ok, m = Ser:Deserialize(SENT[i].text)
        if ok and type(m) == "table" and m.t == t and (not filter or filter(m, SENT[i])) then
            m._target = SENT[i].target; m._channel = SENT[i].channel
            list[#list + 1] = m
        end
    end
    return list
end
local C = ns.Calendar
-- Long messages go out in pieces, so count what was sent from the log, from a given line on.
local function LogCount(pattern, fromLine)
    local n = 0
    local log = ns.GetLog()
    for i = (fromLine or 1), #log do if log[i]:find(pattern, 1, true) then n = n + 1 end end
    return n
end
ns.settings.sharePosition, ns.settings.shareProfessions = false, false
INJECT("YNM", Msg({ v = 1, t = "HI", ver = "0.5.0" }), "GUILD", "Bluey Heeler")
Tick(15)
local now = GetServerTime()
local store = C.Store()

-- Making an event.
local before = #SENT
check(C.Save(nil, { title = "", at = now + 7200, k = "d" }) == nil, "an event needs a title")
check(C.Save(nil, { title = "x", at = now + 7200, k = "z" }) == nil, "an event needs a known kind")
local key = C.Save(nil, { title = "Wailing Caverns|cff", at = now + 7200, k = "d", nt = 1, nh = 1, nd = 9, note = "Bring water" })
local e = key and store[key]
check(e and e.title == "Wailing Cavernscff" and e.nd == 4, "event saved (colour codes stripped, DPS capped at 4)")
local evt = Sent("EVT", before + 1)
check(#evt == 1 and evt[1]._channel == "GUILD" and evt[1].ti == "Wailing Cavernscff" and evt[1].at == now + 7200, "EVT sent to the guild")
local t = date("*t", now + 7200)
local onDay = C.OnDay(t.year, t.month, t.day)
check(#onDay >= 1 and onDay[1].key == key, "it shows on its day")

-- Editing: only the owner; a newer version goes out.
local v1 = e.v
before = #SENT
C.Save(key, { title = "Wailing Caverns", at = now + 9000, k = "d", nt = 1, nh = 1, nd = 3, note = "" })
evt = Sent("EVT", before + 1)
check(#evt == 1 and evt[1].ev > v1 and store[key].at == now + 9000, "edited: new time, newer version sent")

-- Someone else's event arrives; junk, future versions and impostors are dropped.
INJECT("YNM", Msg({ v = 1, t = "EVT", id = 500, ti = "Shadowfang Keep", at = now + 86400, k = "d", nt = 1, nh = 1, nd = 3, note = "", ev = now }), "GUILD", "Bluey Heeler")
INJECT("YNM", Msg({ v = 1, t = "EVT", id = 501, ti = "", at = now, k = "d", ev = now }), "GUILD", "Bluey Heeler")
INJECT("YNM", Msg({ v = 1, t = "EVT", id = 502, ti = "Later", at = now, k = "q", ev = now }), "GUILD", "Bluey Heeler")
INJECT("YNM", Msg({ v = 1, t = "EVT", id = 503, ti = "Future", at = now, k = "s", ev = now + 99999 }), "GUILD", "Bluey Heeler")
INJECT("YNM", Msg({ v = 1, t = "EVT", id = 500, x = true, ev = now + 5 }), "GUILD", "Bingo Heeler")
Tick(1)
local bkey = "Bluey Heeler:500"
check(store[bkey] and not store[bkey].x, "Bluey's event kept; Bingo can't cancel it")
check(store["Bluey Heeler:501"] == nil and store["Bluey Heeler:502"] == nil and store["Bluey Heeler:503"] == nil, "junk and future versions dropped")
check(C.Save(bkey, { title = "Mine now", at = now, k = "s" }) == nil, "I can't edit Bluey's event")
INJECT("YNM", Msg({ v = 1, t = "EVT", id = 500, ti = "Old", at = now, k = "s", ev = now - 100 }), "GUILD", "Bluey Heeler")
Tick(1)
check(store[bkey].title == "Shadowfang Keep", "an older version is ignored")

-- Answers: mine goes to the guild; Bluey's answer to my event pops up for me.
before = #SENT
C.Answer(bkey, store[bkey].at, "y", "h")
local rsvp = Sent("RSVP", before + 1)
check(#rsvp == 1 and rsvp[1]._channel == "GUILD" and rsvp[1].a == "y" and rsvp[1].r == "h" and rsvp[1].o == "Bluey Heeler", "my answer (going, healer) sent")
local a, r = C.MyAnswer(store[bkey], store[bkey].at)
check(a == "y" and r == "h", "my answer kept")
ns.Toast.Show("x", "y")
ns.UI.Open("home")
INJECT("YNM", Msg({ v = 1, t = "RSVP", o = "Ned Jones", id = store[key].id, at = store[key].at, a = "y", r = "t", rv = now }), "GUILD", "Bluey Heeler")
INJECT("YNM", Msg({ v = 1, t = "RSVP", o = "Ned Jones", id = store[key].id, at = store[key].at, a = "y", r = "t", rv = now }), "WHISPER", "Bingo Heeler")
INJECT("YNM", Msg({ v = 1, t = "RSVP", o = "Ned Jones", id = store[key].id, at = store[key].at, a = "q", rv = now }), "GUILD", "Chilli Heeler")
Tick(1)
local ans = C.Answers(store[key], store[key].at)
-- (0.8.8: a whispered answer is the guildie's own too: it's how answers reach an owner who was offline.)
check(#ans.y == 2 and ans.y[1] == "Bingo Heeler" and ans.y[2] == "Bluey Heeler" and ans.roles.t == 2,
    "Bluey and Bingo (whispered) going as tanks; the junk answer ignored")
INJECT("YNM", Msg({ v = 1, t = "RSVP", o = "Ned Jones", id = store[key].id, at = store[key].at, a = "n", rv = now - 50 }), "GUILD", "Bluey Heeler")
Tick(1)
check(C.Answers(store[key], store[key].at).y[2] == "Bluey Heeler", "an older answer doesn't replace a newer one")

-- Mute: no "going" pop-ups for that event (the owner's own switch; nothing is sent).
local answeredPops = 0
ns.Listen("ANSWERED", function() answeredPops = answeredPops + 1 end)
before = #SENT
C.ToggleMute(key)
check(store[key].mute == true and #SENT == before, "muted my event (nothing sent)")
INJECT("YNM", Msg({ v = 1, t = "RSVP", o = "Ned Jones", id = store[key].id, at = store[key].at, a = "y", rv = now + 1 }), "GUILD", "Chilli Heeler")
Tick(1)
check(answeredPops == 0 and #C.Answers(store[key], store[key].at).y == 3, "Chilli's answer counted, but no pop-up")
C.ToggleMute(bkey)
check(store[bkey].mute == nil, "can't mute someone else's event")
C.ToggleMute(key)
INJECT("YNM", Msg({ v = 1, t = "RSVP", o = "Ned Jones", id = store[key].id, at = store[key].at, a = "y", rv = now + 1 }), "GUILD", "Bingo Heeler")
Tick(1)
check(answeredPops == 1, "unmuted: pop-ups again")

-- Mute can be set when making the event, and it's never sent.
before = #SENT
local quiet = C.Save(nil, { title = "Big one", at = now + 50000, k = "s", mute = true })
evt = Sent("EVT", before + 1)
check(store[quiet].mute == true and #evt == 1 and evt[1].mute == nil, "made muted from the form; the mute isn't sent")
INJECT("YNM", Msg({ v = 1, t = "RSVP", o = "Ned Jones", id = store[quiet].id, at = store[quiet].at, a = "y", rv = now + 2 }), "GUILD", "Chilli Heeler")
Tick(1)
check(answeredPops == 1, "no pop-up for the muted event")
C.Save(quiet, { title = "Big one", at = now + 50000, k = "s", mute = false })
check(store[quiet].mute == nil, "unticking Mute in the edit form turns it off")
C.Cancel(quiet)

-- Weekly events: next occurrence, and answers belong to one occurrence.
local wkey = C.Save(nil, { title = "Levelling night", at = now - 86400, k = "s", w = true })
local we = store[wkey]
local nextAt = C.NextAt(we, now)
check(nextAt == now - 86400 + 7 * 86400, "a weekly event's next one is a week on")
local nt = date("*t", nextAt)
local found = false
for _, item in ipairs(C.OnDay(nt.year, nt.month, nt.day)) do if item.key == wkey and item.at == nextAt then found = true end end
check(found, "it shows on next week's day")
C.Answer(wkey, nextAt, "y")
check(#C.Answers(we, nextAt).y == 1 and #C.Answers(we, nextAt + 7 * 86400).y == 0, "an answer counts for that week only")

-- A guildie logging in gets my events straight from me (with answers).
FAKE.roster[5][9] = true
ns.Guild.Scan()
local logBefore = #ns.GetLog() + 1
INJECT("YNM", Msg({ v = 1, t = "HI", ver = "0.5.0", ask = true }), "GUILD", "Bandit Heeler")
Tick(10)
check(LogCount("sent my event (", logBefore) == 2 and LogCount(") to Bandit Heeler", logBefore) >= 2, "my two events whispered to Bandit as the owner")

-- Asked for the calendar: copies of others' events (marked with the owner), my own as mine.
logBefore = #ns.GetLog() + 1
INJECT("YNM", Msg({ v = 1, t = "REQ", w = "CAL" }), "WHISPER", "Chilli Heeler")
Tick(20)
local copies = LogCount("sent my Bluey Heeler's event", logBefore)
local own = LogCount("sent my event (", logBefore)
check(copies == 1 and own == 2, "answered Chilli: 1 copy (Bluey's) and my 2 (" .. copies .. ", " .. own .. ")")

-- 40 s after login we asked Bluey; copies from Bluey count, unasked ones don't.
local reqs = Sent("REQ", 1, function(m) return m.w == "CAL" end)
check(#reqs == 1 and ns.Guild.IsMember(reqs[1]._target), "asked one online guildie for the calendar after login")
local calPeer = reqs[1]._target
INJECT("YNM", Msg({ v = 1, t = "EVT", o = "Chilli Heeler", id = 700, ti = "Copy", at = now + 3600, k = "s", ev = now,
    rs = { ["Bingo Heeler"] = "y||" .. (now + 3600) .. "|" .. now } }), "WHISPER", calPeer)
INJECT("YNM", Msg({ v = 1, t = "EVT", o = "Bingo Heeler", id = 701, ti = "Sneaky", at = now, k = "s", ev = now }), "WHISPER", "Chilli Heeler")
Tick(1)
check(store["Chilli Heeler:700"] and not store["Chilli Heeler:700"].direct, "a copy of Chilli's event, from the guildie we asked")
check(#C.Answers(store["Chilli Heeler:700"], now + 3600).y == 1, "with its answers")
check(store["Bingo Heeler:701"] == nil, "a copy nobody asked for is dropped")
INJECT("YNM", Msg({ v = 1, t = "EVT", id = 700, ti = "Copy (real)", at = now + 3600, k = "s", ev = now }), "GUILD", "Chilli Heeler")
Tick(1)
check(store["Chilli Heeler:700"].direct and store["Chilli Heeler:700"].title == "Copy (real)", "the owner's own message beats the copy")

-- Reminder 15 minutes before an event I'm going to (and its own setting).
ns.Toast.Show("x", "y")
local soon = C.Save(nil, { title = "Soon", at = GetServerTime() + 14 * 60 + 20, k = "s" })
local reminded = 0
ns.Listen("REMIND", function() reminded = reminded + 1 end)
Tick(40)
check(reminded == 1, "reminded once for my own event starting in 15 minutes")
ns.settings.remind = false
C.Save(nil, { title = "Soon 2", at = GetServerTime() + 14 * 60, k = "s" })
Tick(40)
check(reminded == 1, "no reminder with the setting off")
ns.settings.remind = true

-- Cancel: only mine; the guild hears it; it leaves the day.
before = #SENT
C.Cancel(bkey)
C.Cancel(key)
evt = Sent("EVT", before + 1)
check(#evt == 1 and evt[1].x == true and store[key].x and not store[bkey].x, "cancelled mine (not Bluey's)")
onDay = C.OnDay(t.year, t.month, t.day)
for _, item in ipairs(onDay) do if item.key == key then check(false, "cancelled event still shows") end end

-- Home's next up lists the coming events.
local up = C.Upcoming(4)
check(#up >= 2 and up[1].at <= up[2].at, "upcoming events in time order (" .. #up .. ")")

-- Old events are forgotten after a week (weekly ones stay).
Tick(9 * 86400, 600)
local left = 0
for k2, e2 in pairs(store) do left = left + 1 end
check(store[wkey] ~= nil and store[bkey] == nil, "a week later: the one-off events are gone, the weekly one stays (" .. left .. " left)")

-- Sim mode: fake events with answers; my new event gets fake answers; sim off removes the fakes'.
SlashCmdList.YEAHNAHMATE("dev sim on")
Tick(15)
local fakeEvents = 0
for _, e2 in pairs(store) do if ns.Sim.IsFake(e2.owner) and not e2.x then fakeEvents = fakeEvents + 1 end end
check(fakeEvents == 3, "three fake events (" .. fakeEvents .. ")")
local mineKey = C.Save(nil, { title = "My run", at = GetServerTime() + 7200, k = "d", nt = 1, nh = 1, nd = 3 })
Tick(12)
local mineAns = C.Answers(store[mineKey], store[mineKey].at)
check(#mineAns.y == 2 and mineAns.roles.h == 1 and mineAns.roles.t == 1, "two fake guildies said they're going (healer, tank)")

-- Several events on one day: the "1-2 of 3" pager shows, and its arrows move through them.
local day = GetServerTime() + 3 * 86400
local dt = date("*t", day)
for i = 1, 3 do C.Save(nil, { title = "Busy " .. i, at = time({ year = dt.year, month = dt.month, day = dt.day, hour = 10 + i }), k = "s" }) end
ns.UI.Open("calendar")
local cal
for _, o in ipairs(CREATED) do if o.dayPager then cal = o end end
cal.offset, cal.sel, cal.mode = 0, dt.day, nil
if dt.month ~= date("*t").month then cal.offset = 1 end
ns.UI.Select("calendar")
Tick(1)
check(cal.dayPager.text:IsShown() and cal.dayPager.text:GetText() == "1-2 of 3", "pager shows 1-2 of 3 (" .. tostring(cal.dayPager.text:GetText()) .. ")")
cal.dayPager.down:Click()
Tick(1)
check(cal.dayPager.text:GetText() == "2-3 of 3", "down arrow shows the rest")

-- Click everything on the tab (new event form, steppers, kinds, answers, month arrows).
ns.UI.Open("calendar")
for pass = 1, 3 do
    local n = #CREATED
    for i = 1, n do
        local o = CREATED[i]
        if o._template == "UIPanelCloseButton" then o = { _scripts = {} } end
        if not IsInside(o, "YeahNahMateWhisper") and o._name ~= "YeahNahMateWelcome" then
            for _, s in ipairs({ "OnClick", "OnMouseUp", "OnEnter", "OnLeave" }) do
                if o._scripts[s] then o._scripts[s](o, "LeftButton") end
            end
            if o._scripts.OnMouseWheel then o._scripts.OnMouseWheel(o, -1) end
        end
    end
    Tick(1)
end
ns.UI.Open("home")
Tick(1)
SlashCmdList.YEAHNAHMATE("dev sim off")
Tick(1)
fakeEvents = 0
for _, e2 in pairs(store) do if ns.Sim.IsFake(e2.owner) or e2.owner == "Bazza Stubbs" then fakeEvents = fakeEvents + 1 end end
check(fakeEvents == 0 and #C.Answers(store[mineKey], store[mineKey].at).y == 0, "sim off: fake events and fake answers gone")

for _, m in ipairs(SENT) do
    if m.channel == "WHISPER" and ns.Sim.IsFake(m.target) then check(false, "whispered a fake guildie: " .. m.target) end
end
check(#UISpecialFrames == 0 and PanelManagerCalls == 0, "no taint tripwires touched")
check(#ERRORS == 0, "no errors (" .. (ERRORS[1] or "none") .. ")")

-- Raid roster: a "coming soon" panel for now; it opens and closes and sends nothing.
do
    ns.UI.Open("calendar")
    local cal
    for _, o in ipairs(CREATED) do if o.raidBox then cal = o end end
    Tick(4)             -- the click-everything sweep above also picked roles on the Clans tab (sent 3 s later)
    local before = #SENT
    cal.raidBtn:Click()
    Tick(1)
    check(cal.raidBox:IsShown() and not cal.newBtn:IsShown(), "Raid roster opens the coming-soon panel")
    cal.raidBtn:Click()
    Tick(1)
    check(not cal.raidBox:IsShown() and cal.newBtn:IsShown(), "clicking it again goes back to the day")
    check(#SENT == before, "Raid roster sends nothing")
end
