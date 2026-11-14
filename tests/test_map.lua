-- Phase 2: status (ST), positions (POS), the first-run question, the dots, and the sim guildies moving.
math.randomseed(2)
YeahNahMateDB = nil
local ns = LoadAddon("YeahNahMate", "YeahNahMate")
LOGGED_IN = true
FireEvent("PLAYER_LOGIN")
local Ser = LibStub("AceSerializer-3.0")
local function Msg(t) return Ser:Serialize(t) end
local function SentOfType(t, from)
    local list = {}
    for i = (from or 1), #SENT do
        local ok, m = Ser:Deserialize(SENT[i].text)
        if ok and type(m) == "table" and m.t == t then list[#list + 1] = m end
    end
    return list
end

-- Bluey (a real guildie, per the game's roster) has the addon and says hi with their status.
INJECT("YNM", Msg({ v = 1, t = "HI", ver = "0.2.0", ask = true, l = 25, z = "Durotar", st = "g", n = 3 }), "GUILD", "Bluey Heeler")
Tick(1)
local bluey = ns.Guild.Get("Bluey Heeler")
check(bluey.level == 25 and bluey.zone == "Durotar", "status in HI beats the roster's level and zone")
check(ns.Status.Text(bluey) == "Group 3/5", "status text: " .. ns.Status.Text(bluey))
check(ns.Comm.OthersOnline() == 1, "one other addon user online")

-- Our HI carries our status.
Tick(12)
local his = SentOfType("HI")
check(#his >= 1 and his[1].l == 22 and his[1].z == "The Barrens", "our HI carries level and zone")

-- The first-run question appears; until it's answered no position is sent.
local ask = _G.YeahNahMateWelcome
check(ask and ask:IsShown(), "the welcome page shows after login")
SlashCmdList.YEAHNAHMATE("")
check(ask:GetFrameStrata() == "FULLSCREEN_DIALOG" and _G.YeahNahMateFrame:GetFrameStrata() == "DIALOG",
    "the welcome page sits above the main window")
SlashCmdList.YEAHNAHMATE("")
check(YeahNahMateDB.settings.sharePosition == nil, "not answered yet")
Tick(30)
check(#SentOfType("POS") == 0, "no position sent before the player answers")

-- Yes: positions go out.
local before = #SENT
check(not ask.done:IsEnabled(), "Sounds good waits until both are answered")
ask.questions[1].yes:Click()
check(not ask.done:IsEnabled() and YeahNahMateDB.settings.sharePosition == nil, "nothing saved yet after one answer")
ask.questions[2].no:Click()
ask.done:Click()
check(YeahNahMateDB.settings.sharePosition == true and YeahNahMateDB.settings.shareProfessions == false and not ask:IsShown(),
    "Yeah (map) and Nah (professions) saved")
Tick(6)
local pos = SentOfType("POS", before + 1)
check(#pos == 1 and pos[1].m == 1413 and pos[1].x == 0.5, "position sent straight after Yes (map 1413, x 0.5)")

-- Standing still: nothing more until the minute's keep-alive.
before = #SENT
Tick(40)
check(#SentOfType("POS", before + 1) == 0, "standing still: nothing for 40 s")
Tick(25)
check(#SentOfType("POS", before + 1) == 1, "standing still: one keep-alive after a minute")

-- Moving: about every 15 s.
before = #SENT
for i = 1, 12 do FAKE.x = 0.5 + i * 0.01; Tick(5) end
local moving = #SentOfType("POS", before + 1)
check(moving >= 3 and moving <= 5, "moving for 60 s sends 3-5 positions (" .. moving .. ")")

-- Every message stays small.
for _, m in ipairs(SENT) do if #m.text > 255 then check(false, "message over 255 bytes") end end

-- Into a dungeon: one "gone", then silence.
before = #SENT
FAKE.instance = true
Tick(6)
local gone = SentOfType("POS", before + 1)
check(#gone == 1 and gone[1].off == true, "entering a dungeon sends one 'gone'")
Tick(70)
check(#SentOfType("POS", before + 1) == 1, "nothing more while inside")
FAKE.instance = false
Tick(6)
check(#SentOfType("POS", before + 1) == 2, "position again after leaving")

-- Sharing off: one "gone", then nothing at all.
before = #SENT
ns.settings.sharePosition = false
ns.Fire("SETTINGS")
local off = SentOfType("POS", before + 1)
check(#off == 1 and off[1].off == true, "turning sharing off sends 'gone' at once")
for i = 1, 10 do FAKE.x = 0.3 + i * 0.01; Tick(10) end
check(#SentOfType("POS", before + 1) == 1, "nothing sent while sharing is off, even moving")
local lastPosLine
for _, l in ipairs(ns.GetLog()) do
    if l:find("sent my position", 1, true) or l:find("remove my dot", 1, true) then lastPosLine = l end
end
check(lastPosLine and lastPosLine:find("remove my dot", 1, true), "the log's last position line is the remove-my-dot one: " .. tostring(lastPosLine))
check(ns.Comm.Summary():find("Totals this session: sent", 1, true), "totals line reads plainly: " .. ns.Comm.Summary())

-- No other addon users online: nothing sent even with sharing on.
ns.settings.sharePosition = true
FAKE.roster[2][9] = false                 -- Bluey logs off
ns.Guild.Scan()
before = #SENT
Tick(70)
check(#SentOfType("POS", before + 1) == 0, "nobody with the addon online: no positions sent")
FAKE.roster[2][9] = true
ns.Guild.Scan()

-- Receiving: Bluey's position makes dots; junk is dropped; a dot goes when they stop, go
-- offline, or say "gone".
INJECT("YNM", Msg({ v = 1, t = "POS", m = 1411, x = 0.52, y = 0.48 }), "GUILD", "Bluey Heeler")
Tick(1)
local w, mm = ns.Map.DotShown("Bluey Heeler")
check(ns.Map.pos["Bluey Heeler"] and w and mm, "Bluey's dot on the world map and minimap")
-- 0.9.4: Bluey is in Durotar and I'm in the Barrens, so HereBeDragons keeps the minimap dot hidden;
-- we must not Show() it ourselves on each new position (a guildie 4000 yards away stayed on the minimap).
for _ = 1, 3 do
    INJECT("YNM", Msg({ v = 1, t = "POS", m = 1411, x = 0.53, y = 0.48 }), "GUILD", "Bluey Heeler")
    Tick(1)
end
local _, _, onScreen = ns.Map.DotShown("Bluey Heeler")
check(not onScreen, "a guildie in another zone never shows on the minimap")
INJECT("YNM", Msg({ v = 1, t = "POS", m = 1411, x = 5, y = 0.5 }), "GUILD", "Bingo Heeler")
INJECT("YNM", Msg({ v = 1, t = "POS", m = "x", x = 0.5, y = 0.5 }), "GUILD", "Bingo Heeler")
INJECT("YNM", Msg({ v = 1, t = "POS", m = 1411.5, x = 0.5, y = 0.5 }), "GUILD", "Bingo Heeler")
Tick(1)
check(ns.Map.pos["Bingo Heeler"] == nil, "bad positions dropped")
INJECT("YNM", Msg({ v = 1, t = "POS", m = 1411, x = 0.5, y = 0.5 }), "WHISPER", "Not Inguild")
Tick(1)
check(ns.Map.pos["Not Inguild"] == nil, "a whispered position from someone outside the guild is dropped")
-- 0.8.6: a guildie whispers where they are in answer to my hello (no broadcast per log-in).
INJECT("YNM", Msg({ v = 1, t = "POS", m = 1411, x = 0.5, y = 0.5 }), "WHISPER", "Bingo Heeler")
Tick(1)
check(ns.Map.pos["Bingo Heeler"] ~= nil, "a guildie's whispered position counts")
ns.Map.Remove("Bingo Heeler")
ns.settings.showMinimap = false
ns.Fire("SETTINGS")
w, mm = ns.Map.DotShown("Bluey Heeler")
check(w and not mm, "minimap dots can be turned off")
-- Ring colour: gold by default, red or blue from Settings, on both maps.
local RC = ns.Map.RING_COLOURS
check(ns.settings.dotRing == 3 and ns.Map.DotRing("Bluey Heeler") == RC[3], "dots have a gold ring by default")
ns.settings.dotRing = 1
ns.settings.showMinimap = true
ns.Fire("SETTINGS")
local rw2, rm2 = ns.Map.DotRing("Bluey Heeler")
check(rw2 == RC[1] and rm2 == RC[1], "picking red turns both rings red")
ns.settings.dotRing = 99
ns.Fire("SETTINGS")
check(ns.Map.DotRing("Bluey Heeler") == RC[3], "an unknown ring setting falls back to gold")
ns.settings.dotRing = 3
ns.settings.showMinimap = true
ns.Fire("SETTINGS")
Tick(160)
check(ns.Map.pos["Bluey Heeler"] == nil, "a dot goes after 150 s without a position")
INJECT("YNM", Msg({ v = 1, t = "POS", m = 1411, x = 0.5, y = 0.5 }), "GUILD", "Bluey Heeler")
Tick(1)
INJECT("YNM", Msg({ v = 1, t = "POS", off = true }), "GUILD", "Bluey Heeler")
Tick(1)
check(ns.Map.pos["Bluey Heeler"] == nil and not ns.Map.DotShown("Bluey Heeler"), "'gone' removes the dot at once")
INJECT("YNM", Msg({ v = 1, t = "POS", m = 1411, x = 0.5, y = 0.5 }), "GUILD", "Bluey Heeler")
Tick(1)
FAKE.roster[2][9] = false
ns.Guild.Scan()
check(ns.Map.pos["Bluey Heeler"] == nil, "going offline removes the dot")
FAKE.roster[2][9] = true
ns.Guild.Scan()

-- ST: a change arrives; odd values ignored.
INJECT("YNM", Msg({ v = 1, t = "ST", l = 26, z = "Orgrimmar", st = "t" }), "GUILD", "Bluey Heeler")
INJECT("YNM", Msg({ v = 1, t = "ST", l = "lots", z = 7, st = "zzz" }), "GUILD", "Chilli Heeler")
Tick(1)
bluey = ns.Guild.Get("Bluey Heeler")
check(bluey.level == 26 and bluey.zone == "Orgrimmar" and ns.Status.Text(bluey) == "In town", "ST updates level, zone and status")
check(ns.Guild.Get("Chilli Heeler").level == 40, "a junk ST is ignored")

-- Our ST: sent when something changes, at most every 30 s.
before = #SENT
FAKE.group = 2
FireEvent("GROUP_ROSTER_UPDATE")
Tick(3)
local st = SentOfType("ST", before + 1)
check(#st == 1 and st[1].st == "g" and st[1].n == 2, "joining a group sends ST (g, 2)")
FAKE.group = 3
FireEvent("GROUP_ROSTER_UPDATE")
Tick(5)
check(#SentOfType("ST", before + 1) == 1, "a second change within 30 s waits")
Tick(30)
st = SentOfType("ST", before + 1)
check(#st == 2 and st[2].n == 3, "then goes out (n = 3)")

-- Sim mode: fake guildies get dots and move.
SlashCmdList.YEAHNAHMATE("dev sim on")
Tick(20)
local dots = 0
for name in pairs(ns.Map.pos) do if ns.Sim.IsFake(name) then dots = dots + 1 end end
check(dots >= 8, "fake guildies have dots (" .. dots .. ")")
local bazza = ns.Map.pos["Bazza Stubbs"]
local x1 = bazza and bazza.x
Tick(20)
check(bazza and ns.Map.pos["Bazza Stubbs"].x ~= x1, "fake guildies move")
check(ns.Status.Text(ns.Guild.Get("Davo Thongs")) == "Group 3/5", "fake guildies have a status")

-- Every tab and button, with dots and statuses about.
SlashCmdList.YEAHNAHMATE("")
for _, lvl in ipairs({ 5, 22, 60 }) do
    FAKE.level = lvl
    for pass = 1, 2 do
        local n = #CREATED
        for i = 1, n do
            local o = CREATED[i]
            if o._template == "UIPanelCloseButton" then o = { _scripts = {} } end   -- X buttons have their own test
            if o._name ~= "YeahNahMateWhisper" and o._name ~= "YeahNahMateWelcome" then
                for _, s in ipairs({ "OnClick", "OnMouseUp", "OnEnter", "OnLeave" }) do
                    if o._scripts[s] then o._scripts[s](o, "LeftButton") end
                end
            end
        end
        Tick(1)
    end
end
FAKE.level = 22
check(#WHISPERS == 0, "clicking around sends no whispers")
SlashCmdList.YEAHNAHMATE("dev sim off")
Tick(2)
dots = 0
for name in pairs(ns.Map.pos) do dots = dots + 1 end
check(dots == 0, "sim off removes the fake dots (" .. dots .. ")")

-- Positions are never saved.
local function hasKey(t, k, depth)
    if depth > 6 or type(t) ~= "table" then return false end
    for key, v in pairs(t) do
        if key == k or hasKey(v, k, depth + 1) then return true end
    end
    return false
end
check(not hasKey(YeahNahMateDB, "px", 0) and YeahNahMateDB.pos == nil, "no positions in saved data")

check(#UISpecialFrames == 0 and PanelManagerCalls == 0, "no taint tripwires touched")
check(#ERRORS == 0, "no errors (" .. (ERRORS[1] or "none") .. ")")
