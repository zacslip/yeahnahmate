-- Copies vs the author: fixes from the code review of 0.8.7 (Nov 2026), one block per finding.
-- The theme: "a copy never replaces what the author told us" kept stale data for good. Now the
-- author's own message always wins, and otherwise the newer version wins (copies may run at most a
-- minute ahead of our clock).
math.randomseed(13)
YeahNahMateDB = nil
local ns = LoadAddon("YeahNahMate", "YeahNahMate")
LOGGED_IN = true
FireEvent("PLAYER_LOGIN")
local Ser = LibStub("AceSerializer-3.0")
local function Msg(t) return Ser:Serialize(t) end
local C, B, R, G = ns.Calendar, ns.Board, ns.Requests, ns.Gather
ns.settings.sharePosition, ns.settings.shareProfessions = false, false
INJECT("YNM", Msg({ v = 1, t = "HI", ver = "0.8.6" }), "GUILD", "Bluey Heeler")
Tick(15)
local now = GetServerTime()
local function LastReq(w)
    for i = #SENT, 1, -1 do
        local ok, m = Ser:Deserialize(SENT[i].text)
        if ok and type(m) == "table" and m.t == "REQ" and m.w == w then return SENT[i].target end
    end
end

-- The shared rule itself.
check(ns.Newer(100, true, 50, true) == false and ns.Newer(100, false, 50, true) == true, "author's own: newer wins; own beats a copy")
check(ns.Newer(100, true, 150, false) == true and ns.Newer(100, true, 100, false) == false, "a newer copy beats an older own; a tie doesn't")
check(ns.Newer(200, false, 100, true, true) == false, "shared slot: an older own message doesn't beat a newer copy")
check(not ns.Future(GetServerTime() + 5, true) and ns.Future(GetServerTime() + 120, true), "copies may run a few seconds ahead, not minutes")

-- Bluey is the only other addon user, so he's the guildie we ask for copies. Chilli (online, made an
-- officer here) is the author whose changes we missed. Bingo answers events.
for _, row in ipairs(FAKE.roster) do
    if row[1]:find("^Chilli") then row[3] = 1 end
end
ns.Guild.Scan()
local A = "Chilli Heeler"

-- Finding 2: events heard straight from Chilli, then Chilli cancels one and moves another while
-- we're away: copies from Bluey bring both changes.
INJECT("YNM", Msg({ v = 1, t = "EVT", id = 1, ti = "Old raid", at = now + 86400, k = "d", nt = 1, nh = 1, nd = 3, note = "", ev = now - 100 }), "GUILD", A)
INJECT("YNM", Msg({ v = 1, t = "EVT", id = 2, ti = "Moved meet", at = now + 3600, k = "s", nt = 0, nh = 0, nd = 0, note = "", ev = now - 100 }), "GUILD", A)
INJECT("YNM", Msg({ v = 1, t = "RQ", id = 5, it = "Silk Cloak", n = 1, u = now + 86400, ev = now - 100 }), "GUILD", A)
INJECT("YNM", Msg({ v = 1, t = "RSVP", o = A, id = 2, at = now + 3600, a = "y", rv = now - 100 }), "GUILD", "Bingo Heeler")
Tick(1)
check(C.Store()[A .. ":1"] and C.Store()[A .. ":1"].direct, "events heard straight from Chilli")
check(C.Store()[A .. ":2"].rs["Bingo Heeler"].a == "y", "Bingo said going")
Tick(30)                                     -- 40 s after login: ask a guildie for the calendar
local peer = LastReq("CAL")
check(peer == "Bluey Heeler", "asked Bluey for the calendar")
INJECT("YNM", Msg({ v = 1, t = "EVT", o = A, id = 1, ev = now - 10, x = true }), "WHISPER", peer)
INJECT("YNM", Msg({ v = 1, t = "EVT", o = A, id = 2, ti = "Moved meet", at = now + 5400, k = "s", nt = 0, nh = 0, nd = 0, note = "", ev = now - 10,
    rs = { ["Bingo Heeler"] = "n||" .. (now + 5400) .. "|" .. (now - 20) } }), "WHISPER", peer)
Tick(1)
check(C.Store()[A .. ":1"].x, "finding 2: Chilli's cancel reaches us by a copy")
local e2 = C.Store()[A .. ":2"]
check(e2.at == now + 5400, "finding 2: and the move")
check(e2.rs["Bingo Heeler"].a == "n" and e2.rs["Bingo Heeler"].relayed, "finding 3: Bingo's newer answer arrives relayed")
INJECT("YNM", Msg({ v = 1, t = "EVT", o = A, id = 2, ti = "Stale", at = now + 3600, k = "s", nt = 0, nh = 0, nd = 0, note = "", ev = now - 50 }), "WHISPER", peer)
Tick(1)
check(C.Store()[A .. ":2"].title == "Moved meet", "an older copy doesn't undo it")
INJECT("YNM", Msg({ v = 1, t = "EVT", id = 2, ti = "Moved meet", at = now + 5400, k = "s", nt = 0, nh = 0, nd = 0, note = "", ev = now - 10 }), "GUILD", A)
Tick(1)
check(C.Store()[A .. ":2"].direct, "Chilli's own message of the same version is kept as hers")

