-- The guild board: things the guild's officers set for everyone (a Home message and a longer Info
-- page), who counts as an officer (set by the guild master), and streamers' own cards.
--
-- Who may change what, checked by every reader against their own copy of the game's guild roster
-- (never against anything in the message):
--   * Managers: guildies the guild master named (any rank). A manager has exactly the guild master's
--     access: the GM tab, milestones, naming managers, the tab ranks, moderating every tab. Nobody
--     can take the guild master's access away.
--   * Tab moderators: for each tab (Calendar, Dungeons, Professions, Ask, Streamers, Info) the guild
--     master or a manager ticks which ranks moderate it (pick the ranks, not "this rank
--     and above"). Info = edit the guild info; Streamers = edit or remove anyone's card; the others in
--     their own files. The guild master and the rank under them by default.
--   * A streamer card: its owner, or a Streamers moderator.
-- Streamer cards are the players' own words for their guildmates; the addon itself adds no links
-- or adverts (Blizzard's policy) and WoW can't open links anyway: the Twitch name is copyable text.
--
-- One message type, BRD, with a kind:
--   BRD { k = "info", motd, text, dc, ev }    Home message + Info page + the guild's Discord invite
--   BRD { k = "rank", er, tm = { cal, dun, prof, ask, strm, info }, ev }   which ranks moderate each
--                                              tab: a number, bit i set = rank index i ticked (er: the
--                                              old single setting, for older versions)
--   BRD { k = "mgr", mg = { names }, ev }      the managers (guild master or a manager)
--   BRD { k = "strm", tw, when, about, live, ev } / { k = "strm", x = true, ev }   my streamer card
--   BRD { k = "strm", mo = owner, ... }        a Streamers moderator edits or removes owner's card
--   with o = author, only by WHISPER from a guildie we asked: a copy (the same rules as event copies)
--   REQ { w = "BRD" }                          send me the board (WHISPER)
-- ev is the item's version (its edit time). Copies never beat the author's own message; versions
-- from the future are refused.
local ADDON, ns = ...
local L = ns.L

local Board = {}
ns.Board = Board

Board.MAX_MOTD = 300
Board.MAX_TEXT = 3000
Board.LIVE_FOR = 6 * 3600       -- "live now" switches itself off after 6 hours
Board.MAX_MANAGERS = 20
local ASK_WINDOW = 300

local function Clean(s, max) return type(s) == "string" and ns.CutBytes((s:gsub("|", ""):gsub("\r", "")), max) or "" end
local function OneLine(s, max) return Clean(s, max):gsub("\n", " ") end
local Future = ns.Future

function Board.Store()
    local g = ns.GuildData()
    if not g then return nil end
    if type(g.board) ~= "table" then g.board = {} end
    local b = g.board
    if type(b.streamers) ~= "table" then b.streamers = {} end
    return b
end

local function Changed() ns.Fire("BOARD") end

-- More kinds from other files (Milestones.lua): Board.kinds[k] = { take(author, msg, direct) -> changed,
-- all(add(msg, author)), evs(author, list) }. They ride on the board's sync: asking, copies, log-in catch-up.
Board.kinds = {}

---------------------------------------------------------------------------------------------------
-- Ranks

-- The tabs with their own moderator rank.
Board.TABS = { "cal", "dun", "prof", "ask", "strm", "info", "clan" }
local IS_TAB = {}
for _, t in ipairs(Board.TABS) do IS_TAB[t] = true end
Board.IS_TAB = IS_TAB

-- A set of rank indices kept as one number: rank i is in it when bit i is set. Ranks 0-9.
local MAX_MASK = 1023
local function Has(mask, i) return math.floor(mask / 2 ^ i) % 2 == 1 end
local function UpTo(er) return 2 ^ (math.floor(er) + 1) - 1 end        -- ranks 0..er
local function CleanMask(v)
    if type(v) ~= "number" or v < 0 or v > MAX_MASK or v ~= math.floor(v) then return nil end
    if not Has(v, 0) then v = v + 1 end                                  -- the guild master always
    return v
end
Board.MaskHas = Has

-- Which ranks moderate a tab, as that number.
function Board.TabMask(tab)
    local b = Board.Store()
    local r = b and b.rank
    local v = r and type(r.tm) == "table" and r.tm[tab]
    if type(v) == "number" then return v end
    return UpTo((r and r.er) or 1)
end

-- Is this rank ticked for this tab? (The guild master's rank always is.)
function Board.RankModerates(tab, index)
    if type(index) ~= "number" or index < 0 or index > 9 then return false end
    return index == 0 or Has(Board.TabMask(tab), index)
end

-- Does this rank moderate any tab? (The roster's shield.)
function Board.RankModeratesAny(index)
    for _, t in ipairs(Board.TABS) do if Board.RankModerates(t, index) then return true end end
    return false
end

-- The old single setting, for older versions: the ranks from the top down that moderate Info.
local function Contiguous(mask)
    local e = 0
    while e < 9 and Has(mask, e + 1) do e = e + 1 end
    return e
end

-- The old single setting as a rank index (Info's ticks from the top down).
function Board.EditRank() return Contiguous(Board.TabMask("info")) end

local function RankOf(name)
    if name == ns.me then return ns.Guild.myRank end
    local m = ns.Guild.Get(name)
    return m and not m.sim and m.rankIndex or (m and m.sim and m.rankIndex) or nil
end

function Board.IsGuildMaster(name)
    return RankOf(name) == 0
end

-- The managers the guild master named, still in the guild, by name.
function Board.Managers()
    local b = Board.Store()
    local list = {}
    if not b or not b.mgr or type(b.mgr.mg) ~= "table" then return list end
    for name in pairs(b.mgr.mg) do
        if name == ns.me or ns.Guild.IsMember(name) then list[#list + 1] = name end
    end
    table.sort(list)
    return list
end

local function Named(name)
    local b = Board.Store()
    return b ~= nil and b.mgr ~= nil and type(b.mgr.mg) == "table" and b.mgr.mg[name] == true
        and (name == ns.me or ns.Guild.IsMember(name))
end

-- A manager: the guild master, or someone they named.
function Board.IsManager(name)
    return name ~= nil and (Board.IsGuildMaster(name) or Named(name))
end

-- Does this guildie moderate this tab? Managers (and the guild master) moderate every tab; otherwise
-- their guild rank must be at or above the tab's setting.
function Board.CanModerate(name, tab)
    if name == nil then return false end
    if Board.IsManager(name) then return true end
    return Board.RankModerates(tab, RankOf(name))
end

-- Testing alone: /ynm dev editor on shows every moderator button; /ynm dev rank N
-- shows the addon as guild rank N sees it (0 = guild master). Both on this screen only: what's sent
-- is still checked against my real rank (DevBlocked, and each file's real-rank check), and every
-- guildie's addon checks it again against their own roster.
Board.simRank = nil
function Board.Testing() return Board.devEditor == true or Board.simRank ~= nil end

-- Do I moderate this tab? (As shown on this screen; see above for testing.)
function Board.Moderates(tab)
    if Board.devEditor then return true end
    if Board.simRank then return Board.RankModerates(tab, Board.simRank) end
    return Board.CanModerate(ns.me, tab)
end

-- The tabs a guildie moderates (for their tooltip), in Board.TABS order.
function Board.ModeratorTabs(name)
    local list = {}
    for _, t in ipairs(Board.TABS) do if Board.CanModerate(name, t) then list[#list + 1] = t end end
    return list
end

-- The Info tab's moderators (the name older code uses).
function Board.IsEditor(name) return Board.CanModerate(name, "info") end

-- Can I edit the guild info?
function Board.CanEdit() return Board.Moderates("info") end
-- Am I a manager, as shown on this screen? (A simulated rank 0 is the guild master.)
local function ShownManager()
    if Board.devEditor then return true end
    if Board.simRank then return Board.simRank == 0 end
    return Board.IsManager(ns.me)
end
-- Can I name managers and set the tab ranks? (The guild master or a manager.)
function Board.CanSetRank() return ShownManager() end
-- Do I see the GM tab? (The guild master and the managers they named.)
function Board.CanManage() return ShownManager() end
-- Am I the guild master, as shown on this screen?
function Board.ShownGuildMaster()
    if Board.devEditor then return true end
    if Board.simRank then return Board.simRank == 0 end
    return Board.IsGuildMaster(ns.me)
end

-- The guild's ranks, from the roster: { { index, name }, ... } best first.
function Board.Ranks()
    local seen, list = {}, {}
    for _, m in ipairs(ns.Guild.list) do
        if not m.sim and m.rankIndex and m.rankIndex < 99 and not seen[m.rankIndex] then
            seen[m.rankIndex] = true
            list[#list + 1] = { index = m.rankIndex, name = m.rank }
        end
    end
    table.sort(list, function(a, b) return a.index < b.index end)
    return list
end

---------------------------------------------------------------------------------------------------
-- Reading

function Board.Info()
    local b = Board.Store()
    return b and b.info
end

-- The guild's Discord invite ("discord.gg/CODE"), or nil.
function Board.Discord()
    local info = Board.Info()
    return info and info.dc and info.dc ~= "" and info.dc or nil
end

-- The Home message: the officers' one, else the game's own guild message of the day.
function Board.HomeMessage()
    local info = Board.Info()
    if info and info.motd and info.motd ~= "" then return info.motd, info.by end
    local motd = GetGuildRosterMOTD and ns.Public(GetGuildRosterMOTD(), "string")
    if motd and motd ~= "" then return motd, nil end
    return nil
end

-- Streamer cards, live ones first, then by name.
function Board.Streamers()
    local b = Board.Store()
    local list = {}
    if not b then return list end
    local now = GetServerTime()
    for name, s in pairs(b.streamers) do
        if not s.x and (name == ns.me or ns.Guild.IsMember(name)) then
            local m = ns.Guild.Get(name)
            local live = s.live and s.liveAt and now - s.liveAt < Board.LIVE_FOR and (name == ns.me or (m and m.online))
            list[#list + 1] = { name = name, s = s, live = live and true or false }
        end
    end
    table.sort(list, function(x, y)
        if x.live ~= y.live then return x.live end
        return x.name < y.name
    end)
    return list
end

function Board.Mine()
    local b = Board.Store()
    local s = b and b.streamers[ns.me or "?"]
    if s and s.x then return nil end
    return s
end

---------------------------------------------------------------------------------------------------
-- Changing (my own things, or the guild's if I'm an editor)

-- In /ynm dev editor mode, don't send what my real rank couldn't.
local function DevBlocked(msg)
    if not Board.Testing() or msg.o ~= nil then return false end
    if (msg.k == "mgr" or msg.k == "rank") and not Board.IsManager(ns.me) then return true end
    if msg.k == "info" and not Board.CanModerate(ns.me, "info") then return true end
    if msg.k == "strm" and msg.mo ~= nil and not Board.CanModerate(ns.me, "strm") then return true end
    return false
end

local function Send(msg, channel, target)
    if DevBlocked(msg) then
        ns.Log("(dev) not sent: your guild rank can't do that")
        return
    end
    if Board.Testing() and not Board.IsManager(ns.me) and Board.kinds[msg.k] then
        ns.Log("(dev) not sent: you're not a manager")
        return
    end
    ns.Comm.Send(msg, channel or "GUILD", target, "BULK")
end

Board.Send = Send

local function NextVersion(old) return math.max(GetServerTime(), (old or 0) + 1) end
Board.NextVersion = NextVersion

-- A Discord invite, tidied to "discord.gg/CODE" (from discord.gg/..., discord.com/invite/..., with or
-- without https://). Empty is fine (no Discord); anything else isn't kept.
function Board.CleanDiscord(s)
    s = type(s) == "string" and s:gsub("%s", "") or ""
    if s == "" then return "" end
    s = s:gsub("^https?://", ""):gsub("^www%.", "")
    local code = s:match("^discord%.gg/([%w%-]+)/?$") or s:match("^discord%.com/invite/([%w%-]+)/?$")
        or s:match("^discordapp%.com/invite/([%w%-]+)/?$")
    if not code or #code < 2 or #code > 32 then return nil end
    return "discord.gg/" .. code
end

function Board.SetInfo(motd, text, dc)
    local b = Board.Store()
    if not b or not Board.CanEdit() then return false end
    dc = Board.CleanDiscord(dc)
    if dc == nil then return false, "discord" end
    local info = { motd = OneLine(motd, Board.MAX_MOTD), text = Clean(text, Board.MAX_TEXT), dc = dc, by = ns.me,
                   ev = NextVersion(b.info and b.info.ev), direct = true }
    b.info = info
    Send({ t = "BRD", k = "info", motd = info.motd, text = info.text, dc = info.dc, ev = info.ev })
    Changed()
    return true
end

local function RankMessage(r)
    local tm = {}
    for _, t in ipairs(Board.TABS) do tm[t] = (r.tm and r.tm[t]) or UpTo(r.er or 1) end
    return { t = "BRD", k = "rank", er = r.er, tm = tm, ev = r.ev }
end

-- Set which ranks moderate the tabs: tm = { tab = number } (tabs left out keep theirs).
local function SetMasks(tm)
    local b = Board.Store()
    if not b or not Board.CanSetRank() then return false end
    local new = {}
    for _, t in ipairs(Board.TABS) do
        local v = tm[t]
        if v == nil then v = Board.TabMask(t) end
        v = CleanMask(v)
        if not v then return false end
        new[t] = v
    end
    b.rank = { er = Contiguous(new.info), tm = new, by = ns.me, ev = NextVersion(b.rank and b.rank.ev), direct = true }
    Send(RankMessage(b.rank))
    Changed()
    return true
end

-- Tick (or untick) one rank for one tab. The guild master's rank can't be unticked.
function Board.SetRankModerates(tab, index, on)
    if not IS_TAB[tab] or type(index) ~= "number" or index < 1 or index > 9 then return false end
    local mask = Board.TabMask(tab)
    local has = Has(mask, index)
    if on and not has then mask = mask + 2 ^ index elseif not on and has then mask = mask - 2 ^ index end
    return SetMasks({ [tab] = mask })
end

-- Every tab to the guild master and the ranks under them down to er (the old single setting).
function Board.SetEditRank(er)
    if type(er) ~= "number" or er < 0 or er > 9 then return false end
    local tm = {}
    for _, t in ipairs(Board.TABS) do tm[t] = UpTo(er) end
    return SetMasks(tm)
end

-- The guild master or a manager names (or un-names) a manager.
local function ManagerMessage(m)
    local names = {}
    for name in pairs(m.mg) do names[#names + 1] = name end
    table.sort(names)
    return { t = "BRD", k = "mgr", mg = names, ev = m.ev }
end

function Board.SetManager(name, on)
    local b = Board.Store()
    if not b or not Board.CanSetRank() or type(name) ~= "string" then return false end
    name = ns.Key(name) or name
    if not ns.Guild.IsMember(name) then return false, "member" end
    local mg = {}
    for _, n in ipairs(Board.Managers()) do mg[n] = true end
    if on and not mg[name] and #Board.Managers() >= Board.MAX_MANAGERS then return false, "full" end
    mg[name] = on and true or nil
    b.mgr = { mg = mg, by = ns.me, ev = NextVersion(b.mgr and b.mgr.ev), direct = true }
    Send(ManagerMessage(b.mgr))
    Changed()
    return true
end

-- Twitch names are letters, numbers and underscores, 4 to 25 long.
function Board.CleanTwitch(s)
    s = type(s) == "string" and s:gsub("^%s*https?://", ""):gsub("^www%.", ""):gsub("^twitch%.tv/", "") or ""
    s = s:gsub("%s", "")
    if not s:match("^[%w_]+$") or #s < 4 or #s > 25 then return nil end
    return s
end

local function StreamerMessage(s)
    return { t = "BRD", k = "strm", tw = s.tw, when = s.when, about = s.about, live = s.live or nil, ev = s.ev }
end

function Board.SetStreamer(tw, when, about)
    local b = Board.Store()
    tw = Board.CleanTwitch(tw)
    if not b or not tw then return false end
    local old = b.streamers[ns.me]
    local s = { tw = tw, when = OneLine(when, 60), about = OneLine(about, 100),
                live = old and not old.x and old.live or nil, liveAt = old and old.liveAt or nil,
                ev = NextVersion(old and old.ev), direct = true }
    b.streamers[ns.me] = s
    Send(StreamerMessage(s))
    Changed()
    return true
end

function Board.SetLive(on)
    local b = Board.Store()
    local s = b and b.streamers[ns.me]
    if not s or s.x then return end
    s.live = on and true or nil
    s.liveAt = on and GetServerTime() or nil
    s.ev = NextVersion(s.ev)
    Send(StreamerMessage(s))
    Changed()
end

-- A Streamers moderator edits someone else's card, or takes it down. The card stays
-- theirs; mb says who changed it. Their later edits still win (newer), their old copy doesn't.
local function ModStreamerMessage(owner, s)
    local m = s.x and { t = "BRD", k = "strm", x = true, ev = s.ev } or StreamerMessage(s)
    m.mo = owner
    return m
end

function Board.ModStreamer(owner, tw, when, about)
    local b = Board.Store()
    tw = Board.CleanTwitch(tw)
    if not b or not tw or owner == ns.me or not Board.Moderates("strm") then return false end
    local old = b.streamers[owner]
    if not old or old.x then return false end
    local s = { tw = tw, when = OneLine(when, 60), about = OneLine(about, 100), live = old.live, liveAt = old.liveAt,
                ev = NextVersion(old.ev), direct = true, mb = ns.me }
    b.streamers[owner] = s
    Send(ModStreamerMessage(owner, s))
    Changed()
    return true
end

function Board.ModRemoveStreamer(owner)
    local b = Board.Store()
    local old = b and b.streamers[owner]
    if not old or old.x or owner == ns.me or not Board.Moderates("strm") then return false end
    b.streamers[owner] = { x = true, ev = NextVersion(old.ev), direct = true, mb = ns.me }
    Send(ModStreamerMessage(owner, b.streamers[owner]))
    Changed()
    return true
end

function Board.RemoveStreamer()
    local b = Board.Store()
    local s = b and b.streamers[ns.me]
    if not s or s.x then return end
    b.streamers[ns.me] = { x = true, ev = NextVersion(s.ev), direct = true }
    Send({ t = "BRD", k = "strm", x = true, ev = b.streamers[ns.me].ev })
    Changed()
end

---------------------------------------------------------------------------------------------------
-- Receiving

local asked = {}

-- Should this replace what we hold? A streamer card has one author: their own message always wins,
-- a copy when it's newer. The guild info and the editor rank are one slot that several people can
-- write (any editor; a new guild master), so there the newest wins whoever sent it: an editor's
-- older version, whispered at log-in, must not roll back a newer one from someone else.
local function Newer(old, ev, direct, shared)
    if not old then return true end
    return ns.Newer(old.ev, old.direct, ev, direct, shared)
end

local function Take(author, msg, direct)
    local b = Board.Store()
    if not b or author == ns.me or not ns.Guild.IsMember(author) or Future(msg.ev, not direct) then return false end
    if msg.k == "info" then
        if not Board.IsEditor(author) then
            ns.Log("dropped: guild info from " .. author .. ", who isn't an editor rank")
            return false
        end
        if not Newer(b.info, msg.ev, direct, true) then return false end
        b.info = { motd = OneLine(msg.motd, Board.MAX_MOTD), text = Clean(msg.text, Board.MAX_TEXT), by = author,
                   dc = Board.CleanDiscord(msg.dc) or "",
                   ev = msg.ev, direct = direct or nil }
        return true
    elseif msg.k == "rank" then
        if not Board.IsManager(author) then
            ns.Log("dropped: tab ranks from " .. author .. ", who isn't the guild master or a manager")
            return false
        end
        if type(msg.er) ~= "number" or msg.er < 0 or msg.er > 9 or not Newer(b.rank, msg.ev, direct, true) then return false end
        local tm = {}
        local old = b.rank and type(b.rank.tm) == "table" and b.rank.tm or {}
        for _, t in ipairs(Board.TABS) do
            local v = type(msg.tm) == "table" and msg.tm[t]
            -- A tab missing from the message (an older version that doesn't know it) keeps what I hold.
            if v == nil and type(old[t]) == "number" then v = old[t] end
            tm[t] = CleanMask(v) or UpTo(msg.er)
        end
        b.rank = { er = math.floor(msg.er), tm = tm, by = author, ev = msg.ev, direct = direct or nil }
        return true
    elseif msg.k == "mgr" then
        if not Board.IsManager(author) then
            ns.Log("dropped: managers from " .. author .. ", who isn't the guild master or a manager")
            return false
        end
        if type(msg.mg) ~= "table" or not Newer(b.mgr, msg.ev, direct, true) then return false end
        local mg, n = {}, 0
        for _, name in ipairs(msg.mg) do
            local key = type(name) == "string" and ns.Key(name)
            if key and n < Board.MAX_MANAGERS and not mg[key] then mg[key] = true; n = n + 1 end
        end
        b.mgr = { mg = mg, by = author, ev = msg.ev, direct = direct or nil }
        return true
    elseif msg.k == "strm" then
        if not Newer(b.streamers[author], msg.ev, direct) then
            -- The owner came back with their old card, but a moderator changed it: tell them.
            local held = b.streamers[author]
            if direct and held and held.mb then Board.TellStreamer(author, held) end
            return false
        end
        if msg.x == true then
            b.streamers[author] = { x = true, ev = msg.ev, direct = direct or nil }
            return true
        end
        local tw = Board.CleanTwitch(msg.tw)
        if not tw then return false end
        local old = b.streamers[author]
        local live = msg.live == true
        b.streamers[author] = { tw = tw, when = OneLine(msg.when, 60), about = OneLine(msg.about, 100), live = live or nil,
            liveAt = live and ((old and old.live and old.liveAt) or GetServerTime()) or nil, ev = msg.ev, direct = direct or nil }
        return true
    elseif type(msg.k) == "string" and Board.kinds[msg.k] then
        return Board.kinds[msg.k].take(author, msg, direct) and true or false
    end
    return false
end

-- A moderator's change to someone's streamer card (sent by the moderator, mo = the card's owner).
-- It can be my own card: then I take it too, and I'm told.
local function TakeModStreamer(from, msg)
    local b = Board.Store()
    local owner = type(msg.mo) == "string" and ns.Key(msg.mo) or nil
    if not b or not owner or owner == from or msg.k ~= "strm" or Future(msg.ev, false) then return false end
    if not Board.CanModerate(from, "strm") then
        ns.Log("dropped: a streamer card change from " .. from .. ", who doesn't moderate Streamers")
        return false
    end
    if owner ~= ns.me and not ns.Guild.IsMember(owner) then return false end
    local old = b.streamers[owner]
    if old and (old.ev or 0) >= msg.ev then return false end
    if msg.x == true then
        b.streamers[owner] = { x = true, ev = msg.ev, direct = true, mb = from }
    else
        local tw = Board.CleanTwitch(msg.tw)
        if not tw then return false end
        b.streamers[owner] = { tw = tw, when = OneLine(msg.when, 60), about = OneLine(msg.about, 100),
            live = old and old.live or nil, liveAt = old and old.liveAt or nil, ev = msg.ev, direct = true, mb = from }
    end
    if owner == ns.me then
        ns.Print(string.format(msg.x and L.MOD_STRM_REMOVED_MINE or L.MOD_STRM_EDITED_MINE, from))
    end
    return true
end

-- The owner is behind on a change a moderator made: a moderator who holds it tells them (once a minute).
local toldStreamer = {}
function Board.TellStreamer(owner, s)
    if not Board.CanModerate(ns.me, "strm") or (ns.Sim and ns.Sim.IsFake(owner)) then return end
    if toldStreamer[owner] and GetTime() - toldStreamer[owner] < 60 then return end
    toldStreamer[owner] = GetTime()
    ns.Comm.Send(ModStreamerMessage(owner, s), "WHISPER", owner, "BULK")
end

ns.Comm.On("BRD", function(msg, from, channel, isSelf)
    if isSelf then return end
    if msg.mo ~= nil then
        if (channel == "GUILD" or channel == "WHISPER") and TakeModStreamer(from, msg) then Changed() end
        return
    end
    if msg.o == nil then
        if Take(from, msg, true) then Changed() end
        return
    end
    if channel ~= "WHISPER" or not asked[from] or GetTime() - asked[from] > ASK_WINDOW then
        ns.Log("dropped: a board copy from " .. from .. " that we didn't ask for")
        return
    end
    asked[from] = GetTime()
    local author = ns.Key(msg.o)
    if author and author ~= from and Take(author, msg, false) then Changed() end
end)

-- What I know, as messages (copies carry the author; my own go as mine).
local function Everything(forWhom)
    local b = Board.Store()
    local out = {}
    if not b then return out end
    local function Add(m, author)
        if author == forWhom then return end
        if author ~= ns.me then m.o = author end
        out[#out + 1] = m
    end
    if b.rank and b.rank.by then Add(RankMessage(b.rank), b.rank.by) end
    if b.mgr and b.mgr.by and type(b.mgr.mg) == "table" then Add(ManagerMessage(b.mgr), b.mgr.by) end
    if b.info and b.info.by then
        Add({ t = "BRD", k = "info", motd = b.info.motd, text = b.info.text, dc = b.info.dc, ev = b.info.ev }, b.info.by)
    end
    for name, s in pairs(b.streamers) do
        if ns.Guild.IsMember(name) or name == ns.me then
            Add(s.x and { t = "BRD", k = "strm", x = true, ev = s.ev } or StreamerMessage(s), name)
        end
    end
    for _, kind in pairs(Board.kinds) do kind.all(Add) end
    return out
end

local answered = {}
ns.Comm.On("REQ", function(msg, from, channel, isSelf)
    if isSelf or channel ~= "WHISPER" or msg.w ~= "BRD" then return end
    local now = GetTime()
    if answered[from] and now - answered[from] < 60 then return end
    answered[from] = now
    for _, m in ipairs(Everything(from)) do
        if not (DevBlocked(m) or (m.o == nil and Board.Testing() and not Board.IsManager(ns.me) and Board.kinds[m.k])) then
            ns.Comm.Send(m, "WHISPER", from, "BULK")
        end
    end
end)

-- A guildie who just logged in gets my own card (and the guild info if I wrote it) from me.
ns.Listen("HI_IN", function(msg, from)
    if msg.ask ~= true or (ns.Sim and ns.Sim.IsFake(from)) then return end
    C_Timer.After(4 + math.random() * 4, function()
        for _, m in ipairs(Everything(from)) do
            -- Milestone cards (up to 20) aren't pushed at every log-in: the newcomer asks one guildie
            -- for the board 50 s in, and Sync catches up on newer versions.
            if m.o == nil and not Board.kinds[m.k] then Send(m, "WHISPER", from) end
        end
    end)
end)

-- When I log in, guildies already online who missed my changes catch up (Sync.lua): the guild info
-- or editor rank if I wrote the version I hold, and my streamer card.
ns.Sync.Register("board", function(author)
    local b = Board.Store()
    local list = {}
    if not b then return list end
    if b.info and b.info.by == author then list[#list + 1] = b.info.ev end
    if b.rank and b.rank.by == author then list[#list + 1] = b.rank.ev end
    if b.mgr and b.mgr.by == author then list[#list + 1] = b.mgr.ev end
    if b.streamers[author] then list[#list + 1] = b.streamers[author].ev end
    for _, kind in pairs(Board.kinds) do kind.evs(author, list) end
    return list
end, function()
    local out = {}
    for _, m in ipairs(Everything(nil)) do if m.o == nil then out[#out + 1] = m end end
    return out
end)

-- After login, ask one online guildie for the board.
local function AskBoard()
    local peers = {}
    for name, u in pairs(ns.Comm.users) do
        local m = ns.Guild.Get(name)
        if name ~= ns.me and not u.sim and m and m.online then peers[#peers + 1] = name end
    end
    if #peers == 0 then return end
    Board.Ask(peers[math.random(#peers)])
end

-- Ask one guildie for the whole board (their copies are then accepted for a few minutes).
function Board.Ask(peer)
    if not peer or peer == ns.me then return end
    asked[peer] = GetTime()
    ns.Comm.Send({ t = "REQ", w = "BRD" }, "WHISPER", peer)
end
ns.Listen("LOGIN", function() C_Timer.After(50, function() ns.Safe(AskBoard) end) end)

-- Departed guildies' cards go (after a full roster read); live switches itself off after 6 hours.
ns.Listen("ROSTER", function()
    local b = Board.Store()
    if not b or not ns.Guild.complete then return end
    for name in pairs(b.streamers) do
        if name ~= ns.me and not ns.Guild.IsMember(name) then b.streamers[name] = nil end
    end
end)
ns.Listen("LOGIN", function()
    C_Timer.NewTicker(300, function()
        local s = Board.Mine()
        if s and s.live and s.liveAt and GetServerTime() - s.liveAt >= Board.LIVE_FOR then ns.Safe(Board.SetLive, false) end
    end)
end)

-- Dev only: the CurseForge build leaves this out (BigWigs packager's do-not-package markers).
-- A copy installed from source keeps it.
--@do-not-package@
ns.devCommands.editor = function(arg)
    Board.devEditor = (arg == "on") or nil
    ns.Print(Board.devEditor and L.DEV_EDITOR_ON or L.DEV_EDITOR_OFF)
    Changed()
end

-- /ynm dev rank N | off: see the addon as guild rank N (0 = guild master), on this
-- screen only, until /reload or "off". Nothing is sent that my real rank couldn't send.
ns.devCommands.rank = function(arg)
    local n = tonumber(arg)
    if n and n >= 0 and n <= 9 and n == math.floor(n) then
        Board.simRank = n
        ns.Print(string.format(L.DEV_RANK_ON, n))
    else
        Board.simRank = nil
        ns.Print(L.DEV_RANK_OFF)
    end
    Changed()
    ns.Fire("CALENDAR"); ns.Fire("DUNGEONS"); ns.Fire("REQUESTS")
end

-- An optional developer add-on (not part of this addon or its download) can define
-- YeahNahMateDev_Attach and get the addon's table through this command. For anyone without
-- it, this only says so.
ns.devCommands.console = function()
    local attach = _G.YeahNahMateDev_Attach
    if type(attach) == "function" then attach(ns) else ns.Print(L.DEV_CONSOLE_NONE) end
end

-- /ynm dev gm on|off: show the GM tab to test it, kept through /reload. Same test mode
-- as dev editor: you can click everything, but nothing is sent that your rank couldn't send.
ns.devCommands.gm = function(arg)
    local on = arg == "on"
    ns.settings.devGM = on or nil
    Board.devEditor = on or nil
    ns.Print(on and L.DEV_GM_ON or L.DEV_GM_OFF)
    Changed()
end
ns.Listen("LOGIN", function()
    if ns.settings.devGM then Board.devEditor = true; Changed() end
end)
--@end-do-not-package@
