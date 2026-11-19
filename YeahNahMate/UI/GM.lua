-- GM tab: only the guild master and the managers they name see it (Window.lua hides
-- the tab for everyone else). Hidden isn't secret: the list itself goes to the guild like the guild
-- info does (Board.lua), so every client can check who may edit.
-- Sidebar: Edit guild info on top, then three cards: Managers (the guild master names
-- managers from a picker and picks which ranks may also edit; a manager sees the list), Milestones
-- and Welcome (GMMilestones.lua). What managers can do: a button by the Managers title.
local ADDON, ns = ...
local L = ns.L
local UI = ns.UI
local Text, Button, Row = UI.Text, UI.Button, UI.Row
local RX, RW = UI.RX, UI.RW

local ROWS = 8
local VIEW_NAMES = { L.GM_VIEW_MANAGERS, L.GM_VIEW_MODERATORS, L.GM_VIEW_MILESTONES, L.GM_VIEW_WELCOME }
local MS_VIEW, WEL_VIEW, MOD_VIEW = 3, 4, 2

local function MemberName(name)
    local m = ns.Guild.Get(name)
    return m and UI.Name(m, true) or name
end

local BuildPicker
-- The picker: guildies by rank (top ranks first), a name search, [Make manager] on each.
local PICK_ROWS = 10
local TOP_RANKS = 3            -- "Top ranks": the guild's first three ranks (GM, officers, ...)

