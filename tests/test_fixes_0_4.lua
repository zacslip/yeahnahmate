-- Fixes from the code review of 0.4.0 (Nov 2026), one block per bug: keys after combat, bad recipe lists,
-- copies vs the owner, the recipe index size, roster reads, positions on log-in.
math.randomseed(5)
YeahNahMateDB = nil
local ns = LoadAddon("YeahNahMate", "YeahNahMate")
LOGGED_IN = true
FireEvent("PLAYER_LOGIN")
local Ser = LibStub("AceSerializer-3.0")
local function Msg(t) return Ser:Serialize(t) end
local function Sent(t, from, filter)
    local list = {}
    for i = (from or 1), #SENT do
        local ok, m = Ser:Deserialize(SENT[i].text)
        if ok and type(m) == "table" and m.t == t and (not filter or filter(m, SENT[i])) then
            m._target = SENT[i].target; m._channel = SENT[i].channel; m._size = #SENT[i].text
            list[#list + 1] = m
        end
    end
    return list
end
ns.settings.sharePosition, ns.settings.shareProfessions = true, true
INJECT("YNM", Msg({ v = 1, t = "HI", ver = "0.4.0" }), "GUILD", "Bluey Heeler")
Tick(15)

-- 1. Escape out of combat, then the window opened in combat must not eat keys.
ns.UI.Open()
local win = _G.YeahNahMateFrame
win._scripts.OnKeyDown(win, "ESCAPE")
check(not win:IsShown() and win._propagate == false, "Escape: that press doesn't reach the game")
Tick(0.2)
check(win._propagate == true, "after hiding, keys pass through again")
FAKE.combat = true
ns.UI.Open()
check(win:IsShown() and win._propagate == true, "opened in combat: keys still reach the game")
win._scripts.OnKeyDown(win, "ESCAPE")
FAKE.combat = false
Tick(0.2)

-- 4. A malformed recipe list never raises an error.
INJECT("YNM", Msg({ v = 1, t = "PROF", pv = 10, p = { [171] = 5 } }), "GUILD", "Bingo Heeler")
INJECT("YNM", Msg({ v = 1, t = "PROF", pv = 10, p = { [171] = { i = 7 } } }), "GUILD", "Bingo Heeler")
Tick(1)
check(#ERRORS == 0, "malformed recipe lists dropped quietly (" .. (ERRORS[1] or "none") .. ")")

-- 3. A copy can't take over: versions from the future are refused; the owner's own list beats a copy.
local store = ns.Prof.Store()
local now = GetServerTime()
INJECT("YNM", Msg({ v = 1, t = "PROF", pv = now - 100, p = { [171] = { r = 1, m = 1, i = { 2330 } } } }), "GUILD", "Chilli Heeler")
Tick(1)
-- Ask Bluey for copies so a copy is allowed at all.
INJECT("YNM", Msg({ v = 1, t = "IDX", l = {} }), "WHISPER", "Bluey Heeler")
ns.Prof._asked = true
local askedBefore = #SENT
Tick(20)                                         -- 30 s after login we ask Bluey for the index
INJECT("YNM", Msg({ v = 1, t = "PROF", o = "Chilli Heeler", pv = 9e9, p = false }), "WHISPER", "Bluey Heeler")
Tick(1)
check(store["Chilli Heeler"] and not store["Chilli Heeler"].off, "a copy from the future is refused")
INJECT("YNM", Msg({ v = 1, t = "PROF", o = "Bandit Heeler", pv = now, p = false }), "WHISPER", "Bluey Heeler")
Tick(1)
check(store["Bandit Heeler"] and store["Bandit Heeler"].off and not store["Bandit Heeler"].direct, "a copy is taken when it's all we have")
INJECT("YNM", Msg({ v = 1, t = "PROF", pv = now, p = { [164] = { r = 50, m = 75, i = { 2662 } } } }), "GUILD", "Bandit Heeler")
Tick(1)
check(store["Bandit Heeler"].direct and store["Bandit Heeler"].p, "the owner's own list beats a copy, even one with a later version")

-- 8. The index answer fits in one message even with hundreds of lists.
for i = 1, 300 do store["Member Number" .. i] = { pv = now - i, p = {} } end
for i = 1, 300 do FAKE.roster[#FAKE.roster + 1] = { "Member Number" .. i, "Member", 3, 20, "Mage", "Durotar", "", "", false, 0, "MAGE" } end
ns.Guild.Scan()
local before = #SENT
INJECT("YNM", Msg({ v = 1, t = "REQ", w = "IDX" }), "WHISPER", "Chilli Heeler")
Tick(60)
-- (Long messages go out in pieces, so read the log line rather than the raw pieces.)
local sentIdx = false
for _, line in ipairs(ns.GetLog()) do
    if line:find("sent my list index (200 recipe lists) to Chilli Heeler", 1, true) then sentIdx = true end
    if line:find("not sent, too big", 1, true) then sentIdx = false end
end
check(sentIdx, "index answer sent with the newest 200 lists, under the size limit")

-- 2. After an index, at most 30 copies are asked for (newest first), in batches of 10.
local l = {}
for i = 1, 100 do l["Member Number" .. i] = now + 100 - i end
before = #SENT
-- (Bluey was asked for the index 30 s after login, above.)
INJECT("YNM", Msg({ v = 1, t = "IDX", l = l }), "WHISPER", "Bluey Heeler")
Tick(5)
local reqs = Sent("REQ", before + 1, function(m) return m.w == "PROFS" end)
local names = 0
for _, r in ipairs(reqs) do names = names + #r.n end
check(#reqs == 3 and names == 30, "asked for 30 copies in 3 requests (" .. #reqs .. ", " .. names .. ")")
local hasNewest = false
for _, r in ipairs(reqs) do for _, nm in ipairs(r.n) do if nm == "Member Number1" then hasNewest = true end end end
check(hasNewest, "the newest lists asked for first")

-- 5. A roster read that misses people (a hidden name) doesn't forget them.
local g = YeahNahMateDB.guilds["The Good Sorts"]
g.users["Bandit Heeler"] = { ver = "0.4.0", seen = 1 }
local saved = FAKE.roster[5][1]
FAKE.roster[5][1] = nil                          -- the game hid this name
ns.Guild.Scan()
check(not ns.Guild.complete, "the read is marked incomplete")
check(g.users["Bandit Heeler"] ~= nil and store["Bandit Heeler"] ~= nil, "Bandit's tick and recipes are kept")
FAKE.roster[5][1] = saved
ns.Guild.Scan()
check(ns.Guild.complete, "a full read is complete again")

-- 10. A burst of roster events makes one scan.
local scans = 0
ns.Listen("ROSTER", function() scans = scans + 1 end)
for i = 1, 20 do FireEvent("GUILD_ROSTER_UPDATE") end
Tick(2)
check(scans == 1, "20 roster events, 1 scan (" .. scans .. ")")

-- 7. A hello reply (no ask) sends no position; a log-in hello gets one position whispered to that
-- guildie only, never a guild broadcast (0.8.6: with the whole guild on the addon, a broadcast per
-- log-in was 250 broadcasts).
FAKE.x = 0.5
Tick(70)                                         -- a keep-alive goes out
before = #SENT
INJECT("YNM", Msg({ v = 1, t = "HI", ver = "0.4.0" }), "WHISPER", "Bluey Heeler")
Tick(6)
check(#Sent("POS", before + 1) == 0, "a hello reply doesn't trigger a position")
INJECT("YNM", Msg({ v = 1, t = "HI", ver = "0.4.0", ask = true }), "GUILD", "Chilli Heeler")
INJECT("YNM", Msg({ v = 1, t = "HI", ver = "0.4.0", ask = true }), "GUILD", "Bingo Heeler")
Tick(6)
Tick(4)
local pos = Sent("POS", before + 1)
local toGuild, to = 0, {}
for _, m in ipairs(pos) do
    if m._channel == "GUILD" then toGuild = toGuild + 1 else to[m._target] = (to[m._target] or 0) + 1 end
end
check(toGuild == 0, "two logins: no position broadcast (" .. toGuild .. ")")
check(to["Chilli Heeler"] == 1 and to["Bingo Heeler"] == 1, "each newcomer is whispered my position once")

-- 6. (Minimap texture paths) is covered by test_escapes.lua.

check(#ERRORS == 0, "no errors (" .. (ERRORS[1] or "none") .. ")")
