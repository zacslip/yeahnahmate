-- Milestones: cards the guild master and managers make on the GM tab. When a
-- guildie with the addon meets a card (a level, a profession skill, learning to ride, a legendary
-- item, winning a title), their own addon posts the card's message to guild chat and/or pops it up
-- for guildies with the addon. Plus one Welcome card for new members, posted by an online guildie
-- with the addon at or above a rank the managers pick.
--
-- The cards and their sync come first in this file, then the triggers, then the welcome.
-- Cards ride on the guild board's sync (Board.kinds): every client holds them (it needs them to know
-- when to fire), only managers may write them (every reader checks), newest wins (several managers
-- write the same card), deleted cards stay deleted (x = true, kept with their version).
--
--   BRD { k = "ms", id, ty, n (the level/skill), p, ti, m, gc, pu, on, ev } / { k = "ms", id, x = true, ev }   a card
--   BRD { k = "wel", m, on, gc, pu, wr, ev }                                              the welcome
local ADDON, ns = ...
local L = ns.L

local MS = {}
ns.Milestones = MS

MS.MAX_CARDS = 20
MS.MAX_MSG = 200
MS.TAG = "[Yeah Nah Mate] "
MS.MAX_LEVEL = 60                -- Forever's level cap

-- Trigger types, in the editor's order.
MS.TYPES = { "lvl", "prof", "ride", "leg", "title" }
local IS_TYPE = { lvl = true, prof = true, ride = true, leg = true, title = true }
MS.ICON = {
    lvl = "Interface\\Icons\\Spell_Holy_SealOfMight",
    prof = "Interface\\Icons\\Trade_BlackSmithing",
    ride = "Interface\\Icons\\Ability_Mount_RidingHorse",
    leg = "Interface\\Icons\\INV_Misc_Gem_Pearl_04",
    title = "Interface\\Icons\\INV_Misc_Book_09",
    wel = "Interface\\Icons\\INV_Misc_Note_01",
}
-- Professions a card can name ("any" = whichever reaches the skill).
MS.PROFS = { "any", "Alchemy", "Blacksmithing", "Enchanting", "Engineering", "Herbalism", "Leatherworking",
    "Mining", "Skinning", "Tailoring", "Cooking", "Fishing", "First Aid" }
local IS_PROF = {}
for _, p in ipairs(MS.PROFS) do IS_PROF[p] = true end
MS.TITLES = { "any", "lore", "crafty" }
local IS_TITLE = { any = true, lore = true, crafty = true }

local Board = ns.Board

local function Clean(s, max) return type(s) == "string" and ns.CutBytes((s:gsub("|", ""):gsub("[\r\n]", " ")), max) or "" end

function MS.Store()
    local b = Board.Store()
    if not b then return nil end
    if type(b.ms) ~= "table" then b.ms = {} end
    return b
end

local function Changed() ns.Fire("BOARD") end

-- Can I make and change cards? The guild master and their managers (or /ynm dev gm on, which
-- changes this screen only).
function MS.CanEdit() return Board.CanManage() end

-- A card from anything (a message, the editor): cleaned, or nil if it isn't a valid card.
local function Shape(c)
    if type(c) ~= "table" or type(c.id) ~= "string" or #c.id > 60 then return nil end
    if c.x == true then return { id = c.id, x = true } end
    if not IS_TYPE[c.ty] then return nil end
    local card = { id = c.id, ty = c.ty, m = Clean(c.m, MS.MAX_MSG), gc = c.gc == true or nil, pu = c.pu == true or nil,
                   on = c.on == true or nil }
    if card.m == "" then return nil end
    if c.ty == "lvl" then
        local v = tonumber(c.v)
        if not v or v < 2 or v > MS.MAX_LEVEL then return nil end
        card.v = math.floor(v)
    elseif c.ty == "prof" then
        local v = tonumber(c.v)
        if not v or v < 1 or v > 450 or not IS_PROF[c.p] then return nil end
        card.v, card.p = math.floor(v), c.p
    elseif c.ty == "title" then
        if not IS_TITLE[c.ti] then return nil end
        card.ti = c.ti
    end
    return card
end
MS.Shape = Shape

