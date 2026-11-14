-- Info tab: the guild's info page and the Home message, written by the officers (the editor ranks
-- and the managers, Board.lua). Everyone reads; editors get an Edit button. Which ranks may edit and
-- who the managers are is set on the GM tab.
local ADDON, ns = ...
local L = ns.L
local UI = ns.UI
local Text, Button, Box, Header = UI.Text, UI.Button, UI.Box, UI.Header

local W = 736

-- A box with a scrolling area inside (the game's scroll frame template: a scroll bar, nothing else).
local function ScrollBox(parent, x, y, w, h)
    local box = Box(parent, x, y, w, h)
    local sf = CreateFrame("ScrollFrame", nil, box, "UIPanelScrollFrameTemplate")
    sf:SetPoint("TOPLEFT", 8, -8)
    sf:SetPoint("BOTTOMRIGHT", -28, 8)
    box.scroll = sf
    return box
end

local thePage
local function Build(p)
    thePage = p
    p.editing = false
    Header(p, L.INFO_HEADER, 0, -4, W)
    p.by = Text(p, "", "GameFontDisableSmall", 200, -6, 430, "RIGHT")
    p.editBtn = Button(p, L.EDIT, 90, W - 90, 0, function()
        p.editing, p.loaded = true, false
        UI.Dirty()
    end)

    -- Reading
    p.read = CreateFrame("Frame", nil, p)
    p.read:SetAllPoints()
    local home = Box(p.read, 0, -28, W, 40)
    p.motd = Text(home, "", "GameFontHighlightSmall", 12, -8, W - 24)
    p.motd:SetWordWrap(true)
    p.motd:SetHeight(26)
    p.motd:SetJustifyV("TOP")
    p.dcLabel = Text(p.read, ns.GOLD .. L.DISCORD .. "|r", "GameFontNormal", 4, -78, 120)
    p.dcBox = UI.CopyBox(p.read, 120, -74, 260)
    p.dcHint = Text(p.read, L.COPY_HINT, "GameFontDisableSmall", 396, -78, 300)
    local box = ScrollBox(p.read, 0, -100, W, 304)
    p.textHolder = CreateFrame("Frame", nil, box.scroll)
    p.textHolder:SetSize(W - 40, 300)
    box.scroll:SetScrollChild(p.textHolder)
    p.text = p.textHolder:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    p.text:SetPoint("TOPLEFT", 4, -4)
    p.text:SetWidth(W - 48)
    p.text:SetJustifyH("LEFT")
    p.text:SetJustifyV("TOP")
    p.text:SetWordWrap(true)

    -- Editing
    p.edit = CreateFrame("Frame", nil, p)
    p.edit:SetAllPoints()
    p.edit:Hide()
    Text(p.edit, L.INFO_MOTD_LABEL, "GameFontHighlightSmall", 2, -30, 600)
    p.motdCount = Text(p.edit, "", "GameFontDisableSmall", W - 120, -30, 118, "RIGHT")
    p.motdBox = CreateFrame("EditBox", nil, p.edit, "InputBoxTemplate")
    p.motdBox:SetSize(W - 12, 20)
    p.motdBox:SetPoint("TOPLEFT", 8, -44)
    p.motdBox:SetAutoFocus(false)
    p.motdBox:SetMaxLetters(ns.Board.MAX_MOTD)
    p.motdBox:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    p.motdBox:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
    p.motdBox:SetScript("OnTextChanged", function() UI.Dirty() end)
    Text(p.edit, L.INFO_DISCORD_LABEL, "GameFontHighlightSmall", 2, -70, 300)
    p.dcEdit = CreateFrame("EditBox", nil, p.edit, "InputBoxTemplate")
    p.dcEdit:SetSize(300, 20)
    p.dcEdit:SetPoint("TOPLEFT", 304, -66)
    p.dcEdit:SetAutoFocus(false)
    p.dcEdit:SetMaxLetters(80)
    p.dcEdit:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    p.dcEdit:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
    Text(p.edit, L.INFO_TEXT_LABEL, "GameFontHighlightSmall", 2, -96, 600)
    p.textCount = Text(p.edit, "", "GameFontDisableSmall", W - 120, -96, 118, "RIGHT")
    local ebox = ScrollBox(p.edit, 0, -110, W, 230)
    p.textBox = CreateFrame("EditBox", nil, ebox.scroll)
    p.textBox:SetMultiLine(true)
    p.textBox:SetFontObject(ChatFontNormal or "GameFontHighlight")
    p.textBox:SetWidth(W - 48)
    p.textBox:SetHeight(206)
    p.textBox:SetAutoFocus(false)
    p.textBox:SetMaxLetters(ns.Board.MAX_TEXT)
    p.textBox:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    p.textBox:SetScript("OnTextChanged", function() UI.Dirty() end)
    ebox.scroll:SetScrollChild(p.textBox)
    -- Clicking anywhere in the box puts the cursor in the text.
    ebox:EnableMouse(true)
    ebox:SetScript("OnMouseDown", function() p.textBox:SetFocus() end)

    p.save = Button(p.edit, L.SAVE, 110, 0, -346, function()
        local ok = ns.Board.SetInfo(p.motdBox:GetText() or "", p.textBox:GetText() or "", p.dcEdit:GetText() or "")
        if ok then
            p.editing = false
            UI.Dirty()
        else
            ns.Print(L.DISCORD_BAD)
        end
    end, 24)
    p.cancel = Button(p.edit, L.CANCEL, 90, 120, -346, function() p.editing = false; UI.Dirty() end, 24)
end

local function Refresh(p)
    local B = ns.Board
    local info = B.Info()
    local canEdit = B.CanEdit()
    if p.editing and not canEdit then p.editing = false end
    p.read:SetShown(not p.editing)
    p.edit:SetShown(p.editing)
    p.editBtn:SetShown(canEdit and not p.editing)
    if info and info.by then
        p.by:SetText(string.format(L.INFO_BY, info.by, date("%d %b", info.ev)))
    else
        p.by:SetText("")
    end

    if not p.editing then
        local motd = info and info.motd ~= "" and info.motd
        p.motd:SetText(ns.GOLD .. L.INFO_ON_HOME .. "|r " .. (motd or (ns.GREY .. L.INFO_NO_MOTD .. "|r")))
        local dc = ns.Board.Discord()
        p.dcBox:SetShown(dc ~= nil)
        p.dcHint:SetShown(dc ~= nil)
        if dc then p.dcBox.SetValue(dc) end
        p.dcLabel:SetText(ns.GOLD .. L.DISCORD .. "|r" .. (dc and "" or ("  " .. ns.GREY .. L.NO_DISCORD .. "|r")))
        local text = info and info.text ~= "" and info.text
        p.text:SetText(text or (ns.GREY .. (canEdit and L.INFO_EMPTY_EDITOR or L.INFO_EMPTY) .. "|r"))
        local h = p.text.GetStringHeight and p.text:GetStringHeight()
        p.textHolder:SetHeight(math.max(300, (tonumber(h) or 0) + 12))
        return
    end

    if not p.loaded then
        p.loaded = true
        p.motdBox:SetText(info and info.motd or "")
        p.textBox:SetText(info and info.text or "")
        p.dcEdit:SetText(info and info.dc or "")
    end
    p.motdCount:SetText(string.format("%d / %d", #(p.motdBox:GetText() or ""), B.MAX_MOTD))
    p.textCount:SetText(string.format("%d / %d", #(p.textBox:GetText() or ""), B.MAX_TEXT))
end

UI.AddPage("info", Build, Refresh)

-- The GM tab's "Edit guild info": the Info tab, editing.
function UI.EditInfo()
    UI.Open("info")
    if thePage and ns.Board.CanEdit() and not thePage.editing then
        thePage.editing, thePage.loaded = true, false
        UI.Dirty()
    end
end
ns.Listen("BOARD", UI.Dirty)
