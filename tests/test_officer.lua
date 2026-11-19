-- Officers remove a question or someone's posts on it (12 Nov 2026), and rank markers on the Roster.
math.randomseed(43)
YeahNahMateDB = nil
FAKE.myRank, FAKE.myRankName = 0, "Guild Master"       -- I'm the guild master here
local ns = LoadAddon("YeahNahMate", "YeahNahMate")
LOGGED_IN = true
FireEvent("PLAYER_LOGIN")
local Ser = LibStub("AceSerializer-3.0")
local function Msg(t) return Ser:Serialize(t) end
local function Sent(from)
    local out = {}
    for i = from, #SENT do
        local ok, m = Ser:Deserialize(SENT[i].text)
        if ok and type(m) == "table" then out[#out + 1] = m end
    end
    return out
end
ns.settings.sharePosition, ns.settings.shareProfessions = false, false
for _, name in ipairs({ "Bluey Heeler", "Chilli Heeler", "Bingo Heeler" }) do
    INJECT("YNM", Msg({ v = 1, t = "HI", ver = "0.10.1" }), "GUILD", name)
end
Tick(15)
local Q = ns.Questions
local UI = ns.UI
local now = GetServerTime()

-- Rank markers -----------------------------------------------------------------------------------
local ned, bluey, chilli = ns.Guild.Get("Ned Jones"), ns.Guild.Get("Bluey Heeler"), ns.Guild.Get("Chilli Heeler")
check(UI.RankIcon(ned) == UI.RANK_GM and UI.RankIcon(bluey) == UI.RANK_SECOND and UI.RankIcon(chilli) == nil,
    "crown for the guild master, silver for the rank under, nothing for members")
ns.UI.Open("roster")
Tick(1)
local roster
for _, o in ipairs(CREATED) do if o.rows and o.heads and o.ranks then roster = o end end
local shown = {}
for _, r in ipairs(roster.rows) do if r:IsShown() and r.m then shown[r.m.name] = r.cells[3]:GetText() end end
check(shown["Ned Jones"]:find("LeaderIcon", 1, true) and shown["Bluey Heeler"]:find("AssistantIcon", 1, true)
    and not shown["Chilli Heeler"]:find("|T", 1, true), "the Roster shows them by the names")
check(roster.ranks:GetText():find("Guild Master", 1, true) and roster.ranks:GetText():find("Officer", 1, true),
    "the key under the Roster names the guild's own ranks")
-- The guild master lets members edit the guild info too: members get the officer shield.
local b = ns.Board.Store()
b.rank = { er = 3, ev = now }
check(UI.RankIcon(chilli) == UI.RANK_OFFICER, "an officer rank further down gets the shield")
UI.Dirty(); Tick(1)
check(roster.ranks:GetText():find("MainTankIcon", 1, true) and roster.ranks:GetText():find("Member", 1, true), "and the key says which")
b.rank = nil

-- Removing ---------------------------------------------------------------------------------------
local function Ask(from, id, tx)
    INJECT("YNM", Msg({ v = 1, t = "QQ", id = id, tx = tx, tp = "other", u = now + 3600, at = now, ev = now }), "GUILD", from)
end
local function Post(owner, id, from, tx, pv)
    INJECT("YNM", Msg({ v = 1, t = "QA", o = owner, id = id, p = { { tx = tx, at = now } }, pv = pv or now }), "GUILD", from)
end
Ask("Chilli Heeler", 100, "Rude question")
Ask("Bingo Heeler", 101, "Where's the bank?")
Post("Bingo Heeler", 101, "Chilli Heeler", "Rude answer")
Post("Bingo Heeler", 101, "Bluey Heeler", "Next to the auction house")
Tick(1)
check(Q.CanRemove(), "the guild master can remove")

local first = #SENT + 1
check(Q.Remove("Chilli Heeler:100"), "remove a question")
local qm
for _, m in ipairs(Sent(first)) do if m.t == "QM" then qm = m end end
check(qm and qm.o == "Chilli Heeler" and qm.id == 100 and qm.who == nil and qm.by == nil, "it goes to the guild")
check(Q.State(Q.Get("Chilli Heeler:100")) == "removed", "its state is removed")
local inOpen = false
for _, q in ipairs(Q.List("open")) do if q.key == "Chilli Heeler:100" then inOpen = true end end
check(not inOpen, "and it's gone from the list")
check(not Q.Remove("Chilli Heeler:100"), "can't remove it twice")

check(Q.Remove("Bingo Heeler:101", "Chilli Heeler"), "remove one guildie's posts on a card")
local q101 = Q.Get("Bingo Heeler:101")
local who = {}
for _, p in ipairs(Q.Thread(q101)) do who[p.name] = true end
check(not who["Chilli Heeler"] and who["Bluey Heeler"] and Q.AnswerCount(q101) == 1, "their posts are hidden, others stay")
-- Their resend (they missed it) stays hidden.
Post("Bingo Heeler", 101, "Chilli Heeler", "Rude answer again", now + 5)
Tick(1)
who = {}
for _, p in ipairs(Q.Thread(q101)) do who[p.name] = true end
check(not who["Chilli Heeler"], "a resend from them stays hidden")
check(not Q.Remove("Bingo Heeler:101", "Ned Jones") and not Q.Remove("Bingo Heeler:101", "Bandit Heeler"),
    "not my own posts, and not someone with none")

-- From others: only an editor rank, checked against my roster.
Ask("Bingo Heeler", 102, "Best bag for 10 silver?")
Post("Bingo Heeler", 102, "Bluey Heeler", "Linen bag")
Tick(1)
INJECT("YNM", Msg({ v = 1, t = "QM", o = "Bingo Heeler", id = 102, ev = now }), "GUILD", "Chilli Heeler")
Tick(1)
check(Q.State(Q.Get("Bingo Heeler:102")) == "open", "a member can't remove")
INJECT("YNM", Msg({ v = 1, t = "QM", o = "Bluey Heeler", id = 1, ev = now }), "GUILD", "Bluey Heeler")
Tick(1)
check(Q.Removed()["Bluey Heeler:1"] == nil, "nobody removes their own question that way")
INJECT("YNM", Msg({ v = 1, t = "QM", o = "Bingo Heeler", id = 102, who = "Bluey Heeler", ev = now }), "GUILD", "Bluey Heeler")
Tick(1)
check(Q.Removed()["Bingo Heeler:102|Bluey Heeler"] == nil, "nor their own posts")
INJECT("YNM", Msg({ v = 1, t = "QM", o = "Bingo Heeler", id = 102, ev = now + 2 }), "GUILD", "Bluey Heeler")
Tick(1)
check(Q.State(Q.Get("Bingo Heeler:102")) == "removed" and Q.RemovedBy(Q.Get("Bingo Heeler:102")) == "Bluey Heeler",
    "an officer can")
-- Two officers removed the same thing: everyone keeps the earliest.
b.rank = { er = 3, ev = now }                            -- (Chilli is an officer for this bit)
INJECT("YNM", Msg({ v = 1, t = "QM", o = "Bingo Heeler", id = 102, ev = now + 4 }), "GUILD", "Chilli Heeler")
Tick(1)
check(Q.Removed()["Bingo Heeler:102"].by == "Bluey Heeler", "two officers remove the same thing: a later one changes nothing")
INJECT("YNM", Msg({ v = 1, t = "QM", o = "Bingo Heeler", id = 102, ev = now + 1 }), "GUILD", "Chilli Heeler")
Tick(1)
local r102 = Q.Removed()["Bingo Heeler:102"]
check(r102.by == "Chilli Heeler" and r102.ev == now + 1, "an earlier one takes its place (everyone keeps the earliest)")
b.rank = nil
-- A copy that wasn't asked for is dropped.
INJECT("YNM", Msg({ v = 1, t = "QM", o = "Bingo Heeler", id = 101, ev = now, by = "Bluey Heeler" }), "WHISPER", "Chilli Heeler")
Tick(1)
check(Q.Removed()["Bingo Heeler:101"] == nil, "an unasked copy is dropped")

-- My own posts removed: I can't post there again, and the card says so.
Ask("Bingo Heeler", 103, "Who's tanking tonight?")
Tick(1)
Q.Post("Bingo Heeler:103", "Me!")
INJECT("YNM", Msg({ v = 1, t = "QM", o = "Bingo Heeler", id = 103, who = "Ned Jones", ev = now + 3 }), "GUILD", "Bluey Heeler")
Tick(61)
local ok, why = Q.Post("Bingo Heeler:103", "Me again")
check(not ok and why == "removed", "my posts removed: no more posting there")

-- My question removed: it still takes one of my 3 places until its 48 hours are up, because guildies
-- who haven't heard of the removal yet still count it (soak, 12 Nov: they dropped my oldest instead).
local function Mine()
    local n = 0
    for _, q in pairs(Q.Store()) do if q.owner == ns.me and not q.stub and not q.x and now < (q.u or 0) + 100 then n = n + 1 end end
    return n
end
local k1 = Q.Ask("My first question", "other"); Tick(61)
local k2 = Q.Ask("My second question", "other"); Tick(61)
local k3 = Q.Ask("My third question", "other"); Tick(61)
local q1 = Q.Get(k1)
INJECT("YNM", Msg({ v = 1, t = "QM", o = "Ned Jones", id = q1.id, ev = GetServerTime() }), "GUILD", "Bluey Heeler")
Tick(1)
check(Q.State(q1) == "removed", "an officer removed my question")
local k4, why4 = Q.Ask("My fourth question", "other")
check(k4 == nil and why4 == "full", "it still counts towards my 3 open questions")
for _, k in ipairs({ k2, k3 }) do Q.Cancel(k) end
Tick(61)
-- Points: a removed answer that helped doesn't count; a removed question's don't either.
for i = 1, 3 do
    Ask("Bandit Heeler", 110 + i, "Thing " .. i)
    Post("Bandit Heeler", 110 + i, "Bluey Heeler", "Answer " .. i)
    INJECT("YNM", Msg({ v = 1, t = "QQ", id = 110 + i, ev = now + 10, x = "done", hp = { "Bluey Heeler" } }), "GUILD", "Bandit Heeler")
end
Tick(1)
ns.Fire("QUESTIONS")
check(Q.Points("Bluey Heeler") == 3 and Q.LoreMaster() == "Bluey Heeler", "three points: Lore Master")
Q.Remove("Bandit Heeler:111", "Bluey Heeler")
check(Q.Points("Bluey Heeler") == 2 and Q.LoreMaster() == nil, "a removed answer loses its point")
Q.Remove("Bandit Heeler:112")
check(Q.Points("Bluey Heeler") == 1, "a removed question loses its points")

-- Sync: an officer's removals are counted and sent at log-in, as copies to whoever asks.
local vers = ns.Sync.Versions("questions", "Ned Jones")
local n = 0
for _, v in ipairs(vers) do if v == r102.ev then n = n + 1 end end
check(n == 0, "someone else's removal isn't counted as mine")
local mine = 0
for _, r in pairs(Q.Removed()) do if r.by == "Ned Jones" then mine = mine + 1 end end
local msgs, rm = Q.MyMessages(), 0
for _, m in ipairs(msgs) do if m.t == "QM" then rm = rm + 1 end end
check(rm == mine and mine == 4, "my removals go out at log-in (" .. rm .. " of " .. mine .. ")")
first = #SENT + 1
INJECT("YNM", Msg({ v = 1, t = "REQ", w = "QS" }), "WHISPER", "Bandit Heeler")
Tick(5)
local copies, cardOut = 0, false
for _, m in ipairs(Sent(first)) do
    if m.t == "QM" then copies = copies + 1 end
    if m.t == "QQ" and m.o == "Chilli Heeler" and m.id == 100 then cardOut = true end
end
check(copies == mine + 3 and not cardOut, "copies carry every removal, and not the removed question")

-- The Ask tab: Remove on someone else's card, asks first, then it's gone.
Ask("Bandit Heeler", 120, "Spam spam spam")
Post("Bandit Heeler", 120, "Chilli Heeler", "More spam")
Tick(1)
UI.ShowQuestion("Bandit Heeler:120")
Tick(1)
local page
for _, o in ipairs(CREATED) do if o.listView and o.cardView then page = o end end
local v = page.cardView
check(v.remove:IsShown() and not v.cancel:IsShown(), "an officer sees Remove question")
local row
for _, r in ipairs(v.posts) do if r:IsShown() and r.post and r.post.name == "Chilli Heeler" then row = r end end
check(row and row.del:IsShown(), "and an x on others' posts")
row.del:Click()
Tick(1)
check(v.rmAsk:IsShown() and v.rmAsk:GetText():find("Chilli", 1, true) and v.rmYes:IsShown(), "the x asks first")
v.rmNo:Click()
Tick(1)
check(not v.rmAsk:IsShown() and not Q.PostsRemoved(Q.Get("Bandit Heeler:120"), "Chilli Heeler"), "Cancel leaves it")
row.del:Click(); Tick(1)
v.rmYes:Click(); Tick(1)
check(Q.PostsRemoved(Q.Get("Bandit Heeler:120"), "Chilli Heeler"), "Remove removes their posts")
v.remove:Click(); Tick(1)
check(v.rmAsk:GetText() == ns.L.Q_REMOVE_ASK_Q, "Remove question asks first")
v.rmYes:Click(); Tick(1)
check(Q.State(Q.Get("Bandit Heeler:120")) == "removed" and page.openKey == nil, "and goes back to the list")

-- A member sees neither.
FAKE.myRank = 3
FireEvent("GUILD_ROSTER_UPDATE"); FireEvent("PLAYER_GUILD_UPDATE"); Tick(5)
ns.Guild.myRank = 3
check(not Q.CanRemove(), "a member can't remove")
Ask("Bandit Heeler", 121, "Fine question")
Post("Bandit Heeler", 121, "Bluey Heeler", "Fine answer")
Tick(1)
UI.ShowQuestion("Bandit Heeler:121"); Tick(1)
row = nil
for _, r in ipairs(v.posts) do if r:IsShown() and r.post and r.post.name == "Bluey Heeler" then row = r end end
check(not v.remove:IsShown() and row and not row.del:IsShown(), "a member sees no Remove and no x on others' posts")
check(not Q.Remove("Bandit Heeler:121"), "and Remove refuses")
ns.Guild.myRank = 0
FAKE.myRank = 0

-- Tidy: old removals go.
Q.Removed()["Old Timer:1"] = { o = "Old Timer", id = 1, by = "Ned Jones", ev = now - Q.RM_KEEP - 10 }
Q.Tidy()
check(Q.Removed()["Old Timer:1"] == nil, "removals older than any card they could hide are tidied")

-- Sim mode: removing a fake's question stays on my screen.
ns.devCommands.sim("on")
Tick(70)
local bazza
for _, q in ipairs(Q.List("open")) do if q.owner == "Bazza Stubbs" then bazza = q end end
first = #SENT + 1
check(bazza and Q.Remove(bazza.key), "remove a fake's question in sim mode")
local leaked = false
for _, m in ipairs(Sent(first)) do if m.t == "QM" then leaked = true end end
check(not leaked, "nothing about it goes out")
-- The sim's own: Kezza posts rubbish on Macca's new question, then Bazza (a fake officer) removes it.
Tick(15)
local macca
for _, q in ipairs(Q.List("open")) do if q.owner == "Macca Ute" then macca = q end end
local function KezzaShows()
    for _, p in ipairs(Q.Thread(macca)) do if p.name == "Kezza Galah" then return true end end
    return false
end
check(macca and KezzaShows(), "sim: Kezza's rubbish answer shows")
Tick(35)
check(not KezzaShows() and Q.PostsRemoved(macca, "Kezza Galah"), "sim: then Bazza removes it")
ns.devCommands.sim("off")
Tick(2)
check(#ERRORS == 0, "no errors (" .. (ERRORS[1] or "none") .. ")")
