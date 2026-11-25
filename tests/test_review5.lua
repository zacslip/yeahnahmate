-- Full code review, 25 Nov (before 0.28.0): the fixes.
--   * Nothing is saved under a made-up character ("?") when the game fires events before log-in.
--   * A first Yeah to sharing professions sends the recipe list.
--   * A request heard as a copy keeps when it was posted.
--   * Milestone pop-ups: at most 3 a minute from one guildie.
--   * "Welcome posted" only counts from someone who may post the welcome.
--   * Posts on questions we haven't heard of: at most MAX_STUBS waiting, and they never push real cards out.
--   * The all-clans column scrolls when there are more clans than fit.
--   * The minimap button's angle is a real default again.
math.randomseed(23)
YeahNahMateDB = nil
FAKE.myRank = 0                 -- I'm the guild master (Ned Jones)
local ns = LoadAddon("YeahNahMate", "YeahNahMate")
-- Before log-in: a group change (after a /reload in a group) must not save a "?" character.
FireEvent("GROUP_ROSTER_UPDATE")
ns.Dungeons.MyGroup()
ns.Prof.MyData()
check(ns.db.chars == nil or ns.db.chars["?"] == nil, "before log-in: no '?' character saved")
LOGGED_IN = true
FireEvent("PLAYER_LOGIN")
local Ser = LibStub("AceSerializer-3.0")
local function Msg(t) t.v = 1; return Ser:Serialize(t) end
local function Sent(t, from)
    local list = {}
    for i = (from or 1), #SENT do
        local ok, m = Ser:Deserialize(SENT[i].text)
        if ok and type(m) == "table" and m.t == t then list[#list + 1] = m end
    end
    return list
end
local L, UI = ns.L, ns.UI
ns.settings.sharePosition = false
Tick(15)
check(ns.db.chars["?"] == nil, "after log-in: still no '?' character")
check(ns.settings.minimapAngle == 200, "the minimap button's angle has its default")

-- A first Yeah to sharing professions (it was never answered): my list goes to the guild.
ns.settings.shareProfessions = nil
local mine = ns.Prof.MyData()
mine.profs[171] = { i = { 2330, 2331 }, s = 50 }
local pv0 = mine.pv
local before = #SENT
ns.settings.shareProfessions = true
ns.Fire("SETTINGS")
Tick(3)
local profs = Sent("PROF", before + 1)
check(#profs == 1 and type(profs[1].p) == "table" and mine.pv > pv0, "first Yeah: the recipe list goes out with a new version")

-- A request copy from two days ago: it keeps its posting time.
local now = GetServerTime()
INJECT("YNM", Msg({ t = "RQ", id = 7, it = "Linen Bag", n = 1, u = now + 86400, ev = now - 100, at = now - 2 * 86400 }), "GUILD", "Bluey Heeler")
Tick(1)
local rq = ns.Requests.Store()["Bluey Heeler:7"]
check(rq and rq.at == now - 2 * 86400, "a request keeps when it was posted (" .. tostring(rq and rq.at) .. ")")

-- Milestone pop-ups: 3 a minute from one guildie, then quiet; a minute later, fine again.
local pops = 0
local realShow = ns.Milestones.ShowPop
ns.Milestones.ShowPop = function(...) pops = pops + 1 end
for _ = 1, 6 do INJECT("YNM", Msg({ t = "MSF", m = "Bingo hit 20!" }), "GUILD", "Bingo Heeler") end
Tick(1)
check(pops == 3, "pop-ups: 3 a minute from one guildie (" .. pops .. ")")
INJECT("YNM", Msg({ t = "MSF", m = "Bluey hit 30!" }), "GUILD", "Bluey Heeler"); Tick(1)
check(pops == 4, "another guildie's still shows")
Tick(61)
INJECT("YNM", Msg({ t = "MSF", m = "Bingo hit 21!" }), "GUILD", "Bingo Heeler"); Tick(1)
check(pops == 5, "a minute later, fine again")
ns.Milestones.ShowPop = realShow

-- "Welcome posted": only from someone who may post it (rank index <= wr; wr is 1 by default).
local posted = 0
local realPost = ns.Milestones.PostWelcome
ns.Milestones.PostWelcome = function() posted = posted + 1 end
check(ns.Milestones.SetWelcome({ m = "Welcome {name}!", on = true, gc = true, wr = 1 }), "welcome on, officers and up")
Tick(1)
INJECT("YNM", Msg({ t = "MSW", n = "Newbie One" }), "GUILD", "Bingo Heeler"); Tick(1)     -- a Member: ignored
ns.Milestones.OnJoin("Newbie One"); Tick(5)
check(posted == 1, "a Member's 'welcome posted' doesn't stop the welcome")
INJECT("YNM", Msg({ t = "MSW", n = "Newbie Two" }), "GUILD", "Bluey Heeler"); Tick(1)     -- an Officer: counts
ns.Milestones.OnJoin("Newbie Two"); Tick(5)
check(posted == 1, "an Officer's 'welcome posted' does")
ns.Milestones.PostWelcome = realPost

-- Posts on questions nobody has heard of: at most 200 wait; they never push real cards out.
local store = ns.Questions.Store()
for i = 1, 230 do
    INJECT("YNM", Msg({ t = "QA", o = "Bandit Heeler", id = 5000 + i, pv = now, p = { { tx = "hi" } } }), "GUILD", "Bluey Heeler")
end
Tick(1)
local stubs = 0
for _, q in pairs(store) do if q.stub then stubs = stubs + 1 end end
check(stubs == 200, "at most 200 posts wait for their question (" .. stubs .. ")")

-- The all-clans column: 7 clans, 5 shown, the wheel shows the rest.
ns.settings.clanView = "roll"
UI.Open("clans"); Tick(1)
local cp
for _, o in ipairs(CREATED) do if o.cols and o.roleBtns then cp = o end end
local col = cp.allCol
local realList = ns.Clans.List
local seven = {}
for _, r in ipairs({ "Orc", "Troll", "Tauren", "Scourge", "Skyborne", "BloodElf", "Goblin" }) do seven[#seven + 1] = { race = r, n = 1, online = 1, leaders = {} } end
ns.Clans.List = function() return seven end
UI.Dirty(); Tick(1)
local shown = {}
for _, b in ipairs(col.blocks) do if b:IsShown() then shown[#shown + 1] = b.race end end
check(#shown == 5 and shown[1] == "Orc" and col.more:GetText() == string.format(L.SHOWN, 1, 5, 7), "7 clans: the first 5 shown, '1-5 of 7'")
col.blocks[1]._scripts.OnMouseWheel(col.blocks[1], -1); Tick(1)
col.blocks[1]._scripts.OnMouseWheel(col.blocks[1], -1); Tick(1)
col.blocks[1]._scripts.OnMouseWheel(col.blocks[1], -1); Tick(1)
shown = {}
for _, b in ipairs(col.blocks) do if b:IsShown() then shown[#shown + 1] = b.race end end
check(shown[5] == "Goblin" and shown[1] == "Tauren", "scrolled to the end: Goblin shown (and no further)")
ns.Clans.List = realList
ns.settings.clanView = "mine"
UI.Dirty(); Tick(1)

check(#ERRORS == 0, "no errors (" .. tostring(ERRORS[1]) .. ")")
