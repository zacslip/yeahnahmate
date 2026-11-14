-- Project rules checked on the source itself (CONTRIBUTING.md, Rules). Our own code only: libs/ is
-- third-party and exempt (ChatThrottleLib's secure hooks are an accepted exception, see LIBRARIES.md).

local function listLua(dir)
    local out = {}
    for _, f in ipairs(LIST_LUA(dir)) do out[#out + 1] = f end    -- recursive, from tests/run.py
    return out
end

local function read(path)
    local f = assert(io.open(path, "rb"))
    local s = f:read("*a")
    f:close()
    return s
end

-- Things our code must never contain, and why.
local FORBIDDEN = {
    { "UISpecialFrames",     "taints Blizzard's panel code (handle Escape on our own frame)" },
    { "ShowUIPanel",         "panel functions taint Blizzard's UI" },
    { "HideUIPanel",         "panel functions taint Blizzard's UI" },
    { "COMBAT_LOG_EVENT",    "the combat log is Blizzard-only on Forever" },
    { "CombatLogGet",        "the combat log is Blizzard-only on Forever" },
    { "StaticPopup_Show",    "game popups break under Forever's gamepad UI; use our own dialog" },
    { "hooksecurefunc",      "we don't hook Blizzard functions" },
    { "RunScript",           "no running strings as code" },
    { "loadstring",          "no running strings as code" },
    { "SetCVar",             "don't change the player's game settings" },
    { "AcceptGroup",         "never accept invites for the player" },
    { "AcceptTrade",         "never trade for the player" },
    { "COMBAT_LOG",          "the combat log is Blizzard-only on Forever" },
}
-- Only Comm.lua talks to the game's addon message functions; everything else goes through it.
local COMM_ONLY = { "SendAddonMessage", "SendCommMessage" }

local files = {}
-- ../YeahNahMateDev: the author's private developer console (not in this repo); checked the same way
-- when it's there, skipped when it isn't.
for _, dir in ipairs({ "YeahNahMate", "../YeahNahMateDev/YeahNahMateDev" }) do
    for _, f in ipairs(listLua(dir)) do
        if not f:find("/libs/", 1, true) then files[#files + 1] = f end
    end
end
check(#files > 0, #files .. " source files checked")

local bad = 0
for _, f in ipairs(files) do
    local s = read(f)
    -- Strip comments so the rules can be explained in comments.
    local code = s:gsub("%-%-%[%[.-%]%]", ""):gsub("%-%-[^\n]*", "")
    for _, rule in ipairs(FORBIDDEN) do
        if code:find(rule[1], 1, true) then
            check(false, f .. " uses " .. rule[1] .. ": " .. rule[2]); bad = bad + 1
        end
    end
    if not f:match("/Comm%.lua$") then
        for _, w in ipairs(COMM_ONLY) do
            if code:find(w, 1, true) then
                check(false, f .. " uses " .. w .. " (only Comm.lua may)"); bad = bad + 1
            end
        end
    end
    -- Chat: only the whisper box (UI/Whisper.lua) sends, only as WHISPER, and only after the player
    -- presses Enter or Send. Anywhere else the name may only appear inside a string (the probe).
    local bare = code:gsub('"[^"\n]*"', '""')
    if f:match("/UI/Whisper%.lua$") then
        for args in code:gmatch("SendChatMessage%(([^)]*)%)") do
            if not args:find('"WHISPER"', 1, true) then
                check(false, f .. " sends chat that isn't a whisper"); bad = bad + 1
            end
        end
    elseif f:match("/Probe%.lua$") then
        -- Phase 9 probe: /ynm dev msprobe chat posts one GUILD test line from a timer,
        -- only when the developer types it. Nothing else in the probe sends chat.
        local n = select(2, bare:gsub("SendChatMessage", ""))
        if n > 2 or not code:find('L.MSPROBE_CHAT_LINE, "GUILD"', 1, true) then
            check(false, f .. ": the probe may only send its one GUILD test line"); bad = bad + 1
        end
    elseif f:match("/Milestones%.lua$") then
        -- Phase 9: milestone posts are the one no-click guild chat line. Only through
        -- Post(), only "GUILD", and every line starts with the [Yeah Nah Mate] tag (MS.Fire).
        local n = select(2, bare:gsub("SendChatMessage", ""))
        if n > 2 or not code:find('pcall(send, text, "GUILD")', 1, true) or select(2, code:gsub("Post%(line%)", "")) ~= 2
            or select(2, code:gsub("local line = %(MS%.TAG %.%. filled%)", "")) ~= 2 then
            check(false, f .. ": milestones may only post tagged GUILD lines through Post()"); bad = bad + 1
        end
    elseif bare:find("SendChatMessage", 1, true) then
        check(false, f .. " uses SendChatMessage: only the whisper box may, after the player's own click"); bad = bad + 1
    end
    for _, w in ipairs({ "ChatFrame_OpenChat", "ChatFrame_SendTell", "ChatFrameUtil", "ChatEdit_" }) do
        if bare:find(w, 1, true) then
            check(false, f .. " uses " .. w .. ": opening the game's chat box taints what the player types next"); bad = bad + 1
        end
    end
    if code:find('"CHANNEL"', 1, true) then
        check(false, f .. " sends on a chat channel (Forever never delivers those)"); bad = bad + 1
    end
    if s:find("\r", 1, true) then
        check(false, f .. " has Windows line endings (keep LF)"); bad = bad + 1
    end
end
check(bad == 0, "no forbidden calls in our code")

-- The .toc lists only files that exist, and every one of our .lua files is listed.
local toc = read("YeahNahMate/YeahNahMate.toc")
check(toc:find("## Interface: 16001", 1, true) ~= nil, "toc targets Forever (16001)")
local listed = {}
for line in toc:gmatch("[^\n]+") do
    line = line:gsub("\r", "")
    if not line:match("^#") and line:match("%S") then
        local path = "YeahNahMate/" .. line:gsub("\\", "/")
        listed[path] = true
        local f = io.open(path, "rb")
        check(f ~= nil, "toc file exists: " .. line)
        if f then f:close() end
    end
end
for _, f in ipairs(files) do
    if f:match("^YeahNahMate/") then
        check(listed[f] == true, "listed in the toc: " .. f)
    end
end

-- Every L.KEY our code uses exists in Strings.lua (a missing one shows the raw key in game).
local strings = read("YeahNahMate/Strings.lua")
local defined = {}
for k in strings:gmatch("\nL%.([%w_]+)%s*=") do defined[k] = true end
local missing = {}
for _, f in ipairs(files) do
    if f:match("^YeahNahMate/") and not f:match("Strings%.lua$") then
        local code = read(f):gsub("%-%-[^\n]*", "")
        for k in code:gmatch("L%.([%u][%w_]+)") do
            if not defined[k] and not missing[k] then missing[k] = f end
        end
    end
end
local n = 0
for k, f in pairs(missing) do check(false, "missing string L." .. k .. " (used in " .. f .. ")"); n = n + 1 end
check(n == 0, "every string the UI uses is defined")

