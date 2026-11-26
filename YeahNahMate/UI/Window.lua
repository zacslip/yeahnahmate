-- The main window: title, tabs, pages, footer. Built the first time it opens.
-- Escape is handled on our own frame (OnKeyDown); never UISpecialFrames or the panel functions,
-- which taint Blizzard's UI on Forever (CONTRIBUTING.md, Forever's rules).
local ADDON, ns = ...
local L = ns.L
local UI = ns.UI

local W, H = 760, 552               -- the guild header adds 52 to the mock-up's 500

-- Tabs in order (Calendar before Dungeons; Legends; a GM tab), each as wide as its
-- word so twelve fit in one row (12 + widths + 4 between = 724 of 760). The GM tab only shows for the guild master and their managers.
-- Settings has no tab: it opens from the gear in the header. The last tab's name follows my level (UI/Leveling.lua).
-- Each page file calls UI.AddPage(key, build, refresh).
local function Managing() return ns.Board ~= nil and ns.Board.CanManage() end
local TABS = {
    { "home", L.TAB_HOME, 46 }, { "roster", L.TAB_ROSTER, 52 }, { "clans", L.TAB_CLANS, 50 },
    { "calendar", L.TAB_CALENDAR, 64 }, { "dungeons", L.TAB_DUNGEONS, 68 }, { "professions", L.TAB_PROFESSIONS, 76 },
    { "ask", L.TAB_ASK, 38 }, { "legends", L.TAB_LEGENDS, 62 }, { "streamers", L.TAB_STREAMERS, 70 },
    { "info", L.TAB_INFO, 38 }, { "gm", L.TAB_GM, 36, Managing }, { "leveling", L.TAB_LEVELING, 64 },
    { "raids", L.TAB_RAIDS, 48 },
}

local pages = {}                -- key -> { build, refresh, frame }
local frame, title, foot, tabButtons, header, gear
local current = "home"
local beforeSettings = "home"   -- the gear's second click goes back here
local entered                   -- the page last moved to (for onEnter)
local dirty = false

-- onEnter (optional) runs when the player moves to this page from another one, not when the window
-- is closed and opened again on the same page.
function UI.AddPage(key, build, refresh, onEnter)
    pages[key] = { build = build, refresh = refresh, onEnter = onEnter }
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
    header.ver:SetPoint("TOPRIGHT", -60, -30)     -- room on its right for the About "i" and the Settings gear
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

-- The Settings gear, right of the "i". One click opens Settings, another goes back to where I was.
local function BuildGear()
    gear = CreateFrame("Button", nil, header)
    gear:SetSize(20, 20)
    if UI.aboutButton then
        gear:SetPoint("LEFT", UI.aboutButton, "RIGHT", 4, 0)
    else
        gear:SetPoint("TOPRIGHT", -10, -28)
    end
    local icon = gear:CreateTexture(nil, "ARTWORK")
    icon:SetAllPoints()
    icon:SetTexture("Interface\\Icons\\INV_Misc_Gear_01")
    icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)    -- trims the icon's square border
    gear:SetHighlightTexture("Interface\\Buttons\\UI-Common-MouseHilight", "ADD")
    gear.sel = gear:CreateTexture(nil, "OVERLAY")
    gear.sel:SetColorTexture(1, 0.82, 0, 1)
    gear.sel:SetPoint("TOPLEFT", gear, "BOTTOMLEFT", 0, -1)
    gear.sel:SetPoint("TOPRIGHT", gear, "BOTTOMRIGHT", 0, -1)
    gear.sel:SetHeight(2)
    gear.sel:Hide()
    gear:SetScript("OnClick", function()
        UI.Select(current == "settings" and beforeSettings or "settings")
    end)
    gear:SetScript("OnEnter", function(self)
        if not GameTooltip then return end
        GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
        GameTooltip:AddLine(L.TAB_SETTINGS, 1, 1, 1)
        GameTooltip:AddLine(L.GEAR_TIP, nil, nil, nil, true)
        GameTooltip:Show()
    end)
    gear:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
    UI.settingsButton = gear
