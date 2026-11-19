-- Small builders shared by every page (from the approved mock-up). All frames are our own; none
-- is a Blizzard panel and none goes on a Blizzard list.
local ADDON, ns = ...

local UI = {}
ns.UI = UI

UI.TICK = "|TInterface\\RaidFrame\\ReadyCheck-Ready:14|t"
-- The guild crest (Media/crest*.tga, made by tools/art/make_crest.py).
UI.CREST = "Interface\\AddOns\\YeahNahMate\\Media\\crest"
UI.ICON = "Interface\\AddOns\\YeahNahMate\\Media\\crest32"
UI.MINI = "Interface\\AddOns\\YeahNahMate\\Media\\crestmini"   -- the owl, cut in close

-- Our windows use Blizzard's frame template for the look, but its X button closes through
-- Blizzard's panel system (HideUIPanel), which the game blocks in combat and which taints
-- Blizzard's UI. So every X just hides its own window.
function UI.PlainClose(frame)
    local close = frame.CloseButton
    if close then close:SetScript("OnClick", function() frame:Hide() end) end
end

function UI.Text(parent, text, font, x, y, w, justify)
    local fs = parent:CreateFontString(nil, "OVERLAY", font or "GameFontHighlightSmall")
    fs:SetPoint("TOPLEFT", x, y)
    if w then
        fs:SetWidth(w)
        fs:SetJustifyH(justify or "LEFT")
        fs:SetWordWrap(false)
    end
    fs:SetText(text or "")
    return fs
end

function UI.Button(parent, label, w, x, y, onClick, h)
    local b = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    b:SetSize(w, h or 22)
    b:SetPoint("TOPLEFT", x, y)
    b:SetText(label)
    if onClick then b:SetScript("OnClick", onClick) end
    return b
end

function UI.Box(parent, x, y, w, h)
    local b = CreateFrame("Frame", nil, parent, BackdropTemplateMixin and "BackdropTemplate" or nil)
    b:SetPoint("TOPLEFT", x, y)
    b:SetSize(w, h)
    if b.SetBackdrop then
        b:SetBackdrop({
            bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            edgeSize = 12, insets = { left = 3, right = 3, top = 3, bottom = 3 },
        })
        b:SetBackdropColor(0, 0, 0, 0.45)
        b:SetBackdropBorderColor(0.55, 0.55, 0.55, 0.9)
    end
    return b
end

function UI.Header(parent, text, x, y, w)
    local fs = UI.Text(parent, text, "GameFontNormal", x, y)
    local line = parent:CreateTexture(nil, "ARTWORK")
    line:SetColorTexture(0.9, 0.76, 0.36, 0.35)
    line:SetPoint("TOPLEFT", x, y - 16)
    line:SetSize(w or 200, 1)
    return fs
end

-- A tick box with a label. onChange(checked) runs when the player clicks it.
function UI.Check(parent, label, x, y, checked, onChange)
    local c = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
    c:SetSize(24, 24)
    c:SetPoint("TOPLEFT", x, y)
    c:SetChecked(checked)
    local fs = UI.Text(parent, label, "GameFontHighlight", x + 28, y - 5)
    c:SetScript("OnClick", function(self)
        if onChange then onChange(self:GetChecked() and true or false) end
    end)
    return c, fs
end

-- A row: a hover highlight and an optional stripe, clickable.
function UI.Row(parent, x, y, w, h)
    local r = CreateFrame("Button", nil, parent)
    r:SetPoint("TOPLEFT", x, y)
    r:SetSize(w, h)
    r.stripe = r:CreateTexture(nil, "BACKGROUND")
    r.stripe:SetAllPoints()
    r.stripe:SetColorTexture(1, 1, 1, 0.04)
    r.hl = r:CreateTexture(nil, "BORDER")
    r.hl:SetAllPoints()
    r.hl:SetColorTexture(1, 0.82, 0, 0.12)
    r.hl:Hide()
    r:SetScript("OnEnter", function(self) self.hl:Show() end)
    r:SetScript("OnLeave", function(self) self.hl:Hide() end)
    return r
end

