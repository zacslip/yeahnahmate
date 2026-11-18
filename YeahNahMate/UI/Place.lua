-- Meeting places: an event's spot (set with Here in the event form) pinned on the world map and the
-- minimap, through HereBeDragons-Pins.
local ADDON, ns = ...
local UI = ns.UI

local Place = {}
UI.Place = Place

local HBD_Pins = LibStub("HereBeDragons-Pins-2.0")
local REF = "YeahNahMate-place"

-- The map's name, or nil.
function Place.MapName(mapID)
    local info = mapID and C_Map and C_Map.GetMapInfo and C_Map.GetMapInfo(mapID)
    return info and ns.Public(info.name, "string") or nil
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

function Place.Unpin()
    if worldPin then HBD_Pins:RemoveWorldMapIcon(REF, worldPin); worldPin:Hide() end
    if miniPin then HBD_Pins:RemoveMinimapIcon(REF, miniPin); miniPin:Hide() end
    pinned = nil
    ns.Fire("PLACE")
end

-- key: which event (so its card can say Unpin). x, y are 0-1.
function Place.Pin(key, mapID, x, y, title, text)
    Place.Unpin()
    worldPin = worldPin or MakePin(20)
    miniPin = miniPin or MakePin(14)
    pinned = { key = key, title = title, text = text }
    HBD_Pins:AddWorldMapIconMap(REF, worldPin, mapID, x, y, HBD_PINS_WORLDMAP_SHOW_CONTINENT)
    HBD_Pins:AddMinimapIconMap(REF, miniPin, mapID, x, y, false, true)
    ns.Fire("PLACE")
end

function Place.PinnedKey() return pinned and pinned.key or nil end
