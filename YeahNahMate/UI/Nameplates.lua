-- Guildies' nameplates: corner brackets round a guildie's nameplate (its name and health bar), in
-- their clan's colour, so guildies stand out in a crowd; the guild's top two ranks (guild master and
-- the rank under it) get a crown on each side. Settings switch (on by default).
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
-- How far the brackets sit outside the health bar (x each side, y below), how much room above it for
-- the name, and how far the whole thing is moved up (dy, negative = down). /ynm dev platefit tries a look.
Plates.FIT = { x = -19, y = 3, top = 14, dy = -5 }   -- picked by eye in game
local markers, spare = {}, {}     -- unit token -> marker frame; unused frames to reuse
local live = {}                   -- unit tokens with a nameplate showing now (from the game's events)
local CROWN = "Interface\\GroupFrame\\UI-Group-LeaderIcon"
Plates.CROWN_RANKS = 1            -- ranks 0 .. this get the crown

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
    f.crown = f:CreateTexture(nil, "OVERLAY")
    f.crown:SetSize(14, 14)
    f.crown:SetPoint("RIGHT", f, "LEFT", -2, 0)
    f.crown:SetTexture(CROWN)
    f.crown:Hide()
    f.crown2 = f:CreateTexture(nil, "OVERLAY")
    f.crown2:SetSize(14, 14)
    f.crown2:SetPoint("LEFT", f, "RIGHT", 2, 0)
    f.crown2:SetTexture(CROWN)
    f.crown2:Hide()
    return f
end

-- Is this unit a guildie? Returns their roster key (or true when only the game's check says so),
-- their race file name if known, and their guild rank index if known.
local function Guildie(unit)
    local isPlayer = ns.Public(UnitIsPlayer and UnitIsPlayer(unit), "boolean")
    if not isPlayer then return nil end
    -- My own plate (the personal resource display) never gets brackets.
    if UnitIsUnit and ns.Public(UnitIsUnit(unit, "player"), "boolean") then return nil end
    local name, surname = UnitName(unit)
    name, surname = ns.Public(name, "string"), ns.Public(surname, "string")
    local key = name and ((surname and surname ~= "") and (name .. " " .. surname) or name) or nil
    local inGuild = ns.Public(UnitIsInMyGuild and UnitIsInMyGuild(unit), "boolean")
    -- The game's own answer wins when it's readable: someone else with a guildie's name isn't marked.
    -- The roster name is only used when the game won't say (nil or secret).
    if inGuild == false and not Plates.preview then return nil end
    local member = key and ns.Guild.IsMember(key)
    if not (member or inGuild or Plates.preview) then return nil end
    local race = member and ns.Clans.Race(key) or nil
    if not race and UnitRace then
        local _, file = UnitRace(unit)
        race = ns.Clans.CleanRace(ns.Public(file, "string"))
    end
    local rank = member and ns.Guild.Get(key) and ns.Guild.Get(key).rankIndex or nil
    if rank == nil and GetGuildInfo then
        local _, _, index = GetGuildInfo(unit)
        rank = ns.Public(index, "number")
    end
    return member and key or true, race, rank
end

local function Hide(unit)
    local f = markers[unit]
    if not f then return end
    markers[unit] = nil
    f:Hide()
    f:ClearAllPoints()
    spare[#spare + 1] = f
end

-- Round the visible part: the health bar with room for the name above it. The nameplate's own frame
-- is a bigger click box, so it's only the fallback (pulled in a little).
local function Usable(frame) return frame ~= nil and type(frame) == "table" and not (frame.IsForbidden and frame:IsForbidden()) end
local function Place(f, plate)
    local fit = Plates.FIT
    local uf = plate.UnitFrame
    local bar = Usable(uf) and uf.healthBar or nil
    f:ClearAllPoints()
    if Usable(bar) and bar.IsShown and bar:IsShown() then
        f:SetPoint("TOPLEFT", bar, "TOPLEFT", -fit.x, fit.top + fit.dy)
        f:SetPoint("BOTTOMRIGHT", bar, "BOTTOMRIGHT", fit.x, -fit.y + fit.dy)
    else
        f:SetPoint("TOPLEFT", plate, "TOPLEFT", 12, -6 + fit.dy)
        f:SetPoint("BOTTOMRIGHT", plate, "BOTTOMRIGHT", -12, 6 + fit.dy)
    end
end

local function Show(unit)
    local plate = C_NamePlate and C_NamePlate.GetNamePlateForUnit and C_NamePlate.GetNamePlateForUnit(unit)
    if not plate or (plate.IsForbidden and plate:IsForbidden()) then Hide(unit) return end
    local who, race, rank = Guildie(unit)
    if not who then Hide(unit) return end
    local f = markers[unit] or table.remove(spare) or NewMarker()
    markers[unit] = f
    local c = (race and Plates.COLOURS[race]) or Plates.GOLD
    f.colour = c
    for _, b in ipairs(f.bars) do b:SetColorTexture(c[1], c[2], c[3], 0.95) end
    local crown = type(rank) == "number" and rank <= Plates.CROWN_RANKS
    f.crown:SetShown(crown)
    f.crown2:SetShown(crown)
    Place(f, plate)
    f:Show()
end

-- Every nameplate showing now, again (after the switch, a roster read or a clan change). Markers are
-- updated where they are, never all taken down first, so a busy guild's frequent roster reads don't
-- make them blink or vanish.
function Plates.Refresh()
    if not Plates.On() then
        for unit in pairs(markers) do Hide(unit) end
        return
    end
    for unit in pairs(live) do ns.Safe(Show, unit) end
end

function Plates.Count() local n = 0 for _ in pairs(markers) do n = n + 1 end return n end
function Plates.MarkerFor(unit) return markers[unit] end

ns.OnEvent("NAME_PLATE_UNIT_ADDED", function(unit)
    if type(unit) ~= "string" then return end
    live[unit] = true
    if Plates.On() then ns.Safe(Show, unit) end
end)
ns.OnEvent("NAME_PLATE_UNIT_REMOVED", function(unit)
    if type(unit) ~= "string" then return end
    live[unit] = nil
    ns.Safe(Hide, unit)
end)
-- Nameplates already showing when we load (a /reload in town): nameplate1 .. nameplate40.
ns.Listen("LOGIN", function()
    if not (C_NamePlate and C_NamePlate.GetNamePlateForUnit) then return end
    for i = 1, 40 do
        local unit = "nameplate" .. i
        if C_NamePlate.GetNamePlateForUnit(unit) then live[unit] = true end
    end
    ns.Safe(Plates.Refresh)
end)
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

-- /ynm dev platefit x y top [dy]: how far the brackets sit outside the health bar, and moved up
-- (default -19 3 14 -5).
ns.devCommands.platefit = function(arg)
    local x, y, top, dy = arg:match("^(%-?%d+)%s+(%-?%d+)%s+(%-?%d+)%s*(%-?%d*)$")
    if x then Plates.FIT = { x = tonumber(x), y = tonumber(y), top = tonumber(top), dy = tonumber(dy) or 0 } end
    Plates.Refresh()
    ns.Print(string.format("(dev) Nameplate brackets: %d out each side, %d below, %d above the bar for the name, moved up %d.",
        Plates.FIT.x, Plates.FIT.y, Plates.FIT.top, Plates.FIT.dy))
end
--@end-do-not-package@
