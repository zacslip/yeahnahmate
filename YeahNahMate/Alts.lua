-- Alt links (0.12.0): a guildie's characters are linked automatically, so points and titles
-- (Lore Master, Crafty Bugger) go to the person, not the character they happened to be on.
--
-- How it knows: the addon's saved data is per WoW account, and every character that ran the addon
-- has an entry in it (ns.db.chars). So each character knows the account's other characters.
--
-- Why it's safe: each character only ever speaks for itself (the game says who sent a message).
-- Character A says "my characters are B and C"; A and B count as one person only when B says A
-- too. Nobody can claim a character they can't log into. Turning "Link my characters" off sends an
-- empty list, which breaks the links for everyone.
--
-- Messages
--   ALT { al = { names }, mn = main, ev }   my other characters in this guild, and which is the main
--   ALT { o = author, ... }                  a copy (WHISPER, only from a guildie we asked)
--   REQ { w = "ALT" }                        send me the alt links (WHISPER)
-- ev is the record's version (when it changed). The author's own message wins; copies when newer.
local ADDON, ns = ...

local Alts = {}
ns.Alts = Alts

local MAX = 20                  -- characters in one record
local ASK_WINDOW = 300
local Future = ns.Future

function Alts.Store()
    local g = ns.GuildData()
    if not g then return nil end
    if type(g.alts) ~= "table" then g.alts = {} end
    return g.alts
end

local cache = nil
local function Changed()
    cache = nil
    ns.Fire("ALTS")
end
ns.Listen("ROSTER", function() cache = nil end)

local function Member(name) return name == ns.me or ns.Guild.IsMember(name) end

---------------------------------------------------------------------------------------------------
-- Who is who

-- Do a and b both name each other?
local function Mutual(store, a, b)
    local ra, rb = store[a], store[b]
    return ra ~= nil and rb ~= nil and ra.al[b] == true and rb.al[a] == true
end

