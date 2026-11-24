-- Roll probe: can the clan roll (0.28.0) be built on Forever? Dev only: the CurseForge build leaves
-- all of this out (BigWigs packager's do-not-package markers); a copy installed from source keeps it.
--
-- /ynm dev rollprobe on      watches every line that looks like a roll: real game roll lines (system)
--                            and look-alikes typed in say, party, raid, emote, yell or a whisper. Each
--                            gets the verdict the clan roll would give it: counts, wrong range,
--                            repeat, or a fake (player chat, not the game). Stays on after /reload.
-- /ynm dev rollprobe off     stops watching.
-- /ynm dev rollprobe round   starts a new round: everyone's next roll counts again.
-- /ynm dev rollprobe post    one click: a test line to party or raid chat AND a test whisper to the
--                            last person who rolled (or a group member, or me). Only from a click.
-- /ynm dev rollprobe timer   a test line to party or raid chat 10 s later, with no click (the
--                            "Roll over" line the clan roll would post when its timer ends).
-- /ynm dev rollprobe plates  a test die and number over each group member's nameplate for 15 s.
--
-- Answers go to YeahNahMateDB.rollprobe (saved at /reload). The saved rows keep the shape of a
-- roller's name (two words, a realm), never the name itself; chat on my own screen shows the line.
local ADDON, ns = ...

--@do-not-package@
local MAX_ROWS = 60
local TEST_LINE = "[Yeah Nah Mate] Roll test, please ignore."
local TEST_WHISPER = "[Yeah Nah Mate] Roll test whisper, please ignore."
local TIMER_LINE = "[Yeah Nah Mate] Roll over test (no click), please ignore."
local DIE = "Interface\\Buttons\\UI-GroupLoot-Dice-Up"

ns.RollProbe = {}
local P = ns.RollProbe

local function Secret(v) return issecretvalue and issecretvalue(v) or false end
local function Readable(v) return type(v) == "string" and not Secret(v) end

local function Store()
    YeahNahMateDB.rollprobe = YeahNahMateDB.rollprobe or {}
    local s = YeahNahMateDB.rollprobe
    s.checks = s.checks or {}
    s.rows = s.rows or {}
    return s
end

local function Where()
    local inInst, kind = false, nil
    if IsInInstance then inInst, kind = IsInInstance() end
    local fight = InCombatLockdown and InCombatLockdown() or false
    if fight then return "fight" end
    if inInst and not Secret(inInst) then return "instance:" .. tostring(kind) end
    return (IsResting and IsResting()) and "town" or "world"
end

local function GroupKind()
    if IsInRaid and IsInRaid() then return "raid" end
    if IsInGroup and IsInGroup() then return "party" end
    return "solo"
end

---------------------------------------------------------------------------------------------------
-- Reading a roll line

-- The game's own roll line ("%s rolls %d (%d-%d)") turned into a pattern: name, roll, low, high.
function P.Pattern(fmt)
    fmt = fmt or RANDOM_ROLL_RESULT
    if not Readable(fmt) then return nil end
    local p = fmt:gsub("[%(%)%.%+%-%*%?%[%]%^]", "%%%0")
    p = p:gsub("%%%d?%$?s", "(.+)"):gsub("%%%d?%$?d", "(%%d+)")
    return "^" .. p .. "$"
end

-- name, roll, low, high from a game roll line, or nil.
function P.Parse(text)
    if not Readable(text) then return nil end
    local pat = P.Pattern()
    if not pat then return nil end
    local name, roll, lo, hi = text:match(pat)
    if not name then return nil end
    return name, tonumber(roll), tonumber(lo), tonumber(hi)
end

-- Colour codes, links and textures out; what's left, and whether anything was taken out.
function P.Clean(text)
    local s = text:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):gsub("|H.-|h(.-)|h", "%1"):gsub("|T.-|t", ""):gsub("|", "")
    return s, s ~= text
end

