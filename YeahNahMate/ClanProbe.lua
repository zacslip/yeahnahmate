-- Clan probe: can we read what the Clan tab needs on Forever? Dev only: the CurseForge build leaves
-- all of this out (BigWigs packager's do-not-package markers); a copy installed from source keeps it.
--
-- /ynm dev clanprobe            reads my race and every guildie's race from their roster GUID
--                               (GetPlayerInfoByGUID), now and again 15 s later (the game may fill
--                               its cache in between), and starts the whisper watch. Answers go to
--                               YeahNahMateDB.clanprobe (saved at /reload) and a summary to chat.
-- /ynm dev clanprobe off        stops the whisper watch (it stays on across /reloads until then).
--
-- The whisper watch notes, for each whisper I receive (a whisper to myself counts): could the text
-- and the sender be read (or are they secret), is the sender a guildie or me, would it count as
-- asking for an invite ("inv", "invite", "inv pls" ...), and where I was (town, instance, combat).
-- It never saves what the whisper said or who sent it, and never answers.
local ADDON, ns = ...

--@do-not-package@
local MAX_WHISPERS = 40

local function Secret(v) return issecretvalue and issecretvalue(v) or false end

-- How a value came back: "ok", "secret", "nil" or its type.
local function How(v, kind)
    if v == nil then return "nil" end
    if Secret(v) then return "secret" end
    if kind and type(v) ~= kind then return type(v) end
    if kind == "string" and v == "" then return "empty" end
    return "ok"
end

-- Would this whisper count as asking for an invite? The whole message, any case, spaces and
-- punctuation ignored: inv, invite, inv pls / plz / please, invite pls ...
function ns.ClanProbeInvWord(text)
    if type(text) ~= "string" then return false end
    local s = text:lower():gsub("[^%a]", "")
    return s:match("^inv$") ~= nil or s:match("^invite$") ~= nil
        or s:match("^invp?l[sz]e?$") ~= nil or s:match("^invitep?l[sz]e?$") ~= nil
        or s == "invplease" or s == "inviteplease"
end

local function Store()
    YeahNahMateDB.clanprobe = YeahNahMateDB.clanprobe or {}
    return YeahNahMateDB.clanprobe
end

---------------------------------------------------------------------------------------------------
-- Races

local function ReadRaces(label)
    local out = { at = date("%H:%M:%S"), members = 0, online = 0 }
    local hows = { guid = {}, race = {} }
    local byRace, onlineKnown, offlineKnown = {}, 0, 0
    local n = GetNumGuildMembers and GetNumGuildMembers() or 0
    for i = 1, n do
        local full, _, _, _, _, _, _, _, online, _, _, _, _, _, _, _, guid = GetGuildRosterInfo(i)
        if full then
            out.members = out.members + 1
            local on = online == true and not Secret(online)
            if on then out.online = out.online + 1 end
            local hg = How(guid, "string")
            hows.guid[hg] = (hows.guid[hg] or 0) + 1
            local hr = "no guid"
            if hg == "ok" then
                if type(GetPlayerInfoByGUID) ~= "function" then
                    hr = "no GetPlayerInfoByGUID"
                else
                    local ok, _, _, _, race = pcall(GetPlayerInfoByGUID, guid)
                    if not ok then hr = "error"
                    else
                        hr = How(race, "string")
                        if hr == "ok" then
                            byRace[race] = (byRace[race] or 0) + 1
                            if on then onlineKnown = onlineKnown + 1 else offlineKnown = offlineKnown + 1 end
                        end
                    end
                end
            end
            hows.race[hr] = (hows.race[hr] or 0) + 1
        end
    end
    out.guid, out.race, out.byRace = hows.guid, hows.race, byRace
    out.raceKnownOnline, out.raceKnownOffline = onlineKnown, offlineKnown
    Store()[label] = out
    return out
end

local function Mine()
    local out = {}
    if type(UnitRace) ~= "function" then out.unitRace = "missing" else
        local ok, loc, file, id = pcall(UnitRace, "player")
        out.unitRace = ok and (How(file, "string") .. " " .. tostring(not Secret(file) and file or "?")
            .. " / " .. tostring(not Secret(loc) and loc or "?") .. " / id " .. tostring(not Secret(id) and id or "?")) or "error"
    end
    local guid = UnitGUID and UnitGUID("player")
    if How(guid, "string") == "ok" and type(GetPlayerInfoByGUID) == "function" then
        local ok, _, _, _, race = pcall(GetPlayerInfoByGUID, guid)
        out.myGuidRace = ok and (How(race, "string") .. " " .. tostring(not Secret(race) and race or "?")) or "error"
    else
        out.myGuidRace = "no guid or no GetPlayerInfoByGUID"
    end
    Store().mine = out
    return out
end

local function Count(t)
    local parts = {}
    for k, v in pairs(t) do parts[#parts + 1] = k .. " " .. v end
    table.sort(parts)
    return table.concat(parts, ", ")
end

local function PrintRaces(r, label)
    ns.Print(string.format("Clan probe (%s): %d guildies (%d online). Race read for %d online + %d offline.",
        label, r.members, r.online, r.raceKnownOnline, r.raceKnownOffline))
    print("  GUIDs: " .. Count(r.guid) .. ". Race: " .. Count(r.race) .. ".")
    if next(r.byRace) then print("  Races: " .. Count(r.byRace)) end
end

---------------------------------------------------------------------------------------------------
-- The whisper watch

local hooked = false

local function Where()
    local inInst, kind = false, nil
    if IsInInstance then inInst, kind = IsInInstance() end
    local combat = (InCombatLockdown and InCombatLockdown()) or (UnitAffectingCombat and UnitAffectingCombat("player")) or false
    local w = inInst and ("instance " .. tostring(kind)) or ((IsResting and IsResting()) and "town" or "outdoors")
    if combat then w = w .. ", in combat" end
    return w
end

local function OnWhisper(event, text, sender, ...)
    local s = YeahNahMateDB and YeahNahMateDB.clanprobe
    if not s or not s.watch then return end
    local guid = select(10, ...)                    -- arg 12 of the event
    local row = { at = date("%H:%M:%S"), event = event, where = Where(),
                  text = How(text, "string"), sender = How(sender, "string"), guid = How(guid, "string") }
    if row.text == "ok" then
        row.len = #text
        row.inv = ns.ClanProbeInvWord(text)
    end
    if row.sender == "ok" then
        local key = ns.Key(sender)
        row.me = key == ns.me
        row.guildie = ns.Guild.IsMember(key) and true or false
    end
    s.whispers = s.whispers or {}
    table.insert(s.whispers, row)
    while #s.whispers > MAX_WHISPERS do table.remove(s.whispers, 1) end
    if event == "CHAT_MSG_WHISPER" then
        ns.Print(string.format("Clan probe: whisper heard (%s): text %s, sender %s%s%s.", row.where, row.text, row.sender,
            row.me and ", from me" or (row.guildie and ", a guildie" or ""),
            row.inv and ", counts as 'inv'" or (row.text == "ok" and ", not an 'inv'" or "")))
    end
end

local function Hook()
    if hooked then return end
    hooked = true
    -- ns.OnEvent handlers get the event's arguments without its name (already inside ns.Safe).
    ns.OnEvent("CHAT_MSG_WHISPER", function(...) OnWhisper("CHAT_MSG_WHISPER", ...) end)
    ns.OnEvent("CHAT_MSG_WHISPER_INFORM", function(...) OnWhisper("CHAT_MSG_WHISPER_INFORM", ...) end)
end

-- Still watching after a /reload.
ns.Listen("LOGIN", function()
    if YeahNahMateDB and YeahNahMateDB.clanprobe and YeahNahMateDB.clanprobe.watch then Hook() end
end)

local function Run()
    local s = Store()
    s.version = ns.VERSION
    local m = Mine()
    ns.Print("Clan probe: my race " .. m.unitRace .. "; from my GUID: " .. m.myGuidRace .. ".")
    if C_GuildInfo and C_GuildInfo.GuildRoster then pcall(C_GuildInfo.GuildRoster) elseif GuildRoster then pcall(GuildRoster) end
    PrintRaces(ReadRaces("now"), "now")
    C_Timer.After(15, function() ns.Safe(function() PrintRaces(ReadRaces("after15s"), "15 s later") end) end)
    s.watch = true
    Hook()
    local n = s.whispers and #s.whispers or 0
    ns.Print("Clan probe: whisper watch on (" .. n .. " noted so far). Whisper yourself \"inv\" (/w your name),"
        .. " also in a dungeon and in a fight. /ynm dev clanprobe off stops it; /reload saves.")
end

ns.devCommands.clanprobe = function(arg)
    if arg == "off" then
        Store().watch = false
        ns.Print("Clan probe: whisper watch off. /reload to save.")
    else
        ns.Safe(Run)
    end
end
--@end-do-not-package@
