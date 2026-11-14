-- The guild board: Home message and Info page (editor ranks only, checked against the reader's own
-- roster), the guild master's who-can-edit setting, streamer cards (owner only), copies, sim.
math.randomseed(8)
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
            m._target = SENT[i].target; list[#list + 1] = m
        end
    end
    return list
end
local function LogHas(text, fromLine)
    local log = ns.GetLog()
    for i = (fromLine or 1), #log do if log[i]:find(text, 1, true) then return true end end
    return false
end
local B = ns.Board
ns.settings.sharePosition, ns.settings.shareProfessions = false, false
INJECT("YNM", Msg({ v = 1, t = "HI", ver = "0.6.0" }), "GUILD", "Bluey Heeler")
Tick(15)
local now = GetServerTime()

-- I'm rank 4 (a member): I can't edit the guild info.
check(ns.Guild.myRank == 4 and not B.CanEdit() and not B.CanSetRank(), "a member can't edit the guild info or ranks")
check(B.SetInfo("hi", "there") == false, "SetInfo refused for a member")

-- Bluey is an officer (rank 1): their info is taken; Bingo (rank 3) isn't an editor.
INJECT("YNM", Msg({ v = 1, t = "BRD", k = "info", motd = "Levelling night Wed 7pm|cff", text = "Rules:\nBe nice.", ev = now }), "GUILD", "Bluey Heeler")
INJECT("YNM", Msg({ v = 1, t = "BRD", k = "info", motd = "I'm the boss now", text = "", ev = now + 5 }), "GUILD", "Bingo Heeler")
Tick(1)
local info = B.Info()
check(info and info.by == "Bluey Heeler" and info.motd == "Levelling night Wed 7pmcff" and info.text == "Rules:\nBe nice.", "Bluey's info kept (colour codes stripped, lines kept)")
local msg, by = B.HomeMessage()
check(msg == "Levelling night Wed 7pmcff" and by == "Bluey Heeler", "it's the Home message")

-- Only the guild master sets who can edit. Bingo can't; a guild master (Chilli, for this test) can.
INJECT("YNM", Msg({ v = 1, t = "BRD", k = "rank", er = 3, ev = now }), "GUILD", "Bingo Heeler")
Tick(1)
check(B.EditRank() == 1, "Bingo can't change who edits")
FAKE.roster[4][3] = 0                    -- Chilli is the guild master
ns.Guild.Scan()
INJECT("YNM", Msg({ v = 1, t = "BRD", k = "rank", er = 3, ev = now + 1 }), "GUILD", "Chilli Heeler")
Tick(1)
check(B.EditRank() == 3, "the guild master widened editing to rank 3")
INJECT("YNM", Msg({ v = 1, t = "BRD", k = "info", motd = "Bingo's message", text = "x", ev = now + 6 }), "GUILD", "Bingo Heeler")
Tick(1)
check(B.Info().by == "Bingo Heeler", "now Bingo (rank 3) can edit")
INJECT("YNM", Msg({ v = 1, t = "BRD", k = "info", motd = "old", text = "old", ev = now - 100 }), "GUILD", "Bluey Heeler")
INJECT("YNM", Msg({ v = 1, t = "BRD", k = "info", motd = "future", text = "", ev = now + 99999 }), "GUILD", "Bluey Heeler")
Tick(1)
check(B.Info().motd == "Bingo's message", "older and future versions ignored")
FAKE.roster[4][3] = 3
ns.Guild.Scan()

-- Me as guild master: I can edit and set ranks; it goes to the guild.
FAKE.myRank, FAKE.myRankName = 0, "Guild Master"
ns.Guild.Scan()
local before = #SENT
check(B.CanEdit() and B.CanSetRank(), "the guild master can edit and set ranks")
check(B.SetInfo("Home msg", "Long info\nline 2") == true, "saved the guild info")
check(B.SetEditRank(2) == true and B.EditRank() == 2, "set editors to rank 2 and above")
check(LogHas("sent my guild info to the guild") and LogHas("sent my who-can-edit setting to the guild"), "both sent to the guild")
FAKE.myRank, FAKE.myRankName = nil, nil
ns.Guild.Scan()

-- The Discord invite: tidied to discord.gg/CODE; empty means none; anything else is refused.
check(B.CleanDiscord("https://discord.gg/GoodSorts") == "discord.gg/GoodSorts", "discord.gg link kept")
check(B.CleanDiscord(" https://www.discord.com/invite/abc-123/ ") == "discord.gg/abc-123", "discord.com/invite link tidied")
check(B.CleanDiscord("") == "" and B.CleanDiscord("http://evil.example/x") == nil, "empty is fine; other links refused")
FAKE.myRank = 0
ns.Guild.Scan()
check(B.SetInfo("m", "t", "not a link") == false, "a bad invite stops the save")
check(B.SetInfo("m", "t", "discord.com/invite/GoodSorts") == true and B.Discord() == "discord.gg/GoodSorts", "invite saved")
check(LogHas("sent my guild info"), "sent with the info")
FAKE.myRank = nil
ns.Guild.Scan()
INJECT("YNM", Msg({ v = 1, t = "BRD", k = "info", motd = "x", text = "", dc = "javascript:alert(1)", ev = GetServerTime() + 30 }), "GUILD", "Bluey Heeler")
Tick(1)
check(B.Info().by == "Bluey Heeler" and B.Discord() == nil, "a bad invite in a message is dropped (the rest kept)")
INJECT("YNM", Msg({ v = 1, t = "BRD", k = "info", motd = "x", text = "", dc = "discord.gg/realone", ev = GetServerTime() + 31 }), "GUILD", "Bluey Heeler")
Tick(1)
check(B.Discord() == "discord.gg/realone", "Bluey's invite taken")

-- Editor test mode: a member can try editing on their own screen; nothing is sent.
local logLine = #ns.GetLog() + 1
SlashCmdList.YEAHNAHMATE("dev editor on")
check(B.CanEdit(), "editor test mode lets me edit")
before = #SENT
B.SetInfo("Test message", "Test info", "discord.gg/realone")
check(#SENT == before and LogHas("(dev) not sent", logLine), "nothing sent in editor test mode")
check(B.Info().motd == "Test message", "but it shows on my screen")
SlashCmdList.YEAHNAHMATE("dev editor off")
-- /ynm dev gm: the GM tab for testing, kept in settings so it survives a reload.
check(not B.CanManage(), "a Peon doesn't see the GM tab")
SlashCmdList.YEAHNAHMATE("dev gm on")
check(B.CanManage() and ns.settings.devGM == true, "dev gm on: GM tab shown and remembered")
B.devEditor = nil
ns.Fire("LOGIN")
check(B.CanManage(), "still on after a reload")
SlashCmdList.YEAHNAHMATE("dev gm off")
check(not B.CanManage() and ns.settings.devGM == nil, "dev gm off: hidden again")

Tick(40)                        -- 50 s after login: we ask one guildie for the board
-- We asked Bluey for the board 50 s after login: copies from Bluey count, others' don't, and a copy
-- of info is still checked against its author's rank.
check(#Sent("REQ", 1, function(m) return m.w == "BRD" end) == 1, "asked one guildie for the board after login")
local peer = Sent("REQ", 1, function(m) return m.w == "BRD" end)[1]._target
INJECT("YNM", Msg({ v = 1, t = "BRD", o = "Chilli Heeler", k = "strm", tw = "chilli_live", ev = GetServerTime() }), "WHISPER", peer)
INJECT("YNM", Msg({ v = 1, t = "BRD", o = "Bingo Heeler", k = "info", motd = "copy", text = "", ev = GetServerTime() }), "WHISPER", peer)
INJECT("YNM", Msg({ v = 1, t = "BRD", o = "Chilli Heeler", k = "strm", tw = "sneaky", ev = GetServerTime() + 1 }), "WHISPER", "Bingo Heeler")
Tick(1)
check(B.Store().streamers["Chilli Heeler"] and B.Store().streamers["Chilli Heeler"].tw == "chilli_live", "a copy from the guildie we asked; not from Bingo")
check(B.Info().motd ~= "copy", "a copy of guild info by a non-editor is refused")

-- Streamer cards: my own; Twitch names are checked; live; remove.
check(B.SetStreamer("not a name!", "", "") == false, "a bad Twitch name is refused")
before = #SENT
check(B.SetStreamer("https://www.twitch.tv/Ned_Jones", "Tue 8pm", "Shaman levelling") == true, "card saved")
check(B.Mine().tw == "Ned_Jones", "the link is cut down to the name")
B.SetLive(true)
local list = B.Streamers()
check(list[1].live and list[1].name == "Ned Jones", "I'm listed as live, first")
Tick(6 * 3600 + 400, 60)
check(not B.Mine().live, "live turns itself off after 6 hours")
-- Others' cards; live only counts while they're online.
INJECT("YNM", Msg({ v = 1, t = "BRD", k = "strm", tw = "bandit_plays", when = "Weekends", about = "Rogue", live = true, ev = GetServerTime() }), "GUILD", "Bandit Heeler")
INJECT("YNM", Msg({ v = 1, t = "BRD", k = "strm", tw = "x", ev = GetServerTime() }), "GUILD", "Bingo Heeler")
Tick(1)
local bandit
for _, e in ipairs(B.Streamers()) do if e.name == "Bandit Heeler" then bandit = e end end
check(bandit and not bandit.live, "Bandit's card listed; not live while offline")
check(B.Store().streamers["Bingo Heeler"] == nil, "a bad card is dropped")
FAKE.roster[5][9] = true
ns.Guild.Scan()
for _, e in ipairs(B.Streamers()) do if e.name == "Bandit Heeler" then bandit = e end end
check(bandit.live and B.Streamers()[1].name == "Bandit Heeler", "online and live: listed first")

-- Asked for the board: copies of others' items, my own as mine.
logLine = #ns.GetLog() + 1
INJECT("YNM", Msg({ v = 1, t = "REQ", w = "BRD" }), "WHISPER", "Chilli Heeler")
Tick(20)
check(LogHas("sent my Bandit Heeler's streamer card to Chilli Heeler", logLine) and LogHas("sent my streamer card to Chilli Heeler", logLine),
    "answered Chilli with Bandit's card (a copy) and mine")

-- Remove my card.
before = #SENT
B.RemoveStreamer()
check(B.Mine() == nil and LogHas("streamer card (removed)"), "card removed and the guild told")

-- The tabs and Home.
ns.UI.Open("home")
local home
for _, o in ipairs(CREATED) do if o.live and o.next then home = o end end
check(home and home.sub:GetText():find("Test message", 1, true), "Home shows the newest message and who it's from: " .. tostring(home and home.sub:GetText()))
check(home.live:IsShown() and home.live.text:GetText():find("Bandit", 1, true), "Home shows who's live")
check(home.dcBox:IsShown() and home.dcBox:GetText() == "discord.gg/realone", "Home shows the Discord invite to copy")
home.dcBox._scripts.OnTextChanged(home.dcBox, true)
check(home.dcBox:GetText() == "discord.gg/realone", "the copy box can't be typed over")
SlashCmdList.YEAHNAHMATE("dev editor on")
ns.UI.Select("info")
local infoPage
for _, o in ipairs(CREATED) do if o.editBtn and o.motdBox then infoPage = o end end
check(infoPage.editBtn:IsShown(), "editors get an Edit button")
infoPage.editBtn:Click()
Tick(1)
infoPage.motdBox:SetText("New home line")
infoPage.textBox:SetText("New info")
infoPage.save:Click()
check(B.Info().motd == "New home line" and not infoPage.editing, "edit and save from the Info tab")
SlashCmdList.YEAHNAHMATE("dev editor off")
Tick(1)
check(not infoPage.editBtn:IsShown(), "no Edit button for members")

-- The guild master's who-can-edit control (on the GM tab): one line, full rank names, < and > step
-- through ranks.
FAKE.myRank, FAKE.myRankName = 0, "Guild Master"
ns.Guild.Scan()
ns.UI.Select("gm")
Tick(1)
local gmPage
for _, o in ipairs(CREATED) do if o.mgrView and o.modRows then gmPage = o end end
B.SetEditRank(1)
gmPage.viewCards[2]:Click()
Tick(1)
-- tick which ranks moderate each tab. Rows = the guild's ranks, columns = tabs.
local rows = gmPage.modRows
check(gmPage.modView:IsShown() and rows[1]:IsShown() and rows[1].name:GetText() == "Guild Master"
    and rows[2].name:GetText() == "Officer" and rows[3].name:GetText() == "Member" and not rows[4]:IsShown(),
    "Moderators: one row per rank (guild master, Officer, Member)")
check(rows[1].boxes.info:GetChecked() and not rows[1].boxes.info:IsEnabled() and rows[2].boxes.cal:GetChecked()
    and not rows[3].boxes.cal:GetChecked(), "guild master always ticked; Officer ticked, Member not, by default")
rows[3].boxes.info:SetChecked(true); rows[3].boxes.info:Click()      -- the game ticks it, then OnClick
Tick(1)
check(B.RankModerates("info", 3) and not B.RankModerates("cal", 3), "ticking Member under Info: Members edit the info, not the calendar")
rows[2].boxes.info:SetChecked(false); rows[2].boxes.info:Click()
Tick(1)
check(not B.RankModerates("info", 1) and B.RankModerates("info", 3) and B.RankModerates("cal", 1),
    "ranks are picked, not 'and above': Officer unticked for Info, Member still ticked")
check(B.EditRank() == 0, "older versions hear Info's ticks from the top down (the guild master only here)")
B.SetEditRank(1)
gmPage.viewCards[1]:Click()
FAKE.myRank, FAKE.myRankName = nil, nil
ns.Guild.Scan()
ns.UI.Select("info")
Tick(1)

-- Sim mode: Bazza (a fake officer) posts info; two fake streamers; sim off removes them.
SlashCmdList.YEAHNAHMATE("dev sim on")
Tick(16)
check(B.Info().by == "Bazza Stubbs", "fake officer's guild info")
local fakeStreamers = 0
for _, e in ipairs(B.Streamers()) do if ns.Sim.IsFake(e.name) then fakeStreamers = fakeStreamers + 1 end end
check(fakeStreamers == 2, "two fake streamers (" .. fakeStreamers .. ")")

for _, tab in ipairs({ "streamers", "info", "home" }) do
    ns.UI.Select(tab)
    for pass = 1, 2 do
        local n = #CREATED
        for i = 1, n do
            local o = CREATED[i]
            if o._template == "UIPanelCloseButton" then o = { _scripts = {} } end
            if o._name ~= "YeahNahMateWhisper" and o._name ~= "YeahNahMateWelcome" then
                for _, s in ipairs({ "OnClick", "OnMouseUp", "OnEnter", "OnLeave", "OnEditFocusGained" }) do
                    if o._scripts[s] then o._scripts[s](o, "LeftButton") end
                end
                if o._scripts.OnTextChanged then o._scripts.OnTextChanged(o, true) end
            end
        end
        Tick(1)
    end
end
SlashCmdList.YEAHNAHMATE("dev sim off")
Tick(1)
fakeStreamers = 0
for name in pairs(B.Store().streamers) do if name == "Kezza Galah" or name == "Trev Drongo" then fakeStreamers = fakeStreamers + 1 end end
check(fakeStreamers == 0 and (not B.Info() or B.Info().by ~= "Bazza Stubbs"), "sim off: fake board items gone")

check(#UISpecialFrames == 0 and PanelManagerCalls == 0, "no taint tripwires touched")
check(#ERRORS == 0, "no errors (" .. (ERRORS[1] or "none") .. ")")
