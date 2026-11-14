-- Professions: my recipes (read when I open a profession window) and everyone else's, shared so
-- the guild can ask a guildie first. Only shared if the player said yes (settings.shareProfessions,
-- asked on first run, switchable in Settings).
--
-- Forever has the newer profession functions (/ynm dev probe, Nov 2026): C_TradeSkillUI.GetAllRecipeIDs,
-- GetRecipeInfo(id).learned, GetBaseProfessionInfo. Only recipe IDs are sent; each player looks
-- the names up on their own client (spell names), so messages stay small.
--
-- Messages
--   PROF { pv, p = { [skillLine] = { r = rank, m = max, i = { recipe IDs } } } }   my list (GUILD or WHISPER)
--   PROF { pv, p = false }                                    I stopped sharing: forget my list
--   PROF { o = owner, pv, p }                                 a copy of someone else's list, only by
--                                                             WHISPER, only from a guildie we asked
--   REQ  { w = "PROF" }            send me your list             (WHISPER)
--   REQ  { w = "IDX" }             which lists do you have?      (WHISPER)
--   REQ  { w = "PROFS", n = {..} } send me these people's lists  (WHISPER, up to 10 names)
--   IDX  { l = { [name] = pv } }   the lists I have              (WHISPER)
-- pv is the list's version: the server time it last changed. HI carries mine (pv) and whether I
-- share (ps), so a guildie who logs in asks only for lists that are new to them. The owner's own
-- message always beats a copy; a copy never beats a newer version.
local ADDON, ns = ...
local L = ns.L

local Prof = {}
ns.Prof = Prof

-- Skill line ID -> name and icon.
Prof.LINES = {
    [171] = { "Alchemy", "Trade_Alchemy" },
    [164] = { "Blacksmithing", "Trade_BlackSmithing" },
    [185] = { "Cooking", "INV_Misc_Food_15" },
    [333] = { "Enchanting", "Trade_Engraving" },
    [202] = { "Engineering", "Trade_Engineering" },
    [129] = { "First Aid", "Spell_Holy_SealOfSacrifice" },
    [356] = { "Fishing", "Trade_Fishing" },
    [182] = { "Herbalism", "Trade_Herbalism" },
    [165] = { "Leatherworking", "Trade_LeatherWorking" },
    [186] = { "Mining", "Trade_Mining" },
    [393] = { "Skinning", "INV_Misc_Pelt_Wolf_01" },
    [197] = { "Tailoring", "Trade_Tailoring" },
}

local MAX_RECIPES = 1000        -- per profession, in a message
local MAX_LINES = 12
local BATCH = 10                -- names per PROFS request
local MAX_COPIES = 30           -- copies asked for after one index (the rest come as people log in)
local MAX_INDEX = 200           -- entries in an index answer (fits the 8000-byte message limit)
local ASK_WINDOW = 300          -- seconds a guildie we asked may keep sending copies

function Prof.Sharing() return ns.settings.shareProfessions == true end

function Prof.LineName(line)
    local l = Prof.LINES[line]
    return l and l[1] or ("Profession " .. tostring(line))
end
function Prof.LineIcon(line)
    local l = Prof.LINES[line]
    return "Interface\\Icons\\" .. (l and l[2] or "INV_Misc_QuestionMark")
end

---------------------------------------------------------------------------------------------------
-- Storage. Mine per character; everyone else's per guild (cached so offline crafters stay searchable).

function Prof.MyData()
    local chars = ns.db.chars
    if type(chars) ~= "table" then chars = {}; ns.db.chars = chars end
    local key = ns.me or "?"
    local c = chars[key]
    if type(c) ~= "table" then c = {}; chars[key] = c end
    if type(c.profs) ~= "table" then c.profs = {} end
    c.pv = tonumber(c.pv) or 0
    return c
end

local function Store()
    local g = ns.GuildData()
    if not g then return nil end
    if type(g.profs) ~= "table" then g.profs = {} end
    return g.profs
end
Prof.Store = Store

-- My list's version, and whether I share it (for HI).
function Prof.MyVersion() return Prof.MyData().pv end

