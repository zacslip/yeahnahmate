-- The "How it works" cards on the Clans tab: one over the Clan roll panel (My Clan, UI/ClanRoll.lua) for
-- clan leaders, one over the All clans roll panel (UI/ClanRollAll.lua) for the guild master and managers.
-- Each panel's "How it works" button opens its card on top of the panel; Close shuts it. Pictures are
-- drawn from the addon's own widgets (the same buttons and boxes the panel uses), so they always match.
-- The all-clans card is a small diagram: you -> each clan leader's addon -> the winners back to you.
local ADDON, ns = ...
local L = ns.L
local UI = ns.UI
local Text, Button = UI.Text, UI.Button

ns.ClanRollHelp = {}
local H = ns.ClanRollHelp

local GOLD_LINE = { 0.9, 0.76, 0.36, 0.85 }
local DIAGRAM_CLANS = { "Orc", "Troll", "Tauren", "Scourge" }

-- A look-alike of a real button: same template and label, but not clickable.
local function Fake(parent, label, w, x, y, h)
    local b = Button(parent, label, w, x, y, nil, h or 22)
    b:EnableMouse(false)
    return b
end

-- A gold disc with a step number on it.
local function Num(parent, n, x, y)
    local t = parent:CreateTexture(nil, "ARTWORK")
    t:SetTexture("Interface\\CHARACTERFRAME\\TempPortraitAlphaMask")
    t:SetVertexColor(0.85, 0.66, 0.15)
    t:SetSize(22, 22)
    t:SetPoint("TOPLEFT", x, y)
    local fs = Text(parent, "|cff1a1000" .. n .. "|r", "GameFontNormal", x, y - 4, 22, "CENTER")
    return t, fs
end

