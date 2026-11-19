-- Map: guildmates as class-coloured dots on the world map and minimap (HereBeDragons-Pins).
--
-- Sending my position (POS) only happens after the player said yes (settings.sharePosition = true,
-- asked on first run, switchable in Settings). "Off" sends one "gone" message so my dot vanishes for
-- everyone, then nothing more. Never inside instances. Positions are never saved to disk.
--
-- POS = { m = uiMapID, x = 0-1, y = 0-1 }  or  { off = true }
-- Cadence: when I've moved, at most every 15 s (slower when many guildies have the addon); standing
-- still, once a minute so my dot stays; nothing when no other guildmate with the addon is online.
-- Near lane: while a guildie with the addon is within NEAR yards (about the minimap's reach), every
-- 1 s while moving (slower with 7-15 near, as usual in a crowd), so their minimap dot of me keeps up.
-- These go on their own prefix (ns.PREFIX_POS: the game allows each prefix about one message a
-- second); one every 3 s still goes on "YNM" for 0.20.0 and older, which don't hear the new prefix.
-- A dot goes after 150 s without a POS, or at once when the roster says they went offline.
-- Nearby minimap dots move every frame, drawn by us rather than the map library: from where the dot
-- is towards the newest position, over the time the last gap between positions took, so they run
-- smoothly about one position (1 s) behind and never overshoot. A guildie in my group is read from
-- the game itself (UnitPosition works for party and raid members), so their dot is live.
local ADDON, ns = ...
local L = ns.L

local HBD = LibStub("HereBeDragons-2.0")
local Pins = LibStub("HereBeDragons-Pins-2.0")

local Map = {}
ns.Map = Map

local REF = "YeahNahMate"
local EXPIRE = 150
local KEEPALIVE = 60
local NEAR, FAST = 400, 1          -- yards for the near lane and gliding; seconds between its positions
local OLD_EVERY = 3                -- the near lane still sends on "YNM" this often, for 0.20.0 and older
local SNAP = 60                    -- yards: a jump bigger than this (a teleport) goes straight there
local GLIDE_MIN, GLIDE_LONGEST = 0.3, 3   -- seconds a glide to the next position takes, at least / at most
local GLIDE_MAX, CROWD = 8, 15     -- only the closest few glide; in a crowd (a meeting) none do: dots
                                   -- that close together can't be followed one by one, and it costs
local DOT_SIZES = { 10, 14, 18 }
-- The ring round each dot (it was black, so guildies looked like the game's own group
-- markers). Settings picks one: red, blue or gold (the default).
local RING_COLOURS = { { 0.9, 0.15, 0.15 }, { 0.2, 0.5, 1 }, { 1, 0.82, 0 } }
Map.RING_COLOURS = RING_COLOURS
local DOT_TEXTURE = "Interface\\CHARACTERFRAME\\TempPortraitAlphaMask"

Map.pos = {}                    -- name -> { m, x, y, at }
local worldDots, miniDots = {}, {}

function Map.Sharing() return ns.settings.sharePosition == true end

-- Seconds between position messages while moving: 15, slower with more than 20 users online.
function Map.Interval()
    return math.min(KEEPALIVE, 15 + math.max(0, ns.Comm.OthersOnline() - 20) * 0.5)
end

-- My position on my current zone map, or nil (inside an instance, or the game won't say).
function Map.MyPosition()
    if IsInInstance() then return nil end
    if not (C_Map and C_Map.GetBestMapForUnit and C_Map.GetPlayerMapPosition) then return nil end
    local mapID = ns.Public(C_Map.GetBestMapForUnit("player"), "number")
    if not mapID then return nil end
    local p = C_Map.GetPlayerMapPosition(mapID, "player")
    if not p or not p.GetXY then return nil end
    local x, y = p:GetXY()
    x, y = ns.Public(x, "number"), ns.Public(y, "number")
    if not x or not y or (x == 0 and y == 0) then return nil end
    return mapID, x, y
end

-- Where a guildie probably is now (proximity voice: volumes must not jitter between positions).
-- From their last two positions: the way they were heading, guessed at most GUESS_MAX seconds past
-- the last one. Their last spot as it is when: only one position, they changed map, the last one is
-- older than STALE (they stopped), or the jump was too fast to be running (a teleport, a hearth).
local GUESS_MAX, STALE, MAX_SPEED = 3, 6, 40    -- seconds, seconds, yards a second
-- The heading is worked out once per position (Heading), so a guess is plain arithmetic: the map
-- library's distances make garbage, and gliding dots ask for a guess five times a second.
local function Heading(p)
    p.vx, p.vy, p.headAt = nil, nil, p.at
    if not p.pat or p.pm ~= p.m then return end
    local span = p.at - p.pat
    if span < 0.5 or span > 20 then return end
    local yards = HBD:GetZoneDistance(p.m, p.px, p.py, p.m, p.x, p.y)
    if not yards or yards / span > MAX_SPEED then return end
    p.vx, p.vy = (p.x - p.px) / span, (p.y - p.py) / span
end
Map.Heading = Heading
function Map.Estimate(name)
    local p = Map.pos[name]
    if not p then return nil end
    if p.headAt ~= p.at then Heading(p) end
    local age = GetTime() - p.at
    if not p.vx or age > STALE then return p.m, p.x, p.y end
    local t = math.min(age, GUESS_MAX)
    local x = math.max(0, math.min(1, p.x + p.vx * t))
    local y = math.max(0, math.min(1, p.y + p.vy * t))
    return p.m, x, y
end

-- Yards from me to a guildie's dot, or nil (no dot, different continent, or I'm in an instance).
-- estimate: where they probably are now (Map.Estimate) rather than their last position.
function Map.Distance(name, estimate)
    local p = Map.pos[name]
    if not p then return nil end
    local m, x, y = Map.MyPosition()
    if not m then return nil end
    local pm, px, py = p.m, p.x, p.y
    if estimate then pm, px, py = Map.Estimate(name) end
    local d = HBD:GetZoneDistance(m, x, y, pm, px, py)
    return d
end

---------------------------------------------------------------------------------------------------
-- Dots

local function DotTooltip(self)
    local m = ns.Guild.Get(self.name)
    if not m or not GameTooltip then return end
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:AddLine("|c" .. ns.ClassHex(m.class) .. m.name .. "|r")
    GameTooltip:AddLine(string.format("%s %s %s", L.COL_LEVEL, tostring(m.level), ns.ClassName(m.class)), 1, 1, 1)
    if m.zone ~= "" then GameTooltip:AddLine(m.zone, 1, 1, 1) end
    local s = ns.Status.Text(m)
    if s ~= "" then GameTooltip:AddLine(s, 0.8, 0.8, 0.8) end
    -- Yards only on the minimap (not needed on the world map).
    local d = not self.onWorld and Map.Distance(self.name)
    if d then GameTooltip:AddLine(string.format(L.YARDS, d), 0.25, 1, 0.25) end
    GameTooltip:Show()
end

local function NewDot(name)
    local f = CreateFrame("Button", nil, UIParent)
    f.name = name
    f.ring = f:CreateTexture(nil, "BORDER")
    f.ring:SetAllPoints()
    f.ring:SetTexture(DOT_TEXTURE)
    f.ring:SetVertexColor(0, 0, 0, 1)
    f.dot = f:CreateTexture(nil, "ARTWORK")
    -- 1 px of ring showing (2 px looked too thick once it was coloured).
    f.dot:SetPoint("TOPLEFT", 1, -1)
    f.dot:SetPoint("BOTTOMRIGHT", -1, 1)
    f.dot:SetTexture(DOT_TEXTURE)
    f:SetScript("OnEnter", DotTooltip)
    f:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
    -- HereBeDragons shows and hides the dot (out of range, other zone, map closed); we never do.
    -- 0.9.4: Place used to Show() it after every position, so a minimap dot HBD had hidden came back
    -- stuck at its last spot, e.g. a guildie 4000 yards away still on the minimap.
    f:Hide()
    return f
end

local function Style(f, m)
    local size = DOT_SIZES[ns.settings.dotSize] or DOT_SIZES[2]
    f:SetSize(size, size)
    local c = m.class and RAID_CLASS_COLORS and RAID_CLASS_COLORS[m.class]
    if c then f.dot:SetVertexColor(c.r, c.g, c.b, 1) else f.dot:SetVertexColor(1, 1, 1, 1) end
    local r = RING_COLOURS[ns.settings.dotRing] or RING_COLOURS[3]
    f.ring:SetVertexColor(r[1], r[2], r[3], 1)
    f.ringRGB = r
end

local function HideDots(name)
    if worldDots[name] then Pins:RemoveWorldMapIcon(REF, worldDots[name]); worldDots[name]:Hide(); worldDots[name].placed = nil end
    if miniDots[name] then
        Pins:RemoveMinimapIcon(REF, miniDots[name]); miniDots[name]:Hide()
        miniDots[name].placed, miniDots[name].gliding = nil, nil
    end
end

-- Draw (or hide) one guildie's dots from their last position.
function Map.Place(name)
    local p, m = Map.pos[name], ns.Guild.Get(name)
    if not p or not m or not m.online or name == ns.me then
        HideDots(name)
        return
    end
    local s = ns.settings
    if s.showWorld then
        local f = worldDots[name] or NewDot(name)
        f.onWorld = true
        worldDots[name] = f
        Style(f, m)
        f.placed = true
        Pins:AddWorldMapIconMap(REF, f, p.m, p.x, p.y, HBD_PINS_WORLDMAP_SHOW_CONTINENT)
    elseif worldDots[name] then
        Pins:RemoveWorldMapIcon(REF, worldDots[name]); worldDots[name]:Hide(); worldDots[name].placed = nil
    end
    if s.showMinimap then
        local f = miniDots[name] or NewDot(name)
        miniDots[name] = f
        Style(f, m)
        f.placed = true
        -- A gliding dot is ours to move (Map.Step); everyone else's goes straight to the new spot.
        if f.gliding then
            Map.GlideTo(name)
        else
            Pins:AddMinimapIconMap(REF, f, p.m, p.x, p.y, false, false)
        end
    elseif miniDots[name] then
        local f = miniDots[name]
        Pins:RemoveMinimapIcon(REF, f); f:Hide(); f.placed, f.gliding = nil, nil
    end
end

function Map.Remove(name)
    if not Map.pos[name] then return end
    Map.pos[name] = nil
    HideDots(name)
    ns.Fire("POSITIONS")
end

function Map.PlaceAll()
    for name in pairs(Map.pos) do Map.Place(name) end
    -- Dots of people with no position any more.
    for name in pairs(worldDots) do if not Map.pos[name] then HideDots(name) end end
    for name in pairs(miniDots) do if not Map.pos[name] then HideDots(name) end end
end

-- For tests: is this guildie's dot placed (world map, minimap), and is the minimap dot on screen?
function Map.DotShown(name)
    local w, mm = worldDots[name], miniDots[name]
    return (w and w.placed) == true, (mm and mm.placed) == true, mm ~= nil and mm:IsShown()
end

-- For tests: the ring colour of this guildie's world map and minimap dots.
function Map.DotRing(name)
    local w, mm = worldDots[name], miniDots[name]
    return w and w.ringRGB, mm and mm.ringRGB
end

---------------------------------------------------------------------------------------------------
-- Receiving

ns.Comm.On("POS", function(msg, from, channel, isSelf)
    -- GUILD normally; a WHISPER when a guildie answers my hello with where they are (0.8.6).
    if isSelf or (channel ~= "GUILD" and channel ~= "WHISPER") then return end
    if msg.off == true then Map.Remove(from) return end
    local m, x, y = msg.m, msg.x, msg.y
    if type(m) ~= "number" or m <= 0 or m ~= math.floor(m) or type(x) ~= "number" or type(y) ~= "number"
        or x < 0 or x > 1 or y < 0 or y > 1 then
        ns.Log("dropped: bad position from " .. from)
        return
    end
    local p = Map.pos[from]
    if not p then p = {}; Map.pos[from] = p end     -- one table per guildie, reused
    -- The one before, for guessing where they're heading (Map.Estimate).
    if p.at then p.pm, p.px, p.py, p.pat = p.m, p.x, p.y, p.at end
    p.m, p.x, p.y, p.at = m, x, y, GetTime()
    -- How long the last gap was: a gliding dot takes that long to reach this position.
    p.gap = p.pat and (p.at - p.pat) or nil
    Heading(p)
    Map.Place(from)
    ns.Fire("POSITIONS")
end)

-- Old dots go; offline or departed guildies' dots go.
local function Expire()
    local now = GetTime()
    for name, p in pairs(Map.pos) do
        local m = ns.Guild.Get(name)
        if now - p.at > EXPIRE or not m or not m.online then Map.Remove(name) end
    end
end

-- After a roster read: drop dots of guildies who went offline, and draw the ones still waiting for
-- their roster row. Dots already showing stay as they are (redrawing all of them on every roster
-- read, every few seconds in a big guild, was wasted work and garbage).
ns.Listen("ROSTER", function()
    Expire()
    local s = ns.settings
    for name in pairs(Map.pos) do
        local w, mm = worldDots[name], miniDots[name]
        if (s.showWorld and not (w and w.placed)) or (s.showMinimap and not (mm and mm.placed)) then
            Map.Place(name)
        end
    end
end)
ns.Listen("SETTINGS", Map.PlaceAll)

---------------------------------------------------------------------------------------------------
-- Nearby guildies: the near lane and gliding minimap dots

Map.near = {}                   -- name -> true: the closest GLIDE_MAX guildies with a fresh position within NEAR yards
local found = {}                -- reused: { name, yards } of everyone near

-- Once a second: who's near. My own position read once (each read makes a new table).
-- Returns how many.
function Map.FindNear()
    wipe(Map.near)
    local count = 0
    Map.nearReal = 0                -- the near ones who aren't sim fakes (only they start the near lane)
    local mm, mx, my = Map.MyPosition()
    local now = GetTime()
    if mm then
        for name, p in pairs(Map.pos) do
            -- Same zone map only: anyone else is rarely in minimap reach, and the distance is costly.
            if p.m == mm and now - p.at < EXPIRE then
                local d = HBD:GetZoneDistance(mm, mx, my, p.m, p.x, p.y)
                if d and d <= NEAR then
                    count = count + 1
                    if not (ns.Sim and ns.Sim.IsFake(name)) then Map.nearReal = Map.nearReal + 1 end
                    local e = found[count] or {}
                    e.name, e.yards = name, d
                    found[count] = e
                end
            end
        end
    end
    -- A crowd (more than CROWD): nobody glides (they're placed the usual way below).
    if count <= GLIDE_MAX then
        for i = 1, count do Map.near[found[i].name] = true end
    elseif count <= CROWD then
        -- The closest ones (a partial sort is enough for 8).
        for i = 1, GLIDE_MAX do
            local best = i
            for j = i + 1, count do if found[j].yards < found[best].yards then best = j end end
            found[i], found[best] = found[best], found[i]
            Map.near[found[i].name] = true
        end
    end
    -- Near dots become ours to move every frame; dots no longer near go back to the map library.
    local s = ns.settings
    for name in pairs(Map.near) do
        local f = miniDots[name]
        if f and f.placed and not f.gliding and s.showMinimap then
            Pins:RemoveMinimapIcon(REF, f)
            f:SetParent(Pins.Minimap or Minimap)
            f.gliding, f.wx, f.wy, f.winst = true, nil, nil, nil
            Map.GlideTo(name)
        end
    end
    for name, f in pairs(miniDots) do
        if f.gliding and not Map.near[name] then
            f.gliding = nil
            Map.Place(name)
        end
    end
    if Map.stepper then Map.stepper:SetShown(next(Map.near) ~= nil) end
    return count
end

-- Seconds between my positions while someone's near: 1 with up to 6 around, slower with 7-15 (so a
-- group of up to 15 sends about 6 a second in all), and as usual in a crowd (more than CROWD: a guild
-- meeting), so the guild's traffic stays as it was.
function Map.NearInterval(count)
    if count > CROWD then return Map.Interval() end        -- a crowd: as usual
    if count <= 6 then return FAST end
    return math.min(Map.Interval(), FAST * count / 6)
end

-- Group members: name -> "party1".."raid40", rebuilt when the group changes.
local groupUnit = {}
local function ReadGroup()
    wipe(groupUnit)
    if not (IsInGroup and IsInGroup()) then return end
    local raid = IsInRaid and IsInRaid()
    for i = 1, raid and 40 or 4 do
        local unit = (raid and "raid" or "party") .. i
        local key = ns.UnitKey(unit)
        if key and key ~= ns.me then groupUnit[key] = unit end
    end
end
ns.OnEvent("GROUP_ROSTER_UPDATE", function() ns.Safe(ReadGroup) end)
Map.groupUnit = groupUnit

-- Where the game says a group member is right now (world yards), or nil (not grouped, in an
-- instance, a hidden value).
local function LivePosition(name)
    local unit = groupUnit[name]
    if not unit or not UnitPosition then return nil end
    -- Checked here first: the map library would do sums on a hidden value.
    local a, b, _, i = UnitPosition(unit)
    if not ns.Public(a, "number") or not ns.Public(b, "number") or not ns.Public(i, "number") then return nil end
    local x, y, inst = HBD:GetUnitWorldPosition(unit)
    if not x or not y or not inst then return nil end
    return x, y, inst
end

-- A new position for a near dot: glide from where it is now to there, taking as long as the last gap
-- between their positions took, so it arrives about when the next one comes. A first position, a
-- new map or a jump of more than SNAP yards (a teleport): straight there.
function Map.GlideTo(name)
    local f, p = miniDots[name], Map.pos[name]
    if not f or not p then return end
    local tx, ty, inst = HBD:GetWorldCoordinatesFromZone(p.x, p.y, p.m)
    if not tx then return end
    local now = GetTime()
    if f.wx and f.winst == inst and math.abs(tx - f.wx) + math.abs(ty - f.wy) <= SNAP then
        f.fx, f.fy = f.wx, f.wy
        f.dur = math.max(GLIDE_MIN, math.min(GLIDE_LONGEST, p.gap or FAST))
    else
        f.fx, f.fy, f.wx, f.wy, f.dur = tx, ty, tx, ty, 0
    end
    f.tx, f.ty, f.winst, f.t0 = tx, ty, inst, now
end

local rotateCVar, minimapRadius = nil, nil
-- The minimap's view radius in yards (the game says; the map library's table on older clients).
local OUTDOOR = { [0] = 466 + 2 / 3, 400, 333 + 1 / 3, 266 + 2 / 6, 200, 133 + 1 / 3 }
local function MinimapRadius(mm)
    if C_Minimap and C_Minimap.GetViewRadius then
        local r = ns.Public(C_Minimap.GetViewRadius(), "number")
        if r and r > 0 then return r end
    end
    return (OUTDOOR[mm.GetZoom and mm:GetZoom() or 0] or 466) / 2
