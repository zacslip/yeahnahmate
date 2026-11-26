-- The real addon (Phase 1): loads, saved data, roster from the game, HI messages, the receive
-- checks (whispers from strangers, junk, newer versions, floods), sim mode, the probe, every tab
-- and button clicked, and the taint tripwires.
math.randomseed(1)
YeahNahMateDB = nil
local ns = LoadAddon("YeahNahMate", "YeahNahMate")
check(type(YeahNahMateDB) == "table" and YeahNahMateDB.settings.pop.group == true and YeahNahMateDB.settings.popups == nil, "saved data created with defaults")
check(ns.VERSION == "test", "version read from the toc")

LOGGED_IN = true
FireEvent("PLAYER_LOGIN")
check(ns.me == "Ned Jones", "my name is First Surname (" .. tostring(ns.me) .. ")")
check(ns.Guild.name == "The Good Sorts", "guild name from the game")
check(ROSTER_ASKS >= 1, "asked the server for the roster")
check(#ns.Guild.list == 5, "roster read: " .. #ns.Guild.list .. " members")
check(ns.Guild.IsMember("Bluey Heeler"), "roster names keyed as plain First Surname")
check(ns.Guild.Get("Bingo Heeler") and ns.Guild.Get("Bingo Heeler").status == 1, "dashed name read as First Surname, away status read")
check(ns.Guild.IsMember("Chilli Heeler"), "sub-realm suffix dropped from a roster name")
check(ns.Key("Ned-Jones") == "Ned Jones" and ns.Key("Ned Jones-SERVER1Realm1PvE") == "Ned Jones"
    and ns.Key("Ned Jones") == "Ned Jones", "name forms all key to the same player")

-- HI goes out about 10 s after login and comes back to us (the game echoes GUILD messages).
Tick(12)
local hi
for _, m in ipairs(SENT) do if m.channel == "GUILD" and m.prefix == "YNM" then hi = m end end
check(hi ~= nil, "HI sent to the guild after login")
check(ns.Comm.selfEcho ~= nil, "our own HI came back")
check(ns.Comm.users["Ned Jones"] ~= nil, "we count ourselves as an addon user")

-- A guildie says hi and asks: we whisper our HI back to them (once).
local Ser = LibStub("AceSerializer-3.0")
local function Msg(t) return Ser:Serialize(t) end
local before = #SENT
INJECT("YNM", Msg({ v = 1, t = "HI", ver = "0.1.0", ask = true }), "GUILD", "Bluey Heeler")
Tick(8)
local reply
for i = before + 1, #SENT do if SENT[i].channel == "WHISPER" then reply = SENT[i] end end
check(ns.Comm.users["Bluey Heeler"] and ns.Comm.users["Bluey Heeler"].ver == "0.1.0", "Bluey seen with version 0.1.0")
check(reply and reply.target == "Bluey Heeler", "whispered our HI back to Bluey")
before = #SENT
INJECT("YNM", Msg({ v = 1, t = "HI", ver = "0.1.0", ask = true }), "GUILD", "Bluey Heeler")
Tick(8)
check(#SENT == before, "no second reply to the same guildie within a minute")
check(YeahNahMateDB.guilds["The Good Sorts"].users["Bluey Heeler"] ~= nil, "addon users saved per guild")

-- The receive checks.
INJECT("YNM", Msg({ v = 1, t = "HI", ver = "0.1.0" }), "WHISPER", "Stranger Danger")
Tick(1)
check(ns.Comm.users["Stranger Danger"] == nil, "whisper from someone not in the guild is ignored")
INJECT("YNM", "complete junk", "GUILD", "Chilli Heeler")
INJECT("YNM", Msg({ v = 1, t = "ZZZ" }), "GUILD", "Chilli Heeler")
INJECT("YNM", Msg({ t = "HI" }), "GUILD", "Chilli Heeler")
INJECT("YNM", Msg({ v = 1, t = "HI", ver = { "not", "a", "string" } }), "GUILD", "Chilli Heeler")
Tick(2)
check(#ERRORS == 0, "junk, unknown types and odd fields cause no errors (" .. (ERRORS[1] or "none") .. ")")
INJECT("YNM", Msg({ v = 99, t = "HI", ver = "9.0.0", brandNew = true }), "GUILD", "Bandit Heeler")
Tick(1)
check(ns.Comm.users["Bandit Heeler"] and ns.Comm.users["Bandit Heeler"].ver == "9.0.0", "a newer protocol's HI still tells us their version")
check(ns.Comm.newest == nil, "a 'test' build doesn't nag about versions")
local logged = 0
for i = 1, 250 do INJECT("YNM", Msg({ v = 1, t = "HI", ver = "0.1.0" }), "GUILD", "Chilli Heeler") end
Tick(1)
local found = false
for _, l in ipairs(ns.GetLog()) do if l:find("too many messages from Chilli", 1, true) then found = true end end
check(found, "a flood from one sender is cut off and logged")

-- Version comparison.
check(ns.CompareVersions("0.1.10", "0.1.9") == 1 and ns.CompareVersions("0.1.0", "0.1") == 0
    and ns.CompareVersions("0.0.9", "0.1.0") == -1, "version comparison")

-- Roster filters (I'm level 22 in The Barrens; range 3).
local R = ns.Roster
local function names(list) local t = {} for _, m in ipairs(list) do t[#t + 1] = m.name:match("^%S+") end return table.concat(t, ",") end
check(#R.Get(R.ONLINE) == 4, "Online: 4 (" .. names(R.Get(R.ONLINE)) .. ")")
check(names(R.Get(R.NEAR)) == "Bluey,Bingo", "Near my level: Bluey, Bingo (" .. names(R.Get(R.NEAR)) .. ")")
check(names(R.Get(R.ZONE)) == "Bluey", "In my zone: Bluey (" .. names(R.Get(R.ZONE)) .. ")")
check(#R.Get(R.ALL) == 5, "Everyone: 5")
check(R.Range() == 3, "near my level is a fixed 3 levels")
check(names(R.Get(R.ALL, "level")) == "Bingo,Ned,Bluey,Chilli,Bandit", "sort by level, online first (" .. names(R.Get(R.ALL, "level")) .. ")")
check(names(R.Get(R.ALL, "level", true)) == "Chilli,Bluey,Ned,Bingo,Bandit", "sort by level reversed (" .. names(R.Get(R.ALL, "level", true)) .. ")")
check(names(R.Get(R.ALL, "name")) == "Bingo,Bluey,Chilli,Ned,Bandit", "sort by name (" .. names(R.Get(R.ALL, "name")) .. ")")
check(names(R.Get(R.ALL, "rank")) == "Ned,Bluey,Bingo,Chilli,Bandit", "sort by rank (" .. names(R.Get(R.ALL, "rank")) .. ")")

-- Sim mode adds fake guildies and they say hi through the real receive path; nothing real is sent.
before = #SENT
SlashCmdList.YEAHNAHMATE("dev sim on")
Tick(15)
check(#ns.Guild.list == 5 + 14, "sim adds 14 fake guildies")
local fakeUsers = 0
for _, u in pairs(ns.Comm.users) do if u.sim then fakeUsers = fakeUsers + 1 end end
check(fakeUsers == 9, "9 fake guildies have the addon (" .. fakeUsers .. ")")
-- Screenshot mode: roster views show only fakes and me; the real roster and data stay.
local R = ns.Roster
local function HasReal(list) for _, m in ipairs(list) do if not m.sim and m.name ~= ns.me then return true end end return false end
check(HasReal(R.Get(R.ALL)), "before screenshot mode the real guildies are listed")
SlashCmdList.YEAHNAHMATE("dev shots on")
check(not HasReal(R.Get(R.ALL)) and not HasReal(R.Get(R.ONLINE)) and not HasReal((R.NearMe())), "screenshot mode lists no real guildies")
check(#ns.Guild.list == 5 + 14 and ns.Guild.IsMember("Bluey Heeler"), "screenshot mode leaves the roster itself alone")
SlashCmdList.YEAHNAHMATE("dev shots off")
check(HasReal(R.Get(R.ALL)), "screenshot mode off lists them again")
local realSends = 0
local what = {}
for i = before + 1, #SENT do
    local ok, m = LibStub("AceSerializer-3.0"):Deserialize(SENT[i].text)
    -- The normal asks to a real guildie after login (calendar, board, requests) aren't from sim mode.
    if not (ok and type(m) == "table" and m.t == "REQ" and (m.w == "CAL" or m.w == "RQS" or m.w == "BRD" or m.w == "IDX")
        and not ns.Sim.IsFake(SENT[i].target) and ns.Guild.IsMember(SENT[i].target)) then
        realSends = realSends + 1
        what[#what + 1] = ok and type(m) == "table" and tostring(m.t) or "?"
    end
end
check(realSends == 0, "sim mode sends nothing real (" .. table.concat(what, ",") .. ")")
check(YeahNahMateDB.dev.sim == true, "sim mode remembered for /reload")
check(YeahNahMateDB.guilds["The Good Sorts"].users["Bazza Stubbs"] == nil, "fake guildies are never saved")
Tick(95)  -- drift a few times

-- The window: open, click everything at three levels, with fake guildies in.
SlashCmdList.YEAHNAHMATE("")
local win = _G.YeahNahMateFrame
check(win and win:IsShown(), "/ynm opens the window")
for _, lvl in ipairs({ 5, 22, 60 }) do
    FAKE.level = lvl
    for pass = 1, 2 do
        local n = #CREATED
        for i = 1, n do
            local o = CREATED[i]
            if o._template == "UIPanelCloseButton" then o = { _scripts = {} } end   -- X buttons have their own test
            if not IsInside(o, "YeahNahMateWhisper") then
                for _, s in ipairs({ "OnClick", "OnMouseUp", "OnEnter", "OnLeave" }) do
                    if o._scripts[s] then o._scripts[s](o, "LeftButton") end
                end
                if o._scripts.OnMouseWheel then o._scripts.OnMouseWheel(o, -1); o._scripts.OnMouseWheel(o, 1) end
            end
        end
        Tick(1)
    end
end
FAKE.level = 22
check(#ERRORS == 0, "no errors while clicking everything (" .. (ERRORS[1] or "none") .. ")")
local fakeInvites = 0
for _, n in ipairs(INVITES) do if n:find("Bazza", 1, true) then fakeInvites = fakeInvites + 1 end end
check(fakeInvites == 0, "Invite on a fake guildie sends nothing")
check(#WHISPERS == 0, "no whisper sent by clicking around (only Send/Enter in the box sends)")
check(win:IsShown(), "window still open")

-- The whisper box: only Send sends, only as a whisper, only to that person.
ns.Whisper.Open(ns.Guild.Get("Bluey Heeler"), "Keen for Wailing Caverns?")
local wbox = _G.YeahNahMateWhisper
check(wbox and wbox:IsShown(), "whisper box opens prefilled")
check(#WHISPERS == 0, "opening it sends nothing")
wbox.edit._scripts.OnEnterPressed(wbox.edit)
check(#WHISPERS == 1 and WHISPERS[1].kind == "WHISPER" and WHISPERS[1].target == "Bluey Heeler"
    and WHISPERS[1].text == "Keen for Wailing Caverns?", "Enter sends one whisper to Bluey")
check(not wbox:IsShown(), "box closes after sending")
ns.Whisper.Open(ns.Guild.Get("Bazza Stubbs"), "hi")
wbox.edit._scripts.OnEnterPressed(wbox.edit)
check(#WHISPERS == 1, "a fake guildie gets no real whisper")

-- Settings change the roster range and hide the minimap button.
ns.UI.Select("settings")
ns.settings.minimap = false
ns.Fire("SETTINGS")
check(not _G.YeahNahMateMinimapButton:IsShown(), "minimap button can be hidden")
ns.settings.minimap = true
ns.Fire("SETTINGS")
check(_G.YeahNahMateMinimapButton:IsShown(), "and shown again")

-- Sim off removes the fakes.
SlashCmdList.YEAHNAHMATE("dev sim off")
check(#ns.Guild.list == 5, "sim off removes the fake guildies")
fakeUsers = 0
for _, u in pairs(ns.Comm.users) do if u.sim then fakeUsers = fakeUsers + 1 end end
check(fakeUsers == 0, "and their addon entries")

-- The probe writes its answers to saved data.
SlashCmdList.YEAHNAHMATE("dev probe")
Tick(6)
local p = YeahNahMateDB.probe
check(p and p.answers and p.answers["has C_PartyInfo.InviteUnit"] == "function" and p.answers["has GetNumTradeSkills"] == "missing", "probe wrote its answers")
check(p and p.answers["UnitFullName"] == '"Ned" | "Jones"', "probe records name format (" .. tostring(p and p.answers["UnitFullName"]) .. ")")
check(p and p.answers["raw senders of our messages"]:find("Ned Jones", 1, true), "probe saw the raw sender name of our own message")

-- The milestones probe (Phase 9): reads, then records only while on; the chat test sends one GUILD line.
SlashCmdList.YEAHNAHMATE("dev msprobe")
local mp = YeahNahMateDB.msprobe
check(mp and mp.answers and mp.answers["has GuildInvite"] and mp.answers.recorder == "on" and ns.settings.msprobe == true, "msprobe read and recorder on")
FireEvent("PLAYER_LEVEL_UP", 13)
FireEvent("CHAT_MSG_SYSTEM", "Bingo Heeler has joined the guild.")
FireEvent("CHAT_MSG_SYSTEM", "You have learned a new spell.")
check(mp.seen.PLAYER_LEVEL_UP and #mp.seen.PLAYER_LEVEL_UP == 1 and #mp.seen.system == 1, "recorder kept the level-up and only the guild system line")
local sentBefore = #WHISPERS
SlashCmdList.YEAHNAHMATE("dev msprobe chat")
Tick(3)
check(#WHISPERS == sentBefore + 1 and WHISPERS[#WHISPERS].kind == "GUILD" and WHISPERS[#WHISPERS].text:find("[Yeah Nah Mate]", 1, true)
    and mp.chat and mp.chat.sent == "no error", "msprobe chat sent one tagged GUILD line")
SlashCmdList.YEAHNAHMATE("dev msprobe off")
FireEvent("PLAYER_LEVEL_UP", 14)
check(#mp.seen.PLAYER_LEVEL_UP == 1 and ns.settings.msprobe == nil, "recorder off: nothing more kept")

-- Errors in our code are caught and saved, not lost.
ns.Listen("TEST_BOOM", function() error("boom") end)
local shown = #ERRORS
ns.Fire("TEST_BOOM")
check(#YeahNahMateDB.errors == 1 and YeahNahMateDB.errors[1].msg:find("boom", 1, true), "an error is saved")
check(#ERRORS == shown + 1, "and still shown by the game")
table.remove(ERRORS)

-- Slash commands that only print.
for _, c in ipairs({ "log", "errors", "help", "reset", "dev", "dev sim" }) do SlashCmdList.YEAHNAHMATE(c) end
check(#YeahNahMateDB.log > 10, "the message log is in saved data (" .. #YeahNahMateDB.log .. " lines)")

-- Not in a guild: nothing breaks, nothing goes to GUILD.
FAKE.guild = nil
FireEvent("PLAYER_GUILD_UPDATE")
before = #SENT
Tick(10)
check(ns.Guild.name == nil and #ns.Guild.list == 0, "leaving the guild empties the roster")
ns.UI.Select("home"); ns.UI.Select("roster")
check(#SENT == before, "nothing sent without a guild")

-- Trial accounts can't send addon messages: we don't try.
FAKE.guild = "The Good Sorts"
FAKE.trial = true
check(ns.Comm.Send({ t = "HI", ver = "x" }, "GUILD") == false, "trial accounts don't send")
FAKE.trial = false

-- Closing in combat: the X button and Escape both work, and the X never uses the panel system.
ns.UI.Open()
check(win:IsShown(), "window open again")
FAKE.combat = true
win.CloseButton:Click()
check(not win:IsShown(), "the X closes the window in combat")
ns.UI.Open()
win._scripts.OnKeyDown(win, "W")
check(win:IsShown(), "in combat, other keys leave it open")
win._scripts.OnKeyDown(win, "ESCAPE")
check(not win:IsShown(), "Escape closes the window in combat")
FAKE.combat = false
ns.UI.Open()
ns.Whisper.Open(ns.Guild.Get("Bluey Heeler"), "x")
_G.YeahNahMateWhisper.CloseButton:Click()
check(not _G.YeahNahMateWhisper:IsShown(), "the whisper box's X closes it")
check(PanelManagerCalls == 0, "no X button went through HideUIPanel")

-- Escape and the taint tripwires.
win._scripts.OnKeyDown(win, "W")
check(win:IsShown(), "other keys leave the window open")
win._scripts.OnKeyDown(win, "ESCAPE")
check(not win:IsShown(), "Escape closes the window")
check(#UISpecialFrames == 0, "UISpecialFrames untouched (no taint)")
check(PanelManagerCalls == 0, "no ShowUIPanel/HideUIPanel calls (no taint)")
-- Escape, then a fight starts before the window lets keys through again: the fight's start puts it
-- back, so the window opened in the fight doesn't eat every key (chat's / and Enter included).
ns.UI.Open()
win._scripts.OnKeyDown(win, "ESCAPE")
check(win._propagate == false, "Escape: that one press stays with the window")
FireEvent("PLAYER_REGEN_DISABLED")
FAKE.combat = true
Tick(1)
ns.UI.Open()
check(win._propagate == true, "a fight starting right after Escape: keys pass through again")
win._scripts.OnKeyDown(win, "ESCAPE")
FAKE.combat = false
check(#ERRORS == 0, "no errors at the end (" .. (ERRORS[1] or "none") .. ")")

-- /ynm dev wipe: asks first; "yes" forgets all saved data and reloads, sending nothing.
local sentBefore = #SENT
SlashCmdList.YEAHNAHMATE("dev wipe")
check(type(YeahNahMateDB) == "table" and RELOADS == 0, "dev wipe without yes only explains")
SlashCmdList.YEAHNAHMATE("dev wipe yes")
check(YeahNahMateDB == nil and RELOADS == 1, "dev wipe yes clears saved data and reloads")
check(#SENT == sentBefore, "wiping sends nothing")
