-- Addon messages between guildmates. The only file that sends or receives them (test_rules).
--
-- * GUILD and WHISPER only: Forever never delivers addon messages on custom channels.
-- * Every message is a small table { v = protocol, t = type, ... }, serialised with AceSerializer
--   and sent with AceComm, which splits long ones under 255 bytes and throttles everything through
--   ChatThrottleLib: about 800 bytes a second shared by every addon that uses it (the standard budget
--   that keeps clients under the server's limits), with a small burst. Big things (recipe lists) go
--   as BULK so they wait behind everything else.
-- * Who sent it comes from the game, never from the message. A whisper only counts if the sender
--   is on our own guild roster. Junk, unknown types and newer protocols are dropped quietly and
--   logged; they never cause an error.
-- * Sim mode feeds fake messages into Comm.Receive, the same path real ones take.
local ADDON, ns = ...
local L = ns.L

local AceComm = LibStub("AceComm-3.0")
local Ser = LibStub("AceSerializer-3.0")

local Comm = {}
ns.Comm = Comm
AceComm:Embed(Comm)

local MAX_TEXT = 8000           -- a serialised message bigger than this is refused (both ways)
-- More than this from one sender in a minute is dropped (a runaway or rogue client). It must stay well
-- above a full set of copies after login (up to 60 requests + 40 events + board + hellos + positions).
local MAX_PER_MINUTE = 240
local handlers = {}             -- type -> { function(msg, sender, channel, isSelf), ... }
local counts = {}               -- sender -> { start, n } for the per-minute limit

Comm.users = {}                 -- "Name-Realm" -> { ver, seen, sim } for guildmates with the addon
Comm.selfEcho = nil             -- server time our own GUILD message last came back to us
Comm.newest = nil               -- the newest version seen in the guild, if newer than ours
Comm.got = {}                   -- type -> messages received this session (for /ynm log)
Comm.sent = {}                  -- type -> messages sent this session

-- Frequent types that would flood the message log: counted, not logged one by one when received.
local QUIET_IN = { POS = true }

function Comm.On(t, fn)
    handlers[t] = handlers[t] or {}
    table.insert(handlers[t], fn)
end

-- Can we send at all? Trial accounts can't, and GUILD needs a guild.
local trialTold = false
function Comm.CanSend(channel)
    if (IsTrialAccount and IsTrialAccount()) or (IsVeteranTrialAccount and IsVeteranTrialAccount()) then
        if not trialTold then trialTold = true; ns.Print(L.TRIAL) end
        return false
    end
    if channel == "GUILD" and not IsInGuild() then return false end
    return true
end

-- Plain-English names for the message log (/ynm log in game, or the saved-variables file).
local NAMES = { HI = { "hello", "hellos" }, ST = { "status", "statuses" }, POS = { "position", "positions" },
    PROF = { "recipe list", "recipe lists" }, REQ = { "request", "requests" }, IDX = { "list index", "list indexes" },
    GRP = { "group post", "group posts" }, SIGN = { "sign-up", "sign-ups" }, ANS = { "answer", "answers" },
    AVL = { "availability", "availabilities" }, EVT = { "event", "events" }, RSVP = { "event answer", "event answers" },
    BRD = { "board item", "board items" }, RQ = { "craft request", "craft requests" }, CL = { "I'll-make-it", "I'll-make-its" },
    GTH = { "gathering", "gatherings" }, GAK = { "invite ask", "invite asks" }, ALT = { "alt link", "alt links" } }

local function Describe(msg)
    local t = msg.t
    if t == "POS" then
        if msg.off then return "last message: remove my dot (guildies' maps clear it now)" end
        return string.format("position (map %s, %.3f, %.3f)", tostring(msg.m), tonumber(msg.x) or 0, tonumber(msg.y) or 0)
    elseif t == "HI" then
        return "hello (version " .. tostring(msg.ver) .. (msg.ask and ", asking who has the addon" or "") .. ")"
    elseif t == "ST" then
        return "status (level " .. tostring(msg.l) .. ", " .. tostring(msg.z) .. ")"
    elseif t == "PROF" then
        local who = msg.o and (msg.o .. "'s ") or ""
        if msg.p == false then return who .. "recipe list: not shared" end
        local n, lines = 0, 0
        if type(msg.p) == "table" then
            for _, d in pairs(msg.p) do
                lines = lines + 1
                n = n + ((type(d) == "table" and type(d.i) == "table") and #d.i or 0)
            end
        end
        return who .. "recipe list (" .. lines .. " professions, " .. n .. " recipes)"
    elseif t == "REQ" then
        if msg.w == "PROF" then return "request for a recipe list" end
        if msg.w == "IDX" then return "request for the recipe lists they have" end
        if msg.w == "CAL" then return "request for the guild calendar" end
        if msg.w == "BRD" then return "request for the guild info and streamers" end
        if msg.w == "RQS" then return "request for the craft requests" end
        if msg.w == "SYNC" then return "request for your changes they missed" end
        if msg.w == "ALT" then return "request for the alt links" end
        return "request for " .. (type(msg.n) == "table" and #msg.n or 0) .. " guildies' recipe lists"
    elseif t == "GTH" then
        return "gathering " .. (msg.on and "started" or "stopped")
    elseif t == "GAK" then
        return "ask for an invite"
    elseif t == "RQ" then
        local who = msg.o and (msg.o .. "'s ") or ""
        if msg.x then
            return who .. "craft request: " .. tostring(msg.x)
                .. (type(msg.mk) == "table" and #msg.mk > 0 and (", made by " .. table.concat(msg.mk, ", ")) or "")
        end
        return who .. "craft request (" .. tostring(msg.it) .. " x" .. tostring(msg.n) .. ")"
    elseif t == "CL" then
        return msg.x and "\"can't make it after all\"" or "\"I'll make it\""
    elseif t == "BRD" then
        local who = msg.o and (msg.o .. "'s ") or ""
        local what = ({ info = "guild info", rank = "who-can-edit setting", mgr = "managers list", strm = "streamer card" })[msg.k] or "board item"
        return who .. what .. (msg.x and " (removed)" or "")
    elseif t == "EVT" then
        local who = msg.o and (msg.o .. "'s ") or ""
        if msg.x then return who .. "event: " .. (msg.rm and ("removed by " .. tostring(msg.rm)) or "cancelled") end
        return who .. "event (" .. tostring(msg.ti) .. ")"
    elseif t == "EVR" then
        return "removal of " .. tostring(msg.o) .. "'s event"
    elseif t == "RSVP" then
        local words = { y = "going", m = "maybe", n = "can't" }
        return "event answer (" .. (words[msg.a] or "?") .. ")"
    elseif t == "ALT" then
        local who = msg.o and (msg.o .. "'s ") or ""
        local n = type(msg.al) == "table" and #msg.al or 0
        if n == 0 then return who .. "alt links: none" end
        return who .. "alt links (" .. n .. " other characters, main " .. tostring(msg.mn) .. ")"
    elseif t == "IDX" then
        local n = 0
        if type(msg.l) == "table" then for _ in pairs(msg.l) do n = n + 1 end end
        return "list index (" .. n .. " recipe lists)"
    end
    local parts = {}
    for k, v in pairs(msg) do
        if k ~= "v" and k ~= "t" then
            local s = type(v) == "table" and ("{" .. #v .. "}") or tostring(v)
            parts[#parts + 1] = k .. "=" .. s
        end
    end
    table.sort(parts)
    return t .. (#parts > 0 and (" " .. table.concat(parts, " ")) or "")
end

local function Count(t, n)
    local name = NAMES[t]
    if not name then return n .. " " .. t end
    return n .. " " .. (n == 1 and name[1] or name[2])
end

-- Send a message table on GUILD, or WHISPER to one guildmate. Returns true if handed to AceComm.
-- fast: positions of the near lane only, on their own prefix (ns.PREFIX_POS).
function Comm.Send(msg, channel, target, prio, fast)
    if channel ~= "GUILD" and channel ~= "WHISPER" then return false end
    if fast and msg.t ~= "POS" then return false end
    if channel == "WHISPER" and type(target) ~= "string" then return false end
    if channel == "WHISPER" and ns.Sim and ns.Sim.IsFake(target) then
        ns.Log("(sim) would whisper " .. msg.t .. " to " .. target)
        return false
    end
    -- Sim mode: anything about a fake guildie's event, request, question or group (my answer to it, or
    -- a copy for a guildie catching up) stays on this screen. Guildies' addons would drop it anyway
    -- (fakes aren't in their roster), but it shouldn't go out at all. SENT still fires, so the fakes
    -- react as if it had gone. Fake names are taken out of "who helped" lists too.
    if ns.Sim and ns.Sim.IsOn() then
        if ns.Sim.IsFake(msg.o) or ns.Sim.IsFake(msg.by) or ns.Sim.IsFake(msg.who) or ns.Sim.IsFake(msg.to) then
            ns.Log("(sim) kept on this screen: " .. tostring(msg.t) .. " about " .. tostring(msg.o))
            ns.Fire("SENT", msg, channel, target)
            return true
        end
        for _, field in ipairs({ "hp", "mk" }) do
            if type(msg[field]) == "table" then
                local real = {}
                for _, name in ipairs(msg[field]) do if not ns.Sim.IsFake(name) then real[#real + 1] = name end end
                msg[field] = real
            end
        end
    end
    if not Comm.CanSend(channel) then return false end
    -- "v" is the protocol version on every message; a module's own version field must be named differently.
    assert(msg.v == nil or msg.v == ns.PROTOCOL, "message field 'v' is reserved for the protocol version")
    msg.v = ns.PROTOCOL
    local text = Ser:Serialize(msg)
    if #text > MAX_TEXT then
        ns.Log("not sent, too big: " .. msg.t .. " (" .. #text .. " bytes)")
        return false
    end
    Comm:SendCommMessage(fast and ns.PREFIX_POS or ns.PREFIX, text, channel, target, prio or "NORMAL")
    Comm.sent[msg.t] = (Comm.sent[msg.t] or 0) + 1
    ns.Log("sent my " .. Describe(msg) .. (channel == "GUILD" and " to the guild" or (" to " .. target)))
    ns.Fire("SENT", msg, channel, target)
    return true
end

local function TooMany(sender)
    local now = GetTime()
    local c = counts[sender]
    if not c or now - c.start > 60 then
        counts[sender] = { start = now, n = 1 }
        return false
    end
    c.n = c.n + 1
    return c.n > MAX_PER_MINUTE
end

-- Every received message comes through here: real ones from AceComm, fake ones from Sim.lua.
function Comm.Receive(text, channel, sender, fast)
    local from = ns.Key(sender)
    if not from then return end
    if channel ~= "GUILD" and channel ~= "WHISPER" then
        ns.Log("dropped: " .. tostring(channel) .. " message from " .. from)
        return
    end
    local isSelf = (from == ns.me)
    if channel == "WHISPER" and not isSelf and not ns.Guild.IsMember(from) then
        ns.Log("dropped: whisper from " .. from .. " (not on our guild roster)")
        return
    end
    if type(text) ~= "string" or #text > MAX_TEXT then
        ns.Log("dropped: oversized message from " .. from)
        return
    end
    if TooMany(from) then
        if counts[from].n == MAX_PER_MINUTE + 1 then ns.Log("dropping: too many messages from " .. from) end
        return
    end
    local ok, msg = Ser:Deserialize(text)
    if not ok or type(msg) ~= "table" or type(msg.v) ~= "number" or type(msg.t) ~= "string" or #msg.t > 8 then
        ns.Log("dropped: unreadable message from " .. from)
        return
    end
    if fast and msg.t ~= "POS" then
        ns.Log("dropped: " .. msg.t .. " on the positions prefix from " .. from)
        return
    end
    if msg.v > ns.PROTOCOL then
        -- A newer version speaks a format we don't know. Only note its version.
        if msg.t == "HI" and type(msg.ver) == "string" then Comm.SeeUser(from, msg.ver:sub(1, 20)) end
        ns.Log("ignored: newer protocol " .. msg.v .. " " .. msg.t .. " from " .. from)
        return
    end
    local fns = handlers[msg.t]
    if not fns then
        ns.Log("ignored: unknown type " .. msg.t .. " from " .. from)
        return
    end
    if not isSelf then
        Comm.got[msg.t] = (Comm.got[msg.t] or 0) + 1
        if not QUIET_IN[msg.t] then
            ns.Log("got " .. Describe(msg) .. " from " .. from .. (channel == "WHISPER" and " (whisper)" or ""))
        end
    end
    -- Each handler on its own: several modules answer the same type (REQ has seven), and one
    -- failing must not stop the others.
    for i = 1, #fns do ns.Safe(fns[i], msg, from, channel, isSelf) end
end

Comm:RegisterComm(ns.PREFIX, function(prefix, text, channel, sender)
    ns.Safe(Comm.Receive, text, channel, sender)
end)
-- The near lane's prefix carries positions only; anything else on it is dropped.
Comm:RegisterComm(ns.PREFIX_POS, function(prefix, text, channel, sender)
    ns.Safe(Comm.Receive, text, channel, sender, true)
end)

---------------------------------------------------------------------------------------------------
-- Who has the addon. Real users are kept in saved data per guild (so the roster can show a tick
-- for them while they're offline); fake ones only in memory.

local newerTold = false

function Comm.SeeUser(name, ver, sim)
    ver = (type(ver) == "string" and ver ~= "") and ver or "?"
    local u = Comm.users[name] or {}
    u.ver, u.seen, u.sim = ver, GetServerTime(), sim or nil
    Comm.users[name] = u
    if not sim then
        local g = ns.GuildData()
        if g then g.users[name] = { ver = ver, seen = u.seen } end
        if ver ~= "?" and ns.VERSION:match("^%d") and ns.CompareVersions(ver, ns.VERSION) > 0
            and (not Comm.newest or ns.CompareVersions(ver, Comm.newest) > 0) then
            Comm.newest = ver
            if not newerTold then newerTold = true; ns.Print(string.format(L.NEWER, ver)) end
        end
    end
    ns.Fire("USERS")
end

-- Fake users go when sim mode is turned off.
function Comm.ForgetSims()
    for name, u in pairs(Comm.users) do
        if u.sim then Comm.users[name] = nil end
    end
    ns.Fire("USERS")
end

-- How many other guildmates with the addon are online right now (fake ones don't count).
function Comm.OthersOnline()
    local n = 0
    for name, u in pairs(Comm.users) do
        if name ~= ns.me and not u.sim then
            local m = ns.Guild.Get(name)
            if m and m.online then n = n + 1 end
        end
    end
    return n
end

-- One line of message counts for /ynm log.
function Comm.Summary()
    local sent, got = {}, {}
    for t, n in pairs(Comm.sent) do sent[#sent + 1] = Count(t, n) end
    for t, n in pairs(Comm.got) do got[#got + 1] = Count(t, n) end
    table.sort(sent); table.sort(got)
    if #sent == 0 and #got == 0 then return "Totals this session: no messages yet." end
    return "Totals this session: sent " .. (#sent > 0 and table.concat(sent, ", ") or "nothing")
        .. "; received " .. (#got > 0 and table.concat(got, ", ") or "nothing") .. "."
end

-- Users saved from earlier sessions, for this guild. Members who left the guild are dropped.
local function LoadUsers()
    local g = ns.GuildData()
    if not g then return end
    for name, u in pairs(g.users) do
        if type(u) == "table" and not Comm.users[name] then
            Comm.users[name] = { ver = u.ver, seen = u.seen }
        end
    end
end

ns.Listen("ROSTER", function()
    if not ns.Guild.loaded then return end
    if not Comm.usersLoaded and ns.Guild.key then
        Comm.usersLoaded = true
        LoadUsers()
    end
    local g = ns.GuildData()
    if g and ns.Guild.complete then         -- only after a full read, so nobody is dropped by mistake
        for name in pairs(g.users) do
            if not ns.Guild.IsMember(name) and name ~= ns.me then
                g.users[name] = nil
                if Comm.users[name] and not Comm.users[name].sim then Comm.users[name] = nil end
            end
        end
    end
end)

---------------------------------------------------------------------------------------------------
-- HI: "I have the addon, version x". Sent to the guild at login with ask = true; everyone who
-- hears it whispers their own HI back once (a short random wait, so replies don't all land at once).

local replied = {}              -- name -> GetTime() of our last reply

-- Other modules add their fields to our HI (Status.lua adds level, zone and group size).
local function NewHi(ask)
    local msg = { t = "HI", ver = ns.VERSION, ask = ask or nil }
    ns.Fire("HI_OUT", msg)
    return msg
end

function Comm.SayHi()
    Comm.Send(NewHi(true), "GUILD")
end

Comm.On("HI", function(msg, from, channel, isSelf)
    local ver = type(msg.ver) == "string" and msg.ver:sub(1, 20) or "?"
    if isSelf then
        Comm.selfEcho = GetServerTime()
        Comm.SeeUser(from, ver)
        ns.Log("our own hello came back from the server (guild messages work)")
        return
    end
    Comm.SeeUser(from, ver, ns.Sim and ns.Sim.IsFake(from))
    ns.Fire("HI_IN", msg, from)
    if msg.ask == true then
        local now = GetTime()
        if replied[from] and now - replied[from] < 60 then return end
        replied[from] = now
        C_Timer.After(1 + math.random() * 5, function()
            if ns.Sim and ns.Sim.IsFake(from) then
                ns.Log("(sim) would whisper HI back to " .. from)
                return
            end
            Comm.Send(NewHi(false), "WHISPER", from)
        end)
    end
end)

-- Say hi once the game has settled after login (ChatThrottleLib holds messages for the first
-- seconds anyway), and again when we join a guild.
local saidHiTo = nil
local function MaybeSayHi()
    if not IsInGuild() or not ns.Guild.key then return end
    if saidHiTo == ns.Guild.key then return end
    saidHiTo = ns.Guild.key
    Comm.SayHi()
end

ns.Listen("LOGIN", function()
    C_Timer.After(10, function() ns.Safe(MaybeSayHi) end)
end)
ns.OnEvent("PLAYER_GUILD_UPDATE", function()
    if ns.me then C_Timer.After(5, function() ns.Safe(MaybeSayHi) end) end
end)
