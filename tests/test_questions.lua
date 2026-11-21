-- Ask the Guild (Phase 8a): asking, answering, follow-ups, marking answered (asker only), the 48 h
-- and 7-day limits, links, copies for guildies who log in later, the Ask tab, pop-ups and sim mode.
math.randomseed(12)
YeahNahMateDB = nil
-- My quest log (Forever has C_QuestLog.GetInfo; probe 2026-10-14).
FAKE.quests = {
    { title = "The Barrens", isHeader = true },
    { title = "The Forgotten Pools", questID = 870, level = 20 },
    { title = "Raptor Thieves", questID = 869, level = 15 },
}
C_QuestLog = {
    GetNumQuestLogEntries = function() return #FAKE.quests, 2 end,
    GetInfo = function(i) return FAKE.quests[i] end,
    GetLogIndexForQuestID = function(id)
        for i, q in ipairs(FAKE.quests) do if q.questID == id then return i end end
    end,
}
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
local Q = ns.Questions
ns.settings.sharePosition, ns.settings.shareProfessions = false, false
for _, name in ipairs({ "Bluey Heeler", "Chilli Heeler" }) do
    INJECT("YNM", Msg({ v = 1, t = "HI", ver = "0.10.0" }), "GUILD", name)
end
Tick(15)
local now = GetServerTime()
local fired = {}
for _, e in ipairs({ "QUESTION_ASKED", "QUESTION_ANSWERED", "QUESTION_REPLY", "QUESTIONS_WAITING" }) do
    ns.Listen(e, function(...) fired[e] = (fired[e] or 0) + 1 end)
end

-- 1. Bluey asks. Colour codes stripped, links checked (a junk one dropped), 48 h at most.
INJECT("YNM", Msg({ v = 1, t = "QQ", id = 100, tx = "What level for |cffff0000Deadmines|r?", tp = "dungeons",
    lk = { { k = "d", id = "dm" }, { k = "d", id = "nope" }, { k = "x", id = 5 } }, u = now + 999999, at = now, ev = now }), "GUILD", "Bluey Heeler")
Tick(1)
local key = "Bluey Heeler:100"
local q = Q.Get(key)
check(q and q.tx == "What level for cffff0000Deadmines|r?" == false and q.tx:find("Deadmines") and not q.tx:find("|", 1, true),
    "Bluey's question kept, no colour codes")
