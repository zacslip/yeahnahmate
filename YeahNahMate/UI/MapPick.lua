-- Meeting places on the map: picking a spot on the world map for an event, and pinning an event's
-- spot on the world map and minimap.
--
-- Picking: the player opens the map themselves (M; we never open, change or hook Blizzard's panels).
-- While picking, our own see-through layer sits over the map's zone and city views and takes left
-- clicks only. On the world and continent views it isn't there, so left-click still goes into a
-- zone; right-click and the mouse wheel always reach the map. We only read the map's id and where the
-- cursor is on it (checked on Forever with /ynm dev mappick, 18 Nov).
local ADDON, ns = ...
local L = ns.L
local UI = ns.UI

local MapPick = {}
UI.MapPick = MapPick

local HBD_Pins = LibStub("HereBeDragons-Pins-2.0")
local REF = "YeahNahMate-place"
local PICK_FOR = 180            -- picking stops by itself after 3 minutes

local layer, driver, onPick, started

local function Map() local W = WorldMapFrame; return type(W) == "table" and W or nil end
local function Scroll(W) local sc = W and W.ScrollContainer; return type(sc) == "table" and sc or nil end

-- The map's name, or nil.
function MapPick.MapName(mapID)
    local info = mapID and C_Map and C_Map.GetMapInfo and C_Map.GetMapInfo(mapID)
    return info and ns.Public(info.name, "string") or nil
end

-- A zone or city map (not the world or a continent)?
local function ZoneMap(mapID)
    local info = mapID and C_Map and C_Map.GetMapInfo and C_Map.GetMapInfo(mapID)
    local t = info and ns.Public(info.mapType, "number")
    return t ~= nil and t >= 3
end

local function ShownMapID(W)
    return W and W.GetMapID and ns.Public(W:GetMapID(), "number") or nil
end

function MapPick.Active() return onPick ~= nil end

function MapPick.Stop()
    onPick = nil
    if layer then layer:Hide() end
    if driver then driver:Hide() end
    ns.Fire("MAPPICK")
end

local function Build(W, sc)
    layer = CreateFrame("Frame", nil, UIParent)
    layer:SetFrameStrata("FULLSCREEN_DIALOG")
    layer:EnableMouse(true)
    if layer.SetPassThroughButtons then pcall(layer.SetPassThroughButtons, layer, "RightButton", "MiddleButton") end
    local tint = layer:CreateTexture(nil, "BACKGROUND")
    tint:SetAllPoints()
    tint:SetColorTexture(1, 0.82, 0, 0.06)
    local bar = layer:CreateTexture(nil, "ARTWORK")
    bar:SetPoint("TOPLEFT", 0, 0)
    bar:SetPoint("TOPRIGHT", 0, 0)
    bar:SetHeight(24)
    bar:SetColorTexture(0, 0, 0, 0.7)
    local hint = layer:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    hint:SetPoint("TOP", 0, -5)
    hint:SetText(L.PLACE_LAYER_HINT)
    layer:SetScript("OnMouseUp", function(_, button)
        if button ~= "LeftButton" or not onPick then return end
        local mapID = ShownMapID(W)
        local ok, x, y = pcall(sc.GetNormalizedCursorPosition, sc)
        x, y = ok and ns.Public(x, "number"), ok and ns.Public(y, "number")
        if not (mapID and ZoneMap(mapID) and x and y and x >= 0 and x <= 1 and y >= 0 and y <= 1) then return end
        local fn = onPick
        MapPick.Stop()
        ns.Safe(fn, mapID, math.floor(x * 1000 + 0.5), math.floor(y * 1000 + 0.5))
    end)
    layer:Hide()
    driver = CreateFrame("Frame", nil, UIParent)
    driver:SetScript("OnUpdate", function()
        if GetTime() - started > PICK_FOR then MapPick.Stop() return end
        local on = W:IsShown() and ZoneMap(ShownMapID(W))
        if on and not layer:IsShown() then
            layer:ClearAllPoints()
            layer:SetAllPoints(sc)
            layer:Show()
        elseif not on and layer:IsShown() then
            layer:Hide()
        end
    end)
end

-- Start picking: fn(mapID, x, y) with x, y as 0-1000. Returns false if this game has no world map
-- we can read.
function MapPick.Start(fn)
    local W = Map()
    local sc = Scroll(W)
    if not (W and sc and sc.GetNormalizedCursorPosition) then return false end
    if not layer then Build(W, sc) end
    onPick, started = fn, GetTime()
    layer:Hide()
    driver:Show()
    ns.Fire("MAPPICK")
    return true
end

---------------------------------------------------------------------------------------------------
-- Pins: one event's meeting place at a time, on the world map and the minimap (at the edge when
-- it's further away), until unpinned or the next /reload.

local pinned, worldPin, miniPin

local function MakePin(size)
    local f = CreateFrame("Frame", nil, UIParent)
    f:SetSize(size, size)
    local t = f:CreateTexture(nil, "OVERLAY")
    t:SetAllPoints()
    t:SetTexture("Interface\\TargetingFrame\\UI-RaidTargetingIcon_1")
    f:EnableMouse(true)
    f:SetScript("OnEnter", function(self)
        if not (GameTooltip and pinned) then return end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:AddLine(pinned.title)
        if pinned.text then GameTooltip:AddLine(pinned.text, 1, 1, 1, true) end
        GameTooltip:Show()
    end)
    f:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
    return f
end

function MapPick.Unpin()
    if worldPin then HBD_Pins:RemoveWorldMapIcon(REF, worldPin); worldPin:Hide() end
    if miniPin then HBD_Pins:RemoveMinimapIcon(REF, miniPin); miniPin:Hide() end
    pinned = nil
    ns.Fire("MAPPICK")
end

-- key: which event (so its card can say Unpin). x, y are 0-1.
function MapPick.Pin(key, mapID, x, y, title, text)
    MapPick.Unpin()
    worldPin = worldPin or MakePin(20)
    miniPin = miniPin or MakePin(14)
    pinned = { key = key, title = title, text = text }
    HBD_Pins:AddWorldMapIconMap(REF, worldPin, mapID, x, y, HBD_PINS_WORLDMAP_SHOW_CONTINENT)
    HBD_Pins:AddMinimapIconMap(REF, miniPin, mapID, x, y, false, true)
    ns.Fire("MAPPICK")
end

function MapPick.PinnedKey() return pinned and pinned.key or nil end
