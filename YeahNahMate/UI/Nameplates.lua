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
-- Clan roll (ClanRoll.lua): while a roll is open, each roller's number over their nameplate (the
-- highest gold); when it ends, the winner gets a gold die with a small crown and their roll, pulsing,
-- for 10 s. Its own Settings switch ("Show rolls above heads"), separate from the brackets. Found by
-- name among the nameplates on screen: the game refuses GetNamePlateForUnit("party1").
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
-- Round the bar's drawn background (healthBar.bgTexture: the whole bar whatever the health, so it's the
-- bar's real size on any nameplate size or scale). Anchored, never measured: Forever refuses to measure
-- nameplate parts ("Can't measure restricted regions").
Plates.FIT = { x = 1, y = 2, top = 8, dy = 4 }            -- the game's own nameplates (picked in game)
Plates.FIT_PLATER = { x = 11, y = 2, top = 17, dy = -4 }  -- Plater's (its own look, so its own numbers)
-- Only when a plate has no bgTexture: round the health bar frame, which is wider than what's drawn
-- (picked by eye in game on one nameplate size; on bigger plates these sat inside the bar).
Plates.FIT_FRAME = { x = -19, y = 3, top = 14, dy = -5 }
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
    local key = ns.UnitKey(unit)                  -- the same "First Surname" key as the roll numbers use
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
    -- Plater (a nameplate addon) draws its own plate (plate.unitFrame, lowercase) over the game's: round
    -- its health bar, which is the size it's drawn.
    local pl = Usable(plate.unitFrame) and plate.unitFrame ~= uf and plate.unitFrame.healthBar or nil
    if Usable(pl) and pl.IsShown and pl:IsShown() then
        local fit = Plates.FIT_PLATER
        local ok = pcall(function()
            f:SetPoint("TOPLEFT", pl, "TOPLEFT", -fit.x, fit.top + fit.dy)
            f:SetPoint("BOTTOMRIGHT", pl, "BOTTOMRIGHT", fit.x, -fit.y + fit.dy)
        end)
        if ok then f.round = "plater" return end
        f:ClearAllPoints()
    end
    if Usable(bar) and bar.IsShown and bar:IsShown() then
        local bg = Usable(bar.bgTexture) and bar.bgTexture or nil
        local ok = bg and pcall(function()
            f:SetPoint("TOPLEFT", bg, "TOPLEFT", -fit.x, fit.top + fit.dy)
            f:SetPoint("BOTTOMRIGHT", bg, "BOTTOMRIGHT", fit.x, -fit.y + fit.dy)
        end)
        f.round = ok and "bg" or "bar"
        if not ok then
            local ff = Plates.FIT_FRAME
            f:ClearAllPoints()
            f:SetPoint("TOPLEFT", bar, "TOPLEFT", -ff.x, ff.top + ff.dy)
            f:SetPoint("BOTTOMRIGHT", bar, "BOTTOMRIGHT", ff.x, -ff.y + ff.dy)
        end
    else
        f.round = "plate"
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
-- How many brackets are round each kind of plate now: { plater = n, bg = n, bar = n, plate = n }.
function Plates.Rounds()
    local t = {}
    for _, f in pairs(markers) do if f.round then t[f.round] = (t[f.round] or 0) + 1 end end
    return t
end
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

