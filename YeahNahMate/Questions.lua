-- Ask the Guild: a guildie posts a question ("what level is Deadmines?") as a
-- card; anyone with the addon answers. The asker gets a pop-up for each answer, can reply, and marks
-- the card answered, ticking the answers that helped (those count towards the Lore Master, 8b).
--
-- Times: a question takes answers for 48 hours. With no answers by then it's gone. With
-- answers it stays open for replies until the asker marks it, up to 7 more days ("waiting").
-- Finished cards stay 30 days and can be searched (Answered view), so the next person finds them.
--
-- Messages
--   QQ { id, tx, tp, lk, u, at, ev }          my question: text, topic, links, answers close at u
--   QQ { id, ev, x = "done", hp = { names } } answered, with the posters whose answers helped
--   QQ { id, ev, x = "cancel" }               taken down by the asker
--   QQ { o = asker, ... }                     a copy (WHISPER, only from a guildie we asked)
--   QA { o = asker, id, p = { { tx, lk, at }, ... }, pv }   all my posts on that card (GUILD)
--   QA { o, id, by = poster, ... }            a copy of someone's posts (WHISPER, asked for)
--   REQ { w = "QS" }                          send me the questions you know (WHISPER)
--   QM { o = asker, id, ev }                  an officer removes the question (GUILD)
--   QM { o = asker, id, who = poster, ev }    an officer removes that guildie's posts on it
--   QM { ..., by = officer }                  a copy of a removal (WHISPER, asked for)
-- Removals are checked against the reader's own roster: only an Info editor rank (Board.lua) may
-- remove, and never their own question. A removal can't be undone, and it's kept apart from the
-- card (g.qremoved) so a resent question or post from someone who missed it stays hidden.
-- Only the asker changes or ends a question, and only a poster changes their posts (the sender is
-- from the game). The author's own message always wins over a copy; a copy wins when it's newer.
--
-- Links (lk, up to 2 on a question or a post):
--   { k = "i", id = itemID, n = name }        an item
--   { k = "q", id = questID, lv = level, n = title }   a quest (picked from the asker's quest log)
--   { k = "d", id = dungeon key }             a dungeon from ns.Dungeons.LIST (shows its levels)
-- Old versions of the addon don't know QQ / QA and drop them quietly (Comm), so nothing breaks.
local ADDON, ns = ...
local L = ns.L

local Q = {}
ns.Questions = Q

Q.OPEN = 48 * 3600              -- a question takes answers this long
Q.WAIT = 7 * 86400              -- then, with answers, this long for the asker to mark it
Q.KEEP = 30 * 86400             -- finished cards stay this long (Answered view, Lore Master points)
Q.MAX_OPEN = 3                  -- open questions per guildie
Q.GAP = 60                      -- seconds between my questions
Q.MAX_Q, Q.MAX_A = 200, 300     -- characters in a question / a post
Q.MAX_POSTS = 4                 -- posts per person on one card (an answer and a few follow-ups)
local MAX_POSTERS = 30          -- people posting on one card
local MAX_LINKS = 2
local MAX_STORE = 400
local MAX_STUBS = 200           -- posts waiting for a question we haven't heard of (a copy batch is <= 80)
local MAX_COPIES = 80           -- questions sent to a guildie who asks
local ASK_WINDOW = 300

Q.TOPICS = { "dungeons", "quests", "class", "professions", "gear", "other" }
local TOPIC = {}
for _, t in ipairs(Q.TOPICS) do TOPIC[t] = true end

local function Clean(s, max)
    if type(s) ~= "string" then return "" end
    return strtrim(ns.CutLetters(strtrim((s:gsub("[|\n\r]", ""))), max))
end
local Future = ns.Future

function Q.Store()
    local g = ns.GuildData()
    if not g then return nil end
    if type(g.questions) ~= "table" then g.questions = {} end
    return g.questions
end

local function Changed() ns.Fire("QUESTIONS") end

---------------------------------------------------------------------------------------------------
-- Removed by an officer
--
-- g.qremoved["owner:id"] = { by, ev, direct }          the whole question
-- g.qremoved["owner:id|poster"] = { by, ev, direct }   all that guildie's posts on it (an answer is
-- one person's posts on a card, so every client hides the same thing and agrees on the points).
-- Kept as long as any card it could hide can still be about: asked + 48 h + 7 days + 30 days.
Q.RM_KEEP = Q.OPEN + Q.WAIT + Q.KEEP

function Q.Removed()
    local g = ns.GuildData()
    if not g then return {} end
    if type(g.qremoved) ~= "table" then g.qremoved = {} end
    return g.qremoved
end

local function KeyOf(q) return q.owner .. ":" .. q.id end

-- Who removed the question (nil if it wasn't).
function Q.RemovedBy(q)
    local r = Q.Removed()[KeyOf(q)]
    return r and r.by or nil
end

-- Were this guildie's posts on the card removed?
function Q.PostsRemoved(q, poster)
    return Q.Removed()[KeyOf(q) .. "|" .. poster] ~= nil
end

-- Can I remove things? (An Ask moderator, Board.lua; /ynm dev editor on tries it on this screen only.)
function Q.CanRemove()
    return ns.Board and ns.Board.Moderates("ask") or false
end

---------------------------------------------------------------------------------------------------
-- Links

-- A link as sent, checked: nil if it's no good.
function Q.CleanLink(l)
    if type(l) ~= "table" then return nil end
    if l.k == "i" and type(l.id) == "number" and l.id > 0 and l.id < 10000000 then
        return { k = "i", id = math.floor(l.id), n = Clean(l.n, 60) }
    elseif l.k == "q" and type(l.id) == "number" and l.id > 0 and l.id < 10000000 then
        local lv = tonumber(l.lv)
        return { k = "q", id = math.floor(l.id), lv = lv and math.max(0, math.min(100, math.floor(lv))) or nil, n = Clean(l.n, 60) }
    elseif l.k == "d" and type(l.id) == "string" and ns.Dungeons.BY_KEY[l.id] then
        return { k = "d", id = l.id }
    end
    return nil
end

local function CleanLinks(list)
    local out = {}
    if type(list) ~= "table" then return out end
    for i = 1, math.min(#list, MAX_LINKS) do
        local l = Q.CleanLink(list[i])
        if l then out[#out + 1] = l end
    end
    return out
end
Q.CleanLinks = CleanLinks

-- What a link says on a card.
function Q.LinkText(l)
    if l.k == "d" then
        local d = ns.Dungeons.BY_KEY[l.id]
        return d and string.format(L.Q_LINK_DUNGEON, d.name, d.min, d.max) or l.id
    elseif l.k == "q" then
        local name = l.n ~= "" and l.n or nil
        if not name and C_QuestLog and C_QuestLog.GetTitleForQuestID then
            -- Only a real answer: a failed call's error text isn't a quest name .
            local ok, title = pcall(C_QuestLog.GetTitleForQuestID, l.id)
            name = ok and ns.Public(title, "string") or nil
        end
        name = name or ("Quest " .. l.id)
        return l.lv and l.lv > 0 and string.format(L.Q_LINK_QUEST, l.lv, name) or name
    else
        local name
        if C_Item and C_Item.GetItemNameByID then
            local ok, n = pcall(C_Item.GetItemNameByID, l.id)
            name = ok and ns.Public(n, "string") or nil
        end
        return name or (l.n ~= "" and l.n) or ("Item " .. l.id)
    end
end

-- Is this quest in my quest log right now?
function Q.InMyLog(questID)
    if not (C_QuestLog and C_QuestLog.GetLogIndexForQuestID) then return false end
    local ok, i = pcall(C_QuestLog.GetLogIndexForQuestID, questID)
    return ok and type(i) == "number" and i > 0 or false
end

-- The quests in my log: { { id, lv, n, zone } }, for the quest picker.
function Q.MyQuests()
    local out = {}
    if not (C_QuestLog and C_QuestLog.GetNumQuestLogEntries and C_QuestLog.GetInfo) then return out end
    local ok, n = pcall(C_QuestLog.GetNumQuestLogEntries)
    if not ok or type(n) ~= "number" then return out end
    local zone = ""
    for i = 1, math.min(n, 60) do
        local ok2, info = pcall(C_QuestLog.GetInfo, i)
        if ok2 and type(info) == "table" then
            local title = ns.Public(info.title, "string")
            if info.isHeader then
                zone = title or ""
            elseif title and type(info.questID) == "number" and not info.isHidden then
                out[#out + 1] = { id = info.questID, lv = tonumber(ns.Public(info.level)) or 0, n = title, zone = zone }
            end
        end
    end
    return out
end

---------------------------------------------------------------------------------------------------
-- State

-- Posters other than the asker who have posted, sorted.
function Q.Answerers(q)
    local list = {}
    for name, e in pairs(q.posts or {}) do
        if name ~= q.owner and #e.p > 0 and not Q.PostsRemoved(q, name) then list[#list + 1] = name end
    end
    table.sort(list)
    return list
end

function Q.AnswerCount(q)
    local n = 0
    for name, e in pairs(q.posts or {}) do
        if name ~= q.owner and #e.p > 0 and not Q.PostsRemoved(q, name) then n = n + 1 end
    end
    return n
end

-- "open" (taking answers), "waiting" (answered, for the asker to mark), "done", "cancel",
-- "expired" (nobody answered, or never marked), "removed" (by an officer).
function Q.State(q, now)
    if Q.RemovedBy(q) then return "removed" end
    if q.x == "done" then return "done" end
    if q.x == "cancel" then return "cancel" end
    -- Posts that came before their question (a stub) have no question yet: nothing to show.
    if q.stub or type(q.u) ~= "number" then return "expired" end
    now = now or GetServerTime()
    if now < q.u then return "open" end
    if Q.AnswerCount(q) > 0 and now < q.u + Q.WAIT then return "waiting" end
    return "expired"
end

-- Can people still post on it? (Open, or answered and waiting for the asker.)
function Q.Live(q, now)
    local s = Q.State(q, now)
    return s == "open" or s == "waiting"
end

-- When it finished (nil while live).
function Q.EndTime(q, now)
    local rm = Q.Removed()[KeyOf(q)]
    if rm and not q.stub then return math.min(rm.ev, q.x and (q.endAt or q.ev) or rm.ev) end
    if q.x then return q.endAt or q.ev end
    if q.stub or type(q.u) ~= "number" then return q.at or 0 end
    now = now or GetServerTime()
    if Q.Live(q, now) then return nil end
    if Q.AnswerCount(q) > 0 then return q.u + Q.WAIT end
    return q.u
end

-- Every post on a card, oldest first: { name, tx, lk, at, i (index in that poster's list) }.
function Q.Thread(q)
    local list = {}
    for name, e in pairs(q.posts or {}) do
        for i, p in ipairs(Q.PostsRemoved(q, name) and {} or e.p) do
            list[#list + 1] = { name = name, tx = p.tx, lk = p.lk, at = p.at, i = i }
        end
    end
    table.sort(list, function(a, b)
        if a.at ~= b.at then return a.at < b.at end
        if a.name ~= b.name then return a.name < b.name end
        return a.i < b.i
    end)
    return list
end

local function Visible(q)
    return not q.stub and (q.owner == ns.me or ns.Guild.IsMember(q.owner)) and not Q.RemovedBy(q)
end

-- Text to search in: the question, its links, who asked, and the posts.
local function Haystack(q)
    if q.hay then return q.hay end
    local parts = { q.tx, q.owner }
    for _, l in ipairs(q.lk or {}) do parts[#parts + 1] = Q.LinkText(l) end
    for name, e in pairs(q.posts or {}) do
        parts[#parts + 1] = name
        for _, p in ipairs(Q.PostsRemoved(q, name) and {} or e.p) do
            parts[#parts + 1] = p.tx
            for _, l in ipairs(p.lk or {}) do parts[#parts + 1] = Q.LinkText(l) end
        end
    end
    q.hay = strlower(table.concat(parts, " "))
    return q.hay
end

-- Is a card in a view? s is its state.
local function InView(q, view, s)
    if view == "open" then return s == "open" or s == "waiting" end
    if view == "answered" then return s == "done" end
    return (q.owner == ns.me or (q.posts and q.posts[ns.me] and #q.posts[ns.me].p > 0))
        and s ~= "cancel" and not (s == "expired" and Q.AnswerCount(q) == 0 and q.owner ~= ns.me)
end

-- How many in each view, in one pass (the Ask tab's sidebar): { open = n, mine = n, answered = n }.
function Q.Counts()
    local c = { open = 0, mine = 0, answered = 0 }
    local now = GetServerTime()
    for _, q in pairs(Q.Store() or {}) do
        if Visible(q) then
            local s = Q.State(q, now)
            for view in pairs(c) do if InView(q, view, s) then c[view] = c[view] + 1 end end
        end
    end
    return c
end

-- view: "open" (open and waiting), "mine" (asked or posted on by me), "answered" (done).
-- topic filters (nil = all); filter is text to look for. Newest first; in Open, mine first.
function Q.List(view, topic, filter)
    local store = Q.Store()
    local list = {}
    if not store then return list end
    local now = GetServerTime()
    filter = strlower(strtrim(filter or ""))
    for key, q in pairs(store) do
        if Visible(q) and (not topic or q.tp == topic) then
            local keep = InView(q, view, Q.State(q, now))
            if keep and (filter == "" or strfind(Haystack(q), filter, 1, true)) then
                q.key = key
                list[#list + 1] = q
            end
        end
    end
    table.sort(list, function(a, b)
        if view == "open" then
            local am, bm = a.owner == ns.me, b.owner == ns.me
            if am ~= bm then return am end
        end
        return (a.at or 0) > (b.at or 0)
    end)
    return list
end

function Q.OpenCount()
    return #Q.List("open")
end

-- My questions waiting for me to mark them.
function Q.MyWaiting()
    local n = 0
    local store = Q.Store()
    if not store then return 0 end
    local now = GetServerTime()
    for _, q in pairs(store) do
        if q.owner == ns.me and not q.stub and Q.State(q, now) == "waiting" then n = n + 1 end
    end
    return n
end

-- Past answered questions that look like this one (words of 4+ letters in common), best first.
function Q.Similar(text, max)
    local words = {}
    for w in strlower(text or ""):gmatch("[%a']+") do
        if #w >= 4 then words[#words + 1] = w end
    end
    if #words == 0 then return {} end
    local scored = {}
    for _, q in ipairs(Q.List("answered")) do
        local hay, n = strlower(q.tx), 0
        for _, w in ipairs(words) do if strfind(hay, w, 1, true) then n = n + 1 end end
        if n > 0 then scored[#scored + 1] = { q = q, n = n } end
    end
    table.sort(scored, function(a, b)
        if a.n ~= b.n then return a.n > b.n end
        return (a.q.at or 0) > (b.q.at or 0)
    end)
    local out = {}
    for i = 1, math.min(#scored, max or 3) do out[i] = scored[i].q end
    return out
end

---------------------------------------------------------------------------------------------------
-- Points and the Lore Master (8b)
--
-- 1 point per finished card (marked answered in the last 30 days) where the asker ticked your answer.
-- Counted from the cards everyone holds, so every client agrees. The Lore Master has the most points
-- (at least LORE_MIN); on a tie, whoever got to that many first. Points go to the person (0.12.0,
-- Alts.lua: all their characters count as one, named by their main), never for your own questions.

Q.LORE_MIN = 3
local board, boardAt = nil, -1000

local function Board()
    local now = GetServerTime()
    if board and now - boardAt < 60 then return board end
    local store = Q.Store()
    local cards = {}
    for _, q in pairs(store or {}) do
        if q.x == "done" and not q.stub and q.hp and Visible(q) then
            local e = Q.EndTime(q, now) or 0
            if e > now - Q.KEEP then cards[#cards + 1] = { q = q, e = e } end
        end
    end
    table.sort(cards, function(a, b)
        if a.e ~= b.e then return a.e < b.e end
        return a.q.owner .. a.q.id < b.q.owner .. b.q.id
    end)
    local pts, reached = {}, {}
    local Person = ns.Alts.Person
    for _, c in ipairs(cards) do
        local owner, got = Person(c.q.owner), {}
        for name in pairs(c.q.hp) do
            local who = Person(name)
            if who ~= owner and not got[who] and (name == ns.me or ns.Guild.IsMember(name)) and not Q.PostsRemoved(c.q, name) then
                got[who] = true
                pts[who] = (pts[who] or 0) + 1
                reached[who] = c.e
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
    local lore = list[1] and list[1].n >= Q.LORE_MIN and list[1].name or nil
    board, boardAt = { list = list, pts = pts, lore = lore }, now
    return board
end
ns.Listen("QUESTIONS", function() board = nil end)
ns.Listen("ROSTER", function() board = nil end)
ns.Listen("ALTS", function() board = nil end)

-- Everyone with points, most first: { { name, n, at } }.
function Q.Top(max)
    local list, out = Board().list, {}
    for i = 1, math.min(#list, max or 10) do out[i] = list[i] end
    return out
end

function Q.Points(name) return Board().pts[ns.Alts.Person(name)] or 0 end

-- The Lore Master (the person's main), or nil.
function Q.LoreMaster() return Board().lore end

-- Is this character the Lore Master (or one of their characters)?
function Q.IsLoreMaster(name)
    local lore = Board().lore
    return lore ~= nil and name ~= nil and ns.Alts.Person(name) == lore
end

function Q.Get(key)
    local store = Q.Store()
    local q = store and store[key]
    if q and not q.stub then q.key = key; return q end
    return nil
end

---------------------------------------------------------------------------------------------------
-- Mine

local function QuestionMessage(q)
    return { t = "QQ", id = q.id, tx = q.tx, tp = q.tp, lk = q.lk, u = q.u, at = q.at, ev = q.ev }
end

local function FullQuestionMessage(q)
    local m = QuestionMessage(q)
    m.x = q.x
    if q.x == "done" then m.hp = Q.Helpers(q) end
    return m
end

function Q.Helpers(q)
    local list = {}
    for name in pairs(q.hp or {}) do list[#list + 1] = name end
    table.sort(list)
    return list
end

local lastAsk = -1000

-- Ask a question. Returns its key, or nil and why ("empty", "full", "wait").
function Q.Ask(text, topic, links)
    local store = Q.Store()
    if not store or not ns.me then return nil, "none" end
    text = Clean(text, Q.MAX_Q)
    if #text < 3 then return nil, "empty" end
    if not TOPIC[topic] then topic = "other" end
    local now = GetServerTime()
    local open = 0
    for _, q in pairs(store) do
        -- Counted like every other guildie counts them (OpenCountOf): a removed one keeps its place
        -- until its 48 hours are up, as guildies who haven't heard of the removal yet still count it.
        if q.owner == ns.me and not q.stub and not q.x and type(q.u) == "number" and now < q.u then open = open + 1 end
    end
    if open >= Q.MAX_OPEN then return nil, "full" end
    if GetTime() - lastAsk < Q.GAP then return nil, "wait" end
    lastAsk = GetTime()
    local id = now
    while store[ns.me .. ":" .. id] do id = id + 1 end
    local q = { owner = ns.me, id = id, tx = text, tp = topic, lk = CleanLinks(links), u = now + Q.OPEN,
                at = now, ev = now, posts = {}, direct = true }
    local key = ns.me .. ":" .. id
    store[key] = q
    ns.Comm.Send(QuestionMessage(q), "GUILD")
    Changed()
    return key
end

-- The asker marks it answered: helpers are the posters whose answers helped (never the asker).
function Q.Finish(key, helpers)
    local q = Q.Get(key)
    if not q or q.owner ~= ns.me or not Q.Live(q) then return false end
    q.hp = {}
    for _, name in ipairs(helpers or {}) do
        if name ~= ns.me and q.posts[name] and #q.posts[name].p > 0 and not Q.PostsRemoved(q, name) then q.hp[name] = true end
    end
    q.x = "done"
    q.ev = math.max(GetServerTime(), q.ev + 1)
    q.endAt = GetServerTime()
    q.hay = nil
    ns.Comm.Send({ t = "QQ", id = q.id, ev = q.ev, x = "done", hp = Q.Helpers(q) }, "GUILD")
    Changed()
    return true
end

function Q.Cancel(key)
    local q = Q.Get(key)
    if not q or q.owner ~= ns.me or q.x then return false end
    q.x = "cancel"
    q.ev = math.max(GetServerTime(), q.ev + 1)
    q.endAt = GetServerTime()
    ns.Comm.Send({ t = "QQ", id = q.id, ev = q.ev, x = "cancel" }, "GUILD")
    Changed()
    return true
end

local function SendMyPosts(q)
    local mine = q.posts[ns.me]
    ns.Comm.Send({ t = "QA", o = q.owner, id = q.id, p = mine.p, pv = mine.pv }, "GUILD")
end

-- Post an answer (or, for the asker, a follow-up). Returns true, or nil and why.
function Q.Post(key, text, links)
    local q = Q.Get(key)
    if not q or not ns.me then return nil, "none" end
    if not Q.Live(q) then return nil, "closed" end
    if Q.PostsRemoved(q, ns.me) then return nil, "removed" end
    text = Clean(text, Q.MAX_A)
    links = CleanLinks(links)
    if text == "" and #links == 0 then return nil, "empty" end
    local mine = q.posts[ns.me]
    if mine and #mine.p >= Q.MAX_POSTS then return nil, "full" end
    if not mine then
        local n = 0
        for _ in pairs(q.posts) do n = n + 1 end
        if n >= MAX_POSTERS then return nil, "crowded" end
        mine = { p = {}, pv = 0, direct = true }
        q.posts[ns.me] = mine
    end
    local now = GetServerTime()
    mine.p[#mine.p + 1] = { tx = text, lk = links, at = now }
    mine.pv = math.max(now, (mine.pv or 0) + 1)
    mine.direct = true
    q.hay = nil
    SendMyPosts(q)
    Changed()
    return true
end

-- Take one of my posts back (to fix a typo: take it back and post again).
function Q.DeletePost(key, i)
    local q = Q.Get(key)
    local mine = q and q.posts[ns.me]
    if not mine or not mine.p[i] then return false end
    table.remove(mine.p, i)
    mine.pv = math.max(GetServerTime(), (mine.pv or 0) + 1)
    q.hay = nil
    SendMyPosts(q)
    Changed()
    return true
end

-- An officer removes a question (poster nil) or one guildie's posts on it. Not my own question (I
-- take that down myself) and not my own posts (I take those back). Returns true if removed.
function Q.Remove(key, poster)
    local q = Q.Get(key)
    if not q or not ns.me or not Q.CanRemove() or q.owner == ns.me or Q.RemovedBy(q) then return false end
    if poster and (poster == ns.me or Q.PostsRemoved(q, poster) or not (q.posts[poster] and #q.posts[poster].p > 0)) then
        return false
    end
    local now = GetServerTime()
    local r = { o = q.owner, id = q.id, who = poster, by = ns.me, ev = now, direct = true }
    if not ns.Board.CanModerate(ns.me, "ask") then
        -- /ynm dev editor on without the rank: on this screen only, never sent or counted.
        r.dev = true
        ns.Log("(dev) removal not sent: your guild rank isn't an editor rank")
    end
    Q.Removed()[key .. (poster and ("|" .. poster) or "")] = r
    q.hay = nil
    if not r.dev then ns.Comm.Send({ t = "QM", o = q.owner, id = q.id, who = poster, ev = now }, "GUILD") end
    Changed()
    return true
end

---------------------------------------------------------------------------------------------------
-- Receiving

local asked = {}

local function OpenCountOf(store, owner, now)
    local n, oldestKey, oldestEv = 0, nil, nil
    for k, q in pairs(store) do
        if q.owner == owner and not q.stub and not q.x and now < q.u then
            n = n + 1
            if not oldestEv or q.ev < oldestEv then oldestKey, oldestEv = k, q.ev end
        end
    end
    return n, oldestKey, oldestEv
end

local function CleanHelpers(list, owner)
    local hp = {}
    if type(list) ~= "table" then return hp end
    for i = 1, math.min(#list, MAX_POSTERS) do
        local name = type(list[i]) == "string" and ns.Key(list[i]) or nil
        if name and name ~= owner then hp[name] = true end
    end
    return hp
end

-- A question (the asker's own, or a copy). Returns true if it was new or newer and kept.
local function TakeQuestion(owner, msg, direct)
    local store = Q.Store()
    if not store or owner == ns.me or not ns.Guild.IsMember(owner) then return false end
    if type(msg.id) ~= "number" or Future(msg.ev, not direct) then return false end
    local key = owner .. ":" .. msg.id
    local old = store[key]
    if old and old.stub then old = nil end
    if old and not ns.Newer(old.ev, old.direct, msg.ev, direct) then return false end
    local now = GetServerTime()
    local tx = Clean(msg.tx, Q.MAX_Q)
    local q = old or { owner = owner, id = msg.id, posts = (store[key] and store[key].posts) or {} }
    if msg.x == "done" or msg.x == "cancel" then
        -- A finished one we never saw needs what was asked, or it's no use to anyone.
        if not old and tx == "" then return false end
        if not old then
            q.tx, q.tp, q.lk = tx, TOPIC[msg.tp] and msg.tp or "other", CleanLinks(msg.lk)
            q.at = type(msg.at) == "number" and math.min(msg.at, now) or msg.ev
            q.u = type(msg.u) == "number" and math.min(msg.u, q.at + Q.OPEN) or (q.at + Q.OPEN)
        end
        q.x, q.ev, q.direct, q.endAt = msg.x, msg.ev, direct or nil, math.min(msg.ev, now)
        q.hp = msg.x == "done" and CleanHelpers(msg.hp, owner) or nil
        q.stub, q.hay = nil, nil
        store[key] = q
        return true, not old
    end
    if tx == "" or type(msg.u) ~= "number" then
        ns.Log("dropped: bad question from " .. owner)
        return false
    end
    -- At most MAX_OPEN open from one guildie: a newer one past the limit means our oldest open copy
    -- is stale (taken down while we were offline); the newer one takes its place (as for requests).
    if not old then
        local n, oldestKey, oldestEv = OpenCountOf(store, owner, now)
        if n >= Q.MAX_OPEN then
            if not oldestKey or msg.ev <= oldestEv then return false end
            -- Keep its posts in a stub (found by the multi.py soak): copies can arrive newest first, so the
            -- "stale" one may still be live and come straight back; its posts, mine included, must
            -- not be lost with it. A stub isn't shown or sent, and goes after 2 days.
            local gone = store[oldestKey]
            store[oldestKey] = { owner = gone.owner, id = gone.id, stub = true, at = GetServerTime(), posts = gone.posts or {} }
        end
    end
    q.tx, q.tp, q.lk = tx, TOPIC[msg.tp] and msg.tp or "other", CleanLinks(msg.lk)
    q.at = type(msg.at) == "number" and math.min(msg.at, now) or (old and old.at) or now
    q.u = math.min(msg.u, q.at + Q.OPEN, now + Q.OPEN)
    q.ev, q.x, q.hp, q.direct, q.stub, q.hay = msg.ev, nil, nil, direct or nil, nil, nil
    store[key] = q
    return true, not old
end

ns.Comm.On("QQ", function(msg, from, channel, isSelf)
    if isSelf then return end
    if msg.o == nil then
        local ok, isNew = TakeQuestion(from, msg, true)
        if ok then
            Changed()
            local q = Q.Get(from .. ":" .. msg.id)
            if isNew and q and Q.State(q) == "open" then ns.Fire("QUESTION_ASKED", q) end
        end
        return
    end
    if channel ~= "WHISPER" or not asked[from] or GetTime() - asked[from] > ASK_WINDOW then
        ns.Log("dropped: a question copy from " .. from .. " that we didn't ask for")
        return
    end
    asked[from] = GetTime()
    local owner = ns.Key(msg.o)
    if owner and owner ~= from and TakeQuestion(owner, msg, false) then Changed() end
end)

local function CleanPosts(list)
    if type(list) ~= "table" or #list > Q.MAX_POSTS then return nil end
    local out, now = {}, GetServerTime()
    for _, p in ipairs(list) do
        if type(p) ~= "table" then return nil end
        local tx, lk = Clean(p.tx, Q.MAX_A), CleanLinks(p.lk)
        if tx ~= "" or #lk > 0 then
            out[#out + 1] = { tx = tx, lk = lk, at = type(p.at) == "number" and math.min(p.at, now) or now }
        end
    end
    return out
end

-- Someone's posts on a card. Returns true if kept, and how many posts are new.
local function TakePosts(owner, id, poster, msg, direct)
    local store = Q.Store()
    if not store or poster == ns.me or not ns.Guild.IsMember(poster) then return false end
    if owner ~= ns.me and not ns.Guild.IsMember(owner) then return false end
    if type(id) ~= "number" or Future(msg.pv, not direct) then return false end
    local p = CleanPosts(msg.p)
    if not p then ns.Log("dropped: bad posts from " .. poster) return false end
    local key = owner .. ":" .. id
    local q = store[key]
    if not q then
        -- Posts on a question we haven't heard of yet: kept until the question comes (copies).
        if owner == ns.me then return false end
        local stubs = 0
        for _, s in pairs(store) do if s.stub then stubs = stubs + 1 end end
        if stubs >= MAX_STUBS then
            ns.Log("dropped: posts from " .. poster .. " on a question we haven't heard of (too many waiting)")
            return false
        end
        q = { owner = owner, id = id, stub = true, at = GetServerTime(), posts = {} }
        store[key] = q
    end
    q.posts = q.posts or {}
    local old = q.posts[poster]
    if old and not ns.Newer(old.pv, old.direct, msg.pv, direct) then return false end
    -- No new posters on a finished card (their own edits and take-backs still count).
    -- (A finished card's copy still brings the asker's posts and the ones that helped.)
    if not old and q.x and not q.stub and poster ~= owner and not (q.hp and q.hp[poster]) then return false end
    if not old then
        local n = 0
        for _ in pairs(q.posts) do n = n + 1 end
        if n >= MAX_POSTERS then return false end
    end
    local before = old and #old.p or 0
    q.posts[poster] = { p = p, pv = msg.pv, direct = direct or nil }
    q.hay = nil
    return true, math.max(0, #p - before), q
end

ns.Comm.On("QA", function(msg, from, channel, isSelf)
    if isSelf then return end
    local owner = type(msg.o) == "string" and ns.Key(msg.o) or nil
    if not owner then return end
    if msg.by == nil then
        local ok, added, q = TakePosts(owner, msg.id, from, msg, true)
        if not ok then return end
        Changed()
        if added > 0 and q and not q.stub and Q.Live(q) and not Q.PostsRemoved(q, from) then
            if owner == ns.me then
                ns.Fire("QUESTION_ANSWERED", from, q)
            elseif from == owner and q.posts[ns.me] and #q.posts[ns.me].p > 0 then
                ns.Fire("QUESTION_REPLY", q)
            end
        end
        return
    end
    if channel ~= "WHISPER" or not asked[from] or GetTime() - asked[from] > ASK_WINDOW then
        ns.Log("dropped: an answer copy from " .. from .. " that we didn't ask for")
        return
    end
    asked[from] = GetTime()
    local poster = type(msg.by) == "string" and ns.Key(msg.by) or nil
    if poster and poster ~= from and TakePosts(owner, msg.id, poster, msg, false) then Changed() end
end)

-- A removal from an officer (checked against my roster). Removals can't be changed, so a second
-- one of the same thing only matters if it's earlier: then everyone keeps the same one (the
-- earliest), and the sync counts agree.
local function TakeRemoval(officer, msg, direct)
    if not officer or officer == ns.me or not ns.Board.CanModerate(officer, "ask") then
        ns.Log("dropped: a removal from " .. tostring(officer) .. ", who doesn't moderate Ask")
        return false
    end
    local owner = type(msg.o) == "string" and ns.Key(msg.o) or nil
    if not owner or owner == officer or type(msg.id) ~= "number" then return false end
    if owner ~= ns.me and not ns.Guild.IsMember(owner) then return false end
    local who
    if msg.who ~= nil then
        who = type(msg.who) == "string" and ns.Key(msg.who) or nil
        if not who or who == officer then return false end
    end
    if type(msg.ev) ~= "number" or Future(msg.ev, not direct) or msg.ev < GetServerTime() - Q.RM_KEEP then return false end
    local key = owner .. ":" .. msg.id
    local rk = key .. (who and ("|" .. who) or "")
    local store = Q.Removed()
    local old = store[rk]
    if old and (old.ev < msg.ev or (old.ev == msg.ev and old.by <= officer)) then return false end
    store[rk] = { o = owner, id = msg.id, who = who, by = officer, ev = msg.ev, direct = direct or nil }
    local q = Q.Store() and Q.Store()[key]
    if q then q.hay = nil end
    return true
end

local function RemovalMessage(r, asCopy)
    local m = { t = "QM", o = r.o, id = r.id, who = r.who, ev = r.ev }
    if asCopy then m.by = r.by end
    return m
end

-- Removals that go out: real ones (not /ynm dev editor ones) within RM_KEEP; with by, only that
-- officer's. Newest first.
local function Removals(by, now)
    local list = {}
    for _, r in pairs(Q.Removed()) do
        if not r.dev and (not by or r.by == by) and r.ev > now - Q.RM_KEEP then list[#list + 1] = r end
    end
    table.sort(list, function(a, b) return a.ev > b.ev end)
    return list
end

ns.Comm.On("QM", function(msg, from, channel, isSelf)
    if isSelf then return end
    if msg.by == nil then
        if TakeRemoval(from, msg, true) then Changed() end
        return
    end
    if channel ~= "WHISPER" or not asked[from] or GetTime() - asked[from] > ASK_WINDOW then
        ns.Log("dropped: a removal copy from " .. from .. " that we didn't ask for")
        return
    end
    asked[from] = GetTime()
    local by = type(msg.by) == "string" and ns.Key(msg.by) or nil
    if by and by ~= from and TakeRemoval(by, msg, false) then Changed() end
end)

-- Copies for a guildie who asks: questions of the last 30 days, newest first, each followed by its
-- posts. Finished ones carry only the helpful posts (that's the answer people come back for).
local function PostMessages(q, poster, asCopy)
    local e = q.posts[poster]
    local m = { t = "QA", o = q.owner, id = q.id, p = e.p, pv = e.pv }
    if asCopy then m.by = poster end
    return m
end

local function Copies(forWhom)
    local store = Q.Store()
    local out = {}
    if not store then return out end
    local now = GetServerTime()
    local list = {}
    for _, q in pairs(store) do
        local ended = Q.EndTime(q, now)
        if not q.stub and q.owner ~= forWhom and (q.owner == ns.me or ns.Guild.IsMember(q.owner))
            and (not ended or ended > now - Q.KEEP) and not Q.RemovedBy(q) then
            list[#list + 1] = q
        end
    end
    table.sort(list, function(a, b) return (a.ev or 0) > (b.ev or 0) end)
    for i = 1, math.min(#list, MAX_COPIES) do
        local q = list[i]
        local m = FullQuestionMessage(q)
        if q.owner ~= ns.me then m.o = q.owner end
        out[#out + 1] = m
        local live = Q.Live(q, now)
        for poster, e in pairs(q.posts or {}) do
            if poster ~= forWhom and not Q.PostsRemoved(q, poster) and (#e.p > 0 or live) and (live or (q.hp and q.hp[poster]) or poster == q.owner and q.x == "done") then
                out[#out + 1] = PostMessages(q, poster, poster ~= ns.me)
            end
        end
    end
    -- What officers removed (mine first-hand, without by), so nothing removed comes back.
    local rms = Removals(nil, now)
    for i = 1, math.min(#rms, MAX_COPIES) do
        if rms[i].by ~= forWhom then out[#out + 1] = RemovalMessage(rms[i], rms[i].by ~= ns.me) end
    end
    return out
end

local answered = {}
ns.Comm.On("REQ", function(msg, from, channel, isSelf)
    if isSelf or channel ~= "WHISPER" or msg.w ~= "QS" then return end
    local now = GetTime()
    if answered[from] and now - answered[from] < 60 then return end
    answered[from] = now
    for _, m in ipairs(Copies(from)) do ns.Comm.Send(m, "WHISPER", from, "BULK") end
end)

-- My own: my questions (30 days) and my posts on cards that are live or where mine helped.
local function MyMessages()
    local out = {}
    local store = Q.Store()
    if not store then return out end
    local now = GetServerTime()
    local qs = {}
    for _, q in pairs(store) do
        local ended = Q.EndTime(q, now)
        if not q.stub and (not ended or ended > now - Q.KEEP) then
            if q.owner == ns.me then qs[#qs + 1] = q end
        end
    end
    -- Finished ones first, so a guildie's stale open copies close before new ones land.
    table.sort(qs, function(a, b)
        if (a.x and true or false) ~= (b.x and true or false) then return a.x and true or false end
        return (a.ev or 0) < (b.ev or 0)
    end)
    for _, q in ipairs(qs) do
        out[#out + 1] = FullQuestionMessage(q)
        if q.posts[ns.me] then out[#out + 1] = PostMessages(q, ns.me, false) end
    end
    for _, q in pairs(store) do
        local e = q.posts and q.posts[ns.me]
        if not q.stub and q.owner ~= ns.me and e
            and (Q.Live(q, now) or (q.hp and q.hp[ns.me]) or (type(q.u) == "number" and now < q.u)) then
            out[#out + 1] = PostMessages(q, ns.me, false)
        end
    end
    for _, r in ipairs(Removals(ns.me, now)) do out[#out + 1] = RemovalMessage(r, false) end
    return out
end
Q.MyMessages = MyMessages

ns.Listen("HI_IN", function(msg, from)
    if msg.ask ~= true or (ns.Sim and ns.Sim.IsFake(from)) then return end
    C_Timer.After(6 + math.random() * 4, function()
        for _, m in ipairs(MyMessages()) do ns.Comm.Send(m, "WHISPER", from, "BULK") end
    end)
end)

-- When I log in, guildies already online who missed my changes catch up (Sync.lua).
-- The versions counted are the same things MyMessages sends (an author's posts on a finished card
-- of someone else's only when they helped), so a guildie never asks for something that won't come.
-- What's counted: the author's own questions, their posts on them, and their posts on others' cards
-- only while that card is in its 48 hours (now < u). Whether a card is finished, or who helped,
-- depends on what each side has heard; u doesn't, so both sides count the same posts. (Counting by
-- "live"/"helped" made a guildie ask on every hello and never get them.) Posts
-- on fakes' cards in sim mode aren't counted: they never go out (Comm.Send).
local function CountedPost(q, author, now)
    if q.stub or type(q.u) ~= "number" then return false end
    if q.owner == author then return true end
    if ns.Sim and ns.Sim.IsOn() and ns.Sim.IsFake(q.owner) then return false end
    return now < q.u
end

ns.Sync.Register("questions", function(author)
    local list = {}
    local now = GetServerTime()
    for _, q in pairs(Q.Store() or {}) do
        if not q.stub then
            if q.owner == author then list[#list + 1] = q.ev end
            local e = q.posts and q.posts[author]
            if e and e.pv and CountedPost(q, author, now) then list[#list + 1] = e.pv end
        end
    end
    -- An officer's removals (the same ones MyMessages sends; in sim mode not ones about fakes).
    local sim = ns.Sim and ns.Sim.IsOn()
    for _, r in ipairs(Removals(author, now)) do
        if not (sim and (ns.Sim.IsFake(r.o) or ns.Sim.IsFake(r.who))) then list[#list + 1] = r.ev end
    end
    return list
end, MyMessages)

local function AskQuestions()
    local peers = {}
    for name, u in pairs(ns.Comm.users) do
        local m = ns.Guild.Get(name)
        if name ~= ns.me and not u.sim and m and m.online then peers[#peers + 1] = name end
    end
    if #peers == 0 then return end
    local peer = peers[math.random(#peers)]
    asked[peer] = GetTime()
    ns.Comm.Send({ t = "REQ", w = "QS" }, "WHISPER", peer)
end
ns.Listen("LOGIN", function() C_Timer.After(65, function() ns.Safe(AskQuestions) end) end)

-- Tidy: finished ones go after 30 days; stubs nobody filled after 2 days; departed guildies'
-- questions and posts (after a full roster read); the oldest finished if there are too many.
local function Tidy()
    local store = Q.Store()
    if not store then return end
    local now = GetServerTime()
    local changed = false
    local ended = {}
    for key, q in pairs(store) do
        local e = not q.stub and Q.EndTime(q, now)
        if (q.stub and (q.at or 0) < now - 2 * 86400) or (e and e < now - Q.KEEP)
            or (ns.Guild.complete and q.owner ~= ns.me and not ns.Guild.IsMember(q.owner)) then
            store[key] = nil; changed = true
        else
            if ns.Guild.complete then
                for name in pairs(q.posts or {}) do
                    if name ~= ns.me and not ns.Guild.IsMember(name) then q.posts[name] = nil; q.hay = nil; changed = true end
                end
            end
            if e then ended[#ended + 1] = { key, e } end
        end
    end
    local rms = Q.Removed()
    for rk, r in pairs(rms) do
        if type(r) ~= "table" or type(r.ev) ~= "number" or r.ev < now - Q.RM_KEEP then rms[rk] = nil end
    end
    -- Stubs don't count: they have their own limit (MAX_STUBS) and must never push real cards out.
    local count = 0
    for _, q in pairs(store) do if not q.stub then count = count + 1 end end
    if count > MAX_STORE then
        table.sort(ended, function(a, b) return a[2] < b[2] end)
        for i = 1, math.min(#ended, count - MAX_STORE) do store[ended[i][1]] = nil end
        changed = true
    end
    if changed then Changed() end
end
Q.Tidy = Tidy
ns.Listen("LOGIN", function()
    C_Timer.After(7, function() ns.Safe(Tidy) end)
    C_Timer.NewTicker(600, function() ns.Safe(Tidy) end)
    -- Questions of mine waiting to be marked: a reminder once, a little after logging in.
    C_Timer.After(25, function()
        local n = Q.MyWaiting()
        if n > 0 then ns.Fire("QUESTIONS_WAITING", n) end
    end)
end)
ns.Listen("ROSTER", function() if ns.Guild.complete then ns.Safe(Tidy) end end)

-- The search text (q.hay) and q.key are rebuilt when needed; they don't go in the saved file (a copy
-- of every card's text made the file bigger, and old link names stuck).
local function StripCached()
    for _, g in pairs(ns.db and ns.db.guilds or {}) do
        if type(g) == "table" and type(g.questions) == "table" then
            for _, q in pairs(g.questions) do q.hay, q.key = nil, nil end
        end
    end
end
ns.OnEvent("PLAYER_LOGOUT", function() ns.Safe(StripCached) end)
ns.Listen("LOGIN", function() ns.Safe(StripCached) end)

-- Once per account: forget every question from before release (test questions, 12 Nov 2026).
-- Nobody else had this version then, so there are no other copies to take down.
ns.Listen("LOGIN", function()
    if not ns.db or ns.db.questionsCleared1 then return end
    for _, g in pairs(ns.db.guilds or {}) do
        if type(g) == "table" then g.questions, g.qremoved = nil, nil end
    end
    ns.db.questionsCleared1 = true
    Changed()
end)

-- Sim mode off: fake guildies' questions and posts go.
function Q.PurgeFakes(isFake)
    local store = Q.Store()
    if not store then return end
    for key, q in pairs(store) do
        if isFake(q.owner) then
            store[key] = nil
        else
            for name in pairs(q.posts or {}) do if isFake(name) then q.posts[name] = nil; q.hay = nil end end
            if q.hp then for name in pairs(q.hp) do if isFake(name) then q.hp[name] = nil end end end
        end
    end
    local rms = Q.Removed()
    for rk, r in pairs(rms) do
        if isFake(r.o) or isFake(r.by) or (r.who and isFake(r.who)) then rms[rk] = nil end
    end
    Changed()
end