check(q and #q.lk == 1 and q.lk[1].k == "d" and q.lk[1].id == "dm", "only the good dungeon link is kept")
check(q and q.u <= now + Q.OPEN, "open 48 hours at most")
check(fired.QUESTION_ASKED == 1, "a new question is announced (for the 8c alert)")
check(Q.State(q) == "open" and #Q.List("open") == 1, "it's in Open")
check(Q.LinkText(q.lk[1]) == "The Deadmines 17-26", "the dungeon link shows its levels")

-- A copy of it from someone we never asked is dropped; a question from a non-member too.
INJECT("YNM", Msg({ v = 1, t = "QQ", o = "Bluey Heeler", id = 100, tx = "changed", tp = "other", u = now + 3600, at = now, ev = now + 5 }), "WHISPER", "Chilli Heeler")
INJECT("YNM", Msg({ v = 1, t = "QQ", id = 1, tx = "hi", tp = "other", u = now + 3600, at = now, ev = now }), "GUILD", "Random Stranger")
Tick(1)
check(Q.Get(key).tx:find("Deadmines") and Q.Get("Random Stranger:1") == nil, "unasked copies and strangers are ignored")

-- 2. I answer, with a quest link from my log.
local mine = Q.MyQuests()
check(#mine == 2 and mine[1].id == 870 and mine[1].zone == "The Barrens" and mine[1].lv == 20, "my quest log is read (headers skipped)")
local before = #SENT
check(Q.Post(key, "Level 18 is fine with a tank.", { { k = "q", id = 870, lv = 20, n = "The Forgotten Pools" } }), "I can answer")
local qa = Sent("QA", before + 1)
check(#qa == 1 and qa[1]._channel == "GUILD" and qa[1].o == "Bluey Heeler" and qa[1].id == 100 and #qa[1].p == 1
    and qa[1].p[1].lk[1].id == 870, "my answer goes to the guild with its link")
check(Q.AnswerCount(Q.Get(key)) == 1 and #Q.List("mine") == 1, "it counts as an answer; the card is in Mine")
check(Q.InMyLog(870) and not Q.InMyLog(1), "quest links know if the quest is in my log")

-- Bluey replies to me: I get the reply pop-up.
INJECT("YNM", Msg({ v = 1, t = "QA", o = "Bluey Heeler", id = 100, pv = now + 10, p = { { tx = "Cheers! Any tips for VanCleef?", at = now + 10 } } }), "GUILD", "Bluey Heeler")
Tick(1)
check(fired.QUESTION_REPLY == 1 and ns.Toast.IsShown(), "the asker's follow-up pops up for me")
check(#Q.Thread(Q.Get(key)) == 2 and Q.AnswerCount(Q.Get(key)) == 1, "thread: my answer and Bluey's reply (the asker's posts aren't answers)")

-- Max 4 posts each; take one back.
for i = 2, 4 do Q.Post(key, "more " .. i) end
local ok, why = Q.Post(key, "one too many")
check(not ok and why == "full", "4 posts each on a card")
-- (Long messages go out in several pieces, so this one is checked as it's handed to AceComm.)
local lastQA
ns.Listen("SENT", function(m) if m.t == "QA" then lastQA = m end end)
check(Q.DeletePost(key, 4), "I can take a post back")
check(lastQA and #lastQA.p == 3, "taking it back sends my posts again (3 now)")
-- An older version of my posts can't come back in a copy (I'm the author).
check(Q.Get(key).posts[ns.me] and #Q.Get(key).posts[ns.me].p == 3, "my posts kept")

-- Chilli answers too; a later message from Chilli with a lower version is ignored.
INJECT("YNM", Msg({ v = 1, t = "QA", o = "Bluey Heeler", id = 100, pv = now + 20, p = { { tx = "Be 20", at = now + 20 } } }), "GUILD", "Chilli Heeler")
INJECT("YNM", Msg({ v = 1, t = "QA", o = "Bluey Heeler", id = 100, pv = now + 19, p = {} }), "GUILD", "Chilli Heeler")
Tick(1)
check(Q.AnswerCount(Q.Get(key)) == 2, "Chilli's answer stays (an older version doesn't wipe it)")
check(#Q.List("open", nil, "be 20") == 1 and #Q.List("open", nil, "zzz") == 0 and #Q.List("open", "quests") == 0,
    "search looks in answers; topic filter works")

-- 3. Only Bluey closes it. Bluey ticks Chilli's answer.
INJECT("YNM", Msg({ v = 1, t = "QQ", id = 100, ev = now + 30, x = "done", hp = { "Chilli Heeler", "Bluey Heeler" } }), "GUILD", "Bluey Heeler")
Tick(1)
q = Q.Get(key)
check(Q.State(q) == "done" and q.hp["Chilli Heeler"] and not q.hp["Bluey Heeler"] and not q.hp[ns.me],
    "Bluey marked it answered: Chilli's answer helped (the asker can't tick themselves)")
check(#Q.List("open") == 0 and #Q.List("answered") == 1, "it moves to Answered")
ok, why = Q.Post(key, "late")
check(not ok and why == "closed", "no posting on a finished card")
local sim = Q.Similar("what level should I be for the deadmines", 3)
check(#sim == 1 and sim[1].key == key, "a new question that looks like it finds it (Already asked)")

-- 4. Asking: 3 open at most, a minute apart.
before = #SENT
local k1 = Q.Ask("Where's the Mor'shan Rampart?", "quests", { { k = "d", id = "wc" } })
local qq = Sent("QQ", before + 1)
check(k1 and #qq == 1 and qq[1]._channel == "GUILD" and qq[1].tp == "quests" and qq[1].u == qq[1].at + Q.OPEN, "my question goes to the guild")
local k2, why2 = Q.Ask("Second one straight away", "other")
check(not k2 and why2 == "wait", "a minute between questions")
Tick(61)
k2 = Q.Ask("Second?", "other"); Tick(61)
local k3 = Q.Ask("Third?", "gear"); Tick(61)
local k4, why4 = Q.Ask("Fourth?", "class")
check(k2 and k3 and not k4 and why4 == "full", "3 open questions at most")
check(not Q.Ask("hi", "other"), "too short a question is refused")
before = #SENT
check(Q.Cancel(k3) and Sent("QQ", before + 1)[1].x == "cancel", "taking one down tells the guild")

-- Bluey answers mine: pop-up for me (the asker), with a Show that opens the card.
fired.QUESTION_ANSWERED = 0
local myId = Q.Get(k1).id
INJECT("YNM", Msg({ v = 1, t = "QA", o = ns.me, id = myId, pv = GetServerTime(), p = { { tx = "North of the Crossroads", at = GetServerTime() } } }), "GUILD", "Bluey Heeler")
Tick(1)
check(fired.QUESTION_ANSWERED == 1 and ns.Toast.IsShown(), "an answer to my question pops up")
ns.settings.pop.qanswer = false
INJECT("YNM", Msg({ v = 1, t = "QA", o = ns.me, id = myId, pv = GetServerTime() + 1, p = { { tx = "x", at = GetServerTime() }, { tx = "y", at = GetServerTime() } } }), "GUILD", "Bluey Heeler")
Tick(1)
check(fired.QUESTION_ANSWERED == 2, "the event still fires (the switch only hides the pop-up)")
ns.settings.pop.qanswer = true
-- A guildie can't post a question under my name (copies of my own are refused).
check(Q.Finish(k1, { "Bluey Heeler", ns.me, "Nobody Here" }), "I mark mine answered")
q = Q.Get(k1)
check(q.x == "done" and q.hp["Bluey Heeler"] and not q.hp[ns.me] and not q.hp["Nobody Here"], "only real answerers can be ticked")
local fin = Sent("QQ", #SENT)[1] or Sent("QQ", 1, function(m) return m.x == "done" end)[1]
check(fin and fin.x == "done", "done goes to the guild")

-- 5. Time: unanswered questions close after 48 h; answered ones wait up to 7 days for the asker.
INJECT("YNM", Msg({ v = 1, t = "QQ", id = 200, tx = "Nobody will answer this", tp = "other", u = GetServerTime() + Q.OPEN, at = GetServerTime(), ev = GetServerTime() }), "GUILD", "Chilli Heeler")
Tick(1)
check(Q.State(Q.Get(k2)) == "open", "mine is open")
INJECT("YNM", Msg({ v = 1, t = "QA", o = ns.me, id = Q.Get(k2).id, pv = GetServerTime(), p = { { tx = "an answer", at = GetServerTime() } } }), "GUILD", "Chilli Heeler")
Tick(1)
fired.QUESTIONS_WAITING = 0
NOW = NOW + Q.OPEN + 10
check(Q.State(Q.Get("Chilli Heeler:200")) == "expired" and Q.State(Q.Get(k2)) == "waiting", "after 48 h: unanswered closes, answered waits")
check(Q.MyWaiting() == 1 and Q.Live(Q.Get(k2)), "mine waits for me to mark it (and can still get replies)")
FireEvent("PLAYER_LOGIN")
Tick(30)
check(fired.QUESTIONS_WAITING == 1, "a reminder after logging in")
NOW = NOW + Q.WAIT
check(Q.State(Q.Get(k2)) == "expired" and not Q.Finish(k2, { "Chilli Heeler" }), "after 7 more days it closes unmarked")

-- 6. Copies. Chilli asks me for the questions I know: question then posts, finished ones carrying
-- only the helpful posts.
local Bkey = "Bluey Heeler:100"
before = #SENT
INJECT("YNM", Msg({ v = 1, t = "REQ", w = "QS" }), "WHISPER", "Chilli Heeler")
Tick(5)
local copies = Sent("QQ", before + 1, function(m, s) return s.target == "Chilli Heeler" end)
local postCopies = Sent("QA", before + 1, function(m, s) return s.target == "Chilli Heeler" end)
local blueyQ, blueyPosts = nil, {}
for _, m in ipairs(copies) do if m.o == "Bluey Heeler" and m.id == 100 then blueyQ = m end end
for _, m in ipairs(postCopies) do if m.o == "Bluey Heeler" and m.id == 100 then blueyPosts[m.by or "me"] = m end end
check(blueyQ and blueyQ.x == "done" and blueyQ.tx and blueyQ.hp[1] == "Chilli Heeler", "the finished question goes in full")
check(blueyPosts["Bluey Heeler"] and not blueyPosts["me"] and not blueyPosts["Chilli Heeler"],
    "finished: only the helpful and the asker's posts go (not mine, and not Chilli's own back to Chilli)")
local mineCopy
for _, m in ipairs(copies) do if m.o == nil and m.id == myId then mineCopy = m end end
check(mineCopy and mineCopy.x == "done", "my own questions go as mine (no o)")

-- Taking copies: a fresh client asks a peer after logging in; posts arriving before their question
-- wait for it.
YeahNahMateDB.guilds = {}
Q.Store()
before = #SENT
FireEvent("PLAYER_LOGIN")
Tick(70)
local ask = Sent("REQ", before + 1, function(m) return m.w == "QS" end)[1]
check(ask ~= nil, "after logging in I ask a guildie for the questions")
local peer = ask._target
local t0 = GetServerTime()
local askedBefore = fired.QUESTION_ASKED
INJECT("YNM", Msg({ v = 1, t = "QA", o = "Bandit Heeler", id = 300, by = "Bingo Heeler", pv = t0, p = { { tx = "Go to Ratchet", at = t0 } } }), "WHISPER", peer)
Tick(1)
check(Q.Get("Bandit Heeler:300") == nil and Q.Store()["Bandit Heeler:300"].stub, "posts before their question wait (not shown)")
-- Found by the soak (multi.py): a waiting stub has no question yet; copies and log-in whispers
-- must skip it, not error on it.
local errsBefore = #ERRORS
INJECT("YNM", Msg({ v = 1, t = "REQ", w = "QS" }), "WHISPER", "Chilli Heeler")
INJECT("YNM", Msg({ v = 1, t = "HI", ver = "0.10.0", ask = true }), "GUILD", "Chilli Heeler")
Tick(65)
check(#ERRORS == errsBefore and Q.State(Q.Store()["Bandit Heeler:300"]) == "expired" and #Q.List("open") >= 0,
    "a waiting stub doesn't break copies, log-in whispers or the lists")
INJECT("YNM", Msg({ v = 1, t = "QQ", o = "Bandit Heeler", id = 300, tx = "How do I get to Booty Bay?", tp = "other", u = t0 + 3600, at = t0, ev = t0 }), "WHISPER", peer)
Tick(1)
q = Q.Get("Bandit Heeler:300")
check(q and Q.AnswerCount(q) == 1 and q.posts["Bingo Heeler"], "the question arrives and keeps the waiting answer")
check(fired.QUESTION_ASKED == askedBefore, "copies don't announce questions as new")
-- The author's own message beats a copy, even an older version.
INJECT("YNM", Msg({ v = 1, t = "QA", o = "Bandit Heeler", id = 300, pv = t0 - 50, p = { { tx = "Ratchet boat", at = t0 } } }), "GUILD", "Bingo Heeler")
Tick(1)
check(Q.Get("Bandit Heeler:300").posts["Bingo Heeler"].p[1].tx == "Ratchet boat", "the poster's own message wins over a copy")

-- When a guildie logs in, I whisper them my own questions and posts.
Q.Post("Bandit Heeler:300", "Zeppelin to Grom'gol, then run south")
before = #SENT
INJECT("YNM", Msg({ v = 1, t = "HI", ver = "0.10.0", ask = true }), "GUILD", "Bluey Heeler")
Tick(15)
local whispered = Sent("QA", before + 1, function(m, s) return s.target == "Bluey Heeler" and m.o == "Bandit Heeler" end)
check(#whispered == 1 and whispered[1].by == nil, "a guildie logging in gets my posts from me")

-- Old versions: unknown types are dropped by Comm (checked in test_addon); a newer protocol too.
INJECT("YNM", Msg({ v = 99, t = "QQ", id = 5, tx = "future", tp = "other", u = t0 + 10, at = t0, ev = t0 }), "GUILD", "Chilli Heeler")
Tick(1)
check(Q.Get("Chilli Heeler:5") == nil, "a newer protocol's question is ignored")

-- 7. The Ask tab.
ns.UI.Open("ask")
local page
for _, o in ipairs(CREATED) do if o.listView and o.cardView and o.formFrame then page = o end end
check(page ~= nil and page.listView:IsShown(), "the Ask tab opens on the list")
page.pickView(1)
Tick(1)
local shown = 0
for _, c in ipairs(page.cards) do if c:IsShown() then shown = shown + 1 end end
check(shown == 1 and page.cards[1].key == "Bandit Heeler:300", "Open lists Bandit's question")
page.cards[1].click:Click()
Tick(1)
check(page.cardView:IsShown() and page.openKey == "Bandit Heeler:300", "clicking a card opens it")
local v = page.cardView
check(v.posts[1]:IsShown() and v.posts[2]:IsShown(), "the thread shows both answers")
-- Reply with a dungeon picked from the list.
v.dungeon:Click()
local picker = ns.UI.AskPicker()
check(picker:IsShown() and #picker.items == #ns.Dungeons.MyList(), "the dungeon picker lists every dungeon my faction can use")
picker.rows[1]:Click()
check(#page.replyLinks == 1 and page.replyLinks[1].k == "d", "picking one adds the link")
v.reply:SetText("Or take the boat from Ratchet")
before = #SENT
v.send:Click()
qa = Sent("QA", before + 1)
check(#qa == 1 and #qa[1].p == 2 and qa[1].p[2].lk[1].k == "d", "Post sends my posts with the link")
check(#page.replyLinks == 0 and v.reply:GetText() == "", "the box is cleared")
-- An item from the bags.
FAKE.cursor = { "item", 2592, "|cffffffff|Hitem:2592::::::::|h[Wool Cloth]|h|r" }
v.item:Click()
check(page.replyLinks[1] and page.replyLinks[1].k == "i" and page.replyLinks[1].id == 2592 and page.replyLinks[1].n == "Wool Cloth",
    "+ Item takes the item on the cursor")
v.quest:Click()
check(picker:IsShown() and #picker.items == 2, "the quest picker lists my quest log")
picker.rows[1]:Click()
check(#page.replyLinks == 2 and page.replyLinks[2].k == "q" and page.replyLinks[2].id == 870, "a quest link added")
v.dungeon:Click(); picker.rows[2]:Click()
check(#page.replyLinks == 2, "2 links at most")
v.pending[1]:Click()
Tick(1)
local left = 0
for i = 1, 2 do if page.replyLinks[i] then left = left + 1 end end
check(left == 1, "clicking a waiting link removes it")

-- Asking from the form; the Already asked list.
page.openKey = nil
page.pickView(1)
page.askBtn:Click()
Tick(1)
check(page.formFrame:IsShown(), "Ask a question opens the form")
local f = page.formFrame
f.text:SetText("what level should I be for the deadmines")
Tick(1)
-- (Bluey's Deadmines question was wiped with the fresh start above: nothing similar now.)
check(not f.already[1]:IsShown(), "no Already asked when nothing matches")
f.text:SetText("How do I get to Booty Bay from Orgrimmar")
page.pickTopic(2)
FAKE.cursor = { "item", 6948, "|cffffffff|Hitem:6948::::::::|h[Hearthstone]|h|r" }
f.item:Click()
before = #SENT
NOW = NOW + 120
f.post:Click()
Tick(1)
qq = Sent("QQ", before + 1)
check(#qq == 1 and qq[1].tp == "quests" and qq[1].lk[1].id == 6948, "Ask posts the question with its topic and link")
check(not page.formFrame:IsShown() and page.view == "mine", "back to Mine after asking")

-- Marking from the card: ticks on others' answers, then Done.
local myKey = ns.me .. ":" .. qq[1].id
INJECT("YNM", Msg({ v = 1, t = "QA", o = ns.me, id = qq[1].id, pv = GetServerTime(), p = { { tx = "Zeppelin!", at = GetServerTime() } } }), "GUILD", "Chilli Heeler")
Tick(1)
ns.UI.ShowQuestion(myKey)
Tick(1)
check(page.cardView:IsShown() and v.mark:IsShown() and v.cancel:IsShown(), "my card has Mark answered and Take it down")
v.mark:Click()
Tick(1)
check(v.posts[1].tick:IsShown(), "marking: a tick on Chilli's answer")
v.posts[1].tick:SetChecked(true); v.posts[1].tick:Click()
before = #SENT
v.markDone:Click()
Tick(1)
qq = Sent("QQ", before + 1)
check(#qq == 1 and qq[1].x == "done" and qq[1].hp[1] == "Chilli Heeler", "Done sends it answered with Chilli ticked")
check(not v.reply:IsShown() and v.closed:IsShown(), "a finished card has no reply box")

-- 8. Tidy: finished cards go after 30 days.
NOW = NOW + Q.KEEP + 86400
Q.Tidy()
check(Q.Get(myKey) == nil, "finished questions are tidied away after 30 days")

-- 8a. Found by the soak: when I take back all my posts on my own question, the empty list still goes
-- to guildies who log in (otherwise they keep the old post for good).
YeahNahMateDB.guilds = {}
NOW = NOW + 120
local emptyKey = Q.Ask("Taking my follow-up back", "other")
Q.Post(emptyKey, "follow-up")
Q.DeletePost(emptyKey, 1)
local whisperedPosts
local listen = function(m, channel, target)
    if m.t == "QA" and channel == "WHISPER" and target == "Chilli Heeler" and m.o == ns.me then whisperedPosts = m end
end
ns.Listen("SENT", listen)
INJECT("YNM", Msg({ v = 1, t = "HI", ver = "0.10.0", ask = true }), "GUILD", "Chilli Heeler")
Tick(15)
check(whisperedPosts and #whisperedPosts.p == 0, "my emptied posts on my own question still go to a guildie logging in")

-- 8b. Catching up on an old copy (found by the soak): Chilli edited a post while I was offline, then
-- asked something new that I did get. Newest and count match; the checksum doesn't, so I ask.
YeahNahMateDB.guilds = {}
local t1 = GetServerTime()
INJECT("YNM", Msg({ v = 1, t = "QQ", id = 400, tx = "Old question", tp = "other", u = t1 + 3600, at = t1 - 100, ev = t1 - 100 }), "GUILD", "Chilli Heeler")
INJECT("YNM", Msg({ v = 1, t = "QA", o = "Chilli Heeler", id = 400, pv = t1 - 90, p = { { tx = "first go", at = t1 - 90 } } }), "GUILD", "Chilli Heeler")
INJECT("YNM", Msg({ v = 1, t = "QQ", id = 401, tx = "New question", tp = "other", u = t1 + 3600, at = t1, ev = t1 }), "GUILD", "Chilli Heeler")
Tick(1)
local function SyncAsks(from)
    return Sent("REQ", from, function(m, s)
        if m.w ~= "SYNC" or s.target ~= "Chilli Heeler" then return false end
        for _, k in ipairs(m.k) do if k == "questions" then return true end end
        return false
    end)
end
local since = t1 - 86400
before = #SENT
INJECT("YNM", Msg({ v = 1, t = "HI", ver = "0.10.0", ask = true,
    sv = { questions = { v = t1, n = 3, s = since, h = ((t1 - 100) + (t1 - 90) + t1) % 2147483647 } } }), "GUILD", "Chilli Heeler")
Tick(6)
check(#SyncAsks(before + 1) == 0, "same versions: no catch-up asked")
before = #SENT
INJECT("YNM", Msg({ v = 1, t = "HI", ver = "0.10.0", ask = true,
    sv = { questions = { v = t1, n = 3, s = since, h = ((t1 - 100) + (t1 - 50) + t1) % 2147483647 } } }), "GUILD", "Chilli Heeler")
Tick(6)
check(#SyncAsks(before + 1) == 1, "same newest and count but an old copy (checksum differs): I ask to catch up")
before = #SENT
INJECT("YNM", Msg({ v = 1, t = "HI", ver = "0.9.11", ask = true,
    sv = { questions = { v = t1, n = 3, s = since } } }), "GUILD", "Chilli Heeler")
Tick(6)
check(#SyncAsks(before + 1) == 0, "an older version's hello (no checksum) works as before")

-- 9. Sim mode: fake questions, a fake answers mine, all gone when sim is off.
YeahNahMateDB.guilds = {}
ns.Sim.Start(true)
Tick(20)
check(#Q.List("open") == 2 and #Q.List("answered") == 3, "sim: two open fake questions and three answered (Davo helped on all three)")
local sfk = Q.Get("Bazza Stubbs:" .. (GetServerTime() - 20 + 17 - 17))
for _, c in ipairs(Q.List("open")) do if c.owner == "Bazza Stubbs" then sfk = c end end
check(sfk and Q.AnswerCount(sfk) == 1 and #Q.Thread(sfk) == 2, "Bazza's has Davo's answer and his own follow-up")
NOW = NOW + 120
local simKey = Q.Ask("Sim question for the fakes", "other")
Tick(20)
check(simKey and Q.AnswerCount(Q.Get(simKey)) == 2, "Shazza and Bazza answer mine")
Q.Post(sfk.key, "Grab it, it's on the way")
Tick(10)
check(#Q.Get(sfk.key).posts["Bazza Stubbs"].p == 2, "Bazza replies to my answer")
ns.Sim.Stop()
Tick(1)
check(#Q.List("open") == 1 and Q.List("open")[1].key == simKey and Q.AnswerCount(Q.Get(simKey)) == 0,
    "sim off: fake questions and answers are gone (mine stays)")

-- Soak 13 Nov (seed 70): copies can arrive newest first. A newer question past the 3-open limit
-- drops the oldest open copy as stale, but it may still be live and come straight back: my posts on
-- it must survive.
do
    local base = GetServerTime() - 600
    local function QQ(id) return Msg({ v = 1, t = "QQ", id = id, tx = "Chilli question " .. id, tp = "other", at = id, ev = id, u = id + 48 * 3600 }) end
    INJECT("YNM", QQ(base), "GUILD", "Chilli Heeler")
    Tick(1)
    local oldKey = "Chilli Heeler:" .. base
    check(Q.Get(oldKey) ~= nil and Q.Post(oldKey, "My answer"), "I answer Chilli's question")
    for k = 1, 3 do INJECT("YNM", QQ(base + k * 10), "GUILD", "Chilli Heeler") end
    Tick(1)
    check(Q.Get(oldKey) == nil and Q.Store()[oldKey].stub and Q.Store()[oldKey].posts[ns.me], "three newer ones: the oldest copy is dropped as stale (its posts kept in a stub)")
    INJECT("YNM", Msg({ v = 1, t = "QQ", id = base + 30, x = "cancel", ev = base + 40 }), "GUILD", "Chilli Heeler")
    INJECT("YNM", QQ(base), "GUILD", "Chilli Heeler")
    Tick(1)
    local q = Q.Get(oldKey)
    check(q and q.posts[ns.me] and q.posts[ns.me].p[1] and q.posts[ns.me].p[1].tx == "My answer", "it comes back: my answer is still on it")
end

check(#ERRORS == 0, "no errors (" .. (ERRORS[1] or "none") .. ")")
