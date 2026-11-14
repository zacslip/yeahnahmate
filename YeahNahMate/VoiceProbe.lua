-- Proximity voice probe. Dev only: the CurseForge build leaves all of this
-- out (BigWigs packager's do-not-package markers); a copy installed from source keeps it.
--
-- /ynm dev vprobe          reads what proximity voice needs from Blizzard's voice chat and writes it
--                          to YeahNahMateDB.vprobe (saved at /reload). Only reads.
-- /ynm dev vprobe set      sets ONE other voice member's volume to half and reads it back (the
--                          original is kept). Then /reload and:
-- /ynm dev vprobe check    reads it again (does an addon's volume stick?) and puts it back.
--
-- /ynm dev vtest [close|normal|far] [even|natural]   the sound test: marks where you stand. Every 3 s the game's
--                          text-to-speech says "g'day" at the volume a guildie standing on the mark
--                          would have, and chat shows the yards and volume. Walk away and listen.
-- /ynm dev vtest stop      stops it (it also stops by itself after 10 minutes).
local ADDON, ns = ...

--@do-not-package@
local HBD = LibStub("HereBeDragons-2.0")
local out

local function D(v) return ns.Describe(v) end

local function Try(key, fn, ...)
    if type(fn) ~= "function" then out[key] = "missing"; return end
    local res = (function(...) return { n = select("#", ...), ... } end)(pcall(fn, ...))
    if not res[1] then out[key] = "error: " .. tostring(res[2]); return res end
    local parts = {}
    for i = 2, math.max(2, res.n) do parts[#parts + 1] = D(res[i]) end
    out[key] = table.concat(parts, " | ")
    return res
end

local function Secret(v) return issecretvalue and issecretvalue(v) or false end

local function VC(name) return C_VoiceChat and C_VoiceChat[name] end

-- A PlayerLocation for a GUID, or nil and why.
local function Loc(guid)
    if Secret(guid) then return nil, "guid is secret" end
    if type(guid) ~= "string" then return nil, "no guid" end
    if not (PlayerLocation and PlayerLocation.CreateFromGUID) then return nil, "no PlayerLocation" end
    local ok, loc = pcall(PlayerLocation.CreateFromGUID, PlayerLocation, guid)
    if not ok then return nil, "CreateFromGUID error: " .. tostring(loc) end
    return loc
end

-- Guild roster GUIDs by plain name, to compare with the voice members' GUIDs.
local function RosterGUIDs()
    local t = {}
    for i = 1, (GetNumGuildMembers and GetNumGuildMembers() or 0) do
        local full, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _, guid = GetGuildRosterInfo(i)
        if type(full) == "string" and not Secret(full) then t[ns.Key and ns.Key(full) or full] = guid end
    end
    return t
end

-- The other voice members of the active channel: { id, guid, name, loc }.
local function Members()
    local list = {}
    local chID = VC("GetActiveChannelID") and C_VoiceChat.GetActiveChannelID()
    if not chID or Secret(chID) then return list, chID end
    local ok, ch = pcall(C_VoiceChat.GetChannel, chID)
    if not ok or type(ch) ~= "table" or Secret(ch) or type(ch.members) ~= "table" then return list, chID end
    for _, m in ipairs(ch.members) do
        local id = m.memberID
        local isMe = VC("IsMemberLocalPlayer") and select(2, pcall(C_VoiceChat.IsMemberLocalPlayer, id, chID))
        local guid = VC("GetMemberGUID") and select(2, pcall(C_VoiceChat.GetMemberGUID, id, chID))
        local name = VC("GetMemberName") and select(2, pcall(C_VoiceChat.GetMemberName, id, chID))
        list[#list + 1] = { id = id, guid = guid, name = name, me = isMe == true, info = m, loc = (Loc(guid)) }
    end
    return list, chID
end

local function Run()
    YeahNahMateDB.vprobe = { at = date("%Y-%m-%d %H:%M"), version = ns.VERSION }
    out = YeahNahMateDB.vprobe
    for _, n in ipairs({ "IsEnabled", "CanPlayerUseVoiceChat", "IsLoggedIn", "IsVoiceChatConnected",
        "CanAccessSettings", "GetActiveVoiceProviderID", "GetCurrentVoiceChatConnectionStatusCode",
        "IsParentalDisabled", "IsParentalMuted", "IsMuted", "IsDeafened", "IsSilenced",
        "GetCommunicationMode", "GetOutputVolume", "GetMasterVolumeScale", "GetActiveChannelID",
        "GetActiveChannelType", "SetMemberVolume", "GetMemberVolume", "SpeakText",
        "RequestJoinAndActivateCommunityStreamChannel" }) do
        if n:match("^Set") or n:match("^Speak") or n:match("^Request") then
            out["exists " .. n] = VC(n) and "yes" or "missing"
        else
            Try(n, VC(n))
        end
    end
    out["C_Discord.IsVoiceEnabled"] = C_Discord and C_Discord.IsVoiceEnabled and D(select(2, pcall(C_Discord.IsVoiceEnabled))) or "missing"
    out["cvar voiceProvider"] = GetCVar and D(GetCVar("voiceProvider")) or "missing"
    out["InChatMessagingLockdown"] = C_ChatInfo and C_ChatInfo.InChatMessagingLockdown and D(C_ChatInfo.InChatMessagingLockdown()) or "missing"
    out["PlayerLocation.CreateFromGUID"] = (PlayerLocation and PlayerLocation.CreateFromGUID) and "yes" or "missing"

    -- Text to speech (the sound test).
    local voices = VC("GetTtsVoices") and select(2, pcall(C_VoiceChat.GetTtsVoices))
    if type(voices) == "table" then
        local names = {}
        for i, v in ipairs(voices) do if i <= 4 then names[#names + 1] = tostring(v.voiceID) .. "=" .. tostring(v.name) end end
        out["tts voices"] = #voices .. ": " .. table.concat(names, ", ")
    else
        out["tts voices"] = D(voices)
    end

    -- The guild as a club, its streams, and which one has a voice channel.
    local clubId = C_Club and C_Club.GetGuildClubId and C_Club.GetGuildClubId()
    out["guild clubId"] = D(clubId)
    if clubId and C_Club.GetStreams then
        local ok, streams = pcall(C_Club.GetStreams, clubId)
        if ok and type(streams) == "table" then
            for i, s in ipairs(streams) do
                local key = "stream " .. i .. " " .. tostring(s.name) .. " (id " .. tostring(s.streamId) .. ", type " .. tostring(s.streamType) .. ")"
                local ch = VC("GetChannelForCommunityStream") and select(2, pcall(C_VoiceChat.GetChannelForCommunityStream, clubId, s.streamId))
                out[key] = ch and D(ch) or "no voice channel"
            end
        else
            out["streams"] = "error: " .. tostring(streams)
        end
        if VC("GetJoinClubVoiceChannelError") then Try("GetJoinClubVoiceChannelError", C_VoiceChat.GetJoinClubVoiceChannelError, clubId) end
    end

    -- The channel I'm in now and who's in it.
    local members, chID = Members()
    if chID then Try("active channel", C_VoiceChat.GetChannel, chID) end
    -- Group mode: Blizzard's party/raid voice channel.
    local CT = Enum and Enum.ChatChannelType
    out["Enum.ChatChannelType"] = CT and D(CT) or "missing"
    out["exists RequestJoinChannelByChannelType"] = VC("RequestJoinChannelByChannelType") and "yes" or "missing"
    if VC("GetChannelForChannelType") then
        Try("party channel", C_VoiceChat.GetChannelForChannelType, (CT and CT.PrivateParty) or 2)
    end
    out["in group"] = tostring(IsInGroup and IsInGroup() or false) .. (IsInRaid and IsInRaid() and " (raid)" or "")
    out["in group voice"] = tostring(ns.Voice.InGroupVoice())
    local roster = RosterGUIDs()
    out["members"] = #members
    for i, m in ipairs(members) do
        if i > 10 then break end
        local key = "member " .. i
        local name = m.name
        local plain = (type(name) == "string" and not Secret(name)) and (ns.Key and ns.Key(name) or name) or nil
        local parts = {
            "name=" .. D(name), "me=" .. tostring(m.me), "guid=" .. (Secret(m.guid) and "<secret>" or D(m.guid)),
            "speaking=" .. D(m.info.isSpeaking), "active=" .. D(m.info.isActive),
            "rosterGUID=" .. (plain and D(roster[plain]) or "?"),
            "sameAsRoster=" .. tostring(plain ~= nil and roster[plain] ~= nil and roster[plain] == m.guid),
        }
        local loc, why = Loc(m.guid)
        if loc then
            parts[#parts + 1] = "volume=" .. D(select(2, pcall(C_VoiceChat.GetMemberVolume, loc)))
            parts[#parts + 1] = "muted=" .. D(select(2, pcall(C_VoiceChat.IsMemberMuted, loc)))
        else
            parts[#parts + 1] = "no location: " .. why
        end
        out[key] = table.concat(parts, ", ")
    end

    local inVoice = chID and #members > 0
    ns.Print(string.format("Voice probe: voice chat %s, logged in %s, in a voice channel %s (%d in it). /reload to save it.",
        out["IsEnabled"] or "?", out["IsLoggedIn"] or "?", inVoice and "yes" or "no", #members))
end

-- set / check: one other member at half volume, then (after /reload) read it again and put it back.
local function SetTest()
    local members = Members()
    local target
    for _, m in ipairs(members) do if not m.me and m.loc then target = m break end end
    YeahNahMateDB.vprobe = YeahNahMateDB.vprobe or {}
    out = YeahNahMateDB.vprobe
    if not target then
        out["set"] = "nobody to test on (needs another guildie in the voice channel)"
        ns.Print("Voice probe: nobody else in your voice channel to test on.")
        return
    end
    local ok0, before = pcall(C_VoiceChat.GetMemberVolume, target.loc)
    local half = (type(before) == "number" and before > 1) and 50 or 0.5
    local ok1, err = pcall(C_VoiceChat.SetMemberVolume, target.loc, half)
    local ok2, after = pcall(C_VoiceChat.GetMemberVolume, target.loc)
    out["set"] = string.format("before=%s set(%s)=%s after=%s", D(ok0 and before or "error"), tostring(half),
        ok1 and "ok" or ("error: " .. tostring(err)), D(ok2 and after or "error"))
    out["set guid"] = target.guid
    out["set original"] = ok0 and before or nil
    ns.Print("Voice probe: set " .. tostring(target.name) .. " to half (" .. out["set"] .. "). Now /reload, then /ynm dev vprobe check")
end

local function CheckTest()
    out = YeahNahMateDB.vprobe or {}
    YeahNahMateDB.vprobe = out
    local loc = Loc(out["set guid"])
    if not loc then ns.Print("Voice probe: run /ynm dev vprobe set first.") return end
    local ok, now = pcall(C_VoiceChat.GetMemberVolume, loc)
    local orig = out["set original"]
    local okR = orig ~= nil and pcall(C_VoiceChat.SetMemberVolume, loc, orig)
    local _, back = pcall(C_VoiceChat.GetMemberVolume, loc)
    out["check"] = string.format("after reload=%s, put back to %s: %s, now=%s", D(ok and now or "error"), D(orig),
        okR and "ok" or "failed", D(back))
    ns.Print("Voice probe: " .. out["check"] .. ". /reload to save it.")
end

ns.devCommands.vprobe = function(arg)
    if arg == "set" then ns.Safe(SetTest)
    elseif arg == "check" then ns.Safe(CheckTest)
    else ns.Safe(Run) end
end

---------------------------------------------------------------------------------------------------
-- The sound test

local test                      -- { m, x, y, range, ticker, voice, started, last }
local WORD = "g'day"

local function StopTest(why)
    if not test then return end
    test.ticker:Cancel()
    test = nil
    ns.Print("Sound test stopped" .. (why and (": " .. why) or "") .. ".")
end

local function TestTick()
    if not test then return end
    if GetTime() - test.started > 600 then StopTest("10 minutes are up") return end
    local m, x, y = ns.Map.MyPosition()
    if not m then
        print("  (can't tell where you are here, e.g. in a dungeon)")
        return
    end
    local yards = HBD:GetZoneDistance(m, x, y, test.m, test.x, test.y)
    if not yards then print("  (too far: another continent)") return end
    local vol = ns.Voice.Volume(yards, test.range, 0, test.curve)
    local pct = math.floor(vol * 100 + 0.5)
    if pct > 0 then
        local ok, err = pcall(C_VoiceChat.SpeakText, test.voice, WORD, 0, pct, false)
        if not ok then StopTest("the game wouldn't speak (" .. tostring(err) .. ")") return end
    end
    print(string.format("  %d yd: volume %d%%", math.floor(yards + 0.5), pct))
end

ns.devCommands.vtest = function(arg)
    if arg == "stop" then StopTest() return end
    -- /ynm dev vtest [close|normal|far] [even|natural]: the range and the fade curve to try.
    local rname, curve = "normal", nil
    for word in (arg or ""):gmatch("%S+") do
        if ns.Voice.RANGES[word] then rname = word
        elseif ns.Voice.CURVES[word] then curve = word
        else ns.Print("Sound test: /ynm dev vtest [close | normal | far] [even | natural], or stop") return end
    end
    local range = ns.Voice.RANGES[rname]
    curve = curve or ns.settings.voiceCurve or "even"
    arg = rname .. ", " .. curve
    if not (VC("SpeakText") and VC("GetTtsVoices")) then ns.Print("Sound test: this game has no text to speech.") return end
    local ok, voices = pcall(C_VoiceChat.GetTtsVoices)
    if not ok or type(voices) ~= "table" or not voices[1] then ns.Print("Sound test: no text-to-speech voices installed.") return end
    local m, x, y = ns.Map.MyPosition()
    if not m then ns.Print("Sound test: can't tell where you are here (dungeons don't work).") return end
    if test then test.ticker:Cancel() end
    test = { m = m, x = x, y = y, range = range, curve = curve, voice = voices[1].voiceID, started = GetTime() }
    test.ticker = C_Timer.NewTicker(3, function() ns.Safe(TestTick) end)
    ns.Print(string.format("Sound test (%s): marked this spot. Full volume within %d yd, silent by %d yd. Walk away and listen. /ynm dev vtest stop to end.",
        arg ~= "" and arg or "normal", range.full, range.gone))
    TestTick()
end

-- /ynm dev voice: who's in guild voice and what the addon has done with their volume.
ns.devCommands.voice = function()
    local state, line = ns.Voice.State()
    ns.Print("Proximity voice: " .. state .. " - " .. tostring(line))
    -- What it costs, to watch for any slow-down.
    local st = ns.Voice.stats
    if st.ticks > 0 then
        print(string.format("  cost: %.2f ms a second on average, worst %.2f ms (%d seconds measured)",
            st.ms / st.ticks, st.worst, st.ticks))
    end
    if st.fastSince then
        local mins = math.max(1 / 60, (GetTime() - st.fastSince) / 60)
        print(string.format("  fast positions on: %.1f sent a minute", ((ns.Map.sentCount or 0) - st.sentAtStart) / mins))
    else
        print("  fast positions off (no guildie in voice within 400 yd)")
    end
    if #ns.Voice.list == 0 then print("  (nobody else in guild voice)") return end
    for _, r in ipairs(ns.Voice.list) do
        print(string.format("  %s: %s, volume %s (aiming for %s)%s%s", r.name,
            r.yards and (math.floor(r.yards + 0.5) .. " yd") or (r.why or "can't place"),
            tostring(r.volume or "-"), tostring(r.want or "-"),
            r.muted and ", muted (left alone)" or "", r.speaking and ", talking" or ""))
    end
end
--@end-do-not-package@