-- A plain line (the diagram's arrows).
local function Line(parent, x, y, w, h)
    local t = parent:CreateTexture(nil, "ARTWORK")
    t:SetColorTexture(GOLD_LINE[1], GOLD_LINE[2], GOLD_LINE[3], GOLD_LINE[4])
    t:SetPoint("TOPLEFT", x, y)
    t:SetSize(w, h)
    return t
end

-- A wrapped paragraph.
local function Para(parent, text, font, x, y, w)
    local fs = parent:CreateFontString(nil, "OVERLAY", font or "GameFontHighlightSmall")
    fs:SetPoint("TOPLEFT", x, y)
    fs:SetWidth(w)
    fs:SetJustifyH("LEFT")
    fs:SetWordWrap(true)
    fs:SetText(text)
    return fs
end

local function ClanHex(race)
    local c = ns.Plates and ns.Plates.COLOURS and ns.Plates.COLOURS[race] or { 1, 0.82, 0 }
    return string.format("|cff%02x%02x%02x", c[1] * 255, c[2] * 255, c[3] * 255), c
end

-- The card itself: covers the panel (same size), solid, above everything on it.
local function Card(panel, title)
    local W, Hh = ns.ClanRollUI.W, ns.ClanRollUI.H      -- both roll panels are this size
    local c = UI.Box(panel, 0, 0, W, Hh)
    if c.SetBackdropColor then
        c:SetBackdropColor(0.03, 0.03, 0.04, 0.97)
        c:SetBackdropBorderColor(0.9, 0.76, 0.36, 0.9)
    end
    -- A solid fill inside the border: the backdrop's texture alone lets the panel show through.
    local fill = c:CreateTexture(nil, "BACKGROUND")
    fill:SetColorTexture(0.03, 0.03, 0.04, 1)
    fill:SetPoint("TOPLEFT", 3, -3)
    fill:SetSize(W - 6, Hh - 6)
    c:SetFrameLevel((panel:GetFrameLevel() or 1) + 30)
    c:EnableMouse(true)               -- clicks stop here, not on the panel under it
    c.title = Text(c, ns.GOLD .. title .. "|r", "GameFontNormal", 12, -10, 320)
    c.close = Button(c, L.CLANROLL_HOW_CLOSE, 90, W - 100, -6, function() c:Hide() end, 22)
    c:Hide()
    return c
end

---------------------------------------------------------------------------------------------------
-- The clan leader's card (My Clan): five steps down the left, a picture of each on the right.

function H.BuildLeader(panel)
    local c = Card(panel, L.CLANROLL_HOW_TITLE)
    local W = ns.ClanRollUI.W
    local TX, TW, PX = 42, 360, 420          -- step text x and width; pictures x
    local steps = {
        { L.CLANROLL_HOW_1, L.CLANROLL_HOW_1_TEXT },
        { L.CLANROLL_HOW_2, L.CLANROLL_HOW_2_TEXT },
        { L.CLANROLL_HOW_3, L.CLANROLL_HOW_3_TEXT },
        { L.CLANROLL_HOW_4, L.CLANROLL_HOW_4_TEXT },
        { L.CLANROLL_HOW_5, L.CLANROLL_HOW_5_TEXT },
    }
    local y0, STEP = -38, 50
    c.steps = {}
    for i, s in ipairs(steps) do
        local y = y0 - (i - 1) * STEP
        Num(c, i, 12, y)
        local head = Text(c, ns.GOLD .. s[1] .. "|r", "GameFontNormal", TX, y - 3, TW)
        local body = Para(c, s[2], "GameFontHighlightSmall", TX, y - 20, TW)
        c.steps[i] = { head = head, body = body, y = y }
    end
    -- 1: a party of names in their clan's colour, with the crown on you.
    local hex = ClanHex(ns.Clans.MyRace() or "Orc")
    c.party = Text(c, "|TInterface\\GroupFrame\\UI-Group-LeaderIcon:12:12|t " .. hex .. ns.Clans.RaceName(ns.Clans.MyRace() or "Orc")
        .. "|r  " .. ns.GREY .. "+ 4|r", "GameFontHighlight", PX, y0 - 8, W - PX - 12)
    -- 2: the item box.
    local y2 = y0 - STEP
    Text(c, L.CLANROLL_ITEM, "GameFontNormalSmall", PX, y2 - 8, 40)
    local box = UI.Box(c, PX + 36, y2 - 2, W - PX - 48, 24)
    box:EnableMouse(false)
    c.itemHint = Text(box, ns.GREY .. L.CLANROLL_HOW_2_BOX .. "|r", "GameFontHighlightSmall", 8, -6, W - PX - 64)
    -- 3: Start roll.
    c.start = Fake(c, L.CLANROLL_START_BTN, 110, PX, y0 - 2 * STEP - 4, 24)
    -- 4: a few rolls, highest first, the top one in gold.
    local y4 = y0 - 3 * STEP
    c.rolls = Text(c, ns.GOLD .. "1.  88|r     2.  72     3.  45", "GameFontHighlight", PX, y4 - 8, W - PX - 12)
    -- 5: Announce.
    c.announce = Fake(c, L.CLANROLL_ANNOUNCE, 100, PX, y0 - 4 * STEP - 4, 24)

    -- Under the steps: a tie, the pop-out, and when the guild master asks.
    local ty = y0 - 5 * STEP - 4
    Line(c, 10, ty + 4, W - 20, 1)
    c.reroll = Fake(c, L.CLANROLL_REROLL, 100, 12, ty - 2, 20)
    c.tie = Para(c, L.CLANROLL_HOW_TIE, "GameFontHighlightSmall", 122, ty - 4, W - 134)
    c.pop = Fake(c, L.CLANROLL_POP, 100, 12, ty - 26, 20)
    c.popText = Para(c, L.CLANROLL_HOW_POP, "GameFontHighlightSmall", 122, ty - 28, W - 134)
    c.asked = Para(c, ns.GREY .. L.CLANROLL_HOW_ASKED .. "|r", "GameFontHighlightSmall", 12, ty - 52, W - 24)
    return c
end

---------------------------------------------------------------------------------------------------
-- The all-clans card: you (left) -> each clan leader's addon (middle) -> the winners back to you (right).

function H.BuildAll(panel)
    local c = Card(panel, L.CLANROLL_HOW_ALL_TITLE)
    local W = ns.ClanRollUI.W
    local TOP = -40
    local LX, LW = 12, 150                   -- you
    local MX, MW = 196, 150                  -- the leaders' addons
    local RX = MX + MW + 34                  -- back to you
    local RW = W - RX - 12
    local BOX_H, GAP = 40, 8

    -- Column heads.
    Text(c, ns.GOLD .. L.CLANROLL_HOW_ALL_YOU .. "|r", "GameFontNormal", LX, TOP, LW)
    Text(c, ns.GOLD .. L.CLANROLL_HOW_ALL_LEADERS .. "|r", "GameFontNormal", MX, TOP, MW)
    Text(c, ns.GOLD .. L.CLANROLL_HOW_ALL_BACK .. "|r", "GameFontNormal", RX, TOP, RW)

    local by = TOP - 20
    local colH = #DIAGRAM_CLANS * (BOX_H + GAP) - GAP

    -- You: step 1 and the Start roll button.
    local you = UI.Box(c, LX, by, LW, colH)
    you:EnableMouse(false)
    Num(you, 1, 8, -8)
    Para(you, L.CLANROLL_HOW_ALL_1, "GameFontHighlightSmall", 36, -10, LW - 44)
    c.start = Fake(you, L.CLANROLL_ALL_START, 110, (LW - 110) / 2, -colH + 34, 24)

    -- The leaders' addons: one box per clan in its colour, the crown and Start roll in each.
    c.clans = {}
    for i, race in ipairs(DIAGRAM_CLANS) do
        local y = by - (i - 1) * (BOX_H + GAP)
        local hex, col = ClanHex(race)
        local b = UI.Box(c, MX, y, MW, BOX_H)
        b:EnableMouse(false)
        if b.SetBackdropBorderColor then b:SetBackdropBorderColor(col[1], col[2], col[3], 0.95) end
        Text(b, hex .. ns.Clans.RaceName(race) .. "|r", "GameFontNormalSmall", 8, -7, MW - 90)
        Text(b, "|TInterface\\GroupFrame\\UI-Group-LeaderIcon:12:12|t " .. ns.GREY .. L.CLANROLL_HOW_ALL_LEADER .. "|r",
            "GameFontHighlightSmall", 8, -22, MW - 90)
        Fake(b, L.CLANROLL_START_BTN, 76, MW - 82, -10, 20)
        -- Arrow in from you, arrow out to the winners.
        local mid = y - BOX_H / 2
        Line(c, LX + LW, mid, MX - LX - LW - 6, 2)
        Text(c, ns.GOLD .. ">|r", "GameFontNormal", MX - 9, mid + 7, 10)
        Line(c, MX + MW, mid, RX - MX - MW - 6, 2)
        Text(c, ns.GOLD .. ">|r", "GameFontNormal", RX - 9, mid + 7, 10)
        c.clans[i] = b
    end

    -- Back to you: each clan's winner, then the overall winner and Announce.
    local back = UI.Box(c, RX, by, RW, colH)
    back:EnableMouse(false)
    Num(back, 3, 8, -8)
    Para(back, L.CLANROLL_HOW_ALL_3, "GameFontHighlightSmall", 36, -10, RW - 44)
    -- Made-up results: each clan's winning roll in its colour, the highest one gold with a crown.
    local rolls, best = { 88, 95, 72, 81 }, 95
    local names = L.CLANROLL_HOW_ALL_SAMPLES
    for i, race in ipairs(DIAGRAM_CLANS) do
        local y = -84 - (i - 1) * 15
        Text(back, ClanHex(race) .. ns.Clans.RaceName(race) .. "|r", "GameFontHighlightSmall", 10, y, 48)
        Text(back, names[i], "GameFontHighlightSmall", 58, y, 98)
        Text(back, rolls[i] == best and (ns.GOLD .. best .. "|r |TInterface\\GroupFrame\\UI-Group-LeaderIcon:12:12|t")
            or tostring(rolls[i]), "GameFontHighlightSmall", 156, y, RW - 162)
    end
    c.announce = Fake(back, L.CLANROLL_ANNOUNCE, 100, (RW - 100) / 2, -colH + 34, 24)

    -- Step 2 under the diagram (what the leaders' addons do), then the hand-off and the dots.
    local ny = by - colH - 10
    Num(c, 2, 12, ny)
    c.step2 = Para(c, L.CLANROLL_HOW_ALL_2, "GameFontHighlightSmall", 42, ny - 2, W - 54)
    Line(c, 10, ny - 34, W - 20, 1)
    c.next = Para(c, L.CLANROLL_HOW_ALL_NEXT, "GameFontHighlightSmall", 12, ny - 42, W - 24)
    c.dots = Para(c, ns.GREY .. string.format(L.CLANROLL_HOW_ALL_DOTS,
        "|TInterface\\COMMON\\Indicator-Green:12:12|t", "|TInterface\\COMMON\\Indicator-Yellow:12:12|t",
        "|TInterface\\COMMON\\Indicator-Red:12:12|t") .. "|r", "GameFontHighlightSmall", 12, ny - 60, W - 24)
    c.need = Text(c, ns.GREY .. L.CLANROLL_HOW_ALL_NEED .. "|r", "GameFontHighlightSmall", 12, ny - 76, W - 24)
    return c
end

-- The "How it works" button for a panel, at x on its top row; the card is built on first click.
function H.AddButton(panel, x, build)
    local b = Button(panel, L.CLANROLL_HOW, 90, x, -6, function()
        panel.how = panel.how or build(panel)
        panel.how:SetShown(not panel.how:IsShown())
    end, 22)
    if ns.ClanRollUI and ns.ClanRollUI.WithTip then ns.ClanRollUI.WithTip(b, { L.CLANROLL_HOW, L.CLANROLL_HOW_TIP }) end
    panel.howBtn = b
    return b
end
