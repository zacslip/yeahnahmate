-- About panel: a small round "i" button just right of the version in the window's banner (top right)
-- opens a panel over the window with your version (and whether a guildie has a newer one), the slash
-- commands, and how to report a problem. Click the button again, or the panel's X, to close it.
local ADDON, ns = ...
local L = ns.L
local UI = ns.UI

local PW, PH = 440, 344

-- Slash commands, as Core.lua's ns.Slash and Voice.Command handle them (dev commands left out).
local COMMANDS = {
    { "/ynm", "ABOUT_CMD_OPEN" },
    { "/ynm voice", "ABOUT_CMD_VOICE" },
    { "/ynm voice join", "ABOUT_CMD_VJOIN" },
    { "/ynm voice group", "ABOUT_CMD_VGROUP" },
    { "/ynm voice guild", "ABOUT_CMD_VGUILD" },
    { "/ynm voice leave", "ABOUT_CMD_VLEAVE" },
    { "/ynm log", "ABOUT_CMD_LOG" },
    { "/ynm errors", "ABOUT_CMD_ERRORS" },
    { "/ynm reset", "ABOUT_CMD_RESET" },
}
UI.ABOUT_COMMANDS = COMMANDS

local panel

local function Wrapped(parent, text, font, x, y, w, h)
    local fs = UI.Text(parent, text, font, x, y, w)
    fs:SetWordWrap(true)
    fs:SetHeight(h)
    fs:SetJustifyV("TOP")
    return fs
end

local function Refresh()
    if not panel then return end
    local line = string.format(L.ABOUT_VERSION, ns.VERSION)
    if ns.Comm.newest then line = line .. "  " .. string.format(L.ABOUT_NEWER, ns.Comm.newest)
    else line = line .. "  " .. ns.GREY .. L.ABOUT_UPTODATE .. "|r" end
    panel.version:SetText(line)
end

local function BuildPanel(window, header)
    panel = UI.Box(window, 0, 0, PW, PH)
    panel:ClearAllPoints()
    panel:SetPoint("TOPRIGHT", header, "BOTTOMRIGHT", 0, -4)
    -- Over the tab buttons and pages, and solid, so the page underneath doesn't show through.
    panel:SetFrameLevel(window:GetFrameLevel() + 40)
    if panel.SetBackdropColor then panel:SetBackdropColor(0.05, 0.05, 0.05, 0.97) end
    panel:EnableMouse(true)          -- clicks on the panel don't fall through to the page

    UI.Text(panel, ns.GOLD .. L.ABOUT_TITLE .. "|r", "GameFontNormal", 12, -10)
    local x = CreateFrame("Button", nil, panel, "UIPanelCloseButton")
    x:SetPoint("TOPRIGHT", 2, 2)
    x:SetScript("OnClick", function() panel:Hide() end)

    panel.version = Wrapped(panel, "", "GameFontHighlightSmall", 12, -30, PW - 24, 26)

    UI.Header(panel, L.ABOUT_COMMANDS, 12, -60, PW - 24)
    local y = -82
    for _, c in ipairs(COMMANDS) do
        UI.Text(panel, "|cffffffff" .. c[1] .. "|r", "GameFontHighlightSmall", 16, y)
        UI.Text(panel, L[c[2]], "GameFontHighlightSmall", 130, y, PW - 142)
        y = y - 16
    end
    Wrapped(panel, ns.GREY .. L.ABOUT_KEYS .. "|r", "GameFontHighlightSmall", 16, y - 2, PW - 28, 26)

    UI.Header(panel, L.ABOUT_PROBLEM, 12, y - 32, PW - 24)
    Wrapped(panel, L.ABOUT_PROBLEM_TEXT, "GameFontHighlightSmall", 16, y - 54, PW - 28, 56)

    panel:SetScript("OnShow", Refresh)
    panel:Hide()
end

-- Called by UI/Window.lua when the window is built: the "i" button right of the version, and the panel.
function UI.BuildAbout(window, header)
    local b = CreateFrame("Button", nil, header)
    b:SetSize(20, 20)          -- 16 was too small (asked for 25% bigger)
    b:SetPoint("LEFT", header.ver, "RIGHT", 6, 0)
    local icon = b:CreateTexture(nil, "ARTWORK")
    icon:SetAllPoints()
    -- The game's round "i"; if this client hasn't got it, a plain gold "i".
    if not icon:SetTexture("Interface\\FriendsFrame\\InformationIcon") then
        icon:Hide()
        local t = b:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        t:SetPoint("CENTER")
        t:SetText("i")
    end
    b:SetHighlightTexture("Interface\\Buttons\\UI-Common-MouseHilight", "ADD")
    b:SetScript("OnClick", function()
        if not panel then BuildPanel(window, header) end
        panel:SetShown(not panel:IsShown())
    end)
    b:SetScript("OnEnter", function(self)
        if not GameTooltip then return end
        GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
        GameTooltip:AddLine(L.ABOUT_TIP, 1, 1, 1)
        GameTooltip:Show()
    end)
    b:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
    -- Closing the window closes the panel too, so it doesn't pop up again next time.
    window:HookScript("OnHide", function() if panel then panel:Hide() end end)
    UI.aboutButton = b
    return b
end

-- For tests.
function UI.AboutPanel() return panel end
