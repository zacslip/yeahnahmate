-- The Ask tab: guildies' questions as cards. Three views (Open, Mine, Answered) with a
-- topic filter and a search box; a card opens into its thread (answers and follow-ups) with a box
-- to post; the asker marks it answered by ticking the answers that helped. "Ask a question" opens a
-- form with a topic, up to 2 links (an item dragged from the bags, a quest from my quest log, a
-- dungeon) and the past answered questions that look like it.
local ADDON, ns = ...
local L = ns.L
local UI = ns.UI
local Text, Button, Box, Header, Row = UI.Text, UI.Button, UI.Box, UI.Header, UI.Row

local CARDS = 5
local POSTS = 4
local PICK_ROWS = 10
local VIEWS = { "open", "mine", "answered" }

local thePage

local function Ago(secs)
    local mins = math.max(0, math.floor(secs / 60))
    if mins < 60 then return mins .. "m" end
    if mins < 1440 then return math.floor(mins / 60) .. "h" end
    return math.floor(mins / 1440) .. "d"
end

local function Left(secs)
    local h = math.max(0, math.floor(secs / 3600))
    if h >= 48 then return math.floor(h / 24) .. "d" end
    if h >= 1 then return h .. "h" end
    return math.max(1, math.floor(secs / 60)) .. "m"
end

local function MemberName(name)
    if name == ns.me then return L.YOU .. UI.Badges(name) end
    local m = ns.Guild.Get(name)
    return m and UI.Name(m, true) or (name .. UI.Badges(name))
end

local function TopicName(tp) return L["Q_TOPIC_" .. strupper(tp or "other")] or tp end