local function PickList(p)
    local B = ns.Board
    local mg = {}
    for _, n in ipairs(B.Managers()) do mg[n] = true end
    local ranks = B.Ranks()
    local cut = ranks[math.min(#ranks, TOP_RANKS)]
    cut = cut and cut.index or 99
    local find = strlower(strtrim(p.search and p.search:GetText() or ""))
    local list = {}
    for _, m in ipairs(ns.Guild.list) do
        if not m.sim and m.name ~= ns.me
            and (find ~= "" or p.pickAll or (m.rankIndex or 99) <= cut)
            and (find == "" or strlower(m.name):find(find, 1, true)) then
            list[#list + 1] = m
        end
    end
    table.sort(list, function(a, b)
        if (a.rankIndex or 99) ~= (b.rankIndex or 99) then return (a.rankIndex or 99) < (b.rankIndex or 99) end
        if a.online ~= b.online then return a.online == true end
        return a.name < b.name
    end)
    return list, mg
end

BuildPicker = function(p, v)
    local f = CreateFrame("Frame", nil, v)
    f:SetAllPoints()
    f:Hide()
    p.picker = f
    Text(f, L.GM_PICK_HEAD, "GameFontNormal", RX + 4, -32, 300)
    p.pickShow = UI.Choice(f, { L.GM_PICK_TOP, L.GM_PICK_ALL }, RX + 4, -54, { 96, 96 }, function(i)
        p.pickAll = i == 2; p.pickOffset = 0; UI.Dirty()
    end)
    p.pickShow(1)
    p.search = CreateFrame("EditBox", nil, f, "InputBoxTemplate")
    p.search:SetSize(170, 22)
    p.search:SetPoint("TOPLEFT", RX + 214, -54)
    p.search:SetAutoFocus(false)
    p.search:SetMaxLetters(40)
    p.search:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    p.search:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
    p.searchHint = Text(f, L.GM_PICK_SEARCH, "GameFontDisableSmall", RX + 218, -59, 160)
    p.search:SetScript("OnTextChanged", function(self)
        p.searchHint:SetShown((self:GetText() or "") == "")
        p.pickOffset = 0
        UI.Dirty()
    end)
    p.pickDone = Button(f, L.GM_PICK_DONE, 80, RW + RX - 84, -54, function()
        p.picking = false; p.search:SetText(""); p.search:ClearFocus(); UI.Dirty()
    end)
    p.pickRows = {}
    for i = 1, PICK_ROWS do
        local r = Row(f, RX, -86 - (i - 1) * 26, RW, 24)
        r.name = Text(r, "", "GameFontHighlight", 8, -5, 200)
        r.rank = Text(r, "", "GameFontHighlightSmall", 212, -6, 130)
        r.level = Text(r, "", "GameFontDisableSmall", 346, -6, 60)
        r.add = Button(r, L.GM_MAKE_MANAGER, 120, RW - 124, -1, function()
            if not r.who then return end
            local ok, err = ns.Board.SetManager(r.who, true)
            if not ok then ns.Print(err == "full" and string.format(L.GM_ADD_FULL, ns.Board.MAX_MANAGERS) or L.GM_ADD_NOBODY) end
        end, 22)
        r.is = Text(r, "", "GameFontHighlightSmall", RW - 124, -6, 116, "CENTER")
        p.pickRows[i] = r
    end
    p.pickNone = Text(f, L.GM_PICK_NONE, "GameFontDisableSmall", RX + 8, -92, RW - 16)
    p.pickOffset = 0
    p.pickPager = UI.Pager(f, 594, -352, function(d) p.pickOffset = math.max(0, p.pickOffset + d * PICK_ROWS); UI.Dirty() end)
    f:EnableMouseWheel(true)
    f:SetScript("OnMouseWheel", function(_, d) p.pickOffset = math.max(0, p.pickOffset - d); UI.Dirty() end)
end

local function RefreshPicker(p)
    local list, mg = PickList(p)
    local off = math.min(p.pickOffset, math.max(0, #list - PICK_ROWS))
    p.pickOffset = off
    p.pickNone:SetShown(#list == 0)
    p.pickPager.Set(off + 1, math.min(#list, off + PICK_ROWS), #list)
    for i, r in ipairs(p.pickRows) do
        local m = list[off + i]
        r.who = m and m.name
        if m then
            r.name:SetText(UI.Name(m, true))
            r.rank:SetText(m.rank or "")
            r.level:SetText(m.level and (L.COL_LEVEL .. " " .. m.level) or "")
            r.add:SetShown(not mg[m.name])
            r.is:SetText(mg[m.name] and (ns.GREEN .. L.GM_IS_MANAGER .. "|r") or "")
            r.stripe:SetColorTexture(1, 1, 1, (i % 2 == 0) and 0.04 or 0)
            r:Show()
        else
            r:Hide()
        end
    end
end

local function BuildManagers(p)
    local v = CreateFrame("Frame", nil, p)
    v:SetAllPoints()
    p.mgrView = v
    p.intro = Text(v, "", "GameFontDisableSmall", RX + 4, -28, RW - 8)
    p.intro:SetWordWrap(true)
    p.intro:SetHeight(30)
    p.intro:SetJustifyV("TOP")

    -- Guild master: "Add a manager" opens a list of guildies to pick from (no typing
    -- names; it's nearly always an officer, so the top ranks show first).
    p.addBtn = Button(v, L.GM_ADD_PICK, 150, RX + 4, -62, function() p.picking = true; p.pickOffset = 0; UI.Dirty() end)
    BuildPicker(p, v)
    p.rows = {}
    for i = 1, ROWS do
        local r = Row(v, RX, -94 - (i - 1) * 26, RW, 24)
        r.name = Text(r, "", "GameFontHighlight", 8, -5, 260)
        r.rank = Text(r, "", "GameFontDisableSmall", 270, -6, 160)
        r.remove = Button(r, L.GM_REMOVE, 80, RW - 84, -1, function()
            if r.who then ns.Board.SetManager(r.who, false) end
        end, 22)
        p.rows[i] = r
    end
    p.none = Text(v, L.GM_NONE, "GameFontDisableSmall", RX + 8, -100, RW - 16)
    p.offset = 0
    p.pager = UI.Pager(v, 594, -300, function(d) p.offset = math.max(0, p.offset + d * ROWS); UI.Dirty() end)
end

-- Moderators: tick which ranks moderate each tab. One row per guild rank (the guild
-- master's always ticked), one column per tab; the column heading's tooltip says what they can do.
-- A second page on the same view (the switch at the top right): Clan leaders, which guild rank
-- leads each clan (Clans.lua).
local MOD_ORDER = { "cal", "dun", "prof", "ask", "strm", "info", "clan" }
local MOD_ROWS = 10
local COL_W = 56

-- The clans a rank can lead: my faction's races, and any other race seen in the guild.
local FACTION_RACES = { Horde = { "Orc", "Troll", "Tauren", "Scourge" }, Alliance = { "Human", "Dwarf", "NightElf", "Gnome" } }
local function ClanChoices()
    local out, seen = {}, {}
    local faction = UnitFactionGroup and UnitFactionGroup("player")
    for _, r in ipairs(FACTION_RACES[faction] or FACTION_RACES.Horde) do out[#out + 1] = r; seen[r] = true end
    for _, c in ipairs((ns.Clans.List())) do
        if not seen[c.race] then out[#out + 1] = c.race; seen[c.race] = true end
    end
    return out
end

local function BuildClanRanks(p, v)
    local f = CreateFrame("Frame", nil, v)
    f:SetAllPoints()
    f:Hide()
    p.clanRanks = f
    local intro = Text(f, L.GM_CLAN_INTRO, "GameFontDisableSmall", RX + 4, -28, RW - 8)
    intro:SetWordWrap(true)
    intro:SetHeight(28)
    intro:SetJustifyV("TOP")
    p.clanMenu = UI.PickMenu(f, 170, 12)
    p.clanRows = {}
    for i = 1, MOD_ROWS do
        local r = Row(f, RX, -62 - (i - 1) * 26, RW, 24)
        r.name = Text(r, "", "GameFontHighlightSmall", 8, -6, 180)
        r.pick = Button(r, "", 170, 196, -1, nil, 22)
        r.pick:SetScript("OnClick", function(self)
            if not r.index or not ns.Clans.CanLinkRanks() then return end
            local races = ClanChoices()
            local items = { L.GM_CLAN_NO }
            for _, race in ipairs(races) do items[#items + 1] = string.format(L.CLAN_NAME, ns.Clans.RaceName(race)) end
            p.clanMenu.Open(self, items, function(k)
                if k == 1 then
                    local cur = ns.Clans.RaceForRank(r.index)
                    if cur then ns.Clans.SetRank(cur, nil) end
                else
                    ns.Clans.SetRank(races[k - 1], r.index)
                end
                UI.Dirty()
            end)
        end)
        r.pick:SetScript("OnEnter", function(self)
            if not GameTooltip then return end
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:AddLine(L.GM_CLAN_TIP, 1, 1, 1, true)
            GameTooltip:Show()
        end)
        r.pick:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
        r.warn = Text(r, "", "GameFontHighlightSmall", 374, -6, RW - 380)
        p.clanRows[i] = r
    end
end

local function RefreshClanRanks(p)
    local B, Cl = ns.Board, ns.Clans
    local can = Cl.CanLinkRanks()
    local holders = {}
    for _, m in ipairs(ns.Guild.list) do
        if not m.sim and m.rankIndex then holders[m.rankIndex] = (holders[m.rankIndex] or 0) + 1 end
    end
    local ranks = B.Ranks()
    for i, r in ipairs(p.clanRows) do
        local rk = ranks[i]
        r.index = rk and rk.index
        if rk then
            r.name:SetText(rk.name ~= "" and rk.name or ("#" .. rk.index))
            local race = Cl.RaceForRank(rk.index)
            r.pick:SetShown(rk.index ~= 0)
            r.pick:SetEnabled(can)
            r.pick:SetText((race and string.format(L.GM_CLAN_PICK, Cl.RaceName(race)) or (ns.GREY .. L.GM_CLAN_NONE .. "|r")) .. "  v")
            local n = holders[rk.index] or 0
            r.warn:SetText((race and n > 1) and ("|cffff8040" .. string.format(L.GM_CLAN_TWO, rk.name, n) .. "|r") or "")
            r.stripe:SetColorTexture(1, 1, 1, (i % 2 == 0) and 0.04 or 0)
            r:Show()
        else
            r:Hide()
        end
    end
end

local function BuildModerators(p)
    local holder = CreateFrame("Frame", nil, p)
    holder:SetAllPoints()
    p.modView = holder
    p.modSub = 1
    p.modSwitch = UI.Choice(holder, { L.GM_RANKS_MOD, L.GM_RANKS_CLANS }, RX + RW - 212, 0, { 100, 108 }, function(i)
        p.modSub = i
        UI.Dirty()
    end)
    p.modSwitch(1)
    BuildClanRanks(p, holder)
    local v = CreateFrame("Frame", nil, holder)
    v:SetAllPoints()
    p.modTicks = v
    local intro = Text(v, L.GM_MOD_INTRO, "GameFontDisableSmall", RX + 4, -28, RW - 8)
    intro:SetWordWrap(true)
    intro:SetHeight(28)
    intro:SetJustifyV("TOP")
    local x0 = RX + 150
    p.modHeads = {}
    for j, tab in ipairs(MOD_ORDER) do
        local h = CreateFrame("Frame", nil, v)
        h:SetPoint("TOPLEFT", x0 + (j - 1) * COL_W, -60)
        h:SetSize(COL_W, 18)
        h.text = Text(h, L.TAB_NAME[tab], "GameFontNormalSmall", 0, -2, COL_W, "CENTER")
        h:EnableMouse(true)
        h:SetScript("OnEnter", function(self)
            if not GameTooltip then return end
            GameTooltip:SetOwner(self, "ANCHOR_TOP")
            GameTooltip:AddLine(L.TAB_NAME[tab])
            GameTooltip:AddLine(L.MOD_TAB_TIP[tab], 1, 1, 1, true)
            GameTooltip:Show()
        end)
        h:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
        p.modHeads[j] = h
    end
    p.modRows = {}
    for i = 1, MOD_ROWS do
        local r = Row(v, RX, -80 - (i - 1) * 24, RW, 22)
        r.name = Text(r, "", "GameFontHighlightSmall", 8, -5, 140)
        r.boxes = {}
        for j, tab in ipairs(MOD_ORDER) do
            local box = UI.Check(r, "", x0 - RX + (j - 1) * COL_W + COL_W / 2 - 12, 1, false, function(on)
                if r.index then ns.Board.SetRankModerates(tab, r.index, on) end
            end)
            r.boxes[tab] = box
        end
        p.modRows[i] = r
    end
    p.modTip = Text(v, L.GM_MOD_TIP, "GameFontDisableSmall", RX + 4, -326, RW - 8)
    p.modTip:SetWordWrap(true)
    p.modTip:SetHeight(40)
    p.modTip:SetJustifyV("TOP")
end

local function RefreshModerators(p)
    p.modTicks:SetShown(p.modSub ~= 2)
    p.clanRanks:SetShown(p.modSub == 2)
    if p.modSub == 2 then RefreshClanRanks(p) return end
    local B = ns.Board
    local ranks = B.Ranks()
    local can = B.CanSetRank()
    for i, r in ipairs(p.modRows) do
        local rk = ranks[i]
        r.index = rk and rk.index
        if rk then
            r.name:SetText((rk.name ~= "" and rk.name or ("#" .. rk.index)))
            for _, tab in ipairs(MOD_ORDER) do
                local box = r.boxes[tab]
                box:SetChecked(B.RankModerates(tab, rk.index))
                box:SetEnabled(can and rk.index ~= 0)
            end
            r.stripe:SetColorTexture(1, 1, 1, (i % 2 == 0) and 0.04 or 0)
            r:Show()
        else
            r:Hide()
        end
    end
end

-- What managers can do (next to the Managers title, not its own card): hover or click.
local function BuildPowers(p)
    local b = Button(p.mgrView, L.GM_POWERS_BTN, 170, RX + 110, -2, nil, 20)
    p.powersBtn = b
    local function Show(self)
        if not GameTooltip then return end
        GameTooltip:SetOwner(self, "ANCHOR_BOTTOMRIGHT")
        GameTooltip:AddLine(L.GM_VIEW_POWERS)
        GameTooltip:AddLine(L.GM_POWERS, 1, 1, 1, true)
        GameTooltip:Show()
    end
    b:SetScript("OnEnter", Show)
    b:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
    b:SetScript("OnClick", Show)
end

-- Milestones and Welcome: built in GMMilestones.lua.
local function BuildMilestones(p)
    local v = CreateFrame("Frame", nil, p)
    v:SetAllPoints()
    p.milestonesView = v
    UI.GMBuildMilestones(p, v)
    local w = CreateFrame("Frame", nil, p)
    w:SetAllPoints()
    p.welcomeView = w
    UI.GMBuildWelcome(p, w)
end

local function Build(p)
    p.view = 1
    function p.pickView(i) p.view = i; p.picking = false; p.msEdit = nil; p.welT = nil; UI.Dirty() end
    -- Sidebar: cards like the other tabs. Edit guild info on top; Managers and
    -- Milestones as cards.
    p.editInfo = Button(p, L.GM_EDIT_INFO, UI.SIDE_W, 0, 0, function() UI.EditInfo() end, 34)
    if p.editInfo.SetNormalFontObject and GameFontNormalLarge then p.editInfo:SetNormalFontObject(GameFontNormalLarge) end
    local icons = { "Interface\\GroupFrame\\UI-Group-LeaderIcon", "Interface\\GroupFrame\\UI-Group-MainTankIcon",
                    "Interface\\Icons\\INV_Banner_02", "Interface\\Icons\\INV_Misc_Note_01" }
    p.viewCards = {}
    for i, name in ipairs(VIEW_NAMES) do
        p.viewCards[i] = UI.SideBox(p, -46 - (i - 1) * 72, icons[i], name, function() p.pickView(i) end)
    end
    local foot = Text(p, L.GM_SIDE_FOOT, "GameFontDisableSmall", 0, -46 - #VIEW_NAMES * 72 - 4, UI.SIDE_W)
    foot:SetWordWrap(true)
    foot:SetHeight(76)
    foot:SetJustifyV("TOP")
    p.viewTitle = UI.ViewTitle(p, 400)
    BuildManagers(p)
    BuildModerators(p)
    BuildMilestones(p)
    BuildPowers(p)
end

local function Refresh(p)
    local B = ns.Board
    local gm = B.CanSetRank()
    local list = B.Managers()
    for i, c in ipairs(p.viewCards) do c.SetPicked(i == p.view) end
    local cm = p.viewCards[1]
    cm.text:SetText(#list > 0 and string.format(L.GM_CARD_MANAGERS, #list) or (ns.GREY .. L.GM_NONE .. "|r"))
    local isGM = B.ShownGuildMaster()
    cm.pts:SetText(isGM and L.GM_YOU_GM_TIP or L.GM_YOU_MANAGER_TIP)
    local MS = ns.Milestones
    local nCards, nOn = #MS.List(), MS.ActiveCount()
    local nRanks = 0
    for _, rk in ipairs(B.Ranks()) do if rk.index ~= 0 and B.RankModeratesAny(rk.index) then nRanks = nRanks + 1 end end
    p.viewCards[MOD_VIEW].text:SetText(string.format(nRanks == 1 and L.GM_CARD_MOD_ONE or L.GM_CARD_MOD, nRanks))
    p.viewCards[MOD_VIEW].pts:SetText(L.GM_CARD_MOD_TIP)
    p.viewCards[MS_VIEW].text:SetText(nCards == 0 and (ns.GREY .. L.GM_CARD_MILESTONES_NONE .. "|r") or string.format(L.MS_CARD_ACTIVE, nOn))
    p.viewCards[MS_VIEW].pts:SetText(L.GM_CARD_MILESTONES_TIP)
    p.viewCards[MS_VIEW].SetActive(nOn > 0)
    local wel = MS.Welcome()
    p.viewCards[WEL_VIEW].text:SetText(wel.on and (ns.GREEN .. L.MS_CARD_WEL_ON .. "|r") or (ns.GREY .. L.MS_CARD_WEL_OFF .. "|r"))
    p.viewCards[WEL_VIEW].pts:SetText(L.MS_CARD_WEL_TIP)
    p.viewCards[WEL_VIEW].SetActive(wel.on)
    p.viewTitle:SetText(VIEW_NAMES[p.view])
    p.mgrView:SetShown(p.view == 1)
    p.modView:SetShown(p.view == MOD_VIEW)
    p.milestonesView:SetShown(p.view == MS_VIEW)
    p.welcomeView:SetShown(p.view == WEL_VIEW)
    if p.view == MOD_VIEW then RefreshModerators(p) return end
    if p.view == MS_VIEW then UI.GMRefreshMilestones(p) return end
    if p.view == WEL_VIEW then UI.GMRefreshWelcome(p) return end

    -- Picking someone to add: the picker takes the whole view.
    p.picking = p.picking and gm or false
    p.picker:SetShown(p.picking)
    for _, w in ipairs({ p.intro, p.addBtn, p.none, p.powersBtn }) do w:SetShown(not p.picking) end
    if p.picking then
        p.pager.Set(1, 0, 0)
        for _, r in ipairs(p.rows) do r:Hide() end
        p.viewTitle:SetText(L.GM_ADD_PICK)
        RefreshPicker(p)
        return
    end
    p.intro:SetText(isGM and L.GM_INTRO_GM or L.GM_INTRO_MANAGER)
    p.addBtn:SetShown(gm)
    local off = math.min(p.offset, math.max(0, #list - ROWS))
    p.offset = off
    p.none:SetShown(#list == 0)
    p.pager.Set(off + 1, math.min(#list, off + ROWS), #list)
    for i, r in ipairs(p.rows) do
        local name = list[off + i]
        r.who = name
        if name then
            local m = ns.Guild.Get(name)
            r.name:SetText(MemberName(name))
            r.rank:SetText(m and m.rank or "")
            r.remove:SetShown(gm)
            r.stripe:SetColorTexture(1, 1, 1, (i % 2 == 0) and 0.04 or 0)
            r:Show()
        else
            r:Hide()
        end
    end

end

UI.AddPage("gm", Build, Refresh)