end

-- Show on map: the window stays open but drops behind the world map, and comes back when the map closes.
-- Only our own frame's layer changes. The map is only looked at, never touched or hooked.
local behindMap = false
local MAP_CHECK, MAP_OPEN_WAIT = 0.2, 1     -- how often to look; how long the map gets to appear

local function ComeBack(raise)
    if not behindMap then return end
    behindMap = false
    if frame then
        frame:SetFrameStrata("DIALOG")
        if raise then frame:Raise() end
    end
end

function UI.IsBehindMap() return behindMap end

function UI.SendBehindMap()
    if not frame or not frame:IsShown() or not WorldMapFrame then return false end
    frame:SetFrameStrata("LOW")
    local run = {}
    behindMap = run
    local waited, seen = 0, false
    local function Look()
        if behindMap ~= run then return end     -- already back, or a newer trip to the map
        if WorldMapFrame:IsShown() then
            seen = true
        elseif seen or waited >= MAP_OPEN_WAIT then
            ComeBack(true)
            return
        end
        waited = waited + MAP_CHECK
        C_Timer.After(MAP_CHECK, function() ns.Safe(Look) end)
    end
    C_Timer.After(MAP_CHECK, function() ns.Safe(Look) end)
    return true
end

local function FootText()
    if ns.Sim and ns.Sim.IsOn() and not ns.Sim.shots then return "|cffff8040" .. L.SIM_FOOT .. "|r" end
    return L.FOOT_TIP
end

-- Place the tabs that show, left to right, across the whole row. Each is as wide as its own label (as the
-- game measures it) plus a margin, and what's left of the row is shared out evenly, so no label runs off
-- its button and short ones (Ask, Info) don't take room they don't need. If they still don't fit (a long
-- translation, a big UI font), the labels step down a font size. Without a measure (offline tests) the
-- fixed widths in TABS are used.
local TAB_GAP, TAB_MARGIN, TAB_ROW = 2, 12, W - 24
local function TabFont(b, small)
    if not b.SetNormalFontObject or not GameFontNormalSmall then return end
    b:SetNormalFontObject(small and GameFontNormalSmall or GameFontNormal)
    b:SetHighlightFontObject(small and GameFontHighlightSmall or GameFontHighlight)
    b:SetDisabledFontObject(small and GameFontDisableSmall or GameFontDisable)
end
local shown, widths, laidOut = {}, {}, nil     -- reused: the row is laid out again only when its tabs change
local function TabWidths()
    local total = 0
    for i, s in ipairs(shown) do
        local tw = s.b.GetTextWidth and s.b:GetTextWidth()
        widths[i] = (tw and tw > 0) and math.ceil(tw) + TAB_MARGIN or s.t[3]
        total = total + widths[i]
    end
    return total
