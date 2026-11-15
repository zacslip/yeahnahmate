-- Fake WoW API for testing Yeah Nah Mate outside the game (Lua 5.1, run through tests/run.py).
-- Things that matter:
--  * Frames behave like the real ones: an unknown method name (Capitalised) is a no-op, but an
--    unknown field (lowercase, e.g. frame.sel) is nil, as in the game.
--  * A game clock: Tick(seconds) advances GetTime/GetServerTime and runs OnUpdate scripts and
--    C_Timer callbacks that are due.
--  * Addon messages: C_ChatInfo.SendAddonMessage puts the message in SENT; Deliver() hands queued
--    GUILD messages to every frame listening for CHAT_MSG_ADDON (the sender too, as the game does)
--    and WHISPER messages to the target if it is "us". INJECT(prefix, text, channel, sender) fakes a
--    message from someone else.
--  * Taint tripwires: UISpecialFrames must stay empty and the panel functions are counted
--    (PanelManagerCalls), so tests can assert we never touch them.

local created = {}
CREATED = created
local listeners = {}          -- event -> { frame, ... }
local onUpdate = {}           -- frames with an OnUpdate script

NOW = 1000                    -- GetTime()
SERVER_EPOCH = 1762700000     -- GetServerTime() at NOW = 1000

local methods = {}
methods.__index = function(t, k)
    local m = methods[k]
    if m then return m end
    if type(k) == "string" and k:match("^%u") then return function() end end
    return nil
end

