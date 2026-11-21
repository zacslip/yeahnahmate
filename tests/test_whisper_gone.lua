-- A guildie logs off while we're whispering them: no "No player named" spam (Comm.lua).
ERR_CHAT_PLAYER_NOT_FOUND_S = "No player named '%s' is currently playing."
local filters = {}
ChatFrame_AddMessageEventFilter = function(event, fn) filters[event] = fn end

YeahNahMateDB = nil
local ns = LoadAddon("YeahNahMate", "YeahNahMate")
LOGGED_IN = true
FireEvent("PLAYER_LOGIN")
Tick(20)
local Comm = ns.Comm
local Ser = LibStub("AceSerializer-3.0")

local members = {}
local function Add(name) members[name] = { name = name, online = true }; return members[name] end
local realGet, realIs = ns.Guild.Get, ns.Guild.IsMember
ns.Guild.Get = function(n) return members[n] or realGet(n) end
ns.Guild.IsMember = function(n) return members[n] ~= nil or realIs(n) end

local function ToThem(name, from)
    local n = 0
    for i = (from or 0) + 1, #SENT do
        if SENT[i].channel == "WHISPER" and SENT[i].target == name then n = n + 1 end
    end
    return n
end
local function Line(name) return string.format(ERR_CHAT_PLAYER_NOT_FOUND_S, name) end
local function Big(i) return { t = "ZZ", n = "M" .. i .. "M", x = string.rep("x", 1500) } end
local function Hear(name)
    Comm.Receive(Ser:Serialize({ t = "ST", v = ns.PROTOCOL }), "GUILD", name)
end

-- 1. The roster says they've gone: nothing is sent.
local off = Add("Offline Olly")
off.online = false
local mark = #SENT
check(Comm.Send({ t = "ZZ" }, "WHISPER", "Offline Olly", "BULK") == false and ToThem("Offline Olly", mark) == 0, "offline on the roster: not sent")
check(Comm.quiet.skipped == 1, "and counted")

-- The roster can be old: someone we just heard from still gets their reply.
Hear("Offline Olly")
mark = #SENT
check(Comm.Send({ t = "ZZ" }, "WHISPER", "Offline Olly", "NORMAL") == true and ToThem("Offline Olly", mark) == 1, "just heard from them: the old roster is doubted")
Tick(25)
mark = #SENT
check(Comm.Send({ t = "ZZ" }, "WHISPER", "Offline Olly", "NORMAL") == false, "a while later the roster is believed")