---------------------------------------------------------------------------------------------------
-- Recipe names. Mine come from the profession window; others' from the spell name on this client.

local names = {}

function Prof.RecipeName(id)
    local n = names[id] or (ns.db and ns.db.recipeNames and ns.db.recipeNames[id])
    if n then return n end
    if C_Spell and C_Spell.GetSpellName then
        local ok, s = pcall(C_Spell.GetSpellName, id)
        n = ok and ns.Public(s, "string") or nil
    end
    if not n and GetSpellInfo then
        local ok, s = pcall(GetSpellInfo, id)
        n = ok and ns.Public(s, "string") or nil
    end
    if not n and ns.Sim then n = ns.Sim.RecipeName(id) end
    if n then names[id] = n; return n end
    return string.format(L.RECIPE_N, id)
end

---------------------------------------------------------------------------------------------------
-- What a recipe makes (Data/RecipeItems.lua, built from the game's files), its icon, and which
-- section of the tab it goes in. GetItemInfoInstant answers from the client's own data (no server
-- round trip), so this works for every recipe at once.

-- Sections, in the order the tab shows them. The filter buttons group some of them.
Prof.CATS = { "bags", "potions", "food", "bandages", "cloth", "leather", "mail", "plate", "armour",
              "weapons", "ammo", "goods", "enchants", "other" }

local function Category(item, line)
    if not item then return line == 333 and "enchants" or "other" end
    local getInfo = C_Item and C_Item.GetItemInfoInstant
    if not getInfo then return "other" end
    local ok, _, _, _, _, _, class, sub = pcall(getInfo, item)
    if not ok or type(class) ~= "number" then return "other" end
    if class == 1 then return "bags"
    elseif class == 0 then
        if sub == 1 or sub == 2 or sub == 3 then return "potions"
        elseif sub == 5 then return "food"
        elseif sub == 7 then return "bandages" end
        return "other"
    elseif class == 2 then return "weapons"
    elseif class == 4 then
        if sub == 1 then return "cloth" elseif sub == 2 then return "leather"
        elseif sub == 3 then return "mail" elseif sub == 4 then return "plate"
        elseif sub == 6 then return "weapons" end              -- shields
        return "armour"                                         -- cloaks, rings, trinkets...
    elseif class == 6 or class == 11 then return "ammo"
    elseif class == 7 then return "goods" end
    return "other"
end

-- item ID (or nil), section, icon for a recipe. Kept per recipe: they never change, and looking them
-- up again on every rebuild cost ~10 ms in a 600-crafter guild.
local itemCache = {}
local function ItemInfoNow(id, line)
    local item = ns.RecipeItem and ns.RecipeItem[id]
    local icon
    if item and C_Item and C_Item.GetItemIconByID then
        local ok, t = pcall(C_Item.GetItemIconByID, item)
        icon = ok and ns.Public(t) or nil
    end
    if not icon and C_Spell and C_Spell.GetSpellTexture then
        local ok, t = pcall(C_Spell.GetSpellTexture, id)
        icon = ok and ns.Public(t) or nil
    end
    return item, Category(item, line), icon or Prof.LineIcon(line)
end

function Prof.ItemInfo(id, line)
    local c = itemCache[id]
    if not c then
        local item, cat, icon = ItemInfoNow(id, line)
        c = { item, cat, icon }
        itemCache[id] = c
    end
    return c[1], c[2], c[3]
end

---------------------------------------------------------------------------------------------------
-- The guild's index for the Professions tab: recipe -> crafters, profession -> crafters.

Prof.recipes = {}               -- id -> { line, crafters = { name, ... } }
Prof.lines = {}                 -- line -> { [name] = rank }
local dirty = true              -- rebuild everything (login, sim on/off, late recipe names)
local pending = {}              -- name -> true: only these people's lists changed
local added = {}                -- name -> { [line] = d } as it was put in the index, to take it out again
local FULL_AT = 100             -- this many changed people at once: a full rebuild is as quick

-- When one guildie's list arrives, only their entries change: their old ones come out, the new ones
-- go in. Rebuilding everything for each list cost ~150 ms with 600 crafters (a hitch if lists arrived
-- with the tab open); one person is ~1 ms.

