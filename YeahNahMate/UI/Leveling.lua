-- The Leveling tab: a row of views (VIEWS, near the end of this file; a new one is one more entry). It
-- opens on Zones, which with Dungeons follows my level and faction. Raids is its own tab (end of the file).
local _, ns = ...
local L = ns.L
local UI = ns.UI
local Text, Button, Box, Row = UI.Text, UI.Button, UI.Box, UI.Row

local YELLOW = "|cffffd100"
local ORANGE = "|cffff8040"
local LIST_W = 736
local LIST_BOTTOM = -388        -- where the pagers and colour keys sit
local PIN_REF = "YeahNahMateGuide"
local Pins = LibStub("HereBeDragons-Pins-2.0")
local page, pin
local newLevel                  -- from PLAYER_LEVEL_UP: UnitLevel can still say the old level then

local function Level()
    return UI.levelingPretend or newLevel or UnitLevel("player") or 1
end

-- The view showing now, for the page and the dev console.
function UI.LevelingView()
    return page and page.view or "zones"
end

-- A new level redraws the view I'm on.
local function LevelChanged()
    UI.Dirty()
end

-- Dev console: see the tab as another level (nil = my real level).
function UI.SetLevelingPretend(level)
    UI.levelingPretend = level
    if page then page.guide.questKey = nil end
    LevelChanged()
end

--@do-not-package@
-- /ynm dev level 60 | off, /ynm dev faction alliance | horde | off: for the /ynmdev Leveling page.
-- They only change what this screen shows.
ns.devCommands.level = function(arg)
    UI.SetLevelingPretend(tonumber(arg))
end
ns.devCommands.faction = function(arg)
    ns.Dungeons.pretendFaction = (arg == "alliance" and "Alliance") or (arg == "horde" and "Horde") or nil
    UI.Dirty()
end
--@end-do-not-package@

ns.OnEvent("PLAYER_LEVEL_UP", function(level)
    newLevel = tonumber(level)
    LevelChanged()
end)

-- Taking or handing in a quest updates In log / Done, only while a quest list is on screen.
local function QuestsChanged()
    if page and page:IsVisible() and (page.guide.questKey or UI.LevelingView() ~= "zones") then UI.DirtySlow() end
end
ns.OnEvent("QUEST_LOG_UPDATE", QuestsChanged)
ns.OnEvent("QUEST_TURNED_IN", QuestsChanged)

---------------------------------------------------------------------------------------------------
-- A list of rows with a pager and the mouse wheel. fill(row, item) draws one row.