-- One choice out of several buttons: the chosen one stays lit with a gold underline.
-- Returns Pick(i), which selects i and calls onPick(i), and the buttons. w is one width for all, or a list (one each).
function UI.Choice(parent, labels, x, y, w, onPick)
    local set = {}
    local function Pick(i)
        -- i = 0 picks none.
        for j, b in ipairs(set) do
            if j == i then b:LockHighlight(); b.sel:Show() else b:UnlockHighlight(); b.sel:Hide() end
        end
        onPick(i)
    end
    local left = x
    for i, label in ipairs(labels) do
        local bw = type(w) == "table" and w[i] or w
        local b = UI.Button(parent, label, bw, left, y, function() Pick(i) end)
        left = left + bw + 4
        b.sel = b:CreateTexture(nil, "OVERLAY")
        b.sel:SetColorTexture(1, 0.82, 0, 1)
        b.sel:SetPoint("BOTTOMLEFT", 6, 2)
        b.sel:SetPoint("BOTTOMRIGHT", -6, 2)
        b.sel:SetHeight(2)
        b.sel:Hide()
        set[i] = b
    end
    return Pick, set
end

-- A box showing text you can select and copy (click it, Ctrl+C) but not change. WoW can't open web
-- links, so Twitch and Discord addresses are shown this way. box.SetValue(text) fills it.
function UI.CopyBox(parent, x, y, w)
    local box = CreateFrame("EditBox", nil, parent, "InputBoxTemplate")
    box:SetSize(w, 20)
    box:SetPoint("TOPLEFT", x + 6, y)
    box:SetAutoFocus(false)
    box:SetScript("OnTextChanged", function(self, userInput)
        if userInput and self.value then self:SetText(self.value); self:HighlightText() end
    end)
    box:SetScript("OnEditFocusGained", function(self) self:HighlightText() end)
    box:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    box:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
    function box.SetValue(value) box.value = value; box:SetText(value); box:SetCursorPosition(0) end
    return box
end

