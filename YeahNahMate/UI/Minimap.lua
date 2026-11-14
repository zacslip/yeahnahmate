-- Minimap button: click to open, drag around the minimap's edge. Can be hidden in Settings.
local ADDON, ns = ...
local L = ns.L
local UI = ns.UI

local button

local function Place()
    local a = math.rad(ns.settings.minimapAngle or 200)
    local r = Minimap:GetWidth() / 2 + 5
    button:ClearAllPoints()
    button:SetPoint("CENTER", Minimap, "CENTER", math.cos(a) * r, math.sin(a) * r)
end

local function Build()
    local b = CreateFrame("Button", "YeahNahMateMinimapButton", Minimap)
    b:SetSize(31, 31)
    b:SetFrameStrata("MEDIUM")
    b:SetFrameLevel(8)
    b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    b:RegisterForDrag("LeftButton")
    b:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")
    local bg = b:CreateTexture(nil, "BACKGROUND")
    bg:SetSize(20, 20)
    bg:SetTexture("Interface\\Minimap\\UI-Minimap-Background")
    bg:SetPoint("TOPLEFT", 7, -5)
    local icon = b:CreateTexture(nil, "ARTWORK")
    icon:SetSize(21, 21)
    icon:SetTexture(UI.MINI)
    icon:SetPoint("TOPLEFT", 6, -5)
    -- Round, to sit inside the button's ring (a texture of our own; nothing of the game's is changed).
    if icon.SetMask then icon:SetMask("Interface\\CharacterFrame\\TempPortraitAlphaMask") end
    local border = b:CreateTexture(nil, "OVERLAY")
    border:SetSize(53, 53)
    border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
    border:SetPoint("TOPLEFT")

    -- Dragging only runs OnUpdate while the mouse button is held.
    b:SetScript("OnDragStart", function(self)
        self:SetScript("OnUpdate", function()
            local mx, my = Minimap:GetCenter()
            local cx, cy = GetCursorPosition()
            local s = Minimap:GetEffectiveScale()
            ns.settings.minimapAngle = math.deg(math.atan2(cy / s - my, cx / s - mx))
            Place()
        end)
    end)
    b:SetScript("OnDragStop", function(self) self:SetScript("OnUpdate", nil) end)
    b:SetScript("OnClick", function() ns.Safe(UI.Toggle) end)
    b:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:AddLine(ns.Guild.name or L.ADDON)
        if ns.Guild.name then GameTooltip:AddLine(L.ADDON, 0.6, 0.6, 0.6) end
        GameTooltip:AddLine(L.MINIMAP_TIP, 1, 1, 1)
        GameTooltip:Show()
    end)
    b:SetScript("OnLeave", function() GameTooltip:Hide() end)
    button = b
    Place()
end

local function Update()
    if not Minimap then return end
    if ns.settings.minimap then
        if not button then Build() end
        button:Show()
    elseif button then
        button:Hide()
    end
end

ns.Listen("LOADED", Update)
ns.Listen("SETTINGS", Update)
