-- Idea probes: can two requested features be built on Forever? Dev only: the CurseForge build leaves
-- all of this out (BigWigs packager's do-not-package markers); a copy installed from source keeps it.
--
-- /ynm dev matprobe        Materials for a recipe (for the Professions tab's tooltip): asks
--                          C_TradeSkillUI for the reagents of one recipe I know and one only a guildie
--                          knows, with whatever profession window is open (or none). Notes which
--                          functions exist, what came back, and the first reagent's item and count.
-- /ynm dev plateprobe on   Nameplates for guildies: for each nameplate that appears, notes whether
--                          the game gives us its frame, whether that frame is forbidden, and whether
--                          the unit's name and guild can be read (or are secret), and where I was
--                          (town, instance, fight). Guildies get a small test owl over their nameplate,
--                          our own frame anchored to it (nothing of Blizzard's is changed or hooked).
-- /ynm dev plateprobe off  Stops it and takes the owls away.
--
-- Answers go to YeahNahMateDB.ideaprobe (saved at /reload) and a summary to chat. Only counts and how
-- values came back are kept, never anyone's name.
local ADDON, ns = ...

--@do-not-package@
local function Secret(v) return issecretvalue and issecretvalue(v) or false end
local function How(v, kind)
    if v == nil then return "nil" end
    if Secret(v) then return "secret" end
    if kind and type(v) ~= kind then return type(v) end
    if kind == "string" and v == "" then return "empty" end
    return "ok"
end
local function Store()
    YeahNahMateDB.ideaprobe = YeahNahMateDB.ideaprobe or {}
    return YeahNahMateDB.ideaprobe
end
local function Exists(t, k) return (type(t) == "table" and type(t[k]) == "function") and "yes" or "no" end
local function Where()
    local inInstance, kind = false, nil
    if IsInInstance then inInstance, kind = IsInInstance() end
    local fight = InCombatLockdown and InCombatLockdown() or false
    if fight then return "fight" end
    if inInstance and not Secret(inInstance) then return "instance:" .. tostring(kind) end
    return "world"
end

---------------------------------------------------------------------------------------------------
-- Materials

ns.IdeaProbe = { mat = nil, plates = nil }

local function ItemName(id)
    if type(id) ~= "number" then return "?" end
    local n = C_Item and C_Item.GetItemNameByID and C_Item.GetItemNameByID(id)
    return (type(n) == "string" and not Secret(n) and n ~= "") and n or ("item " .. id .. " (name not cached)")
end

-- What the game says about one recipe's reagents: { schematic = how, slots = n, first = "Name x2", old = how }
local function Reagents(id)
    local api = C_TradeSkillUI or {}
    local r = { id = id }
    if api.GetRecipeSchematic then
        local ok, s = pcall(api.GetRecipeSchematic, id, false)
        if not ok then r.schematic = "error: " .. tostring(s)
        elseif type(s) ~= "table" then r.schematic = How(s)
        else
            local slots = s.reagentSlotSchematics
            r.schematic = "ok"
            r.slots = type(slots) == "table" and #slots or How(slots)
            local all = {}
            if type(slots) == "table" then
                for _, slot in ipairs(slots) do
                    local first = type(slot.reagents) == "table" and slot.reagents[1]
                    if first then
                        all[#all + 1] = ItemName(first.itemID) .. " x" .. tostring(slot.quantityRequired)
                    end
                end
            end
            r.mats = table.concat(all, ", ")
            r.made = ItemName(s.outputItemID)
        end
    else
        r.schematic = "no GetRecipeSchematic"
    end
    -- The older style, in case it's what Forever kept.
    if api.GetRecipeNumReagents then
        local ok, n = pcall(api.GetRecipeNumReagents, id)
        r.old = ok and How(n, "number") .. "=" .. tostring(not Secret(n) and n or "?") or ("error: " .. tostring(n))
    end
    return r
end

local function MatProbe()
    local api = C_TradeSkillUI or {}
    local s = Store()
    local out = { at = date("%H:%M:%S"), version = ns.VERSION,
        fn = { GetRecipeSchematic = Exists(api, "GetRecipeSchematic"), GetRecipeNumReagents = Exists(api, "GetRecipeNumReagents"),
            GetRecipeReagentInfo = Exists(api, "GetRecipeReagentInfo"), GetRecipeReagentItemLink = Exists(api, "GetRecipeReagentItemLink"),
            GetRecipeOutputItemData = Exists(api, "GetRecipeOutputItemData") },
        window = (api.IsTradeSkillReady and api.IsTradeSkillReady()) and "open" or "closed" }
    -- One recipe I know, one only a guildie knows.
    local mineSet, known, other = {}, nil, nil
    local my = ns.Prof.MyData and ns.Prof.MyData()
    for _, d in pairs(my and my.profs or {}) do
        for _, id in ipairs(d.i or {}) do mineSet[id] = true; known = known or id end
    end
    for id in pairs(ns.Prof.recipes or {}) do if not mineSet[id] then other = id; break end end
    if not other then for id in pairs(ns.RecipeItem or {}) do if not mineSet[id] then other = id; break end end end
    out.known = known and Reagents(known) or "I know no recipes yet (open a profession window once)"
    out.other = other and Reagents(other) or "no recipe found that I don't know"
    s.mat = out
    ns.IdeaProbe.mat = out
    local function Line(label, r)
        if type(r) ~= "table" then return label .. ": " .. tostring(r) end
        return label .. " (" .. tostring(r.made or r.id) .. "): " .. tostring(r.schematic)
            .. (r.slots and (", " .. tostring(r.slots) .. " reagents") or "") .. ((r.mats and r.mats ~= "") and (": " .. r.mats) or "")
    end
    ns.Print("Materials probe (profession window " .. out.window .. "; GetRecipeSchematic " .. out.fn.GetRecipeSchematic .. ")")
    print("  " .. Line("A recipe I know", out.known))
    print("  " .. Line("A guildie's recipe", out.other))
    return out
end

---------------------------------------------------------------------------------------------------
-- Nameplates

local watcher, owls, free = nil, {}, {}

local function Owl(plate)
    local f = table.remove(free) or CreateFrame("Frame", nil, UIParent)
    f:SetSize(18, 18)
    if not f.tex then
        f.tex = f:CreateTexture(nil, "OVERLAY")
        f.tex:SetAllPoints()
        f.tex:SetTexture(ns.UI.MINI)
    end
    f:ClearAllPoints()
    f:SetPoint("BOTTOM", plate, "TOP", 0, 2)
    f:Show()
    return f
end

local function Count(t, k) t[k] = (t[k] or 0) + 1 end

local function OnAdded(unit)
    local p = ns.IdeaProbe.plates
    p.seen = p.seen + 1
    local where = Where()
    Count(p.where, where)
    local isPlayer = UnitIsPlayer and UnitIsPlayer(unit)
    if Secret(isPlayer) then Count(p.player, "secret") return end
    if not isPlayer then Count(p.player, "npc") return end
    Count(p.player, "player")
    local plate = C_NamePlate and C_NamePlate.GetNamePlateForUnit and C_NamePlate.GetNamePlateForUnit(unit)
    local forbidden = plate and plate.IsForbidden and plate:IsForbidden()
    Count(p.frame, plate == nil and "nil" or (forbidden and "forbidden" or "ok"))
    local name = UnitName and UnitName(unit)
    Count(p.name, How(name, "string"))
    local inGuild = UnitIsInMyGuild and UnitIsInMyGuild(unit)
    if Secret(inGuild) then Count(p.myGuild, "secret"); inGuild = nil
    else Count(p.myGuild, inGuild == nil and "nil" or tostring(inGuild)) end
    local gname = GetGuildInfo and GetGuildInfo(unit)
    Count(p.guildName, How(gname, "string"))
    -- A guildie: by the game's own check, or by the name on my roster.
    local onRoster = false
    if How(name, "string") == "ok" then
        local key = ns.Key and ns.Key(name)
        onRoster = key ~= nil and ns.Guild.IsMember(key)
    end
    Count(p.onRoster, tostring(onRoster))
    if (inGuild == true or onRoster) then
        p.guildies = p.guildies + 1
        Count(p.guildieWhere, where)
        if plate and not forbidden then
            local old = owls[unit]                  -- added again: free the old owl first
            if old then old:Hide(); old:ClearAllPoints(); free[#free + 1] = old; owls[unit] = nil end
            local ok, owl = pcall(Owl, plate)
            if ok then owls[unit] = owl; p.owls = p.owls + 1 else Count(p.owlErrors, tostring(owl)) end
        end
    end
end

local function OnRemoved(unit)
    local owl = owls[unit]
    if owl then owl:Hide(); owl:ClearAllPoints(); free[#free + 1] = owl; owls[unit] = nil end
end

local function PlateProbe(on)
    local s = Store()
    if not on then
        if watcher then watcher:UnregisterAllEvents() end
        for unit in pairs(owls) do OnRemoved(unit) end
        s.plateWatch = false
        return
    end
    local cvar = C_CVar and C_CVar.GetCVar and C_CVar.GetCVar("nameplateShowFriends")
    ns.IdeaProbe.plates = { at = date("%H:%M:%S"), version = ns.VERSION, seen = 0, guildies = 0, owls = 0,
        showFriends = tostring(cvar), fn = { GetNamePlateForUnit = Exists(C_NamePlate, "GetNamePlateForUnit"),
            UnitIsInMyGuild = type(UnitIsInMyGuild) == "function" and "yes" or "no" },
        where = {}, player = {}, frame = {}, name = {}, myGuild = {}, guildName = {}, onRoster = {}, guildieWhere = {}, owlErrors = {} }
    s.plates = ns.IdeaProbe.plates
    s.plateWatch = true
    watcher = watcher or CreateFrame("Frame")
    watcher:SetScript("OnEvent", function(_, event, unit)
        if event == "NAME_PLATE_UNIT_ADDED" then ns.Safe(OnAdded, unit) else ns.Safe(OnRemoved, unit) end
    end)
    local ok1 = pcall(watcher.RegisterEvent, watcher, "NAME_PLATE_UNIT_ADDED")
    pcall(watcher.RegisterEvent, watcher, "NAME_PLATE_UNIT_REMOVED")
    ns.IdeaProbe.plates.events = ok1 and "ok" or "NAME_PLATE_UNIT_ADDED unknown"
    -- Nameplates already showing.
    if C_NamePlate and C_NamePlate.GetNamePlates then
        local ok, list = pcall(C_NamePlate.GetNamePlates)
        if ok and type(list) == "table" then
            for _, plate in ipairs(list) do
                local unit = plate.namePlateUnitToken
                if type(unit) == "string" and not Secret(unit) then ns.Safe(OnAdded, unit) end
            end
        end
    end
end

-- A one-line summary for chat and the dev console.
function ns.IdeaProbe.PlateSummary()
    local p = ns.IdeaProbe.plates
    if not p then return "Nameplate probe not run yet." end
    local function List(t)
        local out = {}
        for k, v in pairs(t) do out[#out + 1] = k .. " " .. v end
        table.sort(out)
        return #out > 0 and table.concat(out, ", ") or "-"
    end
    return string.format("%d plates (%s); frames %s; names %s; my guild %s; on my roster %s; %d guildies, %d owls shown. Friendly plates setting: %s.",
        p.seen, List(p.player), List(p.frame), List(p.name), List(p.myGuild), List(p.onRoster), p.guildies, p.owls, p.showFriends)
end

ns.devCommands.matprobe = function() ns.Safe(MatProbe) end
ns.devCommands.plateprobe = function(arg)
    if arg == "off" then
        PlateProbe(false)
        ns.Print("Nameplate probe off. " .. ns.IdeaProbe.PlateSummary() .. " /reload saves.")
    else
        PlateProbe(true)
        ns.Print("Nameplate probe on: walk past guildies (friendly nameplates need to be on: ctrl+V or the game's Names settings), "
            .. "in town, in a dungeon and in a fight. Guildies get a small owl over their nameplate. /ynm dev plateprobe off stops it.")
    end
end
ns.Listen("LOGIN", function()
    if YeahNahMateDB and YeahNahMateDB.ideaprobe and YeahNahMateDB.ideaprobe.plateWatch then PlateProbe(true) end
end)
--@end-do-not-package@
