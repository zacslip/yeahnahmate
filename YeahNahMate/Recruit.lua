-- Recruiters (Phase 13): guildies share the addon with guildies who don't have it, and say who got them
-- onto it; a leaderboard counts who brought the most people on (all time and this month).
--
-- Share: our own whisper box (UI/Whisper.lua) opens to a guildie without the addon, prefilled with my
-- recruitment message (Settings). Nothing goes until I press Enter there; only then is the share noted.
-- Claim: "Who got you onto Yeah Nah Mate?", answered once per person (alts count as one), final. Skip
-- is an answer too, so the question doesn't come back.
-- Hide: the guild master or a manager takes a wrong claim off the leaderboard.
--
-- Fair counting: people, not characters (Alts.Person): a recruiter's alts add up, a recruit's alts count
-- once, nobody recruits themselves or their own alts. Only guildies still in the guild count, on both
-- sides. A recruit who stops using the addon still counts. One share per guildie per 7 days.
--
-- Messages
--   RSH { to, at }          I shared the addon with `to` at server time `at` (GUILD)
--   RCL { by, at }          I was recruited by `by` ("" = skipped). Final. (GUILD)
--   RHD { who, at }         a manager hides `who`'s claim (GUILD, from the manager)
--   Copies (to a guildie who asks, by whisper) carry o = the author: RSH { o, to, at },
--   RCL { o, by, at }, RHD { o = the manager, who, at }.
--   REQ { w = "RCT" }       send me what you hold (after log-in, one guildie)
local ADDON, ns = ...

local R = {}
ns.Recruit = R

local SHARE_KEEP = 30 * 86400   -- shares are only needed to suggest names; claims are kept
local SHARE_AGAIN = 7 * 86400   -- one share per guildie per week
local PENDING = 600             -- a Share button press counts if the whisper goes within 10 minutes
local ASK_WINDOW = 300
R.TOP = 10

local function Changed() ns.Fire("RECRUIT") end

function R.Store()
    local g = ns.GuildData()
    if not g then return nil end
    local s = g.recruit
    if type(s) ~= "table" then s = {}; g.recruit = s end
    if type(s.shares) ~= "table" then s.shares = {} end
    if type(s.claims) ~= "table" then s.claims = {} end
    if type(s.hidden) ~= "table" then s.hidden = {} end
    return s
end

local function Person(name) return ns.Alts and ns.Alts.Person(name) or name end
local function Same(a, b) return a == b or (ns.Alts and ns.Alts.Same(a, b)) or false end
local function Member(name) return name == ns.me or ns.Guild.IsMember(name) end

-- Has this guildie ever shown up with the addon (this session or saved)?
function R.HasAddon(name) return ns.Comm.users[name] ~= nil end

-- May the guild master or a manager hide claims? (On my roster.)
function R.CanHide(name) return ns.Board.IsManager(name) end
function R.ICanHide()
    if R.CanHide(ns.me) then return true end
    -- Test mode (/ynm dev editor, or rank 0): on this screen only (R.Hide keeps it here).
    return ns.Board.Testing() and ns.Board.ShownGuildMaster()
end

-- The recruitment message: mine from Settings, or the default.
function R.Message()
    local m = ns.settings and ns.settings.recruitMsg
    if type(m) == "string" and strtrim(m) ~= "" then return m end
    return ns.L.RECRUIT_MSG_DEFAULT
end

---------------------------------------------------------------------------------------------------
-- Sharing

local pending = {}              -- to -> GetTime() of my Share press

-- When did I last share with this guildie (any of my characters)? Server time or nil.
function R.LastShare(to)
    local s = R.Store()
    if not s then return nil end
    local last
    for author, list in pairs(s.shares) do
        if Same(author, ns.me) and list[to] and (not last or list[to].at > last) then last = list[to].at end
    end
    return last
end

