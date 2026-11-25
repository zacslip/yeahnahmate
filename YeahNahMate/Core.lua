-- Yeah Nah Mate: the core. Namespace, saved data with defaults, game events, our own internal
-- events (ns.Listen / ns.Fire), the error log, the message log and the slash commands.
--
-- Rules this file keeps (CONTRIBUTING.md, Rules): nothing here touches Blizzard's tables or panels,
-- nothing runs every frame, and errors in our code are caught, saved (readable in the saved-variables
-- file after a /reload), and still shown by the game.
local ADDON, ns = ...
local L = ns.L

ns.NAME = "Yeah Nah Mate"
ns.VERSION = (C_AddOns and C_AddOns.GetAddOnMetadata and C_AddOns.GetAddOnMetadata(ADDON, "Version")) or "dev"
ns.PROTOCOL = 1        -- bump when a message format changes incompatibly
ns.PREFIX = "YNM"      -- addon message prefix
-- Positions every second (the near lane) go on their own prefix: the game allows each prefix about one
-- message a second, so on "YNM" they would hold up everything else.
ns.PREFIX_POS = "YNMP"

ns.GOLD = "|cffe6c35c"
ns.GREY = "|cff9d9d9d"
ns.GREEN = "|cff40ff40"

function ns.Print(text)
    print(ns.GOLD .. L.ADDON .. "|r " .. tostring(text))
end

---------------------------------------------------------------------------------------------------
-- Errors: caught, kept (the last 50, repeats counted), and passed on to the game's error handler.
-- Repeats are counted per addon version, so an old error's count can't look like it's still happening.

local pendingErrors = {}         -- errors before the saved data is loaded

-- The game's version and build, e.g. "1.60.1.70790".
local clientBuild
function ns.ClientBuild()
    -- This runs while handling an error, so it must never cause one (ns.Public is set further down).
    if clientBuild == nil and GetBuildInfo and ns.Public then
        local ok, version, build = pcall(GetBuildInfo)
        version, build = ok and ns.Public(version, "string"), ok and ns.Public(build, "string")
        clientBuild = (version and build) and (version .. "." .. build) or false
    end
    return clientBuild or nil
end

local function SaveError(err, stack, count)
    err = tostring(err)
    count = count or 1
    local list = ns.db and ns.db.errors or pendingErrors
    for _, e in ipairs(list) do
        if e.msg == err and e.ver == ns.VERSION then
            e.count = (e.count or 1) + count
            e.last = GetServerTime()
            e.build = ns.ClientBuild()
            return
        end
    end
    list[#list + 1] = {
        msg = err, count = count, at = GetServerTime(), last = GetServerTime(),
        ver = ns.VERSION, build = ns.ClientBuild(), stack = stack,
    }
    while #list > 50 do table.remove(list, 1) end
end

local function OnError(err)
    SaveError(err, debugstack and debugstack(2) or nil)
    return err
end

-- Run fn(...) and catch any error in it. Returns true plus fn's results, or false.
-- (No table for the results: this runs for every message and timer, so it makes no garbage.)
local function Finish(ok, ...)
    if not ok then
        local handler = geterrorhandler and geterrorhandler()
        if handler then handler((...)) end
        return false
    end
    return ok, ...
end
function ns.Safe(fn, ...)
    return Finish(xpcall(fn, OnError, ...))
end

---------------------------------------------------------------------------------------------------
-- Our own events between modules: ns.Listen("ROSTER", fn), ns.Fire("ROSTER", ...).

local listeners = {}

function ns.Listen(name, fn)
    listeners[name] = listeners[name] or {}
    table.insert(listeners[name], fn)
end

function ns.Fire(name, ...)
    local list = listeners[name]
    if not list then return end
    for i = 1, #list do ns.Safe(list[i], ...) end
end

---------------------------------------------------------------------------------------------------
-- Game events: ns.OnEvent("PLAYER_LOGIN", fn). One frame for the whole addon.

local eventFrame = CreateFrame("Frame")
local handlers = {}

function ns.OnEvent(event, fn)
    if not handlers[event] then
        handlers[event] = {}
        eventFrame:RegisterEvent(event)
    end
    table.insert(handlers[event], fn)
end

eventFrame:SetScript("OnEvent", function(_, event, ...)
    local list = handlers[event]
    if not list then return end
    for i = 1, #list do ns.Safe(list[i], ...) end
end)

---------------------------------------------------------------------------------------------------
-- Message log: what was sent and received, newest last. Kept in saved data (last 300 lines) so it
-- can be read from the saved-variables file after a /reload.

local LOG_MAX = 300
local log = {}