-- /ynm dev plateprobe: the parts of the first bracketed nameplate (its UnitFrame and health bar): name,
-- kind, shown, and what each is anchored to. No sizes or positions: Forever refuses to measure
-- nameplates ("Can't measure restricted regions"), which is why the brackets can't fit by measuring.
ns.devCommands.plateprobe = function()
    local unit, plate
    for u in pairs(markers) do unit = u; plate = C_NamePlate.GetNamePlateForUnit(u); break end
    if not plate then ns.Print("(dev) Plate probe: no bracketed nameplate on screen (friendly nameplates on? Shift+V).") return end
    local function Desc(r)
        local ok, kind = pcall(r.GetObjectType, r)
        local okS, shown = pcall(r.IsShown, r)
        local okP, pt, rel, relPt, x, y = pcall(r.GetPoint, r, 1)
        local relName = okP and rel and (pcall(rel.GetDebugName, rel) and rel:GetDebugName() or "?") or "-"
        local anchor = okP and pt and string.format("%s->%s %s %s,%s", pt, tostring(relName):match("[^%.]*$") or "?", tostring(relPt),
            type(x) == "number" and string.format("%.0f", x) or "?", type(y) == "number" and string.format("%.0f", y) or "?")
            or (okP and "no anchor" or "anchor refused")
        local okN, np = pcall(r.GetNumPoints, r)
        return string.format("%s %s %s (%s pts)", ok and kind or "?", okS and (shown and "shown" or "hidden") or "?", anchor, okN and tostring(np) or "?")
    end
    local function List(label, t)
        if type(t) ~= "table" then return end
        ns.Print("(dev) " .. label .. ":")
        local keys = {}
        for k, v in pairs(t) do
            if type(k) == "string" and type(v) == "table" and v.GetObjectType then keys[#keys + 1] = k end
        end
        table.sort(keys)
        for _, k in ipairs(keys) do
            local v = t[k]
            local fine, line = pcall(Desc, v)
            ns.Print("  " .. k .. ": " .. (fine and line or ("error " .. tostring(line))))
        end
    end
    ns.Print("(dev) Plate probe " .. unit .. " " .. tostring(ns.UnitKey(unit)))
    List("UnitFrame", plate.UnitFrame)
    List("healthBar", type(plate.UnitFrame) == "table" and plate.UnitFrame.healthBar or nil)
end

-- /ynm dev platefit [game|plater] x y top [dy]: how far the brackets sit outside the bar (each side,
-- below), room above it for the name, and moved up. "game" (the default) = the game's own nameplates
-- (round the bar's drawn background), "plater" = Plater's. Defaults: game 1 2 8 4, Plater 11 2 17 -4. The dev console's
-- Plates page steps these with < > and keeps them.
ns.devCommands.platefit = function(arg)
    local which, rest = arg:match("^(%a+)%s*(.*)$")
    if which ~= "plater" and which ~= "game" then which, rest = "game", arg end
    local t = which == "plater" and Plates.FIT_PLATER or Plates.FIT
    local x, y, top, dy = (rest or ""):match("^(%-?%d+)%s+(%-?%d+)%s+(%-?%d+)%s*(%-?%d*)$")
    if x then t.x, t.y, t.top, t.dy = tonumber(x), tonumber(y), tonumber(top), tonumber(dy) or 0 end
    Plates.Refresh()
    if Plates.quietFit then return end
    ns.Print(string.format("(dev) %s nameplates: brackets %d out each side, %d below, %d above the bar for the name, moved up %d.",
        which == "plater" and "Plater" or "Game", t.x, t.y, t.top, t.dy))
end
--@end-do-not-package@

---------------------------------------------------------------------------------------------------
-- Clan roll numbers over heads

Plates.WINNER_SECS = 10
local DICE = "Interface\\Buttons\\UI-GroupLoot-Dice-Up"
local WIN_DIE = "Interface\\AddOns\\YeahNahMate\\Media\\rolldie"
local rollsShown = {}             -- roster key -> { n = roll, top = true/nil }
local winner = nil                -- { key, n, till, token }
local rollMarks, rollSpare = {}, {}   -- nameplate token -> frame

function Plates.RollsOn() return ns.settings and ns.settings.rollPlates ~= false end

-- A nameplate's "First Surname", or nil (my own plate, or not a readable player).
local function PlateKey(unit)
    if not ns.Public(UnitIsPlayer and UnitIsPlayer(unit), "boolean") then return nil end
    if UnitIsUnit and ns.Public(UnitIsUnit(unit, "player"), "boolean") then return nil end
    return ns.UnitKey(unit)
end

local function NewRollMark()
    local f = CreateFrame("Frame", nil, UIParent)
    f:SetSize(64, 28)
    f.die = f:CreateTexture(nil, "OVERLAY")
    f.die:SetPoint("LEFT")
    f.num = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    f.num:SetPoint("LEFT", f.die, "RIGHT", 2, 0)
    return f
end

-- The winner's die pulses: the only mark that runs every frame, and only for its 10 s.
local function Pulse(self) self:SetAlpha(0.65 + 0.35 * math.abs(math.sin(GetTime() * 3))) end

local function HideRoll(unit)
    local f = rollMarks[unit]
    if not f then return end
    rollMarks[unit] = nil
    f:SetScript("OnUpdate", nil)
    f:Hide()
    f:ClearAllPoints()
    rollSpare[#rollSpare + 1] = f
end

local function ShowRoll(unit)
    local key = Plates.RollsOn() and PlateKey(unit)
    local won = key and winner and winner.key == key and GetTime() < winner.till
    local e = key and rollsShown[key]
    if not (won or e) then HideRoll(unit) return end
    local plate = C_NamePlate and C_NamePlate.GetNamePlateForUnit and C_NamePlate.GetNamePlateForUnit(unit)
    if not plate or (plate.IsForbidden and plate:IsForbidden()) then HideRoll(unit) return end
    local f = rollMarks[unit] or table.remove(rollSpare) or NewRollMark()
    rollMarks[unit] = f
    if won then
        f.die:SetTexture(WIN_DIE)
        f.die:SetSize(28, 28)
        f.num:SetText(ns.GOLD .. winner.n .. "|r")
        f.pulse = true
        f:SetScript("OnUpdate", Pulse)
    else
        f.die:SetTexture(DICE)
        f.die:SetSize(20, 20)
        f.num:SetText((e.top and ns.GOLD or "|cffffffff") .. e.n .. "|r")
        f.pulse = nil
        f:SetScript("OnUpdate", nil)
        f:SetAlpha(1)
    end
    f.key = key
    f.winning = won or nil
    f:ClearAllPoints()
    f:SetPoint("BOTTOM", plate, "TOP", 0, 10)
    f:Show()
end

function Plates.RefreshRolls()
    for unit in pairs(rollMarks) do if not live[unit] then HideRoll(unit) end end
    for unit in pairs(live) do ns.Safe(ShowRoll, unit) end
end

-- The rolls to show: key -> { n, top }. Empty (or nil) takes them all down.
function Plates.SetRolls(map)
    rollsShown = map or {}
    Plates.RefreshRolls()
end

-- The winner's crowned die and roll, for 10 s.
function Plates.ShowWinner(key, n)
    if not key then return end
    local token = {}
    winner = { key = key, n = n or 0, till = GetTime() + Plates.WINNER_SECS, token = token }
    Plates.RefreshRolls()
    C_Timer.After(Plates.WINNER_SECS + 0.05, function()
        if winner and winner.token == token then winner = nil; ns.Safe(Plates.RefreshRolls) end
    end)
end
function Plates.RollMarkFor(unit) return rollMarks[unit] end

-- Everything down at once: the numbers and the winner's die.
function Plates.ClearRolls()
    rollsShown, winner = {}, nil
    Plates.RefreshRolls()
end

ns.OnEvent("NAME_PLATE_UNIT_ADDED", function(unit) if type(unit) == "string" then ShowRoll(unit) end end)
ns.OnEvent("NAME_PLATE_UNIT_REMOVED", function(unit) if type(unit) == "string" then HideRoll(unit) end end)
ns.Listen("SETTINGS", function() ns.Safe(Plates.RefreshRolls) end)
