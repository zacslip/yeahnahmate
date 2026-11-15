-- GM tab: the Milestones and Welcome pages. GM.lua builds the tab and
-- calls these. Milestones: the cards as boxes (what it waits for, the message, where it goes, on/off,
-- Edit, Delete) and an editor. Welcome: one message for new members and which ranks post it.
local ADDON, ns = ...
local L = ns.L
local UI = ns.UI
local Text, Button, Box = UI.Text, UI.Button, UI.Box
local RX, RW = UI.RX, UI.RW

local CARDS = 4

local function EditBox(parent, x, y, w, max, numeric)
    local box = CreateFrame("EditBox", nil, parent, "InputBoxTemplate")
    box:SetSize(w, 22)
    box:SetPoint("TOPLEFT", x + 6, y)
    box:SetAutoFocus(false)
    box:SetMaxLetters(max or 200)
    if numeric and box.SetNumeric then box:SetNumeric(true) end
    box:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    box:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
    box:SetScript("OnTextChanged", function(_, user) if user then UI.Dirty() end end)
    return box
end

-- A see-through green over a box while it's on (like the sidebar cards).
local function Greenable(box)
    box.green = box:CreateTexture(nil, "BORDER")
    box.green:SetPoint("TOPLEFT", 3, -3)
    box.green:SetPoint("BOTTOMRIGHT", -3, 3)
    box.green:SetColorTexture(0.2, 0.85, 0.3, 0.12)
    function box.SetActive(on)
        box.green:SetShown(on and true or false)
        if box.SetBackdropBorderColor then
            if on then box:SetBackdropBorderColor(0.3, 0.9, 0.4, 0.9) else box:SetBackdropBorderColor(0.55, 0.55, 0.55, 0.9) end
        end
    end
end

