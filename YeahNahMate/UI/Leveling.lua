-- The Leveling / Raids tab. Before the level cap it opens on the leveling guide (zones and dungeons
-- for my level and faction), at the cap on the raid roster (coming soon). Both are always one click away.
local _, ns = ...
local L = ns.L
local UI = ns.UI
local Text, Button, Box, Row = UI.Text, UI.Button, UI.Box, UI.Row

local MAX_LEVEL = 60
local YELLOW = "|cffffd100"
local ORANGE = "|cffff8040"
local ZONE_W, DUNGEON_X, DUNGEON_W = 350, 366, 370
local LIST_BOTTOM = -388        -- where the pagers and colour keys sit
local PIN_REF = "YeahNahMateGuide"
local Pins = LibStub("HereBeDragons-Pins-2.0")
local page, pin
local newLevel                  -- from PLAYER_LEVEL_UP: UnitLevel can still say the old level then

local function Level()
    return UI.levelingPretend or newLevel or UnitLevel("player") or 1
end

local function DefaultView()
    return Level() >= MAX_LEVEL and "raids" or "leveling"
end

function UI.LevelingTabName()
    return DefaultView() == "raids" and L.TAB_RAIDS or L.TAB_LEVELING
end

-- The view showing now, for the page and the dev console.
function UI.LevelingView()
    return page and page.view or DefaultView()
end

-- Back to the view that suits my level.
local function ResetView()
    if page then page.view = nil end
    UI.Dirty()
end

-- Dev console: see the tab as another level (nil = my real level).
function UI.SetLevelingPretend(level)
    UI.levelingPretend = level
    if page then page.guide.questKey = nil end
    ResetView()
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
    ResetView()
end)

-- Taking or handing in a quest updates In log / Done, only while a quest list is on screen.
local function QuestsChanged()
    if page and page:IsVisible() and page.guide.questKey then UI.DirtySlow() end
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
-- Zones (left) and dungeons (right)

local function MakeZoneRow(r)
    r.name = Text(r, "", "GameFontHighlightSmall", 6, -5, 190)
    r.range = Text(r, "", "GameFontHighlightSmall", 196, -5, 54, "CENTER")
    r.best = Text(r, "", "GameFontHighlightSmall", 254, -5, 90, "CENTER")
end

local function FillZoneRow(r, z)
    local colour = z.best and ns.GREEN or ""
    r.name:SetText(colour .. z.name .. "|r")
    r.range:SetText(z.min .. "-" .. z.max)
    r.best:SetText(colour .. z.bestMin .. "-" .. z.bestMax .. "|r")
end

local TAGS = { key = L.GUIDE_TAG_KEY, attune = L.GUIDE_TAG_ATTUNE, item = L.GUIDE_TAG_ITEM, enemy = L.GUIDE_TAG_ENEMY }

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
    GameTooltip:AddLine(L.GUIDE_TIP_CLICK, 0.25, 1, 0.25)
    GameTooltip:Show()
end

-- Open a dungeon's quest list.
function UI.LevelingOpenDungeon(key)
    if not page then UI.Open("leveling") end
    page.view = "leveling"
    page.guide.questKey = key
    page.guide.quests.offset = 0
    page.guide.questHint = nil
    UI.Dirty()
end

local function MakeDungeonRow(r)
    r:SetScript("OnClick", function(self)
        if self.item then UI.LevelingOpenDungeon(self.item.key) end
    end)
    r.name = Text(r, "", "GameFontHighlightSmall", 6, -4, 200)
    r.tag = Text(r, "", "GameFontNormalSmall", 206, -4, 104, "RIGHT")
    r.range = Text(r, "", "GameFontHighlightSmall", 314, -4, 50, "RIGHT")
    r.info = Text(r, "", "GameFontDisableSmall", 6, -19, 190)
    r.where = Text(r, "", "GameFontDisableSmall", 196, -19, 168, "RIGHT")
    r:SetScript("OnEnter", DungeonTip)
    r:SetScript("OnLeave", function(self)
        self.hl:Hide()
        if GameTooltip then GameTooltip:Hide() end
    end)
