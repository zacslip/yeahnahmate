-- Professions tab, in the Ask tab's layout: "New request" and the views as cards on the left (Recipes,
-- Requests, History; like the Dungeons tab's). On the right, a strip with the
-- profession menu (all, or one of the guild's professions) and the search, then the view: Recipes
-- ("who can make...": Ask opens our whisper box prefilled, Request posts a craft request), Requests
-- (crafters say "I'll make it", the poster marks it done and, when several were on it, ticks who
-- made it) or History. The Crafty Bugger's top 10 is on the Legends tab.
local ADDON, ns = ...
local L = ns.L
local UI = ns.UI
local Text, Button, Row, Header, Box = UI.Text, UI.Button, UI.Row, UI.Header, UI.Box

local MENU_ROWS = 13            -- all professions + up to 12 of the guild's
local ROWS = 10                 -- recipe list rows (section headers count as rows)
local CARDS = 5
local RX, RW = UI.RX, UI.RW     -- the right side
local VIEW_NAMES = { L.WHO_MAKES_TAB, L.REQUESTS, L.HISTORY }

local function FirstName(name) return name:match("^%S+") or name end

local function Ago(secs)
    local mins = math.max(0, math.floor(secs / 60))
    if mins < 60 then return mins .. "m" end
    if mins < 1440 then return math.floor(mins / 60) .. "h" end
    return math.floor(mins / 1440) .. "d"
end

local function MemberName(name)
    local m = ns.Guild.Get(name)
    return m and UI.Name(m, true) or name
end

---------------------------------------------------------------------------------------------------
-- Build

-- "Open your Tailoring window once...": a gold box in the sidebar, under the cards, its
-- border slowly pulsing, while any of my crafting professions hasn't been read.
local NOTE_H = 66
local function BuildNote(p, y)
    local b = Box(p, 0, y, UI.SIDE_W, NOTE_H)
    b:SetBackdropColor(0.35, 0.25, 0, 0.55)
    b.icon = b:CreateTexture(nil, "ARTWORK")
    b.icon:SetSize(22, 22)
    b.icon:SetPoint("TOPLEFT", 8, -8)
    b.icon:SetTexture("Interface\\GossipFrame\\AvailableQuestIcon")
    b.text = Text(b, "", "GameFontNormalSmall", 34, -8, UI.SIDE_W - 42)
    b.text:SetWordWrap(true)
    b.text:SetHeight(NOTE_H - 14)
    b.text:SetJustifyV("TOP")
    b.t = 0
    b:SetScript("OnUpdate", function(self, elapsed)
        self.t = self.t + elapsed
        self:SetBackdropBorderColor(1, 0.82, 0, 0.55 + 0.45 * math.sin(self.t * 3))
    end)
    b:Hide()
    p.note = b
end

-- The sidebar, and the strip's profession menu (was the list down the left).
local function BuildSide(p)
    p.newBtn = Button(p, L.NEW_REQUEST, UI.SIDE_W, 0, 0, function()
        p.pickView(2)
        p.OpenForm({ item = "" })
    end, 34)
    if p.newBtn.SetNormalFontObject and GameFontNormalLarge then p.newBtn:SetNormalFontObject(GameFontNormalLarge) end
    -- The views as cards (like the Dungeons tab). The Crafty Bugger lives on the Legends tab.
    local icons = { "Interface\\Icons\\INV_Misc_Book_09", "Interface\\Icons\\INV_Misc_Note_01", "Interface\\Icons\\INV_Misc_PocketWatch_01" }
    p.viewCards = {}
    for i, name in ipairs(VIEW_NAMES) do
        p.viewCards[i] = UI.SideBox(p, -46 - (i - 1) * 72, icons[i], name, function() p.pickView(i) end)
    end
    local line = p:CreateTexture(nil, "ARTWORK")
    line:SetColorTexture(0.9, 0.76, 0.36, 0.5)
    line:SetPoint("TOPLEFT", 0, -263)
    line:SetSize(UI.SIDE_W, 1)
    -- Opt in to the pop-up for requests I can make (like the Ask alert; off until clicked on).
    p.reqAlert = UI.SideBox(p, -272, "Interface\\Icons\\INV_Misc_Note_01", L.REQ_ALERT_CARD, function()
        ns.settings.pop.request = ns.settings.pop.request ~= true
        ns.Fire("SETTINGS")
        UI.Dirty()
    end)
    p.reqAlert:SetScript("OnEnter", function(self)
        if not GameTooltip then return end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:AddLine(L.REQ_ALERT_TIP, 1, 1, 1, true)
        GameTooltip:Show()
    end)
    p.reqAlert:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
    BuildNote(p, -342)

    p.viewTitle = UI.ViewTitle(p, 150)
    p.profBtn = Button(p, "", 150, RX + 156, 0, function() p.profMenu:SetShown(not p.profMenu:IsShown()) end)
    local menu = Box(p, RX + 156, -24, 260, 8 + MENU_ROWS * 26)
    menu:SetFrameLevel((p:GetFrameLevel() or 1) + 20)
    menu:SetBackdropColor(0, 0, 0, 0.97)
    menu:EnableMouse(true)
    menu:Hide()
    p.profMenu = menu
    p.lineRows = {}
    for i = 1, MENU_ROWS do
        local r = Row(menu, 4, -4 - (i - 1) * 26, 252, 25)
        r.icon = r:CreateTexture(nil, "ARTWORK")
        r.icon:SetSize(20, 20)
        r.icon:SetPoint("LEFT", 3, 0)
        r.name = Text(r, "", "GameFontHighlightSmall", 28, -1, 220)
        r.info = Text(r, "", "GameFontDisableSmall", 28, -13, 220)
        r.sel = r:CreateTexture(nil, "BORDER")
        r.sel:SetAllPoints()
        r.sel:SetColorTexture(1, 0.82, 0, 0.18)
        r.sel:Hide()
        r:SetScript("OnClick", function(self)
            p.line, p.offset, p.reqOffset, p.histOffset = self.line, 0, 0, 0
            menu:Hide()
            UI.Dirty()
        end)
        p.lineRows[i] = r
    end
end

-- The filter buttons and the sections each shows (Prof.CATS).
local FILTERS = {
    { L.F_ALL },
    { L.F_BAGS, bags = true },
    { L.F_ARMOUR, cloth = true, leather = true, mail = true, plate = true, armour = true },
    { L.F_WEAPONS, weapons = true, ammo = true },
    { L.F_POTIONS, potions = true },
    { L.F_FOOD, food = true, bandages = true },
    { L.F_ENCHANTS, enchants = true },
    { L.F_OTHER, goods = true, other = true },
}
local ROW_STEP = 31

-- Item tooltip for a recipe row (the item it makes, or the enchant spell), then the materials it
-- needs and how many of each I carry (green: enough).
local tipRow = nil
local function RecipeTooltip(r)
    if not GameTooltip or not r.rid then return end
    tipRow = r
    GameTooltip:SetOwner(r, "ANCHOR_RIGHT")
    local ok = false
    if r.itemID and GameTooltip.SetItemByID then ok = pcall(GameTooltip.SetItemByID, GameTooltip, r.itemID)
    elseif GameTooltip.SetSpellByID then ok = pcall(GameTooltip.SetSpellByID, GameTooltip, r.rid) end
    if not ok then GameTooltip:AddLine(r.recipe or "") end
    local mats = ns.Prof.Materials(r.rid)
    if mats then
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine(L.PROF_MATS, 1, 0.82, 0)
        for _, m in ipairs(mats) do
            local name = ns.Prof.ItemName(m.id) or L.PROF_MATS_LOADING
            local have = ns.Prof.Carried(m.id)
            local icon = C_Item and C_Item.GetItemIconByID and ns.Public(C_Item.GetItemIconByID(m.id))
            local left = (icon and ("|T" .. icon .. ":14:14|t ") or "") .. name .. " x" .. m.n
            local right = string.format(L.PROF_MATS_HAVE, have)
            if have >= m.n then GameTooltip:AddDoubleLine(left, right, 1, 1, 1, 0.3, 1, 0.4)
            else GameTooltip:AddDoubleLine(left, right, 1, 1, 1, 0.6, 0.6, 0.6) end
        end
    end
    GameTooltip:Show()
end
-- A material's name arrived while its tooltip is up: draw it again.
ns.Listen("ITEM_LOADED", function()
    if tipRow and tipRow:IsShown() and GameTooltip and GameTooltip:IsShown() and GameTooltip:GetOwner() == tipRow then
        RecipeTooltip(tipRow)
    end
end)

local function BuildWho(p)
    local v = CreateFrame("Frame", nil, p)
    v:SetAllPoints()
    p.whoView = v
    p.filter = 1
    p.open = {}                 -- section -> true/false once clicked (else the default for the view)
    local box = CreateFrame("EditBox", nil, v, "InputBoxTemplate")
    box:SetSize(140, 22)
    box:SetPoint("TOPLEFT", RX + 318, 0)
    box:SetAutoFocus(false)
    box:SetMaxLetters(40)
    box:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    box:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
    box:SetScript("OnTextChanged", function() p.offset = 0; wipe(p.open); if p:IsShown() then UI.Dirty() end end)
    box:SetScript("OnEditFocusGained", function() p.hint:Hide() end)
    box:SetScript("OnEditFocusLost", function(self) p.hint:SetShown((self:GetText() or "") == "") end)
    p.search = box
    p.hint = Text(v, L.SEARCH_HINT_SHORT, "GameFontDisableSmall", RX + 322, -6, 134)
    p.count = Text(v, "", "GameFontDisableSmall", RX + 462, -6, 90, "RIGHT")

    -- Filter buttons: one click narrows the list to bags, armour, potions...
    local labels = {}
    for i, f in ipairs(FILTERS) do labels[i] = f[1] end
    p.pickFilter = UI.Choice(v, labels, RX, -26, 65, function(i)
        p.filter, p.offset = i, 0
        wipe(p.open)
        if p:IsShown() then UI.Dirty() end
    end)
    p.pickFilter(1)
    local line = v:CreateTexture(nil, "ARTWORK")
    line:SetColorTexture(0.9, 0.76, 0.36, 0.35)
    line:SetPoint("TOPLEFT", RX, -51)
    line:SetSize(RW, 1)

    -- Each row is either a section header (click to open or close it) or a recipe.
    p.rows = {}
    for i = 1, ROWS do
        local r = Row(v, RX, -54 - (i - 1) * ROW_STEP, RW, ROW_STEP - 1)
        r.band = r:CreateTexture(nil, "BACKGROUND", nil, 1)
        r.band:SetAllPoints()
        r.band:SetColorTexture(1, 0.82, 0, 0.10)
        r.icon = r:CreateTexture(nil, "ARTWORK")
        r.icon:SetSize(26, 26)
        r.icon:SetPoint("LEFT", 3, 0)
        r.item = Text(r, "", "GameFontHighlightSmall", 34, -3, 196)
        r.prof = Text(r, "", "GameFontDisableSmall", 34, -16, 196)
        r.crafters = Text(r, "", "GameFontHighlightSmall", 234, -9, 188)
        r.arrow = r:CreateTexture(nil, "ARTWORK")
        r.arrow:SetSize(14, 14)
        r.arrow:SetPoint("LEFT", 8, 0)
        r.title = Text(r, "", "GameFontNormal", 30, -8, 500)
        -- Request: post it for any crafter. Ask: whisper the first online crafter.
        r.request = Button(r, L.REQUEST, 62, 426, -4, function()
            if r.rid then p.pickView(2); p.OpenForm({ rid = r.rid, item = r.recipe }) end
        end, 22)
        -- Ask (let people pick who): one crafter online goes straight to the whisper box; more
        -- opens a list of them (highest skill first) to pick from.
        r.ask = Button(r, L.ASK, 56, 492, -4, function()
            if not r.recipe or not r.askList or #r.askList == 0 then return end
            if #r.askList == 1 then
                p.askMenu:Hide()
                p.AskCrafter(r.askList[1].name, r.recipe)
            elseif p.askMenu:IsShown() and p.askMenu.row == r then
                p.askMenu:Hide()
            else
                p.ShowAskMenu(r, i)
            end
        end, 22)
        r:SetScript("OnClick", function(self)
            if self.cat then
                p.open[self.cat] = not self.isOpen
                UI.Dirty()
            end
        end)
        r:SetScript("OnEnter", function(self)
            self.hl:Show()
            if not self.cat then RecipeTooltip(self) end
        end)
        r:SetScript("OnLeave", function(self)
            self.hl:Hide()
            if tipRow == self then tipRow = nil end
            if GameTooltip then GameTooltip:Hide() end
        end)
        p.rows[i] = r
    end
    -- The "Ask who?" list, under (or over, near the bottom) the row's Ask button.
    local ASK_ROWS = 8
    local menu = Box(v, 0, 0, 236, 34 + ASK_ROWS * 22)
    menu:SetFrameLevel((v:GetFrameLevel() or 1) + 30)
    menu:SetBackdropColor(0, 0, 0, 0.97)
    menu:EnableMouse(true)
    menu:Hide()
    p.askMenu = menu
    menu.title = Text(menu, L.ASK_WHO, "GameFontNormal", 10, -9, 190)
    Button(menu, "x", 22, 208, -5, function() menu:Hide() end, 20)
    menu.rows = {}
    for j = 1, ASK_ROWS do
        local row = Row(menu, 6, -30 - (j - 1) * 22, 224, 21)
        row.name = Text(row, "", "GameFontHighlightSmall", 6, -4, 150)
        row.info = Text(row, "", "GameFontDisableSmall", 158, -5, 60, "RIGHT")
        row:SetScript("OnClick", function(self)
            menu:Hide()
            if self.who and menu.recipe then p.AskCrafter(self.who, menu.recipe) end
        end)
        menu.rows[j] = row
    end
    function p.AskCrafter(name, recipe)
        local who = ns.Guild.Get(name)
        if who then ns.Whisper.Open(who, string.format(L.ASK_TEXT, FirstName(who.name), recipe)) end
    end
    function p.ShowAskMenu(r, index)
        menu.row, menu.recipe, menu.rid = r, r.recipe, r.rid
        local n = math.min(#r.askList, ASK_ROWS)
        for j, row in ipairs(menu.rows) do
            local e = r.askList[j]
            row.who = e and e.name
            if e then
                local m = ns.Guild.Get(e.name)
                row.name:SetText(m and UI.Name(m) or e.name)
                row.info:SetText(e.skill and e.skill > 0 and string.format(L.ASK_SKILL, e.skill) or "")
                row.stripe:SetColorTexture(1, 1, 1, (j % 2 == 0) and 0.04 or 0)
                row:Show()
            else
                row:Hide()
            end
        end
        menu:SetHeight(36 + n * 22)
        menu:ClearAllPoints()
        if index > ROWS / 2 then
            menu:SetPoint("BOTTOMRIGHT", r.ask, "TOPRIGHT", 0, 2)
        else
            menu:SetPoint("TOPRIGHT", r.ask, "BOTTOMRIGHT", 0, -2)
        end
        menu:Show()
    end

    p.empty = Text(v, "", "GameFontDisableSmall", RX + 6, -62, RW - 12)
    p.empty:SetWordWrap(true)
    p.empty:SetHeight(40)
    p.empty:SetJustifyV("TOP")
    p.foot = Text(v, "", "GameFontDisableSmall", RX + 4, -366, 400)
    p.foot:SetWordWrap(true)
    p.foot:SetHeight(28)
    p.foot:SetJustifyV("TOP")
    p.pager = UI.Pager(v, 594, -364, function(d) p.offset = math.max(0, p.offset + d * ROWS); UI.Dirty() end)
end

local function BuildRequests(p)
    local v = CreateFrame("Frame", nil, p)
    v:SetAllPoints()
    p.reqView = v

    p.cards = {}
    for i = 1, CARDS do
        local c = Box(v, RX, -30 - (i - 1) * 64, RW, 60)
        c.item = Text(c, "", "GameFontNormal", 10, -8, 300)
        c.when = Text(c, "", "GameFontDisableSmall", 378, -9, 164, "RIGHT")
        c.who = Text(c, "", "GameFontHighlightSmall", 10, -25, 532)
        c.status = Text(c, "", "GameFontHighlightSmall", 10, -41, 300)
        -- Done: with two or more on it, first tick who made it (the Crafty Bugger's points).
        c.done = Button(c, L.DONE, 64, 402, -34, function()
            if not c.key then return end
            local pick = p.picking
            if pick and pick.key == c.key then
                local mk = {}
                for name in pairs(pick.mk) do mk[#mk + 1] = name end
                p.picking = nil
                ns.Requests.Finish(c.key, "done", mk)
                return
            end
            local store = ns.Requests.Store()
            local r = store and store[c.key]
            if r and #ns.Requests.Claimers(r) >= 2 then
                p.picking = { key = c.key, mk = {} }
                UI.Dirty()
            else
                p.picking = nil
                ns.Requests.Finish(c.key, "done")
            end
        end, 20)
        c.cancel = Button(c, L.CANCEL, 72, 470, -34, function()
            if not c.key then return end
            if p.picking and p.picking.key == c.key then p.picking = nil; UI.Dirty(); return end
            ns.Requests.Finish(c.key, "cancel")
        end, 20)
        -- One tick per guildie on it, up to five (the most a request can credit, Requests.lua).
        c.makers = {}
        for j = 1, 5 do
            local box, label = UI.Check(c, "", 6 + (j - 1) * 78, -36, false, function(on)
                local pick, name = p.picking, c.makers[j].name
                if pick and name then pick.mk[name] = on or nil end
            end)
            label:SetWidth(48)
            label:SetWordWrap(false)
            label:SetJustifyH("LEFT")
            c.makers[j] = { box = box, label = label }
        end
        c.claim = Button(c, L.ILL_MAKE_IT, 92, 374, -34, function() if c.key then ns.Requests.Claim(c.key, not c.claimed) end end, 20)
        c.whisper = Button(c, L.WHISPER, 70, 472, -34, function()
            local m = c.owner and ns.Guild.Get(c.owner)
            if m then ns.Whisper.Open(m, string.format(L.REQUEST_WHISPER, FirstName(m.name), c.itemName or "")) end
        end, 20)
        c.modX = UI.ModRemove(c, RW - 72, -5, function() return c.key end, function(k) ns.Requests.ModRemove(k) end)
        c:EnableMouseWheel(true)
        c:SetScript("OnMouseWheel", function(_, delta) p.reqOffset = math.max(0, (p.reqOffset or 0) - delta); UI.Dirty() end)
        p.cards[i] = c
    end
    p.reqEmpty = Text(v, L.NO_REQUESTS, "GameFontDisableSmall", RX + 6, -36, RW - 12)
    p.reqEmpty:SetWordWrap(true)
    p.reqEmpty:SetHeight(40)
    p.reqEmpty:SetJustifyV("TOP")
    p.reqPager = UI.Pager(v, 594, -352, function(d) p.reqOffset = math.max(0, (p.reqOffset or 0) + d * CARDS); UI.Dirty() end)
    p.reqFoot = Text(v, L.REQUESTS_FOOT, "GameFontDisableSmall", RX + 4, -356, 400)
    p.reqFoot:SetWordWrap(true)
    p.reqFoot:SetHeight(40)
    p.reqFoot:SetJustifyV("TOP")

    -- The new-request form (over the list).
    local f = CreateFrame("Frame", nil, v)
    f:SetAllPoints()
    f:Hide()
    p.formFrame = f
    -- Opens it empty (a cancelled one's text doesn't come back), with the recipe if one was picked.
    function p.OpenForm(form)
        p.form = form
        f.item:SetText(form.rid and "" or (form.item or ""))
        f.note:SetText("")
        UI.Dirty()
    end
    Header(f, L.NEW_REQUEST, RX, -30, RW)
    Text(f, L.REQUEST_ITEM, "GameFontHighlightSmall", RX + 4, -58)
    f.item = CreateFrame("EditBox", nil, f, "InputBoxTemplate")
    f.item:SetSize(300, 20)
    f.item:SetPoint("TOPLEFT", RX + 110, -54)
    f.item:SetAutoFocus(false)
    f.item:SetMaxLetters(50)
    f.item:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    f.item:SetScript("OnEnterPressed", function(self)
        -- Enter picks the first suggestion, if there is one.
        local first = f.sugg[1]
        if first:IsShown() and first.id then first:Click() end
        self:ClearFocus()
    end)
    f.item:SetScript("OnTextChanged", function(self, userInput) if userInput then UI.Dirty() end end)
    -- Drop an item from your bags on the box: its name, and the recipe if a guildie knows it.
    local function TakeDrop()
        if not p.form then return end
        local kind, _, link = GetCursorInfo()
        if kind ~= "item" or type(link) ~= "string" then return end
        local name = link:match("%[(.-)%]")
        ClearCursor()
        if not name then return end
        local rid = ns.Requests.RecipeFor(name)
        p.form.rid, p.form.item = rid, name
        f.item:SetText(name)
        f.item:ClearFocus()
        UI.Dirty()
    end
    f.item:SetScript("OnReceiveDrag", TakeDrop)
    f.item:SetScript("OnMouseUp", function() if GetCursorInfo() then TakeDrop() end end)
    f.fixed = Text(f, "", "GameFontNormal", RX + 112, -58, 290)
    -- Under the picked item, on its own line (it was cut off after the name).
    f.pickedNote = Text(f, ns.GREEN .. L.RECIPE_PICKED .. "|r", "GameFontHighlightSmall", RX + 112, -76, 370)
    f.change = Button(f, L.CHANGE, 70, RX + 410, -55, function()
        if not p.form then return end
        p.form.rid, p.form.item = nil, nil
        f.item:SetText("")
        UI.Dirty()
    end, 20)
    f.dropHint = Text(f, L.REQUEST_ITEM_HINT, "GameFontDisableSmall", RX + 112, -76, 370)

    -- Suggestions as you type: recipes from the guild's lists (and mine). Click one to pick it.
    f.suggBox = Box(f, RX + 106, -74, 380, 6 * 22 + 8)
    f.suggBox:SetFrameLevel((f:GetFrameLevel() or 1) + 20)
    f.suggBox:SetBackdropColor(0, 0, 0, 0.95)
    f.suggBox:Hide()
    f.sugg = {}
    for i = 1, 6 do
        local r = Row(f.suggBox, 4, -4 - (i - 1) * 22, 372, 21)
        r.name = Text(r, "", "GameFontHighlightSmall", 4, -4, 230)
        r.info = Text(r, "", "GameFontDisableSmall", 236, -4, 132, "RIGHT")
        r:SetScript("OnClick", function(self)
            if not self.id or not p.form then return end
            p.form.rid, p.form.item = self.id, self.recipe
            f.item:SetText(self.recipe)
            f.item:ClearFocus()
            UI.Dirty()
        end)
        f.sugg[i] = r
    end
    Text(f, L.REQUEST_HOW_MANY, "GameFontHighlightSmall", RX + 4, -88)
    f.minus = Button(f, "-", 20, RX + 104, -84, function() if p.form then p.form.n = math.max(1, (p.form.n or 1) - 1); UI.Dirty() end end, 20)
    -- The number can be typed too (1-20): click it, type, Enter or click away.
    f.n = CreateFrame("EditBox", nil, f, "InputBoxTemplate")
    f.n:SetSize(22, 20)
    f.n:SetPoint("TOPLEFT", RX + 131, -84)
    f.n:SetAutoFocus(false)
    f.n:SetNumeric(true)
    f.n:SetMaxLetters(2)
    f.n:SetJustifyH("CENTER")
    local function TypedCount(self)
        if not p.form then return end
        local n = math.floor(tonumber(self:GetText()) or 0)
        p.form.n = math.max(1, math.min(20, n))
        self:SetText(tostring(p.form.n))
        self:ClearFocus()
        UI.Dirty()
    end
    f.n:SetScript("OnEnterPressed", TypedCount)
    f.n:SetScript("OnEditFocusLost", TypedCount)
    f.n:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    f.plus = Button(f, "+", 20, RX + 156, -84, function() if p.form then p.form.n = math.min(20, (p.form.n or 1) + 1); UI.Dirty() end end, 20)
    Text(f, L.NOTE, "GameFontHighlightSmall", RX + 4, -118)
    f.note = CreateFrame("EditBox", nil, f, "InputBoxTemplate")
    f.note:SetSize(370, 20)
    f.note:SetPoint("TOPLEFT", RX + 110, -114)
    f.note:SetAutoFocus(false)
    f.note:SetMaxLetters(80)
    f.note:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    f.note:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
    f.noteHint = Text(f, L.REQUEST_NOTE_HINT, "GameFontDisableSmall", RX + 112, -138, 370)
    f.post = Button(f, L.POST, 110, RX, -164, function()
        -- A typed name that matches a recipe exactly is linked to it (so its crafters hear about it).
        if not p.form then return end
        local typed = f.item:GetText() or ""
        local rid = p.form.rid or ns.Requests.RecipeFor(typed)
        local key, why = ns.Requests.Post(rid, typed, p.form.n or 1, f.note:GetText() or "")
        if key then
            p.form = nil
            f.item:SetText(""); f.note:SetText("")
            UI.Dirty()
        else
            ns.Print(why == "full" and L.REQUEST_FULL or L.REQUEST_NEEDS_ITEM)
        end
    end, 24)
    f.cancel = Button(f, L.CANCEL, 90, RX + 120, -164, function() p.form = nil; UI.Dirty() end, 24)
    local tip = Text(f, L.REQUEST_TIP, "GameFontDisableSmall", RX + 4, -200, RW - 8)
    tip:SetWordWrap(true)
    tip:SetHeight(56)
    tip:SetJustifyV("TOP")
end

-- History: finished requests and each guildie's record, so the system isn't abused.
local HROWS = 11
local OUTCOME = { done = "|cff40ff40", cancel = "|cff9d9d9d", expired = "|cffff8040" }

local function BuildHistory(p)
    local v = CreateFrame("Frame", nil, p)
    v:SetAllPoints()
    p.histView = v
    p.histOffset = 0
    local box = CreateFrame("EditBox", nil, v, "InputBoxTemplate")
    box:SetSize(226, 22)
    box:SetPoint("TOPLEFT", RX + 318, 0)
    box:SetAutoFocus(false)
    box:SetMaxLetters(40)
    box:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    box:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
    box:SetScript("OnTextChanged", function(self)
        p.histHint:SetShown((self:GetText() or "") == "")
        p.histOffset = 0
        if p:IsShown() then UI.Dirty() end
    end)
    p.histFilter = box
    p.histHint = Text(v, L.HISTORY_FILTER_HINT, "GameFontDisableSmall", RX + 322, -6, 220)
    p.histSummary = Text(v, "", "GameFontHighlightSmall", RX + 4, -30, RW - 8)
    p.histSummary:SetWordWrap(true)
    p.histSummary:SetHeight(26)
    p.histSummary:SetJustifyV("TOP")
    p.histRows = {}
    for i = 1, HROWS do
        local r = Row(v, RX, -58 - (i - 1) * 26, RW, 24)
        r.item = Text(r, "", "GameFontHighlightSmall", 4, -1, 392)
        r.when = Text(r, "", "GameFontDisableSmall", 402, -1, 146, "RIGHT")
        r.what = Text(r, "", "GameFontDisableSmall", 4, -12, 544)
        -- Click a row to see that guildie's record.
        r:SetScript("OnClick", function(self)
            if self.owner then box:SetText(self.owner); UI.Dirty() end
        end)
        p.histRows[i] = r
    end
    p.histEmpty = Text(v, L.HISTORY_EMPTY, "GameFontDisableSmall", RX + 6, -64, RW - 12)
    p.histPager = UI.Pager(v, 594, -350, function(d) p.histOffset = math.max(0, p.histOffset + d * HROWS); UI.Dirty() end)
end

local function RefreshHistory(p)
    local R = ns.Requests
    local filter = p.histFilter:GetText() or ""
    local who = R.WhoIs(filter)
    if who then
        local s = R.Record(who)
        local m = ns.Guild.Get(who)
        p.histSummary:SetText(string.format(L.RECORD, m and UI.Name(m) or who, s.asked, s.done, s.cancel, s.expired, s.open, s.made)
            .. (s.letDown > 0 and ("  " .. "|cffff8040" .. string.format(L.RECORD_LETDOWN, s.letDown) .. "|r") or ""))
    else
        local list = R.History(p.line, "")
        local n = { done = 0, cancel = 0, expired = 0 }
        for _, r in ipairs(list) do n[R.Outcome(r)] = n[R.Outcome(r)] + 1 end
        p.histSummary:SetText(string.format(L.HISTORY_SUMMARY, #list, n.done, n.cancel, n.expired))
    end
    local list = R.History(p.line, who and "" or filter)
    if who then
        local mine = {}
        for _, r in ipairs(list) do if r.owner == who or (r.cl and r.cl[who]) then mine[#mine + 1] = r end end
        list = mine
    end
    local now = GetServerTime()
    local off = math.min(p.histOffset, math.max(0, #list - HROWS))
    p.histOffset = off
    p.histEmpty:SetShown(#list == 0)
    p.histPager.Set(off + 1, math.min(#list, off + HROWS), #list)
    for i, row in ipairs(p.histRows) do
        local r = list[off + i]
        row.owner = r and r.owner
        if r then
            local outcome = R.Outcome(r)
            row.item:SetText(R.ItemName(r) .. (r.n > 1 and (ns.GREY .. "  x" .. r.n .. "|r") or "")
                .. "   " .. ns.GREY .. L.ASKED_BY .. "|r " .. MemberName(r.owner))
            row.when:SetText(string.format(L.AGO, Ago(now - r.ended)))
            local claimers = R.Claimers(r)
            local names = {}
            local made = (outcome == "done" and r.mk) and R.Makers(r) or claimers
            for _, n in ipairs(outcome == "done" and made or claimers) do names[#names + 1] = MemberName(n) end
            local text = OUTCOME[outcome] .. (L["OUTCOME_" .. outcome:upper()]) .. "|r"
            if outcome == "done" and #names > 0 then
                text = text .. "  " .. string.format(L.MADE_BY, table.concat(names, ", "))
            elseif outcome == "expired" and #names > 0 then
                text = text .. "  " .. "|cffff8040" .. string.format(L.SAID_THEYD_MAKE, table.concat(names, ", ")) .. "|r"
            end
            row.what:SetText(text)
            row.stripe:SetColorTexture(1, 1, 1, (i % 2 == 0) and 0.04 or 0)
            row:Show()
        else
            row:Hide()
        end
    end
end

local thePage
local function Build(p)
    thePage = p
    p.line = nil                -- nil = all professions
    p.offset, p.reqOffset = 0, 0
    p.view = 1
    p.histOffset = 0
    function p.pickView(i)
        p.view = i
        p.picking, p.form = nil, nil
        if p.profMenu then p.profMenu:Hide() end
        if p.askMenu then p.askMenu:Hide() end
        if p:IsShown() then UI.Dirty() end
    end
    BuildSide(p)
    BuildWho(p)
    BuildRequests(p)
    BuildHistory(p)
    p.pickView(1)
    p:EnableMouseWheel(true)
    p:SetScript("OnMouseWheel", function(_, delta)
        if p.view == 1 then p.offset = math.max(0, p.offset - delta * 3)
        elseif p.view == 2 then p.reqOffset = math.max(0, p.reqOffset - delta)
        elseif p.view == 3 then p.histOffset = math.max(0, p.histOffset - delta * 3) end
        UI.Dirty()
    end)
end

---------------------------------------------------------------------------------------------------
-- Refresh

local function RefreshSide(p)
    local P, R = ns.Prof, ns.Requests
    p.viewTitle:SetText(VIEW_NAMES[p.view] or "")
    for i, c in ipairs(p.viewCards) do c.SetPicked(i == p.view) end
    local on = ns.settings.pop.request == true
    p.reqAlert.SetActive(on)
    p.reqAlert.text:SetText(on and (ns.GREEN .. L.Q_ALERT_ON .. "|r") or (ns.GREY .. L.Q_ALERT_OFF .. "|r"))
    p.reqAlert.pts:SetText(on and L.Q_ALERT_CLICK_OFF or L.Q_ALERT_CLICK_ON)
    -- Recipes: which professions, how many recipes or crafters.
    local rc = p.viewCards[1]
    local entry = p.line and P.lines[p.line]
    if entry then
        rc.icon:SetTexture(P.LineIcon(p.line))
        rc.text:SetText(P.LineName(p.line))
        local n = 0
        for _ in pairs(entry) do n = n + 1 end
        rc.pts:SetText(string.format(L.PROF_CARD_LINE, n or 0))
    else
        rc.icon:SetTexture("Interface\\Icons\\INV_Misc_Book_09")
        rc.text:SetText(L.PROF_ALL)
        rc.pts:SetText(string.format(L.PROF_CARD_ALL, P.RecipeCount()))
    end
    -- Requests: how many open, how many I could make.
    local open, canMake = R.List(p.line), 0
    for _, r in ipairs(open) do if r.owner ~= ns.me and R.ICanMake(r) then canMake = canMake + 1 end end
    p.viewCards[2].text:SetText(#open > 0 and string.format(L.REQ_CARD_OPEN, #open) or (ns.GREY .. L.REQ_CARD_NONE .. "|r"))
    p.viewCards[2].pts:SetText(canMake > 0 and (ns.GOLD .. string.format(L.REQ_CARD_CAN, canMake) .. "|r") or "")
    -- History: how many finished, how many made.
    local hist, made = R.History(p.line, ""), 0
    for _, r in ipairs(hist) do if R.Outcome(r) == "done" then made = made + 1 end end
    p.viewCards[3].text:SetText(string.format(L.HIST_CARD_N, #hist))
    p.viewCards[3].pts:SetText(string.format(L.HIST_CARD_MADE, made))
    local unread = P.Sharing() and P.Unread() or {}
    if #unread > 0 then
        local names = #unread == 1 and unread[1]
            or (table.concat(unread, ", ", 1, #unread - 1) .. " " .. L.AND .. " " .. unread[#unread])
        p.note.text:SetText(string.format(#unread == 1 and L.PROF_OPEN_YOURS or L.PROF_OPEN_YOURS_N, names))
    end
    p.note:SetShown(#unread > 0)
    local lines = P.Lines()
    for i, r in ipairs(p.lineRows) do
        local item = (i == 1) and { all = true } or lines[i - 1]
        if item then
            if item.all then
                r.line = nil
                r.icon:SetTexture("Interface\\Icons\\INV_Misc_Book_09")
                r.name:SetText(L.PROF_ALL)
                r.info:SetText(string.format(L.PROF_ALL_INFO, P.RecipeCount()))
            else
                r.line = item.line
                r.icon:SetTexture(P.LineIcon(item.line))
                r.name:SetText(P.LineName(item.line))
                r.info:SetText(string.format(L.PROF_INFO, item.count, item.count == 1 and L.GUILDIE or L.GUILDIES, item.top))
            end
            r.sel:SetShown(r.line == p.line)
            r.stripe:SetColorTexture(1, 1, 1, (i % 2 == 0) and 0.04 or 0)
            r:Show()
        else
            r:Hide()
        end
    end
    if p.line and not P.lines[p.line] then p.line = nil end
    p.profBtn:SetText((p.line and P.LineName(p.line) or L.PROF_ALL) .. "  v")
end

-- The rows to show: section headers, and the recipes of open sections. With nothing searched or
-- filtered, sections start closed (a short list of what the guild makes); otherwise open.
-- Two passes: count each section (no tables), then gather recipes only for open sections. With
-- every section closed (the usual first look), a 600-crafter guild's ~5000 recipes cost one loop.
local counts, gathered = {}, {}
local function WhoRows(p, list, query)
    local filter = FILTERS[p.filter] or FILTERS[1]
    local all = p.filter == 1
    wipe(counts)
    local total = 0
    for _, e in ipairs(list) do
        if all or filter[e.cat] then
            counts[e.cat] = (counts[e.cat] or 0) + 1
            total = total + 1
        end
    end
    local openByDefault = query ~= "" or not all or total <= 15
    local rows, anyOpen = {}, false
    local isOpen = {}
    for _, cat in ipairs(ns.Prof.CATS) do
        if counts[cat] then
            local open = p.open[cat]
            if open == nil then open = openByDefault end
            isOpen[cat] = open
            if open then anyOpen = true end
        end
    end
    wipe(gathered)
    if anyOpen then
        for _, e in ipairs(list) do
            if isOpen[e.cat] and (all or filter[e.cat]) then
                local c = gathered[e.cat]
                if not c then c = {}; gathered[e.cat] = c end
                c[#c + 1] = e
            end
        end
    end
    for _, cat in ipairs(ns.Prof.CATS) do
        if counts[cat] then
            rows[#rows + 1] = { header = cat, n = counts[cat], open = isOpen[cat] }
            local c = gathered[cat]
            if c then for _, e in ipairs(c) do rows[#rows + 1] = e end end
        end
    end
    return rows, total
end

-- The item's quality colour (green, blue...), or nil for white/unknown.
local function QualityHex(item)
    if not item or not C_Item or not C_Item.GetItemQualityByID then return nil end
    local ok, q = pcall(C_Item.GetItemQualityByID, item)
    q = ok and ns.Public(q, "number") or nil
    if not q or q == 1 then return nil end
    local c = ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[q]
    local hex = c and ns.Public(c.hex, "string")
    return hex and hex:gsub("^|c", "") or nil
end

local function RefreshWho(p)
    local P = ns.Prof
    -- The Ask list goes when its row now shows something else (a search, a scroll).
    if p.askMenu:IsShown() and (not p.askMenu.row:IsShown() or p.askMenu.row.rid ~= p.askMenu.rid) then p.askMenu:Hide() end
    local query = p.search:GetText() or ""
    p.hint:SetShown(query == "" and not p.search:HasFocus())
    local list, total = WhoRows(p, P.Search(p.line, query), query)
    local maxOffset = math.max(0, #list - ROWS)
    if p.offset > maxOffset then p.offset = maxOffset end
    p.count:SetText(string.format(L.FOUND, total))
    p.pager.Set(p.offset + 1, math.min(#list, p.offset + ROWS), #list)
    local empty = ""
    if total == 0 then empty = (query == "" and p.filter == 1) and L.PROF_EMPTY or L.PROF_NONE_HERE end
    p.empty:SetText(empty)
    for i, r in ipairs(p.rows) do
        local e = list[p.offset + i]
        local header = e ~= nil and e.header ~= nil
        if e then
            r.band:SetShown(header)
            r.arrow:SetShown(header)
            r.title:SetShown(header)
            r.icon:SetShown(not header)
            r.item:SetShown(not header)
            r.prof:SetShown(not header)
            r.crafters:SetShown(not header)
            r.request:SetShown(not header)
            r.ask:SetShown(not header)
        end
        if header then
            r.cat, r.isOpen = e.header, e.open
            r.rid, r.recipe, r.itemID, r.askTo, r.askList = nil, nil, nil, nil, nil
            r.arrow:SetTexture(e.open and "Interface\\Buttons\\UI-MinusButton-Up" or "Interface\\Buttons\\UI-PlusButton-Up")
            r.title:SetText((L["CAT_" .. e.header:upper()] or e.header) .. ns.GREY .. "  (" .. e.n .. ")|r")
            r.stripe:SetColorTexture(1, 1, 1, 0)
            r:Show()
        elseif e then
            r.cat, r.isOpen = nil, nil
            r.recipe, r.rid, r.itemID = e.name, e.id, e.item
            r.icon:SetTexture(e.icon)
            local hex = QualityHex(e.item)
            r.item:SetText(hex and ("|c" .. hex .. e.name .. "|r") or e.name)
            r.prof:SetText(P.LineName(e.line))
            local people = {}
            for _, name in ipairs(e.crafters) do
                local m = ns.Guild.Get(name)
                if m then people[#people + 1] = m end
            end
            table.sort(people, function(a, b)
                local am, bm = a.name == ns.me, b.name == ns.me
                if am ~= bm then return bm end
                if a.online ~= b.online then return a.online end
                return a.name < b.name
            end)
            local shown = {}
            for j, m in ipairs(people) do
                if j > 3 then shown[#shown + 1] = ns.GREY .. "+" .. (#people - 3) .. "|r"; break end
                shown[#shown + 1] = (m.name == ns.me) and (ns.GREY .. L.YOU .. "|r") or UI.Name(m, true)
            end
            r.crafters:SetText(table.concat(shown, ", "))
            -- Who Ask can whisper: the crafters online (not me), highest skill first.
            local skills = P.lines[e.line] or {}
            local askList = {}
            for _, m in ipairs(people) do
                if m.online and m.name ~= ns.me then askList[#askList + 1] = { name = m.name, skill = skills[m.name] or 0 } end
            end
            table.sort(askList, function(a, b)
                if a.skill ~= b.skill then return a.skill > b.skill end
                return a.name < b.name
            end)
            r.askList = askList
            r.askTo = askList[1] and askList[1].name
            r.ask:SetEnabled(#askList > 0)
            r.ask:SetText(#askList > 1 and string.format(L.ASK_N, #askList) or L.ASK)
            r.stripe:SetColorTexture(1, 1, 1, (i % 2 == 0) and 0.04 or 0)
            r:Show()
        else
            r:Hide()
        end
    end
    local foot = L.PROF_FOOT
    if not P.Sharing() and next(P.MyData().profs) then foot = L.PROF_YOURS_HIDDEN end
    p.foot:SetText(foot)
end

local function RefreshRequests(p)
    local R = ns.Requests
    local inForm = p.form ~= nil
    p.formFrame:SetShown(inForm)
    p.reqFoot:SetShown(not inForm)
    if inForm then
        for _, c in ipairs(p.cards) do c:Hide() end
        p.reqEmpty:Hide()
        p.reqPager.Set(1, 1, 1)
        local f, form = p.formFrame, p.form
        local fixed = form.rid ~= nil
        f.item:SetShown(not fixed)
        f.fixed:SetShown(fixed)
        f.change:SetShown(fixed)
        f.dropHint:SetShown(not fixed)
        f.fixed:SetText(fixed and (form.item or "") or "")
        f.pickedNote:SetShown(fixed)
        -- Suggestions while typing (two letters or more).
        local typed = (not fixed) and strtrim(f.item:GetText() or "") or ""
        local found = (#typed >= 2) and ns.Prof.Search(nil, typed) or {}
        if #found == 1 and strlower(found[1].name) == strlower(typed) then found = {} end   -- already exact
        f.suggBox:SetShown(#found > 0)
        for i, r in ipairs(f.sugg) do
            local e = found[i]
            r.id, r.recipe = e and e.id, e and e.name
            if e then
                r.name:SetText(e.name)
                r.info:SetText(ns.Prof.LineName(e.line) .. "  " .. ns.GREY .. string.format(L.N_CRAFTERS, #e.crafters) .. "|r")
                r:Show()
            else
                r:Hide()
            end
        end
        if not f.n:HasFocus() then f.n:SetText(tostring(form.n or 1)) end
        f.minus:SetEnabled((form.n or 1) > 1)
        f.plus:SetEnabled((form.n or 1) < 20)
        return
    end
    local list = R.List(p.line)
    local now = GetServerTime()
    local off = math.min(p.reqOffset or 0, math.max(0, #list - CARDS))
    p.reqOffset = off
    p.reqEmpty:SetShown(#list == 0)
    p.reqPager.Set(off + 1, math.min(#list, off + CARDS), #list)
    for i, c in ipairs(p.cards) do
        local r = list[off + i]
        c.key = r and r.key
        if r then
            local name = R.ItemName(r)
            local mine = r.owner == ns.me
            c.owner, c.itemName = r.owner, name
            c.item:SetText(name .. (r.n > 1 and (ns.GREY .. "  x" .. r.n .. "|r") or ""))
            c.when:SetText(string.format(L.POSTED_AGO, Ago(now - (r.at or now))))
            local line = R.Line(r)
            c.who:SetText(string.format(L.REQUEST_FOR, mine and L.YOU or MemberName(r.owner))
                .. (line and (ns.GREY .. "  " .. ns.Prof.LineName(line) .. "|r") or "")
                .. (r.note ~= "" and ("   \"" .. r.note .. "\"") or ""))
            local claimers = R.Claimers(r)
            c.claimed = r.cl and r.cl[ns.me] ~= nil
            local status
            if #claimers > 0 then
                local names = {}
                for _, n in ipairs(claimers) do names[#names + 1] = (n == ns.me) and L.YOU or MemberName(n) end
                status = ns.GREEN .. string.format(L.ON_IT, table.concat(names, ", ")) .. "|r"
            elseif not mine and R.ICanMake(r) then
                status = ns.GOLD .. L.YOU_CAN_MAKE .. "|r"
            else
                local can = R.Crafters(r)
                status = #can > 0 and (ns.GREY .. string.format(L.CAN_MAKE_IT, #can) .. "|r") or (ns.GREY .. L.NOBODY_YET .. "|r")
            end
            local picking = mine and p.picking and p.picking.key == r.key
            if picking then
                c.who:SetText(ns.GOLD .. L.WHO_MADE_IT .. "|r")
                status = ""
            end
            for j, mk in ipairs(c.makers) do
                local maker = picking and claimers[j]
                mk.name = maker or nil
                mk.box:SetShown(maker and true or false)
                mk.label:SetShown(maker and true or false)
                if maker then
                    mk.label:SetText(FirstName(maker))
                    mk.box:SetChecked(p.picking.mk[maker] == true)
                end
            end
            c.status:SetText(status)
            c.done:SetShown(mine)
            c.cancel:SetShown(mine)
            c.cancel:SetText(picking and L.BACK or L.CANCEL)
            c.claim:SetShown(not mine)
            c.whisper:SetShown(not mine and ns.Guild.Get(r.owner) ~= nil)
            c.claim:SetText(c.claimed and L.CANT_AFTER_ALL or L.ILL_MAKE_IT)
            local mod = not mine and not r.x and R.CanRemove()
            c.modX.Sync(mod)
            c.when:SetPoint("TOPLEFT", mod and 306 or 378, -9)
            c:Show()
        else
            c:Hide()
        end
    end
end

local function Refresh(p)
    RefreshSide(p)
    p.whoView:SetShown(p.view == 1)
    p.reqView:SetShown(p.view == 2)
    p.histView:SetShown(p.view == 3)
    if p.view == 1 then RefreshWho(p) elseif p.view == 2 then RefreshRequests(p) else RefreshHistory(p) end
end

UI.AddPage("professions", Build, Refresh)

-- Home's "Craft requests open" box opens the Requests view.
function UI.ShowRequests()
    if thePage and thePage.pickView then thePage.pickView(2) end
end
ns.Listen("PROFS", UI.Dirty)
ns.Listen("REQUESTS", UI.Dirty)
ns.Listen("ALTS", UI.Dirty)