function ns.Log(text)
    local line = date("%H:%M:%S") .. " " .. tostring(text)
    log[#log + 1] = line
    while #log > LOG_MAX do table.remove(log, 1) end
end

function ns.GetLog() return log end

---------------------------------------------------------------------------------------------------
-- Names. Forever gives every character a first name and a surname: "Ned Jones". The guild roster and
-- addon messages give it like that, UnitFullName("player") hands back the surname where the realm
-- usually goes ("Ned", "Jones"), and some places may add the sub-realm ("Ned Jones-SERVER1Realm1PvE")
-- or a dash ("Ned-Jones"). Whispers and invites only work with the plain "First Surname" (measured
-- on launch night). So every player is keyed by that plain name: ns.Key(name).

-- Does this look like a realm name rather than a surname? Forever's realms have digits in them
-- ("SERVER1Realm1PvE"); surnames never do.
local function IsRealmLike(s)
    if type(s) ~= "string" or s == "" then return false end
    if GetNormalizedRealmName and s == GetNormalizedRealmName() then return true end
    if GetRealmName and s == GetRealmName() then return true end
    return s:find("%d") ~= nil
end
ns.IsRealmLike = IsRealmLike

function ns.Key(name)
    if type(name) ~= "string" or name == "" then return nil end
    local base, tail = name:match("^(.-)%-([^%-]+)$")
    if base and base ~= "" and IsRealmLike(tail) then name = base end
    local first, second = name:match("^([^%s%-]+)%-([^%s%-]+)$")
    if first then name = first .. " " .. second end
    return name
end

---------------------------------------------------------------------------------------------------
-- Versions of shared things (events, requests, recipe lists, answers, guild board). Versions are
-- server times. "Direct" means it came from its author; a "copy" was passed on by another guildie.

-- A version we refuse: not a number, negative, or from the future. The author's own get 10 minutes
-- of slack; a copy only a minute (versions can run a few seconds ahead after quick edits), so a
-- copy can't claim a far-future version to stay on top.
function ns.Future(v, copy)
    return type(v) ~= "number" or v < 0 or v > GetServerTime() + (copy and 60 or 600)
end

-- Should (v, direct) replace what we hold (oldV, oldDirect)? For things with one author: the
-- author's own message is their current version and always wins over a copy; otherwise the newer
-- version wins, so a copy does bring news the author made while we were offline.
-- shared = true is for a slot several authors write (the guild info): newest wins, and on a tie
-- the author's own message.
function ns.Newer(oldV, oldDirect, v, direct, shared)
    if oldV == nil then return true end
    if not shared and direct and not oldDirect then return true end
    if v ~= oldV then return v > oldV end
    return (direct and not oldDirect) and true or false
end

-- My own key, from UnitFullName (name + surname on Forever, name + realm elsewhere).
function ns.MyKey()
    local name, second = UnitFullName("player")
    if type(name) ~= "string" or name == "" then return nil end
    if type(second) == "string" and second ~= "" and not IsRealmLike(second) then
        return name .. " " .. second
    end
    return name
end

-- Any unit's key ("party1"...), the same way: UnitName gives the surname where the realm goes.
function ns.UnitKey(unit)
    local name, second = UnitName(unit)
    name, second = ns.Public(name, "string"), ns.Public(second, "string")
    if not name or name == "" then return nil end
    if second and second ~= "" and not IsRealmLike(second) then return name .. " " .. second end
    return name
end

-- Text in letters, not bytes: an accented letter, a curly apostrophe or an emoji is 2-4 bytes, and the
-- game's edit boxes count letters (cutting at a byte count lost endings and could split a letter in
-- half).
local LETTER = "[%z\1-\127\192-\255][\128-\191]*"
function ns.Letters(s)
    local n = 0
    for _ in s:gmatch(LETTER) do n = n + 1 end
    return n
end
-- The first max letters of s (never half a letter).
function ns.CutLetters(s, max)
    if #s <= max then return s end
    local n, stop = 0, 0
    for a, b in s:gmatch("()" .. LETTER .. "()") do
        n = n + 1
        if n > max then break end
        stop = b - 1
    end
    return s:sub(1, stop)
end
-- At most max bytes, never half a letter. For limits counted in bytes (chat lines are 255 bytes;
-- the saved limits on titles and notes): s:sub(1, max) can cut an accented letter or an emoji in
-- two, and the game refuses a chat line that ends in half a letter.
function ns.CutBytes(s, max)
    if #s <= max then return s end
    local stop = max
    -- The first byte left out: if it's the middle of a letter (10xxxxxx), leave that whole letter out.
    while stop > 0 do
        local b = s:byte(stop + 1)
        if b < 128 or b >= 192 then break end
        stop = stop - 1
    end
    return s:sub(1, stop)
end
-- Shortened to max letters with "..." when it's longer.
function ns.ShortText(s, max)
    if ns.Letters(s) <= max then return s end
    return ns.CutLetters(s, max - 3) .. "..."