end

local function FillDungeonRow(r, d)
    r.name:SetText((d.ready and ns.GREEN or YELLOW) .. d.name .. "|r")
    r.tag:SetText(d.tag and TAGS[d.tag] or "")
    r.range:SetText(d.min .. "-" .. d.max)
    r.info:SetText(string.format(d.top and L.GUIDE_TOP_BOSS_LINE or L.GUIDE_BOSS_LINE, d.boss, d.best))
    r.where:SetText(d.where or "")
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

local function PlacePin(q)
    if not pin then
        pin = CreateFrame("Button", nil, UIParent)
        pin:SetSize(24, 24)
        local icon = pin:CreateTexture(nil, "OVERLAY")
        icon:SetAllPoints()
        icon:SetTexture("Interface\\GossipFrame\\AvailableQuestIcon")
        pin:SetScript("OnEnter", PinTip)
        pin:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
        pin:SetScript("OnClick", ClearPin)
        pin:Hide()
    elseif pin.quest then
        Pins:RemoveWorldMapIcon(PIN_REF, pin)
    end
    pin.quest = q
    Pins:AddWorldMapIconMap(PIN_REF, pin, q.map, q.x / 100, q.y / 100, HBD_PINS_WORLDMAP_SHOW_CONTINENT)
end

function UI.LevelingPinnedQuest() return pin and pin.quest end

-- A click: pin where it starts and open the map there, with this window waiting behind it. The game's
-- own call, never in combat. If it can't open, the pin is still there for when the player presses M.
local function ShowOnMap(q)
    local g = page.guide
    PlacePin(q)
    local opened = false
    if not InCombatLockdown() and C_Map and C_Map.OpenWorldMap then
        opened = pcall(C_Map.OpenWorldMap, q.map)
    end
    if opened then
        g.questHint = nil
        UI.SendBehindMap()
        UI.Dirty()              -- the row now says Pinned
    else
        g.questHint = L.GUIDE_PINNED_PRESS_M
        UI.Dirty()
    end
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
    if self.locked then
        GameTooltip:AddLine(string.format(L.GUIDE_NEEDS, place.name), 1, 0.5, 0.25, true)
    end
    if place.giver then GameTooltip:AddLine(string.format(L.GUIDE_STARTS_WITH, place.giver)) end
    if self.plan then AddChain(self.plan) end
    GameTooltip:AddLine(" ")
    GameTooltip:AddLine((not place.map and L.GUIDE_NO_MAP_TIP) or (self.locked and L.GUIDE_TIP_NEXT) or L.GUIDE_TIP_MAP,
        0.25, 1, 0.25, true)
    GameTooltip:Show()
end

local function MakeQuestRow(r)
    r.level = Text(r, "", "GameFontHighlightSmall", 6, -5, 34, "CENTER")
    r.name = Text(r, "", "GameFontHighlightSmall", 46, -5, 290)
    r.state = Text(r, "", "GameFontNormalSmall", 340, -5, 70, "CENTER")
    r.giver = Text(r, "", "GameFontDisableSmall", 414, -5, 190)
    r.map = Text(r, "", "GameFontNormalSmall", 604, -5, 126, "RIGHT")
    r:SetScript("OnClick", function(self)
        if self.place and self.place.map then ShowOnMap(self.place) end
    end)
    r:SetScript("OnEnter", QuestTip)
    r:SetScript("OnLeave", function(self)
        self.hl:Hide()
        if GameTooltip then GameTooltip:Hide() end
    end)
end

