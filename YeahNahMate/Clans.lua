-- Clans: the guild split by race. Each character is in the clan of its own race. Each clan has a
-- leader: whoever holds that clan's guild rank (the guild master or a manager links each clan to its
-- rank on the GM tab). Members pick their roles (Tank / Healer / DPS, up to two), shown by their name.
--
-- Where a guildie's race comes from: guildies with the addon say it in their HI (and saved, so they
-- keep it while offline); for the rest, the game's GetPlayerInfoByGUID on their roster GUID, when the
-- game knows it. Otherwise "race not known".
--
-- Messages
--   HI gets  ra = my race (the game's file name: "Orc", "Scourge", ...), ro = my roles ("", "t", "hd")
--   ME  { ra, ro }                                   my roles changed (GUILD)
--   BRD { k = "clr", cr = { [race] = rank index }, ev }   which guild rank leads each clan: the guild
--                                                    master or a manager; one slot, newest wins. A
--                                                    race left out = no rank linked.
local ADDON, ns = ...
local L = ns.L

local C = {}
ns.Clans = C

C.ROLES = { "t", "h", "d" }
C.MAX_ROLES = 2
local IS_ROLE = { t = true, h = true, d = true }
local SEND_GAP = 3                  -- role changes go out 3 s after the last click

-- Races in the order clans are listed (Horde first: the guild this was made for); any other race
-- the game names is listed after these.
C.ORDER = { "Orc", "Troll", "Tauren", "Scourge", "Skyborne", "BloodElf", "Goblin",
            "Human", "Dwarf", "NightElf", "Gnome", "Draenei", "Worgen" }
local ORDER_AT = {}
for i, r in ipairs(C.ORDER) do ORDER_AT[r] = i end

local function Changed() ns.Fire("CLANS") end

-- A race file name as it may travel: letters only, short.
function C.CleanRace(r)
    if type(r) ~= "string" then return nil end
    r = r:gsub("[^%a]", ""):sub(1, 20)
    return r ~= "" and r or nil
end

-- Roles as they may travel: t, h, d in that order, at most two, no repeats.
function C.CleanRoles(s)
    if type(s) ~= "string" then return "" end
    local out = ""
    for _, r in ipairs(C.ROLES) do
        if s:find(r, 1, true) and #out < C.MAX_ROLES then out = out .. r end
    end
    return out
end

function C.RaceName(r)
    return (r and L.RACE[r]) or r or L.CLAN_RACE_UNKNOWN
end

-- Saved per guild: people[name] = { ra, ro, at } from guildies' own messages.
function C.People()
    local g = ns.GuildData()
    if not g then return nil end
    if type(g.people) ~= "table" then g.people = {} end
    return g.people
end

local function MyChar()
    if type(ns.db.chars) ~= "table" then ns.db.chars = {} end
    if not ns.me then return {} end
    if type(ns.db.chars[ns.me]) ~= "table" then ns.db.chars[ns.me] = {} end
    return ns.db.chars[ns.me]
end

function C.MyRace()
    if not UnitRace then return nil end
    local _, file = UnitRace("player")
    return C.CleanRace(ns.Public(file, "string"))
end

function C.MyRoles() return C.CleanRoles(MyChar().roles) end

-- The game's own answer for a guildie's race, from their roster GUID (cached; the game may not know).
local guidRace = {}
local function FromGUID(guid)
    if not guid or not GetPlayerInfoByGUID then return nil end
    if guidRace[guid] then return guidRace[guid] end
    local ok, _, _, _, race = pcall(GetPlayerInfoByGUID, guid)
    race = ok and C.CleanRace(ns.Public(race, "string")) or nil
    if race then guidRace[guid] = race end
    return race
end

-- A guildie's race, or nil when not known.
function C.Race(name)
    if name == ns.me then return C.MyRace() end
    local m = ns.Guild.Get(name)
    if m and m.sim then return m.race end
    local p = C.People()
    local e = p and p[name]
    if e and e.ra then return e.ra end
    return m and FromGUID(m.guid) or nil
end

function C.Roles(name)
    if name == ns.me then return C.MyRoles() end
    local m = ns.Guild.Get(name)
    if m and m.sim then return m.roles or "" end
    local p = C.People()
    local e = p and p[name]
    return e and e.ro or ""
end

---------------------------------------------------------------------------------------------------
-- Leaders: one guild rank per clan (GM tab).

local function Board() return ns.Board.Store() end

function C.RankFor(race)
    local b = Board()
    local cr = b and b.clr and b.clr.cr
    return cr and race and cr[race] or nil
end

-- Which clan does this rank lead? (nil if none)
function C.RaceForRank(index)
    local b = Board()
    local cr = b and b.clr and b.clr.cr
    if not cr then return nil end
    for race, i in pairs(cr) do if i == index then return race end end
    return nil
end

-- The clan's leaders: everyone on its rank on my roster (normally one), by name. In sim mode a fake
-- guildie marked as a leader counts too, so the tab can be seen alone.
function C.Leaders(race)
    local rank = C.RankFor(race)
    local out = {}
    for _, m in ipairs(ns.Guild.list) do
        if (rank and not m.sim and m.rankIndex == rank) or (m.sim and m.simLeader and m.race == race) then
            out[#out + 1] = m.name
        end
    end
    table.sort(out)
    return out
end

function C.IsLeader(name, race)
    race = race or C.Race(name)
    if not race then return false end
    for _, n in ipairs(C.Leaders(race)) do if n == name then return true end end
    return false
end

---------------------------------------------------------------------------------------------------
-- The clans and their members.

local function Before(a, b)
    local ia, ib = ORDER_AT[a] or 99, ORDER_AT[b] or 99
    if ia ~= ib then return ia < ib end
    return a < b
end

-- Every clan with at least one member or a linked rank: { race, n, online, leaders }, in ORDER.
-- Also how many guildies' race isn't known.
function C.List()
    local by, unknown = {}, 0
    local function Clan(race)
        by[race] = by[race] or { race = race, n = 0, online = 0 }
        return by[race]
    end
    for _, m in ipairs(ns.Guild.list) do
        local race = C.Race(m.name)
        if race then
            local c = Clan(race)
            c.n = c.n + 1
            if m.online then c.online = c.online + 1 end
        else
            unknown = unknown + 1
        end
    end
    local b = Board()
    if b and b.clr and b.clr.cr then for race in pairs(b.clr.cr) do Clan(race) end end
    local list = {}
    for race, c in pairs(by) do
        c.leaders = C.Leaders(race)
        list[#list + 1] = c
    end
    table.sort(list, function(a, b2) return Before(a.race, b2.race) end)
    return list, unknown
end

-- A clan's members (roster entries): leaders first, then online, then by name.
function C.Members(race)
    local list = {}
    for _, m in ipairs(ns.Guild.list) do
        if C.Race(m.name) == race then list[#list + 1] = m end
    end
    local lead = {}
    for _, n in ipairs(C.Leaders(race)) do lead[n] = true end
    table.sort(list, function(a, b)
        if (lead[a.name] or false) ~= (lead[b.name] or false) then return lead[a.name] == true end
        if a.online ~= b.online then return a.online == true end
        return a.name < b.name
    end)
    return list
end

-- Guildies whose race isn't known (no addon, and the game didn't say).
function C.Unknown()
    local list = {}
    for _, m in ipairs(ns.Guild.list) do
        if not C.Race(m.name) then list[#list + 1] = m end
    end
    table.sort(list, function(a, b)
        if a.online ~= b.online then return a.online == true end
        return a.name < b.name
    end)
    return list
end

---------------------------------------------------------------------------------------------------
-- My roles

local sendTimer = nil
local function SendMine()
    sendTimer = nil
    ns.Comm.Send({ t = "ME", ra = C.MyRace(), ro = C.MyRoles() }, "GUILD")
end

-- Turn one role on or off (at most two: a third replaces the oldest pick).
function C.ToggleRole(r)
    if not IS_ROLE[r] then return end
    local c = MyChar()
    local cur = c.picks or C.MyRoles()
    if cur:find(r, 1, true) then
        cur = cur:gsub(r, "")
    else
        cur = cur .. r
        if #cur > C.MAX_ROLES then cur = cur:sub(-C.MAX_ROLES) end
    end
    c.picks = cur                                -- in the order picked (which one goes first)
    c.roles = C.CleanRoles(cur)
    if sendTimer then sendTimer:Cancel() end
    sendTimer = C_Timer.NewTimer(SEND_GAP, function() ns.Safe(SendMine) end)
    Changed()
end

function C.SetRoles(s)
    local c = MyChar()
    c.roles = C.CleanRoles(s)
    c.picks = c.roles
    if sendTimer then sendTimer:Cancel() end
    sendTimer = C_Timer.NewTimer(SEND_GAP, function() ns.Safe(SendMine) end)
    Changed()
end

---------------------------------------------------------------------------------------------------
-- Linking ranks (GM tab: the guild master and managers)

local function ClanRankMessage(c)
    local cr = {}
    for race, i in pairs(c.cr) do cr[race] = i end
    return { t = "BRD", k = "clr", cr = cr, ev = c.ev }
end

function C.CanLinkRanks() return ns.Board.CanManage() end

-- Link a clan to a rank (index), or unlink it (nil). A rank leads one clan at most.
function C.SetRank(race, index)
    race = C.CleanRace(race)
    local b = Board()
    if not race or not b or not C.CanLinkRanks() then return false end
    if index ~= nil and (type(index) ~= "number" or index < 1 or index > 9) then return false end
    local cr = {}
    if b.clr and b.clr.cr then for r, i in pairs(b.clr.cr) do cr[r] = i end end
    if index then for r, i in pairs(cr) do if i == index then cr[r] = nil end end end
    cr[race] = index
    b.clr = { cr = cr, by = ns.me, ev = math.max(GetServerTime(), ((b.clr and b.clr.ev) or 0) + 1), direct = true }
    ns.Board.Send(ClanRankMessage(b.clr))
    ns.Fire("BOARD")
    Changed()
    return true
end

ns.Board.kinds.clr = {
    take = function(author, msg, direct)
        local b = Board()
        if not b then return false end
        if not ns.Board.IsManager(author) then
            ns.Log("dropped: clan ranks from " .. author .. ", who isn't the guild master or a manager")
            return false
        end
        if type(msg.cr) ~= "table" then return false end
        if b.clr and not ns.Newer(b.clr.ev, b.clr.direct, msg.ev, direct, true) then return false end
        local cr, used, n = {}, {}, 0
        for race, i in pairs(msg.cr) do
            race = C.CleanRace(race)
            if race and type(i) == "number" and i >= 1 and i <= 9 and i == math.floor(i) and not used[i] and n < 20 then
                cr[race], used[i], n = i, true, n + 1
            end
        end
        b.clr = { cr = cr, by = author, ev = msg.ev, direct = direct or nil }
        ns.Safe(Changed)
        return true
    end,
    all = function(add)
        local b = Board()
        if b and b.clr and b.clr.by then add(ClanRankMessage(b.clr), b.clr.by) end
    end,
    evs = function(author, list)
        local b = Board()
        if b and b.clr and b.clr.by == author then list[#list + 1] = b.clr.ev end
    end,
}

-- Catching up: every hello carries the version of the clan ranks I hold (crv). Someone who logged in
-- in the last 3 minutes and hears a newer one asks that guildie for the board (once). Older versions
-- send no crv and are left alone.
local loginAt, askedRanks = nil, false
ns.Listen("LOGIN", function() loginAt, askedRanks = GetTime(), false end)
local function RankVersion()
    local b = Board()
    return (b and b.clr and type(b.clr.ev) == "number") and b.clr.ev or 0
end

---------------------------------------------------------------------------------------------------
-- Receiving

local function Take(from, ra, ro)
    local p = C.People()
    if not p or from == ns.me or not ns.Guild.IsMember(from) then return end
    ra = C.CleanRace(ra)
    ro = C.CleanRoles(ro)
    local e = p[from]
    if e and e.ra == (ra or e.ra) and e.ro == ro then e.at = GetServerTime() return end
    p[from] = { ra = ra or (e and e.ra), ro = ro, at = GetServerTime() }
    Changed()
end

ns.Comm.On("ME", function(msg, from, channel, isSelf)
    if isSelf then return end
    Take(from, msg.ra, msg.ro)
end)
ns.Listen("HI_IN", function(msg, from)
    if type(msg.crv) == "number" and msg.crv > RankVersion() and not askedRanks and loginAt
        and GetTime() - loginAt < 180 and not (ns.Sim and ns.Sim.IsFake(from)) then
        askedRanks = true
        C_Timer.After(5, function() if msg.crv > RankVersion() then ns.Safe(ns.Board.Ask, from) end end)
    end
    -- Older versions say nothing about race or roles: keep what we hold.
    if msg.ra == nil and msg.ro == nil then return end
    Take(from, msg.ra, msg.ro)
end)
ns.Listen("HI_OUT", function(msg)
    msg.ra = C.MyRace()
    msg.ro = C.MyRoles()
    msg.crv = RankVersion()
end)

-- Departed guildies go after a full roster read.
ns.Listen("ROSTER", function()
    local p = C.People()
    if not p or not ns.Guild.complete then return end
    local gone = false
    for name in pairs(p) do
        if not ns.Guild.IsMember(name) then p[name] = nil; gone = true end
    end
    if gone then Changed() end
end)