end

-- Put one dot on the minimap at world spot x, y (the same sums the map library does for its pins).
local function Draw(f, mm, px, py, x, y, sin, cos, square)
    local xd, yd = px - x, py - y
    if sin then xd, yd = xd * cos - yd * sin, xd * sin + yd * cos end
    local dx, dy = xd / minimapRadius, yd / minimapRadius
    local dist = (square and math.max(dx * dx, dy * dy) or (dx * dx + dy * dy)) / 0.81
    if dist > 1 then f:Hide() return end
    f:ClearAllPoints()
    f:SetPoint("CENTER", mm, "CENTER", dx * mm:GetWidth() / 2, -dy * mm:GetHeight() / 2)
    f:Show()
end

-- Every frame, near minimap dots only (up to GLIDE_MAX): live for group members, gliding otherwise.
function Map.Step()
    if not ns.settings.showMinimap then return end
    local mm = Pins.Minimap or Minimap
    if not mm or not mm:IsVisible() then return end
    local px, py, pinst = HBD:GetPlayerWorldPosition()
    if not px then return end
    minimapRadius = MinimapRadius(mm)
    local sin, cos
    if rotateCVar == nil then rotateCVar = GetCVar and GetCVar("rotateMinimap") == "1" or false end
    if rotateCVar then
        local facing = ns.Public(GetPlayerFacing and GetPlayerFacing(), "number")
        if not facing then return end
        sin, cos = math.sin(facing), math.cos(facing)
    end
    local square = GetMinimapShape and GetMinimapShape() == "SQUARE"
    local now = GetTime()
    for name in pairs(Map.near) do
        local f = miniDots[name]
        if f and f.gliding then
            local x, y, inst = LivePosition(name)
            f.live = x ~= nil
            if x then
                f.wx, f.wy, f.winst = x, y, inst
            elseif f.tx then
                local k = f.dur > 0 and math.min(1, (now - f.t0) / f.dur) or 1
                f.wx, f.wy = f.fx + (f.tx - f.fx) * k, f.fy + (f.ty - f.fy) * k
            end
            if f.wx and f.winst == pinst then Draw(f, mm, px, py, f.wx, f.wy, sin, cos, square) else f:Hide() end
        end
    end