-- Finding 7: copies a few seconds ahead (quick edits) aren't refused.
INJECT("YNM", Msg({ v = 1, t = "EVT", o = A, id = 3, ti = "Quick", at = now + 9000, k = "s", nt = 0, nh = 0, nd = 0, note = "", ev = GetServerTime() + 3 }), "WHISPER", peer)
Tick(1)
check(C.Store()[A .. ":3"] ~= nil, "finding 7: a copy 3 s ahead is taken")

-- Finding 6: the poster's whisper at log-in carries who's on it (shown, marked relayed).
INJECT("YNM", Msg({ v = 1, t = "RQ", id = 6, it = "Wool Bandage", n = 1, u = now + 86400, ev = now - 5, cl = { "Bingo Heeler" } }), "WHISPER", A)
Tick(1)
local rq = R.Store()[A .. ":6"]
check(rq and rq.cl["Bingo Heeler"] and rq.clRelayed["Bingo Heeler"], "finding 6: who's on it is kept from the poster's message (relayed)")

-- Finding 2 (requests): Chilli finished her request while we were away; a copy brings it.
Tick(30)                                     -- 60 s after login: ask a guildie for the requests
local rpeer = LastReq("RQS")
check(rpeer == "Bluey Heeler", "asked Bluey for the requests")
INJECT("YNM", Msg({ v = 1, t = "RQ", o = A, id = 5, ev = now - 10, x = "done", it = "Silk Cloak" }), "WHISPER", rpeer)
Tick(1)
check(R.Store()[A .. ":5"].x == "done", "finding 2: a request done while we were away is done for us too")

-- Finding 1: the guild info is one slot several editors write. Bluey wrote an old version; Chilli
-- a newer one we get as a copy; Bluey's own older version, whispered at log-in, mustn't roll it back.
INJECT("YNM", Msg({ v = 1, t = "BRD", k = "info", motd = "Bluey's old", text = "", ev = now - 100 }), "GUILD", "Bluey Heeler")
Tick(1)
local bpeer = LastReq("BRD")
check(bpeer == "Bluey Heeler", "asked Bluey for the board")
INJECT("YNM", Msg({ v = 1, t = "BRD", o = A, k = "info", motd = "Chilli's new", text = "", ev = now - 10 }), "WHISPER", bpeer)
Tick(1)
check(B.Info().motd == "Chilli's new", "Chilli's newer info arrives as a copy")
INJECT("YNM", Msg({ v = 1, t = "BRD", k = "info", motd = "Bluey's old", text = "", ev = now - 100 }), "WHISPER", "Bluey Heeler")
Tick(1)
check(B.Info().motd == "Chilli's new", "finding 1: Bluey's older own version doesn't roll it back")

-- Finding 5: cancel markers don't push live events out of the 40 copies.
for i = 1, 45 do
    INJECT("YNM", Msg({ v = 1, t = "EVT", id = 100 + i, ti = "Gone " .. i, at = now + 3600, k = "s", nt = 0, nh = 0, nd = 0, note = "", ev = now - 60 }), "GUILD", A)
end
Tick(1)
for i = 1, 45 do INJECT("YNM", Msg({ v = 1, t = "EVT", id = 100 + i, ev = now - 1, x = true }), "GUILD", A) end
INJECT("YNM", Msg({ v = 1, t = "EVT", id = 999, ti = "Ancient weekly", at = now - 90 * 86400, k = "d", nt = 1, nh = 1, nd = 3, note = "", w = true, ev = now - 90 * 86400 }), "GUILD", A)
Tick(1)
local before = #SENT
INJECT("YNM", Msg({ v = 1, t = "REQ", w = "CAL" }), "WHISPER", "Bingo Heeler")
Tick(5)
local sentWeekly, live, cancels = false, 0, 0
for i = before + 1, #SENT do
    local ok, m = Ser:Deserialize(SENT[i].text)
    if ok and type(m) == "table" and m.t == "EVT" and SENT[i].target == "Bingo Heeler" then
        if m.id == 999 then sentWeekly = true end
        if m.x then cancels = cancels + 1 else live = live + 1 end
    end
end
check(sentWeekly, "finding 5: the old weekly event still goes in the copies (" .. live .. " live, " .. cancels .. " cancels)")
check(live + cancels <= 40, "still at most 40 copies")

-- Finding 4: a gathering stopped before its event arrived isn't started when the event comes.
local at = now + 1200
INJECT("YNM", Msg({ v = 1, t = "GTH", o = "Bluey Heeler", id = 50, at = at, on = true }), "WHISPER", "Bluey Heeler")
Tick(1)
INJECT("YNM", Msg({ v = 1, t = "GTH", o = "Bluey Heeler", id = 50, at = at, on = false }), "WHISPER", "Bluey Heeler")
Tick(1)
local started = 0
ns.Listen("GATHER_STARTED", function() started = started + 1 end)
INJECT("YNM", Msg({ v = 1, t = "EVT", id = 50, ti = "Meeting", at = at, k = "s", nt = 0, nh = 0, nd = 0, note = "", ev = now }), "WHISPER", "Bluey Heeler")
Tick(1)
check(G.ActiveFor("Bluey Heeler:50", at) == nil and started == 0, "finding 4: the stopped gathering doesn't start")

-- Finding 8: no public "run the handlers again" door in Comm.
check(ns.Comm.handlersFor == nil, "finding 8: Comm.handlersFor is gone")

check(#ERRORS == 0, "no errors (" .. (ERRORS[1] or "none") .. ")")
