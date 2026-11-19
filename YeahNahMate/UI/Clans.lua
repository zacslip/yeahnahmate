-- Clans tab: every clan side by side (Clans.lua), one list each: the clan's name, how many (online),
-- its leader; then its members, online first, each with their role badges on the left and their name
-- in class colour (offline ones grey). Mouse wheel scrolls a list. Hover a name for the usual guildie
-- tooltip. Along the bottom: My roles (Tank / Healer / DPS, up to two).
-- Being built bit by bit (PLAN Phase 12): clan meetings and challenges come next.
local ADDON, ns = ...
local L = ns.L
local UI = ns.UI
local Text, Button, Row = UI.Text, UI.Button, UI.Row

local COLS = 5
local COL_W, GAP = 140, 9            -- 5 x 140 + 4 x 9 = 736, the whole page
local COL_H = 372
local ROW_H = 17
local ROWS = 17
local LEADER_ICON = "|TInterface\\GroupFrame\\UI-Group-LeaderIcon:12:12|t"
local ROLE_NAME = { t = L.ROLE_TANK, h = L.ROLE_HEALER, d = L.ROLE_DPS }

local function BuildColumn(p, i)
    local x = (i - 1) * (COL_W + GAP)
    local c = UI.Box(p, x, 0, COL_W, COL_H)
    c.offset = 0
    c.title = Text(c, "", "GameFontNormal", 8, -8, COL_W - 16)
    c.count = Text(c, "", "GameFontDisableSmall", 8, -26, COL_W - 16)
    c.leader = Text(c, "", "GameFontHighlightSmall", 8, -41, COL_W - 16)
    local line = c:CreateTexture(nil, "ARTWORK")
    line:SetColorTexture(0.9, 0.76, 0.36, 0.5)
    line:SetPoint("TOPLEFT", 6, -57)
    line:SetSize(COL_W - 12, 1)
    c.rows = {}
    local function Wheel(_, d)
        c.offset = math.max(0, c.offset - d * 3)
        UI.Dirty()
    end
    c:EnableMouseWheel(true)
    c:SetScript("OnMouseWheel", Wheel)
    for j = 1, ROWS do
        local r = Row(c, 4, -61 - (j - 1) * ROW_H, COL_W - 8, ROW_H - 1)
        r.roles = Text(r, "", "GameFontHighlightSmall", 2, -1, 32)
        r.name = Text(r, "", "GameFontHighlightSmall", 34, -2, COL_W - 44)
        r:SetScript("OnEnter", function(self)
            self.hl:Show()
            if self.m then UI.MemberTooltip(self, self.m) end
        end)
        r:SetScript("OnLeave", function(self)
            self.hl:Hide()
            if GameTooltip then GameTooltip:Hide() end
        end)
        r:EnableMouseWheel(true)
        r:SetScript("OnMouseWheel", Wheel)
        c.rows[j] = r
    end
    c.empty = Text(c, L.CLAN_EMPTY, "GameFontDisableSmall", 8, -64, COL_W - 16)
    c.empty:SetWordWrap(true)
    c.empty:SetHeight(42)
    c.empty:SetJustifyV("TOP")
    c.shown = Text(c, "", "GameFontDisableSmall", 8, -61 - ROWS * ROW_H - 2, COL_W - 16, "RIGHT")
    return c
end

local function Build(p)
    p.cols = {}
    for i = 1, COLS do p.cols[i] = BuildColumn(p, i) end

    -- My roles, along the bottom.
    local y = -COL_H - 8
    Text(p, ns.GOLD .. L.CLAN_MY_ROLES .. "|r", "GameFontNormalSmall", 4, y - 6, 70)
    p.roleBtns = {}
    local bw, bx = { t = 60, h = 70, d = 56 }, { t = 74, h = 138, d = 212 }
    for _, r in ipairs(ns.Clans.ROLES) do
        local b = Button(p, UI.ROLE_ICON[r] .. " " .. ROLE_NAME[r], bw[r], bx[r], y, function()
            ns.Clans.ToggleRole(r)
        end, 24)
        b.sel = b:CreateTexture(nil, "OVERLAY")
        b.sel:SetColorTexture(1, 0.82, 0, 1)
        b.sel:SetPoint("BOTTOMLEFT", 6, 2)
        b.sel:SetPoint("BOTTOMRIGHT", -6, 2)
        b.sel:SetHeight(2)
        b.sel:Hide()
        p.roleBtns[r] = b
    end
    p.rolesTip = Text(p, L.CLAN_ROLES_TIP, "GameFontDisableSmall", 278, y - 6, 736 - 278)
end

local function RefreshColumn(c, info)
    local Cl = ns.Clans
    c:SetShown(info ~= nil)
    if not info then return end
    local race = info.race
    local mine = race == Cl.MyRace()
    c.title:SetText(string.format(L.CLAN_NAME, Cl.RaceName(race)) .. (mine and (ns.GREY .. "  " .. L.CLAN_YOU .. "|r") or ""))
    c.count:SetText(string.format(L.CLAN_COUNT, info.n, info.online))
    local leaders = info.leaders or {}
    if #leaders == 0 then
        c.leader:SetText(ns.GREY .. L.CLAN_NO_LEADER .. "|r")
    else
        local m = ns.Guild.Get(leaders[1])
        local name = m and UI.Name(m, true) or leaders[1]
        c.leader:SetText(LEADER_ICON .. " " .. name .. (#leaders > 1 and (ns.GREY .. " +" .. (#leaders - 1) .. "|r") or ""))
    end
    if c.SetBackdropBorderColor then
        if mine then c:SetBackdropBorderColor(0.9, 0.76, 0.36, 0.9) else c:SetBackdropBorderColor(0.55, 0.55, 0.55, 0.9) end
    end

    local members = Cl.Members(race)
    local off = math.min(c.offset, math.max(0, #members - ROWS))
    c.offset = off
    c.empty:SetShown(#members == 0)
    for j, r in ipairs(c.rows) do
        local m = members[off + j]
        r.m = m
        if m then
            r.roles:SetText(UI.RoleIcons(Cl.Roles(m.name)))
            r.name:SetText(UI.Name(m, true))
            r.stripe:SetColorTexture(1, 1, 1, (m.name == ns.me) and 0.1 or ((j % 2 == 0) and 0.04 or 0))
            r:Show()
        else
            r:Hide()
        end
    end
    c.shown:SetText(#members > ROWS and string.format(L.SHOWN, off + 1, math.min(#members, off + ROWS), #members) or "")
end

local function Refresh(p)
    local Cl = ns.Clans
    local list = Cl.List()
    for i, c in ipairs(p.cols) do RefreshColumn(c, list[i]) end

    local roles = Cl.MyRoles()
    for _, r in ipairs(Cl.ROLES) do
        local on = roles:find(r, 1, true) ~= nil
        local b = p.roleBtns[r]
        b.sel:SetShown(on)
        if on then b:LockHighlight() else b:UnlockHighlight() end
    end
end

UI.AddPage("clans", Build, Refresh)

ns.Listen("CLANS", UI.Dirty)
ns.Listen("BOARD", UI.Dirty)
ns.Listen("STATUS", UI.Dirty)
