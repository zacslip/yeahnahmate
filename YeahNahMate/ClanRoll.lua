-- Clan roll: a fair /roll at a clan meeting. Whoever may run the clan's meetings (ClanMeet.CanRun)
-- starts a roll in their own group; members type a normal /roll; the highest roll wins.
--
-- The rules (the screen is UI/ClanRoll.lua):
--   * Only the game's own roll lines count (CHAT_MSG_SYSTEM, read with the game's RANDOM_ROLL_RESULT),
--     only a normal /roll (1-100), only from someone in my group, only while the roll is open.
--   * Someone's first roll stands; repeats are left out completely. My own repeat gets one notice.
--   * Clan members only, unless "Let non-clan members roll" is on (they then show as outsiders).
--   * "Skip past winners": anyone who won a roll for this clan during this meeting (or, with no
--     meeting running, in the last 4 hours) is shown but can't win.
--   * A tie at the top: Reroll ties opens a new round for only the tied players.
--   * The timer (off, 10, 20, 30, 60 s) or Stop closes the roll. A closed roll goes into the history
--     (the last 20, saved per guild).
--
-- Chat (the only chat this file sends; tests/test_rules.lua checks it):
--   * Start and Announce are the player's own click: one line to party or raid chat, and Announce
--     can also whisper the winner from the same click.
--   * Group members with the addon follow the roll on their own screens (numbers over heads, the
--     countdown, their own "first roll stands" notice, the winner's die and pop-up), from:
--       CRS { r, id, m, i, tm, cd, o, s, tie, rd }   a roll started (GUILD)
--       CRE { r, id, w, n, tie }                     it ended: winner and roll, or the tied players
--     Each screen checks the sender may run that clan's rolls (its own roster) and is in its group;
--     followers count rolls themselves for the screen, but the winner is always the starter's.
--   * All clans: the guild master or a manager asks each clan's leader (or second in command) to run
--     the same roll in their own group, by addon whisper:
--       CRA { id, r, m, i, tm, cd }   please run this roll (starter -> leader); the leader's addon checks
--                                      the sender is the guild master or a manager on its own roster
--       CRK { id, r, g }              got it (g: I'm in a group) - the leader's addon, at once
--       CRP { id, r }                 the leader clicked Start
--       CRW { id, r, w, n, tie }      it ended: winner and roll, or the tied players (sent by itself)
--     A report counts only from the person that clan's roll was sent to. The leader still clicks Start.
--   * "Roll over" is posted once, with no click, when a roll the player started with a click closes
--     (timer or Stop). It's the deliberate second exception to the no-automation rule (CONTRIBUTING.md).
local ADDON, ns = ...
local L = ns.L

local R = {}
ns.ClanRoll = R

R.TIMERS = { 0, 10, 20, 30, 60 }  -- seconds; 0 = no timer
R.HISTORY = 20                    -- rolls kept
R.SESSION = 4 * 3600              -- "this session" for past winners when no meeting is running
local MSG_MAX, ITEM_MAX = 40, 60  -- letters
local CHAT_MAX = 255              -- bytes

R.cur = nil                       -- the open (or last closed) roll on this screen
R.unreadable = false              -- true once a roll line came back secret: the screen says so

local function Changed() ns.Fire("CLANROLL") end

---------------------------------------------------------------------------------------------------
-- Reading a roll line

-- The game's own roll line ("%s rolls %d (%d-%d)") turned into a pattern: name, roll, low, high.
function R.Pattern(fmt)
    fmt = ns.Public(fmt or RANDOM_ROLL_RESULT, "string")
    if not fmt then return nil end
    local p = fmt:gsub("[%(%)%.%+%-%*%?%[%]%^]", "%%%0")
    p = p:gsub("%%%d?%$?s", "(.+)"):gsub("%%%d?%$?d", "(%%d+)")
    return "^" .. p .. "$"
end

-- name, roll, low, high from a game roll line, or nil.
function R.Parse(text)
    text = ns.Public(text, "string")
    local pat = text and R.Pattern()
    if not pat then return nil end
    local name, roll, lo, hi = text:match(pat)
    if not name then return nil end
    return name, tonumber(roll), tonumber(lo), tonumber(hi)
end

---------------------------------------------------------------------------------------------------
-- Cleaning what the leader types

-- Plain text: colour codes, links, textures and stray | out; spaces tidied; cut to max letters.
function R.Plain(s, max)
    if type(s) ~= "string" then return "" end
    s = s:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):gsub("|H.-|h(.-)|h", "%1"):gsub("|H[^|]*|h", ""):gsub("|T.-|t", ""):gsub("|", "")
    s = s:gsub("[%c]", " "):gsub("%s+", " ")
    s = strtrim and strtrim(s) or s:match("^%s*(.-)%s*$")
    return ns.CutLetters(s, max or MSG_MAX)
end

-- An item: a whole, real item link is kept as it is (it shows as a link in chat); anything else
-- becomes plain text, [Name] if it was a broken link.
function R.Item(s)
    if type(s) ~= "string" or s == "" then return nil end
    local link = s:match("^%s*(|c%x%x%x%x%x%x%x%x|Hitem:[%-%d:]+|h%[[^%]|]+%]|h|r)%s*$")
    if link then return link end
    local plain = R.Plain(s, ITEM_MAX)
    return plain ~= "" and plain or nil
end

-- "[Name]" for an item link or a plain name, for the screen and the history.
function R.ItemName(item)
    if not item then return nil end
    local n = item:match("|h%[(.-)%]|h")
    return n and ("[" .. n .. "]") or item
end

---------------------------------------------------------------------------------------------------
-- Timer and countdown

-- The next timer setting from secs, one step up (dir 1) or down (-1); stops at the ends.
function R.StepTimer(secs, dir)
    local at = 1
    for i, t in ipairs(R.TIMERS) do if t == secs then at = i end end
    at = math.max(1, math.min(#R.TIMERS, at + dir))
    return R.TIMERS[at]
end

-- The seconds-left marks the countdown shows: a 10 s roll counts 3, 2, 1; longer ones show
-- "Ending in 5", then 3, 2, 1. No timer, no countdown.
function R.CountMarks(secs)
    if not secs or secs <= 0 then return {} end
    if secs <= 10 then return { 3, 2, 1 } end
    return { 5, 3, 2, 1 }
end

---------------------------------------------------------------------------------------------------
-- Who's who

local function InGroup(key)
    if key == ns.me then return true end
    return ns.Gather.GroupKeys()[key] == true
end

local function InClan(key, race) return ns.Clans.Race(key) == race end

-- Saved history, newest last.
function R.History()
    local g = ns.GuildData()
    if not g then return {} end
    if type(g.clanRolls) ~= "table" then g.clanRolls = {} end
    return g.clanRolls
end

-- Since when a win counts as "this session": the meeting I'm running for this clan, else 4 hours.
local function SessionStart(race)
    local mine = ns.ClanMeet.Mine()
    if mine and mine.race == race then return mine.since end
    local a = ns.ClanMeet.ActiveFor(race)
    if a then return a.since end
    return GetServerTime() - R.SESSION
end

-- Has this guildie won a roll for this clan this session?
function R.PastWinner(key, race)
    local since = SessionStart(race)
    for _, h in ipairs(R.History()) do
        if h.race == race and h.winner == key and (h.at or 0) >= since then return true end
    end
    return false
end

---------------------------------------------------------------------------------------------------
-- A roll

function R.CanStart(race) return race ~= nil and ns.ClanMeet.ICanRun(race) end

-- Start a roll. opts = { race, msg, item, timer, countdown, others, skip, tied (keys) , parent }.
-- Returns the roll, or nil if I may not run this clan's rolls.
function R.Start(opts)
    local race = opts.race
    if not R.CanStart(race) then return nil end
    if R.cur and R.cur.open then R.Stop() end
    local now = GetServerTime()
    local msg = R.Plain(opts.msg or L.CLANROLL_DEFAULT, MSG_MAX)
    local timer = 0
    for _, t in ipairs(R.TIMERS) do if t == opts.timer then timer = t end end
    local r = {
        id = now .. "-" .. math.random(1000, 9999), race = race, by = ns.me, at = now,
        msg = msg, item = R.Item(opts.item), timer = timer, countdown = (opts.countdown and timer > 0) or false,
        others = opts.others and true or false, skip = opts.skip and true or false,
        rolls = {}, n = 0, open = true, clicked = opts.clicked ~= false, ask = opts.ask,
        round = (opts.parent and (opts.parent.round or 1) + 1) or 1, tied = opts.tied,
        noticed = false, endsAt = timer > 0 and (GetTime() + timer) or nil,
    }
    if not r.ask and not opts.parent and R.asked and R.asked.race == race then
        r.ask = { id = R.asked.id, from = R.asked.from }
        R.asked = nil
    end
    if r.ask and not opts.parent then R.Report(r.ask, { t = "CRP", id = r.ask.id, r = race }) end
    R.cur = r
    R.unreadable = false
    R.Arm(r)
    R.Broadcast(r, { t = "CRS", r = race, id = r.id, m = r.msg, i = r.item, tm = timer, cd = r.countdown or nil,
        o = r.others or nil, s = r.skip or nil, tie = R.TieList(r), rd = r.round })
    Changed()
    return r
end

-- The countdown marks and the end, for my roll or one I'm following.
function R.Arm(r)
    local timer = r.timer
    if timer <= 0 then
        -- A followed roll with no timer ends when its starter says; this is only a safety net.
        if r.follower then C_Timer.After(600, function() if R.cur == r and r.open then ns.Safe(R.Stop) end end) end
        return
    end
    local marks = r.countdown and R.CountMarks(timer) or {}
    for _, left in ipairs(marks) do
        C_Timer.After(timer - left, function()
            if R.cur == r and r.open then ns.Fire("CLANROLL_COUNT", left) end
        end)
    end
    C_Timer.After(timer, function()
        if R.cur == r and r.open then ns.Safe(R.Stop) end
    end)
end

-- The tied players of a reroll, as a sorted list (nil for a first round).
function R.TieList(r)
    if not r.tied then return nil end
    local out = {}
    for k in pairs(r.tied) do out[#out + 1] = k end
    table.sort(out)
    return out
end

-- A game roll line while my roll is open. Returns what happened, for the tests and the log:
-- "counts", or why it was left out ("closed", "range", "repeat", "group", "clan", "tie", "unreadable").
function R.OnRollLine(text)
    local r = R.cur
    if not r or not r.open then return "closed" end
    if text ~= nil and ns.Public(text, "string") == nil then
        if not R.unreadable then R.unreadable = true; Changed() end
        return "unreadable"
    end
    local name, roll, lo, hi = R.Parse(text)
    if not name then return "not a roll" end
    if lo ~= 1 or hi ~= 100 then return "range" end
    local key = ns.Key(name)
    if not key then return "not a roll" end
    if not InGroup(key) then return "group" end
    if r.tied and not r.tied[key] then return "tie" end
    local outsider = not InClan(key, r.race)
    if outsider and not r.others then return "clan" end
    if r.rolls[key] then
        if key == ns.me and not r.noticed then
            r.noticed = true
            ns.Print(string.format(L.CLANROLL_REPEAT, r.rolls[key].roll))
        end
        return "repeat"
    end
    r.n = r.n + 1
    r.rolls[key] = { roll = roll, order = r.n, outsider = outsider or nil,
        past = (r.skip and R.PastWinner(key, r.race)) or nil }
    ns.Fire("CLANROLL_ROLLED", key, roll)
    Changed()
    return "counts"
end
ns.OnEvent("CHAT_MSG_SYSTEM", function(text) if R.cur and R.cur.open then R.OnRollLine(text) end end)

-- Everyone who rolled, highest first (first to roll first among equals):
-- { name, roll, outsider, past (can't win), top (the current highest of those who can win) }
function R.Results(r)
    r = r or R.cur
    local list = {}
    if not r then return list end
    for key, e in pairs(r.rolls) do
        list[#list + 1] = { name = key, roll = e.roll, order = e.order, outsider = e.outsider, past = e.past }
    end
    table.sort(list, function(a, b)
        if a.roll ~= b.roll then return a.roll > b.roll end
        return a.order < b.order
    end)
    local best
    for _, e in ipairs(list) do
        if not e.past then
            best = best or e.roll
            e.top = e.roll == best or nil
        end
    end
    return list
end

-- The winner's key and roll, or nil and the tied keys (sorted) when two or more share the top.
function R.Winner(r)
    local top, roll = {}, nil
    for _, e in ipairs(R.Results(r)) do
        if e.top then top[#top + 1] = e.name; roll = e.roll end
    end
    if #top == 1 then return top[1], roll end
    if #top > 1 then table.sort(top); return nil, top, roll end
    return nil
end

-- People in my group who could roll and haven't: clan members (anyone, with non-clan members on),
-- only the tied players in a reroll; past winners left out when they can't win anyway.
function R.Missing(r)
    r = r or R.cur
    local out = {}
    if not r or not r.open then return out end
    local group = ns.Gather.GroupKeys()
    group[ns.me] = true
    for key in pairs(group) do
        if not r.rolls[key] and (not r.tied or r.tied[key])
            and (r.others or InClan(key, r.race))
            and not (r.skip and R.PastWinner(key, r.race)) then
            out[#out + 1] = key
        end
    end
    table.sort(out)
    return out
end

-- Close the roll (Stop, or the timer). Saves it, and posts "Roll over" once if I started it with a click.
function R.Stop()
    local r = R.cur
    if not r or not r.open then return end
    r.open = false
    r.closedAt = GetServerTime()
    if r.follower then
        Changed()
        return
    end
    local winner, tiedOrRoll, tieRoll = R.Winner(r)
    r.winner = winner
    r.winRoll = winner and tiedOrRoll or tieRoll
    r.ties = (not winner and type(tiedOrRoll) == "table") and tiedOrRoll or nil
    local h = R.History()
    h[#h + 1] = {
        at = r.at, race = r.race, by = r.by, msg = r.msg, item = r.item and R.ItemName(r.item) or nil, round = r.round,
        timer = r.timer, others = r.others, skip = r.skip, winner = r.winner, roll = r.winRoll, ties = r.ties,
        results = (function()
            local out = {}
            for _, e in ipairs(R.Results(r)) do out[#out + 1] = { e.name, e.roll, e.outsider and 1 or nil, e.past and 1 or nil } end
            return out
        end)(),
    }
    while #h > R.HISTORY do table.remove(h, 1) end
    if r.clicked and not r.overPosted then
        r.overPosted = true
        R.PostOver(r)
    end
    R.Broadcast(r, { t = "CRE", r = r.race, id = r.id, w = r.winner, n = r.winRoll, tie = r.ties })
    if r.ask then R.Report(r.ask, { t = "CRW", id = r.ask.id, r = r.race, w = r.winner, n = r.winRoll, tie = r.ties }) end
    ns.Fire("CLANROLL_OVER", r)
    Changed()
end

-- A new round for only the tied players, with the same message and item.
function R.Reroll()
    local r = R.cur
    if not r or r.open or not r.ties then return nil end
    local tied = {}
    for _, k in ipairs(r.ties) do tied[k] = true end
    return R.Start({ race = r.race, msg = r.msg, item = r.item, timer = r.timer, countdown = r.countdown,
        others = r.others, skip = r.skip, tied = tied, parent = r, ask = r.ask })
end

---------------------------------------------------------------------------------------------------
-- Chat lines

-- "Roll for [item]" (message and item; either may be empty).
function R.Head(r)
    local parts = {}
    if r.msg and r.msg ~= "" then parts[#parts + 1] = r.msg end
    if r.item then parts[#parts + 1] = r.item end
    if #parts == 0 then return L.CLANROLL_NOHEAD end
    return table.concat(parts, " ")
end

function R.StartLine(r)
    local head = R.Head(r)
    if r.tied then head = string.format(L.CLANROLL_REROLL_HEAD, head) end
    if r.timer > 0 then return string.format(L.CLANROLL_START_TIMED, head, r.timer) end
    return string.format(L.CLANROLL_START, head)
end

function R.OverLine(r) return string.format(L.CLANROLL_OVER, R.Head(r)) end

function R.AnnounceLine(r)
    if r.winner then return string.format(L.CLANROLL_WON, R.Head(r), r.winner, r.winRoll) end
    if r.ties then return string.format(L.CLANROLL_TIED, R.Head(r), table.concat(r.ties, ", "), r.winRoll) end
    return string.format(L.CLANROLL_NOBODY, R.Head(r))
end

function R.WhisperLine(r) return string.format(L.CLANROLL_WHISPER, R.Head(r), r.winRoll or 0) end

local function Channel()
    if IsInRaid and IsInRaid() then return "RAID" end
    if IsInGroup and IsInGroup() then return "PARTY" end
    return nil
end

-- May this screen really send for the roll? In test mode (a rank I don't really have) it stays here.
local function Real(r) return ns.ClanMeet.CanRun(ns.me, r.race) end

local function Sender()
    if C_ChatInfo and C_ChatInfo.InChatMessagingLockdown and C_ChatInfo.InChatMessagingLockdown() then return nil end
    return (C_ChatInfo and C_ChatInfo.SendChatMessage) or SendChatMessage
end

-- One line to party or raid chat. Returns true if it went (or was kept on screen in test mode).
local function ToGroup(r, line)
    line = ns.CutBytes(line, CHAT_MAX)
    local chan = Channel()
    if not chan then ns.Print(L.CLANROLL_NOT_IN_GROUP) return false end
    if not Real(r) then ns.Log("(dev) clan roll line kept on this screen: " .. line) return true end
    local send = Sender()
    if not send then ns.Print(L.CLANROLL_CHAT_LOCKED) return false end
    local ok, err = pcall(send, line, chan)
    if not ok then ns.Print(string.format(L.CLANROLL_CHAT_FAILED, tostring(err))) end
    return ok
end

-- An addon message about my roll to the guild (the group's addons pick it up). Test mode: not sent.
function R.Broadcast(r, msg)
    if not Real(r) then ns.Log("(dev) clan roll message kept on this screen: " .. msg.t) return end
    ns.Comm.Send(msg, "GUILD")
end

-- Start: the player's click.
function R.PostStart(r) return ToGroup(r, R.StartLine(r)) end

-- Roll over: once per roll, no click (R.Stop only calls it for a roll started with a click).
function R.PostOver(r) return ToGroup(r, R.OverLine(r)) end

-- Announce: the player's click; whisper = also whisper the winner from the same click.
function R.Announce(r, whisper)
    r = r or R.cur
    if not r or r.open then return false end
    local ok = ToGroup(r, R.AnnounceLine(r))
    if ok and whisper and r.winner and r.winner ~= ns.me then
        if not Real(r) then ns.Log("(dev) clan roll whisper kept on this screen") return true end
        local send = Sender()
        if not send then ns.Print(L.CLANROLL_CHAT_LOCKED) return false end
        local who, text = r.winner, ns.CutBytes(R.WhisperLine(r), CHAT_MAX)
        local sent, err = pcall(send, text, "WHISPER", nil, who)
        if not sent then ns.Print(string.format(L.CLANROLL_CHAT_FAILED, tostring(err))) end
        return sent
    end
    return ok
end

---------------------------------------------------------------------------------------------------
-- Following a roll someone in my group started

local function KeyList(t)
    if type(t) ~= "table" then return nil end
    local out = {}
    for i = 1, math.min(#t, 40) do
        local k = type(t[i]) == "string" and ns.Key(t[i])
        if k then out[k] = true end
    end
    return next(out) and out or nil
end

ns.Comm.On("CRS", function(msg, from, channel, isSelf)
    if isSelf or channel ~= "GUILD" then return end
    local race = ns.Clans.CleanRace(msg.r)
    if not race or type(msg.id) ~= "string" or #msg.id > 40 then return end
    if not ns.ClanMeet.CanRun(from, race) then
        ns.Log("dropped: a clan roll from " .. from .. ", who can't run the " .. race .. " clan's rolls")
        return
    end
    if not ns.Gather.GroupKeys()[from] then return end          -- not in my group: not my roll
    if R.cur and R.cur.open and R.cur.by == ns.me then return end   -- I'm running one myself
    if R.cur and R.cur.open then R.cur.open = false end
    local timer = 0
    for _, t in ipairs(R.TIMERS) do if t == msg.tm then timer = t end end
    local r = {
        id = msg.id, race = race, by = from, at = GetServerTime(), follower = true,
        msg = R.Plain(type(msg.m) == "string" and msg.m or "", MSG_MAX), item = R.Item(type(msg.i) == "string" and msg.i or nil),
        timer = timer, countdown = (msg.cd == true and timer > 0) or false, others = msg.o == true, skip = msg.s == true,
        rolls = {}, n = 0, open = true, clicked = false, round = tonumber(msg.rd) or 1, tied = KeyList(msg.tie),
        noticed = false, endsAt = timer > 0 and (GetTime() + timer) or nil,
    }
    R.cur = r
    R.unreadable = false
    R.Arm(r)
    ns.Fire("CLANROLL_FOLLOW", r)
    Changed()
end)

ns.Comm.On("CRE", function(msg, from, channel, isSelf)
    if isSelf or channel ~= "GUILD" then return end
    local r = R.cur
    if not r or not r.follower or r.id ~= msg.id or r.by ~= from then return end
    r.open = false
    r.closedAt = r.closedAt or GetServerTime()
    r.winner = type(msg.w) == "string" and ns.Key(msg.w) or nil
    r.winRoll = tonumber(msg.n)
    if not r.winner and type(msg.tie) == "table" then
        local ties = {}
        for k in pairs(KeyList(msg.tie) or {}) do ties[#ties + 1] = k end
        table.sort(ties)
        r.ties = #ties > 0 and ties or nil
    end
    ns.Fire("CLANROLL_OVER", r)
    Changed()
end)

---------------------------------------------------------------------------------------------------
-- All clans: the guild master or a manager starts one roll across every clan

R.ALL_WAIT = 20                   -- seconds for a leader's addon to say it got the ask
R.MIN_VER = "0.28.0"              -- the first version that can run an all-clans roll
R.all = nil                       -- the one I started: { id, at, msg, item, timer, countdown, clans = { race -> row } }
R.asked = nil                     -- an ask I got as a leader: { id, from, race, msg, item, timer, countdown, at }

-- Statuses on the starter's screen, in plain words (Strings.lua): waiting, rolling, won, tie, none,
-- offline, noaddon, update, group, noanswer.

function R.CanStartAll() return ns.Board.IsManager(ns.me) or ns.Board.devEditor == true end
local function RealAll() return ns.Board.IsManager(ns.me) end

-- An addon message to whoever asked (or to my own screen, when I asked myself).
function R.Report(ask, msg)
    if not ask then return end
    if ask.from == ns.me then
        ns.Safe(R.OnReport, msg, ns.me)
    elseif ns.Sim and ns.Sim.IsFake(ask.from) then
        ns.Log("(sim) clan roll report kept on this screen")
    else
        ns.Comm.Send(msg, "WHISPER", ask.from)
    end
end

-- Who runs this clan's roll: an online leader with the addon (a new enough one if there's a choice),
-- else the second in command. Returns the name and whether their version is old, or nil and why
-- ("noleader" / "offline" / "noaddon").
function R.PickLeader(race)
    local cands = {}
    for _, n in ipairs(ns.Clans.Leaders(race)) do cands[#cands + 1] = n end
    local d = ns.ClanChallenge.Deputy(race)
    if d and d.who then cands[#cands + 1] = d.who end
    if #cands == 0 then return nil, "noleader" end
    local anyOnline, old = false, nil
    for _, n in ipairs(cands) do
        local m = ns.Guild.Get(n)
        local online = n == ns.me or (m and m.online)
        if online then
            anyOnline = true
            if n == ns.me then return n, false end
            local u = ns.Comm.users[n]
            if u then
                local ver = u.ver
                if u.sim or (ver and ver ~= "?" and ns.CompareVersions(ver, R.MIN_VER) >= 0) then return n, false end
                old = old or n
            end
        end
    end
    if old then return old, true end
    return nil, anyOnline and "noaddon" or "offline"
end

local function AllChanged() ns.Fire("CLANROLL_ALL") end

-- Ask every clan's leader. opts = { msg, item, timer, countdown }.
function R.StartAll(opts)
    if not R.CanStartAll() then return nil end
    local now = GetServerTime()
    local timer = 0
    for _, t in ipairs(R.TIMERS) do if t == opts.timer then timer = t end end
    local all = { id = "A" .. now .. "-" .. math.random(1000, 9999), at = now, msg = R.Plain(opts.msg or L.CLANROLL_DEFAULT, MSG_MAX),
        item = R.Item(opts.item), timer = timer, countdown = (opts.countdown and timer > 0) or false, clans = {}, order = {} }
    R.all = all
    for _, c in ipairs(ns.Clans.List()) do
        local race = c.race
        local row = { race = race }
        all.clans[race] = row
        all.order[#all.order + 1] = race
        local to, why = R.PickLeader(race)
        if not to then
            row.status = why
        else
            row.to, row.old, row.status, row.sentAt = to, why == true or nil, "waiting", GetTime()
            local msg = { t = "CRA", id = all.id, r = race, m = all.msg, i = all.item, tm = timer, cd = all.countdown or nil }
            if to == ns.me then
                ns.Safe(R.OnAsk, msg, ns.me)
            elseif ns.Sim and ns.Sim.IsFake(to) then
                if R.SimLeader then R.SimLeader(msg, to) end
            elseif RealAll() then
                ns.Comm.Send(msg, "WHISPER", to)
            else
                ns.Log("(dev) all-clans roll ask kept on this screen: your rank can't start one")
            end
        end
    end
    C_Timer.After(R.ALL_WAIT, function()
        if R.all ~= all then return end
        for _, row in pairs(all.clans) do
            if row.status == "waiting" and not row.acked then row.status = row.old and "update" or "noanswer" end
        end
        AllChanged()
    end)
    AllChanged()
    return all
end

-- A leader's addon: someone asked me to run my clan's roll.
function R.OnAsk(msg, from)
    local race = ns.Clans.CleanRace(msg.r)
    if not race or type(msg.id) ~= "string" or #msg.id > 40 then return end
    if not ns.Board.IsManager(from) then
        ns.Log("dropped: an all-clans roll from " .. from .. ", who isn't the guild master or a manager")
        return
    end
    if not ns.ClanMeet.CanRun(ns.me, race) then return end
    local timer = 0
    for _, t in ipairs(R.TIMERS) do if t == msg.tm then timer = t end end
    R.asked = { id = msg.id, from = from, race = race, msg = R.Plain(type(msg.m) == "string" and msg.m or "", MSG_MAX),
        item = R.Item(type(msg.i) == "string" and msg.i or nil), timer = timer, countdown = msg.cd == true and timer > 0, at = GetServerTime() }
    R.Report(R.asked, { t = "CRK", id = msg.id, r = race, g = (IsInGroup and IsInGroup()) and true or nil })
    ns.Fire("CLANROLL_ASKED", R.asked)
    Changed()
end

-- The starter's addon: a leader's report. Only from the person that clan's roll was sent to.
function R.OnReport(msg, from)
    local all = R.all
    local race = ns.Clans.CleanRace(msg.r)
    local row = all and race and all.clans[race]
    if not row or msg.id ~= all.id or row.to ~= from then return end
    if msg.t == "CRK" then
        row.acked = true
        if row.status == "waiting" or row.status == "noanswer" or row.status == "update" then
            row.status = msg.g and "waiting" or "group"
        end
    elseif msg.t == "CRP" then
        row.acked = true
        row.status = "rolling"
    elseif msg.t == "CRW" then
        row.acked = true
        row.winner = type(msg.w) == "string" and ns.Key(msg.w) or nil
        row.roll = tonumber(msg.n)
        row.status = row.winner and "won" or ((type(msg.tie) == "table" and #msg.tie > 0) and "tie" or "none")
    end
    AllChanged()
end

ns.Comm.On("CRA", function(msg, from, channel, isSelf)
    if isSelf or channel ~= "WHISPER" then return end
    R.OnAsk(msg, from)
end)
for _, t in ipairs({ "CRK", "CRP", "CRW" }) do
    ns.Comm.On(t, function(msg, from, channel, isSelf)
        if isSelf or channel ~= "WHISPER" then return end
        R.OnReport(msg, from)
    end)
end

-- Dev only: the CurseForge build leaves this out (BigWigs packager's do-not-package markers).
--@do-not-package@
-- /ynm dev rollfakes [tie]   fake guildies of the roll's clan "join" my group and /roll over the next
--                            few seconds (needs fake guildies, /ynm dev sim on, and an open roll):
--                            one rolls twice, one tries /roll 100 100, one from another clan rolls too.
--                            "tie": two of them roll the same, highest.
local function FakeLine(name, n, lo, hi)
    local fmt = ns.Public(RANDOM_ROLL_RESULT, "string") or "%s rolls %d (%d-%d)"
    return string.format(fmt, name, n, lo or 1, hi or 100)
end
ns.devCommands.rollfakes = function(arg)
    local r = R.cur
    if not (ns.Sim and ns.Sim.IsOn()) then ns.Print("(dev) Fake rollers need fake guildies: /ynm dev sim on") return end
    if not (r and r.open) then ns.Print("(dev) Start a roll first (Clans > My Clan > Start roll).") return end
    local same, other = {}, nil
    for _, m in ipairs(ns.Guild.list) do
        if m.sim and m.online then
            if m.race == r.race then same[#same + 1] = m.name elseif not other then other = m.name end
        end
    end
    if #same == 0 then ns.Print("(dev) No online fake guildies in that clan.") return end
    while #same > 5 do table.remove(same) end
    for _, n in ipairs(same) do ns.Sim.Join(n) end
    if other then ns.Sim.Join(other) end
    local plan, t = {}, 0
    local function Add(name, n, lo, hi) t = t + 0.7; plan[#plan + 1] = { t, FakeLine(name, n, lo, hi) } end
    for i, n in ipairs(same) do
        if arg == "tie" and i <= 2 then Add(n, 100) else Add(n, math.random(1, 99)) end
    end
    Add(same[1], 100)                          -- a repeat: left out
    if same[2] then Add(same[2], 100, 100, 100) end  -- /roll 100 100: left out
    if other then Add(other, 100) end           -- another clan: left out unless allowed
    for _, step in ipairs(plan) do
        C_Timer.After(step[1], function() ns.Safe(R.OnRollLine, step[2]) end)
    end
    ns.Print("(dev) " .. #same .. " fake clan members joined your group and are rolling" .. (other and (", plus " .. other .. " from another clan") or "") .. ".")
end

-- A fake leader (sim mode) asked to run their clan's roll: says got it, starts after a few seconds,
-- and reports a winner from their fake clan when the timer would end. One clan says it isn't in a group.
function R.SimLeader(msg, to)
    local race = msg.r
    local first = true
    for r2 in pairs(R.all and R.all.clans or {}) do if r2 < race then first = false end end
    C_Timer.After(1.5, function() R.OnReport({ t = "CRK", id = msg.id, r = race, g = not first or nil }, to) end)
    if first then return end
    C_Timer.After(4, function() R.OnReport({ t = "CRP", id = msg.id, r = race }, to) end)
    local pool = {}
    for _, m in ipairs(ns.Guild.list) do if m.sim and m.race == race and m.name ~= to then pool[#pool + 1] = m.name end end
    C_Timer.After(4 + math.max(10, msg.tm or 0), function()
        local w = pool[math.random(1, math.max(1, #pool))]
        R.OnReport({ t = "CRW", id = msg.id, r = race, w = w, n = w and math.random(60, 100) or nil }, to)
    end)
end
--@end-do-not-package@
