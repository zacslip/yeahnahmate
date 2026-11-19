-- Nearby guildies on the minimap: the near lane (my position every 1 s while a guildie with the addon
-- is within 400 yd, slower with 7-15 near, as usual in a crowd; on its own prefix, one in three on
-- the old one) and near dots we move every frame (gliding from where the dot is to the newest
-- position over the last gap, never past it; straight there after a teleport; a group member read
-- live from the game; none in a crowd).
YeahNahMateDB = nil
-- The game's UnitPosition gives world yards (y first). Set before loading: the map library keeps its
-- own copy. live: unit -> { map x, map y }, where the game says a group member is.
local live = {}
local HBD
UnitPosition = function(unit)
    if not HBD then return nil end      -- while loading
    local mx, my
    if unit == "player" then mx, my = FAKE.x, FAKE.y
    elseif live[unit] then mx, my = live[unit][1], live[unit][2]
    else return nil end
    local wx, wy, inst = HBD:GetWorldCoordinatesFromZone(mx, my, 1413)
    return wy, wx, 0, inst
end
local ns = LoadAddon("YeahNahMate", "YeahNahMate")
LOGGED_IN = true
FireEvent("PLAYER_LOGIN")
local Ser = LibStub("AceSerializer-3.0")
HBD = LibStub("HereBeDragons-2.0")
local function Msg(t) return Ser:Serialize(t) end
local M = ns.Map
ns.settings.sharePosition = true
INJECT("YNM", Msg({ v = 1, t = "HI", ver = ns.VERSION }), "GUILD", "Bluey Heeler")
Tick(20)

-- Where Bluey's dot is put by the map library (when it's not near).
local Pins = LibStub("HereBeDragons-Pins-2.0")
local libX, moves = nil, 0
local realAdd = Pins.AddMinimapIconMap
Pins.AddMinimapIconMap = function(self, ref, icon, m, x, y, ...)
    if icon.name == "Bluey Heeler" then libX, moves = x, moves + 1 end
    return realAdd(self, ref, icon, m, x, y, ...)
end

-- The stub's maps are 1000 yd across; I'm at 0.5, 0.5 on map 1413.
FAKE.x, FAKE.y = 0.5, 0.5
local function World(x) return (HBD:GetWorldCoordinatesFromZone(x, 0.5, 1413)) end
local function Pos(x, prefix)
    INJECT(prefix or "YNMP", Msg({ v = 1, t = "POS", m = 1413, x = x, y = 0.5 }), "GUILD", "Bluey Heeler")
end
local function Near(a, b) return math.abs(a - b) < 1 end         -- within a yard

-- Near-lane pace.
check(M.NearInterval(1) == 1 and M.NearInterval(6) == 1, "a few near: every 1 s")
check(M.NearInterval(12) == 2, "more near: slower (12 near: every 2 s, about 6 a second from all of them)")
check(M.NearInterval(16) == M.Interval(), "a crowd: as usual")