-- The list a person has in the index (nil: none), from my own data, the saved lists or the sim.
local function SourceOf(name)
    if name == ns.me then return Prof.MyData().profs end
    local store = Store()
    local e = store and store[name]
    if e and not e.off and type(e.p) == "table" and ns.Guild.IsMember(name) then return e.p end
    local sim = ns.Sim and ns.Sim.Profs and ns.Sim.Profs()
    return sim and sim[name] or nil
end

-- created: id -> true for recipes that weren't in the index before (nil in a full rebuild).
local function AddPerson(name, profs, created)
    local mine = {}
    for line, d in pairs(profs) do
        mine[line] = d              -- source line tables are replaced when they change, never edited
        Prof.lines[line] = Prof.lines[line] or {}
        Prof.lines[line][name] = d.r or 0
        for _, id in ipairs(d.i or {}) do
            local r = Prof.recipes[id]
            if not r then
                r = { line = line, crafters = {} }
                Prof.recipes[id] = r
                if created then created[id] = true end
            end
            r.crafters[#r.crafters + 1] = name
        end
    end
    added[name] = mine
end

-- Takes a person's entries out. Recipes left with nobody are noted in emptied (removed later, so a
-- person whose list is put straight back keeps the same recipe tables).
local function RemovePerson(name, emptied)
    local mine = added[name]
    if not mine then return end
    added[name] = nil
    for line, d in pairs(mine) do
        local people = Prof.lines[line]
        if people then
            people[name] = nil
            if not next(people) then Prof.lines[line] = nil end
        end
        for _, id in ipairs(d.i or {}) do
            local r = Prof.recipes[id]
            if r then
                local c = r.crafters
                for k = #c, 1, -1 do
                    if c[k] == name then c[k] = c[#c]; c[#c] = nil; break end
                end
                if #c == 0 then emptied[id] = true end
            end
        end
    end
end

local function SortedBefore(a, b)
    if a.name ~= b.name then return a.name < b.name end
    return a.id < b.id
end

local function Entry(id, r)
    local name = Prof.RecipeName(id)
    local item, cat, icon = Prof.ItemInfo(id, r.line)
    return { id = id, name = name, lower = strlower(name), line = r.line, crafters = r.crafters,
             item = item, cat = cat, icon = icon }
end

function Prof.Rebuild()
    dirty = false
    wipe(pending)
    wipe(added)
    wipe(Prof.recipes)
    wipe(Prof.lines)
    if ns.me then AddPerson(ns.me, Prof.MyData().profs) end
    local store = Store()
    if store then
        for name, e in pairs(store) do
            if name ~= ns.me and not e.off and type(e.p) == "table" and ns.Guild.IsMember(name) then AddPerson(name, e.p) end
        end
    end
    if ns.Sim and ns.Sim.Profs then
        for name, profs in pairs(ns.Sim.Profs()) do AddPerson(name, profs) end
    end
    -- Every recipe once, named and sorted, so searching and redrawing don't redo it each time
    -- (with ~5000 recipes in a 500-member guild that cost ~20 ms a redraw).
    local sorted = {}
    for id, r in pairs(Prof.recipes) do sorted[#sorted + 1] = Entry(id, r) end
    table.sort(sorted, SortedBefore)
    Prof.sorted = sorted
end
Prof.sorted = {}

-- Only the people whose lists changed.
local function Update()
    local emptied, created = {}, {}
    for name in pairs(pending) do
        RemovePerson(name, emptied)
        local p = SourceOf(name)
        if p then AddPerson(name, p, created) end
    end
    wipe(pending)
    local gone = false
    for id in pairs(emptied) do
        local r = Prof.recipes[id]
        if r and #r.crafters == 0 then Prof.recipes[id] = nil; gone = true; created[id] = nil end
    end
    if not gone and not next(created) then return end
    -- The sorted list: drop recipes nobody has now, merge in the new ones.
    local new = {}
    for id in pairs(created) do new[#new + 1] = Entry(id, Prof.recipes[id]) end
    table.sort(new, SortedBefore)
    local old, out, j = Prof.sorted, {}, 1
    for _, e in ipairs(old) do
        if Prof.recipes[e.id] then
            while new[j] and SortedBefore(new[j], e) do out[#out + 1] = new[j]; j = j + 1 end
            out[#out + 1] = e
        end
    end
    while new[j] do out[#out + 1] = new[j]; j = j + 1 end
    Prof.sorted = out
end

-- The index is brought up to date when something reads it, not on every message.
local function Fresh()
    if dirty then Prof.Rebuild() return end
    if not next(pending) then return end
    local n = 0
    for _ in pairs(pending) do n = n + 1 end
    if n >= FULL_AT then Prof.Rebuild() else Update() end
end
Prof.Fresh = Fresh

-- Changed(name): only that person's list changed. Changed(): rebuild everything.
local function Changed(name)
    if name then pending[name] = true else dirty = true end
    ns.Fire("PROFS")
end
Prof.MarkDirty = function() Changed() end
Prof.PersonChanged = Changed

-- Recipes for the tab: one profession (or all), matching a search, crafters online first.
function Prof.Search(line, query)
    Fresh()
    query = strlower(query or "")
    if not line and query == "" then return Prof.sorted end
    local list = {}
    for _, e in ipairs(Prof.sorted) do
        if (not line or e.line == line) and (query == "" or strfind(e.lower, query, 1, true)) then list[#list + 1] = e end
    end
    return list
end

-- Professions in the guild: { line, count, top }, by name.
function Prof.Lines()
    Fresh()
    local list = {}
    for line, people in pairs(Prof.lines) do
        local n, top = 0, 0
        for _, rank in pairs(people) do n = n + 1; if rank > top then top = rank end end
        list[#list + 1] = { line = line, count = n, top = top }
    end
    table.sort(list, function(a, b) return Prof.LineName(a.line) < Prof.LineName(b.line) end)
    return list
end

-- Recipe names the client didn't know yet ("Recipe 1234"): try again a little later, once.
ns.Listen("LOGIN", function()
    C_Timer.After(60, function()
        for _, e in ipairs(Prof.sorted) do
            if e.name == string.format(L.RECIPE_N, e.id) then dirty = true; ns.Fire("PROFS"); return end
        end
    end)
end)

function Prof.RecipeCount()
    Fresh()
    local n = 0
    for _ in pairs(Prof.recipes) do n = n + 1 end
    return n
end

---------------------------------------------------------------------------------------------------
-- Reading my own professions from an open profession window.

local function Probe(info, sampleID, sample, all, learned)
    if not ns.db.probe then ns.db.probe = {} end
    local d = ns.Describe or tostring
    ns.db.probe.professions = ns.db.probe.professions or {}
    ns.db.probe.professions[tostring(info.professionID)] = {
        info = d(info), sample = d(sample), sampleID = sampleID, all = all, learned = learned,
        spellName = sampleID and C_Spell and C_Spell.GetSpellName and tostring(C_Spell.GetSpellName(sampleID)) or "n/a",
    }
end

local function SameList(a, b)
    if not a or not b or #a ~= #b then return false end
    for i = 1, #a do if a[i] ~= b[i] then return false end end
    return true
end

local broadcastTimer = nil
local function Broadcast()
    broadcastTimer = nil
    local mine = Prof.MyData()
    if Prof.Sharing() then
        if next(mine.profs) then
            ns.Comm.Send({ t = "PROF", pv = mine.pv, p = mine.profs }, "GUILD", nil, "BULK")
        end
    else
        ns.Comm.Send({ t = "PROF", pv = mine.pv, p = false }, "GUILD", nil, "BULK")
    end
end

-- Send my list to the guild a little later (opening several professions in a row sends once).
function Prof.BroadcastSoon(delay)
    if broadcastTimer then broadcastTimer:Cancel() end
    broadcastTimer = C_Timer.NewTimer(delay or 20, function() ns.Safe(Broadcast) end)
end

function Prof.Scan()
    local api = C_TradeSkillUI
    if not ns.me or not api or not api.GetAllRecipeIDs or not api.GetRecipeInfo or not api.GetBaseProfessionInfo then return false end
    -- Someone else's linked profession, the guild's or an NPC's must never change my list.
    for _, f in ipairs({ "IsTradeSkillLinked", "IsTradeSkillGuild", "IsTradeSkillGuildMember", "IsNPCCrafting" }) do
        if api[f] and api[f]() then return false end
    end
    if api.IsTradeSkillReady and not api.IsTradeSkillReady() then return false end
    if api.IsDataSourceChanging and api.IsDataSourceChanging() then return false end
    local info = api.GetBaseProfessionInfo()
    if type(info) ~= "table" then return false end
    local line = info.professionID
    if not Prof.LINES[line] and Prof.LINES[info.parentProfessionID] then line = info.parentProfessionID end
    if type(line) ~= "number" or line <= 0 then return false end

    local all = api.GetAllRecipeIDs() or {}
    local ids, sampleID, sample = {}, nil, nil
    ns.db.recipeNames = ns.db.recipeNames or {}
    for _, id in ipairs(all) do
        local r = api.GetRecipeInfo(id)
        if not sample and type(r) == "table" then sampleID, sample = id, r end
        if type(r) == "table" and r.learned == true and type(id) == "number" then
            ids[#ids + 1] = id
            local n = ns.Public(r.name, "string")
            if n then names[id] = n; ns.db.recipeNames[id] = n end
        end
    end
    table.sort(ids)
    Probe(info, sampleID, sample, #all, #ids)
    if #ids == 0 then return false end

    local mine = Prof.MyData()
    local old = mine.profs[line]
    local rank = tonumber(ns.Public(info.skillLevel)) or (old and old.r) or 0
    local max = tonumber(ns.Public(info.maxSkillLevel)) or (old and old.m) or 0
    local newRecipes = not (old and SameList(old.i, ids))
    if not newRecipes and old.r == rank and old.m == max then return true end
    mine.profs[line] = { r = rank, m = max, i = ids }
    mine.pv = GetServerTime()
    ns.Log("read " .. Prof.LineName(line) .. ": " .. #ids .. " recipes, skill " .. rank .. "/" .. max)
    Changed(ns.me)
    -- New recipes go out to the guild; a skill point alone waits for the next login's hello.
    if newRecipes and Prof.Sharing() then Prof.BroadcastSoon() end
    return true
end

local scanTimer = nil
local function ScanSoon()
    if scanTimer then scanTimer:Cancel() end
    scanTimer = C_Timer.NewTimer(1, function() scanTimer = nil; ns.Safe(Prof.Scan) end)
end
for _, e in ipairs({ "TRADE_SKILL_SHOW", "TRADE_SKILL_LIST_UPDATE", "TRADE_SKILL_DATA_SOURCE_CHANGED", "NEW_RECIPE_LEARNED" }) do
    ns.OnEvent(e, ScanSoon)
end

-- My crafting professions whose window I haven't opened yet (so the guild can't see their recipes).
-- Shown on the Professions tab whatever else is in the list (0.9.5: the "open your windows" note
-- used to show only while the list was empty, so it vanished once a guildie's recipes arrived).
-- Gathering skills have no recipe window worth asking about.
local NO_WINDOW = { [182] = true, [393] = true, [356] = true, [186] = true }

local previewUnread = false     -- /ynm dev profhint: see the hint without unlearning anything

function Prof.Unread()
    local out = {}
    if previewUnread then return { "Cooking", "Tailoring" } end
    if not GetProfessions or not GetProfessionInfo then return out end
    local mine = Prof.MyData().profs
    for _, index in pairs({ GetProfessions() }) do
        local line = select(7, GetProfessionInfo(index))
        if type(line) == "number" and Prof.LINES[line] and not NO_WINDOW[line] and not mine[line] then
            out[#out + 1] = Prof.LineName(line)
        end
    end
    table.sort(out)
    return out
end

-- Dev only: the CurseForge build leaves this out (BigWigs packager's do-not-package markers).
-- A copy installed from source keeps it.
--@do-not-package@
ns.devCommands.profhint = function(arg)
    if arg ~= "on" and arg ~= "off" then ns.Print("/ynm dev profhint on  or  /ynm dev profhint off") return end
    previewUnread = (arg == "on")
    ns.Print(previewUnread and "Professions tab: showing the 'open your windows' hint as a preview." or "Hint preview off.")
    ns.Fire("PROFS")
end
--@end-do-not-package@

-- A profession unlearned: drop it from my list.
local function CheckDropped()
    if not GetProfessions or not GetProfessionInfo then return end
    local have = {}
    for _, index in pairs({ GetProfessions() }) do
        local line = select(7, GetProfessionInfo(index))
        if line then have[line] = true end
    end
    if not next(have) then return end         -- the game hasn't loaded professions yet
    local mine = Prof.MyData()
    local dropped = false
    for line in pairs(mine.profs) do
        if not have[line] then mine.profs[line] = nil; dropped = true end
    end
    if dropped then
        mine.pv = GetServerTime()
        Changed(ns.me)
        if Prof.Sharing() then Prof.BroadcastSoon() end
    end
end
ns.OnEvent("SKILL_LINES_CHANGED", function() C_Timer.After(2, function() ns.Safe(CheckDropped) end) end)

-- Sharing switched on or off: tell the guild (on: my list; off: forget it).
local lastShare = nil
ns.Listen("SETTINGS", function()
    local now = ns.settings.shareProfessions
    if lastShare == nil then lastShare = now; return end
    if now == lastShare then return end
    lastShare = now
    if now == nil then return end
    local mine = Prof.MyData()
    mine.pv = GetServerTime()
    Prof.BroadcastSoon(1)
end)
ns.Listen("LOADED", function() lastShare = ns.settings.shareProfessions end)

---------------------------------------------------------------------------------------------------
-- Receiving

local asked = {}                -- peer -> GetTime() we last asked them for copies

local function CleanProfs(p)
    if type(p) ~= "table" then return nil end
    local out, lines = {}, 0
    for line, d in pairs(p) do
        lines = lines + 1
        if lines > MAX_LINES then return nil end
        if type(line) ~= "number" or line <= 0 or line > 100000 or type(d) ~= "table" or type(d.i) ~= "table" then return nil end
        if #d.i > MAX_RECIPES then return nil end
        local ids = {}
        for _, id in ipairs(d.i) do
            if type(id) ~= "number" or id <= 0 or id ~= math.floor(id) then return nil end
            ids[#ids + 1] = id
        end
        out[line] = { r = tonumber(d.r) or 0, m = tonumber(d.m) or 0, i = ids }
    end
    return out
end

-- Take a list (the owner's own, or a copy). Returns true if it was newer and kept.
local function TakeList(owner, pv, p, direct)
    local store = Store()
    if not store or owner == ns.me or not ns.Guild.IsMember(owner) then return false end
    if ns.Future(pv, not direct) then return false end
    local old = store[owner]
    -- The owner's own list always wins; a copy when it's newer.
    if old and not ns.Newer(old.pv, old.direct, pv, direct) then return false end
    if p == false then
        store[owner] = { pv = pv, off = true, direct = direct or nil }
    else
        local clean = CleanProfs(p)
        if not clean then ns.Log("dropped: bad profession list for " .. owner) return false end
        store[owner] = { pv = pv, p = clean, direct = direct or nil }
    end
    Changed(owner)
    return true
end

ns.Comm.On("PROF", function(msg, from, channel, isSelf)
    if isSelf then return end
    if msg.o == nil then
        TakeList(from, msg.pv, msg.p, true)
        return
    end
    -- A copy: only by whisper, only from a guildie we asked in the last two minutes.
    if channel ~= "WHISPER" or not asked[from] or GetTime() - asked[from] > ASK_WINDOW then
        ns.Log("dropped: a profession copy from " .. from .. " that we didn't ask for")
        return
    end
    asked[from] = GetTime()                   -- more may be on the way
    local owner = ns.Key(msg.o)
    if owner and owner ~= from then TakeList(owner, msg.pv, msg.p, false) end
end)

---------------------------------------------------------------------------------------------------
-- Asking for lists

local wants = {}                -- peer -> { owner = true }
local flushTimer = nil

local function Flush()
    flushTimer = nil
    for peer, owners in pairs(wants) do
        local list = {}
        for owner in pairs(owners) do list[#list + 1] = owner end
        table.sort(list)
        if #list == 1 and list[1] == peer then
            ns.Comm.Send({ t = "REQ", w = "PROF" }, "WHISPER", peer)
        else
            asked[peer] = GetTime()
            for i = 1, #list, BATCH do
                local batch = {}
                for j = i, math.min(#list, i + BATCH - 1) do
                    if list[j] ~= peer then batch[#batch + 1] = list[j] end
                end
                if #batch > 0 then ns.Comm.Send({ t = "REQ", w = "PROFS", n = batch }, "WHISPER", peer) end
            end
            if owners[peer] then ns.Comm.Send({ t = "REQ", w = "PROF" }, "WHISPER", peer) end
        end
    end
    wants = {}
end

local function Want(owner, peer)
    if ns.Sim and (ns.Sim.IsFake(owner) or ns.Sim.IsFake(peer)) then return end
    wants[peer] = wants[peer] or {}
    wants[peer][owner] = true
    if not flushTimer then flushTimer = C_Timer.NewTimer(3, function() ns.Safe(Flush) end) end
end

-- A guildie's hello says which version of their list they have.
ns.Listen("HI_IN", function(msg, from)
    local pv = msg.pv
    if type(pv) ~= "number" or pv <= 0 then return end
    local store = Store()
    if not store then return end
    local old = store[from]
    if old and old.pv >= pv then return end
    if msg.ps == true then
        Want(from, from)
    else
        TakeList(from, pv, false, true)
    end
end)
ns.Listen("HI_OUT", function(msg)
    msg.pv = Prof.MyVersion()
    msg.ps = Prof.Sharing() or nil
end)

-- After login, ask one online guildie which lists they have, to fill in offline crafters.
local function AskIndex()
    local peers = {}
    for name, u in pairs(ns.Comm.users) do
        local m = ns.Guild.Get(name)
        if name ~= ns.me and not u.sim and m and m.online then peers[#peers + 1] = name end
    end
    if #peers == 0 then return end
    local peer = peers[math.random(#peers)]
    asked[peer] = GetTime()
    ns.Comm.Send({ t = "REQ", w = "IDX" }, "WHISPER", peer)
end
ns.Listen("LOGIN", function() C_Timer.After(30, function() ns.Safe(AskIndex) end) end)

ns.Comm.On("IDX", function(msg, from, channel, isSelf)
    if isSelf or channel ~= "WHISPER" or not asked[from] or GetTime() - asked[from] > ASK_WINDOW then return end
    if type(msg.l) ~= "table" then return end
    local store = Store()
    if not store then return end
    local missing, n = {}, 0
    for owner, pv in pairs(msg.l) do
        n = n + 1
        if n > MAX_INDEX then break end
        owner = type(owner) == "string" and ns.Key(owner) or nil
        if owner and type(pv) == "number" and pv <= GetServerTime() + 600 and owner ~= ns.me and owner ~= from
            and ns.Guild.IsMember(owner) then
            local old = store[owner]
            local m = ns.Guild.Get(owner)
            local online = m and m.online and ns.Comm.users[owner]   -- they answer our hello themselves
            if (not old or old.pv < pv) and not online then missing[#missing + 1] = { owner, pv } end
        end
    end
    -- The newest lists first, and only so many: the rest fill in as those guildies log in.
    table.sort(missing, function(a, b) return a[2] > b[2] end)
    for i = 1, math.min(#missing, MAX_COPIES) do Want(missing[i][1], from) end
end)

---------------------------------------------------------------------------------------------------
-- Answering requests (only by whisper, from guildmates; Comm already checked they're on the roster).

local answered = {}             -- requester -> { at, n } to keep requests in check

local function Allowed(from)
    local now = GetTime()
    local a = answered[from]
    if not a or now - a.at > 60 then answered[from] = { at = now, n = 1 }; return true end
    a.n = a.n + 1
    return a.n <= 8
end

-- Requests for my own list are gathered for a few seconds. When my list changed while most of the
-- guild was offline, everyone online asks at once when I log in: with the whole guild on the addon
-- that was 250 whispers of the same list (800 KB, 20 minutes of my send queue). From 3 askers up,
-- it goes to the guild once instead; for a minute after, asks from guildies who were online then
-- are already answered by it (someone who logged in since still gets a whisper).
local MINE_WAIT, MINE_TO_GUILD, MINE_QUIET = 4, 3, 60
local mineAskers, mineTimer, mineToGuildAt, mineHeard = {}, nil, -1000, {}

local function MyListMessage()
    local mine = Prof.MyData()
    if Prof.Sharing() and next(mine.profs) then return { t = "PROF", pv = mine.pv, p = mine.profs } end
    if mine.pv > 0 then return { t = "PROF", pv = mine.pv, p = false } end
end

local function AnswerMine()
    mineTimer = nil
    local askers = {}
    for name in pairs(mineAskers) do askers[#askers + 1] = name end
    mineAskers = {}
    local m = MyListMessage()
    if not m or #askers == 0 then return end
    if #askers >= MINE_TO_GUILD then
        mineToGuildAt = GetTime()
        mineHeard = {}
        for name, u in pairs(ns.Comm.users) do
            local g = ns.Guild.Get(name)
            if not u.sim and g and g.online then mineHeard[name] = true end
        end
        ns.Comm.Send(m, "GUILD", nil, "BULK")
        ns.Log(string.format("%d guildies asked for your recipe list: sent it to the guild once", #askers))
    else
        for _, name in ipairs(askers) do ns.Comm.Send(m, "WHISPER", name, "BULK") end
    end
end

ns.Comm.On("REQ", function(msg, from, channel, isSelf)
    if msg.w ~= "PROF" and msg.w ~= "IDX" and msg.w ~= "PROFS" then return end
    if isSelf or channel ~= "WHISPER" or not Allowed(from) then return end
    local store = Store()
    if msg.w == "PROF" then
        if GetTime() - mineToGuildAt < MINE_QUIET and mineHeard[from] then return end   -- the guild copy reached them
        mineAskers[from] = true
        if not mineTimer then mineTimer = C_Timer.NewTimer(MINE_WAIT, function() ns.Safe(AnswerMine) end) end
    elseif msg.w == "IDX" and store then
        -- The newest lists, as many as fit in one message.
        local all = {}
        for owner, e in pairs(store) do
            if ns.Guild.IsMember(owner) then all[#all + 1] = { owner, e.pv } end
        end
        table.sort(all, function(a, b) return a[2] > b[2] end)
        local l = {}
        for i = 1, math.min(#all, MAX_INDEX) do l[all[i][1]] = all[i][2] end
        ns.Comm.Send({ t = "IDX", l = l }, "WHISPER", from, "BULK")
    elseif msg.w == "PROFS" and store and type(msg.n) == "table" then
        for i = 1, math.min(#msg.n, BATCH) do
            local owner = type(msg.n[i]) == "string" and ns.Key(msg.n[i]) or nil
            local e = owner and store[owner]
            if e and owner ~= from then
                ns.Comm.Send({ t = "PROF", o = owner, pv = e.pv, p = e.off and false or e.p }, "WHISPER", from, "BULK")
            end
        end
    end
end)

-- Each roster read: saved lists of members not in the index yet go in (the index may have been built
-- before the roster had loaded at login), and members who left are forgotten
-- (only after a full read, so nobody is dropped by mistake).
ns.Listen("ROSTER", function()
    local store = Store()
    if not store then return end
    local changed = false
    for owner, e in pairs(store) do
        if owner ~= ns.me then
            if ns.Guild.IsMember(owner) then
                if not dirty and not added[owner] and not e.off and type(e.p) == "table" and next(e.p) then
                    pending[owner] = true; changed = true
                end
            elseif ns.Guild.complete then
                store[owner] = nil; pending[owner] = true; changed = true
            end
        end
    end
    if changed then ns.Fire("PROFS") end
end)
ns.Listen("LOGIN", function() dirty = true end)