local function FillQuestRow(r, q)
    local state = ns.LevelGuide.QuestState(q)
    local plan = ns.LevelGuide.QuestPlan(q)
    -- Not started: the place to go is the next quest in the chain. Started or done: this quest's own.
    local place = state and q or plan.target
    local locked = not state and plan.locked
    r.plan, r.place, r.locked = plan, place, locked
    r.level:SetText(q.level)
    r.name:SetText(state == "done" and (ns.GREY .. q.name .. "|r") or q.name)
    r.state:SetText((state == "log" and (YELLOW .. L.GUIDE_IN_LOG .. "|r"))
        or (state == "done" and (ns.GREEN .. L.GUIDE_DONE .. "|r"))
        or (locked and (ORANGE .. L.GUIDE_LOCKED .. "|r")) or "")
    r.giver:SetText(locked and (ORANGE .. string.format(L.GUIDE_NEEDS, place.name) .. "|r") or place.giver or "")
    local pinned = pin and pin.quest and pin.quest.id == place.id
    r.map:SetText((pinned and (ns.GREEN .. L.GUIDE_PINNED .. "|r"))
        or (place.map and (locked and L.GUIDE_SHOW_NEXT or L.GUIDE_SHOW_MAP))
        or (ns.GREY .. L.GUIDE_NO_MAP .. "|r"))
end

local function BuildQuests(g)
    local q = CreateFrame("Frame", nil, g)
    q:SetAllPoints()
    g.questPanel = q
    q.back = Button(q, L.BACK, 70, 0, -30, function()
        g.questKey = nil
        UI.Dirty()
    end, 22)
    q.title = Text(q, "", "GameFontNormalLarge", 82, -33, 500)
    q.clear = Button(q, L.GUIDE_CLEAR_PIN, 120, 616, -30, ClearPin, 22)
    q.heads = {
        Text(q, L.GUIDE_LEVEL, "GameFontDisableSmall", 6, -59, 34, "CENTER"),
        Text(q, L.GUIDE_QUEST, "GameFontDisableSmall", 46, -59, 300),
        Text(q, L.GUIDE_STATUS, "GameFontDisableSmall", 340, -59, 70, "CENTER"),
        Text(q, L.GUIDE_STARTS, "GameFontDisableSmall", 414, -59, 190),
    }
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

