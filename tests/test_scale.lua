-- Scale: what happens when the whole guild runs the addon. 600 members, all with Yeah Nah Mate,
-- 250 online at once (a busy evening). Counts what I send and receive in the moments that could
-- snowball: everyone's steady traffic, a guildie logging in (everyone online reacts), my recipe list
-- being asked for by everyone, and what my saved data and memory grow to with 600 crafters.
-- The send queue (ChatThrottleLib) runs on the test clock, so "drains in" is real queue time.
math.randomseed(600)
YeahNahMateDB = nil
local MEMBERS, ONLINE = 600, 250
local CLASSES = { "WARRIOR", "MAGE", "PRIEST", "ROGUE", "HUNTER", "SHAMAN", "WARLOCK", "DRUID" }
local ZONES = { "The Barrens", "Durotar", "Ashenvale", "Orgrimmar", "Stonetalon Mountains", "Hillsbrad Foothills" }
local MAPS = { 1413, 1411, 1440, 1454, 1442, 1424 }
local FIRST = { "Bluey", "Bingo", "Chilli", "Bandit", "Muffin", "Socks", "Rusty", "Calypso", "Lucky", "Indy" }
FAKE.roster = { { "Ned Jones", "Guild Master", 0, 22, "Shaman", "The Barrens", "", "", true, 0, "SHAMAN", 0, 0, false, false, 3, "Player-6797-0000ZAC1" } }
local names = {}
for i = 1, MEMBERS - 1 do
    local name = FIRST[i % 10 + 1] .. " Member" .. i
    names[i] = name
    FAKE.roster[#FAKE.roster + 1] = { name, i <= 5 and "Officer" or "Member", i <= 5 and 1 or 3,
        1 + (i * 7) % 60, "x", ZONES[i % 6 + 1], "", "", i < ONLINE, 0, CLASSES[i % 8 + 1] }
end
local memBefore = collectgarbage("count")
local ns = LoadAddon("YeahNahMate", "YeahNahMate")
LOGGED_IN = true
FireEvent("PLAYER_LOGIN")
ns.settings.sharePosition, ns.settings.shareProfessions = true, true
FAKE.spells = FAKE.spells or {}
Tick(2)
local Ser = LibStub("AceSerializer-3.0")
local function Msg(t) return Ser:Serialize(t) end
local now = GetServerTime()
local lines = {}
local function Note(s) lines[#lines + 1] = s end

-- What I sent since `from`: messages (after splitting into 255-byte pieces) and bytes, by channel.
local function Sent(from)
    local r = { guild = 0, guildBytes = 0, whisper = 0, whisperBytes = 0 }
    for i = from + 1, #SENT do
        local s = SENT[i]
        if s.channel == "GUILD" then r.guild = r.guild + 1; r.guildBytes = r.guildBytes + #s.text
        else r.whisper = r.whisper + 1; r.whisperBytes = r.whisperBytes + #s.text end
    end
    return r
end
-- Run the clock until the send queue is empty; returns the seconds it took.
local function Drain(limit)
    local t0, last = NOW, #SENT
    local quiet = 0
    while NOW - t0 < (limit or 900) do
        Tick(1)
        if #SENT == last then quiet = quiet + 1 else quiet = 0; last = #SENT end
        if quiet >= 10 then break end
    end
    return NOW - t0 - quiet
end

-- Everyone online says hello, with a recipe list (2 professions, 150 recipes each).
-- Like a real guild: everyone's recipes come from the same few hundred per profession (2 of 6
-- professions each, 150 of 400 recipes known).
local PROFS = { 197, 164, 165, 171, 202, 333 }
local function List(i)
    local p = {}
    for k = 0, 1 do
        local prof = PROFS[(i + k * 3) % 6 + 1]
        local ids, start = {}, (i * 37) % 250
        for j = 1, 150 do ids[j] = prof * 1000 + start + j end
        p[prof] = { r = 150, m = 225, i = ids }
    end
    return p
end
local t0 = os.clock()
for i = 1, ONLINE - 1 do
    INJECT("YNM", Msg({ v = 1, t = "HI", ver = ns.VERSION, l = 20 + i % 40, z = ZONES[i % 6 + 1], st = "g", n = 1 }), "GUILD", names[i])
    INJECT("YNM", Msg({ v = 1, t = "POS", m = MAPS[i % 6 + 1], x = (i % 97) / 100 + 0.01, y = 0.5 }), "GUILD", names[i])
    INJECT("YNM", Msg({ v = 1, t = "PROF", pv = now - i, p = List(i) }), "GUILD", names[i])
end
Deliver()
local recvMs = (os.clock() - t0) * 1000
check(ns.Comm.OthersOnline() == ONLINE - 1, (ONLINE - 1) .. " others online with the addon")
Note(string.format("%d hellos + positions + recipe lists received in %.0f ms", (ONLINE - 1) * 3, recvMs))
check(recvMs < 2000, "receiving everyone at once stays under 2 s of work")
Drain(120)

