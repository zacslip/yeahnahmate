-- Fixes from the code review of 0.8.x (Nov 2026), one block per bug: cancelled weekly events, bursts of
-- copies, early gatherings, relayed answers, moved events, pop-up weeks, going live.
math.randomseed(12)
YeahNahMateDB = nil
local ns = LoadAddon("YeahNahMate", "YeahNahMate")
LOGGED_IN = true
FireEvent("PLAYER_LOGIN")
local Ser = LibStub("AceSerializer-3.0")
local function Msg(t) return Ser:Serialize(t) end
local C, B, R, G = ns.Calendar, ns.Board, ns.Requests, ns.Gather
ns.settings.sharePosition, ns.settings.shareProfessions = false, false
INJECT("YNM", Msg({ v = 1, t = "HI", ver = "0.8.3" }), "GUILD", "Bluey Heeler")
Tick(15)
local now = GetServerTime()

-- 1. A cancelled weekly event that started long ago stays cancelled (the cancel isn't forgotten
--    within minutes), and a copy of the live event can't bring it back.
INJECT("YNM", Msg({ v = 1, t = "EVT", id = 10, ti = "Weekly raid", at = now - 30 * 86400, k = "d", nt = 1, nh = 1, nd = 3, note = "", w = true, ev = now - 30 * 86400 }), "GUILD", "Bluey Heeler")
Tick(1)
INJECT("YNM", Msg({ v = 1, t = "EVT", id = 10, ev = now, x = true }), "GUILD", "Bluey Heeler")
Tick(1)
Tick(700)                                   -- the calendar tidies every 10 minutes
local wk = C.Store()["Bluey Heeler:10"]
check(wk and wk.x, "the cancelled weekly event is still remembered as cancelled")

-- 2. A burst of copies (100 messages from one guildie in a minute) isn't cut off.
local before = 0
for _, l in ipairs(ns.GetLog()) do if l:find("too many messages", 1, true) then before = before + 1 end end
for i = 1, 100 do
    INJECT("YNM", Msg({ v = 1, t = "RQ", id = 900 + i, it = "Thing " .. i, n = 1, u = now + 86400, ev = now }), "GUILD", "Chilli Heeler")
end
Tick(1)
local after = 0
for _, l in ipairs(ns.GetLog()) do if l:find("too many messages", 1, true) then after = after + 1 end end
check(after == before, "100 messages from one guildie in a minute aren't dropped")

-- 3. A gathering heard before its event arrives is held, and taken when the event comes.
local at = now + 1200
INJECT("YNM", Msg({ v = 1, t = "GTH", o = "Bluey Heeler", id = 20, at = at, on = true }), "WHISPER", "Bluey Heeler")
Tick(1)
check(G.ActiveFor("Bluey Heeler:20", at) == nil, "no event yet: the gathering waits")
INJECT("YNM", Msg({ v = 1, t = "EVT", id = 20, ti = "Meeting", at = at, k = "s", nt = 0, nh = 0, nd = 0, note = "", ev = now }), "WHISPER", "Bluey Heeler")
Tick(1)
check(G.ActiveFor("Bluey Heeler:20", at) ~= nil, "the event arrived: the gathering shows")

