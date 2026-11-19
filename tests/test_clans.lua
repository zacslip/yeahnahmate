-- Clans: races and roles from guildies' hellos (and the game's GUID lookup for the rest), the
-- clan leaders from the rank each clan is linked to (guild master / managers only), my roles (two at
-- most, sent once after the clicks), older versions' rank edits keeping the Clan moderator ticks,
-- catching up on the clan ranks at log-in, the tab and the GM tab's Clan leaders page.
math.randomseed(21)
YeahNahMateDB = nil
FAKE.myRank = 0                 -- I'm the guild master here (Ned Jones)
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
local Cl, B, UI, L = ns.Clans, ns.Board, ns.UI, ns.L
ns.settings.sharePosition, ns.settings.shareProfessions = false, false
function UnitRace() return "Orc", "Orc", 2 end
-- The game knows Bandit's race (offline, no addon) from his GUID; nobody else's.
function GetPlayerInfoByGUID(guid)
    if guid == "Player-6925-00000004" then return "Rogue", "ROGUE", "Troll", "Troll", 2, "Bandit", "" end
end
Tick(15)
local now = GetServerTime()

-- My hello says my race and roles (none yet).
SlashCmdList.YEAHNAHMATE("")            -- (opens the window; nothing to do with hellos)
local hi = Sent("HI")[1]
check(hi and hi.ra == "Orc" and hi.ro == "" and hi.crv == 0, "my HI carries my race, no roles, clan rank version 0")

-- Guildies' hellos: race and roles kept; junk cleaned; an older version says nothing.
INJECT("YNM", Msg({ v = 1, t = "HI", ver = ns.VERSION, ra = "Troll", ro = "th" }), "GUILD", "Bluey Heeler")
INJECT("YNM", Msg({ v = 1, t = "HI", ver = ns.VERSION, ra = "Tau|ren<>", ro = "dddhtx" }), "GUILD", "Bingo Heeler")
INJECT("YNM", Msg({ v = 1, t = "HI", ver = "0.17.1" }), "GUILD", "Chilli Heeler")
INJECT("YNM", Msg({ v = 1, t = "HI", ver = ns.VERSION, ra = "Orc", ro = "t" }), "GUILD", "Not Inguild")
Tick(2)
check(Cl.Race("Bluey Heeler") == "Troll" and Cl.Roles("Bluey Heeler") == "th", "Bluey: Troll, tank + healer")
check(Cl.Race("Bingo Heeler") == "Tauren" and Cl.Roles("Bingo Heeler") == "th", "junk cleaned: Tauren, two roles at most, in order")
check(Cl.Race("Chilli Heeler") == nil and Cl.Roles("Chilli Heeler") == "", "older version: race not known")
check(Cl.Race("Bandit Heeler") == "Troll", "no addon: race from the game's GUID lookup")
check(Cl.People()["Not Inguild"] == nil, "not a guildie: nothing kept")
check(Cl.Race("Ned Jones") == "Orc", "my own race")

-- Roles change: ME.
INJECT("YNM", Msg({ v = 1, t = "ME", ra = "Troll", ro = "d" }), "GUILD", "Bluey Heeler")
Tick(1)
check(Cl.Roles("Bluey Heeler") == "d", "ME changes Bluey's roles")
-- Chilli updates: an older hello after that doesn't wipe it.
INJECT("YNM", Msg({ v = 1, t = "ME", ra = "Scourge", ro = "h" }), "GUILD", "Chilli Heeler")
INJECT("YNM", Msg({ v = 1, t = "HI", ver = "0.17.1" }), "WHISPER", "Chilli Heeler")
Tick(1)
check(Cl.Race("Chilli Heeler") == "Scourge" and Cl.Roles("Chilli Heeler") == "h", "an old hello keeps what we hold")

