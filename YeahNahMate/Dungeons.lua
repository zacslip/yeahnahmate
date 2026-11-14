-- Dungeons: guild groups (post, sign up, the leader invites) and "I'm available" (roles, dungeons,
-- for how long). Nothing here invites, joins or whispers by itself: the leader clicks Invite, the
-- player clicks Sign up (no automation: CONTRIBUTING.md, Rules).
--
-- Messages
--   GRP  { id, d, me, nt, nh, nd, ht, hh, hd, note, u }  my group: dungeon, my role, how many tanks/
--                                                        healers/DPS wanted (n*) and in it (h*),
--                                                        note, expiry (server time). GUILD, or
--                                                        WHISPER to a guildie who just logged in.
--   GRP  { id, x = true }                                my group is closed
--   SIGN { id, r }  /  { id, x = true }                  sign up as t/h/d, or cancel (WHISPER to leader)
--   ANS  { id, a = "x" }                                 the leader said not this time (WHISPER)
--   AVL  { r, ds, u, note }  /  { x = true }             I'm available: roles "thd", dungeon keys,
--                                                        until (server time), note; or not any more
--   DMX  { o = owner, g = id } / { o = owner, a = true }  a Dungeons moderator closes someone's group
--                                                        or takes down their "I'm available" (GUILD)
-- Only the owner's own messages change their group or availability (sender from the game), and a
-- Dungeons moderator (Board.lua) can close a group or take a listing down. Both end
-- when the time runs out or the roster says the owner went offline.
local ADDON, ns = ...
local L = ns.L

local D = {}
ns.Dungeons = D

-- WoW Forever's dungeons: key, name, suggested levels. Forever is NOT Classic Era: it launched
-- (4 Nov 2026) with 35 dungeons, the Classic ones plus 9 new ones (marked "Forever"). The new ones
-- were checked against the game's own LFGDungeons/Map tables (Hall of Thanes, Ruins of Lordaeron,
-- Excavation Site, City of Dalaran are in the Dungeon Finder; the other five are in the files
-- unnamed) and the published level ranges. Keys never change: they travel in messages.
D.LIST = {
    { "hot", "Hall of Thanes", 13, 18 },                -- Forever: beneath Ironforge
    { "rfc", "Ragefire Chasm", 13, 18 },
    { "rol", "Ruins of Lordaeron", 15, 20 },            -- Forever: above the Undercity
    { "wc", "Wailing Caverns", 17, 24 }, { "dm", "The Deadmines", 17, 26 },
    { "sfk", "Shadowfang Keep", 22, 30 }, { "bfd", "Blackfathom Deeps", 24, 32 }, { "stocks", "The Stockade", 24, 32 },
    { "exc", "Excavation Site: Wetlands", 26, 31 },     -- Forever: above Whelgar's Excavation
    { "smgy", "SM: Graveyard", 26, 36 },
    { "dal", "City of Dalaran", 28, 33 },               -- Forever: Alterac Mountains (attunement quest)
    { "gnomer", "Gnomeregan", 29, 38 }, { "rfk", "Razorfen Kraul", 29, 38 },
    { "smlib", "SM: Library", 29, 39 }, { "smarm", "SM: Armory", 32, 42 },
    { "drown", "The Drowned City", 35, 40 },            -- Forever: off the Stranglethorn coast
    { "smcath", "SM: Cathedral", 35, 45 },
    { "rfd", "Razorfen Downs", 37, 46 },
    { "krol", "Krol'dok Stronghold", 40, 45 },          -- Forever: Riverglades
    { "ulda", "Uldaman", 41, 51 }, { "zf", "Zul'Farrak", 42, 50 },
    { "mara", "Maraudon", 46, 55 },
    { "alcaz", "Alcaz Prison", 48, 53 },                -- Forever: Alcaz Island, Dustwallow Marsh
    { "st", "Sunken Temple", 50, 56 }, { "brd", "Blackrock Depths", 52, 60 },
    { "lbrs", "Lower Blackrock Spire", 55, 60 }, { "dme", "Dire Maul East", 55, 60 },
    { "blackmaw", "Blackmaw Hold", 55, 60 },            -- Forever: behind the gate in Azshara
    { "dmw", "Dire Maul West", 57, 60 }, { "dmn", "Dire Maul North", 57, 60 }, { "scholo", "Scholomance", 58, 60 },
    { "strat", "Stratholme: Main Gate", 58, 60 }, { "stratsg", "Stratholme: Service Gate", 58, 60 },
    { "shaper", "Shaper's Terrace", 58, 60 },           -- Forever: Un'Goro Crater
    { "ubrs", "Upper Blackrock Spire", 58, 60 },
}
D.BY_KEY = {}
for _, d in ipairs(D.LIST) do D.BY_KEY[d[1]] = { key = d[1], name = d[2], min = d[3], max = d[4] } end

