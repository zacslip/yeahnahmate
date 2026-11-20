-- Proximity voice, built on Blizzard's own voice chat: an addon can't use the mic or play sound, so
-- all we do is read the voice state, join the guild's voice channel on the player's click, and set
-- each guildie's volume by distance.
--
-- What /ynm dev vprobe showed on Forever (Nov 2026): voice chat on and logged in, Blizzard's own provider
-- (Discord also offered); the guild is a club (C_Club.GetGuildClubId) whose stream "Guild" (type 1)
-- carries the guild voice channel (channelType 4 = community); member GUIDs are readable and match
-- the guild roster's; volumes run 0-100.
local ADDON, ns = ...
local L = ns.L

local Voice = {}
ns.Voice = Voice

local GUILD_STREAM = 1          -- Enum.ClubStreamType.Guild
local COMMUNITY = 4             -- Enum.ChatChannelType.Communities
local LEGACY = 0                -- Enum.VoiceProviderID.Legacy (Blizzard's own voice service)
-- Group voice: Blizzard's own party/raid voice channel (Enum.ChatChannelType; numbers as fallback).
local CT = Enum and Enum.ChatChannelType or {}
local PRIVATE_PARTY = CT.PrivateParty or 2
local PARTY_TYPES = { [PRIVATE_PARTY] = true, [CT.PublicParty or 3] = true }
if CT.DiscordParty then PARTY_TYPES[CT.DiscordParty] = true end

local function VC(name) return C_VoiceChat and C_VoiceChat[name] end

-- Call a C_VoiceChat function safely; nil when it's missing, errors, or the answer is hidden.
local function Ask(name, ...)
    local fn = VC(name)
    if not fn then return nil end
    local ok, v = pcall(fn, ...)
    if not ok then return nil end
    if issecretvalue and issecretvalue(v) then return nil end
    return v
end
Voice.Ask = Ask

-- A field from a voice or club table, or nil when the game hides it. Ask only checks the table it got
-- back; on some clients the fields inside are secret too, and comparing one is an error (0.20.1:
-- "attempt to compare a secret string value" from GuildChannel, hundreds of times).
local function Field(t, key, kind)
    if type(t) ~= "table" then return nil end
    local v = t[key]
    if v == nil or (issecretvalue and issecretvalue(v)) then return nil end
    if kind then return type(v) == kind and v or nil end
    local tv = type(v)
    return (tv == "string" or tv == "number") and v or nil
end
Voice.Field = Field

-- The guild's club and the stream that carries its voice channel.
function Voice.GuildStream()
    if not (C_Club and C_Club.GetGuildClubId and C_Club.GetStreams) then return nil end
    local ok, club = pcall(C_Club.GetGuildClubId)
    club = ok and ns.Public(club, "string") or (ok and ns.Public(club, "number")) or nil
    if not club then return nil end
    local ok2, streams = pcall(C_Club.GetStreams, club)
    if not ok2 or type(streams) ~= "table" then return club, nil end
    for _, s in ipairs(streams) do
        if Field(s, "streamType", "number") == GUILD_STREAM then return club, Field(s, "streamId") end
    end
    return club, nil
end

-- The voice channel I'm in now, if it's the guild's: channel table, else nil.
function Voice.GuildChannel()
    local id = Ask("GetActiveChannelID")
    if not id then return nil end
    local ch = Ask("GetChannel", id)
    if type(ch) ~= "table" then return nil end
    local club, stream = Voice.GuildStream()
    if not club or not stream then return nil end
    -- Hidden ids: we can't tell it's the guild's, so it counts as not (Proximity waits).
    local cid, sid = Field(ch, "clubId"), Field(ch, "streamId")
    if not cid or not sid then return nil end
    if tostring(cid) ~= tostring(club) or tostring(sid) ~= tostring(stream) then return nil end
    return ch
end

-- Is a guildie (not me) talking in the guild channel right now?
function Voice.SomeoneTalking()
    local ch = Voice.GuildChannel()
    local members, chID = Field(ch, "members", "table"), Field(ch, "channelID")
    if not members or not chID then return false end
    for _, m in ipairs(members) do
        local id = Field(m, "memberID")
        if id and Field(m, "isSpeaking", "boolean") == true and Ask("IsMemberLocalPlayer", id, chID) ~= true then return true end
    end
    return false
end

-- The state for the speaker icon, and a line saying what it means / what to do:
--   "off"   Proximity is switched off
--   "cant"  it can't work (voice chat unavailable, off, not connected, map sharing off)
--   "notin" on, but not in the guild voice channel
--   "on"    on and in the guild voice channel
function Voice.State()
    if not C_VoiceChat then return "cant", L.VOICE_ST_NONE end
    local on = ns.settings and ns.settings.voiceOn
    local blocked = Ask("IsParentalDisabled") == true or Ask("CanPlayerUseVoiceChat") == false
    if blocked then return on and "cant" or "off", L.VOICE_ST_BLOCKED end
    if Ask("IsEnabled") == false then return on and "cant" or "off", L.VOICE_ST_DISABLED end
    -- In my group's own voice chat (group mode): everyone at normal volume, Proximity waits.
    if Voice.InGroupVoice() then return "group", L.VOICE_ST_GROUP end
    -- Proximity off but still in guild voice: plain guild voice chat, everyone at normal volume.
    if not on then return "off", Voice.InGuildVoice() and L.VOICE_ST_OFF_IN or L.VOICE_ST_OFF end
    if not (ns.Map and ns.Map.Sharing()) then return "cant", L.VOICE_ST_SHARING end
    if Voice.GuildChannel() then return "on", L.VOICE_ST_ON end
    -- Not logged in to voice is normal when you're in no voice channel (it said
    -- "can't start" for ever): joining logs in. So it's "not in guild voice", with the Join button,
    -- unless a join is already on its way.
    local club, stream = Voice.GuildStream()
    if club and stream and Ask("IsChannelJoinPending", COMMUNITY, club, stream) == true then
        return "notin", L.VOICE_ST_JOINING, true
    end
    return "notin", L.VOICE_ST_NOTIN
