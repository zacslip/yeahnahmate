-- Roster data for the UI: the game's guild roster joined with who has the addon (Comm.users).
-- Later phases add status and position from addon messages here.
local ADDON, ns = ...

local Roster = {}
ns.Roster = Roster

Roster.ONLINE, Roster.NEAR, Roster.ZONE, Roster.ALL = 1, 2, 3, 4

function Roster.MyLevel() return UnitLevel("player") or 1 end
function Roster.MyZone()
    local z = GetRealZoneText and GetRealZoneText() or GetZoneText()
    return z or ""
end
-- "Near my level" = within 3 levels (fixed; there used to be a setting).
Roster.NEAR_LEVELS = 3
function Roster.Range() return Roster.NEAR_LEVELS end

-- Is this member online and within the "near my level" range (not counting me)?
function Roster.IsNear(m, me)
    if not m.online or m.name == ns.me then return false end
    return math.abs(m.level - (me or Roster.MyLevel())) <= Roster.Range()
end

function Roster.HasAddon(m) return ns.Comm.users[m.name] ~= nil end

-- Hidden in sim's screenshot mode (real guildmates); everyone shows otherwise.
local function Hidden(m) return ns.Sim and ns.Sim.Hides(m) end

-- What each sortable column sorts by. Offline members have no zone to sort by.
local SORT_VALUE = {
    name  = function(m) return strlower(m.name) end,
    level = function(m) return m.level end,
    class = function(m) return strlower(ns.ClassName(m.class)) end,
    zone  = function(m) return m.online and strlower(m.zone) or "~" end,
    rank  = function(m) return m.rankIndex end,
    status = function(m) local t = ns.Status.Text(m); return t == "" and "~" or strlower(t) end,
    addon = function(m) return Roster.HasAddon(m) and 0 or 1 end,
}
Roster.SORTS = SORT_VALUE

-- Members for one filter. Online first always; then by the chosen column (desc = reversed), or by
-- default the closest level; ties by name. A search (part of a name) looks through every member,
-- whatever the filter: someone looking for a guildie by name wants them online or not.
function Roster.Get(filter, sortKey, desc, query)
    local me, zone = Roster.MyLevel(), Roster.MyZone()
    query = query and strlower(strtrim(query)) or ""
    local list = {}
    for _, m in ipairs(ns.Guild.list) do
        local keep
        if Hidden(m) then keep = false
        elseif query ~= "" then keep = strfind(strlower(m.name), query, 1, true) ~= nil
        elseif filter == Roster.ONLINE then keep = m.online
        elseif filter == Roster.NEAR then keep = Roster.IsNear(m, me)
        elseif filter == Roster.ZONE then keep = m.online and m.zone == zone and m.name ~= ns.me
        else keep = true end
        if keep then list[#list + 1] = m end
    end
    local value = sortKey and SORT_VALUE[sortKey]
    table.sort(list, function(a, b)
        if a.online ~= b.online then return a.online end
        if value then
            local va, vb = value(a), value(b)
            if va ~= vb then
                if desc then return va > vb end
                return va < vb
            end
        else
            local da, db = math.abs(a.level - me), math.abs(b.level - me)
            if da ~= db then return da < db end
        end
        return a.name < b.name
    end)
    return list
end

-- Counts for the Home tab.
function Roster.Stats()
    local me, zone = Roster.MyLevel(), Roster.MyZone()
    local s = { online = 0, onlineAddon = 0, near = 0, nearZone = 0, users = 0, usersOnline = 0 }
    for _, m in ipairs(ns.Guild.list) do
        local addon = Roster.HasAddon(m)
        if m.name ~= ns.me and not Hidden(m) then
            if m.online then
                s.online = s.online + 1
                if addon then s.onlineAddon = s.onlineAddon + 1 end
            end
            if addon then
                s.users = s.users + 1
                if m.online then s.usersOnline = s.usersOnline + 1 end
            end
            if Roster.IsNear(m, me) then
                s.near = s.near + 1
                if m.zone == zone then s.nearZone = s.nearZone + 1 end
            end
        end
    end
    return s
end

-- Online guildies near me: in my zone or near my level. Ones with a dot nearby first (closest
-- first), then the rest of my zone, then by level. Returns the list and a name -> yards table.
function Roster.NearMe()
    local me, zone = Roster.MyLevel(), Roster.MyZone()
    local list, dist = {}, {}
    for _, m in ipairs(ns.Guild.list) do
        if m.online and m.name ~= ns.me and not Hidden(m) and (Roster.IsNear(m, me) or m.zone == zone) then
            list[#list + 1] = m
            dist[m.name] = ns.Map and ns.Map.Distance(m.name) or nil
        end
    end
    table.sort(list, function(a, b)
        local da, db = dist[a.name], dist[b.name]
        if (da ~= nil) ~= (db ~= nil) then return da ~= nil end
        if da and db and da ~= db then return da < db end
        local az, bz = a.zone == zone, b.zone == zone
        if az ~= bz then return az end
        local la, lb = math.abs(a.level - me), math.abs(b.level - me)
        if la ~= lb then return la < lb end
        return a.name < b.name
    end)
    return list, dist
end