-- 4. Speaking for others (changed in 0.8.7, third review: the old rule left stale data). A poster's
--    own request may carry who's on it, but those names are marked relayed and never counted in
--    records. A relayed answer only replaces a guildie's own when it's newer (they changed it while
--    we weren't around), never from the future, and their own next answer wins again.
INJECT("YNM", Msg({ v = 1, t = "RQ", id = 30, it = "Silk Cloak", n = 1, u = now + 86400, ev = now, cl = { "Bingo Heeler" } }), "GUILD", "Bandit Heeler")
Tick(1)
local rq = R.Store()["Bandit Heeler:30"]
check(rq.cl["Bingo Heeler"] and rq.clRelayed and rq.clRelayed["Bingo Heeler"], "a request's own claims list shows, marked relayed")
INJECT("YNM", Msg({ v = 1, t = "RSVP", o = "Bluey Heeler", id = 20, at = at, a = "n", rv = now }), "GUILD", "Bingo Heeler")
Tick(1)
INJECT("YNM", Msg({ v = 1, t = "EVT", id = 20, ti = "Meeting", at = at, k = "s", nt = 0, nh = 0, nd = 0, note = "", ev = now + 1,
    rs = { ["Bingo Heeler"] = "y||" .. at .. "|" .. now } }), "GUILD", "Bluey Heeler")
Tick(1)
local bingo = C.Store()["Bluey Heeler:20"].rs["Bingo Heeler"]
check(bingo.a == "n" and not bingo.relayed, "a relayed answer of the same version doesn't replace Bingo's own")
INJECT("YNM", Msg({ v = 1, t = "EVT", id = 20, ti = "Meeting", at = at, k = "s", nt = 0, nh = 0, nd = 0, note = "", ev = now + 2,
    rs = { ["Bingo Heeler"] = "y||" .. at .. "|" .. (now + 3600) } }), "GUILD", "Bluey Heeler")
Tick(1)
bingo = C.Store()["Bluey Heeler:20"].rs["Bingo Heeler"]
check(bingo.a == "n", "a relayed answer from the future is refused")
INJECT("YNM", Msg({ v = 1, t = "EVT", id = 20, ti = "Meeting", at = at, k = "s", nt = 0, nh = 0, nd = 0, note = "", ev = now + 3,
    rs = { ["Bingo Heeler"] = "y||" .. at .. "|" .. (now + 2) } }), "GUILD", "Bluey Heeler")
Tick(1)
bingo = C.Store()["Bluey Heeler:20"].rs["Bingo Heeler"]
check(bingo.a == "y" and bingo.relayed, "a newer relayed answer (Bingo changed it) comes through")
INJECT("YNM", Msg({ v = 1, t = "RSVP", o = "Bluey Heeler", id = 20, at = at, a = "n", rv = now + 1 }), "GUILD", "Bingo Heeler")
Tick(1)
bingo = C.Store()["Bluey Heeler:20"].rs["Bingo Heeler"]
check(bingo.a == "n" and not bingo.relayed, "Bingo's own answer wins again")

-- 5. A copy (which names its author itself) can't overrule the author, or come from the future.
INJECT("YNM", Msg({ v = 1, t = "BRD", k = "info", motd = "Real", text = "", ev = now }), "GUILD", "Bluey Heeler")
Tick(1)
Tick(40)                                    -- 50 s after login we ask one guildie for the board
local peer
for i = #SENT, 1, -1 do
    local ok, m = Ser:Deserialize(SENT[i].text)
    if ok and type(m) == "table" and m.t == "REQ" and m.w == "BRD" then peer = SENT[i].target break end
end
check(peer ~= nil, "asked one guildie for the board")
INJECT("YNM", Msg({ v = 1, t = "BRD", o = "Bluey Heeler", k = "info", motd = "Forged", text = "", ev = now }), "WHISPER", peer)
INJECT("YNM", Msg({ v = 1, t = "BRD", o = "Ned Jones", k = "rank", er = 9, ev = GetServerTime() + 550 }), "WHISPER", peer)
Tick(1)
check(B.Info().motd == "Real", "a copy of the same version doesn't replace what Bluey told us")
check(B.EditRank() == 1, "a future-dated copy is refused")

-- 6. Moving an event keeps its answers.
local key = C.Save(nil, { title = "Deadmines", at = now + 7200, k = "d", nt = 1, nh = 1, nd = 3 })
local e = C.Store()[key]
INJECT("YNM", Msg({ v = 1, t = "RSVP", o = "Ned Jones", id = e.id, at = e.at, a = "y", r = "t", rv = now }), "GUILD", "Bluey Heeler")
Tick(1)
C.Save(key, { title = "Deadmines", at = now + 7200 + 900, k = "d", nt = 1, nh = 1, nd = 3 })
local ans = C.Answers(e, e.at)
check(#ans.y == 1 and ans.y[1] == "Bluey Heeler" and ans.roles.t == 1, "moved 15 minutes later: Bluey's still going as tank")

-- 7. Working out "can I make it" is done once per request, not on every comparison (speed).
for i = 1, 60 do
    INJECT("YNM", Msg({ v = 1, t = "RQ", id = 2000 + i, it = "Item " .. i, n = 1, u = now + 86400, ev = now }), "GUILD", "Bingo Heeler")
end
Tick(1)
local t0 = os.clock()
for _ = 1, 5 do R.List() end
check((os.clock() - t0) * 1000 / 5 < 20, string.format("listing %d requests: %.1f ms", #R.List(), (os.clock() - t0) * 1000 / 5))

-- 8. The "X is going" pop-up names the week they answered, not the first week.
local seen
ns.Listen("ANSWERED", function(_, _, _, when) seen = when end)
local wkey = C.Save(nil, { title = "Levelling night", at = now - 14 * 86400, k = "s", w = true })
local we = C.Store()[wkey]
local nextAt = C.NextAt(we, GetServerTime())
INJECT("YNM", Msg({ v = 1, t = "RSVP", o = "Ned Jones", id = we.id, at = nextAt, a = "y", rv = GetServerTime() }), "GUILD", "Bluey Heeler")
Tick(1)
check(seen == nextAt, "the pop-up is for the week answered")

-- 10. "Go live" after the 6 hours ran out turns live back on (not off).
B.SetStreamer("ned_jones", "", "")
B.SetLive(true)
B.Mine().liveAt = GetServerTime() - 6 * 3600 - 10
ns.UI.Open("streamers")
local page
for _, o in ipairs(CREATED) do if o.mine and o.mine.liveBtn then page = o end end
page.mine.liveBtn:Click()
check(B.Mine().live and GetServerTime() - B.Mine().liveAt < 60, "clicking 'I'm live now' after 6 hours goes live again")

check(#ERRORS == 0, "no errors (" .. (ERRORS[1] or "none") .. ")")
