-- Craft requests: "can someone make me 2 Linen Bags?" posted to the guild; crafters who know the
-- recipe get a pop-up and say "I'll make it" (everyone sees who's on it); the poster marks it done.
--
-- Messages
--   RQ  { id, rid, it, n, note, u, ev }   my request: recipe ID (if picked from a recipe, else nil),
--                                         item text, how many, note, ends (server time), version
--   RQ  { id, ev, x = "done" | "cancel" } finished or cancelled
--   RQ  { id, ev, x = "done", mk = { names } }  done, and who made it (0.12.0; the poster ticks them,
--                                         or the one guildie who said "I'll make it")
--   RQ  { o = owner, ..., cl = { names } }  a copy (WHISPER, only from a guildie we asked), with who's on it
--   CL  { o, id }  /  { o, id, x = true } I'll make it / I can't after all (GUILD; the sender is the crafter)
--   REQ { w = "RQS" }                     send me the open requests (WHISPER)
--   RQX { o, id, ev }                     a Professions moderator removes someone's request (GUILD;
--                                         WHISPER to a poster who comes back with it)
-- Only the poster changes or ends their request (sender from the game), or a Professions moderator
-- removes it (Board.lua): it ends as cancelled, marked rm = moderator, for good. Everyone keeps a copy per
-- guild so requests stay up while the poster is offline. Requests end after 3 days.
--
-- History (so people can see what's been asked for, and nobody abuses it): finished requests
-- (done, cancelled, or ran out after 3 days) stay for 30 days with who said they'd make them. The
-- History view lists them and sums up one guildie's record. Guildies who log in later get the last
-- week's finished ones in the copies.
--
-- The Crafty Bugger (0.12.0): 1 point for each request marked done in the last 30 days that
-- names you as the one who made it. Points go to the person (Alts.lua: all their characters count
-- as one), never for your own requests. Counted from the requests everyone holds, so every client
-- agrees: done requests with makers stay in the copies for the full 30 days (others for a week).
-- The most points (at least BUGGER_MIN) wins; a tie goes to whoever got there first.
local ADDON, ns = ...
local L = ns.L

local R = {}
ns.Requests = R

R.LASTS = 3 * 86400
R.KEEP_LOG = 30 * 86400        -- finished requests stay this long, for the History view
local COPY_ENDED = 7 * 86400    -- finished ones newer than this go to guildies who ask
local MAX_STORE = 500
local MAX_OPEN = 5              -- open requests per guildie
local MAX_ITEM, MAX_NOTE = 50, 80
local ASK_WINDOW = 300
local MAX_COPIES = 100
local MAX_MAKERS = 5
R.BUGGER_MIN = 3

local function Clean(s, max) return type(s) == "string" and ns.CutBytes((s:gsub("[|\n\r]", "")), max) or "" end
local Future = ns.Future

function R.Store()
    local g = ns.GuildData()
    if not g then return nil end
    if type(g.requests) ~= "table" then g.requests = {} end
    return g.requests
end

local function Changed() ns.Fire("REQUESTS") end

-- The item's name: the recipe's (on this client) when it has one, else the text typed.
function R.ItemName(r)
    if r.rid then
        local n = ns.Prof.RecipeName(r.rid)
        if n and not n:match("^" .. L.RECIPE_N:gsub("%%d", "%%d+") .. "$") then return n end
    end
    return r.it ~= "" and r.it or "?"
end

-- The profession a request is for (nil if typed without a recipe and nobody's list knows it).
function R.Line(r)
    if r.rid then
        if ns.Prof.Fresh then ns.Prof.Fresh() end
        local rec = ns.Prof.recipes[r.rid]
        if rec then return rec.line end
        for line, d in pairs(ns.Prof.MyData().profs) do
            for _, id in ipairs(d.i or {}) do if id == r.rid then return line end end
        end
    end
    return nil
end

-- The recipe with exactly this name in the guild's lists (or mine), or nil.
function R.RecipeFor(name)
    name = strlower(strtrim(name or ""))
    if name == "" then return nil end
    for _, e in ipairs(ns.Prof.Search(nil, name)) do
        if strlower(e.name) == name then return e.id end
    end
    return nil
end

-- Can I make it? (I know the recipe, or a recipe of mine has exactly that name.)
local myIds, myNames = nil, nil          -- my recipes, by ID and lower-case name (rebuilt when they change)
ns.Listen("PROFS", function() myIds, myNames = nil, nil end)

function R.ICanMake(r)
    if not myIds then
        myIds, myNames = {}, {}
        for _, d in pairs(ns.Prof.MyData().profs) do
            for _, id in ipairs(d.i or {}) do
                myIds[id] = true
                myNames[strlower(ns.Prof.RecipeName(id))] = true
            end
        end
    end
    if r.rid and myIds[r.rid] then return true end
    return myNames[strlower(R.ItemName(r))] == true
end

-- Who else could make it, from the guild's recipe lists (for the card).
function R.Crafters(r)
    if ns.Prof.Search then ns.Prof.Search(nil, "") end    -- makes sure the guild index is built
    local rec = r.rid and ns.Prof.recipes[r.rid]
    return rec and rec.crafters or {}
end

-- Open requests (and recently finished), newest first; mine first. line filters by profession.
function R.List(line)
    local store = R.Store()
    local list = {}
    if not store then return list end
    local now = GetServerTime()
    for key, r in pairs(store) do
        if not r.x and r.u > now and (r.owner == ns.me or ns.Guild.IsMember(r.owner)) then
            if not line or R.Line(r) == line then
                r.key = key
                list[#list + 1] = r
            end
        end
    end
    local can = {}
    for _, r in ipairs(list) do can[r] = R.ICanMake(r) end
    table.sort(list, function(a, b)
        local am, bm = a.owner == ns.me, b.owner == ns.me
        if am ~= bm then return am end
        local ac, bc = can[a], can[b]
        if ac ~= bc then return ac end
        return (a.at or 0) > (b.at or 0)
    end)
    return list
end

-- When a request finished (done or cancelled, or ran out), or nil while it's still open.
function R.EndTime(r, now)
    if r.x then return r.endAt or r.ev end
    now = now or GetServerTime()
    if r.u and r.u <= now then return r.u end
    return nil
end

function R.Outcome(r)
    if r.x == "done" then return "done" end
    if r.x == "cancel" then return "cancel" end
    return "expired"
end

-- Finished requests for the History view, newest first. filter matches a name or the item.
function R.History(line, filter)
    local store = R.Store()
    local list = {}
    if not store then return list end
    local now = GetServerTime()
    filter = strlower(strtrim(filter or ""))
    for key, r in pairs(store) do
        local ended = R.EndTime(r, now)
        if ended and (not line or R.Line(r) == line) then
            local keep = filter == ""
            if not keep then
                keep = strfind(strlower(r.owner), filter, 1, true) or strfind(strlower(R.ItemName(r)), filter, 1, true)
                if not keep then
                    for name in pairs(r.cl or {}) do if strfind(strlower(name), filter, 1, true) then keep = true end end
                end
            end
            if keep then r.key, r.ended = key, ended; list[#list + 1] = r end
        end
    end
    table.sort(list, function(a, b) return a.ended > b.ended end)
    return list
end

-- One guildie's record over the last 30 days: what they asked for and how it went, and what they
-- made (or said they'd make) for others.
function R.Record(name)
    local s = { asked = 0, done = 0, cancel = 0, expired = 0, open = 0, made = 0, letDown = 0 }
    local store = R.Store()
    if not store then return s end
    local now = GetServerTime()
    for _, r in pairs(store) do
        local ended = R.EndTime(r, now)
        local outcome = ended and R.Outcome(r)
        if r.owner == name then
            s.asked = s.asked + 1
            if outcome then s[outcome] = s[outcome] + 1 else s.open = s.open + 1 end
        elseif r.x == "done" and r.mk then
            if r.mk[name] then s.made = s.made + 1 end
        elseif r.cl and r.cl[name] and not (r.clRelayed and r.clRelayed[name]) then
            if outcome == "done" then s.made = s.made + 1
            elseif outcome == "expired" then s.letDown = s.letDown + 1 end
        end
    end
    return s
end

-- The guildie a filter means, if it matches exactly one name (full name or first name).
function R.WhoIs(filter)
    filter = strlower(strtrim(filter or ""))
    if #filter < 2 then return nil end
    local found
    for _, m in ipairs(ns.Guild.list) do
        local full = strlower(m.name)
        if full == filter or strlower(m.name:match("^%S+") or "") == filter then
            if found and found ~= m.name then return nil end
            found = m.name
        end
    end
    return found
end

function R.OpenCount()
    local n = 0
    for _ in ipairs(R.List()) do n = n + 1 end
    return n
end

function R.Claimers(r)
    local list = {}
    for name in pairs(r.cl or {}) do list[#list + 1] = name end
    table.sort(list)
    return list
end

---------------------------------------------------------------------------------------------------
-- The Crafty Bugger (see the top)

local board, boardAt = nil, -1000

local function Board()
    local now = GetServerTime()
    if board and now - boardAt < 60 then return board end
    local done = {}
    for _, r in pairs(R.Store() or {}) do
        if r.x == "done" and r.mk and (r.owner == ns.me or ns.Guild.IsMember(r.owner)) then
            local e = R.EndTime(r, now) or 0
            if e > now - R.KEEP_LOG then done[#done + 1] = { r = r, e = e } end
        end
    end
    table.sort(done, function(a, b)
        if a.e ~= b.e then return a.e < b.e end
        if a.r.owner ~= b.r.owner then return a.r.owner < b.r.owner end
        return a.r.id < b.r.id
    end)
    local pts, reached = {}, {}
    local Person = ns.Alts.Person
    for _, d in ipairs(done) do
        local owner = Person(d.r.owner)
        local got = {}
        for name in pairs(d.r.mk) do
            local who = Person(name)
            if who ~= owner and not got[who] and (name == ns.me or ns.Guild.IsMember(name)) then
                got[who] = true
                pts[who] = (pts[who] or 0) + 1
                reached[who] = d.e
            end
        end
    end
    local list = {}
    for name, n in pairs(pts) do list[#list + 1] = { name = name, n = n, at = reached[name] } end
    table.sort(list, function(a, b)
        if a.n ~= b.n then return a.n > b.n end
        if a.at ~= b.at then return a.at < b.at end
        return a.name < b.name
    end)
    local top = list[1] and list[1].n >= R.BUGGER_MIN and list[1].name or nil
    board, boardAt = { list = list, pts = pts, top = top }, now
    return board
end
ns.Listen("REQUESTS", function() board = nil end)
ns.Listen("ROSTER", function() board = nil end)
ns.Listen("ALTS", function() board = nil end)

-- Everyone with points, most first: { { name (the person's main), n, at } }.
function R.Top(max)
    local list, out = Board().list, {}
    for i = 1, math.min(#list, max or 10) do out[i] = list[i] end
    return out
end

-- A character's points (their person's).
function R.Points(name) return Board().pts[ns.Alts.Person(name)] or 0 end

-- The Crafty Bugger (the person's main), or nil.
function R.CraftyBugger() return Board().top end

-- Is this character the Crafty Bugger (or one of their characters)?
function R.IsCraftyBugger(name)
    local top = Board().top
    return top ~= nil and name ~= nil and ns.Alts.Person(name) == top
end

---------------------------------------------------------------------------------------------------
-- Mine

local function RequestMessage(r)
    return { t = "RQ", id = r.id, rid = r.rid, it = r.it, n = r.n, note = r.note, u = r.u, ev = r.ev }
end

function R.Post(rid, item, n, note)
    local store = R.Store()
    if not store or not ns.me then return nil end
    if type(rid) ~= "number" then rid = nil end
    item = Clean(item, MAX_ITEM)
    if not rid and item == "" then return nil end
    local now = GetServerTime()
    local open = 0
    for _, r in pairs(store) do if r.owner == ns.me and not r.x and r.u > now then open = open + 1 end end
    if open >= MAX_OPEN then return nil, "full" end
    local id = now
    while store[ns.me .. ":" .. id] do id = id + 1 end
    local r = { owner = ns.me, id = id, rid = rid, it = rid and Clean(ns.Prof.RecipeName(rid), MAX_ITEM) or item,
                n = math.max(1, math.min(20, math.floor(tonumber(n) or 1))), note = Clean(note, MAX_NOTE),
                u = now + R.LASTS, at = now, ev = now, cl = {}, direct = true }
    local key = ns.me .. ":" .. id
    store[key] = r
    ns.Comm.Send(RequestMessage(r), "GUILD")
    Changed()
    return key
end

-- Who made it, as a list (sorted), or nil.
local function MakerList(r)
    if not r.mk then return nil end
    local list = {}
    for n in pairs(r.mk) do list[#list + 1] = n end
    if #list == 0 then return nil end
    table.sort(list)
    return list
end
R.Makers = function(r) return MakerList(r) or {} end

-- Done (makers: the names the poster ticked; left out, the one guildie on it if there's only one)
-- or cancelled.
function R.Finish(key, how, makers)
    local store = R.Store()
    local r = store and store[key]
    if not r or r.owner ~= ns.me or r.x then return end
    r.x = (how == "done") and "done" or "cancel"
    r.ev = math.max(GetServerTime(), r.ev + 1)
    r.endAt = GetServerTime()
    if r.x == "done" then
        if makers == nil then
            local on = R.Claimers(r)
            makers = (#on == 1) and on or {}
        end
        local mk, n = {}, 0
        for _, name in ipairs(makers) do
            if n < MAX_MAKERS and name ~= ns.me and ns.Guild.IsMember(name) and not mk[name] then mk[name] = true; n = n + 1 end
        end
        r.mk = next(mk) and mk or nil
    end
    ns.Comm.Send({ t = "RQ", id = r.id, ev = r.ev, x = r.x, mk = MakerList(r) }, "GUILD")
    Changed()
end

-- Professions moderators remove anyone's open request (/ynm dev editor on: on this screen only).
function R.CanRemove() return ns.Board and ns.Board.Moderates("prof") or false end

function R.ModRemove(key)
    local store = R.Store()
    local r = store and store[key]
    if not r or r.x or r.owner == ns.me or not R.CanRemove() then return false end
    local now = GetServerTime()
    r.x, r.rm, r.endAt, r.direct = "cancel", ns.me, now, true
    r.ev = math.max(now, (r.ev or 0) + 1)
    if ns.Board.CanModerate(ns.me, "prof") then
        ns.Comm.Send({ t = "RQX", o = r.owner, id = r.id, ev = r.ev }, "GUILD")
    end
    Changed()
    return true
end

-- I'll make it (or, again, I can't after all).
function R.Claim(key, on)
    local store = R.Store()
    local r = store and store[key]
    if not r or r.x or r.owner == ns.me then return end
    r.cl = r.cl or {}
    r.cl[ns.me] = on and GetServerTime() or nil
    ns.Comm.Send({ t = "CL", o = r.owner, id = r.id, x = (not on) or nil }, "GUILD")
    Changed()
end

---------------------------------------------------------------------------------------------------
-- Receiving

local asked = {}

-- The makers a done message names (guildies, not the poster), or nil.
local function ReadMakers(owner, msg)
    if msg.x ~= "done" or type(msg.mk) ~= "table" then return nil end
    local mk, n = {}, 0
    for i = 1, math.min(#msg.mk, MAX_MAKERS) do
        local name = type(msg.mk[i]) == "string" and ns.Key(msg.mk[i])
        if name and name ~= owner and (name == ns.me or ns.Guild.IsMember(name)) and not mk[name] then mk[name] = true; n = n + 1 end
    end
    return n > 0 and mk or nil
end

local function Take(owner, msg, direct)
    local store = R.Store()
    if not store or owner == ns.me or not ns.Guild.IsMember(owner) then return false end
    if type(msg.id) ~= "number" or Future(msg.ev, not direct) then return false end
    local key = owner .. ":" .. msg.id
    local old = store[key]
    if old and old.rm then return false end
    -- Who said they'd make it counts (in records) only from the crafter's own CL message. Names riding
    -- along on a request (from the poster's whisper or a copy) are shown but marked relayed and never
    -- counted, so nobody can speak for a crafter.
    if old then
        -- The poster's own message always wins; a copy wins when it's newer (done or cancelled while
        -- we were offline).
        local newer = ns.Newer(old.ev, old.direct, msg.ev, direct)
        -- The same "done" without who made it (heard by 0.11 before updating): take the makers.
        if not newer and old.x == "done" and msg.x == "done" and old.ev == msg.ev and not old.mk then
            local mk = ReadMakers(owner, msg)
            if mk then old.mk = mk; return true end
        end
        if not newer then
            -- Still merge who's on it from a copy.
            if type(msg.cl) == "table" then
                for _, name in ipairs(msg.cl) do
                    name = type(name) == "string" and ns.Key(name)
                    if name and ns.Guild.IsMember(name) then
                        old.cl = old.cl or {}
                        if not old.cl[name] then old.cl[name] = msg.ev; old.clRelayed = old.clRelayed or {}; old.clRelayed[name] = true end
                    end
                end
            end
            return false
        end
    end
    local now = GetServerTime()
    if msg.x == "done" or msg.x == "cancel" then
        -- A finished request; from a copy it brings what was asked for and who was on it, for History.
        -- A "done" for a request we never saw, with nothing about what it was, is no use to anyone.
        if not old and not (type(msg.rid) == "number" or (type(msg.it) == "string" and msg.it ~= "")) then return false end
        local r = old or { owner = owner, id = msg.id, cl = {} }
        if not old then
            r.rid = type(msg.rid) == "number" and msg.rid > 0 and math.floor(msg.rid) or nil
            r.it, r.note = Clean(msg.it, MAX_ITEM), Clean(msg.note, MAX_NOTE)
            r.n = math.max(1, math.min(20, math.floor(tonumber(msg.n) or 1)))
            r.u = type(msg.u) == "number" and math.min(msg.u, now + R.LASTS) or msg.ev
            r.at = type(msg.at) == "number" and math.min(msg.at, now) or (r.u - R.LASTS)
        end
        if type(msg.cl) == "table" then
            for _, name in ipairs(msg.cl) do
                name = type(name) == "string" and ns.Key(name)
                if name and ns.Guild.IsMember(name) and not r.cl[name] then
                    r.cl[name] = msg.ev; r.clRelayed = r.clRelayed or {}; r.clRelayed[name] = true
                end
            end
        end
        r.x, r.ev, r.direct, r.endAt = msg.x, msg.ev, direct or nil, math.min(msg.ev, now)
        r.mk = ReadMakers(owner, msg)
        local rm = msg.x == "cancel" and type(msg.rm) == "string" and ns.Key(msg.rm) or nil
        if rm and ns.Board.CanModerate(rm, "prof") then r.rm = rm end
        store[key] = r
        return true
    end
    -- At most MAX_OPEN open from one guildie. Their own addon never has more than that open, so a
    -- newer one past the limit means our oldest open copy is stale (finished while we were offline,
    -- and the news hasn't reached us yet): the newer one takes its place. Found by tests/multi.py.
    if not old then
        local open, oldestKey, oldestEv = 0, nil, nil
        for k, r in pairs(store) do
            if r.owner == owner and not r.x and r.u > now then
                open = open + 1
                if not oldestEv or r.ev < oldestEv then oldestKey, oldestEv = k, r.ev end
            end
        end
        if open >= MAX_OPEN then
            if not oldestKey or msg.ev <= oldestEv then return false end
            store[oldestKey] = nil
        end
    end
    local rid = type(msg.rid) == "number" and msg.rid > 0 and math.floor(msg.rid) or nil
    local it = Clean(msg.it, MAX_ITEM)
    if not rid and it == "" or type(msg.u) ~= "number" then
        ns.Log("dropped: bad request from " .. owner)
        return false
    end
    local r = old or { owner = owner, id = msg.id, at = now, cl = {} }
    r.rid, r.it, r.note = rid, it, Clean(msg.note, MAX_NOTE)
    r.n = math.max(1, math.min(20, math.floor(tonumber(msg.n) or 1)))
    r.u = math.min(msg.u, now + R.LASTS)
    r.ev, r.x, r.direct, r.mk = msg.ev, nil, direct or nil, nil
    if type(msg.cl) == "table" then
        for _, name in ipairs(msg.cl) do
            name = type(name) == "string" and ns.Key(name)
            if name and ns.Guild.IsMember(name) and not r.cl[name] then
                    r.cl[name] = msg.ev; r.clRelayed = r.clRelayed or {}; r.clRelayed[name] = true
                end
        end
    end
    store[key] = r
    if not old and direct then ns.Fire("REQUEST_POSTED", r) end
    return true
end

-- The poster came back with a request a moderator removed: a moderator who holds it tells them.
local toldPoster = {}
local function TellPoster(owner, r)
    if not ns.Board.CanModerate(ns.me, "prof") or (ns.Sim and ns.Sim.IsFake(owner)) then return end
    local k = owner .. ":" .. r.id
    if toldPoster[k] and GetTime() - toldPoster[k] < 60 then return end
    toldPoster[k] = GetTime()
    ns.Comm.Send({ t = "RQX", o = owner, id = r.id, ev = r.ev }, "WHISPER", owner, "BULK")
end

ns.Comm.On("RQ", function(msg, from, channel, isSelf)
    if isSelf then return end
    if msg.o == nil then
        local store = R.Store()
        local held = store and type(msg.id) == "number" and store[from .. ":" .. msg.id]
        if held and held.rm and msg.rm == nil then TellPoster(from, held) end
        if Take(from, msg, true) then Changed() end
        return
    end
    if channel ~= "WHISPER" or not asked[from] or GetTime() - asked[from] > ASK_WINDOW then
        ns.Log("dropped: a request copy from " .. from .. " that we didn't ask for")
        return
    end
    asked[from] = GetTime()
    local owner = ns.Key(msg.o)
    if owner and owner ~= from and Take(owner, msg, false) then Changed() end
end)

-- A Professions moderator removed someone's request. It can be mine: then it ends for me too.
ns.Comm.On("RQX", function(msg, from, channel, isSelf)
    if isSelf or (channel ~= "GUILD" and channel ~= "WHISPER") then return end
    if not ns.Board.CanModerate(from, "prof") then
        ns.Log("dropped: a request removal from " .. from .. ", who doesn't moderate Professions")
        return
    end
    local store = R.Store()
    local owner = type(msg.o) == "string" and ns.Key(msg.o) or nil
    local r = store and owner and type(msg.id) == "number" and store[owner .. ":" .. msg.id]
    if not r or r.rm or owner == from or type(msg.ev) ~= "number" or Future(msg.ev, false) then return end
    local was = not r.x
    local now = GetServerTime()
    r.x, r.rm, r.direct = "cancel", from, true
    r.endAt = r.endAt or now
    r.ev = math.max(msg.ev, (r.ev or 0) + (owner == ns.me and 1 or 0))
    if owner == ns.me and was then ns.Print(string.format(L.RQ_REMOVED_MINE, from, R.ItemName(r))) end
    Changed()
end)

ns.Comm.On("CL", function(msg, from, channel, isSelf)
    if isSelf or channel ~= "GUILD" then return end
    local store = R.Store()
    local owner = type(msg.o) == "string" and ns.Key(msg.o) or nil
    local r = store and owner and type(msg.id) == "number" and store[owner .. ":" .. msg.id]
    if not r or r.x or from == owner then return end
    r.cl = r.cl or {}
    if msg.x == true then
        r.cl[from] = nil
    else
        local isNew = r.cl[from] == nil
        r.cl[from] = GetServerTime()
        if r.clRelayed then r.clRelayed[from] = nil end
        if isNew and owner == ns.me then ns.Fire("REQUEST_CLAIMED", from, r) end
    end
    Changed()
end)

-- Shared with guildies who log in later (copies, my own at log-in, Sync's counts): open ones, those
-- finished in the last week, and done ones with makers for the full 30 days (the Crafty Bugger).
local function Shared(r, now)
    local ended = R.EndTime(r, now)
    if not ended then return true end
    if r.x == "done" and r.mk and next(r.mk) then return ended > now - R.KEEP_LOG end
    return ended > now - COPY_ENDED
end

-- Copies: what I know, for a guildie who asks (mine go as mine).
local function Copies(forWhom)
    local store = R.Store()
    local out = {}
    if not store then return out end
    local now = GetServerTime()
    local list = {}
    for _, r in pairs(store) do
        if r.owner ~= forWhom and (r.owner == ns.me or ns.Guild.IsMember(r.owner)) and Shared(r, now) then
            list[#list + 1] = r
        end
    end
    table.sort(list, function(a, b) return (a.ev or 0) > (b.ev or 0) end)
    for i = 1, math.min(#list, MAX_COPIES) do
        local r = list[i]
        local m = RequestMessage(r)
        m.x, m.cl, m.at, m.mk, m.rm = r.x, R.Claimers(r), r.at, MakerList(r), r.rm
        if r.owner ~= ns.me then m.o = r.owner end
        out[#out + 1] = m
    end
    return out
end

local answered = {}
ns.Comm.On("REQ", function(msg, from, channel, isSelf)
    if isSelf or channel ~= "WHISPER" or msg.w ~= "RQS" then return end
    local now = GetTime()
    if answered[from] and now - answered[from] < 60 then return end
    answered[from] = now
    for _, m in ipairs(Copies(from)) do ns.Comm.Send(m, "WHISPER", from, "BULK") end
end)

-- My own requests as messages: open ones and those finished in the last week.
local function MyRequestMessages()
    local out = {}
    local store = R.Store()
    if not store then return out end
    local now = GetServerTime()
    for _, r in pairs(store) do
        if r.owner == ns.me and Shared(r, now) then
            local m = RequestMessage(r)
            m.x, m.cl, m.at, m.mk, m.rm = r.x, R.Claimers(r), r.at, MakerList(r), r.rm
            out[#out + 1] = m
        end
    end
    -- Finished ones first: whispers arrive in order, so a guildie's stale open copies are closed
    -- before the new open ones land (and don't count against the 5-open limit).
    table.sort(out, function(x, y)
        if (x.x and true or false) ~= (y.x and true or false) then return x.x and true or false end
        return (x.ev or 0) < (y.ev or 0)
    end)
    return out
end

ns.Listen("HI_IN", function(msg, from)
    if msg.ask ~= true or (ns.Sim and ns.Sim.IsFake(from)) then return end
    C_Timer.After(5 + math.random() * 4, function()
        for _, m in ipairs(MyRequestMessages()) do ns.Comm.Send(m, "WHISPER", from, "BULK") end
    end)
end)

-- When I log in, guildies already online who missed my changes catch up (Sync.lua).
-- Count only what MyRequestMessages sends (Shared), so a guildie never asks for a version that won't
-- come (an old finished one made them ask forever).
ns.Sync.Register("requests", function(author)
    local list = {}
    local now = GetServerTime()
    for _, r in pairs(R.Store() or {}) do
        if r.owner == author and Shared(r, now) then list[#list + 1] = r.ev end
    end
    return list
end, MyRequestMessages)

local function AskRequests()
    local peers = {}
    for name, u in pairs(ns.Comm.users) do
        local m = ns.Guild.Get(name)
        if name ~= ns.me and not u.sim and m and m.online then peers[#peers + 1] = name end
    end
    if #peers == 0 then return end
    local peer = peers[math.random(#peers)]
    asked[peer] = GetTime()
    ns.Comm.Send({ t = "REQ", w = "RQS" }, "WHISPER", peer)
end
ns.Listen("LOGIN", function() C_Timer.After(60, function() ns.Safe(AskRequests) end) end)

-- Tidy: finished ones go after 30 days (and the oldest if there are too many); departed guildies'
-- go (after a full roster read).
local function Tidy()
    local store = R.Store()
    if not store then return end
    local now = GetServerTime()
    local changed = false
    local ended = {}
    for key, r in pairs(store) do
        local e = R.EndTime(r)
        if (e and e < now - R.KEEP_LOG) or (ns.Guild.complete and r.owner ~= ns.me and not ns.Guild.IsMember(r.owner)) then
            store[key] = nil; changed = true
        elseif e then
            ended[#ended + 1] = { key, e }
        end
    end
    local count = 0
    for _ in pairs(store) do count = count + 1 end
    if count > MAX_STORE then
        table.sort(ended, function(a, b) return a[2] < b[2] end)
        for i = 1, math.min(#ended, count - MAX_STORE) do store[ended[i][1]] = nil end
        changed = true
    end
    if changed then Changed() end
end
ns.Listen("LOGIN", function()
    C_Timer.After(6, function() ns.Safe(Tidy) end)
    C_Timer.NewTicker(600, function() ns.Safe(Tidy) end)
end)
ns.Listen("ROSTER", function() if ns.Guild.complete then ns.Safe(Tidy) end end)
