-- Guildies' nameplates: gold-style corner brackets round a guildie's nameplate, in their clan's colour,
-- and the guild owl on top, so guildies stand out in a crowd. Settings switch (on by default).
--
-- Only our own frames: each marker is a small frame of ours (parent UIParent) anchored to the
-- nameplate the game gives for the unit (C_NamePlate.GetNamePlateForUnit). Nothing of Blizzard's
-- nameplate is changed, hooked or read beyond its position. A forbidden nameplate (the game locks some,
-- e.g. in dungeons) is left alone. Needs the player's friendly nameplates on (the game's setting; we
-- never change it).
--
-- A guildie: the game's own UnitIsInMyGuild, or the name on my roster. Forever gives the surname
-- where the realm usually goes, so UnitName's two parts make the "First Surname" key.
-- Dev: Plates.preview (/ynm dev platepreview) marks every player's nameplate, coloured by their race,
-- to see the look in a busy town.
local ADDON, ns = ...
local UI = ns.UI

local Plates = {}
ns.Plates = Plates

-- Each clan's bracket colour; anyone else (race not known, other factions) gold.
Plates.COLOURS = {
    Orc = { 0.90, 0.22, 0.15 },
    Troll = { 0.10, 0.80, 0.65 },
    Tauren = { 0.90, 0.58, 0.20 },
    Scourge = { 0.62, 0.38, 0.95 },
    Skyborne = { 0.35, 0.72, 1.00 },
}
Plates.GOLD = { 1, 0.82, 0 }

local ARM, THICK = 10, 2          -- bracket arm length and thickness
local OWL = 18
local markers, spare = {}, {}     -- unit token -> marker frame; unused frames to reuse

function Plates.On() return ns.settings and ns.settings.guildPlates ~= false end

-- One corner: a horizontal and a vertical bar meeting at (point).
local function Corner(f, point)
    local h = f:CreateTexture(nil, "OVERLAY")
    h:SetSize(ARM, THICK)
    h:SetPoint(point, f, point, 0, 0)
    local v = f:CreateTexture(nil, "OVERLAY")
    v:SetSize(THICK, ARM)
    v:SetPoint(point, f, point, 0, 0)
    f.bars[#f.bars + 1] = h
    f.bars[#f.bars + 1] = v
end

local function NewMarker()
    local f = CreateFrame("Frame", nil, UIParent)
    f:SetFrameStrata("BACKGROUND")
    f.bars = {}
    Corner(f, "TOPLEFT"); Corner(f, "TOPRIGHT"); Corner(f, "BOTTOMLEFT"); Corner(f, "BOTTOMRIGHT")
    f.owl = f:CreateTexture(nil, "OVERLAY")
    f.owl:SetSize(OWL, OWL)
    f.owl:SetPoint("BOTTOM", f, "TOP", 0, 1)
    f.owl:SetTexture(UI.MINI)
    return f
end

-- Is this unit a guildie? Returns their roster key (or true when only the game's check says so), and
-- their race file name if known.
local function Guildie(unit)
    local isPlayer = ns.Public(UnitIsPlayer and UnitIsPlayer(unit), "boolean")
    if not isPlayer then return nil end
    local name, surname = UnitName(unit)
    name, surname = ns.Public(name, "string"), ns.Public(surname, "string")
    local key = name and ((surname and surname ~= "") and (name .. " " .. surname) or name) or nil
    local inGuild = ns.Public(UnitIsInMyGuild and UnitIsInMyGuild(unit), "boolean")
    local member = key and ns.Guild.IsMember(key)
    if not (member or inGuild or Plates.preview) then return nil end
    local race = member and ns.Clans.Race(key) or nil
    if not race and UnitRace then
        local _, file = UnitRace(unit)
        race = ns.Clans.CleanRace(ns.Public(file, "string"))
    end
    return member and key or true, race
end

local function Show(unit)
    local plate = C_NamePlate and C_NamePlate.GetNamePlateForUnit and C_NamePlate.GetNamePlateForUnit(unit)
    if not plate or (plate.IsForbidden and plate:IsForbidden()) then return end
    local who, race = Guildie(unit)
    if not who then return end
    local f = markers[unit] or table.remove(spare) or NewMarker()
    markers[unit] = f
    local c = (race and Plates.COLOURS[race]) or Plates.GOLD
    f.colour = c
    for _, b in ipairs(f.bars) do b:SetColorTexture(c[1], c[2], c[3], 0.95) end
    f:ClearAllPoints()
    f:SetPoint("TOPLEFT", plate, "TOPLEFT", -2, 2)
    f:SetPoint("BOTTOMRIGHT", plate, "BOTTOMRIGHT", 2, -2)
    f:Show()
end

local function Hide(unit)
    local f = markers[unit]
    if not f then return end
    markers[unit] = nil
    f:Hide()
    f:ClearAllPoints()
    spare[#spare + 1] = f
end

-- Every nameplate showing now, again (after the switch, a roster read or a clan change).
function Plates.Refresh()
    for unit in pairs(markers) do Hide(unit) end
    if not Plates.On() or not (C_NamePlate and C_NamePlate.GetNamePlates) then return end
    local ok, list = pcall(C_NamePlate.GetNamePlates)
    if not ok or type(list) ~= "table" then return end
    for _, plate in ipairs(list) do
        local unit = ns.Public(plate.namePlateUnitToken, "string")
        if unit then ns.Safe(Show, unit) end
    end
end

function Plates.Count() local n = 0 for _ in pairs(markers) do n = n + 1 end return n end
function Plates.MarkerFor(unit) return markers[unit] end

ns.OnEvent("NAME_PLATE_UNIT_ADDED", function(unit) if Plates.On() then ns.Safe(Show, unit) end end)
ns.OnEvent("NAME_PLATE_UNIT_REMOVED", function(unit) ns.Safe(Hide, unit) end)
ns.Listen("ROSTER", function() ns.Safe(Plates.Refresh) end)
ns.Listen("CLANS", function() ns.Safe(Plates.Refresh) end)
ns.Listen("SETTINGS", function() ns.Safe(Plates.Refresh) end)

-- Dev only: the CurseForge build leaves this out (BigWigs packager's do-not-package markers).
--@do-not-package@
-- /ynm dev platepreview on|off: mark every player's nameplate (coloured by their race), to see the
-- look in a busy town. On this screen only, until /reload or off.
ns.devCommands.platepreview = function(arg)
    Plates.preview = (arg == "on") or nil
    Plates.Refresh()
    ns.Print(Plates.preview and "(dev) Nameplate preview on: every player's nameplate is marked, coloured by race."
        or "(dev) Nameplate preview off: guildies only.")
end
--@end-do-not-package@
