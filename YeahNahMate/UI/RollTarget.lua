-- Whisper and Target on each row of the roll lists (Clan roll results, its pop-out, All clans roll winners).
--   Whisper: opens our own whisper box (UI/Whisper.lua) to that player, with "You won ..." filled in
--            for a winner; nothing is sent until the player presses Send.
--   Target:  targets that player. Targeting is protected, so it's a secure button (the game does the
--            targeting from the player's own click) and it only works on someone in my group (by
--            their party/raid unit); anyone else gets it greyed out, saying why. It is parented to UIParent
--            and NOT anchored to the row: it's placed at the row's spot on screen (by numbers, again
--            whenever the list redraws or the window is dragged). A secure frame anchored to (or inside)
--            our window makes the game protect the whole window, and a protected window can't be told to
--            pass keys on: with the window open, / and Enter never reached chat (0.28.0 before release).
--            While the window is dragged they're placed again every frame, so they move with it.
--            In a fight nothing secure can be changed, so every Target button hides when combat
--            starts and comes back after it.
local ADDON, ns = ...
local L = ns.L
local UI = ns.UI

ns.RollTarget = {}
local T = ns.RollTarget

local BTN_W, BTN_H = 50, 15
local buttons = {}                   -- every Target button made, to hide them all when a fight starts
local HookDrag

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

-- Puts a Target button over its row's spot on screen (false: the row has no spot yet). Same scale as the
-- row, so it lines up whatever the window's scale. Only by numbers against UIParent (see the top).
local function Place(t)
    local row = t.row
    local l, top = row:GetLeft(), row:GetTop()
    if not l or not top then return false end
    local ui = UIParent:GetEffectiveScale()
    t:SetScale((row:GetEffectiveScale() or 1) / ((ui and ui > 0) and ui or 1))
    t:ClearAllPoints()
    t:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", l + t.dx, top - 1)
    t:SetFrameStrata(row:GetFrameStrata() or "HIGH")
    t:SetFrameLevel((row:GetFrameLevel() or 1) + 5)
    return true
end

-- Every row with the buttons, by the window it's in (the main window, the roll pop-out).
local rowsIn = {}

-- Points every row at its player again: after a fight, a group change, or its window being dragged.
function T.RefreshAll(top)
    if Fight() then return end
    for win, rows in pairs(rowsIn) do
        if not top or win == top then
            for _, row in ipairs(rows) do T.Set(row, row.key) end
        end
    end
end

-- Dragging a window: its buttons aren't anchored, so they're placed again every frame while it moves
-- (only then; a plain frame's OnUpdate, nothing secure). Hiding them for the drag wasn't enough: a roll
-- redraws its list twice a second, which put them back at a stale spot, so they lagged behind.
local dragging
local follow = CreateFrame("Frame", nil, UIParent)
follow:Hide()
follow:SetScript("OnUpdate", function(self)
    local list = dragging and rowsIn[dragging]
    if not list or Fight() then dragging = nil; self:Hide(); return end
    for _, r in ipairs(list) do
        local t = r.targetBtn
        if t and t:IsShown() then Place(t) end
    end
end)
local function StopFollow(top)
    if dragging == top then dragging = nil; follow:Hide() end
end
function T.Dragging() return dragging end

-- Hooked once on each window rows are in.
HookDrag = function(row)
    local top = row
    while top:GetParent() and top:GetParent() ~= UIParent do top = top:GetParent() end
    local list = rowsIn[top]
    if not list then
        list = {}
        rowsIn[top] = list
        if top.HookScript then
            top:HookScript("OnDragStart", function()
                if Fight() then return end
                dragging = top
                follow:Show()
            end)
            top:HookScript("OnDragStop", function() StopFollow(top); T.RefreshAll(top) end)
            -- the window closing takes them all (as well as each row's own OnHide)
            top:HookScript("OnHide", function()
                StopFollow(top)
                if Fight() then return end
                for _, r in ipairs(list) do if r.targetBtn then r.targetBtn:Hide() end end
            end)
        end
    end
    list[#list + 1] = row
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
        t.row, t.dx = row, x + BTN_W + 2         -- where it goes; placed by Place, never anchored to the row
        t:SetText(L.CLANROLL_TARGET)
        Small(t)
        t:RegisterForClicks("AnyUp", "AnyDown")
        t:SetAttribute("type", "target")
        t:SetScript("OnEnter", function(self)
            if not GameTooltip then return end
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:AddLine(L.CLANROLL_TARGET, 1, 0.82, 0)
            GameTooltip:AddLine(self:IsEnabled() and L.CLANROLL_ROW_TARGET_TIP or L.CLANROLL_ROW_TARGET_OFF, 1, 1, 1, true)
            GameTooltip:Show()
        end)
        t:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
        t:SetMotionScriptsWhileDisabled(true)       -- greyed out still says why on hover
        t:Hide()
        row.targetBtn = t
        buttons[#buttons + 1] = t
        -- The row (or the window) going away takes its Target button with it.
        row:HookScript("OnHide", function() if not Fight() then t:Hide() end end)
        row:HookScript("OnShow", function() T.Set(row, row.key) end)
        HookDrag(row)
    end
end

-- Points a row's buttons at a player (nil: none). Whisper for any guildie; Target for anyone but me,
-- working only for someone in my group (greyed out for the rest), and never touched during a fight.
function T.Set(row, key)
    row.key = key
    if row.whisperBtn then
        row.whisperBtn:SetShown(key ~= nil and key ~= ns.me and ns.Guild.Get(key) ~= nil)
    end
    local t = row.targetBtn
    if not t or Fight() then return end
    if key and key ~= ns.me and row:IsVisible() and Place(t) then
        local unit = T.UnitFor(key)
        t:SetAttribute("unit", unit)               -- nil when not in my group: nothing to target
        t:SetEnabled(unit ~= nil)
        t:Show()
    else
        t:Hide()
    end
end

function T.Buttons() return buttons end

-- A fight: hide them all while that's still allowed; after it, the lists put them back.
ns.OnEvent("PLAYER_REGEN_DISABLED", function() for _, t in ipairs(buttons) do t:Hide() end end)
ns.OnEvent("PLAYER_REGEN_ENABLED", function() T.RefreshAll() end)
ns.OnEvent("GROUP_ROSTER_UPDATE", function() T.RefreshAll() end)
