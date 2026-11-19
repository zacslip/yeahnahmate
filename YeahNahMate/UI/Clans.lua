-- Clans tab: the guild by race (Clans.lua). Sidebar: a clan picker (yours first shown), the clan's
-- leader, the Members card, and My roles (Tank / Healer / DPS, up to two). Right: the clan's members
-- with their roles, level and where they are; hover a name for the usual guildie tooltip.
-- Coming next (PLAN Phase 12): clan meetings and leadership challenges, as more cards.
local ADDON, ns = ...
local L = ns.L
local UI = ns.UI
local Text, Button, Row = UI.Text, UI.Button, UI.Row
local RX, RW, SIDE_W = UI.RX, UI.RW, UI.SIDE_W

local ROWS = 13
local UNKNOWN = "?"                 -- the picker's "race not known" entry
local LEADER_ICON = "|TInterface\\GroupFrame\\UI-Group-LeaderIcon:12:12|t"
local ROLE_NAME = { t = L.ROLE_TANK, h = L.ROLE_HEALER, d = L.ROLE_DPS }

local function ClanTitle(race)
    if race == UNKNOWN then return L.CLAN_RACE_UNKNOWN end
    return string.format(L.CLAN_NAME, ns.Clans.RaceName(race))
end

local function Build(p)
    p.offset = 0
    p.race = nil                     -- nil = my own clan

    -- The clan picker.
    p.pickBtn = Button(p, "", SIDE_W, 0, 0, nil, 28)
    p.menu = UI.PickMenu(p, SIDE_W, 14)
    p.pickBtn:SetScript("OnClick", function(self)
        local items, keys = {}, {}
        local list, unknown = ns.Clans.List()
        for _, c in ipairs(list) do
            items[#items + 1] = string.format(L.CLAN_MENU_ROW, ClanTitle(c.race), c.n)
            keys[#keys + 1] = c.race
        end
        if unknown > 0 then
            items[#items + 1] = string.format(L.CLAN_UNKNOWN_VIEW, unknown)
            keys[#keys + 1] = UNKNOWN
        end
        p.menu.Open(self, items, function(i) p.race = keys[i]; p.offset = 0; UI.Dirty() end)
    end)

    p.leaderCard = UI.SideBox(p, -34, "Interface\\GroupFrame\\UI-Group-LeaderIcon", L.CLAN_CARD_LEADER, nil)
    p.membersCard = UI.SideBox(p, -106, "Interface\\Icons\\Spell_Nature_Bloodlust", L.CLAN_CARD_MEMBERS, nil)
    p.membersCard.SetPicked(true)

    local line = p:CreateTexture(nil, "ARTWORK")
    line:SetColorTexture(0.9, 0.76, 0.36, 0.5)
    line:SetPoint("TOPLEFT", 0, -180)
    line:SetSize(SIDE_W, 1)

    -- My roles: three buttons that light up when picked.
    Text(p, ns.GOLD .. L.CLAN_MY_ROLES .. "|r", "GameFontNormalSmall", 2, -190, SIDE_W)
    p.roleBtns = {}
    local bw, bx = { t = 50, h = 62, d = 48 }, { t = 0, h = 54, d = 120 }
    for _, r in ipairs(ns.Clans.ROLES) do
        local b = Button(p, UI.ROLE_ICON[r] .. " " .. ROLE_NAME[r], bw[r], bx[r], -206, function()
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
    p.myRoles = Text(p, "", "GameFontHighlightSmall", 2, -236, SIDE_W)
    local tip = Text(p, L.CLAN_ROLES_TIP, "GameFontDisableSmall", 2, -252, SIDE_W)
    tip:SetWordWrap(true)
    tip:SetHeight(28)
    tip:SetJustifyV("TOP")
    local foot = Text(p, L.CLAN_SIDE_FOOT, "GameFontDisableSmall", 2, -292, SIDE_W)
    foot:SetWordWrap(true)
    foot:SetHeight(42)
    foot:SetJustifyV("TOP")

    -- Right: the members.
    p.viewTitle = UI.ViewTitle(p, 400)
    Text(p, ns.GOLD .. L.CLAN_COL_NAME .. "|r", "GameFontNormalSmall", RX + 6, -32, 200)
    Text(p, ns.GOLD .. L.CLAN_COL_ROLES .. "|r", "GameFontNormalSmall", RX + 220, -32, 60)
    Text(p, ns.GOLD .. L.CLAN_COL_LEVEL .. "|r", "GameFontNormalSmall", RX + 284, -32, 40)
    Text(p, ns.GOLD .. L.CLAN_COL_WHERE .. "|r", "GameFontNormalSmall", RX + 334, -32, 200)
    p.rows = {}
    for i = 1, ROWS do
        local r = Row(p, RX, -48 - (i - 1) * 22, RW, 21)
        r.name = Text(r, "", "GameFontHighlightSmall", 6, -4, 210)
        r.roles = Text(r, "", "GameFontHighlightSmall", 220, -3, 60)
        r.level = Text(r, "", "GameFontHighlightSmall", 284, -4, 40)
        r.where = Text(r, "", "GameFontHighlightSmall", 334, -4, RW - 340)
        r:SetScript("OnEnter", function(self)
            self.hl:Show()
            if self.m then UI.MemberTooltip(self, self.m) end
        end)
        r:SetScript("OnLeave", function(self)
            self.hl:Hide()
            if GameTooltip then GameTooltip:Hide() end
        end)
        r:EnableMouseWheel(true)
        r:SetScript("OnMouseWheel", function(_, d) p.offset = math.max(0, p.offset - d); UI.Dirty() end)
        p.rows[i] = r
    end
    p.empty = Text(p, "", "GameFontDisableSmall", RX + 6, -54, RW - 12)
    p.pager = UI.Pager(p, RX + RW - 142, -340, function(d) p.offset = math.max(0, p.offset + d * ROWS); UI.Dirty() end)
    p.note = Text(p, "", "GameFontDisableSmall", RX + 4, -364, RW - 8)
    p.note:SetWordWrap(true)
    p.note:SetHeight(30)
    p.note:SetJustifyV("TOP")
end

local function Where(m)
    if not m.online then return ns.GREY .. L.OFFLINE .. "|r" end
    local zone = m.zone ~= "" and m.zone or "?"
    local d = ns.Map and ns.Map.Distance(m.name)
    if d then zone = zone .. ns.GREEN .. "  " .. string.format(L.YARDS, d) .. "|r" end
    return zone
end

local function Refresh(p)
    local Cl = ns.Clans
    local mine = Cl.MyRace()
    local list, unknown = Cl.List()
    local race = p.race or mine or (list[1] and list[1].race) or UNKNOWN
    if race == UNKNOWN and unknown == 0 and list[1] then race = list[1].race end
    p.pickBtn:SetText(ClanTitle(race) .. "  v")

    -- Leader card.
    local info
    for _, c in ipairs(list) do if c.race == race then info = c end end
    local lc = p.leaderCard
    if race == UNKNOWN then
        lc.text:SetText(ns.GREY .. "-" .. "|r")
        lc.pts:SetText("")
    else
        local leaders = info and info.leaders or {}
        if #leaders == 0 then
            lc.text:SetText(ns.GREY .. L.CLAN_NO_LEADER .. "|r")
        else
            local first = leaders[1]:match("^%S+") or leaders[1]
            lc.text:SetText(#leaders > 1 and string.format(L.CLAN_TWO_LEADERS, first, #leaders - 1) or first)
        end
        lc.pts:SetText(string.format(L.CLAN_ONLINE, info and info.online or 0, info and info.n or 0))
    end
    lc.SetActive(race ~= UNKNOWN and Cl.IsLeader(ns.me, race))
    local mc = p.membersCard
    mc.text:SetText(race == mine and L.CLAN_YOURS or L.CLAN_NOT_YOURS)
    mc.pts:SetText(unknown > 0 and string.format(L.CLAN_UNKNOWN_VIEW, unknown) or "")

    -- My roles.
    local roles = Cl.MyRoles()
    local names = {}
    for _, r in ipairs(Cl.ROLES) do
        local on = roles:find(r, 1, true) ~= nil
        local b = p.roleBtns[r]
        b.sel:SetShown(on)
        if on then b:LockHighlight(); names[#names + 1] = ROLE_NAME[r] else b:UnlockHighlight() end
    end
    p.myRoles:SetText(#names > 0 and table.concat(names, ", ") or (ns.GREY .. L.CLAN_ROLES_NONE .. "|r"))

    -- Members.
    p.viewTitle:SetText(ClanTitle(race))
    local members = race == UNKNOWN and Cl.Unknown() or Cl.Members(race)
    local lead = {}
    if race ~= UNKNOWN then for _, n in ipairs(Cl.Leaders(race)) do lead[n] = true end end
    local off = math.min(p.offset, math.max(0, #members - ROWS))
    p.offset = off
    p.empty:SetText(race == UNKNOWN and L.CLAN_UNKNOWN_EMPTY or L.CLAN_EMPTY)
    p.empty:SetShown(#members == 0)
    p.pager.Set(off + 1, math.min(#members, off + ROWS), #members)
    for i, r in ipairs(p.rows) do
        local m = members[off + i]
        r.m = m
        if m then
            r.name:SetText((lead[m.name] and (LEADER_ICON .. " ") or "") .. UI.Name(m, true))
            r.roles:SetText(UI.RoleIcons(Cl.Roles(m.name)))
            r.level:SetText(m.online and tostring(m.level or "") or (ns.GREY .. tostring(m.level or "") .. "|r"))
            r.where:SetText(Where(m))
            r.stripe:SetColorTexture(1, 1, 1, (m.name == ns.me) and 0.1 or ((i % 2 == 0) and 0.04 or 0))
            r:Show()
        else
            r:Hide()
        end
    end
    p.note:SetText((race ~= UNKNOWN and unknown > 0) and string.format(L.CLAN_UNKNOWN_NOTE, unknown) or "")
end

UI.AddPage("clans", Build, Refresh)

ns.Listen("CLANS", UI.Dirty)
ns.Listen("BOARD", UI.Dirty)
ns.Listen("STATUS", UI.Dirty)
