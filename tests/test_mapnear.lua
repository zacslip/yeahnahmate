-- Nearby guildies on the minimap: the near lane (my position every 3 s while a guildie with the addon
-- is within 400 yd, slower with more around, as usual in a crowd) and gliding dots (a nearby guildie
-- on the move: their minimap dot moves smoothly towards where they're heading instead of jumping;
-- straight there after a teleport; still when they stop; none glide in a crowd).
YeahNahMateDB = nil
local ns = LoadAddon("YeahNahMate", "YeahNahMate")
LOGGED_IN = true
FireEvent("PLAYER_LOGIN")
local Ser = LibStub("AceSerializer-3.0")
local function Msg(t) return Ser:Serialize(t) end
local M = ns.Map
ns.settings.sharePosition = true
INJECT("YNM", Msg({ v = 1, t = "HI", ver = ns.VERSION }), "GUILD", "Bluey Heeler")
Tick(20)

-- Where Bluey's minimap dot is put (the map library's minimap call).
local Pins = LibStub("HereBeDragons-Pins-2.0")
local dotX, moves = nil, 0
local realAdd = Pins.AddMinimapIconMap
Pins.AddMinimapIconMap = function(self, ref, icon, m, x, y, ...)
    if icon.name == "Bluey Heeler" then dotX, moves = x, moves + 1 end
    return realAdd(self, ref, icon, m, x, y, ...)
end

-- The stub's maps are 1000 yd across; I'm at 0.5, 0.5 on map 1413.
FAKE.x, FAKE.y = 0.5, 0.5
local function Pos(x) INJECT("YNM", Msg({ v = 1, t = "POS", m = 1413, x = x, y = 0.5 }), "GUILD", "Bluey Heeler") end

-- Near-lane pace.
check(M.NearInterval(1) == 3 and M.NearInterval(6) == 3, "a few near: every 3 s")
check(M.NearInterval(12) == 6, "more near: slower (12 near: every 6 s)")
check(M.NearInterval(16) == M.Interval(), "a crowd: as usual")

-- Bluey walks east past me, 30 yd every 3 s (10 yd a second).
Pos(0.55); Tick(3)
Pos(0.58); Tick(0.1)
check(dotX == 0.58, "a new position: the dot is there")
Tick(1)
check(M.near["Bluey Heeler"], "Bluey is near")
local xs = {}
for _ = 1, 10 do Tick(0.2); xs[#xs + 1] = dotX end
local steady = true
for i = 2, #xs do if xs[i] < xs[i - 1] then steady = false end end
check(steady and xs[#xs] > 0.58 and xs[#xs] <= 0.58 + 0.03 * 1.01, "the dot glides on east, never back, at most 3 s ahead",
    table.concat(xs, ","))
local step = xs[2] - xs[1]
check(step > 0 and step < 0.005, "in small steps (no jump)")

-- A teleport (300 yd at once): straight there.
Pos(0.88); Tick(0.25)
check(math.abs(dotX - 0.88) < 0.0001, "a teleport: the dot goes straight there")

-- Standing still: once the guess runs out the dot stays put.
Pos(0.88); Tick(8)
local still = dotX
local before = moves
Tick(3)
check(dotX == still and moves == before, "stopped: the dot stays and isn't moved again")

-- A crowd (16 near): nobody glides.
for i = 1, 16 do ns.Map.pos["Crowd " .. i] = { m = 1413, x = 0.5 + i * 0.001, y = 0.5, at = GetTime() } end
Pos(0.6); Tick(3); Pos(0.63); Tick(1.5)
check(next(M.near) == nil, "a crowd: nobody glides")
for i = 1, 16 do ns.Map.pos["Crowd " .. i] = nil end

-- Guildies elsewhere (another map) aren't near.
INJECT("YNM", Msg({ v = 1, t = "POS", m = 1411, x = 0.5, y = 0.5 }), "GUILD", "Bluey Heeler")
Tick(1.5)
check(M.near["Bluey Heeler"] == nil, "another map: not near")

check(#ns.db.errors == 0, "no errors " .. tostring(ns.db.errors[1] and ns.db.errors[1].msg))
