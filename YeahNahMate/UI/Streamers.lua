-- Streamers tab: guildmates who stream, live ones first, each with their own card (Board.lua).
-- WoW can't open web links, so the Twitch address sits in a box you can copy from (click, Ctrl+C).
-- On the right: my own card.
local ADDON, ns = ...
local L = ns.L
local UI = ns.UI
local Text, Button, Box, Header = UI.Text, UI.Button, UI.Box, UI.Header

local LEFT_W = 470
local X = 490
local RIGHT_W = 246
local CARDS = 4
local RED = "|cffff3030"

local function Field(parent, label, y, max)
    Text(parent, label, "GameFontHighlightSmall", 2, y)
    local box = CreateFrame("EditBox", nil, parent, "InputBoxTemplate")
    box:SetSize(RIGHT_W - 10, 20)
    box:SetPoint("TOPLEFT", 8, y - 14)
    box:SetAutoFocus(false)
    box:SetMaxLetters(max)
    box:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    box:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
    return box
end

local function Build(p)
    p.offset = 0
    Header(p, L.STREAMERS_HEADER, 0, -4, LEFT_W)
    p.list = CreateFrame("Frame", nil, p)
    p.list:SetPoint("TOPLEFT", 0, -26)
    p.list:SetSize(LEFT_W, 380)
    p.list:EnableMouseWheel(true)
    p.list:SetScript("OnMouseWheel", function(_, delta) p.offset = math.max(0, p.offset - delta); UI.Dirty() end)
    p.cards = {}
    for i = 1, CARDS do
        local c = Box(p.list, 0, -(i - 1) * 88, LEFT_W, 84)
        c.name = Text(c, "", "GameFontHighlight", 12, -10, 300)
        c.live = Text(c, "", "GameFontNormal", 330, -10, 128, "RIGHT")
        c.when = Text(c, "", "GameFontHighlightSmall", 12, -28, 446)
        c.about = Text(c, "", "GameFontHighlightSmall", 12, -44, 446)
        c.link = UI.CopyBox(c, 12, -58, 220)
        c.hint = Text(c, L.COPY_HINT, "GameFontDisableSmall", 250, -62, 210)
        -- Streamers moderators: edit or take down anyone's card.
        c.modEdit = Button(c, L.EDIT, 46, LEFT_W - 124, -56, function()
            if not c.who then return end
            p.mine.target, p.mine.loaded = c.who, false
            UI.Dirty()
        end, 18)
        c.modX = UI.ModRemove(c, LEFT_W - 74, -56, function() return c.who end, function(k)
            ns.Board.ModRemoveStreamer(k)
            if p.mine.target == k then p.mine.target, p.mine.loaded = nil, false end
        end)
        p.cards[i] = c
    end
    p.empty = Text(p.list, L.NO_STREAMERS, "GameFontDisableSmall", 4, -8, 460)
    p.empty:SetWordWrap(true)
    p.empty:SetHeight(30)
    p.empty:SetJustifyV("TOP")
    p.pager = UI.Pager(p.list, LEFT_W - 142, -356, function(d) p.offset = math.max(0, p.offset + d * CARDS); UI.Dirty() end)

    -- My card
    local f = CreateFrame("Frame", nil, p)
    f:SetPoint("TOPLEFT", X, 0)
    f:SetSize(RIGHT_W, 410)
    p.mine = f
    Header(f, L.MY_STREAM_CARD, 0, -4, RIGHT_W)
    f.tw = Field(f, L.TWITCH_NAME, -28, 40)
    f.when = Field(f, L.STREAM_WHEN, -66, 60)
    f.about = Field(f, L.STREAM_ABOUT, -104, 100)
    f.head = Text(f, "", "GameFontNormalSmall", 2, -20, RIGHT_W)
    f.save = Button(f, L.SAVE, 110, 0, -146, function()
        local ok
        if f.target then
            ok = ns.Board.ModStreamer(f.target, f.tw:GetText() or "", f.when:GetText() or "", f.about:GetText() or "")
            if ok then f.target = nil end
        else
            ok = ns.Board.SetStreamer(f.tw:GetText() or "", f.when:GetText() or "", f.about:GetText() or "")
        end
        if ok then
            f.loaded = false
            UI.Dirty()
        else
            ns.Print(L.TWITCH_BAD)
        end
    end, 24)
    f.stopEdit = Button(f, L.CANCEL, 120, 120, -146, function() f.target, f.loaded = nil, false; UI.Dirty() end, 24)
    f.remove = Button(f, L.REMOVE_CARD, 120, 120, -146, function() ns.Board.RemoveStreamer(); f.loaded = false end, 24)
    f.liveBtn = Button(f, L.GO_LIVE, RIGHT_W, 0, -184, function()
        local s = ns.Board.Mine()
        if not s then return end
        -- The same "live" the button's label shows (live switches itself off after 6 hours).
        local live = s.live and s.liveAt and GetServerTime() - s.liveAt < ns.Board.LIVE_FOR
        ns.Board.SetLive(not live)
    end, 26)
    f.status = Text(f, "", "GameFontHighlightSmall", 2, -218, RIGHT_W)
    local tip = Text(f, L.STREAM_TIP, "GameFontDisableSmall", 2, -240, RIGHT_W)
    tip:SetWordWrap(true)
    tip:SetHeight(70)
    tip:SetJustifyV("TOP")