local function RowList(parent, x, w, top, rowH, count, make, fill)
    local l = { offset = 0, items = {}, rows = {} }
    for i = 1, count do
        local r = Row(parent, x, top - (i - 1) * rowH, w, rowH - 1)
        r.stripe:SetColorTexture(1, 1, 1, (i % 2 == 0) and 0.04 or 0)
        make(r)
        l.rows[i] = r
    end
    local function Draw()
        local most = math.max(0, #l.items - count)
        l.offset = math.max(0, math.min(most, l.offset))
        for i, r in ipairs(l.rows) do
            local item = l.items[l.offset + i]
            r.item = item
            if item then fill(r, item); r:Show() else r:Hide() end
        end
        l.pager.Set(l.offset + 1, math.min(#l.items, l.offset + count), #l.items)
    end
    l.pager = UI.Pager(parent, x + w - 142, LIST_BOTTOM, function(d)
        l.offset = l.offset + d * count
        Draw()
    end)
    local wheel = CreateFrame("Frame", nil, parent)
    wheel:SetPoint("TOPLEFT", x, top)
    wheel:SetSize(w, count * rowH)
    wheel:EnableMouseWheel(true)
    wheel:SetScript("OnMouseWheel", function(_, delta)
        l.offset = l.offset - delta
        Draw()
    end)
    function l.Set(items)
        l.items = items
        Draw()
    end
    return l
end

---------------------------------------------------------------------------------------------------
-- Zone and dungeon rows

-- Open the world map at this map, with this window waiting behind it. The game's own call, from a
-- click, never in combat. False if it couldn't open.
local function OpenMap(mapID)
    if InCombatLockdown() or not (C_Map and C_Map.OpenWorldMap) then return false end
    if not pcall(C_Map.OpenWorldMap, mapID) then return false end
    UI.SendBehindMap()
    return true
end

-- The Fishing cell: "min / no getaways", coloured by my own fishing skill when I have it: green = nothing
-- gets away, yellow = some get away, grey = too low to catch anything. "-" no fishing listed, blank not known.
local myFishing
local function FishText(z)
    if z.fishMin == false then return ns.GREY .. "-|r" end
    if not z.fishMin then return "" end
    local text = z.fishMin .. " / " .. z.fishAll
    local mine = myFishing
    if not mine then return text end
    if mine >= z.fishAll then return ns.GREEN .. text .. "|r" end
    if mine >= z.fishMin then return YELLOW .. text .. "|r" end
    return ns.GREY .. text .. "|r"
end

local function ZoneTip(self)
    self.hl:Show()
    local z = self.item
    if not z or not GameTooltip then return end
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:AddLine(z.name, 1, 1, 1)
    GameTooltip:AddLine(string.format(L.GUIDE_TIP_RANGE, z.min, z.max))
    GameTooltip:AddLine(string.format(L.GUIDE_TIP_ZONE_BEST, z.bestMin, z.bestMax))
    if z.fishMin == false then
        GameTooltip:AddLine(L.GUIDE_TIP_FISH_NONE, 0.62, 0.62, 0.62)
    elseif z.fishMin then
        GameTooltip:AddLine(string.format(L.GUIDE_TIP_FISH, z.fishMin, z.fishAll))
    else
        GameTooltip:AddLine(L.GUIDE_TIP_FISH_UNKNOWN, 0.62, 0.62, 0.62, true)
    end
    if myFishing then GameTooltip:AddLine(string.format(L.GUIDE_TIP_MY_FISH, myFishing), 0.62, 0.62, 0.62) end
    if ns.LevelGuide.ZoneMap(z.name) then
        GameTooltip:AddLine(L.GUIDE_TIP_ZONE_MAP, 0.25, 1, 0.25)
    else
        GameTooltip:AddLine(L.GUIDE_ZONE_NO_MAP, 0.62, 0.62, 0.62)
    end
    GameTooltip:Show()
end

-- Zones list columns: name, Range, Best at, Fishing (x, width). The headings use the same.
local ZCOL = { name = { 6, 330 }, range = { 340, 110 }, best = { 455, 130 }, fish = { 590, 140 } }

local function MakeZoneRow(r)
    r.name = Text(r, "", "GameFontHighlightSmall", ZCOL.name[1], -5, ZCOL.name[2])
    r.range = Text(r, "", "GameFontHighlightSmall", ZCOL.range[1], -5, ZCOL.range[2], "CENTER")
    r.best = Text(r, "", "GameFontHighlightSmall", ZCOL.best[1], -5, ZCOL.best[2], "CENTER")
    r.fish = Text(r, "", "GameFontHighlightSmall", ZCOL.fish[1], -5, ZCOL.fish[2], "CENTER")
    r:SetScript("OnClick", function(self)
        local mapID = self.item and ns.LevelGuide.ZoneMap(self.item.name)
        if not mapID then return end
        page.guide.zoneHint = not OpenMap(mapID) and L.GUIDE_ZONE_MAP_FAILED or nil
        UI.Dirty()
    end)
    r:SetScript("OnEnter", ZoneTip)
    r:SetScript("OnLeave", function(self)
        self.hl:Hide()
        if GameTooltip then GameTooltip:Hide() end
    end)
end

local function FillZoneRow(r, z)
    local colour = (z.outside and ns.GREY) or (z.best and ns.GREEN) or ""
    r.name:SetText(colour .. z.name .. "|r")
    r.range:SetText(z.min .. "-" .. z.max)
    r.best:SetText(colour .. z.bestMin .. "-" .. z.bestMax .. "|r")
    r.fish:SetText(FishText(z))
end

local TAGS = { key = L.GUIDE_TAG_KEY, attune = L.GUIDE_TAG_ATTUNE, item = L.GUIDE_TAG_ITEM, enemy = L.GUIDE_TAG_ENEMY }

local BOSS_TICK = "|TInterface\\RaidFrame\\ReadyCheck-Ready:12:12|t "

local function AddBossList(title, rows)
    if #rows == 0 then return end
    local done = 0
    for _, b in ipairs(rows) do
        if b.done then done = done + 1 end
    end
    GameTooltip:AddLine(" ")
    GameTooltip:AddLine(string.format(title, done, #rows), 1, 0.82, 0)
    for _, b in ipairs(rows) do
        if b.done then
            GameTooltip:AddLine(BOSS_TICK .. b.name, 0.25, 1, 0.25)
        else
            GameTooltip:AddLine("     " .. b.name, 0.62, 0.62, 0.62)
        end
    end
end

local function AddBosses(key)
    local main, extra = ns.Bosses.Rows(key)
    AddBossList(L.GUIDE_TIP_BOSSES, main)
    AddBossList(L.GUIDE_TIP_BONUS, extra)
    if #main > 0 then GameTooltip:AddLine(" ") end
end

local function DungeonTip(self)
    self.hl:Show()
    local d = self.item
    if not d or not GameTooltip then return end
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:AddLine(d.name, 1, 1, 1)
    GameTooltip:AddLine(string.format(L.GUIDE_TIP_RANGE, d.min, d.max))
    GameTooltip:AddLine(string.format(d.top and L.GUIDE_TIP_TOP_BOSS or L.GUIDE_TIP_BOSS, d.boss))
    GameTooltip:AddLine(string.format(L.GUIDE_TIP_BEST, d.best))
    if d.where then GameTooltip:AddLine(string.format(L.GUIDE_TIP_WHERE, d.where)) end
    if d.note then GameTooltip:AddLine(d.note, 1, 0.82, 0, true) end
    if d.enemy then GameTooltip:AddLine(string.format(L.GUIDE_TIP_ENEMY, d.enemy), 1, 0.5, 0.25, true) end
    AddBosses(d.key)
    GameTooltip:AddLine(L.GUIDE_TIP_CLICK, 0.25, 1, 0.25)
    GameTooltip:Show()
end

-- Open a dungeon's quest list.
function UI.LevelingOpenDungeon(key)
    if not page then UI.Open("leveling") end
    page.view = "dungeons"
    page.guide.questKey = key
    page.guide.quests.offset = 0
    page.guide.questHint = nil
    page.guide.treeJump = true
    UI.Dirty()
end

local function MakeDungeonRow(r)
    r:SetScript("OnClick", function(self)
        if self.item then UI.LevelingOpenDungeon(self.item.key) end
    end)
    r.name = Text(r, "", "GameFontHighlightSmall", 6, -4, 340)
    r.tag = Text(r, "", "GameFontNormalSmall", 300, -4, 192, "RIGHT")
    r.bossTint = r:CreateTexture(nil, "BACKGROUND", nil, 1)
    r.bossTint:SetPoint("TOPLEFT", 498, 0)
    r.bossTint:SetSize(108, 35)
    r.bossTint:Hide()
    r.bosses = Text(r, "", "GameFontHighlightSmall", 498, -12, 108, "CENTER")
    r.range = Text(r, "", "GameFontHighlightSmall", 610, -4, 120, "RIGHT")
    r.info = Text(r, "", "GameFontDisableSmall", 6, -19, 290)
    r.where = Text(r, "", "GameFontDisableSmall", 300, -19, 192, "RIGHT")
    r:SetScript("OnEnter", DungeonTip)
    r:SetScript("OnLeave", function(self)
        self.hl:Hide()
        if GameTooltip then GameTooltip:Hide() end
    end)
end

local function FillDungeonRow(r, d)
    r.name:SetText(((d.outside and ns.GREY) or (d.ready and ns.GREEN) or YELLOW) .. d.name .. "|r")
    r.tag:SetText(d.tag and TAGS[d.tag] or "")
    r.range:SetText(d.min .. "-" .. d.max)
    r.info:SetText(string.format(d.top and L.GUIDE_TOP_BOSS_LINE or L.GUIDE_BOSS_LINE, d.boss, d.best))
    r.where:SetText(d.where or "")
    -- Bosses killed: gold while some are done, green when every main boss is.
    local done, total, bonus = ns.Bosses.Count(d.key)
    local complete, started = total > 0 and done == total, done > 0 or bonus > 0
    local colour = (complete and ns.GREEN) or (started and YELLOW) or ns.GREY
    r.bosses:SetText(colour .. string.format(L.GUIDE_BOSS_COUNT, done, total)
        .. (bonus > 0 and string.format(L.GUIDE_BOSS_BONUS, bonus) or "") .. "|r")
    r.bossState = (complete and "complete") or (started and "progress") or nil
    r.bossTint:SetShown(started)
    if complete then
        r.bossTint:SetColorTexture(0.2, 0.85, 0.3, 0.30)
    elseif started then
        r.bossTint:SetColorTexture(1, 0.82, 0, 0.22)
    end
end

---------------------------------------------------------------------------------------------------
-- A dungeon's quests, and one pin on the world map for where a quest starts

local function PinTip(self)
    local q = self.quest
    if not q or not GameTooltip then return end
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:AddLine(q.name, 1, 1, 1)
    if q.giver then GameTooltip:AddLine(string.format(L.GUIDE_STARTS_WITH, q.giver)) end
    GameTooltip:AddLine(L.GUIDE_PIN_REMOVE, 0.25, 1, 0.25)
    GameTooltip:Show()
end

local function ClearPin()
    if pin and pin.quest then
        Pins:RemoveWorldMapIcon(PIN_REF, pin)
        pin:Hide()
        pin.quest = nil
        if GameTooltip then GameTooltip:Hide() end
    end
    UI.Dirty()
end

-- Above every other pin on the map (the game's pin levels stop at 9000), but still inside the map.
local PIN_LEVEL = 8900
local PIN_SIZE = 56
local PIN_QUEST = "Interface\\GossipFrame\\AvailableQuestIcon"
local PIN_ENTRANCE = "Interface\\TargetingFrame\\UI-RaidTargetingIcon_8"

-- A gold glow that pulses, so it's easy to spot on a big map. Only runs while the map shows it.
local function PulsePin(self, elapsed)
    self.pulse = (self.pulse + elapsed * 3.2) % (2 * math.pi)
    local wave = (math.sin(self.pulse) + 1) / 2
    local size = 34 + 22 * wave
    self.glow:SetSize(size, size)
    self.glow:SetAlpha(0.65 - 0.4 * wave)
end

local function MakePin()
    local p = CreateFrame("Button", nil, UIParent)
    p:SetSize(PIN_SIZE, PIN_SIZE)
    p:SetFrameLevel(PIN_LEVEL)
    if p.SetFixedFrameLevel then p:SetFixedFrameLevel(true) end
    if p.SetHitRectInsets then p:SetHitRectInsets(12, 12, 12, 12) end
    p.glow = p:CreateTexture(nil, "BACKGROUND")
    p.glow:SetPoint("CENTER")
    p.glow:SetSize(40, 40)
    p.glow:SetTexture("Interface\\CHARACTERFRAME\\TempPortraitAlphaMask")
    p.glow:SetVertexColor(1, 0.82, 0)
    p.back = p:CreateTexture(nil, "BORDER")
    p.back:SetPoint("CENTER")
    p.back:SetSize(34, 34)
    p.back:SetTexture("Interface\\CHARACTERFRAME\\TempPortraitAlphaMask")
    p.back:SetVertexColor(0, 0, 0, 0.8)
    p.icon = p:CreateTexture(nil, "OVERLAY")
    p.icon:SetPoint("CENTER")
    p.icon:SetSize(30, 30)
    p.pulse = 0
    p:SetScript("OnUpdate", PulsePin)
    p:SetScript("OnEnter", PinTip)
    p:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
    p:SetScript("OnClick", ClearPin)
    p:Hide()
    return p
end

local function PlacePin(q)
    if not pin then
        pin = MakePin()
    elseif pin.quest then
        Pins:RemoveWorldMapIcon(PIN_REF, pin)
    end
    pin.quest = q
    pin.icon:SetTexture(q.entrance and PIN_ENTRANCE or PIN_QUEST)
    Pins:AddWorldMapIconMap(PIN_REF, pin, q.map, q.x / 100, q.y / 100, HBD_PINS_WORLDMAP_SHOW_CONTINENT)
end

function UI.LevelingPinnedQuest() return pin and pin.quest end

-- A click: pin where it starts and open the map there, with this window waiting behind it. The game's
-- own call, never in combat. If it can't open, the pin is still there for when the player presses M.
local function ShowOnMap(q)
    local g = page.guide
    PlacePin(q)
    g.questHint = not OpenMap(q.map) and L.GUIDE_PINNED_PRESS_M or nil
    UI.Dirty()                  -- the row now says Pinned
end

local MAX_CHAIN_LINES = 10
local CHAIN_MARK = {
    done = { L.GUIDE_DONE, 0.25, 1, 0.25 }, log = { L.GUIDE_IN_LOG, 1, 0.82, 0 },
    next = { L.GUIDE_NEXT, 1, 0.5, 0.25 }, later = { "", 0.62, 0.62, 0.62 },
}

-- The chain in the tooltip, in the order you do it. A long one keeps its last steps.
local function AddChain(plan)
    local steps = ns.LevelGuide.QuestChain(plan)
    if #steps < 2 then return end
    GameTooltip:AddLine(" ")
    GameTooltip:AddLine(L.GUIDE_CHAIN, 1, 0.82, 0)
    local from = math.max(1, #steps - MAX_CHAIN_LINES + 1)
    if from > 1 then GameTooltip:AddLine(string.format(L.GUIDE_CHAIN_MORE, from - 1), 0.62, 0.62, 0.62) end
    for i = from, #steps do
        local s, m = steps[i], CHAIN_MARK[steps[i].state]
        GameTooltip:AddDoubleLine(i .. ". [" .. s.level .. "] " .. s.name, m[1], m[2], m[3], m[4], m[2], m[3], m[4])
    end
end

local function QuestTip(self)
    self.hl:Show()
    local q = self.item
    if not q or not GameTooltip then return end
    local place = self.place or q
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:AddLine(q.name, 1, 1, 1)
    GameTooltip:AddLine(string.format(L.GUIDE_QUEST_LEVELS, q.level, q.req))
    local bag = page.guide.treeKey == "bags" and ns.LevelGuide.BagFor(q, not q.focus)
    if bag then GameTooltip:AddLine(string.format(L.GUIDE_BAG_TIP, bag.name, bag.slots), 1, 0.82, 0) end
    if q.focus then GameTooltip:AddLine(string.format(L.GUIDE_CHAIN_PROGRESS, q.doneCount, q.total), 1, 0.82, 0) end
    if self.locked then
        GameTooltip:AddLine(string.format(L.GUIDE_NEEDS, place.name), 1, 0.5, 0.25, true)
    end
    if place.giver then GameTooltip:AddLine(string.format(L.GUIDE_STARTS_WITH, place.giver)) end
    local location = ns.LevelGuide.MapName(place.map)
    if location then GameTooltip:AddLine(string.format(L.GUIDE_LOCATION_TIP, location)) end
    if self.plan then AddChain(self.plan) end
    GameTooltip:AddLine(" ")
    GameTooltip:AddLine((not place.map and L.GUIDE_NO_MAP_TIP) or (self.locked and L.GUIDE_TIP_NEXT) or L.GUIDE_TIP_MAP,
        0.25, 1, 0.25, true)
    GameTooltip:Show()
end

local function MakeQuestRow(r)
    r.level = Text(r, "", "GameFontHighlightSmall", 6, -5, 34, "CENTER")
    r.name = Text(r, "", "GameFontHighlightSmall", 46, -5, 224)
    r.state = Text(r, "", "GameFontNormalSmall", 274, -5, 52, "CENTER")
    r.giver = Text(r, "", "GameFontDisableSmall", 330, -5, 150)
    r.location = Text(r, "", "GameFontDisableSmall", 484, -5, 130)
    r.map = Text(r, "", "GameFontNormalSmall", 616, -5, 114, "RIGHT")
    r.tint = r:CreateTexture(nil, "BACKGROUND", nil, 1)     -- the status colour, under the hover highlight
    r.tint:SetAllPoints()
    r.tint:Hide()
    r.toggle = Button(r, "+", 18, 45, -2, function()        -- open or close a storyline
        local g = page.guide
        local open = g.treeOpen[g.treeKey]
        if r.item then open[r.item.id] = not open[r.item.id] or nil end
        UI.Dirty()
    end, 17)
    r.toggle:Hide()
    r:SetScript("OnClick", function(self)
        if self.place and self.place.map then ShowOnMap(self.place) end
    end)
    r:SetScript("OnEnter", QuestTip)
    r:SetScript("OnLeave", function(self)
        self.hl:Hide()
        if GameTooltip then GameTooltip:Hide() end
    end)
end

-- Status: text colour, row tint (the see-through green and gold of the clan meeting rows), label.
local STATUS = {
    done = { ns.GREEN, 0.2, 0.85, 0.3, 0.30, L.GUIDE_DONE },
    log = { YELLOW, 1, 0.82, 0, 0.22, L.GUIDE_IN_LOG },
    locked = { ORANGE, 1, 0.5, 0.25, 0.20, L.GUIDE_LOCKED },
}

-- Where a quest stands. Not started: the place to go is the next quest in the chain. Started or done:
-- this quest's own.
local function QuestPlace(quest)
    local state = ns.LevelGuide.QuestState(quest)
    local plan = ns.LevelGuide.QuestPlan(quest)
    return state, plan, state and quest or plan.target, not state and plan.locked
end

local function FillQuestRow(r, q)
    -- A closed storyline stands for the quest I'm working towards in it.
    local state, plan, place, locked = QuestPlace(q.focus or q)
    r.plan, r.place, r.locked = plan, place, locked
    r.level:SetText(q.level)
    -- A tree: indented by depth, with + / - on a storyline of two or more.
    local x = 68 + q.depth * 14
    r.name:ClearAllPoints()
    r.name:SetPoint("TOPLEFT", x, -5)
    r.name:SetWidth(270 - x)
    r.toggle:SetShown(q.summary == true)
    if q.summary then r.toggle:SetText(page.guide.treeOpen[page.guide.treeKey][q.id] and "-" or "+") end
    r.name:SetText(q.name)
    -- The row's colour: its own status, or on a storyline's top row the furthest I've got.
    local status = q.summary and q.furthest or (not q.summary and (state or (locked and "locked"))) or nil
    r.status = status
    local look = STATUS[status]
    r.tint:SetShown(look ~= nil)
    if look then r.tint:SetColorTexture(look[2], look[3], look[4], look[5]) end
    local colour = look and look[1] or ""
    if q.summary then
        r.state:SetText(colour .. string.format(L.GUIDE_CHAIN_COUNT, q.doneCount, q.total) .. "|r")
    else
        r.state:SetText(look and (colour .. look[6] .. "|r") or "")
    end
    local bag = page.guide.treeKey == "bags" and ns.LevelGuide.BagFor(q, not q.focus)
    if bag then
        r.giver:SetText(ns.GOLD .. string.format(L.GUIDE_BAG_ROW, bag.slots, bag.name) .. "|r")
    else
        r.giver:SetText(locked and (ORANGE .. string.format(L.GUIDE_NEEDS, place.name) .. "|r") or place.giver or "")
    end
    r.location:SetText(ns.LevelGuide.MapName(place.map) or L.GUIDE_NO_LOCATION)
    local pinned = pin and pin.quest and pin.quest.id == place.id
    r.map:SetText((pinned and (ns.GREEN .. L.GUIDE_PINNED .. "|r"))
        or (place.map and (locked and L.GUIDE_SHOW_NEXT or L.GUIDE_SHOW_MAP))
        or (ns.GREY .. L.GUIDE_NO_MAP .. "|r"))
end

-- The quest list's columns: label, x, width, sort key.
local QUEST_COLS = {
    { L.GUIDE_LEVEL, 4, 40, "level" }, { L.GUIDE_QUEST, 46, 224, "name" }, { L.GUIDE_STATUS, 274, 54, "status" },
    { L.GUIDE_STARTS, 330, 150, "giver" }, { L.GUIDE_LOCATION, 484, 130, "location" },
}
local SORT_UP = " |TInterface\\Buttons\\Arrow-Up-Up:12:12:0:-2|t"
local SORT_DOWN = " |TInterface\\Buttons\\Arrow-Down-Up:12:12:0:2|t"

-- Click a column title to sort by it, again to reverse, a third time for the usual order, as on the
-- Roster. The choice carries across the quest lists until /reload.
local function ClickQuestSort(g, key)
    if g.sortKey ~= key then
        g.sortKey, g.sortDesc = key, false
    elseif not g.sortDesc then
        g.sortDesc = true
    else
        g.sortKey, g.sortDesc = nil, nil
    end
    g.quests.offset = 0
    UI.Dirty()
end

local function BuildQuestHeads(g, q)
    q.heads = {}
    for _, c in ipairs(QUEST_COLS) do
        local h = CreateFrame("Button", nil, q)
        h:SetPoint("TOPLEFT", c[2] - 2, -55)
        h:SetSize(c[3] + 4, 18)
        h.label = Text(h, c[1], "GameFontNormalSmall", 2, -4, c[3] + 2)
        h.key = c[4]
        h:SetScript("OnClick", function() ClickQuestSort(g, c[4]) end)
        h:SetScript("OnEnter", function(self)
            self.label:SetTextColor(1, 1, 1)
            if GameTooltip then
                GameTooltip:SetOwner(self, "ANCHOR_TOP")
                GameTooltip:AddLine(L.SORT_TIP, 1, 1, 1)
                GameTooltip:Show()
            end
        end)
        h:SetScript("OnLeave", function(self)
            self.label:SetTextColor(1, 0.82, 0)
            if GameTooltip then GameTooltip:Hide() end
        end)
        q.heads[#q.heads + 1] = h
    end
end

local function BuildQuests(g, parent)
    local q = CreateFrame("Frame", nil, parent)
    q:SetAllPoints()
    g.questPanel = q
    g.treeOpen = {}             -- per list, the storylines I've opened, kept while the game is running
    q.back = Button(q, L.BACK, 70, 0, -30, function()
        g.questKey = nil
        UI.Dirty()
    end, 22)
    q.title = Text(q, "", "GameFontNormalLarge", 82, -33, 500)
    q.clear = Button(q, L.GUIDE_CLEAR_PIN, 120, 616, -30, ClearPin, 22)
    q.entrance = Button(q, L.GUIDE_SHOW_ENTRANCE, 110, 396, -30, function()
        local e = g.questKey and ns.LevelGuide.Entrance(g.questKey)
        if e then ShowOnMap(e) end
    end, 22)
    q.dungeonMap = Button(q, L.GUIDE_DUNGEON_MAP, 100, 510, -30, function()
        local map = g.questKey and ns.LevelGuide.DungeonMap(g.questKey)
        if not map then return end
        g.questHint = not OpenMap(map) and L.GUIDE_ZONE_MAP_FAILED or nil
        UI.Dirty()
    end, 22)
    BuildQuestHeads(g, q)
    g.quests = RowList(q, 0, 736, -74, 22, 14, MakeQuestRow, FillQuestRow)
    q.empty = Text(q, L.GUIDE_NO_QUESTS, "GameFontDisableSmall", 6, -80, 700)
    q.hint = Text(q, "", "GameFontDisableSmall", 0, LIST_BOTTOM - 3, 580)

    -- No QuestieDB, or one we can't read: a clear notice in place of the list.
    local n = Box(q, 40, -84, 656, 264)
    q.notice = n
    n.icon = n:CreateTexture(nil, "ARTWORK")
    n.icon:SetSize(64, 64)
    n.icon:SetPoint("TOPLEFT", 22, -24)
    n.icon:SetTexture("Interface\\DialogFrame\\UI-Dialog-Icon-AlertNew")
    n.heading = Text(n, "", "GameFontNormalHuge", 104, -26, 530)
    n.text = Text(n, "", "GameFontHighlightLarge", 104, -66, 530)
    n.text:SetWordWrap(true)
    n.steps = Text(n, "", "GameFontHighlightLarge", 104, -122, 530)
    n.steps:SetWordWrap(true)
    n.steps:SetSpacing(5)
    n.footer = Text(n, L.GUIDE_QUEST_DATA_FOOTER, "GameFontNormalLarge", 104, -216, 530)
    n:Hide()
end

-- Status order, soonest to act on first: in my log, part done, ready, locked, finished.
local STATUS_ORDER = { log = 1, done = 2, locked = 4 }

-- What a storyline sorts by. It uses the quest I'm working towards whether it's open or closed, so
-- opening one never moves it. Nil = nothing to show, and those stay at the bottom either way.
local function SortValue(root, key, focus)
    if key == "level" then return root.level end
    if key == "name" then return root.name:lower() end
    if key == "status" then
        if root.doneCount == root.total then return 5 end
        return STATUS_ORDER[root.furthest] or 3
    end
    if key == "giver" and page.guide.treeKey == "bags" then
        local bag = ns.LevelGuide.BagFor(root)
        return bag and bag.slots or nil
    end
    local _, _, place = QuestPlace(focus)
    local text
    if key == "giver" then text = place.giver else text = ns.LevelGuide.MapName(place.map) end
    return text and text:lower() or nil
end

-- A quest tree as rows: a closed storyline is one row, an open one lists its steps in order.
-- Also returns how many quests and storylines, and the row of the first storyline not finished.
local function TreeRows(g, key)
    local roots, quests = ns.LevelGuide.QuestTree(key)
    local rows, firstOpen, open = {}, nil, g.treeOpen[key]
    local values, order, focusOf = {}, {}, {}
    for i, root in ipairs(roots) do
        local done, total, focus, furthest = ns.LevelGuide.ChainProgress(root)
        root.doneCount, root.total, root.furthest = done, total, furthest
        if total > 1 then root.summary = true end
        order[root], focusOf[root] = i, focus
        if g.sortKey then values[root] = SortValue(root, g.sortKey, focus) end
    end
    if g.sortKey then
        local desc = g.sortDesc
        table.sort(roots, function(a, b)
            local va, vb = values[a], values[b]
            if va ~= vb then
                if va == nil then return false end
                if vb == nil then return true end
                if desc then return va > vb end
                return va < vb
            end
            return order[a] < order[b]
        end)
    end
    for _, root in ipairs(roots) do
        local total = root.total
        if root.doneCount < total and not firstOpen then firstOpen = #rows + 1 end
        if total > 1 and not open[root.id] then
            root.focus = focusOf[root]
            rows[#rows + 1] = root
        else
            for _, node in ipairs(root.chain) do rows[#rows + 1] = node end
        end
    end
    return rows, quests, #roots, firstOpen
end

-- The quest list for a dungeon's key, "class" for my class quests, or "bags" for the bag quests.
local function RefreshQuests(g, key)
    local q, isBags = g.questPanel, key == "bags"
    local isClass = key == "class" or isBags        -- a page of its own, not one dungeon's list
    g.treeKey = key
    g.treeOpen[key] = g.treeOpen[key] or {}
    local list, quests, chains, firstOpen = TreeRows(g, key)
    -- Opening a list starts at the first storyline I haven't finished.
    if g.treeJump then
        g.treeJump = false
        g.quests.offset = (firstOpen or 1) - 1
    end
    if isBags then
        q.title:SetText(ns.GOLD .. L.GUIDE_BAGS_TITLE .. "|r  " .. ns.GREY .. "("
            .. string.format(L.GUIDE_BAGS_COUNT, quests, chains) .. ")|r")
    elseif isClass then
        q.title:SetText(ns.GOLD .. string.format(L.GUIDE_CLASS_TITLE, (UnitClass("player"))) .. "|r  "
            .. ns.GREY .. "(" .. string.format(L.GUIDE_CLASS_COUNT, quests, chains) .. ")|r")
    else
        local d = ns.Dungeons.BY_KEY[key]
        q.title:SetText(ns.GOLD .. d.name .. "|r  " .. ns.GREY .. "(" .. d.min .. "-" .. d.max .. ")|r")
    end
    q.back:SetShown(not isClass)
    q.title:ClearAllPoints()
    q.title:SetPoint("TOPLEFT", isClass and 0 or 82, -33)
    q.title:SetWidth(isClass and 600 or 310)    -- leaves room for the entrance and map buttons
    q.entrance:SetShown(not isClass and ns.LevelGuide.Entrance(key) ~= nil)
    q.dungeonMap:SetShown(not isClass and ns.LevelGuide.DungeonMap(key) ~= nil)
    q.empty:SetText((isBags and L.GUIDE_NO_BAGS) or (isClass and L.GUIDE_NO_CLASS_QUESTS) or L.GUIDE_NO_QUESTS)
    g.quests.Set(list)
    local heading, text, steps = ns.LevelGuide.QuestDataNote()
    q.notice:SetShown(heading ~= nil)
    if heading then
        q.notice.heading:SetText(heading)
        q.notice.text:SetText(text)
        q.notice.steps:SetText(steps)
    end
    for i, head in ipairs(q.heads) do
        head:SetShown(not heading)
        local label = (isBags and head.key == "giver") and L.GUIDE_BAG_COL or QUEST_COLS[i][1]
        head.label:SetText(label .. (head.key == g.sortKey and (g.sortDesc and SORT_DOWN or SORT_UP) or ""))
    end
    q.empty:SetShown(#list == 0 and not heading)
    q.clear:SetShown(pin ~= nil and pin.quest ~= nil)
    q.hint:SetShown(not heading)
    q.hint:SetText(g.questHint or L.GUIDE_QUEST_HINT)
end

---------------------------------------------------------------------------------------------------
-- The views

-- Show all / My level, on Zones and Dungeons. One choice for both, kept until /reload.
local function ShowAllButton(parent, g)
    return Button(parent, L.GUIDE_SHOW_ALL, 120, LIST_W - 120, -30, function()
        g.showAll = not g.showAll or nil
        g.zones.offset, g.dungeons.offset = 0, 0
        UI.Dirty()
    end, 22)
end

local function BuildZones(panel, p)
    local g = p.guide
    g.zoneTitle = UI.Header(panel, "", 0, -32, LIST_W)
    g.zoneAll = ShowAllButton(panel, g)
    Text(panel, L.GUIDE_ZONE, "GameFontDisableSmall", ZCOL.name[1], -53, ZCOL.name[2])
    Text(panel, L.GUIDE_RANGE, "GameFontDisableSmall", ZCOL.range[1], -53, ZCOL.range[2], "CENTER")
    Text(panel, L.GUIDE_BEST_AT, "GameFontDisableSmall", ZCOL.best[1], -53, ZCOL.best[2], "CENTER")
    Text(panel, L.GUIDE_FISHING, "GameFontDisableSmall", ZCOL.fish[1], -53, ZCOL.fish[2], "CENTER")
    g.zones = RowList(panel, 0, LIST_W, -68, 22, 14, MakeZoneRow, FillZoneRow)
    g.noZones = Text(panel, L.GUIDE_NO_ZONES, "GameFontDisableSmall", 6, -74, LIST_W - 12)
    g.zoneKey = Text(panel, "", "GameFontDisableSmall", 0, LIST_BOTTOM - 3, LIST_W)
end

local function RefreshZones(p)
    local g, level = p.guide, Level()
    g.zoneTitle:SetText(string.format(g.showAll and L.GUIDE_ALL_ZONES or L.GUIDE_ZONES_FOR, level))
    g.zoneAll:SetText(g.showAll and L.GUIDE_MY_LEVEL or L.GUIDE_SHOW_ALL)
    myFishing = ns.LevelGuide.MyFishing()
    local zones = ns.LevelGuide.Zones(level, g.showAll)
    g.zones.Set(zones)
    g.noZones:SetShown(#zones == 0)
    g.zoneKey:SetText(g.zoneHint or (ns.GREEN .. L.GUIDE_ZONE_KEY .. "|r  "
        .. (g.showAll and (ns.GREY .. L.GUIDE_OUTSIDE_KEY .. "|r  ") or "") .. L.GUIDE_ZONE_CLICK
        .. "  " .. L.GUIDE_FISH_KEY))
end

local function BuildDungeons(panel, p)
    local g = p.guide
    local lists = CreateFrame("Frame", nil, panel)
    lists:SetAllPoints()
    g.lists = lists
    g.dungeonTitle = UI.Header(lists, "", 0, -32, LIST_W)
    g.dungeonAll = ShowAllButton(lists, g)
    g.dungeons = RowList(lists, 0, LIST_W, -52, 36, 9, MakeDungeonRow, FillDungeonRow)
    g.noDungeons = Text(lists, "", "GameFontDisableSmall", 6, -58, LIST_W - 12)
    g.dungeonKey = Text(lists, "", "GameFontDisableSmall", 0, LIST_BOTTOM - 3, 560)
    BuildQuests(g, p)           -- on the page itself: Dungeons and Class quests share it
end

local function RefreshDungeons(p)
    local g = p.guide
    g.lists:SetShown(not g.questKey)
    if g.questKey then return end
    local level = Level()
    g.dungeonTitle:SetText(string.format(g.showAll and L.GUIDE_ALL_DUNGEONS or L.GUIDE_DUNGEONS_FOR, level))
    g.dungeonAll:SetText(g.showAll and L.GUIDE_MY_LEVEL or L.GUIDE_SHOW_ALL)
    g.dungeonKey:SetText(ns.GREEN .. L.GUIDE_READY .. "|r  " .. YELLOW .. L.GUIDE_TOUGH .. "|r"
        .. (g.showAll and ("  " .. ns.GREY .. L.GUIDE_OUTSIDE_KEY .. "|r") or ""))
    local dungeons = ns.LevelGuide.Dungeons(level, g.showAll)
    g.dungeons.Set(dungeons)
    g.noDungeons:SetShown(#dungeons == 0)
    if #dungeons == 0 then
        local first = ns.Dungeons.MyList()[1]
        g.noDungeons:SetText(first and level < first[3] and string.format(L.GUIDE_NO_DUNGEONS, first[3]) or "")
    end
end

---------------------------------------------------------------------------------------------------
-- Guide pages (Sleeping bag, Keys, Mounts): rows of steps with a status, and a click for the map.

local GUIDE_LOOK = {
    done = { ns.GREEN, 0.2, 0.85, 0.3, 0.30, L.GUIDE_DONE },
    log = { YELLOW, 1, 0.82, 0, 0.22, L.GUIDE_IN_LOG },
    next = { "|cff66bbff", 0.3, 0.6, 1, 0.18, L.GUIDE_NEXT },
}

local function GuideTip(self)
    self.hl:Show()
    local it = self.item
    if not it or not GameTooltip then return end
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:AddLine(it.tipName or it.name, 1, 1, 1)
    for _, line in ipairs(it.tip or {}) do GameTooltip:AddLine(line, 1, 0.82, 0, true) end
    if it.place then
        GameTooltip:AddLine(string.format(L.GUIDE_GO_TO, it.place.name))
        GameTooltip:AddLine(L.GUIDE_TIP_PIN, 0.25, 1, 0.25, true)
    end
    GameTooltip:Show()
end

local function MakeGuideRow(r)
    r.tint = r:CreateTexture(nil, "BACKGROUND", nil, 1)
    r.tint:SetAllPoints()
    r.tint:Hide()
    r.name = Text(r, "", "GameFontHighlightSmall", 6, -4, 480)
    r.state = Text(r, "", "GameFontNormalSmall", 490, -4, 110, "CENTER")
    r.map = Text(r, "", "GameFontNormalSmall", 606, -4, 124, "RIGHT")
    r.detail = Text(r, "", "GameFontDisableSmall", 6, -19, 724)
    r:SetScript("OnClick", function(self)
        local it = self.item
        if not it then return end
        if it.place then
            ShowOnMap(it.place)
        elseif it.zone and it.state ~= "done" then
            page.guide.questHint = not OpenMap(it.zone) and L.GUIDE_ZONE_MAP_FAILED or nil
            UI.Dirty()
        end
    end)
    r:SetScript("OnEnter", GuideTip)
    r:SetScript("OnLeave", function(self)
        self.hl:Hide()
        if GameTooltip then GameTooltip:Hide() end
    end)
end

local function FillGuideRow(r, it)
    local look = GUIDE_LOOK[it.state]
    r.tint:SetShown(look ~= nil)
    if look then r.tint:SetColorTexture(look[2], look[3], look[4], look[5]) end
    r.name:SetText(it.name)
    r.state:SetText((look and look[1] or ns.GREY) .. (it.stateText or (look and look[6]) or "") .. "|r")
    r.detail:SetText(it.detail or "")
    local pinned = it.place and pin and pin.quest and pin.quest.id == it.place.id
    r.map:SetText((pinned and (ns.GREEN .. L.GUIDE_PINNED .. "|r")) or (it.place and L.GUIDE_SHOW_MAP)
        or (it.zone and it.state ~= "done" and L.GUIDE_OPEN_ZONE) or "")
end

-- A view of guide rows. read() returns the rows, the title and the note under the list.
local function GuideView(key, read)
    local function Build(panel, p)
        local v = {}
        p.guide[key] = v
        v.title = UI.Header(panel, "", 0, -32, LIST_W)
        v.clear = Button(panel, L.GUIDE_CLEAR_PIN, 120, LIST_W - 120, -30, ClearPin, 22)
        v.list = RowList(panel, 0, LIST_W, -52, 36, 9, MakeGuideRow, FillGuideRow)
        v.hint = Text(panel, "", "GameFontDisableSmall", 0, LIST_BOTTOM - 3, 580)
    end
    local function Refresh(p)
        local v, g = p.guide[key], p.guide
        local rows, title, hint = read()
        v.title:SetText(title)
        v.list.Set(rows)
        v.hint:SetText(g.questHint or hint)
        v.clear:SetShown(pin ~= nil and pin.quest ~= nil)
    end
    return Build, Refresh
end

local BuildSleep, RefreshSleep = GuideView("sleeping", function()
    local rows, done, total = ns.LevelExtras.SleepingBag()
    return rows, string.format(L.GUIDE_SLEEP_TITLE, done, total), done == total and L.GUIDE_SLEEP_DONE or L.GUIDE_SLEEP_HINT
end)
local BuildKeys, RefreshKeys = GuideView("keys", function()
    local rows, have, total = ns.LevelExtras.Keys()
    return rows, string.format(L.GUIDE_KEYS_TITLE, have, total), L.GUIDE_KEYS_HINT
end)
local BuildMounts, RefreshMounts = GuideView("mounts", function()
    return ns.LevelExtras.Mounts(Level()), L.GUIDE_MOUNTS_TITLE, L.GUIDE_MOUNTS_HINT
end)

-- The row of views, left to right. To add one: a build(panel, page), an optional refresh(page), a line here.
local VIEWS = {
    { key = "zones", label = L.GUIDE_TAB_ZONES, build = BuildZones, refresh = RefreshZones },
    { key = "dungeons", label = L.TAB_DUNGEONS, build = BuildDungeons, refresh = RefreshDungeons },
    { key = "class", label = L.GUIDE_TAB_CLASS, build = function() end },    -- draws in the shared quest list
    { key = "bags", label = L.GUIDE_TAB_BAGS, build = function() end },      -- draws in the shared quest list
    { key = "sleeping", label = L.GUIDE_TAB_SLEEPING, build = BuildSleep, refresh = RefreshSleep },
    { key = "keys", label = L.GUIDE_TAB_KEYS, build = BuildKeys, refresh = RefreshKeys },
    { key = "mounts", label = L.GUIDE_TAB_MOUNTS, build = BuildMounts, refresh = RefreshMounts },
}

---------------------------------------------------------------------------------------------------

local function SelectView(p, key)
    local g = p.guide
    if UI.LevelingView() ~= key then
        g.quests.offset, g.questHint = 0, nil
        g.treeJump = true
    end
    p.view, g.zoneHint = key, nil
    UI.Dirty()
end

-- The dev console: open one of the views.
function UI.LevelingShow(key)
    if not page then UI.Open("leveling") end
    SelectView(page, key)
end

local function Build(p)
    page = p
    p.guide, p.panels, p.viewButtons = {}, {}, {}
    -- Side by side at the top left; the open one has the gold line, like the main tabs.
    for i, v in ipairs(VIEWS) do
        local panel = CreateFrame("Frame", nil, p)
        panel:SetAllPoints()
        p.panels[v.key] = panel
        v.build(panel, p)
        local b = Button(p, v.label, 100, (i - 1) * 105, 0, function() SelectView(p, v.key) end, 24)
        b.viewSel = b:CreateTexture(nil, "OVERLAY")
        b.viewSel:SetColorTexture(1, 0.82, 0, 1)
        b.viewSel:SetPoint("BOTTOMLEFT", 8, 2)
        b.viewSel:SetPoint("BOTTOMRIGHT", -8, 2)
        b.viewSel:SetHeight(2)
        p.viewButtons[v.key] = b
    end
end

-- Coming to this tab from another opens the view for my level, at the top of the lists. Closing the
-- window for the map and coming back doesn't count, so the quest list is still there.
local function OnEnter(p)
    local g = p.guide
    p.view, g.questKey, g.questHint, g.zoneHint = nil, nil, nil, nil
    g.zones.offset, g.dungeons.offset = 0, 0
end

local function Refresh(p)
    local view = UI.LevelingView()
    for _, v in ipairs(VIEWS) do
        local open = v.key == view
        local b = p.viewButtons[v.key]
        p.panels[v.key]:SetShown(open)
        if open then b:LockHighlight() else b:UnlockHighlight() end
        b.viewSel:SetShown(open)
        if open and v.refresh then v.refresh(p) end
    end
    local g = p.guide
    local questKey = ((view == "class" or view == "bags") and view) or (view == "dungeons" and g.questKey) or nil
    g.questPanel:SetShown(questKey ~= nil)
    if questKey then RefreshQuests(g, questKey) end
end

UI.AddPage("leveling", Build, Refresh, OnEnter)

-- The Raids tab: the raid roster, coming soon.
UI.AddPage("raids", function(p)
    UI.raidsPage = p
    p.box = Box(p, 0, 0, LIST_W, 220)
    p.title = Text(p.box, ns.GOLD .. L.RAID_ROSTER .. "|r", "GameFontNormalLarge", 12, -12, 500)
    p.soon = Text(p.box, L.COMING_SOON, "GameFontHighlight", 12, -40, 500)
    p.text = Text(p.box, L.RAID_SOON_TEXT, "GameFontHighlightSmall", 12, -66, 700)
    p.text:SetWordWrap(true)
    p.text:SetHeight(110)
    p.text:SetJustifyV("TOP")
end)
