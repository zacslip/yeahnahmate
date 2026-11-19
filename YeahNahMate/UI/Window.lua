-- The main window: title, tabs, pages, footer. Built the first time it opens.
-- Escape is handled on our own frame (OnKeyDown); never UISpecialFrames or the panel functions,
-- which taint Blizzard's UI on Forever (CONTRIBUTING.md, Forever's rules).
local ADDON, ns = ...
local L = ns.L
local UI = ns.UI

local W, H = 760, 552               -- the guild header adds 52 to the mock-up's 500

-- Tabs in order (Calendar before Dungeons; Legends; a GM tab), each as wide as its
-- word so twelve fit in one row (12 + widths + 4 between = 724 of 760). The GM tab only shows for the guild master and their managers.
-- Each page file calls UI.AddPage(key, build, refresh).
local function Managing() return ns.Board ~= nil and ns.Board.CanManage() end
local TABS = {
    { "home", L.TAB_HOME, 46 }, { "roster", L.TAB_ROSTER, 52 }, { "clans", L.TAB_CLANS, 50 },
    { "calendar", L.TAB_CALENDAR, 64 }, { "dungeons", L.TAB_DUNGEONS, 68 }, { "professions", L.TAB_PROFESSIONS, 80 },
    { "ask", L.TAB_ASK, 38 }, { "legends", L.TAB_LEGENDS, 62 }, { "streamers", L.TAB_STREAMERS, 70 },
    { "info", L.TAB_INFO, 38 }, { "gm", L.TAB_GM, 36, Managing }, { "settings", L.TAB_SETTINGS, 64 },
}

local pages = {}                -- key -> { build, refresh, frame }
local frame, title, foot, tabButtons, header
local current = "home"
local dirty = false

function UI.AddPage(key, build, refresh)
    pages[key] = { build = build, refresh = refresh }
end

-- The title bar is small and just says what this is; the guild gets the big header below it.
local function TitleText()
    return ns.GREY .. L.ADDON .. "|r"
end

-- The guild's banner across the top: crest, the guild's name big and gold, and how it's going.
local FACTION = {
    Horde = { nil, 0.55, 0.08, 0.06 },
    Alliance = { nil, 0.10, 0.22, 0.55 },
}

local function BuildHeader()
    header = CreateFrame("Frame", nil, frame)
    header:SetPoint("TOPLEFT", 10, -26)
    header:SetPoint("TOPRIGHT", -10, -26)
    header:SetHeight(52)
    header.bg = header:CreateTexture(nil, "BACKGROUND")
    header.bg:SetAllPoints()
    header.bg:SetColorTexture(0, 0, 0, 0.55)
    header.tint = header:CreateTexture(nil, "BORDER")
    header.tint:SetPoint("TOPLEFT")
    header.tint:SetPoint("BOTTOMLEFT")
    header.tint:SetWidth(260)
    header.line = header:CreateTexture(nil, "ARTWORK")
    header.line:SetPoint("BOTTOMLEFT")
    header.line:SetPoint("BOTTOMRIGHT")
    header.line:SetHeight(2)
    header.line:SetColorTexture(0.9, 0.76, 0.36, 0.8)
    header.crest = header:CreateTexture(nil, "ARTWORK")
    -- The whole crest, as big as the header allows: the image's empty edges are trimmed off so the
    -- crest itself fills the 50 px above the gold line.
    header.crest:SetSize(48, 50)
    header.crest:SetPoint("TOPLEFT", 6, 0)
    header.crest:SetTexCoord(0.068, 0.932, 0.068, 0.968)
    header.name = header:CreateFontString(nil, "OVERLAY", "GameFontNormalHuge")
    header.name:SetPoint("TOPLEFT", 62, -6)
    header.name:SetJustifyH("LEFT")
    header.info = header:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    header.info:SetPoint("TOPLEFT", 64, -34)
    header.info:SetJustifyH("LEFT")
    header.me = header:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    header.me:SetPoint("TOPRIGHT", -10, -10)
    header.me:SetJustifyH("RIGHT")
    header.ver = header:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    header.ver:SetPoint("TOPRIGHT", -10, -30)
    header.ver:SetJustifyH("RIGHT")
end