local function RefreshQuests(g)
    local q, d = g.questPanel, ns.Dungeons.BY_KEY[g.questKey]
    q.title:SetText(ns.GOLD .. d.name .. "|r  " .. ns.GREY .. "(" .. d.min .. "-" .. d.max .. ")|r")
    local list = ns.LevelGuide.Quests(g.questKey)
    g.quests.Set(list)
    local heading, text, steps = ns.LevelGuide.QuestDataNote()
    q.notice:SetShown(heading ~= nil)
    if heading then
        q.notice.heading:SetText(heading)
        q.notice.text:SetText(text)
        q.notice.steps:SetText(steps)
    end
    for _, head in ipairs(q.heads) do head:SetShown(not heading) end
    q.empty:SetShown(#list == 0 and not heading)
    q.clear:SetShown(pin ~= nil and pin.quest ~= nil)
    q.hint:SetShown(not heading)
    q.hint:SetText(g.questHint or L.GUIDE_QUEST_HINT)
end

local function BuildGuide(p)
    local g = CreateFrame("Frame", nil, p)
    g:SetAllPoints()
    p.guide = g
    local lists = CreateFrame("Frame", nil, g)
    lists:SetAllPoints()
    g.lists = lists
    g.zoneTitle = UI.Header(lists, "", 0, -32, ZONE_W)
    Text(lists, L.GUIDE_ZONE, "GameFontDisableSmall", 6, -53, 190)
    Text(lists, L.GUIDE_RANGE, "GameFontDisableSmall", 196, -53, 54, "CENTER")
    Text(lists, L.GUIDE_BEST_AT, "GameFontDisableSmall", 254, -53, 90, "CENTER")
    g.zones = RowList(lists, 0, ZONE_W, -68, 22, 14, MakeZoneRow, FillZoneRow)
    g.noZones = Text(lists, L.GUIDE_NO_ZONES, "GameFontDisableSmall", 6, -74, ZONE_W - 12)
    Text(lists, ns.GREEN .. L.GUIDE_ZONE_KEY .. "|r", "GameFontDisableSmall", 0, LIST_BOTTOM - 3, 200)

    g.dungeonTitle = UI.Header(lists, "", DUNGEON_X, -32, DUNGEON_W)
    g.dungeons = RowList(lists, DUNGEON_X, DUNGEON_W, -52, 36, 9, MakeDungeonRow, FillDungeonRow)
    g.noDungeons = Text(lists, "", "GameFontDisableSmall", DUNGEON_X + 6, -58, DUNGEON_W - 12)
    Text(lists, ns.GREEN .. L.GUIDE_READY .. "|r  " .. YELLOW .. L.GUIDE_TOUGH .. "|r", "GameFontDisableSmall",
        DUNGEON_X, LIST_BOTTOM - 3, 220)
    BuildQuests(g)
end

local function RefreshGuide(g)
    g.lists:SetShown(not g.questKey)
    g.questPanel:SetShown(g.questKey ~= nil)
    if g.questKey then
        RefreshQuests(g)
        return
    end
    local level = Level()
    g.zoneTitle:SetText(string.format(L.GUIDE_ZONES_FOR, level))
    g.dungeonTitle:SetText(string.format(L.GUIDE_DUNGEONS_FOR, level))
    local zones, dungeons = ns.LevelGuide.Zones(level), ns.LevelGuide.Dungeons(level)
    g.zones.Set(zones)
    g.dungeons.Set(dungeons)
    g.noZones:SetShown(#zones == 0)
    g.noDungeons:SetShown(#dungeons == 0)
    if #dungeons == 0 then
        local first = ns.Dungeons.MyList()[1]
        g.noDungeons:SetText(first and level < first[3] and string.format(L.GUIDE_NO_DUNGEONS, first[3]) or "")
    end
end

---------------------------------------------------------------------------------------------------

local function Build(p)
    page = p
    -- The two views, side by side at the top left; the open one has the gold line, like the main tabs.
    p.viewButtons = {}
    for i, v in ipairs({ { "leveling", L.LEVELING_GUIDE }, { "raids", L.RAID_ROSTER } }) do
        local b = Button(p, v[2], 120, (i - 1) * 124, 0, function()
            p.view = v[1]
            UI.Dirty()
        end, 24)
        b.viewSel = b:CreateTexture(nil, "OVERLAY")
        b.viewSel:SetColorTexture(1, 0.82, 0, 1)
        b.viewSel:SetPoint("BOTTOMLEFT", 8, 2)
        b.viewSel:SetPoint("BOTTOMRIGHT", -8, 2)
        b.viewSel:SetHeight(2)
        p.viewButtons[v[1]] = b
    end
    BuildGuide(p)
    p.box = Box(p, 0, -30, 736, 220)
    p.title = Text(p.box, ns.GOLD .. L.RAID_ROSTER .. "|r", "GameFontNormalLarge", 12, -12, 500)
    p.soon = Text(p.box, L.COMING_SOON, "GameFontHighlight", 12, -40, 500)
    p.text = Text(p.box, L.RAID_SOON_TEXT, "GameFontHighlightSmall", 12, -66, 700)
    p.text:SetWordWrap(true)
    p.text:SetHeight(110)
    p.text:SetJustifyV("TOP")
end

-- Coming to this tab from another opens the view for my level, at the top of the lists. Closing the
-- window for the map and coming back doesn't count, so the quest list is still there.
local function OnEnter(p)
    local g = p.guide
    p.view, g.questKey, g.questHint = nil, nil, nil
    g.zones.offset, g.dungeons.offset = 0, 0
end

local function Refresh(p)
    local view = UI.LevelingView()
    p.guide:SetShown(view == "leveling")
    p.box:SetShown(view == "raids")
    if view == "leveling" then RefreshGuide(p.guide) end
    for key, b in pairs(p.viewButtons) do
        if key == view then b:LockHighlight() else b:UnlockHighlight() end
        b.viewSel:SetShown(key == view)
    end
end

UI.AddPage("leveling", Build, Refresh, OnEnter)
