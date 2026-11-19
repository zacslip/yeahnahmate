-- Clans, round 2: the clan's guild rank title under its name, sorting every clan's list by roles or
-- name (again = reversed, a third time = the usual order; not during my meeting), the Roster's role
-- icons and Race column (sortable), and the GM tab's warning when two ranks would lead one clan.
math.randomseed(23)
YeahNahMateDB = nil
FAKE.myRank = 0                 -- I'm the guild master here (Ned Jones)
-- Ranks: Chilli on "Warband" (2) and Bandit on "Blood Guard" (3), both Trolls: Chilli's rank leads the
-- Trolls, Bandit's would too (a clash). Bingo on rank 4.
FAKE.roster[3][2], FAKE.roster[3][3] = "Member", 4         -- Bingo
FAKE.roster[4][2], FAKE.roster[4][3] = "Warband", 2        -- Chilli
FAKE.roster[5][2], FAKE.roster[5][3] = "Blood Guard", 3    -- Bandit (offline)
function GetPlayerInfoByGUID(guid)
    if guid == "Player-6925-00000004" then return "Rogue", "ROGUE", "Troll", "Troll", 2, "Bandit", "" end
end
local ns = LoadAddon("YeahNahMate", "YeahNahMate")
LOGGED_IN = true
FireEvent("PLAYER_LOGIN")
local Ser = LibStub("AceSerializer-3.0")
local function Msg(t) return Ser:Serialize(t) end
local Cl, UI, L = ns.Clans, ns.UI, ns.L
ns.settings.sharePosition, ns.settings.shareProfessions = false, false
function UnitRace() return "Orc", "Orc", 2 end
Tick(15)
INJECT("YNM", Msg({ v = 1, t = "HI", ver = ns.VERSION, ra = "Orc", ro = "t" }), "GUILD", "Bluey Heeler")
INJECT("YNM", Msg({ v = 1, t = "HI", ver = ns.VERSION, ra = "Orc", ro = "h" }), "GUILD", "Bingo Heeler")
INJECT("YNM", Msg({ v = 1, t = "HI", ver = ns.VERSION, ra = "Troll", ro = "" }), "GUILD", "Chilli Heeler")
Cl.SetRoles("d")
FireEvent("GUILD_ROSTER_UPDATE"); Tick(2)

-- Leaders and the clash.
check(Cl.RankFor("Troll") == 2 and Cl.Leaders("Troll")[1] == "Chilli Heeler", "Warband (2) leads the Trolls: Chilli")
local clash = Cl.Clash(3)
check(clash and clash.race == "Troll" and clash.winner == 2 and clash.who == "Bandit Heeler", "Blood Guard (3) clashes: a Troll too")
check(Cl.Clash(2) == nil and Cl.Clash(4) == nil, "no clash on the leading rank or on a rank that isn't one")
check(Cl.RankTitle("Troll") == "Warband" and Cl.RankTitle("Orc") == "Member" and Cl.RankTitle("Skyborne") == "",
    "rank titles: Warband for the Trolls, Member for the Orcs (Bingo, alone on rank 4), none for a clan without a rank")

-- The GM tab warns on the Blood Guard row.
UI.Open("gm"); Tick(1)
local gm
for _, o in ipairs(CREATED) do if o.clanRows and o.modSwitch then gm = o end end
gm.pickView(2); gm.modSwitch(2); Tick(1)
local row3
for _, r in ipairs(gm.clanRows) do if r.index == 3 then row3 = r end end
check(row3 and row3.warn:GetText():find(string.format(L.GM_CLAN_CLASH, "Troll", "Warband"), 1, true), "GM tab: 2 leaders for Troll: Warband leads",
    row3 and row3.warn:GetText())
row3._scripts.OnEnter(row3); row3._scripts.OnLeave(row3)
-- Linking Blood Guard to another clan by hand ends the clash.
Cl.SetRank("Scourge", 3); Tick(1)
check(Cl.Clash(3) == nil, "linked by hand: no clash")
Cl.SetRank("Scourge", nil); Tick(1)
check(Cl.Clash(3) ~= nil, "unlinked: the clash is back")