-- Does typed chat look like a roll line? (Someone trying to fake one.)
local function LooksLikeRoll(text)
    local s = P.Clean(text):lower()
    return s:find("rolls?%s+%d+") ~= nil or s:find("%(%s*%d+%s*%-%s*%d+%s*%)") ~= nil
end

-- What a name looks like, without keeping it: "2 words", "1 word, realm" ...
local function Shape(name)
    local words = select(2, name:gsub("%S+", ""))
    return words .. (words == 1 and " word" or " words") .. (name:find("-", 1, true) and ", realm" or "")
end

-- The group unit for a name ("party2", "raid7", "player"), or nil if they're not in my group.
function P.UnitFor(name)
    local key = ns.Key(name)
    if key == ns.me then return "player" end
    local raid = IsInRaid and IsInRaid()
    local n = GetNumGroupMembers and GetNumGroupMembers() or 0
    for i = 1, (raid and n or math.max(0, n - 1)) do
        local unit = (raid and "raid" or "party") .. i
        if ns.UnitKey(unit) == key then return unit end
    end
    return nil
end

---------------------------------------------------------------------------------------------------
-- Nameplate markers: a die and a number over a group member's nameplate (our own frame)

local marks, free = {}, {}

local function Unmark(unit)
    local m = marks[unit]
    if m then m:Hide(); m:ClearAllPoints(); free[#free + 1] = m; marks[unit] = nil end
end

-- A group member's nameplate. Forever refuses GetNamePlateForUnit("party1") with an error ("Raid/Party
-- unit tokens are not allowed"), so the nameplates on screen (nameplate1-40, as UI/Nameplates.lua uses)
-- are matched by name. Returns the plate and how it was found, or nil.
local function PlateFor(unit)
    local get = C_NamePlate and C_NamePlate.GetNamePlateForUnit
    if not get then return nil end
    local key = ns.UnitKey(unit)
    if not key then return nil end
    for i = 1, 40 do
        local np = "nameplate" .. i
        if ns.UnitKey(np) == key then
            local plate = get(np)
            if plate then return plate, "by name" end
        end
    end
    return nil
end

-- Returns "shown (how)", "no plate" (not on screen, or friendly plates off), "forbidden" or "me".
local function Mark(unit, number, secs)
    if unit == "player" then return "me" end
    local plate, how = PlateFor(unit)
    if not plate then return "no plate" end
    if plate.IsForbidden and plate:IsForbidden() then return "forbidden" end
    Unmark(unit)
    local f = table.remove(free) or CreateFrame("Frame", nil, UIParent)
    f:SetSize(40, 22)
    if not f.tex then
        f.tex = f:CreateTexture(nil, "OVERLAY")
        f.tex:SetSize(20, 20)
        f.tex:SetPoint("LEFT")
        f.tex:SetTexture(DIE)
        f.num = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
        f.num:SetPoint("LEFT", f.tex, "RIGHT", 2, 0)
    end
    f.num:SetText(tostring(number))
    f:ClearAllPoints()
    f:SetPoint("BOTTOM", plate, "TOP", 0, 4)
    f:Show()
    marks[unit] = f
    f.token = (f.token or 0) + 1
    local token = f.token
    C_Timer.After(secs or 20, function() if marks[unit] == f and f.token == token then Unmark(unit) end end)
    return "shown (" .. how .. ")"
end

-- Mark, but a nameplate problem is noted ("error: ...") instead of stopping the roll being recorded.
local function TryMark(unit, number, secs)
    local ok, res = pcall(Mark, unit, number, secs)
    if ok then return res end
    return "error: " .. tostring(res):gsub("^.-:%d+: ", ""):sub(1, 80)
end

local function Count(t, k) t[k] = (t[k] or 0) + 1 end

---------------------------------------------------------------------------------------------------
-- Watching

local seen = {}               -- this round: key -> first roll
local echo = nil              -- { line, kind, check }: our own test line, to hear it come back
local lastRoller = nil        -- the last other group member whose roll counted (the test whisper goes there)

local function AddRow(row)
    local s = Store()
    row.at = date("%H:%M:%S")
    row.where = Where()
    row.group = GroupKind()
    s.rows[#s.rows + 1] = row
    while #s.rows > MAX_ROWS do table.remove(s.rows, 1) end
    ns.Fire("ROLLPROBE")
end

local function Check(name, value)
    Store().checks[name] = value
    ns.Fire("ROLLPROBE")
end

local function OnSystem(text)
    if not Readable(text) then
        Count(Store(), "secretLines")
        if Secret(text) then Check("read_" .. GroupKind(), "FAIL: system lines come back secret (" .. Where() .. ")") end
        return
    end
    local name, roll, lo, hi = P.Parse(text)
    if not name then
        -- A roll line the game's own pattern didn't read: the clan roll would miss it.
        local clean = P.Clean(text)
        if clean:find(" rolls ", 1, true) and clean:find("%(%d+%-%d+%)") then
            Check("pattern", "FAIL: a roll line didn't match the game's pattern")
            ns.Print("Roll probe: " .. clean .. " |cffff6060(didn't match RANDOM_ROLL_RESULT)|r")
        end
        return
    end
    local key = ns.Key(name)
    local unit = P.UnitFor(name)
    local row = { kind = "game roll", shape = Shape(name), roll = roll, range = lo .. "-" .. hi,
        me = key == ns.me, inGroup = unit ~= nil }
    if lo ~= 1 or hi ~= 100 then
        row.verdict = "ignored: range " .. lo .. "-" .. hi
    elseif seen[key] then
        row.verdict = "ignored: repeat (first was " .. seen[key] .. ")"
    else
        seen[key] = roll
        row.verdict = "counts"
        if unit then row.plate = TryMark(unit, roll, 20) end
        if unit and unit ~= "player" then lastRoller = name end
    end
    AddRow(row)
    if not row.me then
        Check("read_" .. row.group, "PASS (" .. row.where .. ")")
    end
    if name:find(" ", 1, true) then Check("surname", "PASS: the line has First Surname (" .. row.shape .. ")") end
    Check("pattern", Store().checks.pattern or "PASS")
    if row.plate then
        local s = Store()
        s.plates = s.plates or {}
        Count(s.plates, row.plate)
    end
    ns.Print("Roll probe: " .. text .. "  ->  " .. (row.verdict == "counts" and "|cff40ff40counts|r" or ("|cffff9020" .. row.verdict .. "|r"))
        .. (row.plate and (", nameplate: " .. row.plate) or ""))
end

local function OnTyped(event, text, sender)
    if not Readable(text) then return end
    -- Our own test lines coming back: they reached chat.
    if echo and text == echo.line and Readable(sender) and ns.Key(sender) == ns.me then
        Check(echo.check, "PASS: seen in " .. echo.kind .. " chat")
        echo = nil
        return
    end
    if event == "CHAT_MSG_WHISPER_INFORM" then
        if text == TEST_WHISPER then Check("whisper", "PASS: whisper went") end
        return
    end
    if not LooksLikeRoll(text) then return end
    local clean, had = P.Clean(text)
    local channel = event:gsub("^CHAT_MSG_", ""):gsub("_LEADER$", ""):lower()
    AddRow({ kind = channel, verdict = "ignored: typed in " .. channel .. ", not a game roll", codes = had or nil,
        me = Readable(sender) and ns.Key(sender) == ns.me or false })
    local s = Store()
    s.fakes = s.fakes or {}
    Count(s.fakes, channel)
    ns.Print("Roll probe: fake in " .. channel .. ": " .. clean .. "  ->  |cffff9020ignored|r" .. (had and " (colour codes or links taken out)" or ""))
end

local TYPED = { "CHAT_MSG_SAY", "CHAT_MSG_YELL", "CHAT_MSG_EMOTE", "CHAT_MSG_TEXT_EMOTE", "CHAT_MSG_PARTY",
    "CHAT_MSG_PARTY_LEADER", "CHAT_MSG_RAID", "CHAT_MSG_RAID_LEADER", "CHAT_MSG_WHISPER", "CHAT_MSG_WHISPER_INFORM" }

local hooked = false
local function Hook()
    if hooked then return end
    hooked = true
    -- ns.OnEvent handlers get the event's arguments without its name. Registered once, for good:
    -- they do nothing while the probe is off.
    ns.OnEvent("CHAT_MSG_SYSTEM", function(text)
        if YeahNahMateDB.rollprobe and YeahNahMateDB.rollprobe.watch then OnSystem(text) end
    end)
    for _, e in ipairs(TYPED) do
        ns.OnEvent(e, function(text, sender)
            if YeahNahMateDB.rollprobe and YeahNahMateDB.rollprobe.watch then OnTyped(e, text, sender) end
        end)
    end
end

---------------------------------------------------------------------------------------------------
-- Sending (the only chat this file sends, all from the developer's own click or command)

local function Channel()
    if IsInRaid and IsInRaid() then return "RAID" end
    if IsInGroup and IsInGroup() then return "PARTY" end
    return nil
end

local function Sender()
    if C_ChatInfo and C_ChatInfo.InChatMessagingLockdown and C_ChatInfo.InChatMessagingLockdown() then return nil, "chat locked" end
    local send = (C_ChatInfo and C_ChatInfo.SendChatMessage) or SendChatMessage
    if not send then return nil, "no send function" end
    return send
end

-- Who the test whisper goes to: the last other person who rolled, else a group member, else me.
local function WhisperTarget()
    if lastRoller and P.UnitFor(lastRoller) then return lastRoller end
    local raid = IsInRaid and IsInRaid()
    local n = GetNumGroupMembers and GetNumGroupMembers() or 0
    for i = 1, (raid and n or n - 1) do
        local unit = (raid and "raid" or "party") .. i
        local k = ns.UnitKey(unit)
        if k and k ~= ns.me then return k end
    end
    return ns.me
end

-- One click: the group line and the whisper.
function P.Post()
    Store().watch = true
    Hook()
    local chan = Channel()
    if not chan then Check("post", "not run: join a party or raid first") return end
    local send, why = Sender()
    if not send then Check("post", "FAIL: " .. why) return end
    local ok, err = pcall(send, TEST_LINE, chan)
    Check("post", ok and ("sent to " .. chan:lower() .. ", waiting to see it in chat") or ("FAIL: " .. tostring(err)))
    if ok then echo = { line = TEST_LINE, kind = chan:lower(), check = "post" } end
    local who = WhisperTarget()
    local ok2, err2 = pcall(send, TEST_WHISPER, "WHISPER", nil, who)
    Check("whisper", ok2 and ("sent to " .. tostring(who) .. ", waiting") or ("FAIL: " .. tostring(err2)))
end

-- No click: the "Roll over" line, 10 s later.
function P.Timer()
    Store().watch = true
    Hook()
    if not Channel() then Check("timer", "not run: join a party or raid first") return end
    Check("timer", "posting in 10 s ...")
    C_Timer.After(10, function()
        ns.Safe(function()
            local chan = Channel()
            if not chan then Check("timer", "not run: left the group") return end
            local send, why = Sender()
            if not send then Check("timer", "FAIL: " .. why) return end
            local ok, err = pcall(send, TIMER_LINE, chan)
            Check("timer", ok and ("sent to " .. chan:lower() .. " with no click, waiting to see it in chat") or ("FAIL: " .. tostring(err)))
            if ok then echo = { line = TIMER_LINE, kind = chan:lower(), check = "timer" } end
        end)
    end)
end

-- A test die and number over every group member's nameplate.
function P.Plates()
    local n = GetNumGroupMembers and GetNumGroupMembers() or 0
    if n == 0 then Check("plates", "not run: join a party or raid first") return end
    local raid = IsInRaid and IsInRaid()
    local got = {}
    for i = 1, (raid and n or n - 1) do
        local unit = (raid and "raid" or "party") .. i
        Count(got, TryMark(unit, math.random(1, 100), 15))
    end
    local parts = {}
    for k, v in pairs(got) do parts[#parts + 1] = k .. " " .. v end
    table.sort(parts)
    local shown = 0
    for k, v in pairs(got) do if k:find("^shown") then shown = shown + v end end
    Check("plates", (shown > 0 and "PASS: " or "FAIL: ") .. table.concat(parts, ", ")
        .. (shown == 0 and " (friendly nameplates on? ctrl+V; stand near them)" or ""))
end

function P.Round()
    seen = {}
    for unit in pairs(marks) do Unmark(unit) end
    ns.Fire("ROLLPROBE")
end

---------------------------------------------------------------------------------------------------
-- Results, for the console and chat

local CHECKS = {
    { "read_party", "Read a party member's /roll" },
    { "read_raid", "Read a raid member's /roll" },
    { "surname", "Surname in the roll line" },
    { "pattern", "Game's roll pattern matches" },
    { "post", "Click: post to group chat" },
    { "whisper", "Same click: whisper" },
    { "timer", "No click: Roll over line" },
    { "plates", "Die over a nameplate" },
}

function P.Lines()
    local s = YeahNahMateDB and YeahNahMateDB.rollprobe
    local out = {}
    for _, c in ipairs(CHECKS) do
        local v = s and s.checks and s.checks[c[1]]
        local col = not v and "|cff9d9d9d" or (v:find("^PASS") and "|cff40ff40" or (v:find("^FAIL") and "|cffff6060" or "|cffffffff"))
        out[#out + 1] = c[2] .. ": " .. col .. (v or "not yet") .. "|r"
    end
    local fakes = {}
    for k, v in pairs(s and s.fakes or {}) do fakes[#fakes + 1] = k .. " " .. v end
    table.sort(fakes)
    out[#out + 1] = "Fakes caught: " .. (#fakes > 0 and table.concat(fakes, ", ") or "none yet")
    return out
end

-- The last few verdicts, newest first.
function P.Recent(n)
    local s = YeahNahMateDB and YeahNahMateDB.rollprobe
    local rows, out = s and s.rows or {}, {}
    for i = #rows, math.max(1, #rows - (n or 5) + 1), -1 do
        local r = rows[i]
        out[#out + 1] = r.at .. " " .. r.kind .. (r.roll and (" " .. r.roll .. " (" .. r.range .. ")") or "")
            .. (r.me and " (me)" or "") .. ": " .. r.verdict
    end
    return out
end

ns.devCommands.rollprobe = function(arg)
    local s = Store()
    s.version = ns.VERSION
    s.pattern = P.Pattern() or "RANDOM_ROLL_RESULT unreadable"
    if arg == "off" then
        s.watch = false
        P.Round()
        ns.Print("Roll probe off. /reload saves the results.")
    elseif arg == "round" then
        P.Round()
        ns.Print("Roll probe: new round, everyone's next /roll counts.")
    elseif arg == "post" then
        ns.Safe(P.Post)
    elseif arg == "timer" then
        ns.Safe(P.Timer)
    elseif arg == "plates" then
        ns.Safe(P.Plates)
    else
        s.watch = true
        Hook()
        P.Round()
        ns.Print("Roll probe on: /roll, and have a group member /roll and try fakes. /ynm dev rollprobe off stops it.")
    end
end

ns.Listen("LOGIN", function()
    if YeahNahMateDB and YeahNahMateDB.rollprobe and YeahNahMateDB.rollprobe.watch then Hook() end
end)
--@end-do-not-package@
