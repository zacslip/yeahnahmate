-- Clan challenges and second in command: challenging for my own clan (not as its leader, one open at
-- a time), withdrawing (two clicks), results only from those who may settle (final, newest wins),
-- forged and wrong-clan messages dropped, copies after log-in, tidying; second in command given and
-- ended by a moderator (meeting buttons for them, ends by itself); the tab's swords, bar and
-- right-click menu; the dev command in sim mode.
math.randomseed(41)
YeahNahMateDB = nil
FAKE.myRank = 0                 -- I'm the guild master here (Ned Jones)
local ns = LoadAddon("YeahNahMate", "YeahNahMate")
LOGGED_IN = true
FireEvent("PLAYER_LOGIN")
local Ser = LibStub("AceSerializer-3.0")
local function Msg(t) return Ser:Serialize(t) end
local function Sent(t, from)
    local list = {}
    for i = (from or 1), #SENT do
        local ok, m = Ser:Deserialize(SENT[i].text)
        if ok and type(m) == "table" and m.t == t then m._target = SENT[i].target; m._channel = SENT[i].channel; list[#list + 1] = m end
    end
    return list
end
local X, Cl, CM, UI, L = ns.ClanChallenge, ns.Clans, ns.ClanMeet, ns.UI, ns.L
ns.settings.sharePosition, ns.settings.shareProfessions = false, false
function UnitRace() return "Orc", "Orc", 2 end
Tick(15)
INJECT("YNM", Msg({ v = 1, t = "HI", ver = ns.VERSION, ra = "Orc", ro = "t" }), "GUILD", "Bluey Heeler")
INJECT("YNM", Msg({ v = 1, t = "HI", ver = ns.VERSION, ra = "Orc", ro = "h" }), "GUILD", "Bingo Heeler")
INJECT("YNM", Msg({ v = 1, t = "HI", ver = ns.VERSION, ra = "Troll", ro = "d" }), "GUILD", "Chilli Heeler")
Tick(2)
local now = GetServerTime()

-- Bingo (a member, Orc) challenges.
INJECT("YNM", Msg({ v = 1, t = "CHG", id = now, r = "Orc", st = "o", at = now, ev = now }), "GUILD", "Bingo Heeler")
Tick(1)
local open = X.Open("Orc")
check(#open == 1 and open[1].owner == "Bingo Heeler", "Bingo challenges for the Orcs")
-- Chilli (a Troll) can't challenge for the Orcs; a forged one in Bingo's name from Chilli is dropped.
INJECT("YNM", Msg({ v = 1, t = "CHG", id = now, r = "Orc", st = "o", at = now, ev = now }), "GUILD", "Chilli Heeler")
INJECT("YNM", Msg({ v = 1, t = "CHG", o = "Bingo Heeler", id = now + 5, r = "Orc", st = "o", at = now, ev = now }), "GUILD", "Chilli Heeler")
Tick(1)
check(#X.Open("Orc") == 1, "a Troll's challenge for the Orcs and a forged one are dropped")
-- A member can't settle.
INJECT("YNM", Msg({ v = 1, t = "CHG", o = "Bingo Heeler", id = now, r = "Orc", st = "won", sb = "Chilli Heeler", at = now, ev = now + 1 }), "GUILD", "Chilli Heeler")
Tick(1)
check(X.Open("Orc")[1].st == "o", "a member's 'won' is dropped")

-- I challenge too (I'm an Orc and not the leader: no rank found for the Orcs here).
local before = #SENT
check(X.CanChallenge() and X.Challenge(), "I challenge")
check(not X.CanChallenge(), "one open challenge at a time")
local chg = Sent("CHG", before + 1)
check(#chg == 1 and chg[1].st == "o" and chg[1].r == "Orc" and chg[1].o == nil and chg[1]._channel == "GUILD", "CHG open, to the guild")
open = X.Open("Orc")
check(#open == 2 and open[1].owner == "Bingo Heeler" and open[2].owner == "Ned Jones", "in sign-up order")

-- The tab: swords count, swords after names, bar's Withdraw (two clicks).
UI.Open("clans")
Tick(1)
local page
for _, o in ipairs(CREATED) do if o.cols and o.bar then page = o end end
local orc = page.cols[1]
check(orc.chal.text:GetText():find("2", 1, true) and orc.chal:IsShown(), "the Orc list's title: two challenging")
local bingoRow
for _, r in ipairs(orc.rows) do if r.m and r.m.name == "Bingo Heeler" then bingoRow = r end end
check(bingoRow and bingoRow.name:GetText():find("DualWield", 1, true), "crossed swords after Bingo's name")
check(page.bar.withdraw:IsShown() and not page.bar.challenge:IsShown(), "bar: Withdraw challenge")
page.bar.withdraw:Click(); Tick(1)
check(X.OpenOf("Ned Jones", "Orc") ~= nil and page.bar.withdraw:GetText():find(L.CHAL_WITHDRAW_SURE, 1, true), "first click: Sure?")
before = #SENT
page.bar.withdraw:Click(); Tick(1)
check(X.OpenOf("Ned Jones", "Orc") == nil and Sent("CHG", before + 1)[1].st == "w", "second click: withdrawn, sent")
check(page.bar.challenge:IsShown(), "bar: Challenge again")
-- A withdrawn challenge can't be reopened by an old copy.
local mine = X.Store()["Ned Jones:" .. chg[1].id]
check(mine.st == "w", "mine is withdrawn")

-- Right-click Bingo: Invite, Whisper, Won, Lost, Second in command.
bingoRow._scripts.OnClick(bingoRow, "RightButton"); Tick(1)
local labels = {}
for _, r in ipairs(page.menu.rows) do if r:IsShown() then labels[#labels + 1] = r.text:GetText() end end
local joined = table.concat(labels, "|")
check(page.menu:IsShown() and #labels == 5 and joined:find(L.CHAL_MENU_WON, 1, true) and joined:find(L.CHAL_MENU_LOST, 1, true)
    and joined:find(L.INVITE, 1, true), "right-click: Invite, Whisper, Won, Lost, Second in command", joined)
-- Lost.
before = #SENT
for i, label in ipairs(labels) do if label:find(L.CHAL_MENU_LOST, 1, true) then page.menu.rows[i]:Click() end end
Tick(1)
local res = Sent("CHG", before + 1)
check(#res == 1 and res[1].st == "lost" and res[1].o == "Bingo Heeler" and res[1].sb == "Ned Jones", "Lost: sent with who settled it")
check(#X.Open("Orc") == 0 and #X.Recent("Orc") == 1, "no open challenges; one result")

-- The right-click menu doesn't stay stuck: mouse on it keeps it; off it for a moment closes it; a click
-- anywhere else closes it; the same right-click again closes it.
local menu = page.menu
bingoRow._scripts.OnClick(bingoRow, "RightButton"); Tick(1)
menu._over = true; Tick(5)
check(menu:IsShown(), "menu stays while the mouse is on it")
menu._over = false; Tick(1)
check(menu:IsShown(), "still there a moment after the mouse leaves")
Tick(1)
check(not menu:IsShown(), "closes by itself once the mouse has been off it")
bingoRow._scripts.OnClick(bingoRow, "RightButton"); Tick(0.5)
FireEvent("GLOBAL_MOUSE_DOWN", "LeftButton")
check(not menu:IsShown(), "a click elsewhere closes it")
bingoRow._scripts.OnClick(bingoRow, "RightButton"); Tick(0.5)
menu._over = true
FireEvent("GLOBAL_MOUSE_DOWN", "LeftButton")
check(menu:IsShown(), "a click on the menu itself doesn't")
menu._over = false
bingoRow._scripts.OnClick(bingoRow, "RightButton")
check(not menu:IsShown(), "the same right-click again closes it")

-- The bar is along the top, the lists under it.
local colY = page.cols[1]._pt and page.cols[1]._pt[3]
check(page.barY == 0 and colY and colY <= -(24 + 4), "bar on top, lists under it", tostring(page.barY) .. " / " .. tostring(colY))
-- A result is final: Bingo's older "open" doesn't undo it, nor does a later "withdrawn".
INJECT("YNM", Msg({ v = 1, t = "CHG", id = now, r = "Orc", st = "o", at = now, ev = now }), "GUILD", "Bingo Heeler")
INJECT("YNM", Msg({ v = 1, t = "CHG", id = now, r = "Orc", st = "w", at = now, ev = GetServerTime() + 5 }), "GUILD", "Bingo Heeler")
Tick(1)
check(X.Store()["Bingo Heeler:" .. now].st == "lost", "a result is final")
-- Another moderator's newer result wins (Bluey, rank 1, moderates Clans by default).
INJECT("YNM", Msg({ v = 1, t = "CHG", o = "Bingo Heeler", id = now, r = "Orc", st = "won", sb = "Bluey Heeler", at = now,
    ev = GetServerTime() + 8 }), "GUILD", "Bluey Heeler")
Tick(1)
check(X.Store()["Bingo Heeler:" .. now].st == "won", "a newer result from another moderator wins")

-- Copies: after log-in I ask one guildie; their copies are taken only because I asked.
local copy = { v = 1, t = "CHG", o = "Bluey Heeler", id = now + 50, r = "Orc", st = "o", at = now, ev = now }
INJECT("YNM", Msg(copy), "WHISPER", "Chilli Heeler")
Tick(1)
check(X.OpenOf("Bluey Heeler", "Orc") == nil, "an unasked copy is dropped")
ns.Comm.users["Chilli Heeler"] = ns.Comm.users["Chilli Heeler"] or { ver = ns.VERSION, seen = GetTime() }
for k, u in pairs(ns.Comm.users) do if k ~= "Chilli Heeler" then u.sim = true end end
before = #SENT
X.AskAll(); Tick(1)
local req = Sent("REQ", before + 1)
check(#req == 1 and req[1].w == "CHG" and req[1]._target == "Chilli Heeler", "asks one guildie for the challenges")
INJECT("YNM", Msg(copy), "WHISPER", "Chilli Heeler")
Tick(1)
check(X.OpenOf("Bluey Heeler", "Orc") ~= nil, "the asked guildie's copy is taken")
-- Someone asks me: I whisper what I hold.
before = #SENT
INJECT("YNM", Msg({ v = 1, t = "REQ", w = "CHG" }), "WHISPER", "Bingo Heeler")
Tick(2)
check(#Sent("CHG", before + 1) >= 3, "copies whispered to a guildie who asks")

-- Second in command: I give it to Bingo for the Orcs. Bingo may run the Orcs' meeting while it lasts.
check(not CM.CanRun("Bingo Heeler", "Orc"), "Bingo can't run a meeting yet")
before = #SENT
check(X.SetDeputy("Bingo Heeler", true), "I make Bingo second in command")
local dep = Sent("DEP", before + 1)
check(#dep == 1 and dep[1].who == "Bingo Heeler" and dep[1].r == "Orc" and dep[1].un > GetServerTime(), "DEP sent")
check(CM.CanRun("Bingo Heeler", "Orc") and Cl.IsDeputy("Bingo Heeler", "Orc"), "Bingo may run the Orcs' meeting now")
UI.Dirty(); Tick(1)
for _, r in ipairs(orc.rows) do if r.m and r.m.name == "Bingo Heeler" then bingoRow = r end end
check(bingoRow.name:GetText():find("AssistantIcon", 1, true), "the second in command's mark by Bingo")
Tick(31 * 60)
check(not Cl.IsDeputy("Bingo Heeler", "Orc") and not CM.CanRun("Bingo Heeler", "Orc"), "it ends by itself after 30 minutes")
-- From a member: dropped. From an officer: taken; un = 0 ends it.
INJECT("YNM", Msg({ v = 1, t = "DEP", r = "Orc", who = "Bingo Heeler", un = GetServerTime() + 600 }), "GUILD", "Chilli Heeler")
Tick(1)
check(not Cl.IsDeputy("Bingo Heeler", "Orc"), "a member can't give second in command")
INJECT("YNM", Msg({ v = 1, t = "DEP", r = "Orc", who = "Bingo Heeler", un = GetServerTime() + 600 }), "GUILD", "Bluey Heeler")
Tick(1)
check(Cl.IsDeputy("Bingo Heeler", "Orc"), "an officer can")
INJECT("YNM", Msg({ v = 1, t = "DEP", r = "Orc", who = "Bingo Heeler", un = 0 }), "GUILD", "Bluey Heeler")
Tick(1)
check(not Cl.IsDeputy("Bingo Heeler", "Orc"), "and end it")

-- Tidying: an open challenge goes after 14 days; results after 30.
INJECT("YNM", Msg({ v = 1, t = "CHG", id = now + 99, r = "Orc", st = "o", at = GetServerTime(), ev = GetServerTime() }), "GUILD", "Bingo Heeler")
Tick(1)
check(X.OpenOf("Bingo Heeler", "Orc") ~= nil, "Bingo challenges again")
Tick(15 * 86400)
FireEvent("GUILD_ROSTER_UPDATE"); Tick(2)
check(X.OpenOf("Bingo Heeler", "Orc") == nil and X.Store()["Bingo Heeler:" .. (now + 99)] == nil, "open for 14 days at most")
Tick(16 * 86400)
FireEvent("GUILD_ROSTER_UPDATE"); Tick(2)
check(#X.Recent("Orc") == 0, "results kept 30 days")

-- The dev command (sim mode): fake guildies challenge; Bazza settles one 20 s later.
SlashCmdList.YEAHNAHMATE("dev sim on")
Tick(16)
SlashCmdList.YEAHNAHMATE("dev challenge")
Tick(1)
local total = 0
for _, c in ipairs(Cl.List()) do total = total + #X.Open(c.race) end
check(total == 3, "dev challenge: three fake challengers", total)
Tick(21)
total = 0
local lost = 0
for _, c in ipairs(Cl.List()) do
    total = total + #X.Open(c.race)
    for _, ch in ipairs(X.Recent(c.race)) do if ch.st == "lost" then lost = lost + 1 end end
end
check(total == 2 and lost == 1, "Bazza marked one Lost")
for _, m in ipairs(SENT) do
    if m.channel == "WHISPER" and ns.Sim.IsFake(m.target) then check(false, "whispered a fake guildie: " .. m.target) end
end
SlashCmdList.YEAHNAHMATE("dev sim off")
Tick(1)

check(#ns.db.errors == 0, "no errors", ns.db.errors[1] and ns.db.errors[1].msg)