end

local function Refresh(p)
    local B = ns.Board
    local list = B.Streamers()
    local now = GetServerTime()
    if p.offset > math.max(0, #list - CARDS) then p.offset = math.max(0, #list - CARDS) end
    p.empty:SetShown(#list == 0)
    p.pager.Set(p.offset + 1, math.min(#list, p.offset + CARDS), #list)
    for i, c in ipairs(p.cards) do
        local e = list[p.offset + i]
        if e then
            local m = ns.Guild.Get(e.name)
            local who = (m and UI.Name(m, true)) or e.name
            c.name:SetText(who .. (e.name == ns.me and (ns.GREY .. " (" .. L.YOU .. ")|r") or ""))
            c.live:SetText(e.live and (RED .. L.LIVE_NOW .. "|r") or "")
            c.when:SetText(e.s.when ~= "" and (ns.GOLD .. L.STREAMS .. "|r " .. e.s.when) or "")
            c.about:SetText(e.s.about or "")
            c.link.SetValue("twitch.tv/" .. e.s.tw)
            c.who = e.name
            local mod = e.name ~= ns.me and B.Moderates("strm")
            c.modEdit:SetShown(mod)
            c.modX.Sync(mod)
            c.hint:SetShown(not mod)
            c:Show()
        else
            c:Hide()
        end
    end

    local f = p.mine
    -- Editing someone else's card (a moderator): their card in the form, Save changes theirs.
    if f.target then
        local t = B.Store() and B.Store().streamers[f.target]
        if not t or t.x or not B.Moderates("strm") then f.target, f.loaded = nil, false end
    end
    f.head:SetText(f.target and (ns.GOLD .. string.format(L.EDITING_CARD, f.target) .. "|r") or "")
    f.stopEdit:SetShown(f.target ~= nil)
    if f.target then
        local t = B.Store().streamers[f.target]
        if not f.loaded then
            f.loaded = true
            f.tw:SetText(t.tw or ""); f.when:SetText(t.when or ""); f.about:SetText(t.about or "")
        end
        f.remove:Hide(); f.liveBtn:Hide()
        f.status:SetText("")
        return
    end
    local s = B.Mine()
    if not f.loaded then
        f.loaded = true
        f.tw:SetText(s and s.tw or "")
        f.when:SetText(s and s.when or "")
        f.about:SetText(s and s.about or "")
    end
    f.remove:SetShown(s ~= nil)
    f.liveBtn:SetShown(s ~= nil)
    if s then
        local live = s.live and s.liveAt and now - s.liveAt < B.LIVE_FOR
        f.liveBtn:SetText(live and L.STOP_LIVE or L.GO_LIVE)
        f.status:SetText(live and (RED .. L.YOURE_LIVE .. "|r") or (ns.GREY .. L.NOT_LIVE .. "|r"))
    else
        f.status:SetText(ns.GREY .. L.NO_CARD_YET .. "|r")
    end
end

UI.AddPage("streamers", Build, Refresh)