D.ROLES = { t = true, h = true, d = true }
D.GROUP_TIME = 7200             -- a group lasts 2 hours
D.FOR = { 3600, 7200, 14400 }   -- available for 1 hour, 2 hours, tonight (4 hours)
local MAX_NOTE = 60
local MAX_DS = 10

D.groups = {}                   -- "owner:id" -> group (others' and mine)
D.avail = {}                    -- owner -> { r = { t, h, d }, ds = { keys }, u, note }

function D.Name(key) local d = D.BY_KEY[key]; return d and d.name or tostring(key) end

-- Dungeons sorted by how close they are to a level (fits first, then nearest).
function D.ForLevel(level)
    local list = {}
    for _, d in ipairs(D.LIST) do
        local dist = (level < d[3]) and (d[3] - level) or (level > d[4]) and (level - d[4]) or 0
        list[#list + 1] = { key = d[1], name = d[2], min = d[3], max = d[4], dist = dist }
    end
    table.sort(list, function(a, b)
        if a.dist ~= b.dist then return a.dist < b.dist end
        return a.min < b.min
    end)
    return list
end

-- Every dungeon in level order (the picker must read lowest to highest), each with its
-- distance from my level (0 = fits). Also the index of the first one that fits, to scroll to.
function D.ByLevel(level)
    local list, first = {}, nil
    for i, d in ipairs(D.LIST) do
        local dist = (level < d[3]) and (d[3] - level) or (level > d[4]) and (level - d[4]) or 0
        list[i] = { key = d[1], name = d[2], min = d[3], max = d[4], dist = dist }
        if dist == 0 and not first then first = i end
    end
    return list, first
end

-- Is this dungeon right for my level? (Inside its range, or a couple of levels under.)
function D.AtMyLevel(key)
    local d = D.BY_KEY[key]
    if not d then return false end
    local me = UnitLevel("player") or 1
    return me >= d.min - 2 and me <= d.max
end

local function Clean(s, max) return type(s) == "string" and s:gsub("[|\n\r]", ""):sub(1, max) or "" end
local function Count(n, max) n = tonumber(n); if not n then return 0 end return math.max(0, math.min(max, math.floor(n))) end
local function RoleSet(s)
    local r = {}
    if type(s) == "string" then for c in s:gmatch("[thd]") do r[c] = true end end
    return r
end
local function RoleString(r) return (r.t and "t" or "") .. (r.h and "h" or "") .. (r.d and "d" or "") end
D.RoleSet, D.RoleString = RoleSet, RoleString

---------------------------------------------------------------------------------------------------
-- My own group and availability (kept per character, so a /reload doesn't drop them).

local function Mine()
    local chars = ns.db.chars
    if type(chars) ~= "table" then chars = {}; ns.db.chars = chars end
    local c = chars[ns.me or "?"]
    if type(c) ~= "table" then c = {}; chars[ns.me or "?"] = c end
    return c
end
D.Mine = Mine

function D.MyGroup()
    local g = Mine().group
    if g and g.u and g.u <= GetServerTime() then Mine().group = nil; return nil end
    return g
end

function D.MyAvail()
    local a = Mine().avail
    if a and a.u and a.u <= GetServerTime() then Mine().avail = nil; return nil end
    return a
end

-- Party members by key, plus fake guildies who "joined" in sim mode.
local function PartyKeys()
    local keys = {}
    for i = 1, 4 do
        local k = ns.UnitKey("party" .. i)
        if k then keys[k] = true end
    end
    if ns.Sim and ns.Sim.Joined then for k in pairs(ns.Sim.Joined()) do keys[k] = true end end
    return keys
end

-- Who's in my group (me plus applicants who joined my party), counted by role.
local function Have(g)
    local h = { t = 0, h = 0, d = 0 }
    h[g.me] = h[g.me] + 1
    local party = PartyKeys()
    for name, a in pairs(g.apps or {}) do
        a.joined = party[name] or nil
        if a.joined then h[a.r] = h[a.r] + 1 end
    end
    return h
end

local function GroupMessage(g)
    local h = Have(g)
    return { t = "GRP", id = g.id, d = g.d, me = g.me, nt = g.nt, nh = g.nh, nd = g.nd,
             ht = h.t, hh = h.h, hd = h.d, note = g.note, u = g.u }
end

local function AvailMessage(a)
    return { t = "AVL", r = RoleString(a.r), ds = a.ds, u = a.u, note = a.note }
end

-- Put my own group / availability into the shared tables too, so the lists show them.
local function ShowMine()
    for k, g in pairs(D.groups) do if g.owner == ns.me then D.groups[k] = nil end end
    local g = D.MyGroup()
    if g then
        local m = GroupMessage(g)
        D.groups[ns.me .. ":" .. g.id] = { owner = ns.me, id = g.id, d = g.d, me = g.me, nt = g.nt, nh = g.nh, nd = g.nd,
            ht = m.ht, hh = m.hh, hd = m.hd, note = g.note, u = g.u, at = g.at, mine = true }
    end
    local a = D.MyAvail()
    D.avail[ns.me or "?"] = a and { r = a.r, ds = a.ds, u = a.u, note = a.note, mine = true } or nil
end

local function Changed()
    ShowMine()
    ns.Fire("DUNGEONS")
end

local sendTimer = nil
local function SendGroupSoon()
    if sendTimer then return end
    sendTimer = C_Timer.NewTimer(3, function()
        sendTimer = nil
        local g = D.MyGroup()
        if g then ns.Comm.Send(GroupMessage(g), "GUILD") end
    end)
end

-- Post a group. need = { t, h, d } counts wanted including nobody yet; me = my role.
function D.Post(key, me, need, note)
    if not D.BY_KEY[key] or not D.ROLES[me] then return false end
    local now = GetServerTime()
    Mine().group = { id = now, d = key, me = me, nt = Count(need.t, 2), nh = Count(need.h, 2), nd = Count(need.d, 4),
                     note = Clean(note, MAX_NOTE), u = now + D.GROUP_TIME, at = now, apps = {} }
    local g = Mine().group
    g["n" .. me] = math.max(1, g["n" .. me])          -- the leader is in it
    ns.Comm.Send(GroupMessage(g), "GUILD")
    Changed()
    return true
end

-- Change how many of each role I still want (the leader's +/- buttons).
function D.SetNeed(role, n)
    local g = D.MyGroup()
    if not g or not D.ROLES[role] then return end
    local max = (role == "d") and 4 or 2
    -- The leader is in the group: their own role is at least 1.
    g["n" .. role] = math.max(role == g.me and 1 or 0, Count(n, max))
    SendGroupSoon()
    Changed()
end

function D.Close()
    local g = D.MyGroup()
    if not g then return end
    Mine().group = nil
    ns.Comm.Send({ t = "GRP", id = g.id, x = true }, "GUILD")
    Changed()
end

-- The leader says no to an applicant: they're told, and dropped from my list.
function D.Decline(name)
    local g = D.MyGroup()
    if not g or not g.apps or not g.apps[name] then return end
    g.apps[name] = nil
    ns.Comm.Send({ t = "ANS", id = g.id, a = "x" }, "WHISPER", name)
    Changed()
end

-- Applicants for my group, oldest first.
function D.Applicants()
    local g = D.MyGroup()
    local list = {}
    if not g then return list end
    Have(g)
    for name, a in pairs(g.apps or {}) do list[#list + 1] = { name = name, r = a.r, at = a.at, joined = a.joined } end
    table.sort(list, function(a, b) if a.at ~= b.at then return a.at < b.at end return a.name < b.name end)
    return list
end

-- Sign up for someone's group (whisper to the leader), or cancel.
D.signed = {}                   -- "owner:id" -> role I signed up as; or "x" if the leader said no
function D.SignUp(key, role)
    local g = D.groups[key]
    if not g or g.mine or not D.ROLES[role] then return end
    D.signed[key] = role
    ns.Comm.Send({ t = "SIGN", id = g.id, r = role }, "WHISPER", g.owner)
    ns.Fire("DUNGEONS")
end
function D.CancelSign(key)
    local g = D.groups[key]
    if not g or not D.signed[key] then return end
    D.signed[key] = nil
    ns.Comm.Send({ t = "SIGN", id = g.id, x = true }, "WHISPER", g.owner)
    ns.Fire("DUNGEONS")
end

-- Mark myself available: roles { t, h, d }, dungeon keys, seconds, note.
function D.SetAvailable(roles, ds, seconds, note)
    local r = { t = roles.t or nil, h = roles.h or nil, d = roles.d or nil }
    local list = {}
    for _, k in ipairs(ds) do if D.BY_KEY[k] and #list < MAX_DS then list[#list + 1] = k end end
    if not next(r) or #list == 0 then return false end
    Mine().avail = { r = r, ds = list, u = GetServerTime() + seconds, note = Clean(note, MAX_NOTE) }
    ns.Comm.Send(AvailMessage(Mine().avail), "GUILD")
    Changed()
    return true
end

function D.StopAvailable()
    if not Mine().avail then return end
    Mine().avail = nil
    ns.Comm.Send({ t = "AVL", x = true }, "GUILD")
    Changed()
end

---------------------------------------------------------------------------------------------------
-- Moderators: close someone's group, take down someone's "I'm available".

D.modGone = {}                  -- "owner:id" -> true: a group a moderator closed (its updates ignored)
D.modAvail = {}                 -- owner -> the until-time of the listing a moderator took down

function D.CanRemove() return ns.Board and ns.Board.Moderates("dun") or false end
local function RealMod() return ns.Board.CanModerate(ns.me, "dun") end

function D.ModClose(key)
    local g = D.groups[key]
    if not g or g.mine or not D.CanRemove() then return false end
    D.groups[key], D.signed[key], D.modGone[key] = nil, nil, true
    if RealMod() then ns.Comm.Send({ t = "DMX", o = g.owner, g = g.id }, "GUILD") end
    ns.Fire("DUNGEONS")
    return true
end

function D.ModUnavail(name)
    local a = D.avail[name]
    if not a or a.mine or not D.CanRemove() then return false end
    D.avail[name], D.modAvail[name] = nil, a.su or a.u
    if RealMod() then ns.Comm.Send({ t = "DMX", o = name, a = true }, "GUILD") end
    ns.Fire("DUNGEONS")
    return true
end

---------------------------------------------------------------------------------------------------
-- Lists for the tab

-- Open groups: mine first, then ones at my level, then newest.
function D.Groups()
    local list = {}
    local now = GetServerTime()
    for key, g in pairs(D.groups) do
        if g.u > now then g.key = key; list[#list + 1] = g end
    end
    table.sort(list, function(a, b)
        if (a.mine or false) ~= (b.mine or false) then return a.mine or false end
        local am, bm = D.AtMyLevel(a.d), D.AtMyLevel(b.d)
        if am ~= bm then return am end
        return (a.at or 0) > (b.at or 0)
    end)
    return list
end

-- Available guildies: me first, then by how close their dungeons are to my level, then name.
function D.Available()
    local list = {}
    local now = GetServerTime()
    for name, a in pairs(D.avail) do
        if a.u > now then list[#list + 1] = { name = name, a = a } end
    end
    table.sort(list, function(x, y)
        if (x.a.mine or false) ~= (y.a.mine or false) then return x.a.mine or false end
        return x.name < y.name
    end)
    return list
end

function D.CountAtMyLevel()
    local n = 0
    for _, g in ipairs(D.Groups()) do if not g.mine and D.AtMyLevel(g.d) then n = n + 1 end end
    return n
end

---------------------------------------------------------------------------------------------------
-- Receiving

ns.Comm.On("GRP", function(msg, from, channel, isSelf)
    if isSelf then return end
    if type(msg.id) ~= "number" then return end
    local key = from .. ":" .. msg.id
    if msg.x == true then
        if D.groups[key] then D.groups[key] = nil; D.signed[key] = nil; ns.Fire("DUNGEONS") end
        return
    end
    if D.modGone[key] then return end       -- a moderator closed it
    if not D.BY_KEY[msg.d] or not D.ROLES[msg.me] or type(msg.u) ~= "number" then
        ns.Log("dropped: bad group from " .. from)
        return
    end
    -- One open group per leader: a new one replaces the old.
    for k, g in pairs(D.groups) do if g.owner == from and k ~= key then D.groups[k] = nil end end
    local now = GetServerTime()
    local u = math.min(msg.u, now + D.GROUP_TIME)          -- nobody posts for longer than 2 hours
    local isNew = D.groups[key] == nil
    D.groups[key] = { owner = from, id = msg.id, d = msg.d, me = msg.me,
        nt = Count(msg.nt, 2), nh = Count(msg.nh, 2), nd = Count(msg.nd, 4),
        ht = Count(msg.ht, 2), hh = Count(msg.hh, 2), hd = Count(msg.hd, 5),
        note = Clean(msg.note, MAX_NOTE), u = u, at = D.groups[key] and D.groups[key].at or now }
    ns.Fire("DUNGEONS")
    if isNew then ns.Fire("GROUP_POSTED", D.groups[key]) end
end)

ns.Comm.On("SIGN", function(msg, from, channel, isSelf)
    if isSelf or channel ~= "WHISPER" then return end
    local g = D.MyGroup()
    if not g or msg.id ~= g.id then return end
    g.apps = g.apps or {}
    if msg.x == true then
        g.apps[from] = nil
    elseif D.ROLES[msg.r] then
        local count = 0
        for _ in pairs(g.apps) do count = count + 1 end
        if count >= 20 and not g.apps[from] then return end
        local isNew = g.apps[from] == nil
        g.apps[from] = { r = msg.r, at = GetServerTime() }
        if isNew then ns.Fire("SIGNED_UP", from, msg.r, g) end
    end
    Changed()
end)

ns.Comm.On("ANS", function(msg, from, channel, isSelf)
    if isSelf or channel ~= "WHISPER" or type(msg.id) ~= "number" then return end
    local key = from .. ":" .. msg.id
    if msg.a == "x" and D.signed[key] then
        D.signed[key] = "x"
        ns.Fire("DUNGEONS")
    end
end)

ns.Comm.On("AVL", function(msg, from, channel, isSelf)
    if isSelf then return end
    if msg.x == true then
        if D.avail[from] then D.avail[from] = nil; ns.Fire("DUNGEONS") end
        return
    end
    local r = RoleSet(msg.r)
    local ds = {}
    if type(msg.ds) == "table" then
        for i = 1, math.min(#msg.ds, MAX_DS) do if D.BY_KEY[msg.ds[i]] then ds[#ds + 1] = msg.ds[i] end end
    end
    if not next(r) or #ds == 0 or type(msg.u) ~= "number" then
        ns.Log("dropped: bad availability from " .. from)
        return
    end
    if D.modAvail[from] and D.modAvail[from] == msg.u then return end   -- the listing a moderator took down
    local now = GetServerTime()
    D.avail[from] = { r = r, ds = ds, u = math.min(msg.u, now + 14400), su = msg.u, note = Clean(msg.note, MAX_NOTE) }
    ns.Fire("DUNGEONS")
end)

-- A Dungeons moderator closed a group or took a listing down. It can be mine: then it ends for me.
ns.Comm.On("DMX", function(msg, from, channel, isSelf)
    if isSelf or channel ~= "GUILD" then return end
    if not ns.Board.CanModerate(from, "dun") then
        ns.Log("dropped: a dungeon removal from " .. from .. ", who doesn't moderate Dungeons")
        return
    end
    local owner = type(msg.o) == "string" and ns.Key(msg.o) or nil
    if not owner or owner == from then return end
    if owner == ns.me then
        local g = D.MyGroup()
        if type(msg.g) == "number" and g and g.id == msg.g then
            Mine().group = nil
            ns.Print(string.format(L.DUN_CLOSED_MINE, from))
        elseif msg.a == true and D.MyAvail() then
            Mine().avail = nil
            ns.Print(string.format(L.DUN_UNLISTED_MINE, from))
        else
            return
        end
        Changed()
        return
    end
    if type(msg.g) == "number" then
        local key = owner .. ":" .. msg.g
        D.modGone[key] = true
        if D.groups[key] then D.groups[key] = nil; D.signed[key] = nil end
    elseif msg.a == true then
        local a = D.avail[owner]
        if a then D.modAvail[owner] = a.su or a.u; D.avail[owner] = nil end
    end
    ns.Fire("DUNGEONS")
end)

---------------------------------------------------------------------------------------------------
-- Upkeep: expiry, owners going offline, guildies logging in, my party changing.

local function Expire()
    local now = GetServerTime()
    local changed = false
    for key, g in pairs(D.groups) do
        local m = ns.Guild.Get(g.owner)
        if not g.mine and (g.u <= now or not m or not m.online) then
            D.groups[key] = nil; D.signed[key] = nil; changed = true
        end
    end
    for name, a in pairs(D.avail) do
        local m = ns.Guild.Get(name)
        if not a.mine and (a.u <= now or not m or not m.online) then D.avail[name] = nil; changed = true end
    end
    -- My own ran out.
    if Mine().group and not D.MyGroup() then changed = true end
    if Mine().avail and not D.MyAvail() then changed = true end
    if changed then Changed() end
end
ns.Listen("ROSTER", function() ns.Safe(Expire) end)

-- A guildie just logged in (their hello asks who has the addon): whisper them my group and availability.
ns.Listen("HI_IN", function(msg, from)
    if msg.ask ~= true or (ns.Sim and ns.Sim.IsFake(from)) then return end
    C_Timer.After(2 + math.random() * 4, function()
        local g = D.MyGroup()
        if g then ns.Comm.Send(GroupMessage(g), "WHISPER", from) end
        local a = D.MyAvail()
        if a then ns.Comm.Send(AvailMessage(a), "WHISPER", from) end
    end)
end)

-- My party changed: applicants who joined count as filled, and the guild hears the new numbers.
function D.Recount()
    local g = D.MyGroup()
    if not g then return end
    local before = (g._ht or 0) .. (g._hh or 0) .. (g._hd or 0)
    local h = Have(g)
    g._ht, g._hh, g._hd = h.t, h.h, h.d
    if before ~= (h.t .. h.h .. h.d) then SendGroupSoon(); Changed() end
end
ns.OnEvent("GROUP_ROSTER_UPDATE", D.Recount)

ns.Listen("LOGIN", function()
    -- After our hello: my group and availability from before a /reload go out again.
    C_Timer.After(12, function()
        ns.Safe(function()
            local g, a = D.MyGroup(), D.MyAvail()
            if g then ns.Comm.Send(GroupMessage(g), "GUILD") end
            if a then ns.Comm.Send(AvailMessage(a), "GUILD") end
            Changed()
        end)
    end)
    C_Timer.NewTicker(15, function() ns.Safe(Expire) end)
end)