-- "1-4 of 9" with up/down buttons, for lists that scroll (it should be obvious there's more).
-- onMove(-1) goes up a page, onMove(1) down. Set(first, last, total) shows it only when needed.
function UI.Pager(parent, x, y, onMove)
    local pg = {}
    pg.text = UI.Text(parent, "", "GameFontDisableSmall", x, y - 3, 96, "RIGHT")
    pg.up = UI.Button(parent, "^", 20, x + 100, y, function() onMove(-1) end, 18)
    pg.down = UI.Button(parent, "v", 20, x + 122, y, function() onMove(1) end, 18)
    function pg.Set(first, last, total)
        local show = total > (last - first + 1)
        pg.text:SetShown(show); pg.up:SetShown(show); pg.down:SetShown(show)
        if not show then return end
        pg.text:SetText(string.format(ns.L.SHOWN, first, last, total))
        pg.up:SetEnabled(first > 1)
        pg.down:SetEnabled(last < total)
    end
    return pg
end

UI.ROLE_ICON = {
    t = "|TInterface\\Icons\\INV_Shield_06:14|t",
    h = "|TInterface\\Icons\\Spell_Holy_Heal:14|t",
    d = "|TInterface\\Icons\\INV_Sword_04:14|t",
}

-- Three clear rows, one per role:  [shield] Tanks   [-]  1  [+]   (the side-by-side ones overlapped
-- and it wasn't obvious what they did). get(role) gives the number; set(role, n) changes it.
-- least(r), if given: the lowest a role can go (the leader's own role is at least 1: they're in it).
function UI.RoleCounts(parent, x, y, get, set, least)
    local rc = { rows = {} }
    local function Min(r) return least and least(r) or 0 end
    local MAX = { t = 2, h = 2, d = 4 }
    local NAME = { t = ns.L.TANKS, h = ns.L.HEALERS, d = ns.L.ROLE_DPS }
    for i, r in ipairs({ "t", "h", "d" }) do
        local ry = y - (i - 1) * 22
        local row = {}
        row.label = UI.Text(parent, UI.ROLE_ICON[r] .. " " .. NAME[r], "GameFontHighlightSmall", x + 4, ry - 4, 90)
        row.minus = UI.Button(parent, "-", 20, x + 96, ry, function() set(r, math.max(Min(r), get(r) - 1)) end, 20)
        row.value = UI.Text(parent, "", "GameFontHighlight", x + 118, ry - 3, 24, "CENTER")
        row.plus = UI.Button(parent, "+", 20, x + 144, ry, function() set(r, math.min(MAX[r], get(r) + 1)) end, 20)
        rc.rows[r] = row
    end
    function rc.Refresh()
        for r, row in pairs(rc.rows) do
            local n = get(r)
            row.value:SetText(tostring(n))
            row.minus:SetEnabled(n > Min(r))
            row.plus:SetEnabled(n < MAX[r])
        end
    end
    function rc.SetShown(v)
        for _, row in pairs(rc.rows) do
            for _, w in ipairs({ row.label, row.minus, row.value, row.plus }) do w:SetShown(v) end
        end
    end
    return rc
end

-- The tab layout (every tab follows the Ask tab's). A sidebar on the left:
-- the tab's main action as a big button, its views as a short list with counts (a gold bar on the
-- one showing), then a box (a title holder, or your own status). The content goes on the right,
-- from UI.RX: a strip along the top (the view's title, a filter, a search), the list under it, the
-- pager at the bottom right. Details and forms open over the content.
UI.SIDE_W = 168
UI.RX = 184
UI.RW = 736 - UI.RX

-- Role icons (UI.ROLE_ICON, further down) as one string: UI.RoleIcons("hd") -> both icons.
function UI.RoleIcons(roles)
    if type(roles) ~= "string" or roles == "" then return "" end
    local out = {}
    for _, r in ipairs({ "t", "h", "d" }) do if roles:find(r, 1, true) then out[#out + 1] = UI.ROLE_ICON[r] end end
    return table.concat(out, " ")
end

-- A drop-down list whose items change: one per parent, opened under any button.
-- menu.Open(anchor, items, onPick): items = { label, ... }, onPick(i). A second click on the same
-- button shuts it.
function UI.PickMenu(parent, w, maxRows, rowH)
    rowH = rowH or 20
    local menu = UI.Box(parent, 0, 0, w, 8 + maxRows * rowH)
    menu:SetFrameLevel((parent:GetFrameLevel() or 1) + 30)
    menu:SetBackdropColor(0, 0, 0, 0.97)
    menu:EnableMouse(true)
    menu:Hide()
    menu.rows = {}
    for i = 1, maxRows do
        local r = UI.Row(menu, 4, -4 - (i - 1) * rowH, w - 8, rowH - 1)
        r.text = UI.Text(r, "", "GameFontHighlightSmall", 6, -3, w - 20)
        r:SetScript("OnClick", function()
            menu:Hide()
            if menu.onPick then menu.onPick(i) end
        end)
        menu.rows[i] = r
    end
    function menu.Open(anchor, items, onPick)
        if menu:IsShown() and menu.anchor == anchor then menu:Hide() return end
        menu.anchor, menu.onPick = anchor, onPick
        local n = math.min(#items, maxRows)
        for i, r in ipairs(menu.rows) do
            r.text:SetText(items[i] or "")
            r:SetShown(i <= n)
        end
        menu:SetHeight(8 + n * rowH)
        menu:ClearAllPoints()
        menu:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, -2)
        menu:Show()
    end
    -- It closes on a pick, on the same click again, on a click anywhere else, and by itself once
    -- the mouse has been off it (and off what opened it) for a moment.
    local function Over(f) return f ~= nil and f.IsMouseOver ~= nil and f:IsMouseOver() == true end
    local away, ticker = 0, nil
    menu:SetScript("OnShow", function()
        away = 0
        if ticker then ticker:Cancel() end
        ticker = C_Timer.NewTicker(0.25, function()
            if Over(menu) or Over(menu.anchor) then away = 0 return end
            away = away + 0.25
            if away >= UI.MENU_AWAY then menu:Hide() end
        end)
    end)
    menu:SetScript("OnHide", function()
        if ticker then ticker:Cancel(); ticker = nil end
    end)
    -- A mouse button pressed anywhere else. GLOBAL_MOUSE_DOWN may not exist on every client: pcall.
    local clicks = CreateFrame("Frame", nil, menu)
    if pcall(clicks.RegisterEvent, clicks, "GLOBAL_MOUSE_DOWN") then
        clicks:SetScript("OnEvent", function()
            if menu:IsShown() and not Over(menu) and not Over(menu.anchor) then menu:Hide() end
        end)
    end
    return menu
end
UI.MENU_AWAY = 1.5              -- seconds off the menu before it closes by itself

-- Builds the sidebar on parent. action = { label, onClick } or nil (the views then start at the top).
-- Returns s: s.action (the button), s.rows[i] (.label, .count, .bar), s.y (under the last row),
-- s.Set(picked, counts) to light the picked row and fill the counts.
function UI.Sidebar(parent, action, labels, onPick)
    local s = { rows = {} }
    local y = 0
    if action then
        s.action = UI.Button(parent, action[1], UI.SIDE_W, 0, 0, action[2], 34)
        if s.action.SetNormalFontObject and GameFontNormalLarge then s.action:SetNormalFontObject(GameFontNormalLarge) end
        y = -46
    end
    for i, label in ipairs(labels) do
        local r = UI.Row(parent, 0, y - (i - 1) * 26, UI.SIDE_W, 24)
        r.label = UI.Text(r, label, "GameFontHighlight", 12, -5, 110)
        r.label.base = label
        r.count = UI.Text(r, "", "GameFontDisableSmall", 112, -6, 50, "RIGHT")
        r.bar = r:CreateTexture(nil, "OVERLAY")
        r.bar:SetPoint("TOPLEFT", 0, 0)
        r.bar:SetSize(3, 24)
        r.bar:SetColorTexture(1, 0.82, 0, 1)
        r:SetScript("OnClick", function() onPick(i) end)
        s.rows[i] = r
    end
    s.y = y - #labels * 26 - 8
    function s.Set(picked, counts)
        for i, r in ipairs(s.rows) do
            local on = i == picked
            r.bar:SetShown(on)
            r.stripe:SetColorTexture(1, 0.82, 0, on and 0.12 or 0)
            r.label:SetText(on and (ns.GOLD .. r.label.base .. "|r") or r.label.base)
            local n = counts and counts[i]
            r.count:SetText(type(n) == "number" and (n > 0 and tostring(n) or "") or (n or ""))
        end
    end
    return s
end

-- The box under the views: an icon, a gold title, a big line and a small line; a click does onClick.
-- A sidebar can also be all boxes (Dungeons): b.SetPicked(on) lights the one showing.
function UI.SideBox(parent, y, icon, title, onClick)
    local b = CreateFrame("Button", nil, parent)
    b:SetPoint("TOPLEFT", 0, y)
    b:SetSize(UI.SIDE_W, 64)
    local box = UI.Box(b, 0, 0, UI.SIDE_W, 64)
    box:EnableMouse(false)
    b.icon = box:CreateTexture(nil, "ARTWORK")
    b.icon:SetSize(28, 28)
    b.icon:SetPoint("TOPLEFT", 10, -10)
    b.icon:SetTexture(icon)
    b.title = UI.Text(box, ns.GOLD .. title .. "|r", "GameFontNormalSmall", 46, -9, 116)
    b.text = UI.Text(box, "", "GameFontHighlight", 46, -24, 116)
    b.pts = UI.Text(box, "", "GameFontDisableSmall", 10, -46, 150)
    b.hl = b:CreateTexture(nil, "HIGHLIGHT")
    b.hl:SetAllPoints()
    b.hl:SetColorTexture(1, 0.82, 0, 0.08)
    -- Picked (when the cards are the views): a gold bar down the left and a gold tint, like a view row.
    b.tint = b:CreateTexture(nil, "BORDER")
    b.tint:SetAllPoints()
    b.tint:SetColorTexture(1, 0.82, 0, 0.12)
    b.tint:Hide()
    b.bar = b:CreateTexture(nil, "OVERLAY")
    b.bar:SetPoint("TOPLEFT", 0, 0)
    b.bar:SetSize(3, 64)
    b.bar:SetColorTexture(1, 0.82, 0, 1)
    b.bar:Hide()
    -- Active: something of yours is on here (you're available, you lead a group, an
    -- alert is on, you hold the title). A see-through green over the black card and a green edge.
    b.green = b:CreateTexture(nil, "BORDER")
    b.green:SetPoint("TOPLEFT", 3, -3)
    b.green:SetPoint("BOTTOMRIGHT", -3, 3)
    b.green:SetColorTexture(0.2, 0.85, 0.3, 0.16)
    b.green:Hide()
    function b.SetPicked(on)
        b.picked = on and true or false
        b.tint:SetShown(b.picked and not b.active)
        b.bar:SetShown(b.picked)
    end
    function b.SetActive(on)
        b.active = on and true or false
        b.green:SetShown(b.active)
        b.tint:SetShown(b.picked == true and not b.active)
        if box.SetBackdropBorderColor then
            if b.active then box:SetBackdropBorderColor(0.3, 0.9, 0.4, 0.9)
            else box:SetBackdropBorderColor(0.55, 0.55, 0.55, 0.9) end
        end
    end
    if onClick then b:SetScript("OnClick", onClick) end
    return b
end

-- A "have you picked it yet" line on a form: see-through red with what's missing, then
-- see-through green with what you picked. When every line on a form is green, it can be sent.
-- line.Set(text or nil, missing): nil text shows missing in red.
function UI.ReadyLine(parent, x, y, w)
    local box = UI.Box(parent, x, y, w, 24)
    box.tint = box:CreateTexture(nil, "BORDER")
    box.tint:SetPoint("TOPLEFT", 3, -3)
    box.tint:SetPoint("BOTTOMRIGHT", -3, 3)
    box.text = UI.Text(box, "", "GameFontHighlightSmall", 8, -6, w - 16)
    function box.Set(text, missing)
        box.ok = text ~= nil and text ~= ""
        if box.ok then
            box.tint:SetColorTexture(0.2, 0.85, 0.3, 0.16)
            if box.SetBackdropBorderColor then box:SetBackdropBorderColor(0.3, 0.9, 0.4, 0.9) end
            box.text:SetText(text)
        else
            box.tint:SetColorTexture(0.9, 0.2, 0.2, 0.16)
            if box.SetBackdropBorderColor then box:SetBackdropBorderColor(0.9, 0.3, 0.3, 0.9) end
            box.text:SetText(missing)
        end
        return box.ok
    end
    return box
end

-- The content strip's view title (top left of the content).
function UI.ViewTitle(parent, w)
    return UI.Text(parent, "", "GameFontNormalLarge", UI.RX + 2, -4, w or 190)
end

-- A small drop-down menu: a button showing the pick, and a list under it. items = { label, ... };
-- onPick(i). Returns the button; button.Set(i) picks without calling onPick, button.menu is the list.
function UI.Menu(parent, x, y, w, items, onPick, rowH)
    rowH = rowH or 20
    local btn = UI.Button(parent, "", w, x, y, nil)
    local menu = UI.Box(parent, x, y - 24, w, 8 + #items * rowH)
    menu:SetFrameLevel((parent:GetFrameLevel() or 1) + 20)
    menu:SetBackdropColor(0, 0, 0, 0.97)
    menu:EnableMouse(true)
    menu:Hide()
    btn.menu = menu
    menu.rows = {}
    for i, label in ipairs(items) do
        local r = UI.Row(menu, 4, -4 - (i - 1) * rowH, w - 8, rowH - 1)
        r.text = UI.Text(r, label, "GameFontHighlightSmall", 6, -3, w - 20)
        r:SetScript("OnClick", function() btn.Set(i); menu:Hide(); onPick(i) end)
        menu.rows[i] = r
    end
    btn:SetScript("OnClick", function() menu:SetShown(not menu:IsShown()) end)
    function btn.Set(i) btn:SetText((items[i] or "") .. "  v") end
    btn.Set(1)
    return btn
end

-- A guildmate's name in their class colour (grey when offline).
-- After the Lore Master's name, a book (Ask the Guild: most answers that helped, last 30 days);
-- after the Crafty Bugger's, a wrench (most craft requests made, last 30 days). On all of that
-- person's characters (Alts.lua).
UI.LORE_ICON = "|TInterface\\Icons\\INV_Misc_Book_09:12:12|t"
UI.CRAFTY_ICON = "|TInterface\\Icons\\INV_Misc_Wrench_01:12:12|t"
function UI.Badges(name)
    local s = ""
    if ns.Questions and ns.Questions.IsLoreMaster(name) then s = s .. " " .. UI.LORE_ICON end
    if ns.Requests and ns.Requests.IsCraftyBugger(name) then s = s .. " " .. UI.CRAFTY_ICON end
    return s
end

-- Rank markers: a gold crown for the guild master, a silver one for the rank under them, and
-- a shield for any other rank the guild master lets edit the guild info (Board.lua's officers).
-- The game's own group icons, which every client has.
UI.RANK_GM = "|TInterface\\GroupFrame\\UI-Group-LeaderIcon:13:13:0:0|t"
UI.RANK_SECOND = "|TInterface\\GroupFrame\\UI-Group-AssistantIcon:13:13:0:0|t"
UI.RANK_OFFICER = "|TInterface\\GroupFrame\\UI-Group-MainTankIcon:13:13:0:0|t"

-- A moderator's Remove button: click once ("Sure?"), again to do it. key() names what
-- the card shows now, so a half-done click doesn't carry over to another card's item. Call b.Sync(on)
-- from the refresh.
function UI.ModRemove(parent, x, y, key, onRemove, w)
    local L = ns.L
    local b = UI.Button(parent, L.MOD_REMOVE, w or 64, x, y, nil, 18)
    b:SetScript("OnClick", function(self)
        local k = key()
        if not k then return end
        if self.armed ~= k then self.armed = k; self:SetText(L.MS_SURE); return end
        self.armed = nil
        self:SetText(L.MOD_REMOVE)
        onRemove(k)
        UI.Dirty()
    end)
    b:SetScript("OnEnter", function(self)
        if not GameTooltip then return end
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:AddLine(L.MOD_REMOVE_TIP, 1, 1, 1, true)
        GameTooltip:Show()
    end)
    b:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
    function b.Sync(on)
        if b.armed ~= nil and b.armed ~= key() then b.armed = nil end
        b:SetText(b.armed and L.MS_SURE or L.MOD_REMOVE)
        b:SetShown(on and true or false)
    end
    return b
end

-- The icon for a guildie's rank, or nil.
function UI.RankIcon(m)
    local r = m and m.rankIndex
    if r == 0 then return UI.RANK_GM end
    if r == 1 then return UI.RANK_SECOND end
    if type(r) == "number" and r < 99 and ns.Board and ns.Board.RankModeratesAny(r) then return UI.RANK_OFFICER end
    if m and ns.Board and ns.Board.IsManager(m.name) then return UI.RANK_OFFICER end
    return nil
end

function UI.Name(m, offlineGrey)
    if offlineGrey and not m.online then return ns.GREY .. m.name .. "|r" .. UI.Badges(m.name) end
    return "|c" .. ns.ClassHex(m.class) .. m.name .. "|r" .. UI.Badges(m.name)
end

-- The tooltip for a guildmate (roster rows, Home rows).
function UI.MemberTooltip(owner, m)
    if not GameTooltip then return end
    local L = ns.L
    GameTooltip:SetOwner(owner, "ANCHOR_RIGHT")
    GameTooltip:AddLine("|c" .. ns.ClassHex(m.class) .. m.name .. "|r")
    GameTooltip:AddLine(string.format("%s %s %s", ns.L.COL_LEVEL, tostring(m.level), ns.ClassName(m.class)), 1, 1, 1)
    if m.online then
        GameTooltip:AddLine(m.zone ~= "" and m.zone or "?", 1, 1, 1)
        local s = ns.Status and ns.Status.Text(m) or ""
        if s ~= "" then GameTooltip:AddLine(s, 0.8, 0.8, 0.8) end
        local d = ns.Map and ns.Map.Distance(m.name)
        if d then GameTooltip:AddLine(string.format(L.YARDS, d), 0.25, 1, 0.25) end
    else
        GameTooltip:AddLine(L.OFFLINE, 0.6, 0.6, 0.6)
    end
    if m.rank ~= "" then
        local icon = UI.RankIcon(m)
        GameTooltip:AddLine((icon and (icon .. " ") or "") .. m.rank, 0.9, 0.76, 0.36)
        -- What they look after (one moderator rank per tab).
        if ns.Board and m.rankIndex ~= 0 then
            if ns.Board.IsManager(m.name) then
                GameTooltip:AddLine(L.RANK_MANAGER, 0.6, 0.6, 0.6)
            else
                local names = {}
                for _, t in ipairs(ns.Board.ModeratorTabs(m.name)) do names[#names + 1] = L.TAB_NAME[t] end
                if #names > 0 then GameTooltip:AddLine(string.format(L.MODERATES, table.concat(names, ", ")), 0.6, 0.6, 0.6, true) end
            end
        end
    end
    if ns.Questions and ns.Questions.IsLoreMaster(m.name) then
        GameTooltip:AddLine(UI.LORE_ICON .. " " .. L.LORE_MASTER, 1, 0.82, 0)
    end
    if ns.Requests and ns.Requests.IsCraftyBugger(m.name) then
        GameTooltip:AddLine(UI.CRAFTY_ICON .. " " .. L.CRAFTY_BUGGER, 1, 0.82, 0)
    end
    if ns.Clans then
        local race, roles = ns.Clans.Race(m.name), ns.Clans.Roles(m.name)
        if race then
            local lead = ns.Clans.IsLeader(m.name, race)
            GameTooltip:AddLine(string.format(lead and L.CLAN_LEADER_TIP or "%s", string.format(L.TIP_CLAN, ns.Clans.RaceName(race))),
                0.8, 0.8, 0.8)
        end
        if roles ~= "" then
            local names = {}
            for _, r in ipairs(ns.Clans.ROLES) do
                if roles:find(r, 1, true) then names[#names + 1] = UI.ROLE_ICON[r] .. " " .. ({ t = L.ROLE_TANK, h = L.ROLE_HEALER, d = L.ROLE_DPS })[r] end
            end
            GameTooltip:AddLine(string.format(L.TIP_ROLES, table.concat(names, "  ")), 0.8, 0.8, 0.8)
        end
    end
    local chars = ns.Alts and ns.Alts.Characters(m.name) or { m.name }
    if #chars > 1 then
        if chars[1] ~= m.name then
            GameTooltip:AddLine(string.format(L.TIP_ALT_OF, chars[1]), 0.8, 0.8, 0.8)
        else
            GameTooltip:AddLine(string.format(L.TIP_ALTS, table.concat(chars, ", ", 2)), 0.8, 0.8, 0.8, true)
        end
    end
    if m.note ~= "" then GameTooltip:AddLine(string.format(L.TIP_NOTE, m.note), 0.8, 0.8, 0.8) end
    local u = ns.Comm.users[m.name]
    if u then
        GameTooltip:AddLine(string.format(L.TIP_VERSION, u.ver or "?"), 0.25, 1, 0.25)
    else
        GameTooltip:AddLine(L.TIP_NO_ADDON, 0.6, 0.6, 0.6)
    end
    if m.sim then GameTooltip:AddLine(L.FAKE, 1, 0.5, 0.25) end
    GameTooltip:Show()
end

-- Invite a guildmate to my group: the game's own invite, from the player's click.
function UI.Invite(m)
    if m.sim then
        ns.Print(string.format(ns.L.INVITE_FAKE, m.name))
        if ns.Sim then ns.Sim.Join(m.name) end
        return
    end
    if C_PartyInfo and C_PartyInfo.InviteUnit then
        pcall(C_PartyInfo.InviteUnit, m.name)
    elseif InviteUnit then
        pcall(InviteUnit, m.name)
    end
end