end
-- Lay the row out again on the next redraw even if the same tabs show (labels changed size).
function UI.TabsChanged() laidOut = nil end
local function LayoutTabs()
    local mask, n = 0, 0
    for i, t in ipairs(TABS) do
        local b = tabButtons[t[1]]
        local on = not t[4] or t[4]()
        b:SetShown(on)
        if on then
            mask = mask + 2 ^ i
            n = n + 1
            local s = shown[n] or {}
            s.t, s.b = t, b
            shown[n] = s
        end
    end
    for i = #shown, n + 1, -1 do shown[i] = nil end
    if mask == laidOut then return end
    laidOut = mask
    local room = TAB_ROW - TAB_GAP * (#shown - 1)
    for _, s in ipairs(shown) do TabFont(s.b, false) end
    local total = TabWidths()
    if total > room then
        for _, s in ipairs(shown) do TabFont(s.b, true) end
        total = TabWidths()
    end
    -- share what's left (or, still too wide, take it back) evenly; the last tab ends at the row's end
    local extra = math.floor((room - total) / #shown)
    local x = 12
    for i, s in ipairs(shown) do
        local w = widths[i] + extra
        if i == #shown then w = 12 + TAB_ROW - x end
        s.b:SetWidth(w)
        s.b:ClearAllPoints()
        s.b:SetPoint("TOPLEFT", x, -82)
        x = x + w + TAB_GAP
    end
end

-- An edit box of ours that still has the keyboard while it can't be seen (its page or the window was
-- hidden while you were typing in it) takes every key, so / and Enter no longer open the game's chat.
-- Let go of it: always when it can't be seen, and with all set, also when it can (the window closing).
-- Only ever our own boxes (inside the window); the game's chat box is never touched.
function UI.FreeKeyboard(all)
    local f = GetCurrentKeyBoardFocus and GetCurrentKeyBoardFocus()
    if not f or not frame or not f.ClearFocus then return false end
    local o, ours = f, false
    for _ = 1, 30 do
        if not o then break end
        if o == frame then ours = true break end
        o = o.GetParent and o:GetParent() or nil
    end
    if not ours then return false end
    if all or not (f.IsVisible and f:IsVisible()) then
        f:ClearFocus()
        return true
    end
    return false
end

-- Redraw the page that's showing (and the title and footer).
local function RefreshNow()
    dirty = false
    if not frame or not frame:IsShown() then return end
    UI.FreeKeyboard(false)
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
-- Settings belongs to the gear, so no tab is lit while it shows.
local UNDER = { breakdown = "home", settings = "gear" }

function UI.Select(key)
    if not pages[key] then key = "home" end
    if key == "settings" and current ~= "settings" then beforeSettings = current end
    current = key
    local tab = UNDER[key] or key
    for k, b in pairs(tabButtons) do
        if k == tab then b:LockHighlight(); b.sel:Show() else b:UnlockHighlight(); b.sel:Hide() end
    end
    if gear then gear.sel:SetShown(key == "settings") end
    for k, p in pairs(pages) do
        if p.frame then p.frame:SetShown(k == key) end
    end
    UI.FreeKeyboard(false)          -- typing on the page just hidden: let go of the keyboard
    if key ~= entered then
        entered = key
        if pages[key].onEnter and pages[key].frame then pages[key].onEnter(pages[key].frame) end
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
        -- Behind the map, every key is the map's and the game's: Escape closes the map, not this.
        if behindMap then
            if not InCombatLockdown() then self:SetPropagateKeyboardInput(true) end
            return
        end
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
        UI.FreeKeyboard(true)
        ComeBack(false)
        C_Timer.After(0, function()
            if not InCombatLockdown() then self:SetPropagateKeyboardInput(true) end
        end)
    end)
    -- A fight about to start: make sure keys pass through now, while that can still be changed. (If
    -- Escape closed the window just before, the switch back after it may not have run yet; the
    -- window opened again in the fight would then eat every key, chat included.)
    ns.OnEvent("PLAYER_REGEN_DISABLED", function()
        if frame and not InCombatLockdown() then frame:SetPropagateKeyboardInput(true) end
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
    -- The "i" left of the version: commands and help (UI/About.lua).
    if UI.BuildAbout then UI.BuildAbout(frame, header) end
    BuildGear()

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

    -- The Recruiters drawer on the right edge, by the version (UI/Recruit.lua).
    if UI.BuildRecruitDrawer then UI.BuildRecruitDrawer(frame) end
end

function UI.Toggle()
    if not frame then Build() end
    if behindMap then           -- /ynm while it's behind the map: bring it to the front
        ComeBack(true)
        return
    end
    if frame:IsShown() then frame:Hide() else frame:Show() end
end

-- Is the window open on this page right now?
function UI.Showing(key) return frame ~= nil and frame:IsShown() and current == key end

function UI.Open(key)
    if not frame then Build() end
    ComeBack(true)
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