-- 1. Steady traffic: my positions while moving. Everyone sends about as often as I do, so what I
-- receive per minute is roughly mine x 249.
local before = #SENT
for i = 1, 300 do FAKE.x = 0.3 + i * 0.001; Tick(1) end
local pos = 0
for i = before + 1, #SENT do
    local ok, m = Ser:Deserialize(SENT[i].text)
    if ok and type(m) == "table" and m.t == "POS" then pos = pos + 1 end
end
local perMin = pos / 5
Note(string.format("steady: I send %.1f positions/min while moving (every %d s); I receive ~%d/min from %d others",
    perMin, ns.Map.Interval(), math.floor(perMin * (ONLINE - 1)), ONLINE - 1))
check(perMin <= 1.2, "positions slow to once a minute with 249 others")
t0 = os.clock()
for i = 1, ONLINE - 1 do
    INJECT("YNM", Msg({ v = 1, t = "POS", m = MAPS[i % 6 + 1], x = (i % 89) / 100 + 0.02, y = 0.4 }), "GUILD", names[i])
end
Deliver()
local minuteMs = (os.clock() - t0) * 1000
Note(string.format("a minute of everyone's positions handled in %.1f ms", minuteMs))
check(minuteMs < 200, "a minute of positions costs under 200 ms")

-- 2. A guildie logs in. Everyone online reacts to their hello, so whatever I do here happens 249
-- times. Broadcasts are the danger: 249 of them reach 250 people each.
-- Counts the first 12 s after their hello (everything I do for a newcomer goes out within ~9 s;
-- the old position broadcast went out on the next 5 s tick). My own once-a-minute position is
-- routine, not caused by them, so it isn't counted.
local function OneLogin(who)
    Tick(30)
    before = #SENT
    INJECT("YNM", Msg({ v = 1, t = "HI", ver = ns.VERSION, ask = true, l = 30, z = "Durotar", st = "g", n = 1 }), "GUILD", who)
    Deliver()
    Tick(12)
    return Sent(before)
end
-- Give me what a typical guildie has to share: an event I made, an open request, a group.
ns.Calendar.Save(nil, { title = "Raid night", at = now + 86400, k = "s" })
Drain(60)
local r = OneLogin(names[ONLINE + 10])
Note(string.format("a guildie logs in: I send %d to the guild (%d bytes) and %d whispers (%d bytes)",
    r.guild, r.guildBytes, r.whisper, r.whisperBytes))
Note(string.format("  -> guild-wide: %d broadcasts (each reaches %d), the newcomer gets ~%d whispers",
    r.guild * (ONLINE - 1), ONLINE, r.whisper * (ONLINE - 1)))
check(r.guild == 0, "a guildie logging in makes no guild broadcasts from me (" .. r.guild .. ")")
check(r.whisperBytes < 1000, "and only a little whispered to them (" .. r.whisperBytes .. " bytes)")

-- An evening rush: 30 guildies log in over 10 minutes.
before = #SENT
for i = 1, 30 do
    INJECT("YNM", Msg({ v = 1, t = "HI", ver = ns.VERSION, ask = true, l = 30, z = "Durotar", st = "g", n = 1 }), "GUILD", names[ONLINE + 20 + i])
    Deliver()
    Tick(20)
end
Drain(120)
r = Sent(before)
Note(string.format("30 log-ins over 10 min: I send %d guild + %d whispers (%d bytes total)",
    r.guild, r.whisper, r.guildBytes + r.whisperBytes))

-- 3. My recipe list changed while most of the guild was offline. When I log back in, everyone
-- online has an old copy and asks me for it.
local mine = ns.Prof.MyData()
mine.profs = List(0)
mine.pv = GetServerTime()
before = #SENT
for i = 1, ONLINE - 1 do
    INJECT("YNM", Msg({ v = 1, t = "REQ", w = "PROF" }), "WHISPER", names[i])
    if i % 25 == 0 then Deliver(); Tick(0.5) end
end
Deliver()
local took = Drain(1200)
r = Sent(before)
Note(string.format("249 guildies ask for my changed recipe list: I send %d guild + %d whispers, %d KB, queue drains in %d s",
    r.guild, r.whisper, math.floor((r.guildBytes + r.whisperBytes) / 1024), took))
