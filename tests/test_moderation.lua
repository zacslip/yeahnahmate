-- 13 Nov: managers get the guild master's access; each tab has its own moderator rank
-- (Calendar, Dungeons, Professions, Ask, Streamers, Info), that rank and above. Moderators edit or
-- remove other people's things on their tab. Fake roster: Ned (me), Bluey Officer (1), Bingo,
-- Chilli, Bandit Members (3).
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
        if ok and type(m) == "table" and m.t == t then
            m._target = SENT[i].target; m._channel = SENT[i].channel
            list[#list + 1] = m
        end
    end
    return list
end
local function Printed(s)
    for _, p in ipairs(PRINTED) do if p:find(s, 1, true) then return true end end
    return false
end
local B, C, R, D = ns.Board, ns.Calendar, ns.Requests, ns.Dungeons
ns.settings.sharePosition, ns.settings.shareProfessions = false, false
Tick(15)
local now = GetServerTime()
local TABS = { "cal", "dun", "prof", "ask", "strm", "info" }

---------------------------------------------------------------------------------------------------
-- Defaults: Officer and above moderate every tab.
local all = true
for _, t in ipairs(TABS) do
    if not B.CanModerate("Bluey Heeler", t) or B.CanModerate("Chilli Heeler", t) or B.CanModerate(ns.me, t) then all = false end
end
check(all, "by default the Officer moderates every tab; Members don't")

-- Chilli is the guild master for this test.
FAKE.roster[4][3] = 0
ns.Guild.Scan()
-- An officer can't set the tab ranks; the guild master can, one tab at a time.
INJECT("YNM", Msg({ v = 1, t = "BRD", k = "rank", er = 3, tm = { cal = 15, dun = 15, prof = 15, ask = 15, strm = 15, info = 15 }, ev = now }), "GUILD", "Bluey Heeler")
Tick(1)
check(not B.RankModerates("dun", 3), "an officer's tab ranks are dropped")
INJECT("YNM", Msg({ v = 1, t = "BRD", k = "rank", er = 1, tm = { cal = 3, dun = 9, prof = 3, ask = 3, strm = 3, info = 3 }, ev = now + 1 }), "GUILD", "Chilli Heeler")
Tick(1)
check(B.RankModerates("dun", 3) and not B.RankModerates("dun", 1) and B.RankModerates("cal", 1) and not B.RankModerates("cal", 3),
    "picked ranks: Dungeons = guild master + Members (not Officers), Calendar = Officers")
check(B.CanModerate("Bingo Heeler", "dun") and not B.CanModerate("Bingo Heeler", "cal") and not B.CanModerate("Bluey Heeler", "dun"),
    "so a Member moderates Dungeons, an Officer doesn't")
-- An older version's message (one rank for everything) sets every tab.
INJECT("YNM", Msg({ v = 1, t = "BRD", k = "rank", er = 0, ev = now + 2 }), "GUILD", "Chilli Heeler")
Tick(1)
check(not B.RankModerates("dun", 3) and not B.RankModerates("info", 1) and B.RankModerates("info", 0), "an older version's single rank sets every tab")
INJECT("YNM", Msg({ v = 1, t = "BRD", k = "rank", er = 1, tm = { cal = 3, dun = 3, prof = 3, ask = 3, strm = 3, info = 3 }, ev = now + 3 }), "GUILD", "Chilli Heeler")
Tick(1)

-- Managers have the guild master's access: Chilli names Bingo; Bingo names Bandit and sets a rank.
INJECT("YNM", Msg({ v = 1, t = "BRD", k = "mgr", mg = { "Bingo Heeler" }, ev = now + 4 }), "GUILD", "Chilli Heeler")
Tick(1)
check(B.IsManager("Bingo Heeler"), "Chilli (guild master) names Bingo")
local everyTab = true
for _, t in ipairs(TABS) do if not B.CanModerate("Bingo Heeler", t) then everyTab = false end end
check(everyTab, "a manager moderates every tab")
INJECT("YNM", Msg({ v = 1, t = "BRD", k = "mgr", mg = { "Bingo Heeler", "Bandit Heeler" }, ev = now + 5 }), "GUILD", "Bingo Heeler")
INJECT("YNM", Msg({ v = 1, t = "BRD", k = "rank", er = 1, tm = { cal = 3, dun = 3, prof = 3, ask = 9, strm = 3, info = 3 }, ev = now + 6 }), "GUILD", "Bingo Heeler")
Tick(1)
check(B.IsManager("Bandit Heeler") and B.RankModerates("ask", 3), "a manager can name managers and set tab ranks")
INJECT("YNM", Msg({ v = 1, t = "BRD", k = "mgr", mg = { "Bingo Heeler" }, ev = now + 7 }), "GUILD", "Bandit Heeler")
INJECT("YNM", Msg({ v = 1, t = "BRD", k = "rank", er = 1, tm = { cal = 3, dun = 3, prof = 3, ask = 3, strm = 3, info = 3 }, ev = now + 8 }), "GUILD", "Bluey Heeler")
Tick(1)
check(not B.IsManager("Bandit Heeler") and B.RankModerates("ask", 3), "a manager can remove a manager; an officer still can't set ranks")
check(B.IsManager("Chilli Heeler"), "the guild master always keeps their access")
INJECT("YNM", Msg({ v = 1, t = "BRD", k = "rank", er = 1, tm = { cal = 3, dun = 3, prof = 3, ask = 3, strm = 3, info = 3 }, ev = now + 9 }), "GUILD", "Chilli Heeler")
INJECT("YNM", Msg({ v = 1, t = "BRD", k = "mgr", mg = {}, ev = now + 10 }), "GUILD", "Chilli Heeler")
Tick(1)
FAKE.roster[4][3] = 3                   -- Chilli back to a Member for the rest
ns.Guild.Scan()

---------------------------------------------------------------------------------------------------
-- I'm a Member: moderators' changes reach me; Members' are dropped.
check(not C.CanRemove() and not R.CanRemove() and not D.CanRemove() and not ns.Questions.CanRemove() and not B.Moderates("strm"),
    "a Member moderates nothing")

-- Calendar: Bluey edits Bandit's event; Bandit's old copy doesn't undo it.
local cs = C.Store()
INJECT("YNM", Msg({ v = 1, t = "EVT", id = 700, ti = "Bandit's run", at = now + 86400, k = "s", ev = now - 100 }), "GUILD", "Bandit Heeler")
Tick(1)
INJECT("YNM", Msg({ v = 1, t = "EVM", o = "Bandit Heeler", id = 700, ti = "Bandit's run (fixed)", at = now + 90000, k = "s", nt = 0, nh = 0, nd = 0, note = "", ev = now }), "GUILD", "Bluey Heeler")
Tick(1)
local bk = "Bandit Heeler:700"
check(cs[bk].title == "Bandit's run (fixed)" and cs[bk].at == now + 90000 and cs[bk].md == "Bluey Heeler", "a Calendar moderator edits someone's event")
INJECT("YNM", Msg({ v = 1, t = "EVT", id = 700, ti = "Bandit's run", at = now + 86400, k = "s", ev = now - 100 }), "WHISPER", "Bandit Heeler")
Tick(1)
check(cs[bk].title == "Bandit's run (fixed)", "the owner's old copy doesn't undo a moderator's edit")
INJECT("YNM", Msg({ v = 1, t = "EVT", id = 700, ti = "Bandit's new plan", at = now + 86400, k = "s", ev = now + 20 }), "GUILD", "Bandit Heeler")
Tick(1)
check(cs[bk].title == "Bandit's new plan", "the owner's own later edit still wins")
INJECT("YNM", Msg({ v = 1, t = "EVM", o = "Bluey Heeler", id = 1, ti = "Hacked", at = now, k = "s", ev = now }), "GUILD", "Chilli Heeler")
Tick(1)
check(cs["Bluey Heeler:1"] == nil, "a Member's edit is dropped")
local mine = C.Save(nil, { title = "My night", at = now + 7200, k = "s" })
INJECT("YNM", Msg({ v = 1, t = "EVM", o = ns.me, id = cs[mine].id, ti = "My night (moved)", at = now + 10800, k = "s", ev = GetServerTime() + 1 }), "GUILD", "Bluey Heeler")
Tick(1)
check(cs[mine].title == "My night (moved)" and Printed("Bluey Heeler edited your calendar event"), "a moderator's edit of my event reaches me, and I'm told")

-- Professions: Bluey removes Bandit's request; a Member can't.
local rs = R.Store()
INJECT("YNM", Msg({ v = 1, t = "RQ", id = 800, it = "Linen Bag", n = 1, note = "", u = now + 99999, ev = now - 50 }), "GUILD", "Bandit Heeler")
INJECT("YNM", Msg({ v = 1, t = "RQ", id = 801, it = "Wool Bag", n = 1, note = "", u = now + 99999, ev = now - 50 }), "GUILD", "Bandit Heeler")
Tick(1)
INJECT("YNM", Msg({ v = 1, t = "RQX", o = "Bandit Heeler", id = 800, ev = now }), "GUILD", "Bluey Heeler")
INJECT("YNM", Msg({ v = 1, t = "RQX", o = "Bandit Heeler", id = 801, ev = now }), "GUILD", "Chilli Heeler")
Tick(1)
check(rs["Bandit Heeler:800"].x == "cancel" and rs["Bandit Heeler:800"].rm == "Bluey Heeler", "a Professions moderator removes a request")
check(not rs["Bandit Heeler:801"].x, "a Member's removal is dropped")
INJECT("YNM", Msg({ v = 1, t = "RQ", id = 800, it = "Linen Bag", n = 1, note = "", u = now + 99999, ev = now + 30 }), "GUILD", "Bandit Heeler")
Tick(1)
check(rs["Bandit Heeler:800"].x == "cancel", "the poster can't bring a removed request back")
local myReq = R.Post(nil, "Silk Bag", 1, "")
INJECT("YNM", Msg({ v = 1, t = "RQX", o = ns.me, id = rs[myReq].id, ev = GetServerTime() }), "GUILD", "Bluey Heeler")
Tick(1)
check(rs[myReq].x == "cancel" and Printed("Bluey Heeler removed your craft request"), "my request removed by a moderator ends for me too")

-- Dungeons: Bluey closes Bingo's group and takes down Bingo's listing; they don't come back.
INJECT("YNM", Msg({ v = 1, t = "GRP", id = 900, d = "wc", me = "t", nt = 1, nh = 1, nd = 3, ht = 1, hh = 0, hd = 0, note = "", u = now + 3600 }), "GUILD", "Bingo Heeler")
INJECT("YNM", Msg({ v = 1, t = "AVL", r = "h", ds = { "rfc" }, u = now + 3600, note = "" }), "GUILD", "Bingo Heeler")
Tick(1)
check(D.groups["Bingo Heeler:900"] and D.avail["Bingo Heeler"], "Bingo's group and listing arrived")
INJECT("YNM", Msg({ v = 1, t = "DMX", o = "Bingo Heeler", g = 900 }), "GUILD", "Chilli Heeler")
Tick(1)
check(D.groups["Bingo Heeler:900"] ~= nil, "a Member can't close a group")
INJECT("YNM", Msg({ v = 1, t = "DMX", o = "Bingo Heeler", g = 900 }), "GUILD", "Bluey Heeler")
INJECT("YNM", Msg({ v = 1, t = "DMX", o = "Bingo Heeler", a = true }), "GUILD", "Bluey Heeler")
Tick(1)
check(D.groups["Bingo Heeler:900"] == nil and D.avail["Bingo Heeler"] == nil, "a Dungeons moderator closes the group and the listing")
INJECT("YNM", Msg({ v = 1, t = "GRP", id = 900, d = "wc", me = "t", nt = 1, nh = 1, nd = 3, ht = 1, hh = 0, hd = 0, note = "", u = now + 3600 }), "GUILD", "Bingo Heeler")
INJECT("YNM", Msg({ v = 1, t = "AVL", r = "h", ds = { "rfc" }, u = now + 3600, note = "" }), "GUILD", "Bingo Heeler")
Tick(1)
check(D.groups["Bingo Heeler:900"] == nil and D.avail["Bingo Heeler"] == nil, "their updates don't bring them back")
INJECT("YNM", Msg({ v = 1, t = "AVL", r = "h", ds = { "rfc" }, u = now + 7200, note = "" }), "GUILD", "Bingo Heeler")
Tick(1)
check(D.avail["Bingo Heeler"] ~= nil, "a new listing later shows as normal")
D.Post("wc", "d", { t = 1, h = 1, d = 3 }, "")
INJECT("YNM", Msg({ v = 1, t = "DMX", o = ns.me, g = D.MyGroup().id }), "GUILD", "Bluey Heeler")
Tick(1)
check(D.MyGroup() == nil and Printed("Bluey Heeler closed your dungeon group"), "my group closed by a moderator closes for me")

-- Streamers: Bluey edits then removes Bandit's card; Bandit's old card doesn't come back.
local st = B.Store().streamers
INJECT("YNM", Msg({ v = 1, t = "BRD", k = "strm", tw = "bandit_plays", when = "Weekends", about = "Rogue", ev = now - 100 }), "GUILD", "Bandit Heeler")
Tick(1)
INJECT("YNM", Msg({ v = 1, t = "BRD", k = "strm", mo = "Bandit Heeler", tw = "bandit_plays", when = "Weekends", about = "Rogue things", ev = now }), "GUILD", "Bluey Heeler")
Tick(1)
check(st["Bandit Heeler"].about == "Rogue things" and st["Bandit Heeler"].mb == "Bluey Heeler", "a Streamers moderator edits someone's card")
INJECT("YNM", Msg({ v = 1, t = "BRD", k = "strm", tw = "bandit_plays", when = "Weekends", about = "Rogue", ev = now - 100 }), "WHISPER", "Bandit Heeler")
Tick(1)
check(st["Bandit Heeler"].about == "Rogue things", "the owner's old card doesn't undo it")
INJECT("YNM", Msg({ v = 1, t = "BRD", k = "strm", mo = "Bandit Heeler", tw = "hacked", ev = now + 5 }), "GUILD", "Chilli Heeler")
Tick(1)
check(st["Bandit Heeler"].tw == "bandit_plays", "a Member's change is dropped")
B.SetStreamer("zac_streams", "Nights", "Shaman")
INJECT("YNM", Msg({ v = 1, t = "BRD", k = "strm", mo = ns.me, x = true, ev = GetServerTime() + 1 }), "GUILD", "Bluey Heeler")
Tick(1)
check(B.Mine() == nil and Printed("Bluey Heeler removed your streamer card"), "my card removed by a moderator goes for me too")

---------------------------------------------------------------------------------------------------
-- I'm an Officer now: I moderate, and my changes go to the guild.
FAKE.myRank, FAKE.myRankName = 1, "Officer"
ns.Guild.Scan()
check(C.CanRemove() and R.CanRemove() and D.CanRemove() and ns.Questions.CanRemove() and B.Moderates("strm") and B.CanEdit(),
    "an Officer moderates every tab by default")
check(not B.CanSetRank() and not B.CanManage(), "but isn't a manager")

local before = #SENT
INJECT("YNM", Msg({ v = 1, t = "EVT", id = 701, ti = "Bandit's other", at = now + 86400, k = "s", ev = now - 100 }), "GUILD", "Bandit Heeler")
Tick(1)
check(C.Save("Bandit Heeler:701", { title = "Bandit's other (fixed)", at = now + 86400, k = "s" }) == "Bandit Heeler:701", "I edit Bandit's event")
local evm = Sent("EVM", before + 1)
check(#evm == 1 and evm[1]._channel == "GUILD" and evm[1].o == "Bandit Heeler" and evm[1].ti == "Bandit's other (fixed)", "the edit goes to the guild")
before = #SENT
INJECT("YNM", Msg({ v = 1, t = "EVT", id = 701, ti = "Bandit's other", at = now + 86400, k = "s", ev = now - 100 }), "WHISPER", "Bandit Heeler")
Tick(3)
local told = Sent("EVM", before + 1)
check(#told == 1 and told[1]._channel == "WHISPER" and told[1]._target == "Bandit Heeler", "Bandit came back with the old one: I tell them")

before = #SENT
INJECT("YNM", Msg({ v = 1, t = "RQ", id = 802, it = "Mageweave Bag", n = 1, note = "", u = now + 99999, ev = now - 50 }), "GUILD", "Bandit Heeler")
Tick(1)
check(R.ModRemove("Bandit Heeler:802") and #Sent("RQX", before + 1) == 1, "I remove Bandit's request; it goes to the guild")
before = #SENT
INJECT("YNM", Msg({ v = 1, t = "RQ", id = 802, it = "Mageweave Bag", n = 1, note = "", u = now + 99999, ev = now - 50 }), "WHISPER", "Bandit Heeler")
Tick(3)
local rqx = Sent("RQX", before + 1)
check(#rqx == 1 and rqx[1]._target == "Bandit Heeler", "Bandit came back with it: I tell them it was removed")

before = #SENT
INJECT("YNM", Msg({ v = 1, t = "GRP", id = 901, d = "rfc", me = "t", nt = 1, nh = 1, nd = 3, ht = 1, hh = 0, hd = 0, note = "", u = now + 3600 }), "GUILD", "Chilli Heeler")
Tick(1)
check(D.ModClose("Chilli Heeler:901") and #Sent("DMX", before + 1) == 1 and D.groups["Chilli Heeler:901"] == nil, "I close Chilli's group; it goes to the guild")

before = #SENT
INJECT("YNM", Msg({ v = 1, t = "BRD", k = "strm", tw = "chilli_tv", when = "", about = "", ev = now }), "GUILD", "Chilli Heeler")
Tick(1)
check(B.ModStreamer("Chilli Heeler", "chilli_tv", "Sundays", "Mage") and st["Chilli Heeler"].when == "Sundays", "I edit Chilli's card")
check(B.ModRemoveStreamer("Chilli Heeler") and st["Chilli Heeler"].x, "and remove it")
local brd = {}
for _, m in ipairs(Sent("BRD", before + 1)) do if m.mo == "Chilli Heeler" then brd[#brd + 1] = m end end
check(#brd == 2, "both go to the guild as moderator changes")

-- A tab set to the guild master only: the Officer stops moderating it.
FAKE.myRank, FAKE.myRankName = 0, "Guild Master"
ns.Guild.Scan()
check(B.SetRankModerates("ask", 1, false) and not B.RankModerates("ask", 1) and B.RankModerates("cal", 1), "the guild master unticks Officer for Ask")
check(B.SetRankModerates("ask", 0, false) == false and B.RankModerates("ask", 0), "the guild master's own rank can't be unticked")
FAKE.myRank, FAKE.myRankName = 1, "Officer"
ns.Guild.Scan()
check(not ns.Questions.CanRemove() and C.CanRemove(), "the Officer no longer moderates Ask, still the calendar")

-- The tab: Remove on others' groups for a moderator.
INJECT("YNM", Msg({ v = 1, t = "GRP", id = 902, d = "rfc", me = "t", nt = 1, nh = 1, nd = 3, ht = 1, hh = 0, hd = 0, note = "", u = now + 3600 }), "GUILD", "Chilli Heeler")
Tick(1)
ns.UI.Open("dungeons")
ns.UI.Select("dungeons")
Tick(1)
local dp
for _, o in ipairs(CREATED) do if o.postForm and o.availForm then dp = o end end
local shown = false
for _, c in ipairs(dp.cards) do if c:IsShown() and c.key == "Chilli Heeler:902" and c.modX:IsShown() then shown = true end end
check(shown, "Remove shows on someone's group for a Dungeons moderator")

---------------------------------------------------------------------------------------------------
-- /ynm dev rank N (for the dev console): see the addon as another rank, this screen only.
FAKE.myRank, FAKE.myRankName = 3, "Member"
ns.Guild.Scan()
check(not B.CanManage() and not C.CanRemove(), "a real Member: no GM tab, no moderating")
SlashCmdList.YEAHNAHMATE("dev rank 0")
check(B.simRank == 0 and B.CanManage() and B.CanSetRank() and B.ShownGuildMaster() and C.CanRemove() and B.CanEdit(),
    "as rank 0: the GM tab and every moderator button show")
before = #SENT
INJECT("YNM", Msg({ v = 1, t = "EVT", id = 702, ti = "Bandit's third", at = now + 86400, k = "s", ev = now - 100 }), "GUILD", "Bandit Heeler")
Tick(1)
C.Remove("Bandit Heeler:702")
B.SetInfo("Simulated", "", "")
B.SetRankModerates("cal", 3, true)
Tick(2)
local leaked = #Sent("EVR", before + 1) + #Sent("BRD", before + 1)
check(leaked == 0, "but nothing is sent that a Member couldn't send (" .. leaked .. ")")
FAKE.myRank, FAKE.myRankName = 0, "Guild Master"
ns.Guild.Scan()
SlashCmdList.YEAHNAHMATE("dev rank 3")
check(not B.CanManage() and not D.CanRemove() and not B.ShownGuildMaster(), "the real guild master can see the addon as a Member")
SlashCmdList.YEAHNAHMATE("dev rank off")
check(B.simRank == nil and B.CanManage(), "rank off: back to the real rank")

-- /ynm dev console hands the addon's table to the private dev console when it's installed.
SlashCmdList.YEAHNAHMATE("dev console")
check(Printed("isn't installed"), "without the console: it just says so")
local got
YeahNahMateDev_Attach = function(t) got = t end
SlashCmdList.YEAHNAHMATE("dev console")
check(got == ns, "with it: the console gets the addon's table")
YeahNahMateDev_Attach = nil

check(#ERRORS == 0, "no errors (" .. (ERRORS[1] or "none") .. ")")
