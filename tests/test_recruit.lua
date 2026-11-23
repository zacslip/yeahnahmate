-- Recruiters (Recruit.lua): sharing the addon with guildies who don't have it (noted only when the
-- whisper really goes), "who got you onto it" (once per person, final), the leaderboard (people not
-- characters, no self or alts, all time and this month), managers hiding a wrong claim, and copies.
math.randomseed(13)
YeahNahMateDB = nil
FAKE.myRank = 0
local ns = LoadAddon("YeahNahMate", "YeahNahMate")      -- I'm Ned Jones, the guild master
LOGGED_IN = true
FireEvent("PLAYER_LOGIN")
local Ser = LibStub("AceSerializer-3.0")
local function Msg(t) t.v = 1; return Ser:Serialize(t) end
local function Sent(t, from)
    local list = {}
    for i = (from or 1), #SENT do
        local ok, m = Ser:Deserialize(SENT[i].text)
        if ok and type(m) == "table" and m.t == t then list[#list + 1] = m end
    end
    return list
end
local R, L = ns.Recruit, ns.L
ns.settings.sharePosition, ns.settings.shareProfessions = false, false
Tick(15)
-- Bluey has the addon; Bingo and Chilli don't (yet); Bandit is offline.
INJECT("YNM", Msg({ t = "HI", ver = ns.VERSION }), "GUILD", "Bluey Heeler")
Tick(2)
-- Chilli is Bingo's alt (as the alt links would say).
local realPerson = ns.Alts.Person
ns.Alts.Person = function(n) if n == "Chilli Heeler" then return "Bingo Heeler" end return realPerson(n) end
local now = GetServerTime()

-- Who I can share with.
local names = {}
for _, c in ipairs(R.Candidates()) do names[#names + 1] = c.name end
check(table.concat(names, ",") == "Bingo Heeler,Chilli Heeler", "share list: online guildies without the addon", table.concat(names, ","))
check(not R.CanShareTo("Bluey Heeler") and not R.CanShareTo("Bandit Heeler") and not R.CanShareTo("Ned Jones"),
    "not to someone with the addon, someone offline, or me")

-- Share: the whisper box opens with my message; nothing is noted until the whisper goes.
local before = #SENT
check(R.Share("Bingo Heeler"), "Share opens the whisper box")
local box
for _, o in ipairs(CREATED) do if o.edit and o.edit.GetText and o.edit:GetText() == L.RECRUIT_MSG_DEFAULT then box = o end end
check(box ~= nil, "prefilled with the recruitment message")
check(#Sent("RSH", before + 1) == 0 and R.LastShare("Bingo Heeler") == nil, "nothing noted before it's sent")
ns.Fire("WHISPERED", "Bingo Heeler", L.RECRUIT_MSG_DEFAULT)
local rsh = Sent("RSH", before + 1)
check(#rsh == 1 and rsh[1].to == "Bingo Heeler" and rsh[1].o == nil, "sent: the share goes to the guild")
check(not R.CanShareTo("Bingo Heeler"), "one share per guildie per week")
check(R.Candidates()[1].shared ~= nil, "the list says I've shared with Bingo")
-- A whisper to someone I didn't press Share for doesn't count.
ns.Fire("WHISPERED", "Chilli Heeler", "hello")
check(R.LastShare("Chilli Heeler") == nil, "an ordinary whisper isn't a share")
-- My own message from Settings.
ns.settings.recruitMsg = "Get the addon mate"
check(R.Message() == "Get the addon mate", "Settings' message is used")
ns.settings.recruitMsg = "  "
check(R.Message() == L.RECRUIT_MSG_DEFAULT, "an empty one falls back to the default")
ns.settings.recruitMsg = nil

-- Bluey shared with me earlier: he's suggested.
INJECT("YNM", Msg({ t = "RSH", to = "Ned Jones", at = now - 3600 }), "GUILD", "Bluey Heeler")
Tick(1)
local sw = R.SharedWithMe()
check(#sw == 1 and sw[1].name == "Bluey Heeler", "who shared with me: Bluey")

-- My answer: once, final.
check(R.NeedsAnswer(), "not answered yet: the tab shows the !")
check(not R.Claim("Ned Jones") and not R.Claim("Nobody Here"), "not myself, not someone outside the guild")
check(R.CanBeRecruiter("Bandit Heeler") and R.CanBeRecruiter("Bingo Heeler"), "any guildie can be named, offline or not yet seen with the addon")
before = #SENT
check(R.Claim("Bluey Heeler"), "Bluey got me onto it")
local rcl = Sent("RCL", before + 1)
check(#rcl == 1 and rcl[1].by == "Bluey Heeler", "the answer goes to the guild")
check(not R.NeedsAnswer() and not R.Claim(""), "answered: final")

-- The leaderboard.
local lb = R.Leaderboard("all")
check(#lb == 1 and lb[1].name == "Bluey Heeler" and lb[1].n == 1 and lb[1].recruits[1] == "Ned Jones", "Bluey: 1 (me)")
-- Bingo says I got her on; Chilli (her alt) then says Bluey: one person, the first answer counts.
INJECT("YNM", Msg({ t = "RCL", by = "Ned Jones", at = now - 60 }), "GUILD", "Bingo Heeler")
INJECT("YNM", Msg({ t = "RCL", by = "Bluey Heeler", at = now - 30 }), "GUILD", "Chilli Heeler")
Tick(1)
lb = R.Leaderboard("all")
check(#lb == 2 and lb[1].n == 1 and lb[2].n == 1, "two recruiters with one each (Chilli is Bingo: her first answer counts)")
check(R.ClaimOf("Chilli Heeler").by == "Ned Jones", "Chilli's person already answered (as Bingo)")
check(select(1, R.MyPlace("all")) ~= nil, "I'm on it")
-- Not your own alt; not someone outside the guild; nothing from the future.
INJECT("YNM", Msg({ t = "RCL", by = "Bingo Heeler", at = now }), "GUILD", "Bandit Heeler")
Tick(1)
local lbBefore = #R.Leaderboard("all")
INJECT("YNM", Msg({ t = "RSH", to = "Nobody Atall", at = now }), "GUILD", "Bluey Heeler")
INJECT("YNM", Msg({ t = "RCL", by = "Bluey Heeler", at = now + 99999 }), "GUILD", "Bandit Heeler")
Tick(1)
check(R.ClaimOf("Bandit Heeler").by == "Bingo Heeler", "Bandit (a member, offline) said Bingo")
check(#R.Leaderboard("all") == lbBefore, "bad ones dropped")

-- This month vs all time: a claim from 40 days ago.
local s = R.Store()
s.claims["Bandit Heeler"] = { by = "Bluey Heeler", at = now - 40 * 86400 }
local all, month = R.Leaderboard("all"), R.Leaderboard("month")
local function N(list, who) for _, e in ipairs(list) do if e.name == who then return e.n end end return 0 end
check(N(all, "Bluey Heeler") == 2 and N(month, "Bluey Heeler") == 1, "all time 2, this month 1")
check(all[1].name == "Bluey Heeler", "most first")

-- Hiding: only the guild master or a manager.
INJECT("YNM", Msg({ t = "RHD", who = "Ned Jones", at = now }), "GUILD", "Bingo Heeler")
Tick(1)
check(N(R.Leaderboard("all"), "Bluey Heeler") == 2, "a member can't hide a claim")
before = #SENT
check(R.ICanHide() and R.Hide("Bandit Heeler"), "the guild master hides Bandit's claim")
check(#Sent("RHD", before + 1) == 1, "sent to the guild")
check(N(R.Leaderboard("all"), "Bluey Heeler") == 1, "Bluey back to 1")

-- Copies: only by whisper from a guildie we asked.
INJECT("YNM", Msg({ t = "RSH", o = "Bluey Heeler", to = "Chilli Heeler", at = now }), "GUILD", "Bingo Heeler")
Tick(1)
check(R.Store().shares["Bluey Heeler"]["Chilli Heeler"] == nil, "a copy on GUILD is ignored")
R.AskAll()
local req = Sent("REQ")
check(req[#req].w == "RCT", "after log-in I ask one guildie for everything")
INJECT("YNM", Msg({ t = "RSH", o = "Bluey Heeler", to = "Chilli Heeler", at = now }), "WHISPER", "Bluey Heeler")
Tick(1)
check(R.Store().shares["Bluey Heeler"]["Chilli Heeler"] ~= nil, "a copy by whisper from the one I asked: taken")
-- Asked for mine: everything goes back by whisper.
before = #SENT
INJECT("YNM", Msg({ t = "REQ", w = "RCT" }), "WHISPER", "Bingo Heeler")
Tick(1)
local whispered = 0
for i = before + 1, #SENT do if SENT[i].channel == "WHISPER" then whispered = whispered + 1 end end
check(whispered >= 5, "a guildie who asks gets what I hold", tostring(whispered))
check(#ns.Sync.Versions("recruit", "Ned Jones") >= 3, "sync: my share, claim and hide counted")

-- A guildie leaves: their side drops out.
for i, r in ipairs(FAKE.roster) do if r[1] == "Bingo-Heeler" then table.remove(FAKE.roster, i) break end end
FireEvent("GUILD_ROSTER_UPDATE")
Tick(3)
check(N(R.Leaderboard("all"), "Ned Jones") == 0, "Bingo left: my recruit no longer counts")

ns.Alts.Person = realPerson
check(#ns.db.errors == 0, "no errors " .. tostring(ns.db.errors[1] and ns.db.errors[1].msg))
