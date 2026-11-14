-- Status: my level, zone and what I'm up to (in a dungeon, in a group, in town), shared with
-- guildmates who have the addon. The game's roster has level and zone too, but only refreshes every
-- minute or so; ST arrives the moment something changes. Nothing here is private: guildmates see
-- level and zone in the game's own guild list. Position is separate (Map.lua) and asked first.
--
-- ST = { l = level, z = zone, st = "i" | "g" | "r" | "t" | "", n = group size }
--   i in an instance, g in a group, r in a raid, t resting in town. Codes, not text, so each player
--   reads them in their own language.
local ADDON, ns = ...
local L = ns.L

local Status = {}
ns.Status = Status

local FRESH = 300               -- an ST counts over the roster's values for 5 minutes
local GAP = 30                  -- at most one ST every 30 s
local CODES = { i = true, g = true, r = true, t = true, [""] = true }

Status.extra = {}               -- name -> { l, z, st, n, at }

function Status.Mine()
    local zone = ns.Roster.MyZone()
    local st, n = "", nil
    local inInstance = IsInInstance()
    if inInstance then
        st = "i"
    elseif IsInRaid and IsInRaid() then
        st, n = "r", GetNumGroupMembers and GetNumGroupMembers() or nil
    elseif IsInGroup and IsInGroup() then
        st, n = "g", GetNumGroupMembers and GetNumGroupMembers() or nil
    elseif IsResting and IsResting() then
        st = "t"
    end
    return { l = UnitLevel("player") or 0, z = zone:sub(1, 60), st = st, n = n }
end

-- Put a guildie's latest status onto their roster entry (called by Guild.Scan for every member).
function Status.Apply(m)
    local e = Status.extra[m.name]
    if not e or not m.online or GetTime() - e.at > FRESH then
        m.st, m.stn = nil, nil
        return
    end
    if e.l then m.level = e.l end
    if e.z and e.z ~= "" then m.zone = e.z end
    m.st, m.stn = e.st, e.n
end

-- The status words for a roster entry: from ST, else the game's away/busy flag.
function Status.Text(m)
    if not m.online then return "" end
    local s = ""
    if m.st == "i" then s = L.ST_INSTANCE
    elseif m.st == "g" and m.stn then s = string.format(L.ST_GROUP, m.stn)
    elseif m.st == "r" and m.stn then s = string.format(L.ST_RAID, m.stn)
    elseif m.st == "t" then s = L.ST_TOWN end
    if m.status == 1 then s = (s ~= "" and (s .. ", ") or "") .. L.AWAY
    elseif m.status == 2 then s = (s ~= "" and (s .. ", ") or "") .. L.BUSY end
    return s
end

-- A status from a guildie (in ST, or riding along in their HI). Odd values are ignored.
local function Take(from, msg)
    local l, z, st, n = msg.l, msg.z, msg.st, msg.n
    if type(l) ~= "number" or l < 1 or l > 100 then return end
    if type(z) ~= "string" then z = "" end
    if type(st) ~= "string" or not CODES[st] then st = "" end
    if type(n) ~= "number" or n < 1 or n > 40 then n = nil end
    Status.extra[from] = { l = math.floor(l), z = z:sub(1, 60), st = st, n = n and math.floor(n), at = GetTime() }
    local m = ns.Guild.Get(from)
    if m then Status.Apply(m) end
    ns.Fire("STATUS", from)
end
Status.Take = Take

ns.Comm.On("ST", function(msg, from, channel, isSelf)
    if isSelf then return end
    Take(from, msg)
end)
ns.Listen("HI_IN", function(msg, from) Take(from, msg) end)
ns.Listen("HI_OUT", function(msg)
    local s = Status.Mine()
    msg.l, msg.z, msg.st, msg.n = s.l, s.z, s.st, s.n
end)

---------------------------------------------------------------------------------------------------
-- Sending: when something changes, at most every 30 s, and only if a guildmate with the addon is
-- online to hear it (anyone who logs in later gets it in our HI reply).

local lastSent, lastAt, pending = nil, -1000, false
local ready = false             -- after our HI has gone out

local function Same(a, b)
    return a and b and a.l == b.l and a.z == b.z and a.st == b.st and a.n == b.n
end

local function SendNow()
    pending = false
    if not ready or not IsInGuild() then return end
    if ns.Comm.OthersOnline() == 0 and not (ns.Sim and ns.Sim.IsOn()) then return end
    local s = Status.Mine()
    if Same(s, lastSent) then return end
    s.t = "ST"
    if ns.Comm.Send(s, "GUILD") then
        lastSent, lastAt = s, GetTime()
    end
end

function Status.Changed()
    if pending then return end
    local wait = GAP - (GetTime() - lastAt)
    if wait <= 0 then
        SendNow()
    else
        pending = true
        C_Timer.After(wait, function() ns.Safe(SendNow) end)
    end
end

for _, e in ipairs({ "PLAYER_LEVEL_UP", "ZONE_CHANGED_NEW_AREA", "GROUP_ROSTER_UPDATE",
                     "PLAYER_UPDATE_RESTING", "PLAYER_ENTERING_WORLD" }) do
    ns.OnEvent(e, function() if ready then C_Timer.After(1, function() ns.Safe(Status.Changed) end) end end)
end

-- Our HI already carried our status; from then on, changes go out as ST.
ns.Listen("SENT", function(msg, channel)
    if msg.t == "HI" and channel == "GUILD" then
        ready = true
        lastSent, lastAt = Status.Mine(), GetTime()
    end
end)