-- Can I share with this guildie? Online, in the guild, not me, no addon, not shared this week.
function R.CanShareTo(name)
    if not name or Same(name, ns.me) then return false end
    local m = ns.Guild.Get(name)
    -- Fake guildies without the addon count too (sim mode, to try it alone; nothing about them is sent).
    if not m or not m.online or R.HasAddon(name) then return false end
    local last = R.LastShare(name)
    return not (last and GetServerTime() - last < SHARE_AGAIN)
end

-- Guildies online now without the addon, by name. shared = when I last shared with them (this week).
function R.Candidates()
    local out = {}
    for _, m in ipairs(ns.Guild.list) do
        if m.online and m.name ~= ns.me and not Same(m.name, ns.me) and not R.HasAddon(m.name) then
            local last = R.LastShare(m.name)
            out[#out + 1] = { name = m.name, class = m.class, level = m.level,
                              shared = (last and GetServerTime() - last < SHARE_AGAIN) and last or nil }
        end
    end
    table.sort(out, function(a, b) return a.name < b.name end)
    return out
end

-- The Share button: our whisper box, prefilled. The share is noted only when the whisper goes.
function R.Share(name)
    if not R.CanShareTo(name) then return false end
    pending[name] = GetTime()
    ns.Whisper.Open(ns.Guild.Get(name), R.Message())
    return true
end

local function ShareMessage(author, to, e)
    local m = { t = "RSH", to = to, at = e.at }
    if author ~= ns.me then m.o = author end
    return m
end

-- Note a share that really went out (the whisper box sent it).
local function Shared(to)
    local s = R.Store()
    if not s then return end
    s.shares[ns.me] = s.shares[ns.me] or {}
    local e = { at = GetServerTime() }
    s.shares[ns.me][to] = e
    ns.Comm.Send(ShareMessage(ns.me, to, e), "GUILD")
    Changed()
end

ns.Listen("WHISPERED", function(to)
    local t = to and pending[to]
    if not t then return end
    pending[to] = nil
    if GetTime() - t <= PENDING then ns.Safe(Shared, to) end
end)

---------------------------------------------------------------------------------------------------
-- Claims

-- The claim made by this person (any of their characters), or nil: { owner, by, at }. The earliest
-- one counts (one answer per person); a hidden one still counts as answered.
function R.ClaimOf(name)
    local s = R.Store()
    if not s then return nil end
    local who = Person(name)
    local best
    for owner, c in pairs(s.claims) do
        if Person(owner) == who and (not best or c.at < best.at or (c.at == best.at and owner < best.owner)) then
            best = { owner = owner, by = c.by, at = c.at }
        end
    end
    return best
end

function R.MyClaim() return R.ClaimOf(ns.me) end

