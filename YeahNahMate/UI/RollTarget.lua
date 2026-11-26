-- Whisper and Target on each row of the roll lists (Clan roll results, All clans roll winners).
--   Whisper: opens our own whisper box (UI/Whisper.lua) to that player, with "You won ..." filled in
--            for a winner; nothing is sent until the player presses Send.
--   Target:  targets that player. Targeting is protected, so it's a secure button (the game does the
--            targeting from the player's own click) and it only works on someone in my group (by
--            their party/raid unit). It is parented to UIParent and only anchored to the row: a secure
--            child would make our whole window protected, so it couldn't open or close in a fight.
--            In a fight nothing secure can be changed, so every Target button hides when combat
--            starts and comes back after it.
local ADDON, ns = ...
local L = ns.L
local UI = ns.UI

ns.RollTarget = {}
local T = ns.RollTarget

local BTN_W, BTN_H = 50, 15
local buttons = {}                   -- every Target button made, to hide them all when a fight starts

local function Fight() return InCombatLockdown and InCombatLockdown() or false end

-- The unit token of someone in my group ("player" for me), or nil.
function T.UnitFor(key)
    if not key then return nil end
    if key == ns.me then return "player" end
    local n = GetNumGroupMembers and GetNumGroupMembers() or 0
    if n == 0 then return nil end
    local prefix = (IsInRaid and IsInRaid()) and "raid" or "party"
    for i = 1, math.max(n, 4) do
        if ns.UnitKey(prefix .. i) == key then return prefix .. i end
    end
    return nil
end

local function Small(b)
    if b.SetNormalFontObject and GameFontNormalSmall then
        b:SetNormalFontObject(GameFontNormalSmall)
        b:SetHighlightFontObject(GameFontHighlightSmall)
        b:SetDisabledFontObject(GameFontDisableSmall)
    end
end

-- Adds Whisper and Target to a list's rows, at x on each row (Whisper, then Target right after it).
-- whisperText(row) gives the text to fill in (or nil).
function T.AddTo(rows, x, whisperText)
    for _, row in ipairs(rows) do
        local w = UI.Button(row, L.CLANROLL_WHISPER_SHORT, BTN_W, x, -1, function()
            local m = row.key and ns.Guild.Get(row.key)
            if m then ns.Whisper.Open(m, whisperText and whisperText(row) or nil) end
        end, BTN_H)
        Small(w)
        if ns.ClanRollUI.WithTip then ns.ClanRollUI.WithTip(w, { L.CLANROLL_WHISPER_SHORT, L.CLANROLL_ROW_WHISPER_TIP }) end
        row.whisperBtn = w

        local t = CreateFrame("Button", nil, UIParent, "SecureActionButtonTemplate,UIPanelButtonTemplate")
        t:SetSize(BTN_W, BTN_H)
        t:SetPoint("TOPLEFT", row, "TOPLEFT", x + BTN_W + 2, -1)
        t:SetText(L.CLANROLL_TARGET)
        Small(t)
        t:RegisterForClicks("AnyUp", "AnyDown")
        t:SetAttribute("type", "target")
        t:SetFrameStrata(row:GetFrameStrata() or "HIGH")
        t:SetFrameLevel((row:GetFrameLevel() or 1) + 5)
        t:SetScript("OnEnter", function(self)
            if not GameTooltip then return end
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:AddLine(L.CLANROLL_TARGET, 1, 0.82, 0)
            GameTooltip:AddLine(L.CLANROLL_ROW_TARGET_TIP, 1, 1, 1, true)
            GameTooltip:Show()
        end)
        t:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
        t:Hide()
        row.targetBtn = t
        buttons[#buttons + 1] = t
        -- The row (or the window) going away takes its Target button with it.
        row:HookScript("OnHide", function() if not Fight() then t:Hide() end end)
        row:HookScript("OnShow", function() T.Set(row, row.key) end)
    end
end

-- Points a row's buttons at a player (nil: none). Whisper for any guildie; Target only for someone in
-- my group, and never during a fight.
function T.Set(row, key)
    row.key = key
    if row.whisperBtn then
        row.whisperBtn:SetShown(key ~= nil and key ~= ns.me and ns.Guild.Get(key) ~= nil)
    end
    local t = row.targetBtn
    if not t or Fight() then return end
    local unit = key and key ~= ns.me and T.UnitFor(key)
    if unit and row:IsVisible() then
        t:SetAttribute("unit", unit)
        t:Show()
    else
        t:Hide()
    end
end

function T.Buttons() return buttons end

-- A fight: hide them all while that's still allowed; after it, the lists put them back.
ns.OnEvent("PLAYER_REGEN_DISABLED", function() for _, t in ipairs(buttons) do t:Hide() end end)
ns.OnEvent("PLAYER_REGEN_ENABLED", function() UI.Dirty() end)
ns.OnEvent("GROUP_ROSTER_UPDATE", function() if not Fight() then UI.Dirty() end end)