-- 2. Long replies go one at a time, in order, and all arrive.
Add("Online Ollie")
mark = #SENT
for i = 1, 5 do Comm.Send(Big(i), "WHISPER", "Online Ollie", "BULK") end
Tick(40)
local order = {}
for i = mark + 1, #SENT do
    local n = SENT[i].target == "Online Ollie" and SENT[i].text:match("M(%d)M")
    if n then order[#order + 1] = n end
end
check(table.concat(order) == "12345", "every message arrives, in order (" .. table.concat(order) .. ")")
check(ToThem("Online Ollie", mark) >= 30, "with all their pieces (" .. ToThem("Online Ollie", mark) .. ")")

-- A short message isn't held behind a sync reply.
Add("Busy Bev")
Tick(5)
for i = 1, 5 do Comm.Send(Big(i), "WHISPER", "Busy Bev", "BULK") end
mark = #SENT
Comm.Send({ t = "ZZ", n = "NOWNOW" }, "WHISPER", "Busy Bev", "NORMAL")
Tick(0.3)
local quick = false
for i = mark + 1, #SENT do if SENT[i].text:find("NOWNOW", 1, true) then quick = true end end
check(quick, "a click's whisper goes straight out, ahead of the queue")
Tick(40)

-- 3. They log off mid-queue (the roster hasn't noticed): the first line stops the rest.
Add("Gone Gary")
Tick(5)
mark = #SENT
for i = 1, 5 do Comm.Send(Big(i), "WHISPER", "Gone Gary", "BULK") end
Tick(0.1)
local dropped = Comm.quiet.dropped
FireEvent("CHAT_MSG_SYSTEM", Line("Gone Gary"))
local atLine = #SENT
check(Comm.quiet.dropped > dropped, "the line drops their queue (" .. (Comm.quiet.dropped - dropped) .. ")")
Tick(30)
check(ToThem("Gone Gary", atLine) <= 7, "only the message already under way finishes (" .. ToThem("Gone Gary", atLine) .. " pieces)")
check(ToThem("Gone Gary", mark) < ToThem("Online Ollie"), "less than the whole queue (" .. ToThem("Gone Gary", mark) .. " of " .. ToThem("Online Ollie") .. ")")
check(Comm.Send({ t = "ZZ" }, "WHISPER", "Gone Gary", "NORMAL") == false, "nothing more goes to them while they're held")

-- Held for a bit, and back as soon as they're heard from.
Add("Back Barry")
Comm.Send({ t = "ZZ" }, "WHISPER", "Back Barry", "NORMAL")
FireEvent("CHAT_MSG_SYSTEM", Line("Back Barry"))
check(Comm.Send({ t = "ZZ" }, "WHISPER", "Back Barry", "NORMAL") == false, "after the line: held")
Hear("Back Barry")
check(Comm.Send({ t = "ZZ" }, "WHISPER", "Back Barry", "NORMAL") == true, "they log back in and say hello: straight back")
FireEvent("CHAT_MSG_SYSTEM", Line("Back Barry"))
Tick(31)
check(Comm.Reachable("Back Barry"), "the hold wears off by itself")

-- 4. The chat filter.
local F = filters.CHAT_MSG_SYSTEM
check(type(F) == "function", "a filter on system lines")
Add("Filter Fay")
Comm.Send({ t = "ZZ" }, "WHISPER", "Filter Fay", "NORMAL")
Tick(1)
check(F(nil, "CHAT_MSG_SYSTEM", Line("Filter Fay")) == true, "the line for someone we just whispered is hidden")
check(F(nil, "CHAT_MSG_SYSTEM", Line("Never Whispered")) == false, "a name the addon didn't whisper still shows")
check(F(nil, "CHAT_MSG_SYSTEM", "You have learned a new spell.") == false, "other lines still show")
Tick(6)
check(F(nil, "CHAT_MSG_SYSTEM", Line("Filter Fay")) == false, "a few seconds later it shows again")

-- The player's own whisper box still gets told.
Comm.Send({ t = "ZZ" }, "WHISPER", "Filter Fay", "NORMAL")
Tick(0.5)
ns.Fire("WHISPERED", "Filter Fay", "hello")
check(F(nil, "CHAT_MSG_SYSTEM", Line("Filter Fay")) == false, "after my own whisper the line shows")
Tick(6)

-- A secret line is never read.
local realSecret = issecretvalue
issecretvalue = function(v) return v == "SECRET" end
check(F(nil, "CHAT_MSG_SYSTEM", "SECRET") == false, "a secret value: left alone")
FireEvent("CHAT_MSG_SYSTEM", "SECRET")
issecretvalue = realSecret

-- With the gamepad UI, chat is left alone.
Enum.InputDeviceInterfaceType = { Gamepad = 1, KeyboardAndMouse = 0 }
C_InputInterfaceStyle = { GetCurrentStyle = function() return 1 end }
Comm.Send({ t = "ZZ" }, "WHISPER", "Filter Fay", "NORMAL")
check(F(nil, "CHAT_MSG_SYSTEM", Line("Filter Fay")) == false, "gamepad UI: the line shows")
C_InputInterfaceStyle = nil

-- 5. A message that never reports finishing can't block the rest.
Add("Stuck Stu")
Tick(6)
local realSendComm = Comm.SendCommMessage
local calls = 0
Comm.SendCommMessage = function() calls = calls + 1 end
for i = 1, 2 do Comm.Send({ t = "ZZ", n = i }, "WHISPER", "Stuck Stu", "BULK") end
check(calls == 1, "one at a time")
Tick(25)
check(calls == 2, "if one never finishes, the next goes anyway")
Comm.SendCommMessage = realSendComm

-- A very long queue doesn't run out of stack when the library calls back at once.
Add("Long Lena")
local instant = 0
Comm.SendCommMessage = function(_, _, text, _, _, _, cb) instant = instant + 1; cb(nil, #text, #text) end
for i = 1, 500 do Comm.Send({ t = "ZZ", n = i }, "WHISPER", "Long Lena", "BULK") end
Comm.SendCommMessage = realSendComm
check(instant == 500, "500 queued messages all go (" .. instant .. ")")

check(#ns.db.errors == 0, "no errors " .. tostring(ns.db.errors[1] and ns.db.errors[1].msg))
