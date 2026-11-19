-- Reads the game's own guild roster: names, levels, classes, zones, ranks, notes, online.
-- No addon is needed on the other end for any of this. Fires ns "ROSTER" after each read.
--
-- Sim mode (Sim.lua) adds fake guildmates through Guild.SetFakes; they're marked sim = true and
-- never leave this client.
local ADDON, ns = ...
local Public = ns.Public

local Guild = {}
ns.Guild = Guild

Guild.members = {}      -- "Name-Realm" -> member
Guild.list = {}         -- the same members, as a list
Guild.name = nil        -- the guild's name from the game
Guild.key = nil         -- saved-data key: guild name + realm
Guild.loaded = false    -- true after the first roster read with members in it
Guild.complete = false  -- the last read had every member the game counts (safe to forget leavers)
Guild.myRank = nil      -- my rank index (0 = guild master)

local fakes = nil       -- sim mode's fake members, or nil
local lastAsk = -100

-- Ask the server for a fresh roster. The game limits this itself; we ask at most every 15 s.
function Guild.Request(force)
    if not IsInGuild() then return end
    local now = GetTime()
    if not force and now - lastAsk < 15 then return end
    lastAsk = now
    if C_GuildInfo and C_GuildInfo.GuildRoster then
        C_GuildInfo.GuildRoster()
    elseif GuildRoster then
        GuildRoster()
    end
end

local function UpdateGuildName()
    local name, _, rankIndex = GetGuildInfo("player")
    name = Public(name, "string")
    if name and name ~= "" then
        Guild.name = name
        -- Just the guild's name: a Forever guild spans sub-realms, and the one we land on can change.
        Guild.key = name
        Guild.myRank = tonumber(Public(rankIndex))
    elseif not IsInGuild() then
        Guild.name, Guild.key, Guild.myRank = nil, nil, nil
    end
end

-- Read every row of the roster. Values Forever hides (secret) are treated as missing.
-- Each member keeps one table for the whole session, updated in place: the game sends roster
-- updates every few seconds in a big guild, and building 500 fresh tables each time made about
-- 5 MB of garbage a minute (the memory number in Settings climbed to 12 MB between sweeps).
local scanNo = 0
function Guild.Scan()
    if not ns.me then return end            -- before login my own name isn't known yet
    UpdateGuildName()
    scanNo = scanNo + 1
    local members = Guild.members
    wipe(Guild.list)
    local myGUID = UnitGUID and Public(UnitGUID("player"), "string")
    Guild.complete = false
    if IsInGuild() then
        local total = tonumber((GetNumGuildMembers())) or 0
        local read = 0
        for i = 1, total do
            local name, rank, rankIndex, level, _, zone, note, _, online, status, class, _, _, _, _, _, guid =
                GetGuildRosterInfo(i)
            local full = ns.Key(Public(name, "string"))
            -- My own row, found by GUID, is the final word on how the game writes my name.
            if full and myGUID and Public(guid, "string") == myGUID and full ~= ns.me then
                ns.Log("my name in the roster is " .. full .. " (was " .. tostring(ns.me) .. ")")
                ns.me = full
            end
            if full then read = read + 1 end
            local m = full and members[full]
            if full and not (m and m.scan == scanNo) then      -- a name twice in the roster: first row wins
                if not m or m.sim then m = { name = full }; members[full] = m end
                m.rank = Public(rank, "string") or ""
                m.rankIndex = tonumber(Public(rankIndex)) or 99
                m.level = tonumber(Public(level)) or 0
                m.zone = Public(zone, "string") or ""
                m.note = Public(note, "string") or ""
                m.online = Public(online) and true or false
                m.status = tonumber(Public(status)) or 0     -- 0 none, 1 away, 2 busy
                m.class = Public(class, "string")
                m.guid = Public(guid, "string")             -- for their race (Clans.lua)
                -- Days since they were last on (0 = online), for the breakdown's "active this week".
                -- nil when the game doesn't say.
                m.offDays = nil
                if m.online then
                    m.offDays = 0
                elseif GetGuildRosterLastOnline then
                    local y, mo, d, h = GetGuildRosterLastOnline(i)
                    y, mo, d, h = tonumber(Public(y)), tonumber(Public(mo)), tonumber(Public(d)), tonumber(Public(h))
                    if y or mo or d or h then m.offDays = (y or 0) * 365 + (mo or 0) * 30 + (d or 0) + (h or 0) / 24 end
                end
                m.scan = scanNo
                Guild.list[#Guild.list + 1] = m
            end
        end
        if #Guild.list > 0 then Guild.loaded = true end
        Guild.complete = total > 0 and read == total
    end
    if fakes then
        for _, m in ipairs(fakes) do
            local have = members[m.name]
            if not (have and have.scan == scanNo) then
                members[m.name] = m
                m.scan = scanNo
                Guild.list[#Guild.list + 1] = m
            end
        end
    end
    -- Whoever wasn't in this read has left (or sim mode ended).
    for name, m in pairs(members) do
        if m.scan ~= scanNo then members[name] = nil end
    end
    -- Fresher level, zone and status from addon messages (Status.lua).
    if ns.Status then
        for _, m in ipairs(Guild.list) do ns.Status.Apply(m) end
    end
    ns.Fire("ROSTER")
end

function Guild.IsMember(full)
    return full ~= nil and Guild.members[full] ~= nil
end

function Guild.Get(full) return Guild.members[full] end

-- Sim mode: a list of fake members (or nil to remove them), then a fresh read.
function Guild.SetFakes(list)
    fakes = list
    Guild.Scan()
end

-- The game sends GUILD_ROSTER_UPDATE often in a big guild (logins, notes, our own requests): one scan
-- a second after a burst, not one per event.
local scanTimer = nil
ns.OnEvent("GUILD_ROSTER_UPDATE", function()
    if scanTimer then return end
    scanTimer = C_Timer.NewTimer(1, function() scanTimer = nil; ns.Safe(Guild.Scan) end)
end)
ns.OnEvent("PLAYER_GUILD_UPDATE", function()
    UpdateGuildName()
    Guild.Request(true)
    Guild.Scan()
end)

ns.Listen("LOGIN", function()
    UpdateGuildName()
    Guild.Scan()
    Guild.Request(true)
    -- Keep the roster fresh: every 60 s (the window asks too when it opens).
    C_Timer.NewTicker(60, function() Guild.Request() end)
end)