-- "Guild chat + Pop-up" / "Nowhere yet".
local function Sends(c)
    local parts = {}
    if c.gc then parts[#parts + 1] = L.MS_TO_GUILD end
    if c.pu then parts[#parts + 1] = L.MS_TO_POPUP_SHORT end
    return L.MS_SENDS_LIST .. " " .. (#parts > 0 and table.concat(parts, " + ") or (ns.GREY .. L.MS_NOWHERE .. "|r"))
end

-- Fill-in buttons: clicking adds the word to the message box.
local FILL_STEP = 68
local function FillButtons(parent, x, y, box, words)
    local list = { order = {}, x = x, y = y, parent = parent }
    for i, w in ipairs(words) do
        local b = Button(parent, "{" .. w .. "}", 64, x + (i - 1) * FILL_STEP, y, function()
            box:Insert("{" .. w .. "}")
            UI.Dirty()
        end, 20)
        b.fillX = x + (i - 1) * FILL_STEP
        list[w] = b
        list.order[i] = w
    end
    return list
end

-- Show only the fill-ins this trigger uses, side by side with no gaps (they kept
-- their own slots, so the shown ones were spread out and {title} ran off the edge).
local function LayFills(list, want)
    local n = 0
    for _, w in ipairs(list.order) do
        local b = list[w]
        local on = want(w)
        b:SetShown(on)
        if on then
            b.fillX = list.x + n * FILL_STEP
            b:ClearAllPoints()
            b:SetPoint("TOPLEFT", list.parent, "TOPLEFT", b.fillX, list.y)
            n = n + 1
        end
    end
end

---------------------------------------------------------------------------------------------------
-- Milestones: the list

local function BuildList(p, v)
    local MS = ns.Milestones
    local f = CreateFrame("Frame", nil, v)
    f:SetAllPoints()
    p.msList = f
    -- Right next to the Milestones title, like the powers button by Managers.
    p.msNew = Button(f, L.MS_NEW, 130, RX + 120, -2, function()
        if #MS.List() >= MS.MAX_CARDS then ns.Print(string.format(L.MS_FULL, MS.MAX_CARDS)) return end
        p.OpenEditor(nil)
    end, 20)
    local note = Text(f, L.MS_ADDON_NOTE, "GameFontDisableSmall", RX + 4, -28, RW - 8)
    note:SetWordWrap(true)
    note:SetHeight(28)
    note:SetJustifyV("TOP")
    p.msNone = Text(f, L.MS_NONE, "GameFontDisableSmall", RX + 8, -70, RW - 16)
    p.msCards = {}
    for i = 1, CARDS do
        local c = Box(f, RX, -60 - (i - 1) * 76, RW, 72)
        Greenable(c)
        c.icon = c:CreateTexture(nil, "ARTWORK")
        c.icon:SetSize(32, 32)
        c.icon:SetPoint("TOPLEFT", 10, -10)
        c.title = Text(c, "", "GameFontNormal", 50, -9, 330)
        c.state = Text(c, "", "GameFontHighlightSmall", RW - 150, -10, 140, "RIGHT")
        c.msg = Text(c, "", "GameFontHighlightSmall", 50, -28, RW - 60)
        c.sends = Text(c, "", "GameFontDisableSmall", 50, -50, 250)
        c.toggle = Button(c, L.MS_TURN_OFF, 76, RW - 246, -44, function()
            local card = c.id and MS.Get(c.id)
            if card then MS.SetOn(card.id, not card.on) end
        end, 20)
        c.edit = Button(c, L.MS_EDIT, 70, RW - 166, -44, function()
            local card = c.id and MS.Get(c.id)
            if card then p.OpenEditor(card) end
        end, 20)
        -- Delete asks once: the first click turns it into "Sure?".
        c.delete = Button(c, L.MS_DELETE, 76, RW - 92, -44, function(self)
            if not c.id then return end
            if self.sure then MS.Delete(c.id); self.sure = nil
            else self.sure = c.id; self:SetText(L.MS_SURE) end
        end, 20)
        p.msCards[i] = c
    end
    p.msOffset = 0
    p.msPager = UI.Pager(f, RW + RX - 142, -368, function(d) p.msOffset = math.max(0, p.msOffset + d * CARDS); UI.Dirty() end)
end

local function RefreshList(p)
    local MS = ns.Milestones
    local list = MS.List()
    local off = math.min(p.msOffset, math.max(0, #list - CARDS))
    p.msOffset = off
    p.msNone:SetShown(#list == 0)
    p.msPager.Set(off + 1, math.min(#list, off + CARDS), #list)
    for i, c in ipairs(p.msCards) do
        local card = list[off + i]
        if card then
            if c.id ~= card.id then c.delete.sure = nil end
            c.id = card.id
            c.icon:SetTexture(MS.ICON[card.ty])
            c.title:SetText(MS.Describe(card))
            c.state:SetText(card.on and (ns.GREEN .. L.MS_ON .. "|r") or (ns.GREY .. L.MS_OFF .. "|r"))
            c.msg:SetText(MS.Preview(card.m, card))
            c.sends:SetText(Sends(card))
            c.toggle:SetText(card.on and L.MS_TURN_OFF or L.MS_TURN_ON)
            c.delete:SetText(c.delete.sure == card.id and L.MS_SURE or L.MS_DELETE)
            c.SetActive(card.on)
            c:Show()
        else
            c.id = nil
            c:Hide()
        end
    end
end

---------------------------------------------------------------------------------------------------
-- Milestones: the editor

local function BuildEditor(p, v)
    local MS = ns.Milestones
    local f = CreateFrame("Frame", nil, v)
    f:SetAllPoints()
    f:Hide()
    p.msForm = f
    local e = {}
    p.msE = e

    Text(f, L.MS_WHEN, "GameFontHighlight", RX + 4, -32)
    local labels = {}
    for i, ty in ipairs(MS.TYPES) do labels[i] = L.MS_TYPE[ty] end
    e.pickType = UI.Choice(f, labels, RX + 4, -50, 92, function(i)
        local t = p.msEdit
        if not t then return end
        -- {prof} or {title} stayed in the box after switching to, say, Legendary.
        if t.ty ~= MS.TYPES[i] then e.msg:SetText("") end
        t.ty = MS.TYPES[i]
        UI.Dirty()
    end)

    -- The value row changes with the type.
    local y = -84
    e.lvlLabel = Text(f, L.MS_LEVEL_LABEL, "GameFontHighlight", RX + 4, y - 4)
    e.level = EditBox(f, RX + 100, y, 44, 2, true)
    e.skillLabel = Text(f, L.MS_SKILL_LABEL, "GameFontHighlight", RX + 4, y - 4)
    e.skill = EditBox(f, RX + 100, y, 44, 3, true)
    e.inLabel = Text(f, L.MS_IN, "GameFontHighlight", RX + 160, y - 4)
    local profLabels = {}
    for i, pr in ipairs(MS.PROFS) do profLabels[i] = pr == "any" and L.MS_PROF_ANY or pr end
    e.prof = UI.Menu(f, RX + 180, y, 160, profLabels, function(i) if p.msEdit then p.msEdit.p = MS.PROFS[i]; UI.Dirty() end end, 18)
    e.rideText = Text(f, L.MS_RIDE_TEXT, "GameFontHighlight", RX + 4, y - 4, RW - 8)
    e.legText = Text(f, L.MS_LEG_TEXT, "GameFontHighlight", RX + 4, y - 4, RW - 8)
    e.titleLabel = Text(f, L.MS_TITLE_LABEL, "GameFontHighlight", RX + 4, y - 4)
    e.pickTitle, e.titleButtons = UI.Choice(f, { L.MS_TITLE_ANY, L.LORE_MASTER, L.CRAFTY_BUGGER }, RX + 110, y, { 90, 100, 110 },
        function(i) if p.msEdit then p.msEdit.ti = MS.TITLES[i]; UI.Dirty() end end)
    e.titleNote = Text(f, L.MS_TITLE_NOTE, "GameFontDisableSmall", RX + 4, y - 26, RW - 8)

    Text(f, L.MS_MESSAGE, "GameFontHighlight", RX + 4, -134)
    e.msg = EditBox(f, RX + 70, -130, RW - 80, MS.MAX_MSG)
    Text(f, L.MS_FILLINS, "GameFontDisableSmall", RX + 4, -162)
    e.fills = FillButtons(f, RX + 140, -158, e.msg, { "name", "class", "level", "prof", "skill", "item", "title" })
    Text(f, L.MS_PREVIEW, "GameFontHighlight", RX + 4, -192)
    e.preview = Text(f, "", "GameFontHighlight", RX + 70, -192, RW - 76)
    e.preview:SetWordWrap(true)
    e.preview:SetHeight(44)
    e.preview:SetJustifyV("TOP")
    Text(f, L.MS_TAG_NOTE, "GameFontDisableSmall", RX + 70, -238, RW - 76)

    Text(f, L.MS_SENDS, "GameFontHighlight", RX + 4, -262)
    e.gc = UI.Check(f, L.MS_TO_GUILD, RX + 90, -256, true, function(on) if p.msEdit then p.msEdit.gc = on end end)
    e.pu = UI.Check(f, L.MS_TO_POPUP, RX + 90, -278, false, function(on) if p.msEdit then p.msEdit.pu = on end end)
    e.on = UI.Check(f, L.MS_CARD_ON, RX + 4, -304, true, function(on) if p.msEdit then p.msEdit.on = on end end)

    e.save = Button(f, L.MS_SAVE, 100, RX + 4, -334, function()
        local t = p.msEdit
        if not t then return end
        t.m = e.msg:GetText()
        t.v = t.ty == "lvl" and tonumber(e.level:GetText()) or (t.ty == "prof" and tonumber(e.skill:GetText()) or nil)
        local card, why = MS.Save(t)
        if not card then
            ns.Print(why == "full" and string.format(L.MS_FULL, MS.MAX_CARDS) or why == "rank" and L.MS_NOT_MANAGER
                or string.format(L.MS_BAD, MS.MAX_LEVEL))
            return
        end
        p.msEdit = nil
        UI.Dirty()
    end, 24)
    e.cancel = Button(f, L.MS_CANCEL, 90, RX + 110, -334, function() p.msEdit = nil; UI.Dirty() end, 24)
    -- Test: the message in my own chat window only (nothing is sent).
    e.test = Button(f, L.MS_TEST, 80, RX + 206, -334, function()
        local t = p.msEdit
        if t then print(L.MS_TEST_LINE .. MS.Preview(e.msg:GetText(), t)) end
    end, 24)
    local note = Text(f, L.MS_ADDON_NOTE, "GameFontDisableSmall", RX + 4, -364, RW - 8)
    note:SetWordWrap(true)
    note:SetHeight(28)
    note:SetJustifyV("TOP")

    -- Open the editor on a card (nil = a new one).
    function p.OpenEditor(card)
        local t = card and {} or { ty = "lvl", v = 10, p = "any", ti = "any", m = "", gc = true, pu = true, on = true }
        if card then for k, val in pairs(card) do t[k] = val end end
        t.p, t.ti = t.p or "any", t.ti or "any"
        p.msEdit = t
        for i, ty in ipairs(MS.TYPES) do if ty == t.ty then e.pickType(i) end end
        e.level:SetText(t.ty == "lvl" and tostring(t.v or "") or "10")
        e.skill:SetText(t.ty == "prof" and tostring(t.v or "") or "150")
        for i, pr in ipairs(MS.PROFS) do if pr == t.p then e.prof.Set(i) end end
        for i, ti in ipairs(MS.TITLES) do if ti == t.ti then e.pickTitle(i) end end
        e.msg:SetText(t.m or "")
        e.gc:SetChecked(t.gc and true or false)
        e.pu:SetChecked(t.pu and true or false)
        e.on:SetChecked(t.on and true or false)
        UI.Dirty()
    end
end

local SHOW = {
    lvl = { "lvlLabel", "level" },
    prof = { "skillLabel", "skill", "inLabel", "prof" },
    ride = { "rideText" },
    leg = { "legText" },
    title = { "titleLabel", "pickTitle", "titleNote" },
}
local FILLS = { lvl = { level = true }, prof = { prof = true, skill = true }, leg = { item = true }, title = { title = true } }

local function RefreshEditor(p)
    local MS = ns.Milestones
    local e, t = p.msE, p.msEdit
    local shown = {}
    for _, k in ipairs(SHOW[t.ty] or {}) do shown[k] = true end
    for _, list in pairs(SHOW) do
        for _, k in ipairs(list) do
            local w = e[k]
            if w and type(w) ~= "function" and w.SetShown then
                w:SetShown(shown[k] == true)
            end
        end
    end
    e.prof.menu:SetShown(e.prof.menu:IsShown() and shown.prof == true)
    if e.titleButtons then for _, b in ipairs(e.titleButtons) do b:SetShown(shown.pickTitle == true) end end
    LayFills(e.fills, function(w)
        return w == "name" or w == "class" or (FILLS[t.ty] and FILLS[t.ty][w]) == true
    end)
    local probe = { ty = t.ty, p = t.p, ti = t.ti,
                    v = t.ty == "lvl" and tonumber(e.level:GetText()) or tonumber(e.skill:GetText()) }
    e.preview:SetText(MS.Preview(e.msg:GetText(), probe))
    p.viewTitle:SetText(t.id and L.MS_EDITOR_EDIT or L.MS_EDITOR_NEW)
end

---------------------------------------------------------------------------------------------------
-- Welcome

local function BuildWelcome(p, v)
    local MS = ns.Milestones
    local w = {}
    p.welE = w
    local intro = Text(v, L.MS_WEL_INTRO, "GameFontDisableSmall", RX + 4, -28, RW - 8)
    intro:SetWordWrap(true)
    intro:SetHeight(28)
    intro:SetJustifyV("TOP")
    Text(v, L.MS_MESSAGE, "GameFontHighlight", RX + 4, -68)
    w.msg = EditBox(v, RX + 70, -64, RW - 80, MS.MAX_MSG)
    Text(v, L.MS_FILLINS, "GameFontDisableSmall", RX + 4, -96)
    FillButtons(v, RX + 140, -92, w.msg, { "name" })
    Text(v, L.MS_PREVIEW, "GameFontHighlight", RX + 4, -124)
    -- room for 4 lines (a 200-letter message ran off the edge).
    w.preview = Text(v, "", "GameFontHighlight", RX + 70, -124, RW - 76)
    w.preview:SetWordWrap(true)
    w.preview:SetHeight(58)
    w.preview:SetJustifyV("TOP")
    Text(v, L.MS_TAG_NOTE, "GameFontDisableSmall", RX + 70, -184, RW - 76)
    -- Where it goes: the two ticks together under "Send it to"; then the switch, said plainly.
    Text(v, L.MS_SENDS, "GameFontHighlight", RX + 4, -212)
    w.gc = UI.Check(v, L.MS_TO_GUILD, RX + 90, -206, true, function(on) if p.welT then p.welT.gc = on end end)
    w.pu = UI.Check(v, L.MS_TO_POPUP, RX + 90, -228, false, function(on) if p.welT then p.welT.pu = on end end)
    w.on = UI.Check(v, L.MS_WEL_ON, RX + 4, -258, false, function(on) if p.welT then p.welT.on = on end end)

    Text(v, L.MS_WEL_WHO, "GameFontHighlight", RX + 4, -296)
    local function Step(d)
        local ranks = ns.Board.Ranks()
        local pos = p.welRankPos or 1
        local r = ranks[math.max(1, math.min(#ranks, pos + d))]
        if r and p.welT then p.welT.wr = r.index; UI.Dirty() end
    end
    w.less = Button(v, "<", 24, RX + 100, -292, function() Step(-1) end, 22)
    w.rank = Text(v, "", "GameFontHighlight", RX + 128, -296, 240, "CENTER")
    w.more = Button(v, ">", 24, RX + 372, -292, function() Step(1) end, 22)
    local who = Text(v, L.MS_WEL_WHO_NOTE, "GameFontDisableSmall", RX + 4, -322, RW - 8)
    who:SetWordWrap(true)
    who:SetHeight(28)
    who:SetJustifyV("TOP")
    w.save = Button(v, L.MS_SAVE, 100, RX + 4, -356, function()
        if not p.welT then return end
        p.welT.m = w.msg:GetText()
        if MS.SetWelcome(p.welT) then
            ns.Print(L.MS_WEL_SAVED)
            p.welT = nil
            UI.Dirty()
        else
            ns.Print(MS.CanEdit() and string.format(L.MS_BAD, MS.MAX_LEVEL) or L.MS_NOT_MANAGER)
        end
    end, 24)
end

-- The page holds a working copy (p.welT) until Save; switching cards away and back reloads it.
local function RefreshWelcome(p)
    local MS = ns.Milestones
    local w = p.welE
    if not p.welT then
        local cur = MS.Welcome()
        p.welT = { m = cur.m, on = cur.on, gc = cur.gc, pu = cur.pu, wr = cur.wr }
        w.msg:SetText(cur.m or "")
        w.gc:SetChecked(cur.gc and true or false)
        w.pu:SetChecked(cur.pu and true or false)
        w.on:SetChecked(cur.on and true or false)
    end
    w.preview:SetText(MS.Preview(w.msg:GetText(), nil))
    local ranks = ns.Board.Ranks()
    local pos = 1
    for i, r in ipairs(ranks) do if r.index <= p.welT.wr then pos = i end end
    p.welRankPos = pos
    local r = ranks[pos]
    local name = r and (r.name ~= "" and r.name or ("#" .. r.index)) or ("#" .. p.welT.wr)
    w.rank:SetText(string.format(pos == 1 and L.RANK_ONLY or L.RANK_AND_ABOVE, name))
    w.less:SetEnabled(pos > 1)
    w.more:SetEnabled(pos < #ranks)
end

---------------------------------------------------------------------------------------------------

function UI.GMBuildMilestones(p, v)
    BuildList(p, v)
    BuildEditor(p, v)
end

function UI.GMRefreshMilestones(p)
    local editing = p.msEdit ~= nil
    p.msList:SetShown(not editing)
    p.msForm:SetShown(editing)
    if editing then RefreshEditor(p) else RefreshList(p) end
end

UI.GMBuildWelcome = BuildWelcome
UI.GMRefreshWelcome = RefreshWelcome
