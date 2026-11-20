-- Phase 4: posting a group, sign-ups, the leader's Invite, joins counting as filled, closing,
-- signing up for others' groups, "I'm available", pop-ups, late joiners, junk, expiry, sim.
math.randomseed(4)
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
            m._target = SENT[i].target; m._channel = SENT[i].channel
            list[#list + 1] = m
        end
    end
    return list
end
local D = ns.Dungeons
ns.settings.sharePosition, ns.settings.shareProfessions = false, false   -- skip the questions
INJECT("YNM", Msg({ v = 1, t = "HI", ver = "0.4.0" }), "GUILD", "Bluey Heeler")
Tick(15)

-- Posting: the guild hears it; it shows as mine.
local before = #SENT
check(D.Post("zzz", "d", { t = 1, h = 1, d = 3 }, "") == false, "an unknown dungeon can't be posted")
check(D.Post("wc", "d", { t = 1, h = 1, d = 3 }, "Quests too|cffff0000") == true, "posted Wailing Caverns")
local grp = Sent("GRP", before + 1)
check(#grp == 1 and grp[1]._channel == "GUILD" and grp[1].d == "wc" and grp[1].hd == 1 and grp[1].nt == 1, "GRP sent: WC, me as DPS (1/3), needs a tank")
check(grp[1].note == "Quests toocffff0000", "colour codes stripped from the note")
local mine = D.MyGroup()
local list = D.Groups()
check(#list == 1 and list[1].mine, "my group is listed, marked mine")

-- Sign-ups by whisper: Bluey as tank, Bingo as healer. Wrong id, GUILD channel and strangers ignored.
INJECT("YNM", Msg({ v = 1, t = "SIGN", id = mine.id, r = "t" }), "WHISPER", "Bluey Heeler")
INJECT("YNM", Msg({ v = 1, t = "SIGN", id = mine.id, r = "h" }), "WHISPER", "Bingo Heeler")
INJECT("YNM", Msg({ v = 1, t = "SIGN", id = mine.id + 1, r = "d" }), "WHISPER", "Chilli Heeler")
INJECT("YNM", Msg({ v = 1, t = "SIGN", id = mine.id, r = "d" }), "GUILD", "Chilli Heeler")
INJECT("YNM", Msg({ v = 1, t = "SIGN", id = mine.id, r = "d" }), "WHISPER", "Stranger Danger")
INJECT("YNM", Msg({ v = 1, t = "SIGN", id = mine.id, r = "x" }), "WHISPER", "Bandit Heeler")
Tick(1)
local apps = D.Applicants()
local function App(name) for _, a in ipairs(D.Applicants()) do if a.name == name then return a end end end
check(#apps == 2 and App("Bluey Heeler") and App("Bluey Heeler").r == "t" and App("Bingo Heeler").r == "h", "two applicants: Bluey (tank) and Bingo (healer)")
check(ns.Toast.IsShown(), "the leader gets a pop-up for a sign-up")

-- Invite is the leader's click; nobody is invited by the addon itself.
check(#INVITES == 0, "nobody invited yet")
SlashCmdList.YEAHNAHMATE("")
ns.UI.Select("dungeons")
Tick(1)
local inviteBtn
for _, o in ipairs(CREATED) do if o.who == "Bluey Heeler" and o.invite and o.decline then inviteBtn = o.invite end end
check(inviteBtn ~= nil, "Bluey's row has an Invite button")
inviteBtn:Click()
check(#INVITES == 1 and INVITES[1] == "Bluey Heeler", "Invite clicked: the game's invite for Bluey Heeler")

-- Bluey joins the party: the tank counts as filled and the guild hears the new numbers.
before = #SENT
FAKE.party = { "Bluey Heeler" }
FireEvent("GROUP_ROSTER_UPDATE")
Tick(4)
grp = Sent("GRP", before + 1)
check(#grp == 1 and grp[1].ht == 1 and grp[1].hd == 1, "after Bluey joined: tank 1/1 sent to the guild")
check(App("Bluey Heeler").joined and not App("Bingo Heeler").joined, "Bluey shows as joined")

-- The leader changes how many are needed.
before = #SENT
D.SetNeed("d", 2)
D.SetNeed("d", 9)
Tick(4)
grp = Sent("GRP", before + 1)
check(#grp == 1 and grp[1].nd == 4, "need changes sent once, capped at 4 DPS")
D.SetNeed("d", 3)

-- Declining tells the applicant.
before = #SENT
D.Decline("Bingo Heeler")
local ans = Sent("ANS", before + 1)
check(#ans == 1 and ans[1]._target == "Bingo Heeler" and #D.Applicants() == 1, "declined Bingo: told by whisper, off the list")

-- A guildie logging in hears about my group by whisper.
FAKE.roster[5][9] = true          -- Bandit comes online
ns.Guild.Scan()
before = #SENT
INJECT("YNM", Msg({ v = 1, t = "HI", ver = "0.4.0", ask = true }), "GUILD", "Bandit Heeler")
Tick(8)
grp = Sent("GRP", before + 1, function(m, s) return s.target == "Bandit Heeler" end)
check(#grp == 1, "my group whispered to Bandit, who just logged in")

-- Closing.
before = #SENT
D.Close()
grp = Sent("GRP", before + 1)
check(#grp == 1 and grp[1].x == true and D.MyGroup() == nil, "closing tells the guild")
FAKE.party = {}

-- Someone else's group at my level: pop-up, sign up, cancel, the leader says no.
ns.Toast.Show("x", "y")
ns.UI.Select("home")
local now = GetServerTime()
INJECT("YNM", Msg({ v = 1, t = "GRP", id = 77, d = "sfk", me = "t", nt = 1, nh = 1, nd = 3, ht = 1, hh = 0, hd = 1,
    note = "", u = now + 99999 }), "GUILD", "Chilli Heeler")
Tick(1)
local key = "Chilli Heeler:77"
local g = D.groups[key]
check(g and g.u <= now + 7200 + 1, "a group can't last longer than 2 hours")
check(D.AtMyLevel("sfk") and ns.Toast.IsShown(), "pop-up for a group at my level")
before = #SENT
D.SignUp(key, "h")
local sign = Sent("SIGN", before + 1)
check(#sign == 1 and sign[1]._target == "Chilli Heeler" and sign[1].r == "h" and sign[1].id == 77, "signed up as healer: whispered to Chilli")
D.CancelSign(key)
sign = Sent("SIGN", before + 1)
check(#sign == 2 and sign[2].x == true and D.signed[key] == nil, "cancel tells Chilli")
D.SignUp(key, "h")
INJECT("YNM", Msg({ v = 1, t = "ANS", id = 77, a = "x" }), "WHISPER", "Chilli Heeler")
Tick(1)
check(D.signed[key] == "x", "Chilli said not this time")

-- Junk and impostors.
INJECT("YNM", Msg({ v = 1, t = "GRP", id = 5, d = "zzz", me = "t", u = now + 100 }), "GUILD", "Bingo Heeler")
INJECT("YNM", Msg({ v = 1, t = "GRP", id = "x", d = "wc", me = "t", u = now + 100 }), "GUILD", "Bingo Heeler")
INJECT("YNM", Msg({ v = 1, t = "GRP", id = 77, x = true }), "GUILD", "Bingo Heeler")
Tick(1)
check(D.groups[key] ~= nil and #D.Groups() == 1, "junk dropped; only Chilli can close Chilli's group")

-- Pop-ups can be turned off.
ns.Toast.Show("x", "y")
ns.settings.pop.group = false
INJECT("YNM", Msg({ v = 1, t = "GRP", id = 78, d = "bfd", me = "t", nt = 1, nh = 1, nd = 3, ht = 1, hh = 0, hd = 0,
    note = "", u = now + 3600 }), "GUILD", "Bingo Heeler")
Tick(1)
check(D.groups["Bingo Heeler:78"] ~= nil, "Bingo's group listed")
ns.settings.pop.group = true

-- A group goes when its leader goes offline.
FAKE.roster[3][9] = false
ns.Guild.Scan()
check(D.groups["Bingo Heeler:78"] == nil, "Bingo went offline: their group goes")
FAKE.roster[3][9] = true
ns.Guild.Scan()

-- I'm available.
before = #SENT
check(D.SetAvailable({}, { "wc" }, 3600, "") == false, "needs a role")
check(D.SetAvailable({ h = true }, {}, 3600, "") == false, "needs a dungeon")
check(D.SetAvailable({ h = true, d = true }, { "wc", "sfk", "zzz" }, 3600, "Keen") == true, "marked available")
local avl = Sent("AVL", before + 1)
check(#avl == 1 and avl[1].r == "hd" and #avl[1].ds == 2 and avl[1].note == "Keen", "AVL sent: healer/DPS, WC and SFK")
check(YeahNahMateDB.chars["Ned Jones"].avail ~= nil, "kept for a /reload")
local av = D.Available()
check(#av == 1 and av[1].a.mine, "I'm listed as available")
-- Others available.
INJECT("YNM", Msg({ v = 1, t = "AVL", r = "t", ds = { "wc" }, u = now + 99999, note = "" }), "GUILD", "Bluey Heeler")
INJECT("YNM", Msg({ v = 1, t = "AVL", r = "q", ds = { "wc" }, u = now + 100 }), "GUILD", "Bingo Heeler")
Tick(1)
av = D.Available()
check(#av == 2 and av[2].name == "Bluey Heeler" and av[2].a.u <= GetServerTime() + 14400, "Bluey listed (capped at 4 hours); junk ignored")
-- A group posted for one of my dungeons pops up even if it's not at my level.
FAKE.level = 40
ns.Toast.Show("x", "y")
INJECT("YNM", Msg({ v = 1, t = "GRP", id = 80, d = "wc", me = "t", nt = 1, nh = 1, nd = 3, ht = 1, hh = 0, hd = 0,
    note = "", u = now + 3600 }), "GUILD", "Bandit Heeler")
Tick(1)
check(not D.AtMyLevel("wc"), "WC isn't at level 40")
FAKE.level = 22
-- My own card has a button to take me off the list; long dungeon lists say "+N more".
ns.UI.Open("dungeons")
local dpage
for _, o in ipairs(CREATED) do if o.availPager then dpage = o end end
dpage.pickView(2)
Tick(1)
local myCard
for _, c in ipairs(dpage.avail) do if c.who == "Ned Jones" then myCard = c end end
check(myCard and myCard.stop:IsShown() and not myCard.whisper:IsShown(), "my card has 'Take me off the list'")
local other
for _, c in ipairs(dpage.avail) do if c.who == "Bluey Heeler" then other = c end end
check(other and not other.stop:IsShown() and other.whisper:IsShown(), "others' cards have Whisper and Invite")
D.SetAvailable({ h = true }, { "wc", "sfk", "bfd", "stocks", "gnomer", "rfk", "smgy", "smlib", "rfd" }, 3600, "")
Tick(1)
check(myCard.what:GetText():find("+3 more", 1, true) and #myCard.allDungeons == 9, "nine dungeons: six shown, +3 more (hover for all)")
before = #SENT
myCard.stop:Click()
check(#Sent("AVL", before + 1) == 1 and D.MyAvail() == nil, "the card's button takes me off the list")
D.SetAvailable({ h = true, d = true }, { "wc", "sfk" }, 3600, "Keen")
Tick(1)

-- Stop, and expiry.
before = #SENT
D.StopAvailable()
avl = Sent("AVL", before + 1)
check(#avl == 1 and avl[1].x == true and #D.Available() == 1, "stop tells the guild")
Tick(14420)
check(#D.Available() == 0, "Bluey's availability ran out")

-- Sim mode: fake groups and availables; posting brings fake sign-ups; Invite makes them join.
SlashCmdList.YEAHNAHMATE("dev sim on")
Tick(15)
local fakeGroups = 0
for _, gg in ipairs(D.Groups()) do if ns.Sim.IsFake(gg.owner) then fakeGroups = fakeGroups + 1 end end
check(fakeGroups == 2, "two fake groups (" .. fakeGroups .. ")")
check(#D.Available() == 2, "two fake guildies available")
D.Post("rfc", "h", { t = 1, h = 1, d = 3 }, "")
Tick(10)
apps = D.Applicants()
check(#apps == 2 and ns.Sim.IsFake(apps[1].name), "two fake guildies signed up")
local invitesBefore = #INVITES
ns.UI.Invite(ns.Guild.Get(apps[1].name))
Tick(4)
check(#INVITES == invitesBefore and D.Applicants()[1].joined, "Invite on a fake: no real invite, counts as joined")

-- Click everything.
ns.UI.Open("dungeons")
for _, lvl in ipairs({ 5, 22, 60 }) do
    FAKE.level = lvl
    for pass = 1, 2 do
        local n = #CREATED
        for i = 1, n do
            local o = CREATED[i]
            if o._template == "UIPanelCloseButton" then o = { _scripts = {} } end
            if not IsInside(o, "YeahNahMateWhisper") and o._name ~= "YeahNahMateWelcome" then
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
for _, m in ipairs(SENT) do
    if m.channel == "WHISPER" and ns.Sim.IsFake(m.target) then check(false, "whispered a fake guildie: " .. m.target) end
    if #m.text > 255 then check(false, "message over 255 bytes") end
end
local realInvites = 0
for i = 2, #INVITES do if not ns.Sim.IsFake(INVITES[i]) then realInvites = realInvites + 1 end end
check(#WHISPERS == 0, "clicking around sent no chat whispers")
SlashCmdList.YEAHNAHMATE("dev sim off")
Tick(1)

check(#UISpecialFrames == 0 and PanelManagerCalls == 0, "no taint tripwires touched")
check(#ERRORS == 0, "no errors (" .. (ERRORS[1] or "none") .. ")")