-- The Clans tab: the rank title under the clan's name.
UI.Open("clans"); Tick(1)
local page
for _, o in ipairs(CREATED) do if o.cols and o.roleBtns then page = o end end
local function Col(race)
    for _, c in ipairs(page.cols) do
        if c:IsShown() and c.title:GetText():find(string.format(L.CLAN_NAME, Cl.RaceName(race)), 1, true) then return c end
    end
end
check(Col("Troll").rankTitle:GetText() == "Warband" and Col("Orc").rankTitle:GetText() == "Member", "rank title under the clan's name")

-- Sorting the lists.
local function Order(race)
    local out = {}
    for _, r in ipairs(Col(race).rows) do if r:IsShown() and r.m then out[#out + 1] = r.m.name:match("^%S+") end end
    return table.concat(out, ",")
end
check(Order("Orc") == "Bingo,Bluey,Ned", "usual order: online, then by name", Order("Orc"))
local orc = Col("Orc")
local rolesHead, nameHead = orc.heads[1], orc.heads[2]
rolesHead:Click(); Tick(1)
check(Order("Orc") == "Bluey,Bingo,Ned", "by roles: Tank, Healer, DPS", Order("Orc"))
check(rolesHead.label:GetText():find("Arrow-Up", 1, true) and Col("Troll").heads[1].label:GetText():find("Arrow-Up", 1, true),
    "every list shows the sort")
rolesHead:Click(); Tick(1)
check(Order("Orc") == "Ned,Bingo,Bluey", "again: reversed", Order("Orc"))
rolesHead:Click(); Tick(1)
check(Order("Orc") == "Bingo,Bluey,Ned" and not rolesHead.label:GetText():find("Arrow", 1, true), "a third time: the usual order")
nameHead:Click(); nameHead:Click(); Tick(1)
check(Order("Orc") == "Ned,Bluey,Bingo", "by name, reversed", Order("Orc"))
check(Order("Troll") == "Chilli,Bandit", "online before offline, whatever the sort", Order("Troll"))
-- During my meeting the meeting's list keeps its order; the sort titles do nothing there.
ns.ClanMeet.Start("Orc"); Tick(1)
nameHead:Click(); Tick(1)
check(page.sortKey == "name" and page.sortDesc == true, "a click on my meeting's list's sort titles does nothing")
ns.ClanMeet.Stop(); Tick(1)
nameHead:Click(); Tick(1)
check(page.sortKey == nil, "off again")

-- The Roster: Roles and Race columns, both sortable.
UI.Open("roster"); Tick(1)
local roster
for _, o in ipairs(CREATED) do if o.rows and o.heads and o.search then roster = o end end
local function RosterRow(name)
    for _, r in ipairs(roster.rows) do if r:IsShown() and r.m and r.m.name == name then return r end end
end
local bluey = RosterRow("Bluey Heeler")
check(bluey and bluey.cells[2]:GetText():find("INV_Shield", 1, true) and not bluey.cells[3]:GetText():find("INV_Shield", 1, true)
    and bluey.cells[3]:GetText():find("Bluey Heeler", 1, true), "Roster: Bluey's tank icon in its own Roles column")
check(bluey.cells[6]:GetText():find("Orc", 1, true) and RosterRow("Chilli Heeler").cells[6]:GetText():find("Troll", 1, true),
    "Roster: Race column")
local rolesHead
for _, h in ipairs(roster.heads) do if h.key == "roles" then rolesHead = h end end
rolesHead._scripts.OnClick(rolesHead); Tick(1)
local first
for _, r in ipairs(roster.rows) do if r:IsShown() and r.m then first = r.m.name; break end end
check(first == "Bluey Heeler", "sorted by roles: the tank first", first)
rolesHead._scripts.OnClick(rolesHead); rolesHead._scripts.OnClick(rolesHead); Tick(1)
local raceHead
for _, h in ipairs(roster.heads) do if h.key == "race" then raceHead = h end end
raceHead._scripts.OnClick(raceHead); Tick(1)
local races = {}
for _, r in ipairs(roster.rows) do if r:IsShown() and r.m and r.m.online then races[#races + 1] = (r.cells[6]:GetText():gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")) end end
check(table.concat(races, ",") == "Orc,Orc,Orc,Troll", "sorted by race (online first)", table.concat(races, ","))

check(#ns.db.errors == 0, "no errors", ns.db.errors[1] and ns.db.errors[1].msg)