-- Bluey walks east past me, 10 yd every second, on the new prefix.
Pos(0.55); Tick(1)
Pos(0.56); Tick(1.05)
check(M.near["Bluey Heeler"], "Bluey is near")
local wx = M.GlideSpot("Bluey Heeler")
check(wx and Near(wx, World(0.56)), "a near dot is ours: drawn at the newest position", tostring(wx))
-- The next one, a second later: the dot runs there over about a second, never past it.
Pos(0.57)
local xs = {}
for _ = 1, 12 do Tick(0.1); xs[#xs + 1] = (M.GlideSpot("Bluey Heeler")) end
local a, b = World(0.56), World(0.57)
local dir = b > a and 1 or -1
local steady, past = true, false
for i = 2, #xs do if (xs[i] - xs[i - 1]) * dir < -1e-9 then steady = false end end
for i = 1, #xs do if (xs[i] - b) * dir > 0.01 then past = true end end
check(steady and not past, "the dot runs towards the newest position, never back, never past it", table.concat(xs, ","))
check(not Near(xs[3], b) and Near(xs[12], b), "it takes about the last gap (1 s) to get there, not at once")
check(math.abs(xs[2] - xs[1]) < 2, "in small steps, every frame (no jumps)")
local shown = select(3, M.DotShown("Bluey Heeler"))
check(shown, "and it's on the minimap")

-- A teleport (300 yd at once): straight there.
Pos(0.88); Tick(0.1)
check(Near((M.GlideSpot("Bluey Heeler")) or 0, World(0.88)), "a teleport: the dot goes straight there")
-- (now 380 yd away: still near)

-- Standing still: the dot stays where it is.
Pos(0.88); Tick(3)
local still = M.GlideSpot("Bluey Heeler")
Tick(3)
check(still and M.GlideSpot("Bluey Heeler") == still, "stopped: the dot stays")

-- In my group: the game says where Bluey is, every frame, no message needed.
Pos(0.6); Tick(1.1)
FAKE.party = { "Bluey Heeler" }; FAKE.group = 1
FireEvent("GROUP_ROSTER_UPDATE")
live.party1 = { 0.61, 0.5 }
Tick(0.1)
local gx, _, isLive = M.GlideSpot("Bluey Heeler")
check(isLive and Near(gx, World(0.61)), "a group member: drawn live where the game says", tostring(gx))
live.party1 = { 0.615, 0.5 }
Tick(0.1)
check(Near((M.GlideSpot("Bluey Heeler")), World(0.615)), "and follows them frame by frame")
-- The game hides it (an instance, or a hidden value): back to gliding on messages.
live.party1 = nil
Tick(0.1)
check(select(3, M.GlideSpot("Bluey Heeler")) == false, "the game stops saying: glides on messages again")
FAKE.party = {}; FAKE.group = 0
FireEvent("GROUP_ROSTER_UPDATE")

-- The old prefix still works (a guildie on 0.20.0).
Pos(0.62, "YNM"); Tick(1.5)
check(Near((M.GlideSpot("Bluey Heeler")), World(0.62)), "a position on the old prefix moves the dot too")
-- Anything but a position on the positions prefix is dropped.
local errs = #ns.db.errors
INJECT("YNMP", Msg({ v = 1, t = "HI", ver = "9.9.9" }), "GUILD", "Bluey Heeler"); Tick(0.5)
check(ns.Comm.newest == nil and #ns.db.errors == errs, "a hello on the positions prefix is dropped")

-- A crowd (16 near): nobody glides; Bluey's dot goes back to the map library.
for i = 1, 16 do ns.Map.pos["Crowd " .. i] = { m = 1413, x = 0.5 + i * 0.001, y = 0.5, at = GetTime() } end
moves = 0
Pos(0.6); Tick(1.5)
check(next(M.near) == nil and M.GlideSpot("Bluey Heeler") == nil, "a crowd: nobody glides")
check(moves > 0 and libX == 0.6, "and Bluey's dot is placed by the map library again")
for i = 1, 16 do ns.Map.pos["Crowd " .. i] = nil end

-- Only sim fakes near: they glide, but my position isn't sent faster for them.
local realFake = ns.Sim.IsFake
ns.Sim.IsFake = function(n) return n == "Bluey Heeler" end
M.FindNear()
check(M.near["Bluey Heeler"] and M.nearReal == 0, "a fake near: glides, but doesn't start the near lane")
ns.Sim.IsFake = realFake
M.FindNear()
check(M.nearReal == 1, "a real guildie near: starts the near lane")

-- Guildies elsewhere (another map) aren't near.
INJECT("YNM", Msg({ v = 1, t = "POS", m = 1411, x = 0.5, y = 0.5 }), "GUILD", "Bluey Heeler")
Tick(1.5)
check(M.near["Bluey Heeler"] == nil, "another map: not near")

-- The dev console's fake runner: a fake guildie circling me, a position a second, glides round.
check(ns.Sim.Runner(true) == false, "the runner needs fake guildies")
ns.Sim.Start(true); Tick(20)
local okRun, who = ns.Sim.Runner(true)
Tick(3)
check(okRun and M.near[who] and M.GlideSpot(who) ~= nil, "the runner is near and their dot glides", tostring(who))
local r1 = M.GlideSpot(who); Tick(0.5)
check(M.GlideSpot(who) ~= r1, "and keeps moving")
check(M.nearReal == 0, "a fake runner doesn't make me send faster")
ns.Sim.Runner(false)
check(ns.Sim.RunnerName() == nil, "runner off")
ns.Sim.Stop()

check(#ns.db.errors == 0, "no errors " .. tostring(ns.db.errors[1] and ns.db.errors[1].msg))
