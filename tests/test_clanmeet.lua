-- Clan meetings: who may run one, asking by the button (CAK) and by whispering "inv", the invite list
-- (Was here > Asked > Close > Same zone > Online > In group > Offline), one invite per click, Invite
-- next, Disband (two clicks; who was in the group goes to the top), the member's side (pop-up, Ask),
-- ending, and that nothing is ever sent back to a whisper.
math.randomseed(31)
YeahNahMateDB = nil
FAKE.myRank = 0                 -- I'm the guild master here (Ned Jones): I may run any clan's meeting
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
local CM, Cl, UI, L = ns.ClanMeet, ns.Clans, ns.UI, ns.L
ns.settings.sharePosition, ns.settings.shareProfessions = false, false
function UnitRace() return "Orc", "Orc", 2 end
Tick(15)
-- Races: Bluey (Officer, rank 1) and Bingo are Orcs, Chilli a Troll, Bandit (offline) an Orc.
INJECT("YNM", Msg({ v = 1, t = "HI", ver = ns.VERSION, ra = "Orc", ro = "t" }), "GUILD", "Bluey Heeler")
INJECT("YNM", Msg({ v = 1, t = "HI", ver = ns.VERSION, ra = "Orc", ro = "h" }), "GUILD", "Bingo Heeler")
INJECT("YNM", Msg({ v = 1, t = "HI", ver = ns.VERSION, ra = "Troll", ro = "d" }), "GUILD", "Chilli Heeler")
INJECT("YNM", Msg({ v = 1, t = "ME", ra = "Orc", ro = "" }), "GUILD", "Bandit Heeler")
Tick(2)

-- Who may run it: the guild master, a Clan moderator rank (ranks 0-1 by default), the clan's leader.
check(CM.CanRun("Ned Jones", "Orc") and CM.CanRun("Bluey Heeler", "Orc") and not CM.CanRun("Bingo Heeler", "Orc"),
    "the guild master and an officer may run the Orcs' meeting; a member may not")

-- A member's meeting message is dropped.
INJECT("YNM", Msg({ v = 1, t = "CMT", r = "Orc", on = true }), "GUILD", "Bingo Heeler")
Tick(1)
check(CM.ActiveFor("Orc") == nil, "a member can't start a clan meeting")

