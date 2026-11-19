-- Guildies' nameplates: brackets in the clan's colour and the owl, on our own frame anchored to the
-- nameplate; not on strangers or NPCs, not on a forbidden nameplate, nothing read from a secret name;
-- the Settings switch; refresh after a roster change; the dev preview marks every player.
YeahNahMateDB = nil
FAKE.myRank = 4
local ns = LoadAddon("YeahNahMate", "YeahNahMate")
LOGGED_IN = true
FireEvent("PLAYER_LOGIN")
local Ser = LibStub("AceSerializer-3.0")
local function Msg(t) return Ser:Serialize(t) end
local P, L = ns.Plates, ns.L
Tick(15)
INJECT("YNM", Msg({ v = 1, t = "HI", ver = ns.VERSION, ra = "Troll", ro = "" }), "GUILD", "Chilli Heeler")
Tick(2)

-- The game's side: units on nameplates. Forever gives the surname where the realm usually goes.
local units = {
    nameplate1 = { name = "Chilli", surname = "Heeler", player = true, race = "Troll" },            -- guildie (roster)
    nameplate2 = { name = "Random", surname = "Stranger", player = true, race = "Orc" },            -- stranger
    nameplate3 = { name = "Grunt", player = false },                                                 -- NPC
    nameplate4 = { name = "Bingo", surname = "Heeler", player = true, race = "Orc", forbidden = true }, -- guildie, locked plate
    nameplate5 = { name = "Alt", surname = "Unlisted", player = true, race = "Tauren", guild = true }, -- the game says guild
}
local plates = {}
C_NamePlate = {
    GetNamePlateForUnit = function(u)
        if not units[u] then return nil end
        plates[u] = plates[u] or CreateFrame("Frame")
        plates[u].namePlateUnitToken = u
        if units[u].forbidden then plates[u].IsForbidden = function() return true end end
        return plates[u]
    end,
    GetNamePlates = function() local out = {} for u in pairs(plates) do out[#out + 1] = plates[u] end return out end,
}
function UnitIsPlayer(u) return units[u] and units[u].player or false end
function UnitName(u) return units[u] and units[u].name, units[u] and units[u].surname end
function UnitIsInMyGuild(u) return units[u] and units[u].guild == true or false end
function UnitRace(u) local r = units[u] and units[u].race return r, r, 1 end

for u in pairs(units) do FireEvent("NAME_PLATE_UNIT_ADDED", u) end
local chilli = P.MarkerFor("nameplate1")
check(chilli and chilli:IsShown() and chilli.colour == P.COLOURS.Troll, "a guildie on the roster: brackets in the Troll clan's colour")
check(chilli._pt and chilli._pt[2] == plates.nameplate1, "anchored to their nameplate (our own frame)")
check(P.MarkerFor("nameplate2") == nil and P.MarkerFor("nameplate3") == nil, "no marker on a stranger or an NPC")
check(P.MarkerFor("nameplate4") == nil, "a forbidden nameplate is left alone")
check(P.MarkerFor("nameplate5") and P.MarkerFor("nameplate5").colour == P.COLOURS.Tauren, "the game's own guild check counts too (race from the unit)")
check(P.Count() == 2, "two markers")

-- Gone when the nameplate goes; reused for the next one.
FireEvent("NAME_PLATE_UNIT_REMOVED", "nameplate1")
check(P.MarkerFor("nameplate1") == nil and not chilli:IsShown(), "nameplate gone: marker hidden")
FireEvent("NAME_PLATE_UNIT_ADDED", "nameplate1")
check(P.MarkerFor("nameplate1") == chilli, "the frame is reused")

-- Roster reads (often, in a big guild) keep the markers where they are, even when the game's
-- nameplate list has no unit tokens on it.
for _, pl in pairs(plates) do pl.namePlateUnitToken = nil end
FireEvent("GUILD_ROSTER_UPDATE"); Tick(2)
check(P.MarkerFor("nameplate1") == chilli and chilli:IsShown() and P.Count() == 2, "a roster read doesn't take markers away")

-- Tight round the health bar (room above for the name) when the nameplate has one.
local bar = CreateFrame("StatusBar")
plates.nameplate1.UnitFrame = CreateFrame("Frame")
plates.nameplate1.UnitFrame.healthBar = bar
P.Refresh()
check(chilli._pt and chilli._pt[2] == bar, "brackets round the health bar")
plates.nameplate1.UnitFrame = nil

-- A secret name: nothing read from it (the game's guild check still works).
local realSecret = issecretvalue
issecretvalue = function(v) return v == "Chilli" end
P.Refresh()
check(P.MarkerFor("nameplate1") == nil and P.MarkerFor("nameplate5") ~= nil, "a secret name isn't used")
issecretvalue = realSecret
P.Refresh()

-- The Settings switch.
ns.UI.Open("settings"); Tick(1)
local page
for _, o in ipairs(CREATED) do if o.plates and o.minimap then page = o end end
check(page and page.plates:GetChecked(), "Settings: the switch, on by default")
page.plates:SetChecked(false); page.plates:Click(); Tick(1)
check(ns.settings.guildPlates == false and P.Count() == 0, "off: every marker goes")
FireEvent("NAME_PLATE_UNIT_ADDED", "nameplate1")
check(P.Count() == 0, "off: new nameplates get none")
page.plates:SetChecked(true); page.plates:Click(); Tick(1)
check(P.Count() == 2, "on again: back on the guildies showing")

-- Dev preview: every player, coloured by race; strangers' unknown races gold.
SlashCmdList.YEAHNAHMATE("dev platepreview on")
check(P.MarkerFor("nameplate2") and P.MarkerFor("nameplate2").colour == P.COLOURS.Orc and P.MarkerFor("nameplate3") == nil,
    "preview: a stranger marked in their race's colour, NPCs still not")
SlashCmdList.YEAHNAHMATE("dev platepreview off")
check(P.MarkerFor("nameplate2") == nil, "preview off")

check(#ns.db.errors == 0, "no errors " .. tostring(ns.db.errors[1] and ns.db.errors[1].msg))