local function RefreshHeader()
    local faction = UnitFactionGroup and UnitFactionGroup("player")
    local f = FACTION[faction] or FACTION.Horde
    header.crest:SetTexture(UI.CREST)        -- the guild's own crest; the faction only picks the tint
    -- A fade from the faction's colour into the dark banner (a plain tint where gradients aren't available).
    header.tint:SetColorTexture(1, 1, 1, 1)
    local faded = header.tint.SetGradient and CreateColor and pcall(header.tint.SetGradient, header.tint, "HORIZONTAL",
        CreateColor(f[2], f[3], f[4], 0.55), CreateColor(f[2], f[3], f[4], 0))
    if not faded then header.tint:SetColorTexture(f[2], f[3], f[4], 0.3) end
    local g = ns.Guild.name
    header.name:SetText(g and (ns.GOLD .. g .. "|r") or (ns.GREY .. L.NO_GUILD_TITLE .. "|r"))
    if g then
        local members, online, addon = 0, 0, 0
        for _, m in ipairs(ns.Guild.list) do
            if not m.sim then
                members = members + 1
                if m.online then online = online + 1 end
                if ns.Comm.users[m.name] then addon = addon + 1 end
            end
        end
        header.info:SetText(string.format(L.HEADER_INFO, members, online, addon))
    else
        header.info:SetText(L.HEADER_NO_GUILD)
    end
    local myRank = ns.Guild.myRank and ns.Guild.Get(ns.me) and ns.Guild.Get(ns.me).rank or nil
    header.me:SetText((ns.me or "") .. (myRank and myRank ~= "" and (ns.GREY .. "  " .. myRank .. "|r") or ""))
    if ns.Comm.newest then
        -- say plainly what they have and what to update to (orange, top right).
        header.ver:SetText("|cffff8040" .. string.format(L.NEWER_SHORT, ns.VERSION, ns.Comm.newest) .. "|r")
    else
        header.ver:SetText(L.ADDON .. " v" .. ns.VERSION)
    end
end

local function FootText()
    if ns.Sim and ns.Sim.IsOn() and not ns.Sim.shots then return "|cffff8040" .. L.SIM_FOOT .. "|r" end
    return L.FOOT_TIP
end

-- Place the tabs that show, left to right.
local function LayoutTabs()
    local x = 12
    for _, t in ipairs(TABS) do
        local b = tabButtons[t[1]]
        local on = not t[4] or t[4]()
        b:SetShown(on)
        if on then
            b:ClearAllPoints()
            b:SetPoint("TOPLEFT", x, -82)
            x = x + t[3] + 4
        end
    end
end

-- Redraw the page that's showing (and the title and footer).
local function RefreshNow()
    dirty = false
    if not frame or not frame:IsShown() then return end
    LayoutTabs()
    for _, t in ipairs(TABS) do
        if t[1] == current and t[4] and not t[4]() then UI.Select("home") return end
    end
    title:SetText(TitleText())
    RefreshHeader()
    foot:SetText(FootText())
    local p = pages[current]
    if p and p.refresh and p.frame then p.refresh(p.frame) end
end

