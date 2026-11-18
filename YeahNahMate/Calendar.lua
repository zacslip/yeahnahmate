-- Calendar: guild events with Going / Maybe / Can't, a reminder 15 minutes before, and the next
-- events on Home. Times are kept as server time (GetServerTime, the same moment for everyone) and
-- shown in each player's local time.
--
-- Messages
--   EVT  { id, ti, at, k, nt, nh, nd, note, w, im, an, ev }  my event: title, start (server time),
--                                                    kind (s social, d dungeon; l levelling and o other
--                                                    from older versions show as social), roles wanted,
--                                                    note, weekly, important (below), version (edit
--                                                    time; not "v", which every message uses for the
--                                                    protocol)
--   EVT  { id, ev, x = true }                        I cancelled it
--   EVT  { o = owner, ..., rs = { [name] = "a|r|at|v" } }  a copy with its answers: only by WHISPER,
--                                                    only from a guildie we asked (like recipe copies)
--   RSVP { o, id, at, a, r, rv }                     my answer (y/m/n, role t/h/d) for one occurrence
--   REQ  { w = "CAL" }                               send me the events you know (WHISPER)
--   EVR  { o = owner, id, ev }                       a Calendar moderator removes someone else's event
--                                                    (GUILD; WHISPER to an owner who comes back with it)
--   EVM  { o = owner, id, ti, at, k, nt, nh, nd, note, w, im, an, ev }   a Calendar moderator edits it (same)
--   EVT  { ..., x = true, rm = moderator }           a removed event, in copies and the owner's own
-- Only the owner (the game's sender name) creates or cancels an event. Calendar moderators (Board.lua:
-- the Calendar rank and above, managers, the guild master) can edit or remove anyone's
-- event and gather for it. A removal is final: the owner's old copy can't bring it back. After a
-- moderator's edit the owner's old copy doesn't win either (older version); the owner's own later
-- edits still do. Everyone keeps a copy
-- per guild so events show for guildies who weren't online when they were made. A newer version
-- wins; the owner's own message beats a copy; versions from the future are refused.
--
-- Important events (only Calendar moderators set them): im = which "remind everyone" times are ticked
-- (1 = 15 min, 2 = 30, 4 = 60 before), an = "tell everyone now" (a pop-up once, also at a later login
-- while it hasn't started). Every guildie gets these pop-ups whatever their settings. Each reader
-- checks the owner, or the moderator who last edited it, moderates the calendar on their own roster;
-- a non-moderator owner's message never changes them. Older versions don't know these fields and
-- leave them out of their copies, so a field missing from a message means "keep what I have".
local ADDON, ns = ...
local L = ns.L

local Cal = {}
ns.Calendar = Cal

local WEEK = 7 * 86400
local DAY = 86400
local LIVE = 3 * 3600           -- an event still counts as "on" until 3 hours after it starts
local KEEP = 7 * DAY            -- past events are kept a week, then forgotten
local KEEP_CANCELLED = 30 * DAY -- a cancel is remembered this long (from when it was cancelled), so
                                -- a guildie still holding the event can't bring it back
local MAX_TITLE, MAX_NOTE = 40, 150    -- a note fills three lines (older versions cut it at 100)
local MAX_COPIES = 40
local ASK_WINDOW = 300
Cal.KINDS = { d = true, l = true, s = true, o = true }    -- accepted from others (older versions too)
Cal.MAX_NOTE = MAX_NOTE
Cal.MAKE = { s = true, d = true }                         -- kinds an event can be made as (raid later)
Cal.IM_TIMES = { { 1, 15 }, { 2, 30 }, { 4, 60 } }        -- im bit, minutes before
local IM_MAX = 7
Cal.ANSWERS = { y = true, m = true, n = true }

local function Clean(s, max) return type(s) == "string" and ns.CutBytes((s:gsub("[|\n\r]", "")), max) or "" end
local function Count(n, max) n = tonumber(n); if not n then return 0 end return math.max(0, math.min(max, math.floor(n))) end
local Future = ns.Future
local function CleanIm(n) n = tonumber(n); if not n or n ~= math.floor(n) or n < 0 or n > IM_MAX then return nil end return n end

-- The kind an event shows as: levelling and other (older versions) show as social.
function Cal.ShownKind(k) return (k == "d" or k == "r") and k or "s" end

function Cal.Store()
    local g = ns.GuildData()
    if not g then return nil end
    if type(g.events) ~= "table" then g.events = {} end
    return g.events
end

local function Changed() ns.Fire("CALENDAR") end
-- Do I really moderate the calendar (my guild rank, not /ynm dev editor)? Only then is a change sent.
local function RealMod() return ns.Board.CanModerate(ns.me, "cal") end

---------------------------------------------------------------------------------------------------
-- Occurrences. A weekly event happens at e.at + n weeks.

-- The occurrence that is on now or next (still "on" until 3 hours after it starts).
function Cal.NextAt(e, now)
    now = now or GetServerTime()
    if not e.w or e.at >= now - LIVE then return e.at end
    local n = math.ceil((now - LIVE - e.at) / WEEK)
    return e.at + n * WEEK
end

-- Events happening on a local calendar day: { { e, key, at }, ... } sorted by time.
function Cal.OnDay(y, m, d)
    local store = Cal.Store()
    local list = {}
    if not store then return list end
    local dayStart = time({ year = y, month = m, day = d, hour = 0, min = 0, sec = 0 })
    local dayEnd = time({ year = y, month = m, day = d + 1, hour = 0, min = 0, sec = 0 })
    for key, e in pairs(store) do
        if not e.x and e.at then
            local at
            if e.w then
                if dayEnd > e.at then
                    local n = math.max(0, math.ceil((dayStart - e.at) / WEEK))
                    local occ = e.at + n * WEEK
                    if occ < dayEnd then at = occ end
                end
            elseif e.at >= dayStart and e.at < dayEnd then
                at = e.at
            end
            if at then list[#list + 1] = { e = e, key = key, at = at } end
        end
    end
    table.sort(list, function(a, b) if a.at ~= b.at then return a.at < b.at end return a.key < b.key end)
    return list
end

-- The next few events from now: { { e, key, at }, ... }.
function Cal.Upcoming(n)
    local store = Cal.Store()
    local list = {}
    if not store then return list end
    local now = GetServerTime()
    for key, e in pairs(store) do
        if not e.x and e.at then
            local at = Cal.NextAt(e, now)
            if at >= now - LIVE then list[#list + 1] = { e = e, key = key, at = at } end
        end
    end
    table.sort(list, function(a, b) if a.at ~= b.at then return a.at < b.at end return a.key < b.key end)
    while #list > (n or 3) do table.remove(list) end
    return list
end

-- Answers for one occurrence: going / maybe / can't (names), and going counted by role.
function Cal.Answers(e, at)
    local r = { y = {}, m = {}, n = {}, roles = { t = 0, h = 0, d = 0 } }
    for name, a in pairs(e.rs or {}) do
        if a.at == at and Cal.ANSWERS[a.a] then
            r[a.a][#r[a.a] + 1] = name
            if a.a == "y" and a.r and r.roles[a.r] then r.roles[a.r] = r.roles[a.r] + 1 end
        end
    end
    for _, k in ipairs({ "y", "m", "n" }) do table.sort(r[k]) end
    return r
end

function Cal.MyAnswer(e, at)
    local a = e.rs and e.rs[ns.me]
    if a and a.at == at then return a.a, a.r end
end

---------------------------------------------------------------------------------------------------
-- My events

local function EventMessage(e)
    return { t = "EVT", id = e.id, ti = e.title, at = e.at, k = e.k, nt = e.nt, nh = e.nh, nd = e.nd,
             note = e.note, w = e.w or nil, im = e.im or 0, an = e.an and true or false, ev = e.v }
end

-- Is this event important, as I see it? Its owner, or the moderator who last edited it, must moderate
-- the calendar on my own roster (anyone could send the flag; only their rank makes it count).
function Cal.IsImportant(e)
    if not e or e.x or not ((e.im or 0) > 0 or e.an) then return false end
    return ns.Board.CanModerate(e.owner, "cal") or (e.md ~= nil and ns.Board.CanModerate(e.md, "cal"))
end

-- The important settings from the form, if I may set them (a Calendar moderator); else what it had.
local function TakeImportant(e, fields)
    if fields.im ~= nil and Cal.CanRemove() then
        e.im = CleanIm(fields.im) or 0
        e.an = fields.an and true or nil
    end
    e.im = e.im or 0
end

-- Answers for a copy: only those for the occurrence that's on or next (old weeks' answers are no use),
-- at most 40, newest first.
local function PackAnswers(e)
    local at = Cal.NextAt(e)
    local list = {}
    for name, a in pairs(e.rs or {}) do
        if a.at == at then list[#list + 1] = { name, a } end
    end
    table.sort(list, function(x, y) return x[2].v > y[2].v end)
    local rs = {}
    for i = 1, math.min(#list, 40) do
        local name, a = list[i][1], list[i][2]
        rs[name] = a.a .. "|" .. (a.r or "") .. "|" .. a.at .. "|" .. a.v
    end
    return rs
end

-- An event moved to a new time: its answers move with it (they belong to the occurrence).
local function MoveAnswers(e, oldAt, newAt)
    if not oldAt or oldAt == newAt then return end
    local delta = newAt - oldAt
    for _, a in pairs(e.rs or {}) do a.at = a.at + delta end
end

-- fields: title, at (server time), k, nt, nh, nd, note, w, mute, im, an. Returns the key, or nil and
-- why ("title", "kind", "gone": removed or cancelled, "denied": not mine to change).
function Cal.Save(key, fields)
    local store = Cal.Store()
    if not store or not ns.me then return nil, "denied" end
    local title = Clean(fields.title, MAX_TITLE)
    if title == "" then return nil, "title" end
    if type(fields.at) ~= "number" or not Cal.MAKE[fields.k] then return nil, "kind" end
    local now = GetServerTime()
    local e = key and store[key]
    if e and e.rm then return nil, "gone" end              -- removed by a moderator: final
    if e and e.owner ~= ns.me then                          -- a Calendar moderator edits it
        if e.x then return nil, "gone" end
        if not Cal.CanRemove() then return nil, "denied" end
        MoveAnswers(e, e.at, math.floor(fields.at))
        e.title, e.at, e.k = title, math.floor(fields.at), fields.k
        local roles = fields.k == "d"
        e.nt, e.nh, e.nd = roles and Count(fields.nt, 2) or 0, roles and Count(fields.nh, 2) or 0, roles and Count(fields.nd, 4) or 0
        e.note, e.w = Clean(fields.note, MAX_NOTE), fields.w and true or nil
        TakeImportant(e, fields)
        e.v, e.direct, e.md = math.max(now, (e.v or 0) + 1), true, ns.me
        if RealMod() then
            local m = EventMessage(e)
            m.t, m.o = "EVM", e.owner
            ns.Comm.Send(m, "GUILD")
        end
        Changed()
        return key
    end
    if not e then
        local id = now
        while store[ns.me .. ":" .. id] do id = id + 1 end
        key = ns.me .. ":" .. id
        e = { owner = ns.me, id = id, rs = {}, direct = true }
        store[key] = e
    end
    MoveAnswers(e, e.at, math.floor(fields.at))
    e.title, e.at, e.k = title, math.floor(fields.at), fields.k
    local roles = fields.k == "d"
    e.nt = roles and Count(fields.nt, 2) or 0
    e.nh = roles and Count(fields.nh, 2) or 0
    e.nd = roles and Count(fields.nd, 4) or 0
    e.note = Clean(fields.note, MAX_NOTE)
    e.w = fields.w and true or nil
    e.mute = fields.mute and true or nil           -- my own switch, never sent (see ToggleMute)
    TakeImportant(e, fields)
    e.anSeen = true                                -- my own "tell everyone": no pop-up for me
    e.v = math.max(now, (e.v or 0) + 1)
    e.x = nil
    ns.Comm.Send(EventMessage(e), "GUILD")
    Changed()
    return key
end

-- The owner's own switch: no "X is going" pop-ups for this event (a big event would be a lot of them).
-- Kept on this client only; nothing is sent.
function Cal.ToggleMute(key)
    local store = Cal.Store()
    local e = store and store[key]
    if not e or e.owner ~= ns.me then return end
    e.mute = not e.mute or nil
    Changed()
end

-- Do I moderate the calendar (edit and remove other people's events)? /ynm dev editor on tries it on
-- this screen only.
function Cal.CanRemove()
    return ns.Board and ns.Board.Moderates("cal") or false
end


-- Remove someone else's event (an editor rank only). My own I cancel instead.
function Cal.Remove(key)
    local store = Cal.Store()
    local e = store and store[key]
    if not e or e.x or e.owner == ns.me or not Cal.CanRemove() then return false end
    e.x, e.rm, e.direct = true, ns.me, nil
    e.v = math.max(GetServerTime(), (e.v or 0) + 1)
    if RealMod() then
        ns.Comm.Send({ t = "EVR", o = e.owner, id = e.id, ev = e.v }, "GUILD")
    end
    ns.Log("removed " .. e.owner .. "'s event " .. tostring(e.title))
    Changed()
    return true
end

function Cal.Cancel(key)
    local store = Cal.Store()
    local e = store and store[key]
    if not e or e.owner ~= ns.me then return end
    e.x = true
    e.v = math.max(GetServerTime(), (e.v or 0) + 1)
    ns.Comm.Send({ t = "EVT", id = e.id, ev = e.v, x = true }, "GUILD")
    Changed()
end

-- My answer for one occurrence: a = y/m/n, r = t/h/d or nil.
function Cal.Answer(key, at, a, r)
    local store = Cal.Store()
    local e = store and store[key]
    if not e or e.x or not Cal.ANSWERS[a] then return end
    if r and not ns.Dungeons.ROLES[r] then r = nil end
    local v = GetServerTime()
    e.rs = e.rs or {}
    local old = e.rs[ns.me]
    if old and old.v >= v then v = old.v + 1 end
    e.rs[ns.me] = { a = a, r = r, at = at, v = v }
    ns.Comm.Send({ t = "RSVP", o = e.owner, id = e.id, at = at, a = a, r = r, rv = v }, "GUILD")
    Changed()
end

---------------------------------------------------------------------------------------------------
-- Receiving

local asked = {}                -- peer -> GetTime() we asked them for the calendar

-- An answer: from the guildie themselves (their RSVP), or passed on inside an event message (relayed).
-- A relayed answer never replaces one we heard from the guildie; theirs always replaces a relayed one.
local function TakeAnswer(e, name, a, r, at, v, relayed)
    if not Cal.ANSWERS[a] or type(at) ~= "number" or Future(v, relayed) then return false end
    if r ~= nil and not ns.Dungeons.ROLES[r] then r = nil end
    e.rs = e.rs or {}
    local old = e.rs[name]
    -- Their own answer always wins; a relayed one only when it's newer (they changed it while we
    -- weren't around to hear).
    if old and not ns.Newer(old.v, not old.relayed, v, not relayed) then return false end
    e.rs[name] = { a = a, r = r, at = math.floor(at), v = v, relayed = relayed or nil }
    return true
end

-- An event from its owner (direct) or a copy. Returns true if kept.
local function TakeEvent(owner, msg, direct)
    local store = Cal.Store()
    if not store or owner == ns.me or not ns.Guild.IsMember(owner) then return false end
    if type(msg.id) ~= "number" or Future(msg.ev, not direct) then return false end
    local key = owner .. ":" .. msg.id
    local old = store[key]
    if old and old.rm then return false end
    -- The owner's own message always wins; a copy wins when it's newer (a move or cancel the owner
    -- made while we were offline).
    local newer = not old or ns.Newer(old.v, old.direct, msg.ev, direct)
    local kept = false
    if newer then
        if msg.x == true then
            old = old or { owner = owner, id = msg.id, rs = {} }
            old.x, old.v, old.direct = true, msg.ev, direct or nil
            -- Removed by an editor rank (checked against my roster).
            local rm = type(msg.rm) == "string" and ns.Key(msg.rm) or nil
            if rm and ns.Board.CanModerate(rm, "cal") then old.rm = rm end
            store[key] = old
            kept = true
        else
            local title = Clean(msg.ti, MAX_TITLE)
            if title == "" or type(msg.at) ~= "number" or not Cal.KINDS[msg.k] then
                ns.Log("dropped: bad event from " .. owner)
                return false
            end
            local e = old or { owner = owner, id = msg.id, rs = {} }
            MoveAnswers(e, e.at, math.floor(msg.at))
            e.title, e.at, e.k = title, math.floor(msg.at), msg.k
            e.nt, e.nh, e.nd = Count(msg.nt, 2), Count(msg.nh, 2), Count(msg.nd, 4)
            e.note, e.w, e.v, e.x = Clean(msg.note, MAX_NOTE), msg.w == true or nil, msg.ev, nil
            e.direct = direct or nil
            -- Important: missing = keep (older versions); an owner who doesn't moderate the calendar
            -- can't change it (only a moderator's edit can have set it).
            if not direct or ns.Board.CanModerate(owner, "cal") then
                if msg.im ~= nil then e.im = CleanIm(msg.im) or e.im end
                if msg.an ~= nil then e.an = msg.an == true or nil end
            end
            e.im = e.im or 0
            store[key] = e
            kept = true
        end
    end
    -- Answers riding along (a copy, or the owner's whisper to someone who just logged in).
    local e = store[key]
    if e and type(msg.rs) == "table" then
        local n = 0
        for name, packed in pairs(msg.rs) do
            n = n + 1
            if n > 40 then break end
            name = type(name) == "string" and ns.Key(name) or nil
            if name and type(packed) == "string" and ns.Guild.IsMember(name) then
                local a, r, at, v = packed:match("^(%a)|(%a?)|(%d+)|(%d+)$")
                if a and TakeAnswer(e, name, a, r ~= "" and r or nil, tonumber(at), tonumber(v), true) then kept = true end
            end
        end
    end
    return kept
end

local toldOwner = {}
local function TellOwner(owner, e)
    if not RealMod() or (ns.Sim and ns.Sim.IsFake(owner)) then return end
    local k = owner .. ":" .. e.id
    if toldOwner[k] and GetTime() - toldOwner[k] < 60 then return end
    toldOwner[k] = GetTime()
    local m
    if e.rm then
        m = { t = "EVR", o = owner, id = e.id, ev = e.v }
    else
        m = EventMessage(e)
        m.t, m.o = "EVM", owner
    end
    ns.Comm.Send(m, "WHISPER", owner, "BULK")
end

ns.Comm.On("EVT", function(msg, from, channel, isSelf)
    if isSelf then return end
    if msg.o == nil then
        local store = Cal.Store()
        local held = store and type(msg.id) == "number" and store[from .. ":" .. msg.id]
        if held and held.rm and not (msg.x and msg.rm) then TellOwner(from, held)
        elseif held and held.md and not held.x and type(msg.ev) == "number" and msg.ev < (held.v or 0) then TellOwner(from, held) end
        if TakeEvent(from, msg, true) then Changed() end
        return
    end
    if channel ~= "WHISPER" or not asked[from] or GetTime() - asked[from] > ASK_WINDOW then
        ns.Log("dropped: an event copy from " .. from .. " that we didn't ask for")
        return
    end
    asked[from] = GetTime()
    local owner = ns.Key(msg.o)
    if owner and owner ~= from and TakeEvent(owner, msg, false) then Changed() end
end)

-- An editor rank removed an event. Only an editor's own message counts (sender from the game, rank
-- from my roster). It can be my own event: then it's gone for me too, and I'm told who removed it.
ns.Comm.On("EVR", function(msg, from, channel, isSelf)
    if isSelf or (channel ~= "GUILD" and channel ~= "WHISPER") then return end
    if not ns.Board.CanModerate(from, "cal") then
        ns.Log("dropped: an event removal from " .. from .. ", who doesn't moderate the calendar")
        return
    end
    local store = Cal.Store()
    local owner = type(msg.o) == "string" and ns.Key(msg.o) or nil
    if not store or not owner or owner == from or type(msg.id) ~= "number" or type(msg.ev) ~= "number"
        or Future(msg.ev, false) then return end
    if owner ~= ns.me and not ns.Guild.IsMember(owner) then return end
    local key = owner .. ":" .. msg.id
    local e = store[key]
    if e and e.rm then return end
    local was = e and not e.x and e.title
    e = e or { owner = owner, id = msg.id, rs = {} }
    e.x, e.rm, e.direct = true, from, nil
    e.v = math.max(msg.ev, (e.v or 0) + (owner == ns.me and 1 or 0))
    store[key] = e
    if owner == ns.me and was then ns.Print(string.format(L.CAL_REMOVED_MINE, from, was)) end
    Changed()
end)

-- A Calendar moderator edited someone's event. It can be mine: then I take it too, and I'm told.
ns.Comm.On("EVM", function(msg, from, channel, isSelf)
    if isSelf or (channel ~= "GUILD" and channel ~= "WHISPER") then return end
    if not ns.Board.CanModerate(from, "cal") then
        ns.Log("dropped: an event edit from " .. from .. ", who doesn't moderate the calendar")
        return
    end
    local store = Cal.Store()
    local owner = type(msg.o) == "string" and ns.Key(msg.o) or nil
    if not store or not owner or owner == from or type(msg.id) ~= "number" or type(msg.ev) ~= "number"
        or Future(msg.ev, false) then return end
    if owner ~= ns.me and not ns.Guild.IsMember(owner) then return end
    local title = Clean(msg.ti, MAX_TITLE)
    if title == "" or type(msg.at) ~= "number" or not Cal.KINDS[msg.k] then return end
    local key = owner .. ":" .. msg.id
    local e = store[key]
    if e and (e.rm or e.x or (e.v or 0) >= msg.ev) then return end
    e = e or { owner = owner, id = msg.id, rs = {} }
    MoveAnswers(e, e.at, math.floor(msg.at))
    e.title, e.at, e.k = title, math.floor(msg.at), msg.k
    e.nt, e.nh, e.nd = Count(msg.nt, 2), Count(msg.nh, 2), Count(msg.nd, 4)
    e.note, e.w = Clean(msg.note, MAX_NOTE), msg.w == true or nil
    if msg.im ~= nil then e.im = CleanIm(msg.im) or e.im end
    if msg.an ~= nil then e.an = msg.an == true or nil end
    e.im = e.im or 0
    e.v, e.direct, e.md, e.x = msg.ev, true, from, nil
    store[key] = e
    if owner == ns.me then ns.Print(string.format(L.CAL_EDITED_MINE, from, title)) end
    Changed()
end)

ns.Comm.On("RSVP", function(msg, from, channel, isSelf)
    -- GUILD when answering; a WHISPER when re-sending my answers to an owner who comes online.
    if isSelf or (channel ~= "GUILD" and channel ~= "WHISPER") then return end
    local store = Cal.Store()
    local owner = type(msg.o) == "string" and ns.Key(msg.o) or nil
    local e = store and owner and type(msg.id) == "number" and store[owner .. ":" .. msg.id]
    if not e or e.x then return end
    if TakeAnswer(e, from, msg.a, msg.r, msg.at, msg.rv) then
        Changed()
        if owner == ns.me and not e.mute then ns.Fire("ANSWERED", from, msg.a, e, math.floor(msg.at)) end
    end
end)

-- Someone asks for the calendar: whisper them a copy of each event I know (with its answers).
local answered = {}
ns.Comm.On("REQ", function(msg, from, channel, isSelf)
    if isSelf or channel ~= "WHISPER" or msg.w ~= "CAL" then return end
    local now = GetTime()
    if answered[from] and now - answered[from] < 60 then return end
    answered[from] = now
    local store = Cal.Store()
    if not store then return end
    local list = {}
    for key, e in pairs(store) do
        if e.owner ~= from and ns.Guild.IsMember(e.owner) then list[#list + 1] = e end
    end
    -- Live events first (newest first), then cancel markers with what room is left: kept 30 days,
    -- the markers would otherwise push long-running weekly events out of the limit.
    table.sort(list, function(a, b)
        if (a.x and true or false) ~= (b.x and true or false) then return not a.x end
        return (a.v or 0) > (b.v or 0)
    end)
    for i = 1, math.min(#list, MAX_COPIES) do
        local e = list[i]
        local m = e.x and { t = "EVT", id = e.id, ev = e.v, x = true, rm = e.rm } or EventMessage(e)
        m.rs = not e.x and PackAnswers(e) or nil
        if e.owner ~= ns.me then m.o = e.owner end         -- my own go as the owner's message
        ns.Comm.Send(m, "WHISPER", from, "BULK")
    end
end)

-- A guildie comes online (their log-in hello, or their reply to mine): whisper them my answers to
-- their events. Without this, answers given while an owner was offline never reached them (copies
-- leave out an owner's own events), so their headcount stayed wrong. Found by tests/multi.py.
local answersSent = {}
ns.Listen("HI_IN", function(msg, from)
    if ns.Sim and ns.Sim.IsFake(from) then return end
    local now = GetTime()
    if answersSent[from] and now - answersSent[from] < 60 then return end     -- their hello and reply
    answersSent[from] = now
    C_Timer.After(2 + math.random() * 6, function()
        local store = Cal.Store()
        if not store then return end
        for _, e in pairs(store) do
            local a = e.owner == from and not e.x and e.rs and e.rs[ns.me]
            if a then
                ns.Comm.Send({ t = "RSVP", o = e.owner, id = e.id, at = a.at, a = a.a, r = a.r, rv = a.v }, "WHISPER", from, "BULK")
            end
        end
    end)
end)

-- My own events as messages (cancels too), with their answers.
local function MyEventMessages()
    local out = {}
    local store = Cal.Store()
    if not store then return out end
    for _, e in pairs(store) do
        if e.owner == ns.me then
            local m = e.x and { t = "EVT", id = e.id, ev = e.v, x = true, rm = e.rm } or EventMessage(e)
            m.rs = not e.x and PackAnswers(e) or nil
            out[#out + 1] = m
        end
    end
    return out
end

-- A guildie who just logged in gets my own events (with answers) straight from me.
ns.Listen("HI_IN", function(msg, from)
    if msg.ask ~= true or (ns.Sim and ns.Sim.IsFake(from)) then return end
    C_Timer.After(3 + math.random() * 4, function()
        for _, m in ipairs(MyEventMessages()) do ns.Comm.Send(m, "WHISPER", from, "BULK") end
    end)
end)

-- And when I log in, guildies already online who missed my changes catch up (Sync.lua).
ns.Sync.Register("events", function(author)
    local list = {}
    for _, e in pairs(Cal.Store() or {}) do if e.owner == author then list[#list + 1] = e.v end end
    return list
end, MyEventMessages)

-- After login, ask one online guildie for the events they know (fills in owners who are offline).
local function AskCalendar()
    local peers = {}
    for name, u in pairs(ns.Comm.users) do
        local m = ns.Guild.Get(name)
        if name ~= ns.me and not u.sim and m and m.online then peers[#peers + 1] = name end
    end
    if #peers == 0 then return end
    local peer = peers[math.random(#peers)]
    asked[peer] = GetTime()
    ns.Comm.Send({ t = "REQ", w = "CAL" }, "WHISPER", peer)
end
ns.Listen("LOGIN", function() C_Timer.After(40, function() ns.Safe(AskCalendar) end) end)

---------------------------------------------------------------------------------------------------
-- Upkeep and reminders

local function Tidy()
    local store = Cal.Store()
    if not store then return end
    local now = GetServerTime()
    local changed = false
    for key, e in pairs(store) do
        local gone
        if e.x then
            gone = (e.v or 0) < now - KEEP_CANCELLED
        else
            gone = not e.w and e.at and e.at < now - KEEP
        end
        gone = gone or (ns.Guild.complete and not ns.Guild.IsMember(e.owner) and e.owner ~= ns.me)
        if gone then
            store[key] = nil; changed = true
        elseif e.w and e.rs then
            -- Old weeks' answers of a weekly event go after a week.
            for name, a in pairs(e.rs) do if a.at < now - KEEP then e.rs[name] = nil end end
        end
    end
    if changed then Changed() end
end

-- Important events: each ticked time once per occurrence. Logging in (or the event moving) inside a
-- window fires only the nearest ticked time, never a late 60 or 30. What's fired is kept on the event
-- (imAt, imT: never sent) so a /reload doesn't fire it again.
local function RemindImportant(now)
    local store = Cal.Store()
    if not store then return end
    for _, e in pairs(store) do
        if (e.im or 0) > 0 and Cal.IsImportant(e) and e.at then
            local at = Cal.NextAt(e, now)
            local left = at - now
            if left > 0 then
                local due
                for _, bt in ipairs(Cal.IM_TIMES) do
                    if math.floor(e.im / bt[1]) % 2 == 1 and left <= bt[2] * 60 then due = due or bt[2] end
                end
                local done = e.imAt == at and e.imT or nil
                if due and (not done or due < done) then
                    e.imAt, e.imT = at, due
                    ns.Fire("IMPORTANT", e, at, math.ceil(left / 60))
                end
            end
        end
    end
end

-- "Tell everyone now": once, while the event hasn't started (not my own; anSeen is never sent).
local function AnnounceImportant(now)
    local store = Cal.Store()
    if not store then return end
    for key, e in pairs(store) do
        if e.an and not e.anSeen and e.owner ~= ns.me and e.at and Cal.IsImportant(e) then
            e.anSeen = true
            local at = Cal.NextAt(e, now)
            if at > now then ns.Fire("IMPORTANT_NEW", e, at, key) end
        end
    end
end

-- Does an important reminder at 15 minutes cover this event (so the normal one doesn't fire too)?
local function Covered(e) return Cal.IsImportant(e) and (e.im or 0) % 2 == 1 end

local reminded = {}
local function Remind()
    local now = GetServerTime()
    RemindImportant(now)
    AnnounceImportant(now)
    if not ns.settings.remind then return end
    for _, u in ipairs(Cal.Upcoming(10)) do
        local mine = Cal.MyAnswer(u.e, u.at)
        local going = mine == "y" or mine == "m" or u.e.owner == ns.me
        local left = u.at - now
        local id = u.key .. "@" .. u.at
        if going and left > 0 and left <= 15 * 60 and not reminded[id] and not Covered(u.e) then
            reminded[id] = true
            ns.Fire("REMIND", u.e, u.at)
        end
    end
end
Cal.CheckReminders = Remind

ns.Listen("LOGIN", function()
    C_Timer.After(5, function() ns.Safe(Tidy) end)
    C_Timer.NewTicker(30, function() ns.Safe(Remind) end)
    C_Timer.NewTicker(600, function() ns.Safe(Tidy) end)
end)
ns.Listen("ROSTER", function() if ns.Guild.complete then ns.Safe(Tidy) end end)
