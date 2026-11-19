-- 13 Nov: players' copies (the CurseForge build) have no dev commands. The packager cuts the
-- code between --@do-not-package@ and --@end-do-not-package@; this loads the addon the same way and
-- checks the player version works and has none of them. A copy installed from source keeps them.
local function read(path)
    local f = assert(io.open(path, "rb"))
    local s = f:read("*a")
    f:close()
    return s
end

-- Every file's markers pair up, and only dev code sits between them.
local unpaired = {}
for _, f in ipairs(LIST_LUA("YeahNahMate")) do
    if not f:find("/libs/", 1, true) then
        local s = read(f)
        local _, starts = s:gsub("%-%-@do%-not%-package@", "")
        local _, ends = s:gsub("%-%-@end%-do%-not%-package@", "")
        if starts ~= ends then unpaired[#unpaired + 1] = f end
        for block in s:gmatch("%-%-@do%-not%-package@(.-)%-%-@end%-do%-not%-package@") do
            if not block:find("devCommands", 1, true) then unpaired[#unpaired + 1] = f .. " (a block without a dev command)" end
        end
    end
end
check(#unpaired == 0, "do-not-package markers pair up around dev commands (" .. table.concat(unpaired, ", ") .. ")")

-- The probes are dev tools from top to bottom: nothing of theirs runs in the player version (no
-- event listeners on guild chat, loot or addon messages, no chat line).
for _, f in ipairs({ "YeahNahMate/Probe.lua", "YeahNahMate/VoiceProbe.lua", "YeahNahMate/ClanProbe.lua", "YeahNahMate/IdeaProbe.lua" }) do
    local kept = read(f):gsub("%-%-@do%-not%-package@.-%-%-@end%-do%-not%-package@", "")
    local code = kept:gsub("%-%-[^\n]*", "")
    check(not code:find("RegisterEvent", 1, true) and not code:find("SendChatMessage", 1, true) and not code:find("CreateFrame", 1, true),
        f .. ": nothing but its header ships to players")
end

PACKAGED = true
YeahNahMateDB = nil
local ns = LoadAddon("YeahNahMate", "YeahNahMate")
PACKAGED = nil
LOGGED_IN = true
FireEvent("PLAYER_LOGIN")
Tick(5)

check(next(ns.devCommands) == nil, "the player version has no dev commands")
for _, cmd in ipairs({ "dev rank 0", "dev editor on", "dev gm on", "dev sim on", "dev wipe yes", "dev msprobe chat", "dev console" }) do
    SlashCmdList.YEAHNAHMATE(cmd)
end
Tick(3)
check(ns.Board.simRank == nil and not ns.Board.devEditor and not ns.settings.devGM and not (ns.Sim and ns.Sim.IsOn())
    and YeahNahMateDB ~= nil and not ns.settings.msprobe, "typing them does nothing")
local guildLines = 0
for _, w in ipairs(WHISPERS or {}) do if w.kind == "GUILD" then guildLines = guildLines + 1 end end
check(guildLines == 0, "no test line in guild chat")

-- The player commands still work, and every tab opens.
SlashCmdList.YEAHNAHMATE("")
SlashCmdList.YEAHNAHMATE("reset")
SlashCmdList.YEAHNAHMATE("errors")
for _, tab in ipairs({ "home", "roster", "calendar", "dungeons", "professions", "ask", "legends", "streamers", "info", "settings" }) do
    ns.UI.Select(tab)
    Tick(1)
end
check(#ERRORS == 0, "the player version runs without errors (" .. (ERRORS[1] or "none") .. ")")
