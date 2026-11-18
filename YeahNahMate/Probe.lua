-- /ynm dev probe: asks the game which functions and values later phases need, and writes the
-- answers to YeahNahMateDB.probe, readable in the saved-variables file after a /reload. It only reads;
-- the one thing it asks the server for is the guild calendar (which the calendar would do anyway).
-- Dev only, all of it: the CurseForge build leaves the whole file out (BigWigs packager's
-- do-not-package markers), including its event listeners. A copy installed from source keeps it.
local ADDON, ns = ...
local L = ns.L
--@do-not-package@

local out
local rawSenders = {}           -- the sender name exactly as the game gives it, for our own prefix

local Describe
function Describe(v, depth)
    depth = depth or 0
    if v == nil then return "nil" end
    if issecretvalue and issecretvalue(v) then return "<secret>" end
    local t = type(v)
    if t == "string" then return string.format("%q", v) end
    if t == "number" or t == "boolean" then return tostring(v) end
    if t == "table" then
        if depth > 1 then return "{...}" end
        local parts, n = {}, 0
        for k, x in pairs(v) do
            n = n + 1
            if n > 12 then parts[#parts + 1] = "..." break end
            parts[#parts + 1] = tostring(k) .. "=" .. Describe(x, depth + 1)
        end
        table.sort(parts)
        return "{" .. table.concat(parts, ", ") .. "}"
    end
    return "<" .. t .. ">"
end

ns.Describe = function(v) return Describe(v) end

-- Call fn(...) and record every return value (or the error).
local function Try(key, fn, ...)
    if type(fn) ~= "function" then out[key] = "missing"; return end
    local res = (function(...) return { n = select("#", ...), ... } end)(pcall(fn, ...))
    if not res[1] then out[key] = "error: " .. tostring(res[2]); return end
    local parts = {}
    for i = 2, math.max(2, res.n) do parts[#parts + 1] = Describe(res[i]) end
    out[key] = table.concat(parts, " | ")
end

local function Exists(path)
    local v = _G
    for part in path:gmatch("[^%.]+") do
        if type(v) ~= "table" then return "missing" end
        v = v[part]
    end
    if v == nil then return "missing" end
    return type(v)
end

local FUNCTIONS = {
    -- Professions
    "GetNumTradeSkills", "GetTradeSkillInfo", "GetTradeSkillLine", "GetTradeSkillItemLink",
    "GetTradeSkillRecipeLink", "GetNumCrafts", "GetCraftInfo", "GetCraftDisplaySkillLine",
    "GetCraftItemLink", "GetCraftRecipeLink", "GetNumSkillLines", "GetSkillLineInfo", "GetProfessions",
    "C_TradeSkillUI", "C_TradeSkillUI.GetAllRecipeIDs", "GetItemInfo", "C_Item.GetItemInfo",
    -- Calendar
    "C_Calendar", "C_Calendar.OpenCalendar", "C_Calendar.GetNumGuildEvents", "C_Calendar.GetGuildEventInfo",
    "C_Calendar.GetNumDayEvents", "C_Calendar.GetDayEvent", "C_Calendar.CanAddEvent",
    "C_GuildInfo.AreGuildEventsEnabled", "C_DateAndTime.GetCurrentCalendarTime", "C_DateAndTime.GetServerTimeLocal",
    -- Map
    "C_Map.GetBestMapForUnit", "C_Map.GetPlayerMapPosition", "C_Map.GetMapInfo", "UnitPosition",
    "C_Map.GetWorldPosFromMapPos", "C_Minimap", "C_Minimap.GetViewRadius", "WorldMapFrame",
    "WorldMapFrame.pinPools", "WorldMapFrame.AddDataProvider", "Minimap",
    -- Chat, invites, guild (all phases)
    "C_ChatInfo.SendChatMessage", "SendChatMessage", "C_ChatInfo.InChatMessagingLockdown",
    "C_PartyInfo.InviteUnit", "InviteUnit", "C_GuildInfo.GuildRoster", "GuildRoster",
    "GetGuildRosterShowOffline", "IsGuildLeader", "C_GuildInfo.CanEditOfficerNote", "C_GuildInfo.IsGuildOfficer",
    "IsTrialAccount", "IsVeteranTrialAccount", "GameLimitedMode_IsActive", "issecretvalue",
    "C_EventUtils.IsEventValid", "ChatFrameUtil", "ChatFrame_OpenChat",
    "C_GamePad", "C_GamePad.IsEnabled", "GetCVarBool",
}

local EVENTS = { "TRADE_SKILL_SHOW", "TRADE_SKILL_UPDATE", "TRADE_SKILL_CLOSE", "CRAFT_SHOW", "CRAFT_UPDATE",
    "CRAFT_CLOSE", "SKILL_LINES_CHANGED", "NEW_RECIPE_LEARNED", "CALENDAR_UPDATE_GUILD_EVENTS",
    "CALENDAR_UPDATE_EVENT_LIST", "GUILD_ROSTER_UPDATE", "CHAT_MSG_ADDON", "GROUP_ROSTER_UPDATE",
    "ZONE_CHANGED_NEW_AREA", "PLAYER_LEVEL_UP", "PLAYER_REGEN_ENABLED" }

local function Run()
    out = {}
    local db = ns.db
    db.probe = { at = date("%Y-%m-%d %H:%M:%S"), version = ns.VERSION, answers = out }

    Try("GetBuildInfo", GetBuildInfo)
    out.WOW_PROJECT_ID = Describe(WOW_PROJECT_ID)
    out.WOW_PROJECT_CAMELOT = Describe(WOW_PROJECT_CAMELOT)
    Try("GetExpansionLevel", GetExpansionLevel)

    for _, f in ipairs(FUNCTIONS) do out["has " .. f] = Exists(f) end
    if C_EventUtils and C_EventUtils.IsEventValid then
        for _, e in ipairs(EVENTS) do Try("event " .. e, C_EventUtils.IsEventValid, e) end
    end

    -- Names and realms
    Try("UnitFullName", UnitFullName, "player")
    Try("UnitName", UnitName, "player")
    Try("GetRealmName", GetRealmName)
    Try("GetNormalizedRealmName", GetNormalizedRealmName)
    out["ns.me"] = Describe(ns.me)
    out["raw senders of our messages"] = Describe(rawSenders)
    out["our HI came back"] = Describe(ns.Comm.selfEcho)

    -- Guild
    Try("IsInGuild", IsInGuild)
    Try("GetGuildInfo", GetGuildInfo, "player")
    Try("GetNumGuildMembers", GetNumGuildMembers)
    Try("GetGuildRosterShowOffline", GetGuildRosterShowOffline)
    Try("IsGuildLeader", IsGuildLeader)
    if C_GuildInfo then Try("C_GuildInfo.IsGuildOfficer", C_GuildInfo.IsGuildOfficer) end
    for i = 1, 3 do Try("GetGuildRosterInfo(" .. i .. ")", GetGuildRosterInfo, i) end
    out["guild key"] = Describe(ns.Guild.key)
    out["roster members read"] = #ns.Guild.list

    -- Account and chat
    Try("IsTrialAccount", IsTrialAccount)
    Try("IsVeteranTrialAccount", IsVeteranTrialAccount)
    if C_ChatInfo then Try("InChatMessagingLockdown", C_ChatInfo.InChatMessagingLockdown) end
    if C_GamePad and C_GamePad.IsEnabled then Try("C_GamePad.IsEnabled", C_GamePad.IsEnabled) end

    -- Time
    Try("GetServerTime", GetServerTime)
    Try("time()", time)
    Try("date(*t)", date, "*t")
    if C_DateAndTime then
        Try("GetCurrentCalendarTime", C_DateAndTime.GetCurrentCalendarTime)
        Try("GetServerTimeLocal", C_DateAndTime.GetServerTimeLocal)
    end

    -- Map position
    if C_Map then
        Try("GetBestMapForUnit", C_Map.GetBestMapForUnit, "player")
        local mapID = C_Map.GetBestMapForUnit and C_Map.GetBestMapForUnit("player")
        if mapID then
            Try("GetMapInfo(best)", C_Map.GetMapInfo, mapID)
            Try("GetPlayerMapPosition", function()
                local p = C_Map.GetPlayerMapPosition(mapID, "player")
                if p and p.GetXY then return p:GetXY() end
                return p
            end)
        end
    end
    Try("UnitPosition", UnitPosition, "player")
    local HBD = LibStub("HereBeDragons-2.0", true)
    if HBD then
        Try("HBD:GetPlayerZonePosition", function() return HBD:GetPlayerZonePosition() end)
        Try("HBD:GetPlayerWorldPosition", function() return HBD:GetPlayerWorldPosition() end)
    end
    Try("IsInInstance", IsInInstance)

    -- Own professions from the skill list (only this character's, nothing is sent)
    if GetNumSkillLines and GetSkillLineInfo then
        local skills = {}
        for i = 1, (GetNumSkillLines() or 0) do
            local ok, name, header, _, rank, _, _, max = pcall(GetSkillLineInfo, i)
            if ok and name and not header then skills[#skills + 1] = tostring(name) .. " " .. tostring(rank) .. "/" .. tostring(max) end
        end
        out["skill lines"] = table.concat(skills, ", ")
    end

    -- Guild calendar: ask for it, read it when it arrives (or after 5 s).
    if C_GuildInfo and C_GuildInfo.AreGuildEventsEnabled then Try("AreGuildEventsEnabled", C_GuildInfo.AreGuildEventsEnabled) end
    if C_Calendar and C_Calendar.OpenCalendar then
        Try("OpenCalendar", C_Calendar.OpenCalendar)
        C_Timer.After(5, function()
            ns.Safe(function()
                Try("GetNumGuildEvents (after 5 s)", C_Calendar.GetNumGuildEvents)
                local n = C_Calendar.GetNumGuildEvents and C_Calendar.GetNumGuildEvents() or 0
                for i = 1, math.min(tonumber(n) or 0, 3) do
                    Try("GetGuildEventInfo(" .. i .. ")", C_Calendar.GetGuildEventInfo, i)
                end
                ns.Print(L.PROBE_DONE)
            end)
        end)
    else
        ns.Print(L.PROBE_DONE)
    end
end

-- Record how the game names the sender of our own prefix (AceComm shortens it before we see it).
local f = CreateFrame("Frame")
f:RegisterEvent("CHAT_MSG_ADDON")
f:SetScript("OnEvent", function(_, _, prefix, _, channel, sender)
    if prefix ~= ns.PREFIX or #rawSenders >= 10 then return end
    local s = tostring(sender) .. " (" .. tostring(channel) .. ")"
    for _, x in ipairs(rawSenders) do if x == s then return end end
    rawSenders[#rawSenders + 1] = s
end)

ns.devCommands.probe = function()
    ns.Print(L.PROBE_START)
    ns.Safe(Run)
end

---------------------------------------------------------------------------------------------------
-- Milestones probe. /ynm dev msprobe: reads what milestones need and keeps a
-- recorder on (through /reload) that saves skill-up, level-up, guild-join and loot lines as they
-- happen. /ynm dev msprobe chat: posts ONE test line in guild chat from a timer (no click), to see
-- if Forever allows it. /ynm dev msprobe off: recorder off. Answers go to YeahNahMateDB.msprobe.

local MS_FUNCTIONS = {
    "SendChatMessage", "C_ChatInfo.SendChatMessage", "C_ChatInfo.InChatMessagingLockdown",
    "GetProfessions", "GetProfessionInfo", "GetSkillLineInfo", "GetNumSkillLines", "C_SkillLine",
    "C_TradeSkillUI.GetAllProfessionTradeSkillLines", "C_TradeSkillUI.GetProfessionInfoBySkillLineID",
    "IsSpellKnown", "C_SpellBook", "C_SpellBook.IsSpellKnown", "C_MountJournal", "C_MountJournal.GetNumMounts",
    "GetNumCompanions", "UnitPVPRank", "GetPVPRankInfo", "GetPVPLifetimeStats", "GetPVPThisWeekStats",
    "GetHonorCurrency", "GuildInvite", "C_GuildInfo.Invite",
    "C_Container.GetContainerNumSlots", "C_Container.GetContainerItemInfo", "GetInventoryItemQuality",
    "GetInventoryItemLink", "C_Item.GetItemQualityByID",
}
local MS_EVENTS = { "CHAT_MSG_SKILL", "CHAT_MSG_SYSTEM", "CHAT_MSG_GUILD", "CHAT_MSG_LOOT", "PLAYER_LEVEL_UP",
    "SKILL_LINES_CHANGED", "LEARNED_SPELL_IN_TAB", "PLAYER_PVP_RANK_CHANGED", "HONOR_CURRENCY_UPDATE",
    "BAG_UPDATE_DELAYED", "ITEM_PUSH", "NEW_MOUNT_ADDED", "COMPANION_LEARNED", "GUILD_ROSTER_UPDATE" }
local MS_STRINGS = { "ERR_GUILD_JOIN_S", "ERR_GUILD_INVITE_S", "ERR_GUILD_LEAVE_S", "SKILL_RANK_UP",
    "ERR_SKILL_UP_SI", "ERR_LEARN_SPELL_S", "LOOT_ITEM_SELF", "LOOT_ITEM_PUSHED_SELF" }

local function MSDB()
    local db = ns.db
    db.msprobe = db.msprobe or {}
    local m = db.msprobe
    m.seen = m.seen or {}
    return m
end

-- Keep up to 12 lines per kind (secret values are written as <secret>, never read).
local function Seen(kind, ...)
    if not (ns.settings and ns.settings.msprobe) then return end
    local s = MSDB().seen
    s[kind] = s[kind] or {}
    if #s[kind] >= 12 then return end
    local parts = { date("%H:%M:%S") }
    for i = 1, select("#", ...) do parts[#parts + 1] = Describe((select(i, ...))) end
    s[kind][#s[kind] + 1] = table.concat(parts, " | ")
end

local function RunMilestones()
    local m = MSDB()
    out = {}
    m.at, m.version, m.answers = date("%Y-%m-%d %H:%M:%S"), ns.VERSION, out
    for _, fn in ipairs(MS_FUNCTIONS) do out["has " .. fn] = Exists(fn) end
    if C_EventUtils and C_EventUtils.IsEventValid then
        for _, e in ipairs(MS_EVENTS) do Try("event " .. e, C_EventUtils.IsEventValid, e) end
    end
    for _, k in ipairs(MS_STRINGS) do out["string " .. k] = Describe(_G[k]) end
    Try("UnitLevel", UnitLevel, "player")
    -- Professions without the window open?
    if GetProfessions then
        Try("GetProfessions", GetProfessions)
        local list = { pcall(GetProfessions) }
        if list[1] and GetProfessionInfo then
            for i = 2, #list do if list[i] then Try("GetProfessionInfo(" .. Describe(list[i]) .. ")", GetProfessionInfo, list[i]) end end
        end
    end
    -- Riding (Apprentice / Journeyman / Expert / Artisan spell IDs, and the classic skill 762).
    local known = (C_SpellBook and C_SpellBook.IsSpellKnown) or IsSpellKnown
    for _, id in ipairs({ 33388, 33391, 34090, 34091 }) do Try("riding spell " .. id .. " known", known, id) end
    if C_MountJournal and C_MountJournal.GetNumMounts then Try("C_MountJournal.GetNumMounts", C_MountJournal.GetNumMounts) end
    if GetNumCompanions then Try("GetNumCompanions(MOUNT)", GetNumCompanions, "MOUNT") end
    -- PvP rank
    Try("UnitPVPRank", UnitPVPRank, "player")
    local okR, rank = pcall(UnitPVPRank or error, "player")
    if okR and type(rank) == "number" and GetPVPRankInfo then Try("GetPVPRankInfo(mine)", GetPVPRankInfo, rank) end
    if GetPVPRankInfo then Try("GetPVPRankInfo(5)", GetPVPRankInfo, 5) end
    Try("GetPVPLifetimeStats", GetPVPLifetimeStats)
    Try("GetPVPThisWeekStats", GetPVPThisWeekStats)
    -- Item quality in bags and gear (legendary = 5): can we read it?
    local counts, readable = {}, 0
    if C_Container and C_Container.GetContainerNumSlots and C_Container.GetContainerItemInfo then
        for bag = 0, 4 do
            local okN, n = pcall(C_Container.GetContainerNumSlots, bag)
            for slot = 1, (okN and tonumber(n) or 0) do
                local okI, info = pcall(C_Container.GetContainerItemInfo, bag, slot)
                if okI and type(info) == "table" and type(info.quality) == "number" then
                    readable = readable + 1
                    counts[info.quality] = (counts[info.quality] or 0) + 1
                end
            end
        end
    end
    out["bag items with quality"] = readable
    out["bag qualities"] = Describe(counts)
    if GetInventoryItemQuality then
        local q = {}
        for slot = 1, 19 do local ok, v = pcall(GetInventoryItemQuality, "player", slot); if ok and v then q[#q + 1] = slot .. "=" .. Describe(v) end end
        out["gear qualities"] = table.concat(q, " ")
    end
    out["recorder"] = ns.settings.msprobe and "on" or "off"
    ns.Print(L.MSPROBE_DONE)
end

-- One test line in guild chat, sent from a timer (not a click), and whether it came back.
local chatTestAt
local function ChatTest()
    local m = MSDB()
    local send = (C_ChatInfo and C_ChatInfo.SendChatMessage) or SendChatMessage
    C_Timer.After(2, function()
        chatTestAt = GetTime()
        local ok, err = pcall(send, L.MSPROBE_CHAT_LINE, "GUILD")
        m.chat = { at = date("%Y-%m-%d %H:%M:%S"), sent = ok and "no error" or ("error: " .. tostring(err)) }
        ns.Print(ok and L.MSPROBE_CHAT_SENT or (L.MSPROBE_CHAT_FAILED .. " " .. tostring(err)))
    end)
end

local rec = CreateFrame("Frame")
for _, e in ipairs({ "CHAT_MSG_SKILL", "CHAT_MSG_SYSTEM", "CHAT_MSG_GUILD", "CHAT_MSG_LOOT", "PLAYER_LEVEL_UP",
    "PLAYER_PVP_RANK_CHANGED", "NEW_MOUNT_ADDED", "COMPANION_LEARNED", "LEARNED_SPELL_IN_TAB" }) do
    pcall(rec.RegisterEvent, rec, e)
end
rec:SetScript("OnEvent", function(_, event, a1, a2, ...)
    if event == "CHAT_MSG_GUILD" then
        -- Only the few seconds after our chat test: did our line come back, and who from?
        if chatTestAt and GetTime() - chatTestAt < 8 then
            local m = MSDB()
            if m.chat then
                m.chat.back = m.chat.back or {}
                if #m.chat.back < 4 then m.chat.back[#m.chat.back + 1] = Describe(a1) .. " from " .. Describe(a2) end
            end
        end
        return
    end
    if event == "CHAT_MSG_SYSTEM" then
        -- Only guild lines (joins, invites, leaves), not every system message.
        if issecretvalue and issecretvalue(a1) then Seen("system", a1) return end
        if type(a1) == "string" and a1:lower():find("guild", 1, true) then Seen("system", a1) end
        return
    end
    if event == "CHAT_MSG_LOOT" then
        -- Only epic or better ("ff a335ee" purple, "ff ff8000" orange) so the file stays small.
        if issecretvalue and issecretvalue(a1) then Seen("loot", a1) return end
        if type(a1) == "string" and (a1:find("ffa335ee", 1, true) or a1:find("ffff8000", 1, true)) then Seen("loot", a1) end
        return
    end
    Seen(event, a1, a2)
end)

-- Who invited a new member: no hook (we never hook Blizzard functions). The inviter's own game says
-- "You have invited X to join your guild." (ERR_GUILD_INVITE_S), which the recorder keeps above.

ns.devCommands.msprobe = function(arg)
    if arg == "off" then
        ns.settings.msprobe = nil
        ns.Print(L.MSPROBE_OFF)
        return
    end
    ns.settings.msprobe = true
    if arg == "chat" then
        ns.Print(L.MSPROBE_CHAT_SOON)
        ChatTest()
        return
    end
    ns.Print(L.MSPROBE_ON)
    ns.Safe(RunMilestones)
end
-- /ynm dev mappick: can an addon read where you click on the world map, for an event's meeting place?
-- Open the map yourself (M; we never open Blizzard's panels), then left-click spots: chat shows the
-- map, its type and the spot. Our own see-through layer sits over the map and takes only left clicks
-- (right-click and the mouse wheel still reach the map, to zoom out and move). Nothing of Blizzard's
-- is hooked or changed. /ynm dev mappick again stops. The answers are kept in YeahNahMateDB.mappick.
local pickLayer, pickDriver
local function MapPickStop()
    if pickLayer then pickLayer:Hide() end
    if pickDriver then pickDriver:Hide() end
    ns.Print("(dev) Map pick test off. /reload and tell Claude: the answers are saved.")
end

local function MapPickStart()
    local W = WorldMapFrame
    local sc = W and W.ScrollContainer
    if type(sc) ~= "table" then sc = nil end
    local db = { at = date("%Y-%m-%d %H:%M"), version = ns.VERSION, checks = {}, clicks = {} }
    YeahNahMateDB.mappick = db
    local c = db.checks
    c.WorldMapFrame = W ~= nil
    c.ScrollContainer = sc ~= nil
    c.GetMapID = W ~= nil and type(W.GetMapID) == "function"
    c.ScrollGetNormalizedCursorPosition = sc ~= nil and type(sc.GetNormalizedCursorPosition) == "function"
    c.MapGetNormalizedCursorPosition = W ~= nil and type(W.GetNormalizedCursorPosition) == "function"
    c.GetMapInfo = C_Map ~= nil and type(C_Map.GetMapInfo) == "function"
    if not (W and sc) then
        ns.Print("(dev) No world map scroll area on this client: picking on the map won't work. Saved.")
        return
    end
    if not pickLayer then
        pickLayer = CreateFrame("Frame", nil, UIParent)
        pickLayer:SetFrameStrata("FULLSCREEN_DIALOG")
        pickLayer:EnableMouse(true)
        c.SetPassThroughButtons = type(pickLayer.SetPassThroughButtons) == "function"
        if c.SetPassThroughButtons then
            c.passThroughOk = pcall(pickLayer.SetPassThroughButtons, pickLayer, "RightButton", "MiddleButton")
        end
        local tint = pickLayer:CreateTexture(nil, "BACKGROUND")
        tint:SetAllPoints()
        tint:SetColorTexture(1, 0.82, 0, 0.06)              -- a faint gold wash: the layer is on
        pickLayer:SetScript("OnMouseUp", function(_, button)
            if button ~= "LeftButton" then return end
            local mapID = W.GetMapID and ns.Public(W:GetMapID(), "number")
            local x, y
            local ok = pcall(function() x, y = sc:GetNormalizedCursorPosition() end)
            local info = mapID and C_Map.GetMapInfo and C_Map.GetMapInfo(mapID)
            local name = info and ns.Public(info.name, "string") or "?"
            local kind = info and ns.Public(info.mapType, "number")
            local click = { map = mapID, name = name, type = kind, x = ok and x or nil, y = ok and y or nil,
                            err = (not ok) and "GetNormalizedCursorPosition failed" or nil }
            db.clicks[#db.clicks + 1] = click
            while #db.clicks > 20 do table.remove(db.clicks, 1) end
            ns.Print(string.format("(dev) map %s (%s, type %s): %s", tostring(mapID), name, tostring(kind),
                (ok and x) and string.format("%.3f, %.3f", x, y) or "no spot"))
        end)
        -- Only over a zone or city map (type 3 and up): on the world and continent maps left-click
        -- must reach the map to go into a zone.
        local function ZoneMap()
            local id = W.GetMapID and ns.Public(W:GetMapID(), "number")
            local info = id and C_Map.GetMapInfo and C_Map.GetMapInfo(id)
            local t = info and ns.Public(info.mapType, "number")
            return t ~= nil and t >= 3
        end
        pickDriver = CreateFrame("Frame", nil, UIParent)
        pickDriver:SetScript("OnUpdate", function()
            local shown = W:IsShown() and ZoneMap()
            if shown and not pickLayer:IsShown() then
                pickLayer:ClearAllPoints()
                pickLayer:SetAllPoints(sc)
                pickLayer:Show()
            elseif not shown and pickLayer:IsShown() then
                pickLayer:Hide()
            end
        end)
    end
    pickLayer:Hide()
    pickDriver:Show()
    ns.Print("(dev) Map pick test on. Open your map (M). On a zone or city map (gold tint) left-click a few spots;"
        .. " on the world and continent maps clicks go to the map as usual. Then /ynm dev mappick to stop, and /reload.")
end

ns.devCommands.mappick = function()
    if pickDriver and pickDriver:IsShown() then MapPickStop() else MapPickStart() end
end
--@end-do-not-package@
