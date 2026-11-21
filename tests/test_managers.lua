-- Managers: the guild master names guildies who may run things. Only the guild master's
-- list counts (checked against each reader's own roster); managers count as editors; the GM tab shows
-- only for the guild master and managers. Plus the new tab row: Calendar before Dungeons, Legends.
math.randomseed(12)
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
        if ok and type(m) == "table" and m.t == t then m._target = SENT[i].target; m._channel = SENT[i].channel; list[#list + 1] = m end
    end
    return list
end
local B, UI = ns.Board, ns.UI
ns.settings.sharePosition, ns.settings.shareProfessions = false, false
INJECT("YNM", Msg({ v = 1, t = "HI", ver = "0.13.0" }), "GUILD", "Bluey Heeler")
Tick(15)
local now = GetServerTime()

local function Tab(label)
    for _, o in ipairs(CREATED) do
        if o._template == "UIPanelButtonTemplate" and o.sel and o:GetText() == label then return o end
    end
end

-- The tab row: Calendar before Dungeons, Legends after Ask; no GM tab for a member.
UI.Open("home")
Tick(1)
local function X(label) return Tab(label)._pt[2] end
check(X("Calendar") < X("Dungeons") and X("Roster") < X("Calendar") and X("Ask") < X("Legends") and X("Legends") < X("Streamers"),
    "Home, Roster, Calendar, Dungeons, ... Ask, Legends, Streamers")
check(Tab("GM") and not Tab("GM"):IsShown(), "no GM tab for a member")
local right = 0
for _, label in ipairs({ "Home", "Roster", "Calendar", "Dungeons", "Professions", "Ask", "Legends", "Streamers", "Info", "Leveling" }) do
    local b = Tab(label)
    right = math.max(right, X(label) + b._w)
end
check(right <= 748, "the tabs fit in the window (" .. right .. ")")

-- A member can't name managers; a list from someone who isn't the guild master is dropped.
check(not B.CanManage() and B.SetManager("Bingo Heeler", true) == false, "a member can't name managers")
INJECT("YNM", Msg({ v = 1, t = "BRD", k = "mgr", mg = { "Bingo Heeler" }, ev = now }), "GUILD", "Bluey Heeler")
Tick(1)
check(#B.Managers() == 0 and not B.IsManager("Bingo Heeler"), "an officer's managers list is dropped")

-- The guild master (Chilli, for this test) names Bingo (rank 3) and me.
FAKE.roster[4][3] = 0
ns.Guild.Scan()
INJECT("YNM", Msg({ v = 1, t = "BRD", k = "mgr", mg = { "Bingo Heeler", "Ned Jones", "Nobody Atall" }, ev = now + 1 }), "GUILD", "Chilli Heeler")
Tick(1)
local list = B.Managers()
check(#list == 2 and list[1] == "Bingo Heeler" and list[2] == "Ned Jones", "the guild master's list is taken (guildies only)", table.concat(list, ","))
check(B.IsManager("Bingo Heeler") and B.IsEditor("Bingo Heeler") and B.IsManager("Chilli Heeler") and not B.IsManager("Bluey Heeler"),
    "managers are editors; the guild master is a manager")
INJECT("YNM", Msg({ v = 1, t = "BRD", k = "info", motd = "Bingo runs this", text = "", ev = now + 2 }), "GUILD", "Bingo Heeler")
Tick(1)
check(B.Info() and B.Info().by == "Bingo Heeler", "a manager (rank 3) edits the guild info")
check(B.CanManage() and B.CanEdit() and B.CanSetRank(), "I'm a manager: the guild master's access")
check(UI.RankIcon(ns.Guild.Get("Bingo Heeler")) == UI.RANK_OFFICER, "a manager gets the shield")

-- The GM tab shows for me now; it lists the managers; no Add or Remove for a manager.
UI.Dirty(); Tick(1)
check(Tab("GM"):IsShown(), "the GM tab shows for a manager")
UI.Select("gm")
Tick(1)
local gm
for _, o in ipairs(CREATED) do if o.mgrView and o.modRows then gm = o end end
check(gm:IsShown() and gm.rows[1]:IsShown() and gm.rows[1].name:GetText():find("Bingo Heeler", 1, true)
    and gm.rows[2]:IsShown() and not gm.rows[3]:IsShown(), "the managers are listed")
check(gm.addBtn:IsShown() and gm.rows[1].remove:IsShown() and ns.Board.CanSetRank(), "a manager can change the list and the ranks")
check(gm.viewCards[1].pts:GetText() == ns.L.GM_YOU_MANAGER_TIP and gm.viewCards[1].bar:IsShown() and #gm.viewCards == 4, "four cards; Managers picked, says I was named")
gm.powersBtn:Click()
Tick(1)
check(gm.powersBtn:IsShown() and gm.mgrView:IsShown(), "What can managers do? sits on the Managers view")
gm.viewCards[3]:Click()
Tick(1)
check(gm.milestonesView:IsShown() and not gm.mgrView:IsShown() and gm.viewTitle:GetText() == ns.L.GM_VIEW_MILESTONES, "Milestones (blank for now)")
gm.viewCards[1]:Click()
Tick(1)

-- An older list (whispered at log-in) doesn't roll the newer one back; a newer one replaces it.
INJECT("YNM", Msg({ v = 1, t = "BRD", k = "mgr", mg = { "Bandit Heeler" }, ev = now }), "GUILD", "Chilli Heeler")
Tick(1)
check(#B.Managers() == 2, "an older list is ignored")
INJECT("YNM", Msg({ v = 1, t = "BRD", k = "mgr", mg = { "Bingo Heeler" }, ev = now + 3 }), "GUILD", "Chilli Heeler")
Tick(1)
check(#B.Managers() == 1 and not B.IsManager(ns.me) and not B.CanManage(), "a newer list without me: I'm not a manager")
UI.Dirty(); Tick(1)
check(not Tab("GM"):IsShown() and not gm:IsShown(), "the GM tab goes, and the window leaves it")
FAKE.roster[4][3] = 3
ns.Guild.Scan()

-- I'm the guild master: add by picking from a list, remove with Remove; each change goes to the guild.
FAKE.myRank, FAKE.myRankName = 0, "Guild Master"
ns.Guild.Scan()
check(#B.Managers() == 1, "Chilli's list still holds (Bingo) after Chilli isn't guild master any more", #B.Managers())
UI.Dirty(); Tick(1)
UI.Select("gm")
Tick(1)
check(gm:IsShown() and gm.addBtn:IsShown() and gm.viewCards[1].pts:GetText() == ns.L.GM_YOU_GM_TIP, "the guild master gets Add and the ranks")
gm.addBtn:Click()
Tick(1)
check(gm.picker:IsShown() and not gm.rows[1]:IsShown() , "Add a manager opens the picker in place of the list")
-- Top ranks first: rows in rank order, nobody below the third rank, not me.
local lastRank, below, me = -1, false, false
local ranks = B.Ranks()
local cut = ranks[math.min(#ranks, 3)].index
for _, r in ipairs(gm.pickRows) do
    if r:IsShown() then
        local m = ns.Guild.Get(r.who)
        if m.rankIndex < lastRank then lastRank = 999 else lastRank = m.rankIndex end
        if m.rankIndex > cut then below = true end
        if r.who == ns.me then me = true end
    end
end
check(lastRank ~= 999 and not below and not me, "top ranks only, highest first, and not me")
gm.pickShow(2)
Tick(1)
local shown = 0
for _, r in ipairs(gm.pickRows) do if r:IsShown() then shown = shown + 1 end end
check(shown >= 1 and gm.pickPager, "Everyone lists all ranks")
gm.search:SetText("band"); UI.Dirty()
Tick(1)
check(gm.pickRows[1]:IsShown() and gm.pickRows[1].who == "Bandit Heeler" and not gm.pickRows[2]:IsShown(), "searching 'band' finds Bandit Heeler")
local before = #SENT + 1
gm.pickRows[1].add:Click()
Tick(1)
local out = Sent("BRD", before)
check(B.IsManager("Bandit Heeler") and #out == 1 and out[1].k == "mgr" and #out[1].mg == 2 and out[1]._channel == "GUILD",
    "Make manager names Bandit Heeler, sent to the guild")
check(not gm.pickRows[1].add:IsShown() and gm.pickRows[1].is:GetText():find(ns.L.GM_IS_MANAGER, 1, true), "the row now says Manager")
gm.pickDone:Click()
Tick(1)
check(not gm.picker:IsShown() and gm.rows[1]:IsShown() and gm.search:GetText() == "", "Done goes back to the list")
UI.Dirty(); Tick(1)
local row
for _, r in ipairs(gm.rows) do if r:IsShown() and r.who == "Bandit Heeler" then row = r end end
check(row and row.remove:IsShown(), "Remove on each row")
before = #SENT + 1
row.remove:Click()
Tick(1)
out = Sent("BRD", before)
check(not B.IsManager("Bandit Heeler") and #out == 1 and #out[1].mg == 1, "Remove takes them off and tells the guild")

-- The side button opens the Info tab, editing.
gm.editInfo:Click()
Tick(1)
local info
for _, o in ipairs(CREATED) do if o.editBtn and o.motdBox then info = o end end
check(info:IsShown() and info.editing, "Edit guild info opens the Info tab, editing")
info.editing = false

-- A guildie asking for the board gets the list as a copy (with its author).
before = #SENT + 1
INJECT("YNM", Msg({ v = 1, t = "REQ", w = "BRD" }), "WHISPER", "Bluey Heeler")
Tick(1)
local got
for _, m in ipairs(Sent("BRD", before)) do if m.k == "mgr" then got = m end end
check(got and got._target and got.o == nil and #got.mg == 1, "my managers list goes to whoever asks (mine, so no o)")

-- Leavers drop out of the list.
FAKE.roster[3][3] = 3
table.remove(FAKE.roster, 3)
ns.Guild.complete = true
ns.Guild.Scan()
check(#B.Managers() == 0, "a manager who left isn't one any more")

check(#ERRORS == 0, "no errors", ERRORS[1])