-- Every linked group: name -> the person's main, and main -> all their characters (sorted).
-- The main is the one the newest record names (all of one account's records name the same one,
-- unless one is out of date); if none names a character in the group, the first name.
local function Build()
    local store = Alts.Store() or {}
    local person, groups = {}, {}
    local names = {}
    for name in pairs(store) do if Member(name) then names[#names + 1] = name end end
    table.sort(names)
    local done = {}
    for _, start in ipairs(names) do
        if not done[start] then
            local group, queue, inGroup = {}, { start }, { [start] = true }
            done[start] = true
            while #queue > 0 do
                local a = table.remove(queue, 1)
                group[#group + 1] = a
                for b in pairs(store[a].al) do
                    if not inGroup[b] and Member(b) and Mutual(store, a, b) then
                        inGroup[b], done[b] = true, true
                        queue[#queue + 1] = b
                    end
                end
            end
            if #group > 1 then
                table.sort(group)
                local recs = {}
                for _, n in ipairs(group) do recs[#recs + 1] = { n = n, r = store[n] } end
                table.sort(recs, function(x, y)
                    if x.r.ev ~= y.r.ev then return x.r.ev > y.r.ev end
                    return x.n < y.n
                end)
                local main = group[1]
                for _, e in ipairs(recs) do
                    if e.r.mn and inGroup[e.r.mn] then main = e.r.mn; break end
                end
                groups[main] = group
                for _, n in ipairs(group) do person[n] = main end
            end
        end
    end
    cache = { person = person, groups = groups }
    return cache
end

-- The person behind a character: their main's name (the character's own name if not linked).
function Alts.Person(name)
    if not name then return name end
    return (cache or Build()).person[name] or name
end

-- All of a person's characters, main first: { main, alt, ... } ({ name } if not linked).
function Alts.Characters(name)
    local main = Alts.Person(name)
    local group = (cache or Build()).groups[main]
    if not group then return { name } end
    local out = { main }
    for _, n in ipairs(group) do if n ~= main then out[#out + 1] = n end end
    return out
end

function Alts.Same(a, b) return a ~= nil and b ~= nil and Alts.Person(a) == Alts.Person(b) end

---------------------------------------------------------------------------------------------------
-- Mine

-- The characters on this WoW account that are in this guild (me included), sorted.
function Alts.MyCharacters()
    local list = {}
    if not ns.me then return list end
    local chars = ns.db and type(ns.db.chars) == "table" and ns.db.chars or {}
    local seen = { [ns.me] = true }
    list[1] = ns.me
    for name in pairs(chars) do
        if type(name) == "string" and not seen[name] and ns.Guild.IsMember(name) and not (ns.Sim and ns.Sim.IsFake(name)) then
            seen[name] = true
            list[#list + 1] = name
        end
    end
    table.sort(list)
    return list
end

function Alts.Linking() return ns.settings.linkAlts ~= false end

-- My main: the one picked in Settings, else the highest level (then the first name).
function Alts.MyMain()
    local mine = Alts.MyCharacters()
    local g = ns.GuildData()
    local picked = g and g.myMain
    for _, n in ipairs(mine) do if n == picked then return picked end end
    local best, bestLevel = nil, -1
    for _, n in ipairs(mine) do
        local m = ns.Guild.Get(n)
        local lv = (n == ns.me and UnitLevel and UnitLevel("player")) or (m and tonumber(m.level)) or 0
        if lv > bestLevel then best, bestLevel = n, lv end
    end
    return best or ns.me
end

function Alts.SetMain(name)
    local g = ns.GuildData()
    if not g then return end
    g.myMain = name
    Alts.Publish()
end

function Alts.SetLinking(on)
    ns.settings.linkAlts = on and true or false
    Alts.Publish()
end

-- One of my characters: linked (both sides said so), or waiting for that character to log in once.
function Alts.IsLinked(name)
    local store = Alts.Store()
    return store ~= nil and ns.me ~= nil and Mutual(store, ns.me, name)
end

local function ListOf(set)
    local list = {}
    for n in pairs(set) do list[#list + 1] = n end
    table.sort(list)
    return list
end

local function Message(r) return { t = "ALT", al = ListOf(r.al), mn = r.mn, ev = r.ev } end

-- Say which characters are mine, when that changes. Only after a full roster read, so a character
-- isn't left out (and then put back) because the roster wasn't all there yet.
function Alts.Publish()
    local store = Alts.Store()
    if not store or not ns.me or not ns.Guild.complete then return end
    local al = {}
    if Alts.Linking() then
        for _, n in ipairs(Alts.MyCharacters()) do if n ~= ns.me then al[n] = true end end
    end
    local mn = next(al) and Alts.MyMain() or nil
    local old = store[ns.me]
    if old then
        local same = old.mn == mn
        for n in pairs(al) do if not old.al[n] then same = false end end
        for n in pairs(old.al) do if not al[n] then same = false end end
        if same then return end
    elseif not next(al) then
        return                  -- nothing to say, and never said anything
    end
    local r = { al = al, mn = mn, ev = math.max(GetServerTime(), (old and old.ev or 0) + 1), direct = true }
    store[ns.me] = r
    ns.Comm.Send(Message(r), "GUILD")
    Changed()
end
ns.Listen("ROSTER", function() ns.Safe(Alts.Publish) end)
ns.Listen("LOGIN", function()
    -- This character is one of the account's (Professions.lua makes the entry too, but not always first).
    if type(ns.db.chars) ~= "table" then ns.db.chars = {} end
    if ns.me and type(ns.db.chars[ns.me]) ~= "table" then ns.db.chars[ns.me] = {} end
end)

---------------------------------------------------------------------------------------------------
-- Receiving

local asked = {}

local function Take(author, msg, direct)
    local store = Alts.Store()
    if not store or author == ns.me or not ns.Guild.IsMember(author) then return false end
    if type(msg.ev) ~= "number" or Future(msg.ev, not direct) or type(msg.al) ~= "table" then return false end
    local old = store[author]
    if old and not ns.Newer(old.ev, old.direct, msg.ev, direct) then return false end
    local al = {}
    for i = 1, math.min(#msg.al, MAX) do
        local n = type(msg.al[i]) == "string" and ns.Key(msg.al[i])
        if n and n ~= author then al[n] = true end
    end
    local mn = type(msg.mn) == "string" and ns.Key(msg.mn) or nil
    store[author] = { al = al, mn = mn, ev = msg.ev, direct = direct or nil }
    return true
end

ns.Comm.On("ALT", function(msg, from, channel, isSelf)
    if isSelf then return end
    if msg.o == nil then
        if Take(from, msg, true) then Changed() end
        return
    end
    if channel ~= "WHISPER" or not asked[from] or GetTime() - asked[from] > ASK_WINDOW then
        ns.Log("dropped: alt links copy from " .. from .. " that we didn't ask for")
        return
    end
    asked[from] = GetTime()
    local author = ns.Key(msg.o)
    if author and author ~= from and Take(author, msg, false) then Changed() end
end)

-- What I hold, as messages (copies carry the author; mine go as mine). My other characters'
-- records are in this account's saved data too: they go as copies.
local function Everything(forWhom)
    local out = {}
    for name, r in pairs(Alts.Store() or {}) do
        if name ~= forWhom and Member(name) and not (ns.Sim and ns.Sim.IsFake(name)) then
            local m = Message(r)
            if name ~= ns.me then m.o = name end
            out[#out + 1] = m
        end
    end
    return out
end

local answered = {}
ns.Comm.On("REQ", function(msg, from, channel, isSelf)
    if isSelf or channel ~= "WHISPER" or msg.w ~= "ALT" then return end
    local now = GetTime()
    if answered[from] and now - answered[from] < 60 then return end
    answered[from] = now
    for _, m in ipairs(Everything(from)) do ns.Comm.Send(m, "WHISPER", from, "BULK") end
end)

-- A guildie who just logged in gets my own record from me.
ns.Listen("HI_IN", function(msg, from)
    if msg.ask ~= true or (ns.Sim and ns.Sim.IsFake(from)) then return end
    local store = Alts.Store()
    local r = store and ns.me and store[ns.me]
    if not r then return end
    C_Timer.After(4 + math.random() * 4, function() ns.Comm.Send(Message(r), "WHISPER", from, "BULK") end)
end)

ns.Sync.Register("alts", function(author)
    local store = Alts.Store()
    local r = store and store[author]
    return r and { r.ev } or {}
end, function()
    local store = Alts.Store()
    local r = store and ns.me and store[ns.me]
    return r and { Message(r) } or {}
end)

-- After login, ask one online guildie for everyone's links.
local function AskAlts()
    local peers = {}
    for name, u in pairs(ns.Comm.users) do
        local m = ns.Guild.Get(name)
        if name ~= ns.me and not u.sim and m and m.online then peers[#peers + 1] = name end
    end
    if #peers == 0 then return end
    local peer = peers[math.random(#peers)]
    asked[peer] = GetTime()
    ns.Comm.Send({ t = "REQ", w = "ALT" }, "WHISPER", peer)
end
ns.Listen("LOGIN", function() C_Timer.After(55, function() ns.Safe(AskAlts) end) end)

-- Departed guildies' records go (after a full roster read).
ns.Listen("ROSTER", function()
    local store = Alts.Store()
    if not store or not ns.Guild.complete then return end
    local gone = false
    for name in pairs(store) do
        if name ~= ns.me and not ns.Guild.IsMember(name) and not (ns.Sim and ns.Sim.IsFake(name)) then
            store[name] = nil; gone = true
        end
    end
    if gone then Changed() end
end)

-- Sim mode off: the fake guildies' records go.
function Alts.PurgeFakes(isFake)
    local store = Alts.Store()
    if not store then return end
    for name in pairs(store) do if isFake(name) then store[name] = nil end end
    Changed()
end