end
ns.OnEvent("CVAR_UPDATE", function() rotateCVar = nil end)

-- For the dev console: one line on nearby dots and my near lane.
function Map.NearStatus()
    local n, live, glide = 0, 0, 0
    for name in pairs(Map.near) do
        n = n + 1
        local f = miniDots[name]
        if f and f.live then live = live + 1 elseif f and f.gliding then glide = glide + 1 end
    end
    local pace = n > 0 and Map.nearReal and Map.nearReal > 0 and Map.NearInterval(n)
    return string.format("%d near (%d gliding, %d live from my group). %s Sent this session: %d positions, %d of them on the fast prefix.",
        n, glide, live, pace and string.format("I send every %.1f s while moving.", pace)
            or "Near lane off (nobody real near, or sharing off).", Map.sentCount or 0, Map.sentFast or 0)
end

-- For tests and the dev console: where a near dot is drawn (world yards), and whether it's live.
function Map.GlideSpot(name)
    local f = miniDots[name]
    if not (f and f.gliding) then return nil end
    return f.wx, f.wy, f.live == true
end

---------------------------------------------------------------------------------------------------
-- Sending

local last = { at = -1000 }     -- what we last sent: m, x, y, at
local sentReal = false          -- a real position went out since the last "off"

local function Round(v) return math.floor(v * 10000 + 0.5) / 10000 end