local function CardMessage(c)
    if c.x then return { t = "BRD", k = "ms", id = c.id, x = true, ev = c.ev } end
    return { t = "BRD", k = "ms", id = c.id, ty = c.ty, n = c.v, p = c.p, ti = c.ti, m = c.m,
             gc = c.gc, pu = c.pu, on = c.on, ev = c.ev }
end

-- Live cards (not deleted), oldest first.
function MS.List()
    local b = MS.Store()
    local list = {}
    if not b then return list end
    for _, c in pairs(b.ms) do if not c.x then list[#list + 1] = c end end
    table.sort(list, function(a, z)
        if (a.made or a.ev) ~= (z.made or z.ev) then return (a.made or a.ev) < (z.made or z.ev) end
        return a.id < z.id
    end)
    return list
end

function MS.Get(id)
    local b = MS.Store()
    local c = b and b.ms[id]
    return c and not c.x and c or nil
end

function MS.ActiveCount()
    local n = 0
    for _, c in ipairs(MS.List()) do if c.on then n = n + 1 end end
    return n
end

-- Save a card from the editor (new when it has no id). Returns the card, or nil + why.
function MS.Save(t)
    local b = MS.Store()
    if not b or not MS.CanEdit() then return nil, "rank" end
    local old = t.id and b.ms[t.id]
    if not old or old.x then
        if #MS.List() >= MS.MAX_CARDS then return nil, "full" end
    end
    local id = (old and not old.x) and t.id or ((ns.me or "?") .. ":" .. GetServerTime() .. ":" .. math.random(999))
    local card = Shape({ id = id, ty = t.ty, v = t.v, p = t.p, ti = t.ti, m = t.m, gc = t.gc, pu = t.pu, on = t.on })
    if not card then return nil, "bad" end
    card.by, card.ev, card.direct = ns.me, Board.NextVersion(old and old.ev), true
    card.made = old and old.made or card.ev
    b.ms[id] = card
    Board.Send(CardMessage(card))
    Changed()
    return card
end

function MS.SetOn(id, on)
    local c = MS.Get(id)
    if not c then return false end
    local t = {}
    for k, v in pairs(c) do t[k] = v end
    t.on = on and true or false
    return MS.Save(t) ~= nil
end

function MS.Delete(id)
    local b = MS.Store()
    local c = b and b.ms[id]
    if not c or c.x or not MS.CanEdit() then return false end
    b.ms[id] = { id = id, x = true, by = ns.me, ev = Board.NextVersion(c.ev), direct = true }
    Board.Send(CardMessage(b.ms[id]))
    Changed()
    return true
end

---------------------------------------------------------------------------------------------------
-- The welcome card

-- Defaults until a manager saves it: off, guild chat on, officers (rank index 1) and above post it.
function MS.Welcome()
    local b = MS.Store()
    local w = b and b.wel
    if w then return w end
    return { m = L.MS_WEL_DEFAULT, on = nil, gc = true, pu = nil, wr = 1 }
end

function MS.SetWelcome(t)
    local b = MS.Store()
    if not b or not MS.CanEdit() then return false end
    local m = Clean(t.m, MS.MAX_MSG)
    local wr = tonumber(t.wr)
    if m == "" or not wr or wr < 0 or wr > 9 then return false end
    b.wel = { m = m, on = t.on == true or nil, gc = t.gc == true or nil, pu = t.pu == true or nil, wr = math.floor(wr),
              by = ns.me, ev = Board.NextVersion(b.wel and b.wel.ev), direct = true }
    local w = b.wel
    Board.Send({ t = "BRD", k = "wel", m = w.m, on = w.on, gc = w.gc, pu = w.pu, wr = w.wr, ev = w.ev })
    Changed()
    return true
end

---------------------------------------------------------------------------------------------------
-- Messages: fill-ins and the preview

-- Fill {name} {level} ... from d (missing ones stay as written, so a mistake shows).
function MS.Fill(msg, d)
    return (msg:gsub("{(%a+)}", function(k)
        local v = d[k]
        return v ~= nil and tostring(v) or nil
    end))
end

-- What a card would post, filled with my own character's details (for the editor's preview).
function MS.Preview(msg, card)
    local m = ns.Guild.Get(ns.me)
    local d = {
        name = (ns.me or "You"):match("^%S+"), level = card and card.ty == "lvl" and card.v or (m and m.level) or UnitLevel("player"),
        class = m and m.class or "Hunter", prof = card and card.p and card.p ~= "any" and card.p or "Tailoring",
        skill = card and card.ty == "prof" and card.v or 300, item = "[Thunderfury]",
        title = card and card.ti == "crafty" and L.CRAFTY_BUGGER or L.LORE_MASTER,
    }
    return MS.TAG .. MS.Fill(msg or "", d)
