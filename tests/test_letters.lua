-- Review fix (v0.17.2): text cut to a byte limit never ends in half a letter. Chat lines are 255 bytes,
-- and an accented letter or an emoji is 2-4 bytes; the game refuses a chat line with half a letter.
YeahNahMateDB = nil
local ns = LoadAddon("YeahNahMate", "YeahNahMate")
LOGGED_IN = true
FireEvent("PLAYER_LOGIN")
Tick(15)

-- Whole letters only: every lead byte is followed by all of its continuation bytes.
local function Whole(s)
    local i, n = 1, #s
    while i <= n do
        local c = s:byte(i)
        local len = c < 128 and 1 or (c >= 240 and 4) or (c >= 224 and 3) or (c >= 192 and 2) or nil
        if not len or i + len - 1 > n then return false end
        for j = i + 1, i + len - 1 do
            local b = s:byte(j)
            if b < 128 or b >= 192 then return false end
        end
        i = i + len
    end
    return true
end

local E = "\195\169"            -- é (2 bytes)
local EMOJI = "\240\159\152\128" -- a 4-byte emoji

-- 1. The helper.
local C = ns.CutBytes
check(C("abc", 5) == "abc" and C("abcdef", 3) == "abc", "plain text: cut at the limit")
check(C("caf" .. E, 4) == "caf" and C("caf" .. E, 5) == "caf" .. E, "an accented letter is kept whole or left out")
check(C("ab" .. EMOJI, 3) == "ab" and C("ab" .. EMOJI, 5) == "ab" and C("ab" .. EMOJI, 6) == "ab" .. EMOJI, "an emoji is kept whole or left out")
check(C(E .. E, 1) == "" and C("", 3) == "", "nothing left is fine")

-- 2. A milestone line at the chat limit.
local MS = ns.Milestones
local w0 = #WHISPERS + 1
local card = { id = "t1", ty = "lvl", v = 10, m = string.rep(E, 120), gc = true }
MS.Fire(card, {}, nil, false)
Tick(1)
local line = WHISPERS[w0] and WHISPERS[w0].text
check(line ~= nil and #line <= 255 and Whole(line), "a long milestone line with accents is cut to whole letters (" .. tostring(line and #line) .. " bytes)")

-- 3. A calendar title at its limit (40 bytes).
local key = ns.Calendar.Save(nil, { title = string.rep("a", 39) .. E .. "zz", at = GetServerTime() + 3600, k = "s" })
local title = key and ns.Calendar.Store()[key].title
check(title ~= nil and #title <= 40 and Whole(title), "an event title with an accent at the limit keeps whole letters")

-- 4. The whisper box: a long whisper with emoji goes out whole; if the game refuses it, the box says
-- so and stays open (no Lua error).
local m = ns.Guild.Get("Bluey Heeler")
ns.Whisper.Open(m, string.rep(EMOJI, 70))
local box = YeahNahMateWhisper
local w1 = #WHISPERS + 1
box.edit:GetScript("OnEnterPressed")(box.edit)
local sent = WHISPERS[w1]
check(sent and sent.kind == "WHISPER" and #sent.text <= 255 and Whole(sent.text) and not box:IsShown(), "a long whisper with emoji goes out whole")

local real = C_ChatInfo.SendChatMessage
C_ChatInfo.SendChatMessage = function() error("refused") end
ns.Whisper.Open(m, "hello")
box.edit:GetScript("OnEnterPressed")(box.edit)
C_ChatInfo.SendChatMessage = real
check(box:IsShown() and box.edit:GetText() == "hello", "a refused whisper keeps the box open with the text")

check(#ERRORS == 0, "no errors (" .. tostring(ERRORS[1]) .. ")")