end

-- A value from the game we may read, or nil if Forever hides it (secret values).
function ns.Public(v, kind)
    if v == nil then return nil end
    if issecretvalue and issecretvalue(v) then return nil end
    if kind and type(v) ~= kind then return nil end
    return v
end

function ns.ClassHex(class)
    local c = class and RAID_CLASS_COLORS and RAID_CLASS_COLORS[class]
    if not c then return "ffffffff" end
    return string.format("ff%02x%02x%02x", c.r * 255, c.g * 255, c.b * 255)
end

function ns.ClassName(class)
    return (class and LOCALIZED_CLASS_NAMES_MALE and LOCALIZED_CLASS_NAMES_MALE[class]) or class or "?"
end

-- "0.1.10" > "0.1.9": compare dotted version numbers. Returns -1, 0 or 1.
function ns.CompareVersions(a, b)
    local pa, pb = {}, {}
    for n in tostring(a):gmatch("%d+") do pa[#pa + 1] = tonumber(n) end
    for n in tostring(b):gmatch("%d+") do pb[#pb + 1] = tonumber(n) end
    for i = 1, math.max(#pa, #pb) do
        local x, y = pa[i] or 0, pb[i] or 0
        if x ~= y then return x < y and -1 or 1 end
    end
    return 0
end

-- The version we tell the guild. Guildies treat the highest version they hear as the latest, so a
-- test copy of an unreleased version must not announce itself: tools/install.py stamps its .toc with
-- the last released version (X-Released). CurseForge copies have no stamp and announce their own.
function ns.AnnouncedVersion(version, released)
    if type(released) == "string" and released:match("^%d+%.%d+%.%d+$")
        and ns.CompareVersions(released, version) < 0 then
        return released
    end
    return version
end
ns.ANNOUNCED_VERSION = ns.AnnouncedVersion(ns.VERSION,
    C_AddOns and C_AddOns.GetAddOnMetadata and C_AddOns.GetAddOnMetadata(ADDON, "X-Released"))

---------------------------------------------------------------------------------------------------
-- Saved data. YeahNahMateDB is per account. Per-guild data lives under guilds[<guild key>].

ns.DEFAULTS = {
    settings = {
        minimap = true,         -- show the minimap button
        guildPlates = true,     -- brackets and the owl on guildies' nameplates (UI/Nameplates.lua)
        minimapAngle = 200,     -- where the minimap button sits (degrees round the minimap)
        showWorld = true,       -- guildies' dots on the world map
        showMinimap = true,     -- and on the minimap
        dotSize = 2,            -- 1 small, 2 medium, 3 large
        dotRing = 3,            -- ring round guildies' dots: 1 red, 2 blue, 3 gold
        pop = {                 -- which pop-ups show (0.8.5: one switch each; UI/Toast.lua)
            group = true,       -- a new dungeon group at my level / for a dungeon I'm available for
            signup = true,      -- someone signed up for my group
            request = false,    -- a guildie asked for something I can make (opt in, 0.13.0: Professions tab card)
            claim = true,       -- someone said they'll make my request
            gather = true,      -- a gathering started for an event I'm going to
            answer = true,      -- someone's going to my event
            qanswer = true,     -- an answer to my question, a reply to my answer (Questions.lua)
            milestone = true,   -- a guildie's milestone (Milestones.lua)
        },
        popupSound = true,
        remind = true,          -- reminder 15 minutes before events I'm going to
        sound = 1,              -- which pop-up sound (UI/Toast.lua SOUNDS)
        soundChannel = 1,       -- which of the game's volume sliders it follows (1 Master, 2 Effects, 3 Dialog)
        linkAlts = true,        -- link my characters in the guild (Alts.lua; 0.12.0)
        qAlert = false,         -- the small alert for every new question (opt in on the Ask tab; UI/QAlert.lua)
        -- qAlertPos: where the player dragged that alert
        -- sharePosition: nil until the player answers the first-run question, then true/false
    },
    window = {},                -- where the window was left
    guilds = {},
    errors = {},
    log = {},
    dev = { sim = false },
}

local function FillDefaults(t, defaults)
    for k, v in pairs(defaults) do
        if type(v) == "table" then
            if type(t[k]) ~= "table" then t[k] = {} end
            FillDefaults(t[k], v)
        elseif t[k] == nil then
            t[k] = v
        end
    end
end

-- The current guild's saved data (nil when not in a guild).
function ns.GuildData()
    local key = ns.Guild and ns.Guild.key
    if not key or not ns.db then return nil end
    local g = ns.db.guilds[key]
    if type(g) ~= "table" then
        g = {}
        ns.db.guilds[key] = g
    end
    if type(g.users) ~= "table" then g.users = {} end
    return g
end

ns.OnEvent("ADDON_LOADED", function(name)
    if name ~= ADDON then return end
    if type(YeahNahMateDB) ~= "table" then YeahNahMateDB = {} end
    FillDefaults(YeahNahMateDB, ns.DEFAULTS)
    ns.db = YeahNahMateDB
    -- Schema 2 (0.1.1): players are keyed "First Surname" and guilds by name only. 0.1.0 keyed
    -- them wrongly ("Ned Jones-Jones", "The Good Sorts - Jones"), so its guild data is dropped.
    if (ns.db.schema or 1) < 2 then wipe(ns.db.guilds) end
    ns.db.schema = 2
    ns.settings = ns.db.settings
    -- 0.1.2 remembered the roster sort; it no longer does.
    ns.settings.rosterSort, ns.settings.rosterSortDesc = nil, nil
    -- 0.13.0: the "I can make it" pop-up is opt in, like the Ask alert. Off once for everyone;
    -- the Professions tab's card (or Settings) turns it on.
    if not ns.settings.reqOptIn then
        ns.settings.pop.request = false
        ns.settings.reqOptIn = true
    end
    -- Before 0.8.5 one "popups" tick covered every pop-up; off then means every kind off now.
    if ns.settings.popups ~= nil then
        if ns.settings.popups == false then
            for k in pairs(ns.settings.pop) do ns.settings.pop[k] = false end
        end
        ns.settings.popups = nil
    end
    -- Errors from before the saved data loaded.
    for _, e in ipairs(pendingErrors) do SaveError(e.msg, e.stack, e.count) end
    wipe(pendingErrors)
    -- The message log lives in saved data, so it is still there after a /reload.
    local saved = ns.db.log
    for _, line in ipairs(log) do saved[#saved + 1] = line end
    while #saved > LOG_MAX do table.remove(saved, 1) end
    log = saved
    ns.Fire("LOADED")
end)

ns.OnEvent("PLAYER_LOGIN", function()
    ns.me = ns.MyKey()
    ns.Log("login as " .. tostring(ns.me) .. ", version " .. ns.VERSION)
    ns.Fire("LOGIN")
end)

---------------------------------------------------------------------------------------------------
-- Slash commands. /ynm alone opens the window; the rest are listed in /ynm help.
-- "/ynm dev ..." is for testing and isn't shown in the UI.

ns.devCommands = {}             -- filled by Sim.lua and Probe.lua

-- Dev only: the CurseForge build leaves this out (BigWigs packager's do-not-package markers).
-- A copy installed from source keeps it.
--@do-not-package@
-- /ynm dev wipe yes: forget everything this addon saved on this account (events, requests, guild
-- info, recipes, settings, log) and reload, as if freshly installed. For clearing out test data.
-- Nothing is sent: guildies who already have copies keep them until they expire.
ns.devCommands.wipe = function(arg)
    if arg ~= "yes" then
        ns.Print("This deletes everything Yeah Nah Mate has saved on this account (events, requests, guild info, recipes, settings, log) and reloads. To do it: /ynm dev wipe yes")
        return
    end
    YeahNahMateDB = nil
    ReloadUI()
end
--@end-do-not-package@

local function ShowLog()
    if #log == 0 then ns.Print(L.LOG_EMPTY) return end
    local n = math.min(15, #log)
    ns.Print(string.format(L.LOG_HEADER, n))
    for i = #log - n + 1, #log do print("  " .. log[i]) end
    if ns.Comm and ns.Comm.Summary then print("  " .. ns.Comm.Summary()) end
end

function ns.Slash(input)
    input = strtrim(strlower(input or ""))
    local cmd, rest = input:match("^(%S*)%s*(.-)$")
    if cmd == "" then
        if ns.UI and ns.UI.Toggle then ns.UI.Toggle() end
    elseif cmd == "log" then
        ShowLog()
    elseif cmd == "errors" then
        ns.Report.Command(rest)
    elseif cmd == "roll" then
        if ns.ClanRollUI then ns.ClanRollUI.TogglePop() end
    elseif cmd == "reset" then
        if ns.UI and ns.UI.ResetPosition then ns.UI.ResetPosition() end
        ns.Print(L.RESET_DONE)
    elseif cmd == "dev" then
        local sub, arg = rest:match("^(%S*)%s*(.-)$")
        local fn = ns.devCommands[sub]
        if fn then fn(arg) else ns.Print(L.HELP) end
    else
        ns.Print(L.HELP)
    end
end

SLASH_YEAHNAHMATE1 = "/ynm"
SLASH_YEAHNAHMATE2 = "/yeahnah"
SlashCmdList.YEAHNAHMATE = function(input) ns.Safe(ns.Slash, input) end
