-- Event kinds (social, dungeon; raid waits for the raid roster) and important events: only Calendar
-- moderators set them, every guildie gets their pop-ups whatever the settings, each ticked time once,
-- a late login only gets the nearest one, "tell everyone now" once, fights hold them back, and older
-- versions' copies (without the fields) don't wipe them. Bluey is an Officer (moderates the calendar
-- by default), Chilli a Member; I'm a Member until the test makes me the guild master.
math.randomseed(41)
YeahNahMateDB = nil
local ns = LoadAddon("YeahNahMate", "YeahNahMate")
LOGGED_IN = true
FireEvent("PLAYER_LOGIN")
local Ser = LibStub("AceSerializer-3.0")
local function Msg(t) return Ser:Serialize(t) end
local function Sent(t, from)
    local list = {}
    for i = (from or 1), #SENT do
        local ok, m = Ser:Deserialize(SENT[i].text)
        if ok and type(m) == "table" and m.t == t then list[#list + 1] = m end
    end
    return list
end
local C = ns.Calendar
ns.settings.sharePosition, ns.settings.shareProfessions = false, false
INJECT("YNM", Msg({ v = 1, t = "HI", ver = "0.17.2" }), "GUILD", "Bingo Heeler")
Tick(45)                                        -- 40 s after login we ask Bingo for the calendar
local now = GetServerTime()
local store = C.Store()

-- An older version's copy (no im / an) doesn't wipe them, even a newer one.
INJECT("YNM", Msg({ v = 1, t = "EVT", id = 12, ti = "Copy meet", at = now + 86400, k = "s", im = 1, ev = now }), "GUILD", "Bluey Heeler")
Tick(1)
local ck12 = "Bluey Heeler:12"
INJECT("YNM", Msg({ v = 1, t = "EVT", o = "Bluey Heeler", id = 12, ti = "Copy meet!", at = now + 86400, k = "s", ev = now + 5 }), "WHISPER", "Bingo Heeler")
Tick(1)
check(store[ck12] and store[ck12].title == "Copy meet!" and store[ck12].im == 1, "an older version's newer copy keeps the important ticks")

-- Pop-ups seen: hook the two important events and the toast itself.
local fired = {}
ns.Listen("IMPORTANT", function(e, at, mins) fired[#fired + 1] = { "soon", e.title, mins } end)
ns.Listen("IMPORTANT_NEW", function(e) fired[#fired + 1] = { "new", e.title } end)
local function Count(kind, title)
    local n = 0
    for _, f in ipairs(fired) do if f[1] == kind and f[2] == title then n = n + 1 end end
    return n
end

-- Kinds: social and dungeon can be made; raid, levelling and other can't (yet / any more).
check(C.Save(nil, { title = "x", at = now + 7200, k = "r" }) == nil, "a raid event can't be made yet")
check(C.Save(nil, { title = "x", at = now + 7200, k = "l" }) == nil, "levelling can't be made any more")
local _, why = C.Save(nil, { title = "", at = now + 7200, k = "s" })
check(why == "title", "no title: says so")
_, why = C.Save(nil, { title = "x", at = now + 7200, k = "o" })
check(why == "kind", "an unknown kind: says so")
INJECT("YNM", Msg({ v = 1, t = "EVT", id = 1, ti = "Old levelling", at = now + 86400, k = "l", ev = now }), "GUILD", "Chilli Heeler")
INJECT("YNM", Msg({ v = 1, t = "EVT", id = 2, ti = "Old other", at = now + 86400, k = "o", ev = now }), "GUILD", "Chilli Heeler")
Tick(1)
check(store["Chilli Heeler:1"] and store["Chilli Heeler:2"], "older versions' levelling and other events still arrive")
check(C.ShownKind("l") == "s" and C.ShownKind("o") == "s" and C.ShownKind("d") == "d", "they show as social")

-- Notes: up to 150 (three lines); a new event doesn't notify me of answers unless I tick it.
local nk = C.Save(nil, { title = "Long note", at = now + 7200, k = "s", note = string.rep("n", 200), mute = true })
check(nk and #store[nk].note == 150 and store[nk].mute, "a note keeps 150 letters; 'tell me who's going' off = muted")

-- A Member can't make an important event: the ticks are ignored, nothing important is sent.
check(not C.CanRemove(), "I'm a Member: no Calendar moderator")
local before = #SENT
local mk = C.Save(nil, { title = "Not important", at = now + 7200, k = "s", im = 7, an = true })
check(mk and store[mk].im == 0 and not store[mk].an, "a Member's important ticks are ignored")
local evt = Sent("EVT", before + 1)
check(#evt == 1 and evt[1].im == 0 and evt[1].an == false, "the message says not important (0 / false)")

-- Chilli (a Member) sends an important flag anyway: nobody honours it.
INJECT("YNM", Msg({ v = 1, t = "EVT", id = 3, ti = "Fake alarm", at = now + 600, k = "s", im = 7, an = true, ev = now }), "GUILD", "Chilli Heeler")
Tick(31)
check(not C.IsImportant(store["Chilli Heeler:3"]), "a Member's important flag doesn't count")
check(Count("soon", "Fake alarm") == 0 and Count("new", "Fake alarm") == 0, "and no pop-ups for it")

-- Bluey (an Officer) makes an important event in 2 hours: remind at 60 and 15, and tell everyone.
fired = {}
ns.settings.remind = false
ns.settings.pop.answer = false
INJECT("YNM", Msg({ v = 1, t = "EVT", id = 10, ti = "Guild meeting", at = now + 7200, k = "s", im = 5, an = true, ev = now }), "GUILD", "Bluey Heeler")
Tick(31)
local bk = "Bluey Heeler:10"
check(C.IsImportant(store[bk]), "an Officer's important event counts")
check(Count("new", "Guild meeting") == 1, "tell everyone: a pop-up now (reminders switched off doesn't matter)")
check(ns.Toast.IsShown(), "the pop-up shows")
Tick(60)
check(Count("new", "Guild meeting") == 1, "only once")
check(Count("soon", "Guild meeting") == 0, "no reminder 2 hours before")

-- 60 minutes before: one reminder. Not at 30 (not ticked). At 15: one more. Each once.
Tick(3600 - 60)
check(Count("soon", "Guild meeting") == 1, "60 minutes before: reminded")
Tick(1800)
check(Count("soon", "Guild meeting") == 1, "30 isn't ticked: nothing")
Tick(900)
check(Count("soon", "Guild meeting") == 2, "15 minutes before: reminded again")
Tick(600)
check(Count("soon", "Guild meeting") == 2, "each time only once")

-- Logging in late (the event arrives 20 minutes before, all three ticked): only the 30, never a late 60.
fired = {}
now = GetServerTime()
INJECT("YNM", Msg({ v = 1, t = "EVT", id = 11, ti = "Late one", at = now + 20 * 60, k = "s", im = 7, ev = now }), "GUILD", "Bluey Heeler")
Tick(31)
check(Count("soon", "Late one") == 1 and fired[1][3] <= 20, "late: one reminder with the minutes left")
Tick(300)
check(Count("soon", "Late one") == 2, "then the 15 as usual")
Tick(600)
check(Count("soon", "Late one") == 2, "nothing more")

-- A weekly important event reminds every week.
now = GetServerTime()
INJECT("YNM", Msg({ v = 1, t = "EVT", id = 14, ti = "Weekly meet!", at = now + 86400, k = "s", w = true, im = 1, ev = now }), "GUILD", "Bluey Heeler")
fired = {}
Tick(86400 - 14 * 60)
check(Count("soon", "Weekly meet!") == 1, "first week: reminded")
Tick(7 * 86400)
check(Count("soon", "Weekly meet!") == 2, "next week: reminded again")

-- In a fight: it waits until the fight's over (and is dropped if the event has started).
fired = {}
now = GetServerTime()
ns.Toast.Show("x", "y")                       -- something on screen
FAKE.combat = true
INJECT("YNM", Msg({ v = 1, t = "EVT", id = 13, ti = "Fight time", at = now + 10 * 60, k = "s", im = 1, ev = now }), "GUILD", "Bluey Heeler")
Tick(31)
check(Count("soon", "Fight time") == 1, "the reminder fires")
check(not (ns.Toast.Title() or ""):find("Fight time", 1, true), "in a fight: the important pop-up waits")
Tick(5)
FAKE.combat = false
FireEvent("PLAYER_REGEN_ENABLED")
Tick(1)
check((ns.Toast.Title() or ""):find("Fight time", 1, true), "after the fight: the important pop-up shows")

-- While an important pop-up shows, a normal one waits instead of replacing it.
ns.settings.pop.group = true
ns.Toast.Show("Normal one", "text", "group")
check((ns.Toast.Title() or ""):find("Fight time", 1, true), "a normal pop-up doesn't replace an important one")
Tick(45)
check(ns.Toast.Title() == "Normal one", "the normal one shows after the important one goes")

-- An important pop-up held back by a fight is dropped if its event starts meanwhile.
now = GetServerTime()
FAKE.combat = true
INJECT("YNM", Msg({ v = 1, t = "EVT", id = 15, ti = "Missed it", at = now + 60, k = "s", im = 1, ev = now }), "GUILD", "Bluey Heeler")
Tick(31)
Tick(120)
FAKE.combat = false
FireEvent("PLAYER_REGEN_ENABLED")
Tick(1)
check(not (ns.Toast.Title() or ""):find("Missed it", 1, true), "it's dropped once the event has started")

-- Being the guild master: my form shows the important rows; my event goes out important.
FAKE.myRank, FAKE.myRankName = 0, "Guild Master"
FireEvent("GUILD_ROSTER_UPDATE")
Tick(3)
before = #SENT
local gk = C.Save(nil, { title = "Raid night chat", at = GetServerTime() + 86400, k = "s", im = 6, an = true })
evt = Sent("EVT", before + 1)
check(gk and store[gk].im == 6 and store[gk].an and #evt == 1 and evt[1].im == 6 and evt[1].an == true,
    "the guild master's important event goes out with its ticks")
check(store[gk].anSeen, "no 'tell everyone' pop-up for my own event")
ns.UI.Open("calendar")
Tick(1)

-- A moderator's edit of Chilli's event can make it important; Chilli's own later edit can't undo it.
INJECT("YNM", Msg({ v = 1, t = "EVT", id = 20, ti = "Old levelling", at = GetServerTime() + 86400, k = "l", ev = GetServerTime() }), "GUILD", "Chilli Heeler")
Tick(1)
local ck = "Chilli Heeler:20"
check(C.Save(ck, { title = "Old levelling", at = store[ck].at, k = "s", im = 1, an = false }) == ck, "I edit Chilli's event: important")
check(C.IsImportant(store[ck]), "it's important (I moderate)")
INJECT("YNM", Msg({ v = 1, t = "EVT", id = 20, ti = "Old levelling", at = store[ck].at, k = "s", im = 0, an = false, ev = GetServerTime() + 5 }), "GUILD", "Chilli Heeler")
Tick(1)
check(store[ck].im == 1, "Chilli (not a moderator) can't switch it off")

check(#ERRORS == 0, "no errors (" .. (ERRORS[1] or "none") .. ")")