local function Obj(kind, name, parent, template)
    local o = { _kind = kind, _name = name, _parent = parent, _template = template,
                _shown = true, _scripts = {}, _enabled = true, _events = {}, _text = nil }
    created[#created + 1] = o
    if name then _G[name] = o end
    return setmetatable(o, methods)
end

function methods.SetScript(self, n, f)
    self._scripts[n] = f
    if n == "OnUpdate" then onUpdate[self] = f and true or nil end
end
function methods.GetScript(self, n) return self._scripts[n] end
function methods.HookScript(self, n, f)
    local old = self._scripts[n]
    self._scripts[n] = function(...) if old then old(...) end f(...) end
end
function methods.RegisterEvent(self, e)
    listeners[e] = listeners[e] or {}
    if not self._events[e] then table.insert(listeners[e], self) end
    self._events[e] = true
end
function methods.UnregisterEvent(self, e)
    self._events[e] = nil
    local l = listeners[e] or {}
    for i = #l, 1, -1 do if l[i] == self then table.remove(l, i) end end
end
function methods.UnregisterAllEvents(self) for e in pairs(self._events) do methods.UnregisterEvent(self, e) end end
function methods.IsEventRegistered(self, e) return self._events[e] or false end
function methods.Show(self)
    local was = self._shown; self._shown = true
    if not was and self._scripts.OnShow then self._scripts.OnShow(self) end
end
function methods.Hide(self)
    local was = self._shown; self._shown = false
    if was and self._scripts.OnHide then self._scripts.OnHide(self) end
end
function methods.SetShown(self, v) if v then self:Show() else self:Hide() end end
function methods.IsShown(self) return self._shown end
function methods.IsVisible(self)
    local o = self
    while o do if not o._shown then return false end o = o._parent end
    return true
end
function methods.SetText(self, t) self._text = t end
function methods.GetText(self) return self._text end
function methods.Insert(self, t) self._text = (self._text or "") .. t end   -- at the end (no cursor here)
function methods.SetFormattedText(self, f, ...) self._text = string.format(f, ...) end
function methods.SetChecked(self, v) self._checked = v and true or false end
function methods.GetChecked(self) return self._checked end
function methods.SetEnabled(self, v) self._enabled = v and true or false end
function methods.Enable(self) self._enabled = true end
function methods.Disable(self) self._enabled = false end
function methods.IsEnabled(self) return self._enabled end
function methods.GetName(self) return self._name end
function methods.GetParent(self) return self._parent end
function methods.GetWidth() return 140 end
-- Where a frame was last put and how big (tests read _pt and _w; GetPoint/GetWidth stay fixed).
function methods.SetPoint(self, ...) self._pt = { ... } end
function methods.ClearAllPoints(self) self._pt = nil end
function methods.SetSize(self, w, h) self._w, self._h = w, h end
function methods.SetWidth(self, w) self._w = w end
function methods.GetHeight() return 140 end
function methods.GetCenter() return 500, 400 end
function methods.GetEffectiveScale() return 1 end
function methods.SetPropagateKeyboardInput(self, v)
    assert(not FAKE.combat, "SetPropagateKeyboardInput is blocked in combat")
    self._propagate = v
end
function methods.GetFrameLevel(self) return self._level or 1 end
function methods.SetFrameStrata(self, s) self._strata = s end
function methods.GetFrameStrata(self) return self._strata or "MEDIUM" end
function methods.SetFrameLevel(self, n) self._level = n end
function methods.GetPoint() return "CENTER", nil, "CENTER", 10, 20 end
function methods.HasFocus() return false end
function methods.CreateTexture(self) return Obj("Texture", nil, self) end
function methods.CreateFontString(self) return Obj("FontString", nil, self) end
function methods.CreateAnimationGroup(self) return Obj("AnimationGroup", nil, self) end
function methods.Click(self, button)
    if self._enabled and self._scripts.OnClick then self._scripts.OnClick(self, button or "LeftButton", true) end
end

function CreateFrame(kind, name, parent, template)
    local f = Obj(kind, name, parent, template)
    -- Like the game: these templates come with an X button that closes through HideUIPanel.
    if template and template:find("BasicFrameTemplate", 1, true) then
        f.CloseButton = Obj("Button", nil, f, "UIPanelCloseButton")
        f.CloseButton._scripts.OnClick = function(self) HideUIPanel(self:GetParent()) end
    end
    return f
end

-- Fire an event at every frame registered for it.
function FireEvent(event, ...)
    local l = listeners[event]
    if not l then return end
    local copy = {}
    for i, f in ipairs(l) do copy[i] = f end
    for _, f in ipairs(copy) do
        if f._events[event] and f._scripts.OnEvent then f._scripts.OnEvent(f, event, ...) end
    end
end

-- Timers --------------------------------------------------------------------------------------
local timers = {}
C_Timer = {}
function C_Timer.After(sec, fn) timers[#timers + 1] = { at = NOW + sec, fn = fn } end
function C_Timer.NewTimer(sec, fn)
    local t = { at = NOW + sec, fn = fn }
    t.Cancel = function() t.cancelled = true end
    t.IsCancelled = function() return t.cancelled end
    timers[#timers + 1] = t
    return t
end
function C_Timer.NewTicker(sec, fn, n)
    local t = { every = sec, at = NOW + sec, fn = fn, left = n }
    t.Cancel = function() t.cancelled = true end
    t.IsCancelled = function() return t.cancelled end
    timers[#timers + 1] = t
    return t
end

-- Advance the clock in small steps, running OnUpdate scripts and due timers.
function Tick(seconds, step)
    step = step or 0.1
    local target = NOW + seconds
    while NOW < target - 1e-9 do
        local dt = math.min(step, target - NOW)
        NOW = NOW + dt
        local fs = {}
        for f in pairs(onUpdate) do fs[#fs + 1] = f end
        for _, f in ipairs(fs) do
            local s = f._scripts.OnUpdate
            if s and f:IsVisible() then s(f, dt) end
        end
        local due = {}
        for i = #timers, 1, -1 do
            local t = timers[i]
            if t.cancelled then table.remove(timers, i)
            elseif t.at <= NOW then
                due[#due + 1] = t
                if t.every and (not t.left or t.left > 1) then
                    t.at = t.at + t.every
                    if t.left then t.left = t.left - 1 end
                else
                    table.remove(timers, i)
                end
            end
        end
        for _, t in ipairs(due) do t.fn(t) end
        Deliver()
    end
end

function GetTime() return NOW end
function GetServerTime() return math.floor(SERVER_EPOCH + (NOW - 1000)) end
function GetFramerate() return 60 end
time = function(t) if t then return os.time(t) end return GetServerTime() end
date = function(f, t) return os.date(f, t or GetServerTime()) end   -- local time, on the game clock

-- Addon messages --------------------------------------------------------------------------------
-- Forever names (measured 2026-11-09): "First Surname"; UnitFullName("player") returns the surname
-- where the realm usually goes; the realm name has digits in it.
PLAYER_NAME, PLAYER_SURNAME, PLAYER_REALM = "Ned", "Jones", "SERVER1Realm1PvE"
PLAYER_FULL = PLAYER_NAME .. " " .. PLAYER_SURNAME
SENT = {}                     -- every message we sent: { prefix, text, channel, target }
local inbox = {}              -- queued for delivery
local prefixes = {}
Enum = Enum or {}
Enum.SendAddonMessageResult = { Success = 0, InvalidPrefix = 1, InvalidMessage = 2, AddonMessageThrottle = 3,
    InvalidChatType = 4, NotInGroup = 5, TargetRequired = 6, InvalidChannel = 7, ChannelThrottle = 8,
    GeneralError = 9, NotInGuild = 10 }
C_ChatInfo = {}
function C_ChatInfo.RegisterAddonMessagePrefix(p) prefixes[p] = true; return true end
function C_ChatInfo.IsAddonMessagePrefixRegistered(p) return prefixes[p] or false end
function C_ChatInfo.SendAddonMessage(prefix, text, channel, target)
    assert(type(text) == "string" and #text <= 255, "addon message over 255 bytes")
    SENT[#SENT + 1] = { prefix = prefix, text = text, channel = channel, target = target }
    if channel == "GUILD" then
        inbox[#inbox + 1] = { prefix, text, channel, PLAYER_FULL }
    elseif channel == "WHISPER" and target == PLAYER_FULL then
        inbox[#inbox + 1] = { prefix, text, channel, PLAYER_FULL }
    end
    return Enum.SendAddonMessageResult.Success
end
C_ChatInfo.SendAddonMessageLogged = C_ChatInfo.SendAddonMessage
function C_ChatInfo.InChatMessagingLockdown() return false end
function C_ChatInfo.SendChatMessage(text, kind, lang, target)
    WHISPERS[#WHISPERS + 1] = { text = text, kind = kind, target = target }
end
function INJECT(prefix, text, channel, sender) inbox[#inbox + 1] = { prefix, text, channel, sender } end
function Deliver()
    while #inbox > 0 do
        local m = table.remove(inbox, 1)
        if prefixes[m[1]] then FireEvent("CHAT_MSG_ADDON", m[1], m[2], m[3], m[4]) end
    end
end

-- Units, guild, misc ----------------------------------------------------------------------------
FAKE = { level = 22, class = "SHAMAN", zone = "The Barrens", guild = "The Good Sorts", combat = false }
FAKE.party = {}               -- party members' keys ("Bluey Heeler"), party1..party4
function UnitName(u)
    if u == "player" then return PLAYER_NAME, PLAYER_SURNAME end
    local i = type(u) == "string" and tonumber(u:match("^party(%d)$"))
    local k = i and FAKE.party[i]
    if k then return k:match("^(%S+)%s+(.+)$") end
end
function UnitGUID(u) if u == "player" then return "Player-6797-0000NED1" end end
function UnitFullName(u) if u == "player" then return PLAYER_NAME, PLAYER_SURNAME end end
function UnitLevel(u) if u == "player" then return FAKE.level end return 1 end
function UnitClass(u) if u == "player" then return "Shaman", FAKE.class, 7 end end
function UnitFactionGroup() return "Horde", "Horde" end
function GetRealmName() return "SERVER 1 Realm 1 PvE" end
-- Like the game: same-realm names lose the realm ("none" and "short" contexts here).
function Ambiguate(name, context)
    local n, r = name:match("^([^%-]+)%-(.+)$")
    if not n then return name end
    if context == "short" or r == PLAYER_REALM then return n end
    return name
end
function GetNormalizedRealmName() return PLAYER_REALM end
function GetZoneText() return FAKE.zone end
function GetRealZoneText() return FAKE.zone end
function IsInGuild() return FAKE.guild ~= nil end
function GetGuildInfo(u) if u == "player" and FAKE.guild then return FAKE.guild, FAKE.myRankName or "Member", FAKE.myRank or 4, nil end end
-- The guild roster, as GetGuildRosterInfo gives it: name, rank, rankIndex, level, class name,
-- zone, note, officer note, online, status, class file. Names come with or without the realm.
FAKE.roster = {
    -- (the 17th value is the GUID; the forms vary on purpose: plain, dashed, with the sub-realm)
    { "Ned Jones",        "Guild Master", 0, 22, "Shaman",  "The Barrens", "", "", true,  0, "SHAMAN", 0, 0, false, false, 3, "Player-6797-0000NED1" },
    { "Bluey Heeler",    "Officer",      1, 23, "Warrior", "The Barrens", "tank", "", true, 0, "WARRIOR", 0, 0, false, false, 3, "Player-6797-00000001" },
    { "Bingo-Heeler",    "Member",       3, 20, "Priest",  "Durotar",     "", "", true,  1, "PRIEST", 0, 0, false, false, 3, "Player-6925-00000002" },
    { "Chilli Heeler-SERVER1Realm1PvE", "Member", 3, 40, "Mage", "Orgrimmar", "", "", true, 0, "MAGE", 0, 0, false, false, 3, "Player-6797-00000003" },
    { "Bandit Heeler",   "Member",       3, 24, "Rogue",   "Ashenvale",   "", "", false, 0, "ROGUE", 0, 0, false, false, 3, "Player-6925-00000004" },
}
ROSTER_ASKS = 0
function GetNumGuildMembers()
    if not FAKE.guild then return 0, 0, 0 end
    local online = 0
    for _, r in ipairs(FAKE.roster) do if r[9] then online = online + 1 end end
    return #FAKE.roster, online, online
end
function GetGuildRosterInfo(i) local r = FAKE.roster[i]; if r then return unpack(r) end end
-- Years, months, days, hours since an offline member was on (FAKE.lastOnlineDays, default 10 days).
function GetGuildRosterLastOnline(i)
    local r = FAKE.roster[i]
    if not r or r[9] then return nil end
    return 0, 0, FAKE.lastOnlineDays or 10, 0
end
C_GuildInfo = { GuildRoster = function() ROSTER_ASKS = ROSTER_ASKS + 1 end }
function IsTrialAccount() return FAKE.trial or false end
function IsVeteranTrialAccount() return false end
INVITES, WHISPERS = {}, {}
C_PartyInfo = { InviteUnit = function(name) INVITES[#INVITES + 1] = name end }
-- Professions, the newer way Forever has them (C_TradeSkillUI). FAKE.trade is the open profession
-- window: { line, rank, max, recipes = { [id] = learned } }, or nil when none is open.
FAKE.spells = { [3755] = "Linen Bag", [3757] = "Woolen Bag", [2387] = "Linen Cloak", [3275] = "Linen Bandage",
    [3276] = "Heavy Linen Bandage", [7928] = "Silk Bandage" }
FAKE.professions = { 197, 129 }
C_TradeSkillUI = {
    IsTradeSkillReady = function() return FAKE.trade ~= nil end,
    IsDataSourceChanging = function() return false end,
    IsTradeSkillLinked = function() return FAKE.tradeLinked or false end,
    IsTradeSkillGuild = function() return false end,
    IsNPCCrafting = function() return false end,
    GetBaseProfessionInfo = function()
        local t = FAKE.trade
        if not t then return {} end
        return { professionID = t.line, professionName = "Prof " .. t.line, skillLevel = t.rank, maxSkillLevel = t.max }
    end,
    GetAllRecipeIDs = function()
        local ids = {}
        for id in pairs(FAKE.trade and FAKE.trade.recipes or {}) do ids[#ids + 1] = id end
        table.sort(ids)
        return ids
    end,
    GetRecipeInfo = function(id)
        local t = FAKE.trade
        if not t or t.recipes[id] == nil then return nil end
        return { recipeID = id, name = FAKE.spells[id] or ("Spell " .. id), learned = t.recipes[id] }
    end,
}
C_Spell = { GetSpellName = function(id) return FAKE.spells[id] end }
-- Items: bags (4238 Linen Bag, 4240 Woolen Bag) are containers, everything else cloth armour.
C_Item = {
    GetItemInfoInstant = function(id)
        if id == 4238 or id == 4240 then return id, "Container", "Bag", "INVTYPE_BAG", 133000 + id, 1, 0 end
        return id, "Armor", "Cloth", "INVTYPE_CHEST", 133000 + id, 4, 1
    end,
    GetItemIconByID = function(id) return 133000 + id end,
    GetItemQualityByID = function(id) return 2 end,
}
ITEM_QUALITY_COLORS = { [2] = { hex = "|cff1eff00" } }
function GetProfessions() return 1, 2 end
function GetProfessionInfo(i)
    local line = FAKE.professions[i]
    -- FAKE.profNames / FAKE.profRanks (by index) for the milestone tests; otherwise "Prof <line>" at 50.
    if line then return (FAKE.profNames and FAKE.profNames[i]) or ("Prof " .. line), 0, (FAKE.profRanks and FAKE.profRanks[i]) or 50, 150, 0, 0, line end
end
function IsSpellKnown(id) return FAKE.spells ~= nil and FAKE.spells[id] == true end
function GetBuildInfo() return "1.60.1", "70790", "Nov 4 2026", 16001 end
function debugstack() return "(stack)" end
function InCombatLockdown() return FAKE.combat end
MEMORY_UPDATES = 0
function UpdateAddOnMemoryUsage() MEMORY_UPDATES = MEMORY_UPDATES + 1 end
function GetAddOnMemoryUsage(name) return FAKE.memoryKB or 1234 end
function IsInInstance() if FAKE.instance then return true, "party" end return false, "none" end
function IsInGroup() return (FAKE.group or 0) > 0 end
function IsInRaid() return FAKE.raid or false end
function UnitIsGroupLeader(u) return u == "player" and (FAKE.leader or false) end
RAID_CONVERTS = 0
C_PartyInfo.ConvertToRaid = function() RAID_CONVERTS = RAID_CONVERTS + 1; FAKE.raid = true end
function GetNumGroupMembers() return FAKE.group or 0 end
function IsResting() return FAKE.resting or false end
function issecretvalue() return false end
function GetCursorPosition() return 600, 400 end
-- What's on the cursor (an item picked up from the bags): FAKE.cursor = { "item", id, link }.
function GetCursorInfo() local c = FAKE.cursor; if c then return c[1], c[2], c[3] end end
function ClearCursor() FAKE.cursor = nil end
function hooksecurefunc(a, b, c)
    local tbl, name, fn = a, b, c
    if type(a) == "string" then tbl, name, fn = _G, a, b end
    local orig = tbl[name]
    tbl[name] = function(...) local r = { orig(...) } fn(...) return unpack(r) end
end
SendChatMessage = function() end
SOUNDS = {}                   -- every PlaySound: { id, channel }
function PlaySound(id, channel) SOUNDS[#SOUNDS + 1] = { id = id, channel = channel } return true end
RAID_CLASS_COLORS = setmetatable({}, { __index = function() return { r = 1, g = 0.5, b = 0, colorStr = "ff ff8000" } end })
LOCALIZED_CLASS_NAMES_MALE = {}
WOW_PROJECT_ID, WOW_PROJECT_CAMELOT = 99, 99
C_AddOns = { GetAddOnMetadata = function(_, k) if k == "Version" then return "test" end end }
C_Map = { GetBestMapForUnit = function() return 1413 end,
          GetPlayerMapPosition = function() return { x = FAKE.x or 0.5, y = FAKE.y or 0.5, GetXY = function(s) return s.x, s.y end } end,
          GetMapInfo = function(id) return { mapID = id, name = "Map " .. id, mapType = 3, parentMapID = 1414 } end,
          GetMapChildrenInfo = function() return {} end,
          GetWorldPosFromMapPos = function(_, v) return 0, CreateVector2D(v and v.x * 1000 or 0, v and v.y * 1000 or 0) end }

-- What HereBeDragons needs at load time (map data is filled in lazily, so empty answers are fine).
Enum.UIMapType = { Cosmic = 0, World = 1, Continent = 2, Zone = 3, Dungeon = 4, Micro = 5, Orphan = 6 }
function CreateVector2D(x, y) return { x = x, y = y, GetXY = function(s) return s.x, s.y end } end
function Mixin(o, ...) for i = 1, select("#", ...) do for k, v in pairs((select(i, ...))) do o[k] = v end end return o end
function CreateFromMixins(...) return Mixin({}, ...) end
MapCanvasPinMixin = {}
MapCanvasDataProviderMixin = { GetMap = function() return WorldMapFrame end }
function CreateFramePool() return { Acquire = function() return Obj("Frame") end, Release = function() end, ReleaseAll = function() end } end
function CreateUnsecuredRegionPoolInstance() return CreateFramePool() end
function GetCVar() return "0" end
function GetPlayerFacing() return 0 end
function UnitPosition() return 0, 0, 0, 1 end
function GetMinimapShape() return "ROUND" end
LOGGED_IN = false
function IsLoggedIn() return LOGGED_IN end
C_Minimap = { GetViewRadius = function() return 200 end }
C_Map.GetMapWorldSize = function() return 1000, 1000 end
C_Map.GetAllMapIDs = nil

-- String helpers the game provides as globals.
strsub, strlen, strfind, strmatch, strlower, strupper = string.sub, string.len, string.find, string.match, string.lower, string.upper
strbyte, strchar, strrep, format, gsub, gmatch = string.byte, string.char, string.rep, string.format, string.gsub, string.gmatch
tinsert, tremove, tconcat = table.insert, table.remove, table.concat
function strsplit(sep, s, n)
    local out, i = {}, 1
    while true do
        local a, b = string.find(s, sep, i, true)
        if not a or (n and #out == n - 1) then out[#out + 1] = s:sub(i) break end
        out[#out + 1] = s:sub(i, a - 1); i = b + 1
    end
    return unpack(out)
end
function strtrim(s) return (s:gsub("^%s+", ""):gsub("%s+$", "")) end
function wipe(t) for k in pairs(t) do t[k] = nil end return t end
table.wipe = wipe              -- the game has both (ChatThrottleLib uses table.wipe)
function CopyTable(t) local c = {} for k, v in pairs(t) do c[k] = type(v) == "table" and CopyTable(v) or v end return c end
math.atan2 = math.atan2 or math.atan
debugprofilestop = function() return NOW * 1000 end
-- Errors go to ERRORS (the game shows them in a box; tests assert the list stays empty).
ERRORS = {}
geterrorhandler = function() return function(e) ERRORS[#ERRORS + 1] = tostring(e) end end
-- The game's xpcall passes extra arguments to the function; plain Lua 5.1's does not.
do
    local raw = xpcall
    xpcall = function(f, h, ...)
        local n, args = select("#", ...), { ... }
        return raw(function() return f(unpack(args, 1, n)) end, h)
    end
end
securecallfunction = function(f, ...) return f(...) end
RELOADS = 0
function ReloadUI() RELOADS = RELOADS + 1 end

UIParent = Obj("Frame", "UIParent"); Minimap = Obj("Frame", "Minimap"); GameTooltip = Obj("GameTooltip", "GameTooltip")
WorldMapFrame = Obj("Frame", "WorldMapFrame")
WorldMapFrame.pinPools = {}
function WorldMapFrame.EnumeratePinsByTemplate() return function() return nil end end
UISpecialFrames = {}
PanelManagerCalls = 0
function HideUIPanel(f) PanelManagerCalls = PanelManagerCalls + 1; f:Hide() end
function ShowUIPanel(f) PanelManagerCalls = PanelManagerCalls + 1; f:Show() end
SlashCmdList = {}
StaticPopupDialogs = {}
PRINTED = {}
print = function(...)
    local t = {}
    for i = 1, select("#", ...) do t[i] = tostring((select(i, ...))) end
    PRINTED[#PRINTED + 1] = table.concat(t, " ")
end

-- Load a .toc's files in order (skips blank lines and ## headers). Returns the namespace.
function LoadAddon(dir, name, ns)
    ns = ns or {}
    local toc = assert(io.open(dir .. "/" .. name .. ".toc", "r"), "no toc in " .. dir)
    for line in toc:lines() do
        line = line:gsub("\r", "")
        if line ~= "" and not line:match("^##") and not line:match("^#") then
            local path = dir .. "/" .. line:gsub("\\", "/")
            local chunk
            if PACKAGED then
                -- As the CurseForge build has it: the packager cuts do-not-package blocks (dev only).
                local f = assert(io.open(path, "rb"))
                local text = f:read("*a"):gsub("%-%-@do%-not%-package@.-%-%-@end%-do%-not%-package@", "")
                f:close()
                chunk = assert(loadstring(text, "@" .. path))
            else
                chunk = assert(loadfile(path))
            end
            chunk(name, ns)
        end
    end
    toc:close()
    FireEvent("ADDON_LOADED", name)
    return ns
end

-- Tiny test helpers.
FAILS = 0
function check(cond, msg)
    io.write((cond and "  PASS " or "  FAIL ") .. msg .. "\n")
    io.flush()
    if not cond then FAILS = FAILS + 1 end
    return cond
end
function find(pred) for _, o in ipairs(created) do if pred(o) then return o end end end
function findAll(pred) local r = {} for _, o in ipairs(created) do if pred(o) then r[#r + 1] = o end end return r end