-- interval, prio: proximity voice's fast lane (Voice.lua) sends every few seconds instead, as
-- NORMAL; everything else uses Map.Interval() and BULK.
function Map.Tick(interval, prio)
    if not ns.me or not IsInGuild() then return end
    local m, x, y
    if Map.Sharing() then m, x, y = Map.MyPosition() end
    if not m then
        -- Sharing off, or in an instance: one "gone" so the dot vanishes for everyone.
        if sentReal then
            sentReal = false
            ns.Log(Map.Sharing() and "In a dungeon, so your position is no longer shared."
                or "Sharing switched OFF. Your position is no longer shared.")
            last = { at = -1000 }
            ns.Comm.Send({ t = "POS", off = true }, "GUILD", nil, "BULK")
        end
        return
    end
    if ns.Comm.OthersOnline() == 0 and not (ns.Sim and ns.Sim.IsOn()) then return end
    local now = GetTime()
    -- Moved: 0.002 of the map is about 8 yd in a big zone, more than a second's run, so the near lane
    -- (every 1 s) counts a much smaller step (about 1 yd).
    local step = (interval and interval < OLD_EVERY) and 0.0003 or 0.002
    local moved = m ~= last.m or math.abs(x - last.x) + math.abs(y - last.y) > step
    local gap = now - last.at
    local iv = interval or Map.Interval()
    -- Fast lane only: one more when I stop, so guildies' guesses stop too (Map.Estimate).
    local stopped = interval and not moved and last.moving
    local slack = interval and 0.05 or 0   -- fast lane: allow for timer jitter (3 s, not 4)
    if ((moved or stopped) and gap >= iv - slack) or gap >= KEEPALIVE then
        x, y = Round(x), Round(y)
        -- The near lane goes on its own prefix, except one every OLD_EVERY seconds on "YNM" so
        -- guildies on 0.20.0 and older still get theirs (newer ones hear both).
        local fast = interval ~= nil and interval < OLD_EVERY and now - (Map.oldAt or -1000) < OLD_EVERY - slack
        if ns.Comm.Send({ t = "POS", m = m, x = x, y = y }, "GUILD", nil, prio or "BULK", fast) then
            if not fast then Map.oldAt = now else Map.sentFast = (Map.sentFast or 0) + 1 end
            last = { m = m, x = x, y = y, at = now, moving = moved }
            sentReal = true
            Map.sentCount = (Map.sentCount or 0) + 1
        end
    end
