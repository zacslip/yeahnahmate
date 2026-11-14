-- Legends tab (titles have their own tab): the guild's titles. The
-- sidebar has a card per title (who holds it, your points; green when it's yours); the right shows one title: who holds it,
-- the top 10 over the last 30 days, your points and how it's earned. A new title is one more entry
-- in TITLES (its module counts the points: Questions.lua, Requests.lua).
local ADDON, ns = ...
local L = ns.L
local UI = ns.UI
local Text, Box, Header, Row = UI.Text, UI.Box, UI.Header, UI.Row
local RX, RW = UI.RX, UI.RW

local function TITLES()
    local Q, R = ns.Questions, ns.Requests
    return {
        { key = "lore", name = L.LORE_MASTER, icon = "Interface\\Icons\\INV_Misc_Book_09",
          holder = Q.LoreMaster, points = Q.Points, top = Q.Top, min = Q.LORE_MIN,
          head = L.Q_TOP_HEAD, none = L.Q_TOP_NONE, how = L.Q_TOP_HOW, pts30 = L.Q_POINTS_30, num = L.Q_POINTS,
          mine = L.Q_MY_POINTS },
        { key = "crafty", name = L.CRAFTY_BUGGER, icon = "Interface\\Icons\\INV_Misc_Wrench_01",
          holder = R.CraftyBugger, points = R.Points, top = R.Top, min = R.BUGGER_MIN,
          head = L.CB_TOP_HEAD, none = L.CB_TOP_NONE, how = L.CB_TOP_HOW, pts30 = L.CB_POINTS_30, num = L.CB_MADE,
          mine = L.CB_MY_POINTS },
    }
end

local thePage

local function FirstName(name) return name:match("^%S+") or name end

local function MemberName(name)
    local m = ns.Guild.Get(name)
    return m and UI.Name(m, true) or name
end

local function Build(p)
    thePage = p
    p.titles = TITLES()
    p.pick = 1
    p.pickView = function(i) p.pick = i; UI.Dirty() end
    -- Sidebar: one card per title like the other tabs; green when it's yours.
    p.titleCards = {}
    for i, t in ipairs(p.titles) do
        p.titleCards[i] = UI.SideBox(p, -(i - 1) * 72, t.icon, t.name, function() p.pickView(i) end)
    end
    local footY = -#p.titles * 72 - 4
    local foot = Text(p, L.LEGEND_SIDE_FOOT, "GameFontDisableSmall", 0, footY, UI.SIDE_W)
    foot:SetWordWrap(true)
    foot:SetHeight(90)
    foot:SetJustifyV("TOP")

    -- Right: one title.
    p.viewTitle = UI.ViewTitle(p, 400)
    local box = Box(p, RX, -30, RW, 62)
    p.big = box:CreateTexture(nil, "ARTWORK")
    p.big:SetSize(40, 40)
    p.big:SetPoint("TOPLEFT", 12, -11)
    p.who = Text(box, "", "GameFontHighlightLarge", 64, -12, 300)
    p.pts = Text(box, "", "GameFontHighlightSmall", 64, -36, RW - 76)
    p.head = Header(p, "", RX, -100, RW)
    p.rows = {}
    for i = 1, 10 do
        local r = Row(p, RX, -122 - (i - 1) * 21, RW, 20)
        r.rank = Text(r, "", "GameFontDisableSmall", 6, -4, 26, "RIGHT")
        r.name = Text(r, "", "GameFontHighlight", 40, -4, 340)
        r.num = Text(r, "", "GameFontHighlightSmall", RW - 160, -5, 150, "RIGHT")
        p.rows[i] = r
    end
    p.none = Text(p, "", "GameFontDisableSmall", RX + 6, -126, RW - 12)
    p.none:SetWordWrap(true)
    p.none:SetHeight(30)
    p.none:SetJustifyV("TOP")
    p.mine = Text(p, "", "GameFontHighlightSmall", RX + 4, -336, RW - 8)
    p.how = Text(p, "", "GameFontDisableSmall", RX + 4, -354, RW - 8)
    p.how:SetWordWrap(true)
    p.how:SetHeight(42)
    p.how:SetJustifyV("TOP")
end

local function Refresh(p)
    local titles = p.titles
    local t = titles[p.pick] or titles[1]
    -- Sidebar: each title's card shows its holder and your points; green when you hold it.
    local meP = ns.Alts.Person(ns.me)
    for i, e in ipairs(titles) do
        local c, h = p.titleCards[i], e.holder()
        c.text:SetText(h and (h == meP and (ns.GREEN .. L.LEGEND_YOU .. "|r") or FirstName(h))
            or (ns.GREY .. L.Q_LORE_NOBODY .. "|r"))
        c.pts:SetText(string.format(e.mine, e.points(ns.me)))
        c.SetPicked(i == p.pick)
        c.SetActive(h ~= nil and h == meP)
    end

    -- The title.
    p.viewTitle:SetText(t.name)
    p.big:SetTexture(t.icon)
    local h = t.holder()
    p.who:SetText(h and MemberName(h) or (ns.GREY .. L.Q_LORE_NOBODY .. "|r"))
    p.pts:SetText(h and string.format(t.pts30, t.points(h)) or string.format(L.Q_LORE_NEED, t.min))
    p.head:SetText(t.head)
    local top = t.top(10)
    p.none:SetText(t.none)
    p.none:SetShown(#top == 0)
    local me = ns.Alts.Person(ns.me)
    for i, r in ipairs(p.rows) do
        local e = top[i]
        if e then
            r.rank:SetText(i .. ".")
            local chars = ns.Alts.Characters(e.name)
            r.name:SetText(MemberName(e.name) .. (#chars > 1 and (ns.GREY .. "  " .. string.format(L.CB_PLUS_ALTS, #chars - 1) .. "|r") or ""))
            r.num:SetText(string.format(t.num, e.n))
            r.stripe:SetColorTexture(1, 1, 1, (e.name == me) and 0.1 or ((i % 2 == 0) and 0.04 or 0))
            r:Show()
        else
            r:Hide()
        end
    end
    p.mine:SetText(string.format(t.mine, t.points(ns.me)))
    p.how:SetText(string.format(t.how, t.min))
end

UI.AddPage("legends", Build, Refresh)

-- Open the Legends tab at one title ("lore", "crafty").
function UI.ShowLegend(key)
    UI.Open("legends")
    if thePage then
        for i, t in ipairs(thePage.titles) do if t.key == key then thePage.pick = i end end
        UI.Dirty()
    end
end

ns.Listen("QUESTIONS", UI.Dirty)
ns.Listen("REQUESTS", UI.Dirty)
ns.Listen("ALTS", UI.Dirty)