local function LinksText(lk)
    local parts = {}
    for _, l in ipairs(lk or {}) do parts[#parts + 1] = ns.GOLD .. "[" .. ns.Questions.LinkText(l) .. "]|r" end
    return table.concat(parts, "  ")
end

-- The tooltip for a link: the game's own for items and quests (when it has one), ours for dungeons.
local function LinkTip(owner, l)
    if not GameTooltip or not l then return end
    GameTooltip:SetOwner(owner, "ANCHOR_RIGHT")
    local shown = false
    if l.k == "i" then
        shown = pcall(GameTooltip.SetHyperlink, GameTooltip, "item:" .. l.id)
    elseif l.k == "q" then
        shown = pcall(GameTooltip.SetHyperlink, GameTooltip, "quest:" .. l.id .. ":" .. (l.lv or 0))
        if shown and GameTooltip.NumLines and GameTooltip:NumLines() == 0 then shown = false end
        if not shown then
            GameTooltip:AddLine(ns.Questions.LinkText(l), 1, 0.82, 0)
            shown = true
        end
        if ns.Questions.InMyLog(l.id) then GameTooltip:AddLine(L.Q_IN_YOUR_LOG, 0.25, 1, 0.25) end
    elseif l.k == "d" then
        local d = ns.Dungeons.BY_KEY[l.id]
        if d then
            GameTooltip:AddLine(d.name, 1, 0.82, 0)
            GameTooltip:AddLine(string.format(L.Q_DUNGEON_LEVELS, d.min, d.max), 1, 1, 1)
            local lvl = UnitLevel and UnitLevel("player")
            if type(lvl) == "number" then
                local ok = lvl >= d.min and lvl <= d.max
                GameTooltip:AddLine(ok and L.Q_DUNGEON_YOURS or string.format(L.Q_DUNGEON_YOU, lvl), ok and 0.25 or 0.8, ok and 1 or 0.8, ok and 0.25 or 0.8)
            end
            shown = true
        end
    end
    if shown then GameTooltip:Show() else GameTooltip:Hide() end
end
local function HideTip() if GameTooltip then GameTooltip:Hide() end end

-- A small button showing a link; hover for its tooltip. onClick (optional) e.g. removes it.
local function LinkButton(parent, x, y, w, onClick)
    local b = CreateFrame("Button", nil, parent)
    b:SetPoint("TOPLEFT", x, y)
    b:SetSize(w, 16)
    b.text = Text(b, "", "GameFontHighlightSmall", 0, -2, w)
    b:SetScript("OnEnter", function(self) LinkTip(self, self.link) end)
    b:SetScript("OnLeave", HideTip)
    if onClick then b:SetScript("OnClick", onClick) end
    function b.Set(l, extra)
        b.link = l
        if l then b.text:SetText(ns.GOLD .. "[" .. ns.Questions.LinkText(l) .. "]|r" .. (extra or "")); b:Show() else b:Hide() end
    end
    return b
end

local function EditBox(parent, x, y, w, max)
    local e = CreateFrame("EditBox", nil, parent, "InputBoxTemplate")
    e:SetSize(w, 20)
    e:SetPoint("TOPLEFT", x + 6, y)
    e:SetAutoFocus(false)
    e:SetMaxLetters(max)
    e:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    return e
end

---------------------------------------------------------------------------------------------------
-- Picking links (shared by the ask form and the reply box): an item from the cursor, a quest from my
-- log, a dungeon from the list. target is the list of links being filled (up to 2).

local picker

local function AddLink(target, l)
    if not target or not l then return end
    for _, have in ipairs(target) do
        if have.k == l.k and have.id == l.id then return end
    end
    if #target >= 2 then ns.Print(L.Q_TWO_LINKS) return end
    target[#target + 1] = l
    UI.Dirty()
end

-- Take the item on the cursor (dragged from the bags).
local function TakeItem(target)
    local kind, id, link = GetCursorInfo()
    if kind ~= "item" then ns.Print(L.Q_ITEM_HINT) return end
    ClearCursor()
    local itemID = tonumber(id) or (type(link) == "string" and tonumber(link:match("item:(%d+)")))
    if not itemID then return end
    local name = type(link) == "string" and link:match("%[(.-)%]") or nil
    AddLink(target, { k = "i", id = itemID, n = name or "" })
end

local function ItemButton(parent, x, y, getTarget)
    local b = Button(parent, L.Q_ADD_ITEM, 70, x, y, function() TakeItem(getTarget()) end, 20)
    b:SetScript("OnReceiveDrag", function() TakeItem(getTarget()) end)
    b:SetScript("OnEnter", function(self)
        if not GameTooltip then return end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:AddLine(L.Q_ITEM_HINT, 1, 1, 1, true)
        GameTooltip:Show()
    end)
    b:SetScript("OnLeave", HideTip)
    return b
end

local function BuildPicker(p)
    picker = Box(p, 180, -20, 380, 30 + PICK_ROWS * 24 + 34)
    picker:SetFrameLevel((p:GetFrameLevel() or 1) + 30)
    picker:SetBackdropColor(0, 0, 0, 0.97)
    picker:EnableMouse(true)
    picker:Hide()
    picker.title = Text(picker, "", "GameFontNormal", 12, -10, 300)
    Button(picker, "x", 24, 346, -6, function() picker:Hide() end, 20)
    picker.rows = {}
    for i = 1, PICK_ROWS do
        local r = Row(picker, 8, -30 - (i - 1) * 24, 364, 23)
        r.name = Text(r, "", "GameFontHighlightSmall", 4, -5, 250)
        r.info = Text(r, "", "GameFontDisableSmall", 256, -5, 104, "RIGHT")
        r:SetScript("OnClick", function(self)
            if self.value then AddLink(picker.target, self.value) end
            picker:Hide()
        end)
        picker.rows[i] = r
    end
    picker.empty = Text(picker, "", "GameFontDisableSmall", 14, -36, 350)
    picker.empty:SetWordWrap(true)
    picker.empty:SetHeight(40)
    picker.offset = 0
    picker.pager = UI.Pager(picker, 224, -34 - PICK_ROWS * 24, function(d)
        picker.offset = math.max(0, math.min(picker.offset + d * PICK_ROWS, #picker.items - PICK_ROWS))
        picker.Fill()
    end)
    function picker.Fill()
        local items = picker.items
        picker.empty:SetShown(#items == 0)
        for i, r in ipairs(picker.rows) do
            local it = items[picker.offset + i]
            r.value = it and it.value
            if it then r.name:SetText(it.label); r.info:SetText(it.info or ""); r:Show() else r:Hide() end
        end
        picker.pager.Set(picker.offset + 1, math.min(#items, picker.offset + PICK_ROWS), #items)
    end
end

local function OpenPicker(kind, target)
    local items = {}
    if kind == "quest" then
        picker.title:SetText(L.Q_PICK_QUEST)
        picker.empty:SetText(L.Q_NO_QUESTS)
        for _, q in ipairs(ns.Questions.MyQuests()) do
            items[#items + 1] = { label = (q.lv > 0 and ("[" .. q.lv .. "] ") or "") .. q.n, info = q.zone,
                                  value = { k = "q", id = q.id, lv = q.lv, n = q.n } }
        end
    else
        picker.title:SetText(L.Q_PICK_DUNGEON)
        picker.empty:SetText("")
        -- Dungeons near my level first, then the rest in order.
        local lvl = UnitLevel and UnitLevel("player") or 0
        local near, rest = {}, {}
        for _, d in ipairs(ns.Dungeons.LIST) do
            local it = { label = d[2], info = d[3] .. "-" .. d[4], value = { k = "d", id = d[1] } }
            if lvl >= d[3] - 3 and lvl <= d[4] then near[#near + 1] = it else rest[#rest + 1] = it end
        end
        for _, it in ipairs(near) do items[#items + 1] = it end
        for _, it in ipairs(rest) do items[#items + 1] = it end
    end
    picker.items, picker.offset, picker.target = items, 0, target
    picker.Fill()
    picker:Show()
end
UI.AskPicker = function() return picker end

---------------------------------------------------------------------------------------------------
-- Build

-- The list page (the row of buttons was a wall, Ask got lost in it). A sidebar on the left:
-- a big "Ask a question", the views as a short list with counts, the Lore Master and the alert tick.
-- On the right: the view's title, one Topic button (a small menu) and the search box, then the cards.
local SIDE_W = 168
local RX = 184                          -- where the right-hand side starts
local RW = 736 - RX

local function BuildList(p)
    local v = CreateFrame("Frame", nil, p)
    v:SetAllPoints()
    p.listView = v
    p.view, p.topic, p.offset = "open", nil, 0

    -- Sidebar (cards like the Dungeons and Professions tabs). Ask a question; the views as
    -- cards; a line; the alert as a card (click to turn it on or off). The Lore Master is on Legends.
    p.askBtn = Button(v, L.Q_ASK_BIG, SIDE_W, 0, 0, function()
        p.form = { links = {}, topic = "other" }
        p.formFrame.text:SetText("")
        p.pickTopic(6)
        UI.Dirty()
    end, 34)
    if p.askBtn.SetNormalFontObject and GameFontNormalLarge then p.askBtn:SetNormalFontObject(GameFontNormalLarge) end
    function p.pickView(i)
        p.view, p.offset = VIEWS[i], 0
        if p.topicMenu then p.topicMenu:Hide() end
        UI.Dirty()
    end
    local icons = { "Interface\\Icons\\INV_Misc_Book_09", "Interface\\GroupFrame\\UI-Group-LeaderIcon", "Interface\\RaidFrame\\ReadyCheck-Ready" }
    p.viewCards = {}
    for i, name in ipairs({ L.Q_VIEW_OPEN, L.Q_VIEW_MINE, L.Q_VIEW_ANSWERED }) do
        p.viewCards[i] = UI.SideBox(v, -46 - (i - 1) * 72, icons[i], name, function() p.pickView(i) end)
    end
    local line = v:CreateTexture(nil, "ARTWORK")
    line:SetColorTexture(0.9, 0.76, 0.36, 0.5)
    line:SetPoint("TOPLEFT", 0, -263)
    line:SetSize(SIDE_W, 1)

    -- Opt in to the small alert for every new question (8c; off until clicked on).
    p.alertMe = UI.SideBox(v, -272, "Interface\\Icons\\INV_Misc_Note_01", L.Q_ALERT_CARD, function()
        ns.settings.qAlert = ns.settings.qAlert ~= true
        ns.Fire("SETTINGS")
        UI.Dirty()
    end)
    p.alertMe:SetScript("OnEnter", function(self)
        if not GameTooltip then return end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:AddLine(L.Q_ALERT_TIP, 1, 1, 1, true)
        GameTooltip:Show()
    end)
    p.alertMe:SetScript("OnLeave", HideTip)
    p.sideFoot = Text(v, L.Q_SIDE_FOOT, "GameFontDisableSmall", 0, -344, SIDE_W)
    p.sideFoot:SetWordWrap(true)
    p.sideFoot:SetHeight(66)
    p.sideFoot:SetJustifyV("TOP")

    -- Right: the cards (Open, Mine, Answered).
    local b = CreateFrame("Frame", nil, v)
    b:SetAllPoints()
    p.browse = b
    p.viewTitle = Text(b, "", "GameFontNormalLarge", RX + 2, -4, 190)
    p.topicBtn = Button(b, "", 124, RX + 196, 0, function()
        p.topicMenu:SetShown(not p.topicMenu:IsShown())
    end)
    p.search = EditBox(b, RX + 330, -1, RW - 336, 40)
    p.search:SetScript("OnTextChanged", function(self, userInput)
        p.searchHint:SetShown((self:GetText() or "") == "")
        if userInput then p.offset = 0; UI.Dirty() end
    end)
    p.search:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
    p.searchHint = Text(b, L.Q_SEARCH_HINT, "GameFontDisableSmall", RX + 340, -5, RW - 350)

    p.cards = {}
    for i = 1, CARDS do
        local c = Box(b, RX, -30 - (i - 1) * 62, RW, 58)
        c.click = CreateFrame("Button", nil, c)
        c.click:SetAllPoints()
        c.hl = c.click:CreateTexture(nil, "HIGHLIGHT")
        c.hl:SetAllPoints()
        c.hl:SetColorTexture(1, 0.82, 0, 0.08)
        c.click:SetScript("OnClick", function() if c.key then p.openKey, p.postOffset, p.marking = c.key, 0, nil; UI.Dirty() end end)
        c.click:EnableMouseWheel(true)
        c.click:SetScript("OnMouseWheel", function(_, delta) p.offset = math.max(0, p.offset - delta); UI.Dirty() end)
        c.title = Text(c, "", "GameFontNormal", 10, -8, RW - 120)
        c.when = Text(c, "", "GameFontDisableSmall", RW - 108, -9, 98, "RIGHT")
        c.who = Text(c, "", "GameFontHighlightSmall", 10, -25, RW - 20)
        c.status = Text(c, "", "GameFontHighlightSmall", 10, -41, RW - 20)
        p.cards[i] = c
    end
    p.empty = Text(b, "", "GameFontDisableSmall", RX + 4, -38, RW - 8)
    p.empty:SetWordWrap(true)
    p.empty:SetHeight(40)
    p.empty:SetJustifyV("TOP")
    p.pager = UI.Pager(b, 594, -344, function(d) p.offset = math.max(0, p.offset + d * CARDS); UI.Dirty() end)
    p.listFoot = Text(b, L.Q_FOOT, "GameFontDisableSmall", RX + 4, -348, 400)

    -- The topic menu (over the cards).
    local menu = Box(b, RX + 196, -24, 124, 8 + #ns.Questions.TOPICS * 20 + 20)
    menu:SetFrameLevel((p:GetFrameLevel() or 1) + 20)
    menu:SetBackdropColor(0, 0, 0, 0.97)
    menu:EnableMouse(true)
    menu:Hide()
    p.topicMenu = menu
    local labels = { L.Q_ALL }
    for i, tp in ipairs(ns.Questions.TOPICS) do labels[i + 1] = TopicName(tp) end
    menu.rows = {}
    for i, label in ipairs(labels) do
        local r = Row(menu, 4, -4 - (i - 1) * 20, 116, 19)
        r.text = Text(r, label, "GameFontHighlightSmall", 6, -3, 104)
        r:SetScript("OnClick", function() p.pickTopicFilter(i) end)
        menu.rows[i] = r
    end
    function p.pickTopicFilter(i)
        p.topic = i > 1 and ns.Questions.TOPICS[i - 1] or nil
        p.offset = 0
        menu:Hide()
        p.topicBtn:SetText(string.format(L.Q_TOPIC_BTN, labels[i]))
        UI.Dirty()
    end
end

-- One card, laid out like the list: the sidebar has Back, where the question's at, and the
-- asker's buttons (Mark resolved, Take it down; Done and Cancel while marking). On the right: who
-- asked and how long ago at the top, the question under it, then the answers and the reply box.
local function BuildCard(p)
    local v = CreateFrame("Frame", nil, p)
    v:SetAllPoints()
    p.cardView = v

    -- Sidebar
    Button(v, "< " .. L.Q_BACK_LIST, SIDE_W, 0, 0, function() p.openKey, p.marking, p.removing = nil, nil, nil; UI.Dirty() end, 24)
    local sb = Box(v, 0, -32, SIDE_W, 112)
    Text(sb, ns.GOLD .. L.Q_STATUS .. "|r", "GameFontNormalSmall", 10, -8, 150)
    v.state = Text(sb, "", "GameFontHighlightSmall", 10, -24, SIDE_W - 20)
    v.state:SetWordWrap(true)
    v.state:SetHeight(42)
    v.state:SetJustifyV("TOP")
    v.left = Text(sb, "", "GameFontDisableSmall", 10, -70, SIDE_W - 20)
    v.topic = Text(sb, "", "GameFontDisableSmall", 10, -88, SIDE_W - 20)

    v.mark = Button(v, L.Q_MARK, SIDE_W, 0, -154, function() p.marking = {}; UI.Dirty() end, 28)
    v.cancel = Button(v, L.Q_TAKE_DOWN, SIDE_W, 0, -188, function()
        if p.openKey and ns.Questions.Cancel(p.openKey) then p.openKey = nil end
        UI.Dirty()
    end, 22)
    v.markHint = Text(v, L.Q_MARK_HINT, "GameFontHighlightSmall", 2, -156, SIDE_W - 4)
    v.markHint:SetWordWrap(true)
    v.markHint:SetHeight(44)
    v.markHint:SetJustifyV("TOP")
    v.markDone = Button(v, L.DONE, SIDE_W, 0, -204, function()
        local names = {}
        for name in pairs(p.marking or {}) do names[#names + 1] = name end
        ns.Questions.Finish(p.openKey, names)
        p.marking = nil
        UI.Dirty()
    end, 28)
    v.markBack = Button(v, L.CANCEL, SIDE_W, 0, -238, function() p.marking = nil; UI.Dirty() end, 22)
    -- Officers (the Info editor ranks): remove the question, or one guildie's posts on it (their x).
    -- A click asks first, here in the sidebar, like marking.
    v.remove = Button(v, L.Q_REMOVE, SIDE_W, 0, -154, function() p.removing = { who = false }; UI.Dirty() end, 22)
    v.remove:HookScript("OnEnter", function(self)
        if not GameTooltip then return end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:AddLine(L.Q_REMOVE_TIP, 1, 1, 1, true)
        GameTooltip:Show()
    end)
    v.remove:HookScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
    v.rmAsk = Text(v, "", "GameFontHighlightSmall", 2, -156, SIDE_W - 4)
    v.rmAsk:SetWordWrap(true)
    v.rmAsk:SetHeight(44)
    v.rmAsk:SetJustifyV("TOP")
    v.rmYes = Button(v, L.Q_REMOVE_YES, SIDE_W, 0, -204, function()
        local r = p.removing
        p.removing = nil
        if r and p.openKey and ns.Questions.Remove(p.openKey, r.who or nil) and not r.who then p.openKey = nil end
        UI.Dirty()
    end, 28)
    v.rmNo = Button(v, L.CANCEL, SIDE_W, 0, -238, function() p.removing = nil; UI.Dirty() end, 22)
    v.sideHint = Text(v, "", "GameFontDisableSmall", 0, -300, SIDE_W)
    v.sideHint:SetWordWrap(true)
    v.sideHint:SetHeight(90)
    v.sideHint:SetJustifyV("TOP")

    -- Right: who asked and when, then the question and its links.
    local qb = Box(v, RX, 0, RW, 86)
    v.info = Text(qb, "", "GameFontHighlightSmall", 10, -8, RW - 20)
    v.title = Text(qb, "", "GameFontNormal", 10, -26, RW - 20)
    v.title:SetWordWrap(true)
    v.title:SetHeight(32)
    v.title:SetJustifyV("TOP")
    v.links = { LinkButton(qb, 10, -64, 260), LinkButton(qb, 280, -64, 260) }

    v.head = Header(v, "", RX, -94, RW)
    v.postPager = UI.Pager(v, 594, -92, function(d) p.postOffset = math.max(0, (p.postOffset or 0) + d * POSTS); UI.Dirty() end)
    v.posts = {}
    for i = 1, POSTS do
        local r = CreateFrame("Frame", nil, v)
        r:SetPoint("TOPLEFT", RX, -116 - (i - 1) * 54)
        r:SetSize(RW, 52)
        r.stripe = r:CreateTexture(nil, "BACKGROUND")
        r.stripe:SetAllPoints()
        r.who = Text(r, "", "GameFontHighlightSmall", 6, -3, RW - 60)
        r.text = Text(r, "", "GameFontHighlight", 6, -16, RW - 40)
        r.text:SetWordWrap(true)
        r.text:SetHeight(24)
        r.text:SetJustifyV("TOP")
        r.links = { LinkButton(r, 6, -36, 260), LinkButton(r, 272, -36, 260) }
        r.del = Button(r, "x", 22, RW - 26, -2, function()
            if not r.post then return end
            if r.post.name == ns.me then ns.Questions.DeletePost(p.openKey, r.post.i)
            else p.removing, p.marking = { who = r.post.name }, nil; UI.Dirty() end
        end, 18)
        r.del:HookScript("OnEnter", function(self)
            if not (GameTooltip and r.post) then return end
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:AddLine(r.post.name == ns.me and L.Q_TAKE_BACK_TIP or string.format(L.Q_REMOVE_POST_TIP, r.post.name), 1, 1, 1, true)
            GameTooltip:Show()
        end)
        r.del:HookScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
        r.tick = CreateFrame("CheckButton", nil, r, "UICheckButtonTemplate")
        r.tick:SetSize(24, 24)
        r.tick:SetPoint("TOPLEFT", RW - 30, -1)
        r.tick:SetScript("OnClick", function(self)
            if p.marking and r.post then p.marking[r.post.name] = self:GetChecked() and true or nil; UI.Dirty() end
        end)
        v.posts[i] = r
    end
    v.empty = Text(v, L.Q_NO_ANSWERS, "GameFontDisableSmall", RX + 6, -120, RW - 12)

    -- Posting: link buttons and the links waiting to go, then the reply box and Post.
    p.replyLinks = {}
    local function Target()
        -- Links go into a list without holes.
        local t = {}
        for i = 1, 2 do if p.replyLinks[i] then t[#t + 1] = p.replyLinks[i] end end
        p.replyLinks = t
        return t
    end
    v.item = ItemButton(v, RX, -334, Target)
    v.quest = Button(v, L.Q_ADD_QUEST, 70, RX + 74, -334, function() OpenPicker("quest", Target()) end, 20)
    v.dungeon = Button(v, L.Q_ADD_DUNGEON, 80, RX + 148, -334, function() OpenPicker("dungeon", Target()) end, 20)
    v.pending = { LinkButton(v, RX + 236, -336, 156, function(self) p.replyLinks[self.idx] = nil; UI.Dirty() end),
                  LinkButton(v, RX + 396, -336, 156, function(self) p.replyLinks[self.idx] = nil; UI.Dirty() end) }
    v.pending[1].idx, v.pending[2].idx = 1, 2
    v.reply = EditBox(v, RX, -360, RW - 100, ns.Questions.MAX_A)
    local function Send()
        local text = v.reply:GetText() or ""
        local links = {}
        for i = 1, 2 do if p.replyLinks[i] then links[#links + 1] = p.replyLinks[i] end end
        local ok, why = ns.Questions.Post(p.openKey, text, links)
        if ok then
            v.reply:SetText("")
            v.reply:ClearFocus()
            p.replyLinks = {}
            p.postOffset = 1e6              -- show the newest posts
        elseif why == "full" then ns.Print(string.format(L.Q_POSTS_FULL, ns.Questions.MAX_POSTS))
        elseif why == "closed" then ns.Print(L.Q_CLOSED)
        elseif why == "removed" then ns.Print(L.Q_MY_POSTS_REMOVED)
        end
        UI.Dirty()
    end
    v.reply:SetScript("OnEnterPressed", Send)
    v.send = Button(v, L.POST, 86, RX + RW - 86, -360, Send, 22)
    v.closed = Text(v, "", "GameFontDisableSmall", RX + 6, -364, RW - 12)
end

local function BuildForm(p)
    local f = CreateFrame("Frame", nil, p)
    f:SetAllPoints()
    p.formFrame = f
    Header(f, L.Q_ASK_TITLE, 0, 0, 736)
    Text(f, L.Q_QUESTION, "GameFontHighlightSmall", 4, -30)
    f.text = EditBox(f, 84, -26, 640, ns.Questions.MAX_Q)
    f.text:SetScript("OnTextChanged", function(_, userInput) if userInput then UI.Dirty() end end)
    f.text:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
    f.count = Text(f, "", "GameFontDisableSmall", 640, -48, 90, "RIGHT")
    Text(f, L.Q_TOPIC, "GameFontHighlightSmall", 4, -64)
    local labels = {}
    for i, tp in ipairs(ns.Questions.TOPICS) do labels[i] = TopicName(tp) end
    p.pickTopic = UI.Choice(f, labels, 88, -58, 86, function(i)
        if p.form then p.form.topic = ns.Questions.TOPICS[i] end
    end)
    Text(f, L.Q_LINKS, "GameFontHighlightSmall", 4, -94)
    local function Target() return p.form and p.form.links end
    f.item = ItemButton(f, 88, -88, Target)
    Button(f, L.Q_ADD_QUEST, 70, 162, -88, function() OpenPicker("quest", Target()) end, 20)
    Button(f, L.Q_ADD_DUNGEON, 80, 236, -88, function() OpenPicker("dungeon", Target()) end, 20)
    f.linkHint = Text(f, L.Q_LINKS_HINT, "GameFontDisableSmall", 324, -93, 410)
    f.chosen = {}
    for i = 1, 2 do
        f.chosen[i] = LinkButton(f, 92 + (i - 1) * 320, -114, 310, function()
            if p.form then table.remove(p.form.links, i); UI.Dirty() end
        end)
    end
    f.alreadyHead = Header(f, L.Q_ALREADY, 0, -140, 736)
    f.already = {}
    for i = 1, 3 do
        local r = Row(f, 0, -162 - (i - 1) * 24, 736, 23)
        r.text = Text(r, "", "GameFontHighlightSmall", 6, -5, 600)
        r.info = Text(r, "", "GameFontDisableSmall", 610, -5, 120, "RIGHT")
        r:SetScript("OnClick", function(self)
            if self.key then p.form, p.openKey, p.postOffset = nil, self.key, 0; UI.Dirty() end
        end)
        f.already[i] = r
    end
    f.post = Button(f, L.Q_POST, 130, 0, -244, function()
        local key, why = ns.Questions.Ask(f.text:GetText() or "", p.form.topic, p.form.links)
        if key then
            p.form = nil
            f.text:SetText("")
            p.pickView(2)                   -- Mine, with the new card on top
        elseif why == "full" then ns.Print(string.format(L.Q_FULL, ns.Questions.MAX_OPEN))
        elseif why == "wait" then ns.Print(L.Q_WAIT)
        elseif why == "empty" then ns.Print(L.Q_EMPTY)
        end
        UI.Dirty()
    end, 24)
    Button(f, L.CANCEL, 90, 140, -244, function() p.form = nil; f.text:ClearFocus(); UI.Dirty() end, 24)
    local tip = Text(f, L.Q_TIP, "GameFontDisableSmall", 4, -282, 728)
    tip:SetWordWrap(true)
    tip:SetHeight(56)
    tip:SetJustifyV("TOP")
end

local function Build(p)
    thePage = p
    BuildList(p)
    BuildCard(p)
    BuildForm(p)
    BuildPicker(p)
    p.pickView(1)
    p.pickTopicFilter(1)
end

---------------------------------------------------------------------------------------------------
-- Refresh

-- noLeft: without the time left (the card's sidebar shows that on its own line).
local function StatusText(q, now, noLeft)
    local Q = ns.Questions
    local s = Q.State(q, now)
    local n = Q.AnswerCount(q)
    if s == "done" then
        local helped = {}
        for _, name in ipairs(Q.Helpers(q)) do helped[#helped + 1] = MemberName(name) end
        return ns.GREEN .. L.Q_ANSWERED .. "|r" .. (#helped > 0 and ("  " .. ns.GREY .. string.format(L.Q_HELPED, table.concat(helped, ", ")) .. "|r") or "")
    elseif s == "removed" then
        return ns.GREY .. L.Q_REMOVED .. "|r"
    elseif s == "cancel" then
        return ns.GREY .. L.Q_TAKEN_DOWN .. "|r"
    elseif s == "expired" then
        return ns.GREY .. (n > 0 and L.Q_NEVER_MARKED or L.Q_NOBODY_ANSWERED) .. "|r"
    elseif s == "waiting" then
        if q.owner == ns.me then return ns.GOLD .. string.format(L.Q_WAITING_YOU, n) .. "|r" end
        return string.format(L.Q_N_ANSWERS, n) .. "  " .. ns.GREY .. L.Q_WAITING_ASKER .. "|r"
    end
    local left = noLeft and "" or ("  " .. ns.GREY .. string.format(L.Q_LEFT, Left(q.u - now)) .. "|r")
    if n == 0 then return ns.GOLD .. L.Q_NO_ANSWERS_YET .. "|r" .. left end
    return string.format(L.Q_N_ANSWERS, n) .. left
end

-- The sidebar: which view is picked, how many in each, the Lore Master, the alert tick.
local function RefreshSide(p)
    local Q = ns.Questions
    local c = Q.Counts()
    for i, card in ipairs(p.viewCards) do card.SetPicked(VIEWS[i] == p.view) end
    -- Open: how many, how many nobody has answered yet.
    local unanswered = 0
    if c.open > 0 then
        for _, q in ipairs(Q.List("open")) do if Q.AnswerCount(q) == 0 then unanswered = unanswered + 1 end end
    end
    p.viewCards[1].text:SetText(c.open > 0 and string.format(L.Q_CARD_OPEN, c.open) or (ns.GREY .. L.Q_CARD_NONE .. "|r"))
    p.viewCards[1].pts:SetText(unanswered > 0 and (ns.GOLD .. string.format(L.Q_CARD_UNANSWERED, unanswered) .. "|r") or "")
    -- Mine: how many, how many are waiting for me to mark.
    local waiting = 0
    if c.mine > 0 then
        local now = GetServerTime()
        for _, q in ipairs(Q.List("mine")) do if q.owner == ns.me and Q.State(q, now) == "waiting" then waiting = waiting + 1 end end
    end
    p.viewCards[2].text:SetText(c.mine > 0 and string.format(L.Q_CARD_MINE, c.mine) or (ns.GREY .. L.Q_CARD_NONE_MINE .. "|r"))
    p.viewCards[2].pts:SetText(waiting > 0 and (ns.GOLD .. string.format(L.Q_CARD_WAITING, waiting) .. "|r") or "")
    -- Resolved: how many (they stay 30 days).
    p.viewCards[3].text:SetText(string.format(L.Q_CARD_RESOLVED, c.answered))
    p.viewCards[3].pts:SetText(L.Q_CARD_RESOLVED_TIP)
    -- The alert: on or off.
    local on = ns.settings.qAlert == true
    p.alertMe.SetActive(on)
    p.alertMe.text:SetText(on and (ns.GREEN .. L.Q_ALERT_ON .. "|r") or (ns.GREY .. L.Q_ALERT_OFF .. "|r"))
    p.alertMe.pts:SetText(on and L.Q_ALERT_CLICK_OFF or L.Q_ALERT_CLICK_ON)
end

local VIEW_TITLES = { open = "Q_TITLE_OPEN", mine = "Q_TITLE_MINE", answered = "Q_TITLE_ANSWERED" }

local function RefreshList(p)
    local Q = ns.Questions
    RefreshSide(p)
    p.viewTitle:SetText(L[VIEW_TITLES[p.view]] or "")
    local list = Q.List(p.view, p.topic, p.search:GetText())
    local now = GetServerTime()
    local off = math.min(p.offset, math.max(0, #list - CARDS))
    p.offset = off
    p.pager.Set(off + 1, math.min(#list, off + CARDS), #list)
    p.empty:SetShown(#list == 0)
    if #list == 0 then
        local filtered = strtrim(p.search:GetText() or "") ~= "" or p.topic
        p.empty:SetText(filtered and L.Q_NONE_MATCH or (p.view == "open" and L.Q_NONE_OPEN)
            or (p.view == "mine" and L.Q_NONE_MINE) or L.Q_NONE_ANSWERED)
    end
    for i, c in ipairs(p.cards) do
        local q = list[off + i]
        c.key = q and q.key
        if q then
            c.title:SetText(ns.GREY .. "[" .. TopicName(q.tp) .. "]|r  " .. q.tx)
            c.when:SetText(string.format(L.Q_ASKED_AGO, Ago(now - (q.at or now))))
            local lk = LinksText(q.lk)
            c.who:SetText(string.format(L.Q_ASKED_BY, MemberName(q.owner)) .. (lk ~= "" and ("   " .. lk) or ""))
            c.status:SetText(StatusText(q, now))
            c:Show()
        else
            c:Hide()
        end
    end
end

local function RefreshCard(p, v, q)
    local Q = ns.Questions
    local now = GetServerTime()
    -- Another card: a half-typed reply and its links belong to the last one, not this one (Enter
    -- once posted them on the wrong question).
    if v.shownKey ~= q.key then
        v.shownKey = q.key
        v.reply:SetText("")
        v.reply:ClearFocus()
        p.replyLinks = {}
        if picker then picker:Hide() end
    end
    local mine = q.owner == ns.me
    local live = Q.Live(q, now)
    local marking = p.marking ~= nil and mine and live
    if not marking then p.marking = nil end
    -- An officer (not on their own question): Remove, and the x on others' posts. Asks first.
    local removedBy = Q.RemovedBy(q)
    local canRemove = Q.CanRemove() and not mine and not removedBy
    local removing = p.removing ~= nil and canRemove and not marking
        and (not p.removing.who or not Q.PostsRemoved(q, p.removing.who))
    if not removing then p.removing = nil end
    v.remove:SetShown(canRemove and not removing)
    v.rmAsk:SetShown(removing)
    v.rmYes:SetShown(removing)
    v.rmNo:SetShown(removing)
    if removing then
        v.rmAsk:SetText(p.removing.who and string.format(L.Q_REMOVE_ASK_POSTS, MemberName(p.removing.who)) or L.Q_REMOVE_ASK_Q)
    end
    -- The asker can mark it resolved any time it's live, answers or not: with answers they
    -- tick the ones that helped (or none), without they just click Done.
    v.mark:SetShown(mine and live and not marking)
    v.markHint:SetText(Q.AnswerCount(q) > 0 and L.Q_MARK_HINT or L.Q_MARK_HINT_NONE)
    v.cancel:SetShown(mine and live and not marking)
    v.markDone:SetShown(marking)
    v.markBack:SetShown(marking)
    v.markHint:SetShown(marking)
    -- Sidebar: where it's at.
    local state = Q.State(q, now)
    v.state:SetText(StatusText(q, now, true))
    v.left:SetText(state == "open" and string.format(L.Q_LEFT_ANSWER, Left(q.u - now))
        or (state == "waiting" and string.format(L.Q_LEFT_MARK, Left(q.u + Q.WAIT - now))) or "")
    v.topic:SetText(string.format(L.Q_TOPIC_IS, TopicName(q.tp)))
    if removedBy then
        v.sideHint:SetText(string.format(L.Q_REMOVED_BY, MemberName(removedBy)))
    elseif marking or removing then
        v.sideHint:SetText("")
    else
        v.sideHint:SetText(((live and (mine and L.Q_SIDE_ASKER or L.Q_SIDE_ANSWER)) or "")
            .. (canRemove and ("\n\n" .. L.Q_SIDE_OFFICER) or ""))
    end
    -- Right: who and when, then the question.
    v.info:SetText(string.format(L.Q_ASKED_BY, MemberName(q.owner)) .. ns.GREY .. "   " .. string.format(L.Q_ASKED_AGO, Ago(now - (q.at or now))) .. "|r")
    v.title:SetText(q.tx)
    for i = 1, 2 do v.links[i].Set(q.lk[i]) end
    local thread = Q.Thread(q)
    v.head:SetText(string.format(L.Q_THREAD, #thread))
    local maxOff = math.max(0, #thread - POSTS)
    local off = math.max(0, math.min(p.postOffset or 0, maxOff))
    p.postOffset = off
    v.postPager.Set(off + 1, math.min(#thread, off + POSTS), #thread)
    v.empty:SetShown(#thread == 0)
    for i, r in ipairs(v.posts) do
        local post = thread[off + i]
        r.post = post
        if post then
            local asker = post.name == q.owner
            local helped = q.hp and q.hp[post.name]
            r.who:SetText(MemberName(post.name) .. (asker and (ns.GOLD .. "  " .. L.Q_ASKER .. "|r") or "")
                .. (helped and (ns.GREEN .. "  " .. L.Q_HELPFUL .. "|r") or "")
                .. ns.GREY .. "  " .. string.format(L.Q_AGO, Ago(now - post.at)) .. "|r")
            r.text:SetText(post.tx)
            for j = 1, 2 do r.links[j].Set(post.lk and post.lk[j]) end
            r.stripe:SetColorTexture(asker and 0.9 or 1, asker and 0.76 or 1, asker and 0.36 or 1, asker and 0.08 or ((i % 2 == 0) and 0.04 or 0))
            r.del:SetShown(not marking and not removing and ((post.name == ns.me and live) or (canRemove and post.name ~= ns.me)))
            local canTick = marking and not asker
            r.tick:SetShown(canTick)
            if canTick then r.tick:SetChecked(p.marking[post.name] == true) end
            r:Show()
        else
            r:Hide()
        end
    end
    -- The reply box: only while it's live, and not while marking.
    local mineGone = Q.PostsRemoved(q, ns.me)
    local canPost = live and not marking and not mineGone
    for _, w in ipairs({ v.reply, v.item, v.quest, v.dungeon, v.send }) do w:SetShown(canPost) end
    v.closed:SetShown(not canPost)
    v.closed:SetText(marking and "" or (removedBy and L.Q_REMOVED) or (mineGone and live and L.Q_MY_POSTS_REMOVED) or L.Q_CLOSED)
    for i = 1, 2 do
        v.pending[i].Set(canPost and p.replyLinks[i] or nil, ns.GREY .. " x|r")
    end
end

local function RefreshForm(p, f)
    local form = p.form
    local text = f.text:GetText() or ""
    f.count:SetText(ns.Letters(text) .. " / " .. ns.Questions.MAX_Q)
    for i = 1, 2 do f.chosen[i].Set(form.links[i], "  " .. ns.GREY .. L.Q_CLICK_REMOVE .. "|r") end
    f.linkHint:SetShown(#form.links == 0)
    local similar = ns.Questions.Similar(text, 3)
    f.alreadyHead:SetShown(#similar > 0)
    for i, r in ipairs(f.already) do
        local q = similar[i]
        r.key = q and q.key
        if q then
            r.text:SetText(q.tx)
            r.info:SetText(ns.GREEN .. L.Q_ANSWERED .. "|r")
            r:Show()
        else
            r:Hide()
        end
    end
end

local function Refresh(p)
    local q = p.openKey and ns.Questions.Get(p.openKey)
    if p.openKey and not q then p.openKey = nil end
    local inForm = p.form ~= nil
    p.listView:SetShown(not inForm and not q)
    p.cardView:SetShown(not inForm and q ~= nil)
    p.formFrame:SetShown(inForm)
    if inForm then RefreshForm(p, p.formFrame)
    elseif q then RefreshCard(p, p.cardView, q)
    else RefreshList(p) end
end

UI.AddPage("ask", Build, Refresh)

-- Open the Ask tab at one card (from a pop-up or Home).
function UI.ShowQuestion(key)
    UI.Open("ask")
    if thePage then
        thePage.form, thePage.openKey, thePage.postOffset, thePage.marking = nil, key, 1e6, nil
        UI.Dirty()
    end
end

-- Open the Ask tab at a view ("open", "mine", "answered").
function UI.ShowQuestions(view)
    UI.Open("ask")
    if thePage then
        thePage.form, thePage.openKey = nil, nil
        for i, v in ipairs(VIEWS) do if v == view then thePage.pickView(i) end end
        UI.Dirty()
    end
end

ns.Listen("QUESTIONS", UI.Dirty)
