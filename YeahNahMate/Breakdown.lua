-- Guild breakdown: counts for the charts behind Home's "Online" box. Classes, levels and ranks come
-- from the game's guild roster (every member, no addon needed); professions and addon users from
-- what Yeah Nah Mate already knows. Worked out on this client only; nothing is sent.
local ADDON, ns = ...

local Breakdown = {}
ns.Breakdown = Breakdown

Breakdown.ALL, Breakdown.ONLINE, Breakdown.ACTIVE = 1, 2, 3
Breakdown.BANDS = { { 1, 9 }, { 10, 19 }, { 20, 29 }, { 30, 39 }, { 40, 49 }, { 50, 59 }, { 60, 999 } }
local ACTIVE_DAYS = 7

-- Classes that can tank or heal (a rough "could", for the at-a-glance box).
local TANKS = { WARRIOR = true, PALADIN = true, DRUID = true }
local HEALERS = { PRIEST = true, PALADIN = true, DRUID = true, SHAMAN = true }
-- Crafting professions (named in "nobody has it yet").
local CRAFTS = { 171, 164, 185, 333, 202, 129, 165, 197 }

-- Does the game tell us when members were last on? (Needed for "active this week".)
function Breakdown.HasLastOnline()
    for _, m in ipairs(ns.Guild.list) do
        if not m.online and m.offDays ~= nil then return true end
    end
    return false
end

local function Counts(m, mode)
    if mode == Breakdown.ONLINE then return m.online end
    if mode == Breakdown.ACTIVE then return m.online or (m.offDays ~= nil and m.offDays < ACTIVE_DAYS) end
    return true
end

-- Everything the charts need, for one view (all / online / active this week).
function Breakdown.Get(mode)
    local out = {
        total = 0, online = 0, classes = {}, bands = {}, ranks = {}, profs = {}, missing = {},
        tanks = 0, healers = 0, top = 0, topN = 0, myBand = nil, addon = 0, shared = 0,
    }
    for i = 1, #Breakdown.BANDS do out.bands[i] = 0 end
    local byClass, byRank, counted = {}, {}, {}
    for _, m in ipairs(ns.Guild.list) do
        if m.online then out.online = out.online + 1 end
        if Counts(m, mode) then
            counted[m.name] = true
            out.total = out.total + 1
            local c = m.class or "?"
            local e = byClass[c]
            if not e then e = { class = c, n = 0, sum = 0, max = 0 }; byClass[c] = e end
            e.n, e.sum = e.n + 1, e.sum + (m.level or 0)
            if (m.level or 0) > e.max then e.max = m.level end
            for b, band in ipairs(Breakdown.BANDS) do
                if (m.level or 0) >= band[1] and (m.level or 0) <= band[2] then out.bands[b] = out.bands[b] + 1 end
            end
            if TANKS[c] then out.tanks = out.tanks + 1 end
            if HEALERS[c] then out.healers = out.healers + 1 end
            if (m.level or 0) > out.top then out.top, out.topN = m.level, 1
            elseif (m.level or 0) == out.top then out.topN = out.topN + 1 end
            local r = byRank[m.rankIndex or 99]
            if not r then r = { index = m.rankIndex or 99, name = m.rank or "?", n = 0 }; byRank[m.rankIndex or 99] = r end
            r.n = r.n + 1
        end
    end
    for _, e in pairs(byClass) do out.classes[#out.classes + 1] = e end
    table.sort(out.classes, function(a, b) if a.n ~= b.n then return a.n > b.n end return a.class < b.class end)
    for _, r in pairs(byRank) do out.ranks[#out.ranks + 1] = r end
    table.sort(out.ranks, function(a, b) return a.index < b.index end)

    local myLevel = UnitLevel and tonumber(UnitLevel("player")) or 0
    for b, band in ipairs(Breakdown.BANDS) do
        if myLevel >= band[1] and myLevel <= band[2] then out.myBand = b end
    end

    -- Professions: guildies in this view whose lists we have (theirs if shared, and mine).
    local P = ns.Prof
    P.Lines()                                   -- makes sure the index is fresh
    local have = {}
    for line, people in pairs(P.lines) do
        local n, top = 0, 0
        for name, rank in pairs(people) do
            if counted[name] then
                n, top = n + 1, math.max(top, rank)
            end
        end
        if n > 0 then
            have[line] = true
            out.profs[#out.profs + 1] = { line = line, n = n, top = top }
        end
    end
    table.sort(out.profs, function(a, b) if a.n ~= b.n then return a.n > b.n end return a.line < b.line end)
    for _, line in ipairs(CRAFTS) do
        if not have[line] then out.missing[#out.missing + 1] = P.LineName(line) end
    end
    table.sort(out.missing)

    -- Addon users: guildies we've heard from with Yeah Nah Mate (saved per guild), and who share recipes.
    local g = ns.GuildData and ns.GuildData()
    if g and type(g.users) == "table" then
        for name in pairs(g.users) do
            if name ~= ns.me and ns.Guild.IsMember(name) then out.addon = out.addon + 1 end
        end
    end
    out.addon = out.addon + 1                   -- me
    if g and type(g.profs) == "table" then
        for name, e in pairs(g.profs) do
            if not e.off and type(e.p) == "table" and ns.Guild.IsMember(name) then out.shared = out.shared + 1 end
        end
    end
    return out
end
