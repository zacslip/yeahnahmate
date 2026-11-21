-- Proximity voice was removed in 0.22.0. This is what it left behind on a player's computer.
--
-- It changed each guildie's real voice volume and kept the originals in YeahNahMateDB.voice.saved. A
-- normal logout put them back, but after a crash they could still be turned down. So: put each one back
-- and forget it only once the game reads back the right volume (a call that doesn't error proves
-- nothing, and voice chat can answer late). Volumes can often only be read for people in my voice
-- channel, so it tries again when voice chat logs in or someone joins.
--
-- Keep this for several releases: players can skip versions.
local ADDON, ns = ...

local Cleanup = {}
ns.VoiceCleanup = Cleanup

local PER_PASS = 8              -- volume calls a second at most (what Proximity allowed itself)
local PASS_GAP = 1              -- seconds between passes
local EXTRA_PASSES = 3          -- more passes after each has had a turn: voice chat can answer late
local EVENT_WAIT = 3            -- seconds after a voice event, so a burst of them is one round

local OLD_SETTINGS = { "voiceOn", "voiceRange", "voiceQuietest", "voiceGroupFull", "voiceUnplaced",
    "voiceCurve", "voiceAlways", "voicePause" }
local EVENTS = { "VOICE_CHAT_LOGIN", "VOICE_CHAT_CHANNEL_ACTIVATED", "VOICE_CHAT_CHANNEL_JOINED",
    "VOICE_CHAT_CHANNEL_MEMBER_ADDED" }

local frame
local lastTry = {}              -- guid -> when it last had a turn, so nobody is left waiting
local running, waiting = false, false

local function Saved()
    local v = ns.db and ns.db.voice
    return type(v) == "table" and type(v.saved) == "table" and v.saved or nil
end

-- Was this error from our old Voice.lua or UI/Voice.lua? (Not another addon's file of the same name.)
function Cleanup.IsOldVoiceError(msg)
    if type(msg) ~= "string" then return false end
    local s = msg:find('Voice%.lua"?%]?:%d+')
    if not s then return false end
    local before = msg:sub(1, s - 1)
    if before:find(": ", 1, true) then return false end     -- only as the place the error happened
    local c = before:sub(-1)
    if c ~= "" and c ~= "/" and c ~= "\\" and c ~= "@" and c ~= '"' then return false end
    if before:find("AddOns", 1, true) and not before:find("YeahNahMate", 1, true) then return false end
    return true
end

-- Old settings and old errors: nothing to wait for.
function Cleanup.Tidy()
    local s = ns.settings
    for _, key in ipairs(OLD_SETTINGS) do s[key] = nil end
    if type(s.pop) == "table" then s.pop.voice = nil end
    local errors = ns.db.errors
    if type(errors) == "table" then
        for i = #errors, 1, -1 do
            if type(errors[i]) == "table" and Cleanup.IsOldVoiceError(errors[i].msg) then table.remove(errors, i) end
        end
    end
    local saved = Saved()
    if ns.db.voice ~= nil and not (saved and next(saved)) then ns.db.voice = nil end
end

local function Finish()
    ns.db.voice = nil
    wipe(lastTry)
    if frame then frame:UnregisterAllEvents() end
end

local function Location(guid)
    if not (PlayerLocation and PlayerLocation.CreateFromGUID) then return nil end
    local ok, loc = pcall(PlayerLocation.CreateFromGUID, PlayerLocation, guid)
    return ok and loc or nil
end

local function ReadVolume(loc)
    if not (C_VoiceChat and C_VoiceChat.GetMemberVolume) then return nil end
    local ok, v = pcall(C_VoiceChat.GetMemberVolume, loc)
    return ok and ns.Public(v, "number") or nil
end

-- One pass: up to PER_PASS people, whoever has waited longest first.
local function Pass()
    local saved = Saved()
    if not saved then return false end
    local list = {}
    for guid, base in pairs(saved) do
        if type(guid) ~= "string" or type(base) ~= "number" then saved[guid] = nil
        else list[#list + 1] = guid end
    end
    if #list == 0 then Finish() return false end
    table.sort(list, function(a, b)
        local ta, tb = lastTry[a] or 0, lastTry[b] or 0
        if ta ~= tb then return ta < tb end
        return a < b
    end)
    local now = GetTime()
    for i = 1, math.min(PER_PASS, #list) do
        local guid = list[i]
        lastTry[guid] = now
        local loc = Location(guid)
        local vol = loc and ReadVolume(loc)
        -- No answer: voice chat isn't ready or they aren't here. Never set a volume blind.
        if vol then
            if math.abs(vol - saved[guid]) <= 1 then
                saved[guid] = nil
            elseif C_VoiceChat.SetMemberVolume then
                pcall(C_VoiceChat.SetMemberVolume, loc, saved[guid])
                local after = ReadVolume(loc)
                if after and math.abs(after - saved[guid]) <= 1 then saved[guid] = nil end
            end
        end
    end
    if not next(saved) then Finish() return false end
    return true
end

-- A round: enough passes for everyone to have a turn, plus a few for late answers.
function Cleanup.Round()
    if running or not Saved() then return end
    local count = 0
    for _ in pairs(Saved()) do count = count + 1 end
    local passes = math.ceil(count / PER_PASS) + EXTRA_PASSES
    running = true
    local function Go()
        passes = passes - 1
        local ok, more = ns.Safe(Pass)
        if ok and more and passes > 0 then
            C_Timer.After(PASS_GAP, Go)
        else
            running = false
        end
    end
    Go()
end

local function Listen()
    frame = frame or CreateFrame("Frame")
    for _, e in ipairs(EVENTS) do
        local valid = not (C_EventUtils and C_EventUtils.IsEventValid) or C_EventUtils.IsEventValid(e)
        if valid then pcall(frame.RegisterEvent, frame, e) end
    end
    frame:SetScript("OnEvent", function()
        if waiting then return end
        waiting = true
        C_Timer.After(EVENT_WAIT, function()
            waiting = false
            ns.Safe(Cleanup.Round)
        end)
    end)
end

ns.Listen("LOADED", function() ns.Safe(Cleanup.Tidy) end)
ns.Listen("LOGIN", function()
    if not Saved() then return end
    ns.Safe(Listen)
    C_Timer.After(15, function() ns.Safe(Cleanup.Round) end)
end)