end

-- One line saying what the card waits for ("Level 12", "300 Tailoring", ...).
function MS.Describe(c)
    if c.ty == "lvl" then return string.format(L.MS_DESC_LVL, c.v)
    elseif c.ty == "prof" then return string.format(L.MS_DESC_PROF, c.v, c.p == "any" and L.MS_ANY_PROF or c.p)
    elseif c.ty == "ride" then return L.MS_DESC_RIDE
    elseif c.ty == "leg" then return L.MS_DESC_LEG
    elseif c.ty == "title" then
        return string.format(L.MS_DESC_TITLE, c.ti == "lore" and L.LORE_MASTER or c.ti == "crafty" and L.CRAFTY_BUGGER or L.MS_ANY_TITLE)
    end
    return "?"
end

---------------------------------------------------------------------------------------------------
-- Sync (on the guild board)

local function Newer(old, ev, direct)
    if not old then return true end
    return ns.Newer(old.ev, old.direct, ev, direct, true)
end

Board.kinds.ms = {
    take = function(author, msg, direct)
        local b = MS.Store()
        if not b then return false end
        if not Board.IsManager(author) then
            ns.Log("dropped: a milestone card from " .. author .. ", who isn't a manager")
            return false
        end
        -- The value travels as n (v is the protocol version).
        local card = Shape({ id = msg.id, x = msg.x, ty = msg.ty, v = msg.n, p = msg.p, ti = msg.ti, m = msg.m,
                             gc = msg.gc, pu = msg.pu, on = msg.on })
        if not card or not Newer(b.ms[card.id], msg.ev, direct) then return false end
        local old = b.ms[card.id]
        if not card.x and (not old or old.x) and #MS.List() >= MS.MAX_CARDS then return false end
        card.by, card.ev, card.direct = author, msg.ev, direct or nil
        card.made = old and old.made or msg.ev
        b.ms[card.id] = card
        return true
    end,
    all = function(add)
        local b = MS.Store()
        if not b then return end
        for _, c in pairs(b.ms) do if c.by then add(CardMessage(c), c.by) end end
    end,
    evs = function(author, list)
        local b = MS.Store()
        if not b then return end
        for _, c in pairs(b.ms) do if c.by == author then list[#list + 1] = c.ev end end
    end,
}

-- Catching up (found by tests/multi.py): cards aren't pushed at log-in (up to 20 per newcomer), and
-- asking one random guildie can miss them. So every hello carries a checksum of the cards and welcome
-- I hold (msh). Someone who just logged in and hears a different one asks that guildie for the board
-- (twice at most). A manager who hears a newcomer with a different one asks them (they may hold the
-- newer card). Nothing extra is sent while everyone holds the same.
local SUM_MOD = 2147483647
function MS.Hash()
    local b = MS.Store()
    if not b then return 0 end
    local h = 0
    for id, c in pairs(b.ms) do
        if type(c.ev) == "number" then
            h = (h + c.ev * 7 + #id) % SUM_MOD
            if c.x then h = (h + 3) % SUM_MOD end
        end
    end
    if b.wel and type(b.wel.ev) == "number" then h = (h + b.wel.ev * 13) % SUM_MOD end
    return h
end

ns.Listen("HI_OUT", function(msg) msg.msh = MS.Hash() end)

local loginAt, askedAfterLogin, askedNewcomer = nil, 0, {}
ns.Listen("LOGIN", function() loginAt, askedAfterLogin = GetTime(), 0 end)

ns.Listen("HI_IN", function(msg, from)
    if type(msg.msh) ~= "number" or (ns.Sim and ns.Sim.IsFake(from)) or msg.msh == MS.Hash() then return end
    local now = GetTime()
    if loginAt and now - loginAt < 180 and askedAfterLogin < 2 then
        askedAfterLogin = askedAfterLogin + 1
        C_Timer.After(askedAfterLogin * 8, function()
            if msg.msh ~= MS.Hash() then ns.Safe(Board.Ask, from) end
        end)
    elseif msg.ask == true and Board.IsManager(ns.me) and not (askedNewcomer[from] and now - askedNewcomer[from] < 600) then
        askedNewcomer[from] = now
        C_Timer.After(10 + math.random() * 20, function()
            if msg.msh ~= MS.Hash() then ns.Safe(Board.Ask, from) end
        end)
    end
end)

Board.kinds.wel = {
    take = function(author, msg, direct)
        local b = MS.Store()
        if not b then return false end
        if not Board.IsManager(author) then
            ns.Log("dropped: the welcome card from " .. author .. ", who isn't a manager")
            return false
        end
        local m, wr = Clean(msg.m, MS.MAX_MSG), tonumber(msg.wr)
        if m == "" or not wr or wr < 0 or wr > 9 or not Newer(b.wel, msg.ev, direct) then return false end
        b.wel = { m = m, on = msg.on == true or nil, gc = msg.gc == true or nil, pu = msg.pu == true or nil,
                  wr = math.floor(wr), by = author, ev = msg.ev, direct = direct or nil }
        return true
    end,
    all = function(add)
        local b = MS.Store()
        local w = b and b.wel
        if w and w.by then add({ t = "BRD", k = "wel", m = w.m, on = w.on, gc = w.gc, pu = w.pu, wr = w.wr, ev = w.ev }, w.by) end
    end,
    evs = function(author, list)
        local b = MS.Store()
        if b and b.wel and b.wel.by == author then list[#list + 1] = b.wel.ev end
    end,
}

---------------------------------------------------------------------------------------------------
-- Firing. My own addon fires my own milestones: once per character per card, the
-- guild chat line at most 3 times an hour (the rest pop-up only), never if I switched posting off
-- (settings.msNoPost). The pop-up goes to guildies with the addon as MSF { m } (the filled message,
-- no tag); each shows it if their "Guildies' milestones" pop-up switch is on.
--
-- Guild chat is the one thing this addon sends there without a click (a deliberate choice: the
-- guild's managers switch each card on): only from Post below, only GUILD, always with the
-- [Yeah Nah Mate] tag.

MS.MAX_POSTS_HOUR = 3
local CHAT_MAX = 255

local function Char()
    ns.db.chars = type(ns.db.chars) == "table" and ns.db.chars or {}
    local me = ns.me or "?"
    if type(ns.db.chars[me]) ~= "table" then ns.db.chars[me] = {} end
    local c = ns.db.chars[me]
    if type(c.msDone) ~= "table" then c.msDone = {} end
    if type(c.msPosts) ~= "table" then c.msPosts = {} end
    return c
end

-- Posts in the last hour (old ones dropped).
local function PostsThisHour()
    local c = Char()
    local now, keep = GetServerTime(), {}
    for _, t in ipairs(c.msPosts) do if type(t) == "number" and now - t < 3600 then keep[#keep + 1] = t end end
    c.msPosts = keep
    return #keep
end

-- The one place that sends guild chat. If the game has chat locked for a moment (Forever can, in
-- instances), try again every 15 s for up to 10 minutes.
local function Post(text, tries)
    tries = tries or 0
    local locked = C_ChatInfo and C_ChatInfo.InChatMessagingLockdown and C_ChatInfo.InChatMessagingLockdown()
    if locked then
        if tries < 40 then C_Timer.After(15, function() ns.Safe(Post, text, tries + 1) end) end
        return
    end
    local send = (C_ChatInfo and C_ChatInfo.SendChatMessage) or SendChatMessage
    local ok, err = pcall(send, text, "GUILD")
    ns.Log(ok and ("milestone posted to guild chat: " .. text) or ("milestone post failed: " .. tostring(err)))
end

-- The details a message can use, for me now.
local function MyDetails(extra)
    local m = ns.Guild.Get(ns.me)
    local d = { name = (ns.me or "?"):match("^%S+"), level = UnitLevel("player"), class = (m and m.class) or (UnitClass and UnitClass("player")) or "" }
    for k, v in pairs(extra or {}) do d[k] = v end
    return d
end

-- An item link shown as plain [Name] (pop-ups and the log can't carry links).
local function Plain(s) return (s:gsub("|c%x+|H.-|h(.-)|h|r", "%1"):gsub("|", "")) end

-- Fire one card for me. test = "dry" (show only on my screen) or "live" (really send, but don't
-- mark it done so it can be tried again). key: what "once" is counted by (default the card; a
-- profession card for any profession counts each profession, a legendary card each item; false =
-- not counted, for titles, which can be won again). Returns what it did, for the log and the tests.
function MS.Fire(card, details, test, key)
    local c = Char()
    if key == nil then key = card.id end
    if not test and key and c.msDone[key] then return "done already" end
    local filled = MS.Fill(card.m, MyDetails(details))
    local line = ns.CutBytes(MS.TAG .. filled, CHAT_MAX)
    local did = {}
    if not test and key then c.msDone[key] = GetServerTime() end
    if card.gc then
        if ns.settings.msNoPost then
            did[#did + 1] = "no post (switched off)"
        elseif test == "dry" then
            print(L.MS_TEST_LINE .. L.MS_WOULD_POST .. " " .. line)
            did[#did + 1] = "guild (dry)"
        elseif PostsThisHour() >= MS.MAX_POSTS_HOUR then
            did[#did + 1] = "no post (3 this hour)"
        else
            c.msPosts[#c.msPosts + 1] = GetServerTime()
            Post(line)
            did[#did + 1] = "guild"
        end
    end
    if card.pu then
        if test ~= "dry" then ns.Comm.Send({ t = "MSF", m = ns.CutBytes(Plain(filled), MS.MAX_MSG) }, "GUILD") end
        MS.ShowPop(ns.me, Plain(filled))
        did[#did + 1] = "pop-up"
    end
    local what = table.concat(did, " + ")
    ns.Log("milestone " .. MS.Describe(card) .. ": " .. (what ~= "" and what or "nothing ticked"))
    return what
end

-- The pop-up, on my screen.
function MS.ShowPop(from, text)
    if not (ns.Toast and ns.Toast.Show) then return end
    ns.Toast.Show(L.MS_POP_TITLE, text, "milestone", { L.MS_POP_NICE, function() end })
end

-- A guildie's milestone pop-up.
ns.Comm.On("MSF", function(msg, from, channel, isSelf)
    if isSelf or channel ~= "GUILD" or not ns.Guild.IsMember(from) then return end
    local text = Clean(msg.m, MS.MAX_MSG)
    if text == "" then return end
    MS.ShowPop(from, text)
end)

-- Level cards: fire the ones for exactly this level (only a level-up seen live, so nobody already
-- past a card is announced).
function MS.OnLevel(level, test)
    local fired = 0
    for _, card in ipairs(MS.List()) do
        if card.on and card.ty == "lvl" and card.v == level then
            MS.Fire(card, { level = level }, test)
            fired = fired + 1
        end
    end
    return fired
end

local lv = CreateFrame("Frame")
lv:RegisterEvent("PLAYER_LEVEL_UP")
lv:SetScript("OnEvent", function(_, _, level)
    if issecretvalue and issecretvalue(level) then return end
    level = tonumber(level)
    if level then ns.Safe(MS.OnLevel, level) end
end)

---------------------------------------------------------------------------------------------------
-- Triggers: professions, riding, legendary items, titles. Each fires only on a change seen live: the
-- first reading after log-in is the starting point, never announced.

-- Professions: GetProfessions + GetProfessionInfo give every skill without the window open (probe,
-- 13 Nov). A card fires when a skill goes from below its number to at or above it.
local skills                      -- profession name -> skill, from the last reading

local function Secret(v) return issecretvalue and issecretvalue(v) end

local function ReadSkills()
    if not (GetProfessions and GetProfessionInfo) then return nil end
    local out = {}
    local list = { pcall(GetProfessions) }
    if not list[1] then return nil end
    for i = 2, 7 do
        local idx = list[i]
        if idx and not Secret(idx) then
            local ok, name, _, rank = pcall(GetProfessionInfo, idx)
            if ok and type(name) == "string" and not Secret(name) and not Secret(rank) and tonumber(rank) then
                out[name] = tonumber(rank)
            end
        end
    end
    return out
end

-- Fire profession cards for a skill change (old -> new) in one profession.
function MS.OnSkill(prof, old, new, test)
    local fired = 0
    for _, card in ipairs(MS.List()) do
        if card.on and card.ty == "prof" and (card.p == "any" or card.p == prof) and old < card.v and new >= card.v then
            MS.Fire(card, { prof = prof, skill = card.v }, test, card.p == "any" and (card.id .. ":" .. prof) or nil)
            fired = fired + 1
        end
    end
    return fired
end

local function CheckSkills()
    local now = ReadSkills()
    if not now then return end
    if skills then
        for prof, rank in pairs(now) do
            local old = skills[prof]
            if old and rank > old then MS.OnSkill(prof, old, rank) end
        end
    end
    skills = now
end

-- Riding: one of the riding spells becomes known, or the game says "You have learned a new spell:
-- ... Riding." The spells are Forever's own "Riding" skill line (read from its game files):
-- Apprentice/Journeyman Riding, the Classic racial ones (Horse, Wolf, Ram, Tiger, Raptor, Kodo
-- Riding, Undead Horsemanship, Mechanostrider Piloting) and Forever's Galestrider Riding.
local RIDING = { 33388, 33391, 824, 825, 826, 828, 10861, 10906, 10907, 18995, 1285849 }
local RIDING_WORDS = { "Riding", "Horsemanship", "Piloting" }
local function RidingName(text)
    for _, w in ipairs(RIDING_WORDS) do if text:find(w, 1, true) then return true end end
    return false
end
MS.RidingName = RidingName              -- for tests
MS.RIDING_SPELLS = {}
for _, id in ipairs(RIDING) do MS.RIDING_SPELLS[id] = true end
local rides

local function KnowsRiding()
    local known = (C_SpellBook and C_SpellBook.IsSpellKnown) or IsSpellKnown
    if not known then return false end
    for _, id in ipairs(RIDING) do
        local ok, yes = pcall(known, id)
        if ok and yes == true then return true end
    end
    return false
end

function MS.OnRiding(test)
    local fired = 0
    for _, card in ipairs(MS.List()) do
        if card.on and card.ty == "ride" then MS.Fire(card, nil, test); fired = fired + 1 end
    end
    return fired
end

local function CheckRiding()
    local now = KnowsRiding()
    if rides == false and now then MS.OnRiding() end
    if rides ~= nil then rides = rides or now end
end

-- Legendary items: my own loot lines with an orange (legendary) item link. Once per item per card.
local lootPats
local function LootPatterns()
    local list = {}
    for _, g in ipairs({ LOOT_ITEM_SELF or "You receive loot: %s", LOOT_ITEM_PUSHED_SELF or "You receive item: %s" }) do
        local p = g:gsub("([%(%)%.%+%-%*%?%[%]%^%$])", "%%%1")
        list[#list + 1] = "^" .. p:gsub("%%s", "(.+)")
    end
    return list
end

function MS.OnLoot(link, test)
    local id = tonumber(link:match("|Hitem:(%d+)"))
    if not id or not link:find("|cffff8000", 1, true) then return 0 end
    local fired = 0
    for _, card in ipairs(MS.List()) do
        if card.on and card.ty == "leg" then MS.Fire(card, { item = link }, test, card.id .. ":" .. id); fired = fired + 1 end
    end
    return fired
end

-- Titles: when I (or one of my characters) become the holder, unless I held it in the last 7 days
-- (titles go by the last 30 days, so a close race can swap it back and forth).
local TITLE_AGAIN = 7 * 86400
local holds                       -- "lore"/"crafty" -> I hold it now (from the last check)

local function TitleState()
    local me = ns.Alts and ns.Alts.Person(ns.me) or ns.me
    local Q, R = ns.Questions, ns.Requests
    return { lore = (Q and Q.LoreMaster and Q.LoreMaster() == me) or false,
             crafty = (R and R.CraftyBugger and R.CraftyBugger() == me) or false }
end

function MS.OnTitle(ti, test)
    local name = ti == "lore" and L.LORE_MASTER or L.CRAFTY_BUGGER
    local fired = 0
    for _, card in ipairs(MS.List()) do
        if card.on and card.ty == "title" and (card.ti == "any" or card.ti == ti) then
            MS.Fire(card, { title = name }, test, false)
            fired = fired + 1
        end
    end
    return fired
end

local function CheckTitles()
    local now = TitleState()
    ns.db.titleHeld = type(ns.db.titleHeld) == "table" and ns.db.titleHeld or {}
    local held, t = ns.db.titleHeld, GetServerTime()
    for ti, mine in pairs(now) do
        if mine then
            local last = held[ti]
            if holds and not holds[ti] and not (type(last) == "number" and t - last < TITLE_AGAIN) then MS.OnTitle(ti) end
            held[ti] = t
        end
    end
    holds = now
end
MS.CheckTitles = CheckTitles

local watch = CreateFrame("Frame")
for _, e in ipairs({ "SKILL_LINES_CHANGED", "CHAT_MSG_SKILL", "TRADE_SKILL_UPDATE", "SPELLS_CHANGED", "NEW_MOUNT_ADDED",
    "COMPANION_LEARNED", "CHAT_MSG_LOOT", "CHAT_MSG_SYSTEM" }) do
    pcall(watch.RegisterEvent, watch, e)
end
local learnedStart = type(ERR_LEARN_SPELL_S) == "string" and ERR_LEARN_SPELL_S:match("^(.-)%%s") or "You have learned a new spell: "
watch:SetScript("OnEvent", function(_, event, text)
    if event == "CHAT_MSG_LOOT" then
        if type(text) ~= "string" or Secret(text) then return end
        lootPats = lootPats or LootPatterns()     -- built once
        for _, pat in ipairs(lootPats) do
            -- Just the link: the line can end with a stack count ("[item]x2").
            local rest = text:match(pat)
            local link = rest and rest:match("(|c%x+|Hitem:.-|h|r)")
            if link then ns.Safe(MS.OnLoot, link) return end
        end
        return
    end
    if event == "CHAT_MSG_SYSTEM" then
        if type(text) ~= "string" or Secret(text) then return end
        if rides == false and text:find(learnedStart, 1, true) and RidingName(text) then
            rides = true
            ns.Safe(MS.OnRiding)
        end
        return
    end
    -- Skill and spell changes come in bursts: read once, a moment later.
    if not watch.pending then
        watch.pending = true
        C_Timer.After(1, function()
            watch.pending = nil
            ns.Safe(CheckSkills)
            ns.Safe(CheckRiding)
        end)
    end
end)

-- The starting point, a few seconds after log-in (nothing is announced from it).
ns.Listen("LOGIN", function()
    C_Timer.After(5, function()
        ns.Safe(function() skills = ReadSkills(); rides = KnowsRiding(); holds = TitleState() end)
    end)
end)
ns.Listen("QUESTIONS", function() if holds then ns.Safe(CheckTitles) end end)
ns.Listen("REQUESTS", function() if holds then ns.Safe(CheckTitles) end end)

---------------------------------------------------------------------------------------------------
-- The welcome. The game tells everyone online "X has joined the guild." Of the
-- guildies online with the addon at or above the welcome rank, the first (highest rank, then name)
-- posts it after 3 s and tells the guild's addons (MSW { n }) so nobody else does. The next two in
-- line are the backup: they wait 15 s each in turn and post only if nobody has. One welcome per new
-- member per day (a quick leave and rejoin isn't welcomed twice); at most 10 welcomes an hour each.

MS.MAX_WELCOMES_HOUR = 10
local WELCOME_AGAIN = 24 * 3600

local joinPat
local function JoinPattern()
    local s = type(ERR_GUILD_JOIN_S) == "string" and ERR_GUILD_JOIN_S or "%s has joined the guild."
    s = s:gsub("([%(%)%.%+%-%*%?%[%]%^%$])", "%%%1")
    return "^" .. s:gsub("%%s", "(.+)") .. "$"
end

local function WelcomeStore()
    local g = ns.GuildData()
    if not g then return nil end
    if type(g.welDone) ~= "table" then g.welDone = {} end
    return g.welDone
end

local function Welcomed(key)
    local done = WelcomeStore()
    local t = done and done[key]
    return type(t) == "number" and GetServerTime() - t < WELCOME_AGAIN
end

local function MarkWelcomed(key)
    local done = WelcomeStore()
    if not done then return end
    local now = GetServerTime()
    for k, t in pairs(done) do if type(t) ~= "number" or now - t > WELCOME_AGAIN then done[k] = nil end end
    done[key] = now
end

-- Who may post the welcome right now, in order: online with the addon, rank index <= wr.
function MS.Posters(wr)
    local list = {}
    local function Add(name, rank)
        if type(rank) == "number" and rank <= wr then list[#list + 1] = { name = name, rank = rank } end
    end
    Add(ns.me, ns.Guild.myRank)
    for name, u in pairs(ns.Comm.users) do
        if name ~= ns.me and not u.sim then
            local m = ns.Guild.Get(name)
            if m and m.online then Add(name, m.rankIndex) end
        end
    end
    table.sort(list, function(a, z) if a.rank ~= z.rank then return a.rank < z.rank end return a.name < z.name end)
    local names = {}
    for i, e in ipairs(list) do names[i] = e.name end
    return names
end

-- Post the welcome for a new member (I'm the one doing it). test = "dry" / "live" as for MS.Fire.
function MS.PostWelcome(newName, test)
    local w = MS.Welcome()
    local key = ns.Key(newName) or newName
    local filled = MS.Fill(w.m, { name = newName:match("^%S+") or newName })
    local line = ns.CutBytes(MS.TAG .. filled, CHAT_MAX)
    local did = {}
    if w.gc then
        local c = Char()
        c.welPosts = type(c.welPosts) == "table" and c.welPosts or {}
        local now, keep = GetServerTime(), {}
        for _, t in ipairs(c.welPosts) do if type(t) == "number" and now - t < 3600 then keep[#keep + 1] = t end end
        c.welPosts = keep
        if test == "dry" then
            print(L.MS_TEST_LINE .. L.MS_WOULD_POST .. " " .. line)
            did[#did + 1] = "guild (dry)"
        elseif #keep >= MS.MAX_WELCOMES_HOUR then
            did[#did + 1] = "no post (10 this hour)"
        else
            keep[#keep + 1] = now
            Post(line)
            did[#did + 1] = "guild"
        end
    end
    if w.pu then
        if test ~= "dry" then ns.Comm.Send({ t = "MSF", m = ns.CutBytes(filled, MS.MAX_MSG) }, "GUILD") end
        MS.ShowPop(ns.me, filled)
        did[#did + 1] = "pop-up"
    end
    if not test then
        MarkWelcomed(key)
        ns.Comm.Send({ t = "MSW", n = key }, "GUILD")
    end
    local what = table.concat(did, " + ")
    ns.Log("welcome for " .. key .. ": " .. (what ~= "" and what or "nothing ticked"))
    return what
end

-- Someone joined: am I the one to welcome them (or a backup)?
function MS.OnJoin(newName)
    local w = MS.Welcome()
    if not w.on or type(newName) ~= "string" or newName == "" then return end
    local key = ns.Key(newName) or newName
    if key == ns.me or Welcomed(key) then return end
    local place
    for i, name in ipairs(MS.Posters(w.wr)) do if name == ns.me then place = i end end
    if not place or place > 3 then return end
    -- Posting switched off: I step aside, and the backup after me takes it.
    if ns.settings.msNoPost and w.gc then return end
    C_Timer.After(3 + (place - 1) * 15, function()
        ns.Safe(function()
            if Welcomed(key) or not MS.Welcome().on then return end
            MS.PostWelcome(newName)
        end)
    end)
end

-- Another addon posted it: nobody else does.
ns.Comm.On("MSW", function(msg, from, channel, isSelf)
    if isSelf or channel ~= "GUILD" or not ns.Guild.IsMember(from) or type(msg.n) ~= "string" then return end
    local key = ns.Key(msg.n)
    if key then MarkWelcomed(key) end
end)

local join = CreateFrame("Frame")
join:RegisterEvent("CHAT_MSG_SYSTEM")
join:SetScript("OnEvent", function(_, _, text)
    if type(text) ~= "string" or (issecretvalue and issecretvalue(text)) then return end
    joinPat = joinPat or JoinPattern()      -- built once
    local name = text:match(joinPat)
    if name then ns.Safe(MS.OnJoin, name) end
end)
