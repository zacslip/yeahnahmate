-- Guild breakdown page (opened from Home's "Online" box): four small charts. Classes (bars in class
-- colours), levels (columns by band, mine in gold), professions (guildies with the addon) and the
-- guild at a glance. A switch shows all members, those online now, or those on this week.
local ADDON, ns = ...
local L = ns.L
local UI = ns.UI
local Text, Button, Box, Row = UI.Text, UI.Button, UI.Box, UI.Row

local CLASS_ROWS, PROF_ROWS = 10, 10
local BAR_W, PROF_BAR_W = 196, 140
local COL_W, COL_GAP, COL_MAX = 36, 12, 96
local BAND_LABELS = { "1-9", "10s", "20s", "30s", "40s", "50s", "60" }

local function Bar(parent)
    local t = parent:CreateTexture(nil, "ARTWORK")
    t:SetColorTexture(1, 1, 1, 1)
    return t
end

local function Title(box, text)
    return Text(box, ns.GOLD .. text .. "|r", "GameFontNormal", 10, -8, 340)
end

local function Build(p)
    p.mode = ns.Breakdown.ALL
    Button(p, L.BACK, 70, 0, 0, function() UI.Select("home") end, 22)
    Text(p, L.BREAKDOWN, "GameFontNormalLarge", 82, -3)
    UI.Choice(p, { L.BD_ALL, L.BD_ONLINE, L.BD_ACTIVE }, 386, 0, 112, function(i)
        p.mode = i
        if p:IsShown() then UI.Dirty() end
    end)(1)

    -- Classes: one bar per class, longest first.
    local c = Box(p, 0, -30, 362, 184)
    Title(c, L.BD_CLASSES)
    p.classRows = {}
    for i = 1, CLASS_ROWS do
        local r = Row(c, 6, -26 - (i - 1) * 15, 350, 14)
        r.stripe:SetColorTexture(1, 1, 1, 0)
        r.name = Text(r, "", "GameFontHighlightSmall", 4, -1, 80)
        r.bar = Bar(r)
        r.bar:SetPoint("LEFT", 88, 0)
        r.bar:SetHeight(10)
        r.num = Text(r, "", "GameFontHighlightSmall", 290, -1, 56, "RIGHT")
        r:SetScript("OnEnter", function(self)
            self.hl:Show()
            local e = self.e
            if not e or not GameTooltip then return end
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:AddLine("|c" .. ns.ClassHex(e.class) .. ns.ClassName(e.class) .. "|r")
            GameTooltip:AddLine(string.format(L.BD_CLASS_TIP, e.n, math.floor(e.sum / math.max(1, e.n) + 0.5), e.max), 1, 1, 1)
            GameTooltip:Show()
        end)
        r:SetScript("OnLeave", function(self) self.hl:Hide(); if GameTooltip then GameTooltip:Hide() end end)
        p.classRows[i] = r
    end

    -- Levels: a column per band.
    local lv = Box(p, 374, -30, 362, 184)
    Title(lv, L.BD_LEVELS)
    p.cols = {}
    for i = 1, #BAND_LABELS do
        local x = 24 + (i - 1) * (COL_W + COL_GAP)
        local col = { bar = Bar(lv) }
        col.bar:SetPoint("BOTTOMLEFT", lv, "BOTTOMLEFT", x, 42)
        col.bar:SetWidth(COL_W)
        col.num = lv:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        col.num:SetPoint("BOTTOM", col.bar, "TOP", 0, 2)
        col.label = lv:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
        col.label:SetPoint("TOP", lv, "BOTTOMLEFT", x + COL_W / 2, 40)
        col.label:SetText(BAND_LABELS[i])
        p.cols[i] = col
    end
    p.levelNote = lv:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    p.levelNote:SetPoint("BOTTOMLEFT", 12, 8)
    p.levelNote:SetWidth(338)
    p.levelNote:SetJustifyH("LEFT")

    -- Professions: guildies with the addon who share, plus me.
    local pr = Box(p, 0, -222, 362, 188)
    Title(pr, L.BD_PROFS)
    p.profRows = {}
    for i = 1, PROF_ROWS do
        local r = { }
        local y = -28 - (i - 1) * 12
        r.name = Text(pr, "", "GameFontHighlightSmall", 12, y, 92)
        r.bar = Bar(pr)
        r.bar:SetPoint("TOPLEFT", 106, y - 2)
        r.bar:SetHeight(9)
        r.bar:SetColorTexture(0.9, 0.76, 0.36, 0.9)
        r.num = Text(pr, "", "GameFontHighlightSmall", 252, y, 102, "RIGHT")
        p.profRows[i] = r
    end
    p.profNone = Text(pr, L.BD_PROFS_NONE, "GameFontDisableSmall", 12, -30, 338)
    p.missing = Text(pr, "", "GameFontDisableSmall", 12, -148, 338)
    p.missing:SetWordWrap(true)
    p.missing:SetHeight(24)
    p.missing:SetJustifyV("TOP")
    -- how professions are counted, here in one line (was under At a glance).
    p.profNote = Text(pr, L.BD_PROF_NOTE, "GameFontDisableSmall", 12, -172, 338)
    p.profNote:SetWordWrap(false)

    -- At a glance.
    local g = Box(p, 374, -222, 362, 188)
    Title(g, L.BD_GLANCE)
    p.glance = {}
    for i = 1, 6 do p.glance[i] = Text(g, "", "GameFontHighlight", 12, -28 - (i - 1) * 16.5, 338) end
    p.ranks = Text(g, "", "GameFontHighlightSmall", 12, -128, 338)
    p.ranks:SetWordWrap(true)
    p.ranks:SetHeight(28)
    p.ranks:SetJustifyV("TOP")
    p.glanceNote = Text(g, "", "GameFontDisableSmall", 12, -154, 338)
    p.glanceNote:SetWordWrap(true)
    p.glanceNote:SetHeight(32)
    p.glanceNote:SetJustifyV("TOP")