end

function Voice.InGuildVoice() return Voice.GuildChannel() ~= nil end

-- Leave voice (a Leave option once Proximity is unticked): the voice channel I'm in now,
-- guild or group, the way Blizzard's own voice button leaves it (DeactivateChannel).
function Voice.Leave()
    local id = Ask("GetActiveChannelID")
    if id and VC("DeactivateChannel") then pcall(C_VoiceChat.DeactivateChannel, id) end
    ns.Fire("VOICE")
end

---------------------------------------------------------------------------------------------------
-- Group mode: one button stops Proximity and turns on normal voice chat for my party or raid. It
-- moves me into Blizzard's own party/raid voice channel: only my group hears me, everyone at normal
-- volume, group members from outside the guild can join too (Blizzard's voice button). Proximity
-- stops by itself (it only runs in guild voice) and everyone's volume goes back. Guildies in my
-- group who have the addon get a pop-up with a Join button: they join with their own click; we
-- never move anyone into a voice channel. "Back to guild voice" is the guild Join.

function Voice.InGroupVoice()
    local t = Ask("GetActiveChannelType")
    return t ~= nil and PARTY_TYPES[t] == true and Ask("GetActiveChannelID") ~= nil
end

local groupJoinQueued = false

-- Join my party/raid's voice channel, as Blizzard's own button does (ChannelFrame
-- TryJoinVoiceChannelByType): the player's own voice service, logged in first if needed.
function Voice.JoinGroup()
    if not (IsInGroup and IsInGroup()) then ns.Print(L.VOICE_NO_GROUP) return false end
    if not VC("RequestJoinChannelByChannelType") then ns.Print(L.VOICE_GROUP_FAIL) return false end
    if VC("RestoreActiveVoiceProvider") then pcall(C_VoiceChat.RestoreActiveVoiceProvider) end
    local ctype = PRIVATE_PARTY
    if CT.DiscordParty and Ask("GetActiveVoiceProviderID") == (Enum.VoiceProviderID and Enum.VoiceProviderID.Discord) then
        ctype = CT.DiscordParty
    end
    if Ask("IsLoggedIn") == true then
        local ok = pcall(C_VoiceChat.RequestJoinChannelByChannelType, ctype, true)
        if not ok then ns.Print(L.VOICE_GROUP_FAIL) end
        return ok
    end
    -- Not logged in to voice yet: log in, and join when that's done (VOICE_CHAT_LOGIN below).
    groupJoinQueued = ctype
    if VC("Login") then pcall(C_VoiceChat.Login, ctype) end
    return true
end
function Voice.FinishQueuedJoin()
    if not groupJoinQueued then return end
    local ctype = groupJoinQueued
    groupJoinQueued = false
    if IsInGroup and IsInGroup() then pcall(C_VoiceChat.RequestJoinChannelByChannelType, ctype, true) end
end

-- Guildies in my party/raid (their keys), not me.
function Voice.GroupGuildies()
    local out = {}
    if not (IsInGroup and IsInGroup()) then return out end
    local raid = IsInRaid and IsInRaid()
    for i = 1, raid and 40 or 4 do
        local key = ns.UnitKey((raid and "raid" or "party") .. i)
        local m = key and key ~= ns.me and ns.Guild.Get(key)
        if m and m.online then out[#out + 1] = key end
    end
    return out
end

-- The Group voice button: join, and tell the guildies in my group (a whisper each; only those with
-- the addon see it, as a pop-up with a Join button).
function Voice.SwitchToGroup()
    if not Voice.JoinGroup() then return end
    for _, key in ipairs(Voice.GroupGuildies()) do
        ns.Comm.Send({ t = "VGRP" }, "WHISPER", key, "NORMAL")
    end
end

-- A guildie in my group moved it to group voice.
ns.Comm.On("VGRP", function(msg, from, channel)
    if channel ~= "WHISPER" or Voice.InGroupVoice() then return end
    local inGroup = false
    for _, key in ipairs(Voice.GroupGuildies()) do if key == from then inGroup = true end end
    if not inGroup or not ns.Toast then return end
    ns.Toast.Show(string.format(L.VOICE_GROUP_POP, from:match("^%S+") or from), L.VOICE_GROUP_POP_TEXT, "voice",
        { L.VOICE_JOIN_SHORT, function() Voice.JoinGroup() end })
end)

-- The Join guild voice button (the player's own click; never called by itself).
function Voice.Join()
    local club, stream = Voice.GuildStream()
    if not club or not stream or not VC("RequestJoinAndActivateCommunityStreamChannel") then
        ns.Print(L.VOICE_JOIN_FAIL)
        return false
    end
    -- As Blizzard's own guild voice button does (ChannelFrame TryJoinCommunityStreamChannel):
    -- community voice needs Blizzard's own service, not Discord; the join logs in by itself.
    if VC("SetActiveVoiceProvider") then pcall(C_VoiceChat.SetActiveVoiceProvider, LEGACY) end
    local ok = pcall(C_VoiceChat.RequestJoinAndActivateCommunityStreamChannel, club, stream)
    if not ok then ns.Print(L.VOICE_JOIN_FAIL) end
    return ok
end

function Voice.SetOn(v)
    ns.settings.voiceOn = v and true or false
    ns.Fire("SETTINGS")
end

-- Always hear a guildie at full volume, whatever the distance (click their name in the drawer).
function Voice.ToggleAlways(name)
    if not name then return end
    local s = ns.settings
    s.voiceAlways = s.voiceAlways or {}
    s.voiceAlways[name] = (not s.voiceAlways[name]) and true or nil
    ns.Fire("SETTINGS")
end

-- /ynm voice [on|off|join|group|guild|leave] and the key binding: a quick toggle without opening the
-- window.
function Voice.Command(arg)
    local s = ns.settings
    arg = arg or ""
    if arg == "on" or arg == "off" then
        Voice.SetOn(arg == "on")
    elseif arg == "join" then
        if not Voice.InGuildVoice() then Voice.Join() end
        if not s.voiceOn then Voice.SetOn(true) end
    elseif arg == "group" then
        Voice.SwitchToGroup()
        return
    elseif arg == "guild" then
        Voice.Join()
        return
    elseif arg == "leave" then
        Voice.Leave()
        return
    elseif arg == "" then
        Voice.SetOn(not s.voiceOn)
    else
        ns.Print(L.VOICE_HELP_CMD)
        return
    end
    local state, line = Voice.State()
    ns.Print(L.VOICE_TITLE .. ": " .. L["VOICE_STATE_" .. state:upper()] .. ". " .. line)
end

-- The key binding (Bindings.xml).
BINDING_HEADER_YEAHNAHMATE = "Yeah Nah Mate"
BINDING_NAME_YEAHNAHMATE_VOICE = "Proximity voice on/off"
function YeahNahMate_VoiceToggle() ns.Safe(Voice.Command, "") end

---------------------------------------------------------------------------------------------------
-- Volume by distance
--
-- Once a second while it's "on": for each other member of the guild voice channel, work out how
-- loud they should be (distance from the map positions guildies share, the range picked in the
-- drawer) and glide their volume there, at most GLIDE points a second, so nobody jumps from quiet
-- to loud. "Full" is the volume the player had for that guildie before (saved in
-- YeahNahMateDB.voice.saved by GUID), so their own choice stays the top. Everyone is put back when
-- it's no longer "on" (off, paused, left guild voice) and at logout; leftovers from a crash go back
-- at the next login unless it's on again. Mutes, mute-for-all and silenced players are never touched.

-- Ranges in plain words (players think in near/far, not yards): full volume within `full` yards,
-- fading to the quietest volume by `gone` yards. Normal fades out by 125 yd (picked with the
-- sound test, /ynm dev vtest).
Voice.RANGES = {
    close = { full = 10, gone = 60 },
    normal = { full = 20, gone = 125 },
    far = { full = 40, gone = 200 },
}
Voice.RANGE_ORDER = { "close", "normal", "far" }

-- How the volume falls between `full` and `gone` (ForeverVoice offers linear /
-- natural / smooth; VRChat and Mumble fall off roughly like real sound). "even": a straight line.
-- "natural": drops quicker at first and tails off, closer to how sound fades in real life (a straight
-- line can sound loud for a long way, then vanish near the edge).
Voice.CURVES = {
    even = function(t) return 1 - t end,
    natural = function(t) return (1 - t) * (1 - t) end,
}
Voice.CURVE_ORDER = { "even", "natural" }

-- Volume (0-1 of the guildie's own saved volume) for a distance in yards.
function Voice.Volume(yards, range, quietest, curve)
    range, quietest = range or Voice.RANGES.normal, quietest or 0
    if yards <= range.full then return 1 end
    if yards >= range.gone then return quietest end
    local t = (yards - range.full) / (range.gone - range.full)
    local f = (Voice.CURVES[curve or "even"] or Voice.CURVES.even)(t)
    return quietest + f * (1 - quietest)
end

local GLIDE = 15                -- most volume points a guildie's volume moves in a second
local MIN_STEP = 3              -- smaller changes aren't sent
local MAX_CALLS = 8             -- SetMemberVolume calls a second, all guildies together
local BACKOFF = 10              -- seconds to stop after voice chat reports an error
-- The fast lane (positions go faster to nearby guildies, without slowing the game or making
-- voices jitter): while it's on, and another voice member with the
-- addon was last within FAST_NEAR yards, my position goes every FAST seconds when I move (instead of
-- every 15+). Not "within the fade distance": their position can be 15 s old, and mounted that's
-- 165 yd, so they'd be in earshot before the fast lane started.
local FAST, FAST_NEAR = 3, 400

local ticker
local pausedUntil = 0
local applied = {}              -- guid -> the volume we last set
local before = {}               -- guid -> the one before that (voice chat may answer late)
Voice.list = {}                 -- the other members, nearest first (for the drawer and /ynm dev voice)

local function Saved()
    local db = ns.db
    db.voice = db.voice or {}
    db.voice.saved = db.voice.saved or {}
    return db.voice.saved
end

local function Loc(guid)
    if type(guid) ~= "string" or not (PlayerLocation and PlayerLocation.CreateFromGUID) then return nil end
    local ok, loc = pcall(PlayerLocation.CreateFromGUID, PlayerLocation, guid)
    return ok and loc or nil
end

local function GetVol(loc) return ns.Public(Ask("GetMemberVolume", loc), "number") end

local function SetVol(loc, v)
    local fn = VC("SetMemberVolume")
    return fn ~= nil and pcall(fn, loc, v)
end

-- Is this GUID in my party or raid?
local function InMyGroup(guid)
    if not (IsInGroup and IsInGroup()) then return false end
    local raid = IsInRaid and IsInRaid()
    for i = 1, raid and 40 or 4 do
        local g = ns.Public(UnitGUID((raid and "raid" or "party") .. i), "string")
        if g == guid then return true end
    end
    return false
end

-- How loud (0-1) a member should be, and the yards (or nil when they can't be placed).
local function Factor(name, guid, s)
    -- Always hear (like ForeverVoice's "hear them at any distance", WakVoice's
    -- per-player override): picked in the drawer's list.
    if name and s.voiceAlways and s.voiceAlways[name] then return 1, nil, "always" end
    local quietest = (s.voiceQuietest or 0) / 100
    local group = InMyGroup(guid)
    if group and s.voiceGroupFull ~= false then return 1, nil, "group" end
    if IsInInstance and IsInInstance() then
        -- No positions inside: my group is with me, everyone else isn't.
        return group and 1 or quietest, nil, "instance"
    end
    local yards = name and ns.Map and ns.Map.Distance(name, true)   -- where they probably are now
    if not yards then return s.voiceUnplaced == "quiet" and quietest or 1, nil, "unplaced" end
    return Voice.Volume(yards, Voice.RANGES[s.voiceRange] or Voice.RANGES.normal, quietest, s.voiceCurve), yards
end

-- Put every saved volume back (and forget them once they're back).
function Voice.RestoreAll()
    local saved = Saved()
    for guid, base in pairs(saved) do
        local loc = Loc(guid)
        if loc and SetVol(loc, base) then saved[guid] = nil end
        applied[guid], before[guid] = nil, nil
    end
end

local clock = debugprofilestop
Voice.stats = { ticks = 0, ms = 0, worst = 0, fastSince = nil, sentAtStart = 0 }

function Voice.Tick()
    local t0 = clock and clock()
    local s = ns.settings
    local ch = Voice.GuildChannel()
    local members, chID = Field(ch, "members", "table"), Field(ch, "channelID")
    if not members or not chID then Voice.list = {} return end
    if GetTime() < pausedUntil then return end
    local saved, list, calls = Saved(), {}, 0
    for _, m in ipairs(members) do
        local id = Field(m, "memberID")
        if id and Ask("IsMemberLocalPlayer", id, chID) ~= true then
            local guid = ns.Public(Ask("GetMemberGUID", id, chID), "string")
            local rawName = ns.Public(Ask("GetMemberName", id, chID), "string")
            local name = rawName and ns.Key(rawName)
            local loc = Loc(guid)
            local row = { name = name or "?", speaking = Field(m, "isSpeaking", "boolean") == true }
            list[#list + 1] = row
            local skip = not loc or Field(m, "isMutedForAll", "boolean") == true or Field(m, "isSilenced", "boolean") == true
                or Ask("IsMemberMuted", loc) == true
            if not skip then
                local now = GetVol(loc)
                if now then
                    -- Their own change (not ours) becomes their new saved volume.
                    -- (Not when it still reads our previous value: voice chat can take a moment.)
                    local mine = applied[guid] and (math.abs(now - applied[guid]) <= 1
                        or (before[guid] and math.abs(now - before[guid]) <= 1))
                    if saved[guid] == nil or (applied[guid] and not mine) then
                        saved[guid] = now
                    end
                    local factor, yards, why = Factor(name, guid, s)
                    local want = math.floor(saved[guid] * factor + 0.5)
                    local cur = applied[guid] or now
                    local step = math.max(-GLIDE, math.min(GLIDE, want - cur))
                    local new = cur + step
                    if new ~= cur and (math.abs(new - cur) >= MIN_STEP or new == want) and calls < MAX_CALLS then
                        if SetVol(loc, new) then before[guid], applied[guid] = cur, new; calls = calls + 1 end
                    elseif not applied[guid] then
                        applied[guid] = now
                    end
                    row.yards, row.volume, row.why, row.want = yards, applied[guid], why, want
                end
            end
            row.muted = skip
        end
    end
    table.sort(list, function(a, b)
        if (a.yards ~= nil) ~= (b.yards ~= nil) then return a.yards ~= nil end
        if a.yards and b.yards and a.yards ~= b.yards then return a.yards < b.yards end
        return a.name < b.name
    end)
    Voice.list = list

    -- The fast lane: someone in guild voice with the addon is near enough to hear me soon.
    local near = false
    for _, r in ipairs(list) do
        local raw = r.name and ns.Map.Distance(r.name)
        if raw and raw <= FAST_NEAR then near = true break end
    end
    local st = Voice.stats
    if near then
        if not st.fastSince then st.fastSince, st.sentAtStart = GetTime(), ns.Map.sentCount or 0 end
        ns.Map.Tick(FAST, "NORMAL")
    else
        st.fastSince = nil
    end
    Voice.fast = near
    ns.Fire("VOICE_LIST")
    if t0 then
        local ms = clock() - t0
        st.ticks, st.ms = st.ticks + 1, st.ms + ms
        if ms > st.worst then st.worst = ms end
    end
end

-- Start or stop the once-a-second loop with the state; put volumes back when it's not "on".
function Voice.Update()
    if not ns.settings or not ns.db then return end
    local running = Voice.State() == "on"
    if running and not ticker then
        ticker = C_Timer.NewTicker(1, function() ns.Safe(Voice.Tick) end)
        ns.Safe(Voice.Tick)
    elseif not running then
        if ticker then ticker:Cancel(); ticker = nil end
        Voice.list = {}
        if next(Saved()) then Voice.RestoreAll() end
    end
end

ns.Listen("VOICE", function() ns.Safe(Voice.Update) end)
ns.Listen("SETTINGS", function() ns.Safe(Voice.Update) end)
ns.Listen("LOGIN", function()
    -- Leftovers from a crash: put back once voice chat is up (or straight away if it's on again,
    -- the saved volumes simply carry on as the top).
    C_Timer.After(15, function() ns.Safe(Voice.Update) end)
end)
ns.OnEvent("PLAYER_LOGOUT", function() if ticker then ns.Safe(Voice.RestoreAll) end end)

-- Voice chat's own events: anything that changes the state redraws the drawer.
local EVENTS = {
    "VOICE_CHAT_LOGIN", "VOICE_CHAT_LOGOUT", "VOICE_CHAT_CONNECTION_SUCCESS", "VOICE_CHAT_ERROR",
    "VOICE_CHAT_CHANNEL_ACTIVATED", "VOICE_CHAT_CHANNEL_DEACTIVATED", "VOICE_CHAT_CHANNEL_JOINED",
    "VOICE_CHAT_CHANNEL_REMOVED", "VOICE_CHAT_CHANNEL_MEMBER_ADDED", "VOICE_CHAT_CHANNEL_MEMBER_REMOVED",
    "VOICE_CHAT_CHANNEL_MEMBER_SPEAKING_STATE_CHANGED", "VOICE_CHAT_PENDING_CHANNEL_JOIN_STATE",
    "GROUP_ROSTER_UPDATE", "GROUP_LEFT",
}
local f = CreateFrame("Frame")
for _, e in ipairs(EVENTS) do
    local valid = not (C_EventUtils and C_EventUtils.IsEventValid) or C_EventUtils.IsEventValid(e)
    if valid then pcall(f.RegisterEvent, f, e) end
end
f:SetScript("OnEvent", function(_, event)
    -- Voice chat said something went wrong (e.g. too many requests): stop changing volumes a while.
    if event == "VOICE_CHAT_ERROR" then pausedUntil = GetTime() + BACKOFF end
    -- A group voice join waiting for the voice login.
    if event == "VOICE_CHAT_LOGIN" then ns.Safe(Voice.FinishQueuedJoin) end
    ns.Fire("VOICE")
end)