end

-- Someone just arrived: whisper them where I am so their map fills in quickly. Only to them: with
-- the whole guild on the addon, a broadcast here would be 250 broadcasts for every log-in.
ns.Listen("HI_IN", function(msg, from)
    if msg.ask ~= true or (ns.Sim and ns.Sim.IsFake(from)) then return end
    C_Timer.After(2 + math.random() * 6, function()
        if not Map.Sharing() or not sentReal then return end
        local m, x, y = Map.MyPosition()
        if not m then return end
        ns.Comm.Send({ t = "POS", m = m, x = Round(x), y = Round(y) }, "WHISPER", from, "BULK")
    end)
end)

ns.Listen("LOGIN", function()
    -- Start after our HI has gone out (Comm waits 10 s after login).
    C_Timer.After(12, function()
        C_Timer.NewTicker(5, function() ns.Safe(Map.Tick) end)
        C_Timer.NewTicker(10, function() ns.Safe(Expire) end)
        -- The near lane: a guildie close by gets my position every 3 s while I move.
        C_Timer.NewTicker(1, function()
            local ok, count = ns.Safe(Map.FindNear)
            if ok and count and count > 0 and (Map.nearReal or 0) > 0 and Map.Sharing() then
                local iv = Map.NearInterval(count)
                if iv < Map.Interval() then ns.Safe(Map.Tick, iv, "NORMAL") end
            end
        end)
        -- Near dots move every frame; the frame is only shown while someone's near (FindNear).
        ns.Safe(ReadGroup)
        Map.stepper = Map.stepper or CreateFrame("Frame")
        Map.stepper:SetScript("OnUpdate", function() ns.Safe(Map.Step) end)
        Map.stepper:SetShown(next(Map.near) ~= nil)
    end)
end)

-- Turning sharing off sends the "gone" straight away.
ns.Listen("SETTINGS", function() if ns.me then ns.Safe(Map.Tick) end end)