check(r.guildBytes + r.whisperBytes < 20000, "my list goes out about once, not 249 times (" .. (r.guildBytes + r.whisperBytes) .. " bytes)")
check(took < 60, "and my send queue is clear within a minute (" .. took .. " s)")
-- Someone who logs in just after that missed it, so they still get it (by whisper).
local late = names[ONLINE + 5]
FAKE.roster[ONLINE + 6][9] = true
ns.Guild.Scan()
INJECT("YNM", Msg({ v = 1, t = "HI", ver = ns.VERSION }), "WHISPER", late)
INJECT("YNM", Msg({ v = 1, t = "REQ", w = "PROF" }), "WHISPER", late)
before = #SENT
Deliver()
Drain(60)
r = Sent(before)
check(r.whisper > 0 and r.guild == 0, "a guildie who logged in after the guild copy still gets my list, by whisper")
INJECT("YNM", Msg({ v = 1, t = "REQ", w = "PROF" }), "WHISPER", names[3])
before = #SENT
Deliver()
Drain(30)
check(#SENT == before, "one who was online for the guild copy isn't sent it again")

-- 3b. I changed my event while the guild was offline; when I log in, everyone online is behind and
-- asks me for it (Sync.lua). One guild copy, not 249 whispers.
ns.Calendar.Save(nil, { title = "Changed while you were away", at = now + 2 * 86400, k = "s" })
Drain(60)
before = #SENT
for i = 1, ONLINE - 1 do
    INJECT("YNM", Msg({ v = 1, t = "REQ", w = "SYNC", k = { "events" } }), "WHISPER", names[i])
    if i % 25 == 0 then Deliver(); Tick(0.5) end
end
Deliver()
took = Drain(300)
r = Sent(before)
Note(string.format("249 guildies behind on my events: I send %d guild + %d whispers (%d bytes), drains in %d s",
    r.guild, r.whisper, r.guildBytes + r.whisperBytes, took))
check(r.whisper == 0 and r.guild > 0 and r.guild < 20, "catching everyone up is one guild copy (" .. r.guild .. " pieces)")

-- 4. Saved data and memory with 600 crafters known (offline ones arrive as copies over time).
for i = ONLINE, MEMBERS - 1 do
    INJECT("YNM", Msg({ v = 1, t = "PROF", pv = now - i, p = List(i) }), "GUILD", names[i])
end
Deliver()
collectgarbage("collect")
local memKB = collectgarbage("count") - memBefore
-- Rough size of the saved file (the game writes it much like this).
local size = 0
local function Walk(v, depth)
    local tv = type(v)
    if tv == "table" then
        size = size + 4 + depth
        for k, x in pairs(v) do
            size = size + (type(k) == "string" and #k + 6 or 8)
            Walk(x, depth + 1)
        end
    elseif tv == "string" then size = size + #v + 4
    else size = size + 8 end
end
Walk(YeahNahMateDB, 0)
Note(string.format("600 crafters known: saved file ~%d KB, Lua memory ~%d KB (whole test)", math.floor(size / 1024), math.floor(memKB)))
check(size < 4 * 1024 * 1024, "saved file stays under 4 MB")

-- Every tab still draws quickly with 600 members, 250 online and 600 crafters.
-- The recipe index is rebuilt once after a list changes, not on every redraw: timed on its own
-- (it used to be inside the professions average, which sat right at the limit and failed now and then).
ns.UI.Open("home")
ns.Prof.MarkDirty()
t0 = os.clock()
ns.Prof.Search(nil, "")
local rebuildMs = (os.clock() - t0) * 1000
Note(string.format("rebuild recipe index  %6.1f ms (once per change)", rebuildMs))
check(rebuildMs < 600, "recipe index rebuilds in under 600 ms (" .. string.format("%.1f", rebuildMs) .. ")")
-- 0.9.11: one guildie's new list only changes their entries, not the whole index.
INJECT("YNM", Msg({ v = 1, t = "PROF", pv = GetServerTime() + 1, p = List(7777) }), "GUILD", names[1])
Deliver()
t0 = os.clock()
ns.Prof.Search(nil, "")
local oneMs = (os.clock() - t0) * 1000
Note(string.format("one changed list      %6.1f ms (was a full rebuild)", oneMs))
check(oneMs < 20, "one changed list updates the index in under 20 ms (" .. string.format("%.1f", oneMs) .. ")")
for _, tab in ipairs({ "home", "roster", "dungeons", "calendar", "professions", "settings" }) do
    t0 = os.clock()
    for _ = 1, 3 do ns.UI.Select(tab) end
    local ms = (os.clock() - t0) * 1000 / 3
    Note(string.format("redraw %-12s %6.1f ms", tab, ms))
    check(ms < 33, "redraw " .. tab .. " under 33 ms (" .. string.format("%.1f", ms) .. ")")
end
t0 = os.clock()
ns.Prof.Search(nil, "12")
Note(string.format("recipe search over 600 crafters: %.1f ms", (os.clock() - t0) * 1000))

for _, line in ipairs(lines) do io.write("    " .. line .. "\n") end
io.flush()
check(#ERRORS == 0, "no errors (" .. (ERRORS[1] or "none") .. ")")