-- I start the Orcs' meeting.
local before = #SENT
check(CM.Start("Orc"), "I start the Orc clan's meeting")
local cmt = Sent("CMT", before + 1)
check(#cmt == 1 and cmt[1].r == "Orc" and cmt[1].on == true and cmt[1]._channel == "GUILD", "CMT on, to the guild")

-- Asking: Bingo by the button; Chilli (a Troll) whispers "inv pls"; noise ignored.
local whispersBefore = #WHISPERS
INJECT("YNM", Msg({ v = 1, t = "CAK", r = "Orc" }), "WHISPER", "Bingo Heeler")
INJECT("YNM", Msg({ v = 1, t = "CAK", r = "Troll" }), "WHISPER", "Bluey Heeler")     -- wrong clan's meeting
Tick(1)
FireEvent("CHAT_MSG_WHISPER", "inv pls!", "Chilli Heeler-SERVER1Realm1PvE", "", "", "", "", 0, 0, "", 0, 1, "Player-6797-00000003")
FireEvent("CHAT_MSG_WHISPER", "hey can I get an inv later", "Bluey Heeler", "", "", "", "", 0, 0, "", 0, 2, "x")
FireEvent("CHAT_MSG_WHISPER", "inv", "Random Stranger", "", "", "", "", 0, 0, "", 0, 3, "x")
FireEvent("CHAT_MSG_WHISPER", "inv", "Ned Jones", "", "", "", "", 0, 0, "", 0, 4, "x")
Tick(1)
local mine = CM.Mine()
check(mine.asks["Bingo Heeler"] and mine.asks["Bingo Heeler"].how == "b", "Bingo asked by the button")
check(mine.asks["Chilli Heeler"] and mine.asks["Chilli Heeler"].how == "w", "Chilli asked by whispering 'inv pls!'")
check(not mine.asks["Bluey Heeler"] and not mine.asks["Random Stranger"] and not mine.asks["Ned Jones"],
    "a chatty whisper, a stranger, myself and the wrong clan's ask don't count")
check(#WHISPERS == whispersBefore, "nothing whispered back")

-- The list: Asked (Bingo, then Chilli from another clan), Online (Bluey), Offline (Bandit).
local function Names(list)
    local out = {}
    for _, r in ipairs(list) do out[#out + 1] = r.name:match("^%S+") .. ":" .. r.state end
    return table.concat(out, ",")
end
check(Names(CM.List()) == "Bingo:asked,Chilli:asked,Bluey:zone,Bandit:offline", "the invite list in order", Names(CM.List()))
check(CM.List()[2].other == true, "Chilli is marked as another clan")

-- Invite next: Bingo, then Chilli (Bingo was just invited), then Bluey.
check(CM.InviteNext() == "Bingo Heeler" and INVITES[#INVITES] == "Bingo Heeler", "Invite next: Bingo first")
check(CM.InviteNext() == "Chilli Heeler", "then Chilli (Bingo invited a moment ago)")
check(CM.InviteNext() == "Bluey Heeler", "then Bluey")
check(CM.Next() == nil, "nobody else to invite (Bandit's offline)")

-- They join: in my group, at the bottom with a tick.
FAKE.group, FAKE.leader = 4, true
local realKeys = ns.Gather.GroupKeys
ns.Gather.GroupKeys = function() return { ["Bingo Heeler"] = true, ["Chilli Heeler"] = true, ["Bluey Heeler"] = true } end
check(Names(CM.List()) == "Bingo:ingroup,Bluey:ingroup,Chilli:ingroup,Bandit:offline", "in the group, then offline",
    Names(CM.List()))
check(select(1, CM.Counts()) == 4, "4 in the group (with me)")

-- The tab: my clan's list is the invite list; the bar shows the meeting's buttons.
UI.Open("clans")
Tick(1)
local page
for _, o in ipairs(CREATED) do if o.cols and o.bar then page = o end end
local orc = page.cols[1]
check(orc.count:GetText():find("4 in group", 1, true), "the Orc list says the meeting's counts", orc.count:GetText())
check(orc.rows[1].name:GetText():find("ReadyCheck", 1, true), "in the group: a tick")
check(page.bar.next:IsShown() and page.bar.disband:IsShown() and page.bar.stop:IsShown() and not page.bar.start:IsShown(),
    "bar: Invite next, Disband, Stop")

-- Disband: two clicks. Uninvites everyone in the group; they're kept as Was here.
local uninvited = {}
function UninviteUnit(name) uninvited[#uninvited + 1] = name end
page.bar.disband:Click(); Tick(1)
check(#uninvited == 0 and page.bar.disband:GetText():find(L.CLAN_DISBAND_SURE, 1, true), "first click: Sure? Disband")
page.bar.disband:Click(); Tick(1)
check(#uninvited == 3, "second click: everyone out of the group", #uninvited)
FAKE.group, FAKE.leader = 0, false
ns.Gather.GroupKeys = realKeys
UI.Dirty(); Tick(1)
check(Names(CM.List()) == "Bingo:here,Bluey:here,Chilli:here,Bandit:offline", "who was here goes to the top", Names(CM.List()))
check(orc.rows[1].tint:IsShown(), "was here: a gold row")
-- After 30 minutes they're ordinary again.
Tick(1810)
check(CM.List()[1].state ~= "here", "Was here lasts 30 minutes")
-- Clicking a green name invites.
FireEvent("CHAT_MSG_WHISPER", "invite", "Bingo Heeler", "", "", "", "", 0, 0, "", 0, 9, "x")
Tick(1)
UI.Dirty(); Tick(1)
local n = #INVITES
check(orc.rows[1].m.name == "Bingo Heeler" and orc.rows[1].tint:IsShown(), "Bingo green again after whispering")
orc.rows[1]:Click(); Tick(1)
check(#INVITES == n + 1 and INVITES[#INVITES] == "Bingo Heeler", "clicking a green name invites them")

-- Stop.
before = #SENT
page.bar.stop:Click(); Tick(1)
check(CM.Mine() == nil and Sent("CMT", before + 1)[1].on == nil, "Stop: CMT off")
check(page.bar.start:IsShown() and page.bar.start:GetText():find("Orc", 1, true), "bar: Start meeting: Orc")

-- The member's side: Bluey (an officer) starts the Orcs' meeting -> pop-up, Ask for an invite.
INJECT("YNM", Msg({ v = 1, t = "CMT", r = "Orc", on = true }), "GUILD", "Bluey Heeler")
Tick(1)
check(CM.ActiveFor("Orc") and CM.ActiveFor("Orc").organiser == "Bluey Heeler", "Bluey's meeting is on")
check(orc.count:GetText():find("Bluey", 1, true), "the Orc list says so")
check(page.bar.ask:IsShown() and page.bar.ask:IsEnabled(), "bar: Ask for an invite")
before = #SENT
page.bar.ask:Click(); Tick(1)
local cak = Sent("CAK", before + 1)
check(#cak == 1 and cak[1]._target == "Bluey Heeler" and cak[1].r == "Orc", "Ask: CAK whispered to Bluey")
check(not page.bar.ask:IsEnabled(), "and the button says Asked")
-- Bluey logs off: the meeting ends.
FAKE.roster[2][9] = false
FireEvent("GUILD_ROSTER_UPDATE"); Tick(2)
check(CM.ActiveFor("Orc") == nil, "the organiser logged off: meeting over")
FAKE.roster[2][9] = true
FireEvent("GUILD_ROSTER_UPDATE"); Tick(2)

-- Whispers while no meeting of mine is on: nothing noted.
FireEvent("CHAT_MSG_WHISPER", "inv", "Bingo Heeler", "", "", "", "", 0, 0, "", 0, 10, "x")
check(CM.Mine() == nil, "no meeting: whispers are left alone")

check(#ns.db.errors == 0, "no errors", ns.db.errors[1] and ns.db.errors[1].msg)