end

local function Refresh(p)
    local B = ns.Breakdown
    local canActive = B.HasLastOnline()
    local mode = p.mode
    if mode == B.ACTIVE and not canActive then mode = B.ALL end
    local d = B.Get(mode)

    -- Classes
    local most = d.classes[1] and d.classes[1].n or 1
    for i, r in ipairs(p.classRows) do
        local e = d.classes[i]
        r.e = e
        if e then
            local c = RAID_CLASS_COLORS and RAID_CLASS_COLORS[e.class]
            r.name:SetText("|c" .. ns.ClassHex(e.class) .. ns.ClassName(e.class) .. "|r")
            r.bar:SetWidth(math.max(2, BAR_W * e.n / most))
            if c then r.bar:SetVertexColor(c.r, c.g, c.b, 0.9) else r.bar:SetVertexColor(0.7, 0.7, 0.7, 0.9) end
            r.num:SetText(e.n .. ns.GREY .. "  " .. math.floor(100 * e.n / math.max(1, d.total) + 0.5) .. "%|r")
            r:Show()
        else
            r:Hide()
        end
    end

    -- Levels
    local top, topBand = 0, 1
    for i, n in ipairs(d.bands) do if n > top then top, topBand = n, i end end
    for i, col in ipairs(p.cols) do
        local n = d.bands[i] or 0
        col.bar:SetHeight(math.max(1, COL_MAX * n / math.max(1, top)))
        if i == d.myBand then col.bar:SetVertexColor(1, 0.82, 0, 0.95) else col.bar:SetVertexColor(0.35, 0.6, 1, 0.85) end
        col.num:SetText(n > 0 and tostring(n) or "")
    end
    p.levelNote:SetText(top > 0 and string.format(L.BD_LEVEL_NOTE, BAND_LABELS[topBand]) or "")

    -- Professions
    local mostP = d.profs[1] and d.profs[1].n or 1
    for i, r in ipairs(p.profRows) do
        local e = d.profs[i]
        local show = e ~= nil
        r.name:SetShown(show); r.bar:SetShown(show); r.num:SetShown(show)
        if e then
            r.name:SetText(ns.Prof.LineName(e.line))
            r.bar:SetWidth(math.max(2, PROF_BAR_W * e.n / mostP))
            r.num:SetText(string.format(L.BD_PROF_NUM, e.n, e.top))
        end
    end
    p.profNone:SetShown(#d.profs == 0)
    p.missing:SetText(#d.missing > 0 and (L.BD_MISSING .. " " .. table.concat(d.missing, ", ")) or "")

    -- At a glance
    local shownAs = mode == B.ONLINE and L.BD_ONLINE or (mode == B.ACTIVE and L.BD_ACTIVE or L.BD_ALL)
    p.glance[1]:SetText(string.format(L.BD_MEMBERS, #ns.Guild.list, d.online))
    p.glance[2]:SetText(string.format(L.BD_SHOWING, d.total, shownAs:lower()))
    p.glance[3]:SetText(string.format(L.BD_ADDON, d.addon, d.shared))
    p.glance[4]:SetText(string.format(L.BD_ROLES, d.tanks, d.healers))
    p.glance[5]:SetText(d.top > 0 and string.format(L.BD_TOP, d.top, d.topN) or "")
    local lore = ns.Questions.LoreMaster()
    p.glance[6]:SetText(lore and (L.LORE_MASTER .. ": " .. (lore:match("^%S+") or lore) .. " " .. UI.LORE_ICON
        .. ns.GREY .. "  " .. string.format(L.Q_POINTS, ns.Questions.Points(lore)) .. "|r") or "")
    local ranks = {}
    for _, r in ipairs(d.ranks) do ranks[#ranks + 1] = r.name .. " " .. ns.GREY .. r.n .. "|r" end
    p.ranks:SetText(ns.GOLD .. L.BD_RANKS .. "|r " .. table.concat(ranks, ", "))
    p.glanceNote:SetText((p.mode == B.ACTIVE and not canActive) and ("|cffff8040" .. L.BD_NO_LAST_ONLINE .. "|r") or "")
end

UI.AddPage("breakdown", Build, Refresh)
ns.Listen("PROFS", function() UI.DirtySlow() end)
