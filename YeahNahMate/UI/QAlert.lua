-- Ask the Guild (8c): a small alert for each new question, for guildies who tick "Alert me when
-- someone asks" on the Ask tab (off until ticked). Smaller than the pop-ups and out of the way:
-- one line, movable (drag it; where it's left is saved), click opens the card, right-click closes it
-- (and any waiting). It fades after 15 s (not while the mouse is on it), shows one at a time with
-- "+N more", waits until out of combat and out of instances, and makes no sound.
local ADDON, ns = ...
local L = ns.L
local UI = ns.UI

local QAlert = {}
ns.QAlert = QAlert

QAlert.SHOW_FOR = 15
local FADE = 1
local MAX_QUEUE = 10
local W, H = 300, 42

local frame, queue, waiting = nil, {}, false
local shownAt

local function Short(s, n) return ns.ShortText(s, n) end

local function SavePosition()
    local point, _, relPoint, x, y = frame:GetPoint(1)
    if point then ns.settings.qAlertPos = { point, relPoint, math.floor(x + 0.5), math.floor(y + 0.5) } end
end

local function Place()
    frame:ClearAllPoints()
    local pos = ns.settings.qAlertPos
    if type(pos) == "table" and type(pos[3]) == "number" and type(pos[4]) == "number" then
        frame:SetPoint(pos[1] or "TOP", UIParent, pos[2] or "TOP", pos[3], pos[4])
    else
        frame:SetPoint("TOP", UIParent, "TOP", 0, -186)
    end
end

local Next

local function Close(all)
    if all then queue = {} end
    frame:Hide()
    frame.key = nil
    C_Timer.After(1, function() ns.Safe(Next) end)
end

local function Build()
    frame = UI.Box(UIParent, 0, 0, W, H)
    frame:SetFrameStrata("HIGH")
    frame:SetBackdropColor(0, 0, 0, 0.85)
    frame:SetBackdropBorderColor(0.9, 0.76, 0.36, 0.9)
    frame:SetClampedToScreen(true)
    frame:SetMovable(true)
    Place()
    frame:Hide()
    local icon = frame:CreateTexture(nil, "ARTWORK")
    icon:SetSize(24, 24)
    icon:SetPoint("LEFT", 9, 0)
    icon:SetTexture("Interface\\Icons\\INV_Misc_Note_01")
    frame.title = UI.Text(frame, "", "GameFontNormalSmall", 40, -6, 196)
    frame.more = UI.Text(frame, "", "GameFontDisableSmall", 236, -6, 56, "RIGHT")
    frame.text = UI.Text(frame, "", "GameFontHighlightSmall", 40, -22, 252)

    local b = CreateFrame("Button", nil, frame)
    frame.btn = b
    b:SetAllPoints()
    b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    b:RegisterForDrag("LeftButton")
    b:SetScript("OnDragStart", function() frame:StartMoving() end)
    -- The mouse-up that ends a drag isn't a click. (The game may or may not send OnClick after a
    -- drag, so only a click within a moment of letting go is ignored.)
    b:SetScript("OnDragStop", function() frame:StopMovingOrSizing(); SavePosition(); frame.droppedAt = GetTime() end)
    b:SetScript("OnClick", function(_, button)
        if frame.droppedAt and GetTime() - frame.droppedAt < 0.3 then frame.droppedAt = nil return end
        if button == "RightButton" then Close(true) return end
        local key = frame.key
        Close(false)
        if key then UI.ShowQuestion(key) end
    end)
    b:SetScript("OnEnter", function(self)
        frame:SetAlpha(1)
        frame.hover = true
        if not GameTooltip then return end
        GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
        local q = frame.key and ns.Questions.Get(frame.key)
        if q then GameTooltip:AddLine(q.tx, 1, 1, 1, true) end
        GameTooltip:AddLine(L.QALERT_TIP, 0.6, 0.6, 0.6, true)
        GameTooltip:Show()
    end)
    b:SetScript("OnLeave", function()
        frame.hover = nil
        shownAt = GetTime()                 -- the full time again after reading it
        if GameTooltip then GameTooltip:Hide() end
    end)
    frame:SetScript("OnUpdate", function()
        if frame.hover or not shownAt then return end
        local t = GetTime() - shownAt
        if t < QAlert.SHOW_FOR then return end
        local a = 1 - (t - QAlert.SHOW_FOR) / FADE
        if a <= 0 then shownAt = nil; Close(false) else frame:SetAlpha(a) end
    end)
end

-- Can it show now? Not in combat, not in a dungeon or raid.
local function Quiet()
    if InCombatLockdown and InCombatLockdown() then return true end
    if IsInInstance then
        local inside = IsInInstance()
        if inside then return true end
    end
    return false
end

-- Still worth showing: still open, and not answered by me already.
local function StillOpen(key)
    local q = ns.Questions.Get(key)
    if not q or ns.Questions.State(q) ~= "open" then return nil end
    if q.posts and q.posts[ns.me] and #q.posts[ns.me].p > 0 then return nil end
    return q
end

local function MoreText()
    local n = 0
    for _, k in ipairs(queue) do if StillOpen(k) then n = n + 1 end end
    return n > 0 and string.format(L.QALERT_MORE, n) or ""
end

Next = function()
    if not ns.settings.qAlert then queue = {} return end
    if frame and frame:IsShown() then frame.more:SetText(MoreText()) return end
    if #queue == 0 then return end
    if Quiet() then
        if not waiting then
            waiting = true
            C_Timer.After(5, function() waiting = false; ns.Safe(Next) end)
        end
        return
    end
    local q
    while #queue > 0 and not q do
        q = StillOpen(table.remove(queue, 1))
    end
    if not q then return end
    if not frame then Build() end
    frame.key = q.key
    frame.title:SetText(string.format(L.QALERT_TITLE, q.owner:match("^%S+") or q.owner))
    frame.text:SetText(Short(q.tx, 48))
    frame.more:SetText(MoreText())
    frame:SetAlpha(1)
    frame:Show()
    shownAt = GetTime()
end

function QAlert.IsShown() return frame ~= nil and frame:IsShown() end
function QAlert.Key() return frame and frame:IsShown() and frame.key or nil end
function QAlert.Queued() return #queue end
QAlert.Next = function() ns.Safe(Next) end
-- For tests: click it as a player would.
function QAlert.Click(button) if frame then frame.btn:GetScript("OnClick")(frame.btn, button or "LeftButton") end end

ns.Listen("QUESTION_ASKED", function(q)
    if not ns.settings.qAlert or not q or q.owner == ns.me then return end
    for _, k in ipairs(queue) do if k == q.key then return end end
    if #queue >= MAX_QUEUE then table.remove(queue, 1) end
    queue[#queue + 1] = q.key
    ns.Safe(Next)
end)

-- Ticked off: nothing more shows.
ns.Listen("SETTINGS", function()
    if not ns.settings.qAlert then
        queue = {}
        if frame and frame:IsShown() then frame:Hide() end
    end
end)