-- The clans.
local list, unknown = Cl.List()
local names = {}
for _, c in ipairs(list) do names[#names + 1] = c.race .. "=" .. c.n end
check(table.concat(names, ",") == "Orc=1,Troll=2,Tauren=1,Scourge=1" and unknown == 0, "clans in order, with counts", table.concat(names, ","))
local trolls = Cl.Members("Troll")
check(#trolls == 2 and trolls[1].name == "Bluey Heeler" and trolls[2].name == "Bandit Heeler", "members: online first")

-- My roles: two at most (a third replaces the oldest), sent once 3 s after the last click.
local before = #SENT
Cl.ToggleRole("h"); Cl.ToggleRole("d"); Cl.ToggleRole("t")
check(Cl.MyRoles() == "td", "third role replaces the first picked (healer)", Cl.MyRoles())
Cl.ToggleRole("t")
check(Cl.MyRoles() == "d", "a second click takes a role off")
Tick(1)
check(#Sent("ME", before + 1) == 0, "not sent straight away")
Tick(3)
local me = Sent("ME", before + 1)
check(#me == 1 and me[1].ro == "d" and me[1].ra == "Orc" and me[1]._channel == "GUILD", "one ME with the roles")
Cl.ToggleRole("x")
check(Cl.MyRoles() == "d", "an unknown role does nothing")

-- Leaders: no rank linked yet.
check(#Cl.Leaders("Troll") == 0, "no leader before a rank is linked")
-- A member can't link ranks; a list from a non-manager is dropped.
INJECT("YNM", Msg({ v = 1, t = "BRD", k = "clr", cr = { Troll = 1 }, ev = now }), "GUILD", "Bingo Heeler")
Tick(1)
check(Cl.RankFor("Troll") == nil, "clan ranks from a member are dropped")
-- I'm the guild master: link Troll to rank 1 (Bluey is an Officer, rank 1).
before = #SENT
check(Cl.SetRank("Troll", 1), "the guild master links a rank")
local brd = Sent("BRD", before + 1)
check(#brd == 1 and brd[1].k == "clr" and brd[1].cr.Troll == 1, "sent to the guild")
check(Cl.Leaders("Troll")[1] == "Bluey Heeler" and Cl.IsLeader("Bluey Heeler") and not Cl.IsLeader("Bandit Heeler"),
    "Bluey leads the Troll clan")
check(Cl.Members("Troll")[1].name == "Bluey Heeler", "the leader is listed first")
-- A rank leads one clan: linking it to Orc unlinks Troll.
Cl.SetRank("Orc", 1)
check(Cl.RankFor("Troll") == nil and Cl.RankFor("Orc") == 1 and #Cl.Leaders("Orc") == 1, "a rank leads one clan at most")
Cl.SetRank("Orc", nil)
Cl.SetRank("Troll", 1)
check(Cl.RankFor("Orc") == nil and Cl.RankFor("Troll") == 1, "unlink and link back")
check(Cl.SetRank("Troll", 0) == false, "the guild master's own rank can't be a clan rank")
-- A manager's message: newest wins; a rank twice is taken once.
INJECT("YNM", Msg({ v = 1, t = "BRD", k = "clr", cr = { Troll = 1, Orc = 1, ["Tau ren"] = 3 }, ev = GetServerTime() + 5 }), "GUILD", "Chilli Heeler")
Tick(1)
check(Cl.RankFor("Troll") == 1 and Cl.RankFor("Orc") == nil, "(Chilli isn't a manager yet: dropped)")
B.SetManager("Chilli Heeler", true)
Tick(1)
INJECT("YNM", Msg({ v = 1, t = "BRD", k = "clr", cr = { Troll = 3, Orc = 3, ["Tau ren"] = 4, Scourge = 12 }, ev = GetServerTime() + 5 }), "GUILD", "Chilli Heeler")
Tick(1)
local orcOrTroll = (Cl.RankFor("Troll") == 3) ~= (Cl.RankFor("Orc") == 3)
check(orcOrTroll and Cl.RankFor("Tauren") == 4 and Cl.RankFor("Scourge") == nil, "a manager's clan ranks: one race per rank, odd ranks dropped")
INJECT("YNM", Msg({ v = 1, t = "BRD", k = "clr", cr = { Troll = 1 }, ev = now - 100 }), "GUILD", "Chilli Heeler")
Tick(1)
check(Cl.RankFor("Tauren") == 4, "an older version of the clan ranks is ignored")
Cl.SetRank("Troll", 1)
for r in pairs(B.Store().clr.cr) do if r ~= "Troll" then Cl.SetRank(r, nil) end end

-- Copies: the board copy for a guildie who asks has the clan ranks.
before = #SENT
INJECT("YNM", Msg({ v = 1, t = "REQ", w = "BRD" }), "WHISPER", "Bingo Heeler")
Tick(2)
local got = false
for _, m in ipairs(Sent("BRD", before + 1)) do if m.k == "clr" and m._target == "Bingo Heeler" and m.cr.Troll == 1 then got = true end end
check(got, "the clan ranks go out with the board copies")

-- Older versions' rank edits leave the Clan moderator ticks alone.
check(B.SetRankModerates("clan", 3, true), "tick rank 3 for Clans")
check(B.RankModerates("clan", 3), "rank 3 moderates Clans")
INJECT("YNM", Msg({ v = 1, t = "BRD", k = "rank", er = 1, tm = { cal = 3, dun = 3, prof = 3, ask = 3, strm = 3, info = 3 },
    ev = GetServerTime() + 30 }), "GUILD", "Chilli Heeler")
Tick(1)
check(B.RankModerates("clan", 3) and not B.RankModerates("cal", 3), "an old manager's edit is taken, the Clan ticks kept")

-- Catching up: a newer clan rank version in a hello in my first 3 minutes -> I ask for the board.
-- (Logged in 15+ s ago, so still inside.)
local held = B.Store().clr.ev
before = #SENT
INJECT("YNM", Msg({ v = 1, t = "HI", ver = ns.VERSION, ra = "Troll", ro = "d", crv = held + 50 }), "WHISPER", "Bluey Heeler")
Tick(6)
local asks = 0
for _, m in ipairs(Sent("REQ", before + 1)) do if m.w == "BRD" and m._target == "Bluey Heeler" then asks = asks + 1 end end
check(asks == 1, "a newer clan rank version: ask that guildie for the board once")
INJECT("YNM", Msg({ v = 1, t = "HI", ver = ns.VERSION, ra = "Troll", ro = "d", crv = held + 60 }), "WHISPER", "Bluey Heeler")
Tick(6)
asks = 0
for _, m in ipairs(Sent("REQ", before + 1)) do if m.w == "BRD" then asks = asks + 1 end end
check(asks == 1, "only once")

-- Departed guildies' race and roles go after a full roster read.
local bingo = table.remove(FAKE.roster, 3)
FireEvent("GUILD_ROSTER_UPDATE"); Tick(2)
check(Cl.People()["Bingo Heeler"] == nil and Cl.People()["Bluey Heeler"] ~= nil, "a departed guildie's race and roles go")
table.insert(FAKE.roster, 3, bingo)
FireEvent("GUILD_ROSTER_UPDATE"); Tick(2)

-- The tab: every clan side by side (Orc, Troll, Undead: Bingo's race isn't known any more since
-- they left and came back), each with its leader and members, role badges on the left.
UI.Open("clans")
Tick(1)
local page
for _, o in ipairs(CREATED) do if o.cols and o.roleBtns then page = o end end
check(page ~= nil, "the Clans tab opens")
local function Col(race)
    for _, c in ipairs(page.cols) do
        if c:IsShown() and c.title:GetText():find(string.format(L.CLAN_NAME, Cl.RaceName(race)), 1, true) then return c end
    end
end
local shownCols = 0
for _, c in ipairs(page.cols) do if c:IsShown() then shownCols = shownCols + 1 end end
check(shownCols == 3 and page.cols[1].title:GetText():find("Orc", 1, true) and page.cols[3].title:GetText():find("Undead", 1, true),
    "three clans shown, in order (Orc, Troll, Undead)")
check(Col("Orc").title:GetText():find(L.CLAN_YOU, 1, true) and not Col("Troll").title:GetText():find(L.CLAN_YOU, 1, true),
    "my clan says (you)")
local troll = Col("Troll")
check(troll.leader:GetText():find("LeaderIcon", 1, true) and troll.leader:GetText():find("Bluey Heeler", 1, true),
    "Troll clan: Bluey leads, with a crown")
check(troll.count:GetText() == string.format(L.CLAN_COUNT, 2, 1), "Troll clan: 2 members, 1 online", troll.count:GetText())
check(troll.rows[1].m.name == "Bluey Heeler" and troll.rows[1].roles:GetText():find("Sword", 1, true)
    and troll.rows[2].m.name == "Bandit Heeler" and troll.rows[2].roles:GetText() == "", "rows: role badge, then the name")
check(Col("Scourge").leader:GetText():find(L.CLAN_NO_LEADER, 1, true), "no leader yet for Undead")
check(page.roleBtns.d.sel:IsShown() and not page.roleBtns.t.sel:IsShown(), "my roles lit: DPS")
page.roleBtns.h:Click(); Tick(1)
check(Cl.MyRoles() == "hd" and page.roleBtns.h.sel:IsShown(), "clicking Healer adds it")
check(Col("Orc").rows[1].roles:GetText():find("Heal", 1, true), "and my badge shows it")

-- Leaders found by themselves: from rank 2 down, each rank with one guildie leads that guildie's clan;
-- the run stops at a rank with more (or none). A hand link on the GM tab wins for its race.
-- Roster: Ned 0, Bluey 1 (Troll, linked by hand to rank 1), Chilli 2 (Undead), Bandit 3 (Troll),
-- Bingo 4 (race not known), and a made-up rank 6 with one guildie, after a gap at 5.
FAKE.roster[4][3], FAKE.roster[5][3], FAKE.roster[3][3] = 2, 3, 4
FAKE.roster[#FAKE.roster + 1] = { "Lonely Larrikin", "Hermit", 6, 30, "Mage", "Durotar", "", "", false, 0, "MAGE", 0, 0, false, false, 3, "Player-6797-00000009" }
local realInfo = GetPlayerInfoByGUID
function GetPlayerInfoByGUID(guid)
    if guid == "Player-6797-00000009" then return "Mage", "MAGE", "Orc", "Orc", 2, "x", "" end
    return realInfo(guid)
end
FireEvent("GUILD_ROSTER_UPDATE"); Tick(2)
check(Cl.RankFor("Scourge") == 2 and Cl.Leaders("Scourge")[1] == "Chilli Heeler", "rank 2, one guildie: Chilli leads the Undead")
check(Cl.RankFor("Troll") == 1 and Cl.Leaders("Troll")[1] == "Bluey Heeler" and not Cl.IsLeader("Bandit Heeler"),
    "the hand link wins: Bluey still leads the Trolls, not Bandit on rank 3")
check(Cl.RankFor("Orc") == nil, "rank 5 has nobody: the run stops, so Lonely on rank 6 leads nobody")
check(not Cl.LinkedByHand(2) and Cl.LinkedByHand(1), "found vs linked by hand")
-- Take the hand link off: back to what the roster says (Bandit, the only one on rank 3).
Cl.SetRank("Troll", nil)
check(Cl.RankFor("Troll") == 3 and Cl.Leaders("Troll")[1] == "Bandit Heeler", "no hand link: Bandit leads the Trolls")
-- Two on rank 2: the run stops at once.
FAKE.roster[5][3] = 2
FireEvent("GUILD_ROSTER_UPDATE"); Tick(2)
check(Cl.RankFor("Scourge") == nil and Cl.RankFor("Troll") == nil, "two on the first clan rank: nothing found")
-- Back as it was.
table.remove(FAKE.roster)
GetPlayerInfoByGUID = realInfo
FAKE.roster[4][3], FAKE.roster[5][3], FAKE.roster[3][3] = 3, 3, 3
FireEvent("GUILD_ROSTER_UPDATE"); Tick(2)
Cl.SetRank("Troll", 1)

-- The GM tab's Clan leaders page.
UI.Open("gm")
Tick(1)
local gm
for _, o in ipairs(CREATED) do if o.clanRows and o.modSwitch then gm = o end end
gm.pickView(2); gm.modSwitch(2); Tick(1)
check(gm.clanRanks:IsShown() and not gm.modTicks:IsShown(), "Clan leaders page shows")
local officerRow
for _, r in ipairs(gm.clanRows) do if r.index == 1 then officerRow = r end end
check(officerRow and officerRow.pick:GetText():find("Troll", 1, true), "the Officer rank leads the Troll clan")
officerRow.pick:Click(); Tick(1)
gm.clanMenu.rows[1]:Click(); Tick(1)
check(Cl.RankFor("Troll") == nil, "As the roster says takes the hand link off")
officerRow.pick:Click(); Tick(1)
gm.clanMenu.rows[3]:Click(); Tick(1)             -- Leads no clan, Orc, Troll, ...
check(Cl.RankFor("Troll") == 1, "picking Troll links it again")

check(#ns.db.errors == 0, "no errors", ns.db.errors[1] and ns.db.errors[1].msg)
