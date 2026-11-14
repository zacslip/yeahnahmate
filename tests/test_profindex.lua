-- 0.9.11: the recipe index is updated one person at a time (only the people whose lists changed),
-- not rebuilt from scratch for every list. Random lists, sharing switched off, my own list changing
-- and guildies leaving: after each round the index must match a full rebuild exactly.
math.randomseed(11)
YeahNahMateDB = nil
local MEMBERS = 40
local CLASSES = { "WARRIOR", "MAGE", "PRIEST", "ROGUE", "HUNTER", "SHAMAN", "WARLOCK", "DRUID" }
FAKE.roster = { { "Ned Jones", "Guild Master", 0, 22, "Shaman", "The Barrens", "", "", true, 0, "SHAMAN", 0, 0, false, false, 3, "Player-6797-0000ZAC1" } }
local names = {}
for i = 1, MEMBERS do
    names[i] = "Crafter Number" .. i
    FAKE.roster[#FAKE.roster + 1] = { names[i], "Member", 3, 20 + i % 40, "x", "Durotar", "", "", true, 0, CLASSES[i % 8 + 1] }
end
local ns = LoadAddon("YeahNahMate", "YeahNahMate")
LOGGED_IN = true
FireEvent("PLAYER_LOGIN")
ns.settings.sharePosition, ns.settings.shareProfessions = false, true
Tick(2)
local Ser = LibStub("AceSerializer-3.0")
local function Msg(t) return Ser:Serialize(t) end
local P = ns.Prof

local LINES = { 197, 164, 171, 333 }
local function RandomList()
    local p = {}
    for _, line in ipairs(LINES) do
        if math.random() < 0.4 then
            local ids, seen = {}, {}
            for _ = 1, math.random(1, 25) do
                local id = line * 1000 + math.random(1, 40)       -- small pool: lots of shared recipes
                if not seen[id] then seen[id] = true; ids[#ids + 1] = id end
            end
            table.sort(ids)
            p[line] = { r = math.random(1, 300), m = 300, i = ids }
        end
    end
    return p
end

-- The index as plain data: every recipe in order with its crafters (sorted), and the professions.
local function Snapshot()
    local recipes = {}
    for _, e in ipairs(P.Search(nil, "")) do
        local c = {}
        for _, n in ipairs(e.crafters) do c[#c + 1] = n end
        table.sort(c)
        recipes[#recipes + 1] = e.id .. ":" .. e.line .. ":" .. table.concat(c, ",")
    end
    local lines = {}
    for _, l in ipairs(P.Lines()) do lines[#lines + 1] = l.line .. ":" .. l.count .. ":" .. l.top end
    local count = P.RecipeCount()
    return table.concat(recipes, "|"), table.concat(lines, "|"), count
end

local pv = GetServerTime() - 100000
local function Send(name, p)
    pv = pv + 1
    INJECT("YNM", Msg({ v = 1, t = "PROF", pv = pv, p = p }), "GUILD", name)
end

-- Everyone's first list (with the index built in between, so later rounds are real updates).
for i = 1, MEMBERS do Send(names[i], RandomList()) end
Deliver()
P.Search(nil, "")

local same, rounds, left = true, 40, {}
for round = 1, rounds do
    for _ = 1, math.random(1, 6) do
        local i = math.random(1, MEMBERS)
        local roll = math.random()
        if left[i] then
            -- nothing: they've left the guild
        elseif roll < 0.6 then Send(names[i], RandomList())
        elseif roll < 0.75 then Send(names[i], false)                -- stopped sharing
        elseif roll < 0.9 then
            -- My own list changes (what reading a profession window does).
            local mine = P.MyData()
            local line = LINES[math.random(1, #LINES)]
            if math.random() < 0.3 then mine.profs[line] = nil
            else mine.profs[line] = RandomList()[line] or { r = 1, m = 75, i = { line * 1000 + 1 } } end
            P.PersonChanged(ns.me)
        elseif i > 5 then
            -- Leaves the guild.
            left[i] = true
            for k, r in ipairs(FAKE.roster) do
                if r[1] == names[i] then table.remove(FAKE.roster, k); break end
            end
            FireEvent("GUILD_ROSTER_UPDATE")
            Tick(2)
        end
    end
    Deliver()
    local r1, l1, c1 = Snapshot()          -- the step-by-step index
    P.MarkDirty()
    local r2, l2, c2 = Snapshot()          -- a full rebuild
    if r1 ~= r2 or l1 ~= l2 or c1 ~= c2 then
        same = false
        print("round " .. round .. " differs")
        print("  step:  " .. r1:sub(1, 300))
        print("  full:  " .. r2:sub(1, 300))
        print("  lines: " .. l1 .. "  vs  " .. l2)
        break
    end
    -- A few rounds with no full rebuild in between, so updates pile on updates.
    if round % 3 ~= 0 then
        for _ = 1, 3 do
            local i = math.random(1, MEMBERS)
            if not left[i] then Send(names[i], RandomList()) end
        end
        Deliver()
        P.Search(nil, "")
    end
end
check(same, "after " .. rounds .. " rounds of changes the step-by-step index matches a full rebuild")

-- Recipes nobody has any more leave the list; a recipe's table stays the same while it's known
-- (open crafter cards keep pointing at the right list).
local id = 197 * 1000 + 999
Send(names[1], { [197] = { r = 1, m = 75, i = { id } } })
Deliver()
P.Search(nil, "")
check(P.recipes[id] and #P.recipes[id].crafters == 1, "a new recipe appears with its crafter")
local before = P.recipes[id]
Send(names[2], { [197] = { r = 1, m = 75, i = { id } } })
Deliver()
P.Search(nil, "")
check(P.recipes[id] == before and #before.crafters == 2, "a second crafter joins the same recipe entry")
Send(names[1], false)
Send(names[2], false)
Deliver()
local found = false
for _, e in ipairs(P.Search(nil, "")) do if e.id == id then found = true end end
check(not found and P.recipes[id] == nil, "nobody has it any more: gone from the list")

-- Changing one list doesn't redo the whole index (the item info per recipe isn't looked up again).
local calls = 0
local real = C_Spell.GetSpellName
C_Spell.GetSpellName = function(...) calls = calls + 1; return real(...) end
Send(names[3], RandomList())
Deliver()
P.Search(nil, "")
C_Spell.GetSpellName = real
check(calls < 30, "one changed list names only its new recipes (" .. calls .. " lookups)")

check(#ERRORS == 0, "no errors (" .. (ERRORS[1] or "none") .. ")")