-- Something changed (a click, a guildie's news): redraw soon, at most a few times a second, and
-- only while the window shows.
local function RefreshLater() ns.Safe(RefreshNow) end
function UI.Dirty()
    if dirty or not frame or not frame:IsShown() then return end
    dirty = true
    C_Timer.After(0.25, RefreshLater)
end
-- Guildies' dots moving: at most one redraw a second. Positions arrive several times a second in
-- a busy guild, and redrawing for each one was garbage for nothing (a dot only moves every 15 s).
local slowDirty = false
local function SlowRefresh()
    slowDirty = false
    UI.Dirty()
end
function UI.DirtySlow()
    if slowDirty or dirty or not frame or not frame:IsShown() then return end
    slowDirty = true
    C_Timer.After(1, SlowRefresh)
end

-- Pages without a tab of their own, and the tab they belong under (it stays lit while they show).
local UNDER = { breakdown = "home" }

function UI.Select(key)
    if not pages[key] then key = "home" end
    current = key
    local tab = UNDER[key] or key
    for k, b in pairs(tabButtons) do
        if k == tab then b:LockHighlight(); b.sel:Show() else b:UnlockHighlight(); b.sel:Hide() end
    end
    for k, p in pairs(pages) do
        if p.frame then p.frame:SetShown(k == key) end
    end
    RefreshNow()
end

local function SavePosition()
    local point, _, relPoint, x, y = frame:GetPoint()
    local w = ns.db.window
    w.point, w.relPoint, w.x, w.y = point, relPoint, x, y
end

local function PlaceWindow()
    frame:ClearAllPoints()
    local w = ns.db and ns.db.window
    if w and w.point then
        frame:SetPoint(w.point, UIParent, w.relPoint or w.point, w.x or 0, w.y or 0)
    else
        frame:SetPoint("CENTER")
    end
end

local function Build()
    frame = CreateFrame("Frame", "YeahNahMateFrame", UIParent, "BasicFrameTemplateWithInset")
    frame:SetSize(W, H)
    frame:SetFrameStrata("DIALOG")
    -- with other addons' windows open, parts of ours drew over theirs and parts under
    -- (windows in the same strata mix by frame level). A top-level window lifts itself and
    -- everything in it above the others when it's clicked or opened, so it's never half-covered.
    frame:SetToplevel(true)             -- (opening it raises it too: the OnShow below)
    frame:SetClampedToScreen(true)
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        SavePosition()
    end)
    frame:Hide()
    PlaceWindow()

    -- Escape closes, handled here (see the top of the file).
    frame:EnableKeyboard(true)
    frame:SetPropagateKeyboardInput(true)
    UI.PlainClose(frame)
    -- In combat the game doesn't let addons change whether keys pass through, so Escape still closes
    -- the window there but the game also sees that press (it may clear your target).
    frame:SetScript("OnKeyDown", function(self, key)
        if InCombatLockdown() then
            if key == "ESCAPE" then self:Hide() end
            return
        end
        if key == "ESCAPE" then
            self:SetPropagateKeyboardInput(false)
            self:Hide()
        else
            self:SetPropagateKeyboardInput(true)
        end
    end)
    -- Escape turns key pass-through off for that one press; turn it back on as soon as the window
    -- is hidden, so a window opened later (even in combat, when it can't be changed) never eats keys.
    frame:SetScript("OnHide", function(self)
        C_Timer.After(0, function()
            if not InCombatLockdown() then self:SetPropagateKeyboardInput(true) end
        end)
    end)
    frame:SetScript("OnShow", function(self)
        self:Raise()
        if not InCombatLockdown() then self:SetPropagateKeyboardInput(true) end
        ns.Guild.Request()
        UI.Select(current)
    end)

    title = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    title:SetPoint("TOP", 0, -6)
    BuildHeader()

    tabButtons = {}
    for i, t in ipairs(TABS) do
        local key = t[1]
        local b = UI.Button(frame, t[2], t[3], 12 + (i - 1) * 60, -82, function() UI.Select(key) end, 24)
        b.sel = b:CreateTexture(nil, "OVERLAY")
        b.sel:SetColorTexture(1, 0.82, 0, 1)
        b.sel:SetPoint("BOTTOMLEFT", 8, 2)
        b.sel:SetPoint("BOTTOMRIGHT", -8, 2)
        b.sel:SetHeight(2)
        b.sel:Hide()
        tabButtons[key] = b
    end

    local content = CreateFrame("Frame", nil, frame)
    content:SetPoint("TOPLEFT", 12, -114)
    content:SetPoint("BOTTOMRIGHT", -12, 28)

    local function BuildPage(p)
        p.frame = CreateFrame("Frame", nil, content)
        p.frame:SetAllPoints()
        p.frame:Hide()
        p.build(p.frame)
    end
    for _, t in ipairs(TABS) do
        if pages[t[1]] then BuildPage(pages[t[1]]) end
    end
    for key in pairs(UNDER) do
        if pages[key] and not pages[key].frame then BuildPage(pages[key]) end
    end

    foot = frame:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    foot:SetPoint("BOTTOMLEFT", 14, 10)

    -- The voice drawer on the left edge (UI/Voice.lua).
    if UI.BuildVoiceDrawer then UI.BuildVoiceDrawer(frame) end
end

function UI.Toggle()
    if not frame then Build() end
    if frame:IsShown() then frame:Hide() else frame:Show() end
end

function UI.Open(key)
    if not frame then Build() end
    if key then current = key end
    if frame:IsShown() then UI.Select(current) else frame:Show() end
end

function UI.ResetPosition()
    if ns.db then wipe(ns.db.window) end
    if frame then PlaceWindow() end
end

ns.Listen("ROSTER", UI.DirtySlow)
ns.Listen("USERS", UI.DirtySlow)
ns.Listen("SETTINGS", UI.Dirty)
ns.Listen("STATUS", UI.DirtySlow)
ns.Listen("POSITIONS", UI.DirtySlow)
ns.Listen("CALENDAR", UI.Dirty)
ns.Listen("BOARD", UI.Dirty)
ns.Listen("GATHER", UI.Dirty)

function YeahNahMate_OnAddonCompartmentClick() ns.Safe(UI.Toggle) end
