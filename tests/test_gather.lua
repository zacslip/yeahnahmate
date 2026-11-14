-- Gathering for an event: who may gather, asking for an invite, the Gather list, Invite next (one per
-- click), make it a raid, late joiners, impostors, ending, the pop-up and Home, sim.
math.randomseed(10)
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
            m._target = SENT[i].target; m._channel = SENT[i].channel; list[#list + 1] = m
        end
    end
    return list
end
local G, C = ns.Gather, ns.Calendar
ns.settings.sharePosition, ns.settings.shareProfessions = false, false
INJECT("YNM", Msg({ v = 1, t = "HI", ver = "0.8.0" }), "GUILD", "Bluey Heeler")
Tick(15)
local now = GetServerTime()

-- My event tonight; Bluey, Bingo and Bandit (offline) are going.
local key = C.Save(nil, { title = "Guild meeting", at = now + 1800, k = "s" })
local e = C.Store()[key]
for _, who in ipairs({ "Bluey Heeler", "Bingo Heeler", "Bandit Heeler" }) do
    INJECT("YNM", Msg({ v = 1, t = "RSVP", o = "Ned Jones", id = e.id, at = e.at, a = "y", rv = now }), "GUILD", who)
end
Tick(1)
local later = C.Save(nil, { title = "Next week", at = now + 7 * 86400, k = "s" })
check(G.Start(later, C.Store()[later].at) == false, "can't gather for an event that isn't today")

-- Start gathering: the guild hears.
local before = #SENT
check(G.Start(key, e.at) == true and G.Mine() ~= nil, "started gathering for my event")
local gth = Sent("GTH", before + 1)
check(#gth == 1 and gth[1]._channel == "GUILD" and gth[1].on == true and gth[1].o == "Ned Jones" and gth[1].at == e.at, "the guild hears it's on")

-- Asks for an invite: only by whisper, only for this gathering.
INJECT("YNM", Msg({ v = 1, t = "GAK", o = "Ned Jones", id = e.id, at = e.at }), "WHISPER", "Bluey Heeler")
INJECT("YNM", Msg({ v = 1, t = "GAK", o = "Ned Jones", id = e.id, at = e.at }), "GUILD", "Chilli Heeler")
INJECT("YNM", Msg({ v = 1, t = "GAK", o = "Ned Jones", id = e.id + 99, at = e.at }), "WHISPER", "Chilli Heeler")
INJECT("YNM", Msg({ v = 1, t = "GAK", o = "Ned Jones", id = e.id, at = e.at }), "WHISPER", "Stranger Danger")
Tick(1)
local list = G.List()
local function State(name) for _, r in ipairs(list) do if r.name == name then return r.state end end end
check(list[1].name == "Bluey Heeler" and list[1].state == "asked", "Bluey asked: top of the list")
check(State("Bingo Heeler") == "going" and State("Bandit Heeler") == "offline", "Bingo going (online), Bandit going (offline)")
check(State("Chilli Heeler") == nil and State("Stranger Danger") == nil, "asks on the guild channel, for another event, or from strangers don't count")

-- Invite next: one invite per click, Bluey then Bingo; nobody invited by itself.
check(#INVITES == 0, "nobody invited yet")
check(G.InviteNext() == "Bluey Heeler" and INVITES[#INVITES] == "Bluey Heeler", "Invite next: Bluey")
check(G.InviteNext() == "Bingo Heeler" and #INVITES == 2, "Invite next again: Bingo (Bluey was just invited)")
check(G.InviteNext() == nil and #INVITES == 2, "then nobody waiting (Bandit's offline)")

-- Bluey joins: in the group. Make it a raid (the leader's click) once in a party.
FAKE.party, FAKE.group, FAKE.leader = { "Bluey Heeler" }, 2, true
FireEvent("GROUP_ROSTER_UPDATE")
list = G.List()
check(State("Bluey Heeler") == "ingroup" and G.InGroupCount() == 2, "Bluey's in the group (2 with me)")
check(G.CanMakeRaid(), "leading a party: can make it a raid")
G.MakeRaid()
check(RAID_CONVERTS == 1 and not G.CanMakeRaid(), "made it a raid")

-- A guildie who logs in hears about it by whisper.
FAKE.roster[5][9] = true
ns.Guild.Scan()
before = #SENT
INJECT("YNM", Msg({ v = 1, t = "HI", ver = "0.8.0", ask = true }), "GUILD", "Bandit Heeler")
Tick(8)
gth = Sent("GTH", before + 1, function(m, s) return s.target == "Bandit Heeler" end)
check(#gth == 1 and gth[1].on, "Bandit (just logged in) hears the gathering's on")

-- The Calendar tab: Gather button on my event, the Gather list, Invite next, Stop.
ns.UI.Open("calendar")
local cal
for _, o in ipairs(CREATED) do if o.gatherFrame then cal = o end end
cal.mode = nil
ns.UI.Select("calendar")
Tick(1)
local card
for _, b in ipairs(cal.details) do if b.key == key and b:IsShown() then card = b end end
check(card and card.gather:IsShown() and card.gather:GetText() == ns.L.GATHER_OPEN, "my event's card has the Gather (list) button")
card.gather:Click()
Tick(1)
check(cal.gatherFrame:IsShown() and cal.gatherFrame.rows[1]:IsShown(), "it opens the Gather list")
check(cal.gatherFrame.next:GetText():find("Invite next", 1, true) or cal.gatherFrame.next:GetText() == ns.L.NOBODY_WAITING, "the Invite next button")
before = #SENT
cal.gatherFrame.stop:Click()
Tick(1)
gth = Sent("GTH", before + 1)
check(#gth == 1 and not gth[1].on and G.Mine() == nil and not cal.gatherFrame:IsShown(), "Stop gathering tells the guild")

-- Someone else gathering: Bluey (an officer) for Bluey's event; I'm going, so a pop-up to ask.
FAKE.party, FAKE.group, FAKE.leader, FAKE.raid = {}, 0, false, false
INJECT("YNM", Msg({ v = 1, t = "EVT", id = 900, ti = "Bluey's meeting", at = now + 1200, k = "s", nt = 0, nh = 0, nd = 0, note = "", ev = now }), "GUILD", "Bluey Heeler")
Tick(1)
local bkey = "Bluey Heeler:900"
local be = C.Store()[bkey]
C.Answer(bkey, be.at, "y")
INJECT("YNM", Msg({ v = 1, t = "GTH", o = "Bluey Heeler", id = 900, at = be.at, on = true }), "GUILD", "Bingo Heeler")
Tick(1)
check(G.ActiveFor(bkey, be.at) == nil, "Bingo (not the owner or an officer) can't gather for Bluey's event")
local pops = 0
ns.Listen("GATHER_STARTED", function() pops = pops + 1 end)
INJECT("YNM", Msg({ v = 1, t = "GTH", o = "Bluey Heeler", id = 900, at = be.at, on = true }), "GUILD", "Bluey Heeler")
Tick(1)
check(G.ActiveFor(bkey, be.at) and pops == 1 and ns.Toast.IsShown(), "Bluey's gathering: a pop-up for me (I'm going)")
before = #SENT
local toastBtn
for _, o in ipairs(CREATED) do if o._text == ns.L.ASK_SHORT and o._parent and o._parent.title and o._parent.show == o then toastBtn = o end end
check(toastBtn ~= nil, "the pop-up has an Ask to join button")
toastBtn:Click()
local gak = Sent("GAK", before + 1)
check(#gak == 1 and gak[1]._target == "Bluey Heeler" and gak[1].id == 900 and G.HaveAsked(bkey, be.at), "asked Bluey for an invite (addon whisper, not chat)")
check(#WHISPERS == 0, "no chat whisper was sent")
-- The card and Home show it.
ns.UI.Open("home")
local home
for _, o in ipairs(CREATED) do if o.next and o.live then home = o end end
local homeRow
for _, r in ipairs(home.next) do if r.key == bkey then homeRow = r end end
check(homeRow and homeRow.when:GetText():find("Gathering now", 1, true) and homeRow.ask:IsShown() and not homeRow.ask:IsEnabled(),
    "Home: 'Gathering now' with the Ask button (greyed: already asked)")

-- Ends when the organiser goes offline, or 3 hours after the start.
FAKE.roster[2][9] = false
ns.Guild.Scan()
check(G.ActiveFor(bkey, be.at) == nil, "Bluey logged off: the gathering's gone")
FAKE.roster[2][9] = true
ns.Guild.Scan()
INJECT("YNM", Msg({ v = 1, t = "GTH", o = "Bluey Heeler", id = 900, at = be.at, on = true }), "GUILD", "Bluey Heeler")
Tick(1)
Tick(3 * 3600 + 1300, 60)
check(G.ActiveFor(bkey, be.at) == nil, "and it ends 3 hours after the start")

-- Sim: my gathering brings five fake asks; Invite on a fake counts them in; /ynm dev gather.
SlashCmdList.YEAHNAHMATE("dev sim on")
Tick(16)
local today = C.Save(nil, { title = "Sim meeting", at = GetServerTime() + 600, k = "s" })
G.Start(today, C.Store()[today].at)
Tick(10)
local asked = 0
for _, r in ipairs(G.List()) do if r.state == "asked" then asked = asked + 1 end end
check(asked == 5, "five fake guildies asked for an invite (" .. asked .. ")")
local invitesBefore = #INVITES
G.InviteNext()
check(#INVITES == invitesBefore, "inviting a fake sends no real invite")
local inGroup = 0
for _, r in ipairs(G.List()) do if r.state == "ingroup" then inGroup = inGroup + 1 end end
check(inGroup == 1, "the fake counts as in the group")
G.Stop()
SlashCmdList.YEAHNAHMATE("dev gather")
Tick(2)
local bazza
for id, a in pairs(G.active) do if a.organiser == "Bazza Stubbs" then bazza = a end end
check(bazza ~= nil, "/ynm dev gather: Bazza's gathering")
before = #SENT
G.AskInvite(bazza.key, bazza.at)
check(#Sent("GAK", before + 1) == 0 and G.HaveAsked(bazza.key, bazza.at), "asking a fake organiser sends nothing real")

-- Click everything on the Calendar with all of it going.
ns.UI.Open("calendar")
for pass = 1, 2 do
    local n = #CREATED
    for i = 1, n do
        local o = CREATED[i]
        if o._template == "UIPanelCloseButton" then o = { _scripts = {} } end
        if o._name ~= "YeahNahMateWhisper" and o._name ~= "YeahNahMateWelcome" then
            for _, s in ipairs({ "OnClick", "OnMouseUp", "OnEnter", "OnLeave" }) do
                if o._scripts[s] then o._scripts[s](o, "LeftButton") end
            end
        end
    end
    Tick(1)
end
SlashCmdList.YEAHNAHMATE("dev sim off")
Tick(1)
for _, m in ipairs(SENT) do
    if m.channel == "WHISPER" and ns.Sim.IsFake(m.target) then check(false, "whispered a fake guildie: " .. m.target) end
end
check(#UISpecialFrames == 0 and PanelManagerCalls == 0, "no taint tripwires touched")
check(#ERRORS == 0, "no errors (" .. (ERRORS[1] or "none") .. ")")