-- Should my tab show the "!" (I haven't answered)?
function R.NeedsAnswer() return ns.me ~= nil and R.Store() ~= nil and R.MyClaim() == nil end

-- Who shared the addon with me (any of my characters), newest first: { name, at }.
function R.SharedWithMe()
    local out, seen = {}, {}
    local s = R.Store()
    if not s then return out end
    for author, list in pairs(s.shares) do
        for to, e in pairs(list) do
            if Same(to, ns.me) and not Same(author, ns.me) and Member(author) then
                local p = Person(author)
                if not seen[p] or e.at > seen[p].at then
                    seen[p] = { name = author, at = e.at }
                end
            end
        end
    end
    for _, v in pairs(seen) do out[#out + 1] = v end
    table.sort(out, function(a, b) if a.at ~= b.at then return a.at > b.at end return a.name < b.name end)
    return out
end

-- Guildies I could name as my recruiter: in the guild, have the addon, not me or my alts.
function R.CanBeRecruiter(name)
    return name ~= nil and Member(name) and not Same(name, ns.me) and R.HasAddon(name)
end

local function ClaimMessage(owner, c)
    local m = { t = "RCL", by = c.by, at = c.at }
    if owner ~= ns.me then m.o = owner end
    return m
end

-- Answer the question: by = a guildie's name, or "" to skip. Once only.
function R.Claim(by)
    local s = R.Store()
    if not s or R.MyClaim() then return false end
    if by ~= "" and not R.CanBeRecruiter(by) then return false end
    local c = { by = by, at = GetServerTime() }
    s.claims[ns.me] = c
    ns.Comm.Send(ClaimMessage(ns.me, c), "GUILD")
    Changed()
    return true
end

---------------------------------------------------------------------------------------------------
-- Hiding a wrong claim (guild master and managers)

local function HideMessage(who, h)
    local m = { t = "RHD", who = who, at = h.at }
    if h.sb ~= ns.me then m.o = h.sb end
    return m
end

function R.Hide(who)
    local s = R.Store()
    if not s or not who or not R.ICanHide() or s.hidden[who] then return false end
    local h = { sb = ns.me, at = GetServerTime() }
    s.hidden[who] = h
    local msg = HideMessage(who, h)
    if R.CanHide(ns.me) then
        ns.Comm.Send(msg, "GUILD")
    else
        ns.Log("(dev) kept on this screen: your guild rank can't send RHD")
        ns.Fire("SENT", msg, "GUILD")
    end
    Changed()
    return true
end

function R.IsHidden(person)
    local s = R.Store()
    if not s then return false end
    for who in pairs(s.hidden) do if Person(who) == person then return true end end
    return false
end

---------------------------------------------------------------------------------------------------
-- The leaderboard

local function MonthOf(t) return date("%Y-%m", t) end

-- period "all" or "month". Returns { { name = recruiter person, n, recruits = { person, ... } }, ... },
-- most recruits first (ties: name).
function R.Leaderboard(period)
    local s = R.Store()
    local out = {}
    if not s then return out end
    local month = period == "month" and MonthOf(GetServerTime()) or nil
    -- One claim per recruit (person): the earliest.
    local per = {}
    for owner, c in pairs(s.claims) do
        local p = Person(owner)
        local cur = per[p]
        if not cur or c.at < cur.at or (c.at == cur.at and owner < cur.owner) then
            per[p] = { owner = owner, by = c.by, at = c.at }
        end
    end
    local by = {}
    for recruit, c in pairs(per) do
        if c.by ~= "" and Member(c.owner) and Member(c.by) and not Same(c.owner, c.by)
            and not R.IsHidden(recruit) and (not month or MonthOf(c.at) == month) then
            local who = Person(c.by)
            local e = by[who]
            if not e then e = { name = who, n = 0, recruits = {} }; by[who] = e end
            e.n = e.n + 1
            e.recruits[#e.recruits + 1] = recruit
        end
    end
    for _, e in pairs(by) do
        table.sort(e.recruits)
        out[#out + 1] = e
    end
    table.sort(out, function(a, b) if a.n ~= b.n then return a.n > b.n end return a.name < b.name end)
    return out
end

-- My place on a leaderboard: place, count (nil if I'm not on it).
function R.MyPlace(period)
    local me = Person(ns.me)
    for i, e in ipairs(R.Leaderboard(period)) do
        if e.name == me then return i, e.n end
    end
    return nil
end

---------------------------------------------------------------------------------------------------
-- Receiving

local asked = {}

local function TakeShare(author, msg)
    local s = R.Store()
    local to = type(msg.to) == "string" and ns.Key(msg.to) or nil
    if not to or not Member(author) or not Member(to) or Same(author, to) then return false end
    if ns.Future(msg.at, true) or GetServerTime() - msg.at >= SHARE_KEEP then return false end
    s.shares[author] = s.shares[author] or {}
    local old = s.shares[author][to]
    if old and old.at >= msg.at then return false end
    s.shares[author][to] = { at = msg.at }
    return true
end

local function TakeClaim(owner, msg)
    local s = R.Store()
    if type(msg.by) ~= "string" or ns.Future(msg.at, true) or not Member(owner) then return false end
    local by = msg.by == "" and "" or ns.Key(msg.by)
    if not by or (by ~= "" and (not Member(by) or Same(owner, by))) then
        ns.Log("dropped: a recruiter claim from " .. owner .. " that can't count")
        return false
    end
    local old = s.claims[owner]
    -- Final: the first answer stays (an earlier one replaces a later one if they crossed).
    if old and old.at <= msg.at then return false end
    s.claims[owner] = { by = by, at = msg.at }
    return true
end

local function TakeHide(sb, msg)
    local s = R.Store()
    local who = type(msg.who) == "string" and ns.Key(msg.who) or nil
    if not who or ns.Future(msg.at, true) then return false end
    if not R.CanHide(sb) then
        ns.Log("dropped: a hidden recruiter claim from " .. sb .. ", who isn't the guild master or a manager")
        return false
    end
    if s.hidden[who] then return false end
    s.hidden[who] = { sb = sb, at = msg.at }
    return true
end

local function Handler(take)
    return function(msg, from, channel, isSelf)
        if isSelf or not R.Store() then return end
        local author = from
        if msg.o ~= nil then
            -- A copy: only by whisper from a guildie we asked.
            if channel ~= "WHISPER" or not asked[from] or GetTime() - asked[from] > ASK_WINDOW then return end
            author = type(msg.o) == "string" and ns.Key(msg.o) or nil
            if not author then return end
        end
        if take(author, msg) then Changed() end
    end
end
ns.Comm.On("RSH", Handler(TakeShare))
ns.Comm.On("RCL", Handler(TakeClaim))
ns.Comm.On("RHD", Handler(TakeHide))
R.TakeShare, R.TakeClaim, R.TakeHide = TakeShare, TakeClaim, TakeHide

-- Everything I hold, as messages (copies for a guildie who asks).
local function Everything()
    local out = {}
    local s = R.Store()
    if not s then return out end
    local now = GetServerTime()
    for author, list in pairs(s.shares) do
        for to, e in pairs(list) do
            if now - e.at < SHARE_KEEP then out[#out + 1] = ShareMessage(author, to, e) end
        end
    end
    for owner, c in pairs(s.claims) do out[#out + 1] = ClaimMessage(owner, c) end
    for who, h in pairs(s.hidden) do out[#out + 1] = HideMessage(who, h) end
    return out
end
R.Everything = Everything

local answered = {}
ns.Comm.On("REQ", function(msg, from, channel, isSelf)
    if isSelf or channel ~= "WHISPER" or msg.w ~= "RCT" then return end
    local now = GetTime()
    if answered[from] and now - answered[from] < 60 then return end
    answered[from] = now
    for _, m in ipairs(Everything()) do ns.Comm.Send(m, "WHISPER", from, "BULK") end
end)

-- What I wrote: my shares, my claim, the claims I hid.
local function MineToSend()
    local out = {}
    local s = R.Store()
    if not s then return out end
    local now = GetServerTime()
    for to, e in pairs(s.shares[ns.me] or {}) do
        if now - e.at < SHARE_KEEP then out[#out + 1] = ShareMessage(ns.me, to, e) end
    end
    if s.claims[ns.me] then out[#out + 1] = ClaimMessage(ns.me, s.claims[ns.me]) end
    for who, h in pairs(s.hidden) do if h.sb == ns.me then out[#out + 1] = HideMessage(who, h) end end
    return out
end

ns.Sync.Register("recruit", function(author)
    local list = {}
    local s = R.Store()
    if not s then return list end
    for _, e in pairs(s.shares[author] or {}) do list[#list + 1] = e.at end
    if s.claims[author] then list[#list + 1] = s.claims[author].at end
    for _, h in pairs(s.hidden) do if h.sb == author then list[#list + 1] = h.at end end
    return list
end, MineToSend)

-- A guildie who just logged in gets what I wrote.
ns.Listen("HI_IN", function(msg, from)
    if msg.ask ~= true or (ns.Sim and ns.Sim.IsFake(from)) then return end
    local list = MineToSend()
    if #list == 0 then return end
    C_Timer.After(5 + math.random() * 4, function()
        for _, m in ipairs(list) do ns.Comm.Send(m, "WHISPER", from, "BULK") end
    end)
end)

-- After log-in, ask one online guildie for everything they hold.
local function AskAll()
    local peers = {}
    for name, u in pairs(ns.Comm.users) do
        local m = ns.Guild.Get(name)
        if name ~= ns.me and not u.sim and m and m.online then peers[#peers + 1] = name end
    end
    if #peers == 0 then return end
    local peer = peers[math.random(#peers)]
    asked[peer] = GetTime()
    ns.Comm.Send({ t = "REQ", w = "RCT" }, "WHISPER", peer)
end
ns.Listen("LOGIN", function() C_Timer.After(62, function() ns.Safe(AskAll) end) end)
R.AskAll = AskAll

-- Tidying: old shares; anything about guildies who left (once the roster is complete).
local function Tidy()
    local s = R.Store()
    if not s then return end
    local now = GetServerTime()
    local full = ns.Guild.complete
    for author, list in pairs(s.shares) do
        for to, e in pairs(list) do
            if now - e.at >= SHARE_KEEP or (full and (not Member(author) or not Member(to))) then list[to] = nil end
        end
        if next(list) == nil then s.shares[author] = nil end
    end
    if full then
        for owner in pairs(s.claims) do if not Member(owner) then s.claims[owner] = nil end end
        for who in pairs(s.hidden) do if not Member(who) then s.hidden[who] = nil end end
    end
end
ns.Listen("ROSTER", function() ns.Safe(Tidy) end)
R.Tidy = Tidy

---------------------------------------------------------------------------------------------------
-- Testing alone (sim mode; the dev console's Recruiters page). Everything here stays on this screen.

-- Sim off: forget everything about the fake guildies.
function R.PurgeFakes(isFake)
    local s = R.Store()
    if not s then return end
    for author, list in pairs(s.shares) do
        if isFake(author) then s.shares[author] = nil
        else for to in pairs(list) do if isFake(to) then list[to] = nil end end end
    end
    for owner, c in pairs(s.claims) do if isFake(owner) or isFake(c.by) then s.claims[owner] = nil end end
    for who in pairs(s.hidden) do if isFake(who) then s.hidden[who] = nil end end
    Changed()
end

local function FakesWithAddon()
    local out = {}
    for _, m in ipairs(ns.Guild.list) do
        if m.sim and R.HasAddon(m.name) then out[#out + 1] = m.name end
    end
    table.sort(out)
    return out
end

--@do-not-package@
-- /ynm dev recruit share | claims | forget
ns.devCommands.recruit = function(arg)
    local s = R.Store()
    if not s then return end
    if not (ns.Sim and ns.Sim.IsOn()) and arg ~= "forget" then ns.Print("/ynm dev sim on first") return end
    local fakes = FakesWithAddon()
    local now = GetServerTime()
    if arg == "share" then
        local who = fakes[math.random(#fakes)]
        if not who then return end
        s.shares[who] = s.shares[who] or {}
        s.shares[who][ns.me] = { at = now - math.random(60, 3600) }
        ns.Print(who .. " shared the addon with you (fake, on your screen only).")
    elseif arg == "claims" then
        -- Each fake with the addon says who got them on: another fake, or me; a few of them last month.
        local n = 0
        for i, who in ipairs(fakes) do
            if not s.claims[who] then
                local by = (i % 3 == 0) and ns.me or fakes[(i % #fakes) + 1]
                if by ~= who then
                    s.claims[who] = { by = by, at = now - ((i % 4 == 0) and 40 * 86400 or math.random(60, 86400)) }
                    n = n + 1
                end
            end
        end
        ns.Print(n .. " fake guildies said who got them on (on your screen only).")
    elseif arg == "forget" then
        for owner in pairs(s.claims) do if Same(owner, ns.me) then s.claims[owner] = nil end end
        ns.Print("Your answer is forgotten on this screen (the guild still has it if it went out).")
    else
        ns.Print("/ynm dev recruit share | claims | forget")
        return
    end
    Changed()
end
--@end-do-not-package@
