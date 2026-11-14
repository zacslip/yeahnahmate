-- Ask the Guild 8b + 8c: points and the Lore Master (30 days rolling, at least 3, a tie goes to whoever
-- got there first), the Ask button on the left, the Lore Master view, the book by the name, the small
-- opt-in alert for new questions (combat, instances, +N more, fade, click, right-click, drag) and the
-- Home line.
math.randomseed(21)
YeahNahMateDB = nil
local ns = LoadAddon("YeahNahMate", "YeahNahMate")
LOGGED_IN = true
FireEvent("PLAYER_LOGIN")
local Ser = LibStub("AceSerializer-3.0")
local function Msg(t) return Ser:Serialize(t) end
local Q = ns.Questions
ns.settings.sharePosition, ns.settings.shareProfessions = false, false
for _, name in ipairs({ "Bluey Heeler", "Chilli Heeler", "Bingo Heeler", "Bandit Heeler" }) do
    INJECT("YNM", Msg({ v = 1, t = "HI", ver = "0.10.1" }), "GUILD", name)
end
Tick(15)
local now = GetServerTime()

-- A finished card: asker, id, days ago it was marked, helpers.
local function Done(asker, id, daysAgo, helpers)
    local at = now - daysAgo * 86400 - 3600
    INJECT("YNM", Msg({ v = 1, t = "QQ", id = id, tx = "Question " .. id, tp = "other", u = at + Q.OPEN, at = at,
        ev = now - daysAgo * 86400, x = "done", hp = helpers }), "GUILD", asker)
end

check(Q.LoreMaster() == nil and #Q.Top() == 0, "no points, no Lore Master")
Done("Bluey Heeler", 1, 20, { "Chilli Heeler" })
Done("Bingo Heeler", 2, 18, { "Chilli Heeler", "Bandit Heeler" })
Tick(1)
check(Q.Points("Chilli Heeler") == 2 and Q.Points("Bandit Heeler") == 1, "a point per card where the asker ticked you")
check(Q.LoreMaster() == nil, "2 points isn't enough for Lore Master")
Done("Bandit Heeler", 3, 10, { "Chilli Heeler", "Bandit Heeler" })    -- can't tick yourself
Tick(1)
check(Q.Points("Bandit Heeler") == 1, "the asker ticking themselves counts for nothing")
check(Q.LoreMaster() == "Chilli Heeler", "3 points: Chilli is the Lore Master")

-- Bandit catches up to 3: a tie, Chilli got there first.
Done("Bluey Heeler", 4, 5, { "Bandit Heeler" })
Done("Bingo Heeler", 5, 4, { "Bandit Heeler" })
Tick(1)
check(Q.Points("Bandit Heeler") == 3 and Q.LoreMaster() == "Chilli Heeler", "a tie goes to whoever got there first")
Done("Chilli Heeler", 6, 3, { "Bandit Heeler" })
Tick(1)
check(Q.LoreMaster() == "Bandit Heeler", "4 points beats 3")
local top = Q.Top(10)
check(#top == 2 and top[1].name == "Bandit Heeler" and top[2].name == "Chilli Heeler", "the top list, most first")

-- Open, taken-down and stranger cards don't count; non-members' points don't either.
INJECT("YNM", Msg({ v = 1, t = "QQ", id = 7, tx = "still open", tp = "other", u = now + 3600, at = now, ev = now }), "GUILD", "Bluey Heeler")
Done("Random Stranger", 8, 1, { "Chilli Heeler" })
Tick(1)
check(Q.Points("Chilli Heeler") == 3, "open cards and strangers' cards don't count")

-- 30 days, rolling: Chilli's oldest card (20 days) drops off after 11 more days.
Tick(11 * 86400, 3600)
check(Q.Points("Chilli Heeler") == 2, "points older than 30 days drop off")
check(Q.LoreMaster() == "Bandit Heeler", "Bandit still has 4")
now = GetServerTime()

-- The book next to the Lore Master's name, and in the member tooltip.
local m = ns.Guild.Get("Bandit Heeler")
check(m and ns.UI.Name(m):find("INV_Misc_Book_09", 1, true), "the Lore Master's name has a book")
check(not ns.UI.Name(ns.Guild.Get("Chilli Heeler")):find("INV_Misc_Book", 1, true), "nobody else's does")

-- The Ask tab: Ask a question on the left; the Lore Master box opens the Legends tab.
ns.UI.Open("ask")
Tick(1)
local page
for _, o in ipairs(CREATED) do if o.listView and o.viewCards and o.browse then page = o end end
check(page ~= nil and page.browse:IsShown(), "the Ask tab opens on the cards")
check(page.lore == nil, "no Lore Master card on Ask (it's on Legends)")
ns.UI.ShowLegend("lore")
Tick(1)
local t
for _, o in ipairs(CREATED) do if o.titles and o.titleCards then t = o end end
check(t and t:IsShown() and t.titles[t.pick].key == "lore" and not page:IsShown(), "Legends at the Lore Master")
check(t.who:GetText():find("Bandit", 1, true) and t.rows[1].name:GetText():find("Bandit", 1, true)
    and t.rows[1].num:GetText():find("4") and t.rows[2]:IsShown() and not t.rows[3]:IsShown(), "the top list shows")
check(t.mine:GetText():find("0"), "my own points")
check(t.titleCards[1].text:GetText() == "Bandit" and not t.titleCards[1].green:IsShown(), "the Legends card names the holder (not green: not mine)")
ns.UI.Open("ask")
page.pickView(1)
Tick(1)
check(page.browse:IsShown() and page.askBtn:IsShown(), "back to the cards; Ask a question is there")

-- 8c: the alert. Off until ticked.
check(ns.settings.qAlert == false and page.alertMe.text:GetText():find("Off", 1, true), "the alert card says off until clicked")
INJECT("YNM", Msg({ v = 1, t = "QQ", id = 20, tx = "Where's the Undercity flight master?", tp = "other", u = now + 3600 * 48, at = now, ev = now }), "GUILD", "Chilli Heeler")
Tick(1)
check(not ns.QAlert.IsShown(), "no alert while it's off")
page.alertMe:Click()
Tick(1)
check(ns.settings.qAlert == true and page.alertMe.text:GetText():find("On", 1, true) and page.alertMe.green:IsShown(), "clicking the card turns it on (green)")
INJECT("YNM", Msg({ v = 1, t = "QQ", id = 21, tx = "What drops the Robe of the Moccasin?", tp = "gear", u = now + 3600 * 48, at = now, ev = now }), "GUILD", "Bingo Heeler")
Tick(1)
check(ns.QAlert.IsShown() and ns.QAlert.Key() == "Bingo Heeler:21", "a new question: the small alert")
-- Another while it shows: "+1 more".
INJECT("YNM", Msg({ v = 1, t = "QQ", id = 22, tx = "Best mining spot at 40?", tp = "professions", u = now + 3600 * 48, at = now, ev = now }), "GUILD", "Bandit Heeler")
Tick(1)
local alert
for _, o in ipairs(CREATED) do if o.btn and o.more then alert = o end end
check(alert and alert.more:GetText():find("+1", 1, true), "+1 more while one shows")
-- It fades and goes after 15 s, then the next one shows.
Tick(17)
check(ns.QAlert.IsShown() and ns.QAlert.Key() == "Bandit Heeler:22", "after 15 s it goes and the next one shows")
-- The mouse on it holds it.
alert.btn:GetScript("OnEnter")(alert.btn)
Tick(30)
check(ns.QAlert.IsShown(), "it stays while the mouse is on it")
alert.btn:GetScript("OnLeave")(alert.btn)
-- Click opens the card.
ns.QAlert.Click("LeftButton")
Tick(1)
check(not ns.QAlert.IsShown() and page.openKey == "Bandit Heeler:22" and page.cardView:IsShown(), "click opens the card")

-- In combat it waits; in a dungeon it waits.
FAKE.combat = true
INJECT("YNM", Msg({ v = 1, t = "QQ", id = 23, tx = "Anyone got a spare Swiftthistle?", tp = "other", u = now + 3600 * 48, at = now, ev = now }), "GUILD", "Bluey Heeler")
Tick(3)
check(not ns.QAlert.IsShown(), "not in combat")
FAKE.combat = nil
FAKE.instance = true
Tick(8)
check(not ns.QAlert.IsShown(), "not in a dungeon")
FAKE.instance = nil
Tick(8)
check(ns.QAlert.IsShown() and ns.QAlert.Key() == "Bluey Heeler:23", "shows once out of combat and out of the dungeon")

-- Right-click closes it and any waiting.
INJECT("YNM", Msg({ v = 1, t = "QQ", id = 24, tx = "q24", tp = "other", u = now + 3600 * 48, at = now, ev = now }), "GUILD", "Chilli Heeler")
Tick(1)
check(ns.QAlert.Queued() == 1, "one waiting")
ns.QAlert.Click("RightButton")
Tick(5)
check(not ns.QAlert.IsShown() and ns.QAlert.Queued() == 0, "right-click closes it and the waiting ones")

-- One I've answered already, or one taken down, doesn't show.
INJECT("YNM", Msg({ v = 1, t = "QQ", id = 25, tx = "q25", tp = "other", u = now + 3600 * 48, at = now, ev = now }), "GUILD", "Chilli Heeler")
INJECT("YNM", Msg({ v = 1, t = "QQ", id = 26, tx = "q26", tp = "other", u = now + 3600 * 48, at = now, ev = now }), "GUILD", "Bingo Heeler")
INJECT("YNM", Msg({ v = 1, t = "QQ", id = 26, ev = now + 5, x = "cancel" }), "GUILD", "Bingo Heeler")
Tick(20)
check(not ns.QAlert.IsShown() or ns.QAlert.Key() ~= "Bingo Heeler:26", "a taken-down question doesn't alert")
Tick(20)

-- My own questions don't alert me.
local before = ns.QAlert.Queued()
INJECT("YNM", Msg({ v = 1, t = "QQ", id = 27, tx = "mine", tp = "other", u = now + 3600 * 48, at = now, ev = now }), "GUILD", ns.me)
Tick(1)
check(not ns.QAlert.IsShown(), "my own question doesn't alert me")

-- Dragging saves where it was left.
INJECT("YNM", Msg({ v = 1, t = "QQ", id = 28, tx = "q28", tp = "other", u = now + 3600 * 48, at = now, ev = now }), "GUILD", "Bandit Heeler")
Tick(1)
check(ns.QAlert.IsShown(), "shown")
alert.btn:GetScript("OnDragStart")(alert.btn)
alert.btn:GetScript("OnDragStop")(alert.btn)
check(type(ns.settings.qAlertPos) == "table" and ns.settings.qAlertPos[3] == 10, "where it's dragged to is saved")
ns.QAlert.Click("LeftButton")       -- the click that ends a drag doesn't open anything
check(ns.QAlert.IsShown(), "the mouse-up after a drag doesn't count as a click")
Tick(1)
ns.QAlert.Click("LeftButton")       -- the next real click does
Tick(1)
check(not ns.QAlert.IsShown() and page.openKey == "Bandit Heeler:28", "the next click after a drag opens the card")

-- Ticked off: it goes.
page.alertMe:Click()
Tick(1)
check(not ns.QAlert.IsShown() and ns.settings.qAlert == false, "unticking hides it")

-- Home: open questions and the Lore Master, click for the Ask tab.
ns.UI.Open("home")
Tick(1)
local home
for _, o in ipairs(CREATED) do if o.ask and o.live and o.near then home = o end end
check(home and home.ask:IsShown() and home.ask.text:GetText():find("Open questions", 1, true)
    and home.ask.text:GetText():find("Bandit", 1, true), "Home: open questions and the Lore Master")
home.ask:Click()
Tick(1)
check(page.listView:IsShown() and page.view == "open", "the Home line opens the Ask tab at Open")

-- The guild breakdown names the Lore Master.
ns.UI.Open("breakdown")
Tick(1)
local bd
for _, o in ipairs(CREATED) do if o.glance and o.classRows then bd = o end end
check(bd and bd.glance[6]:GetText():find("Bandit", 1, true), "the guild breakdown names the Lore Master")

-- The layout (the row of buttons was a wall): Ask a question at the top of a sidebar, the views
-- as rows with counts, one Topic button with a menu.
ns.UI.Open("ask")
page.pickView(1)
Tick(1)
check(page.viewCards[1].text:GetText():find("open", 1, true) and page.viewCards[1].bar:IsShown() and not page.viewCards[2].bar:IsShown(),
    "the Open row is picked and shows how many")
check(page.viewTitle:GetText() == ns.L.Q_TITLE_OPEN, "the view's title over the cards")
check(page.alertMe:IsShown() and page.alertMe.pts:GetText() ~= "", "the alert card under the line")
check(not page.topicMenu:IsShown(), "the topic menu starts shut")
page.topicBtn:Click()
check(page.topicMenu:IsShown(), "Topic opens its menu")
page.topicMenu.rows[6]:Click()           -- Gear
Tick(1)
check(page.topic == "gear" and not page.topicMenu:IsShown() and page.topicBtn:GetText():find("Gear", 1, true), "picking a topic filters and shuts the menu")
page.pickTopicFilter(1)
page.viewCards[3]:Click()
Tick(1)
check(page.view == "answered" and page.viewTitle:GetText() == ns.L.Q_TITLE_ANSWERED, "clicking a view row picks it")
page.pickView(1)

-- Mark resolved with no answers: the asker sorted it themselves.
NOW = NOW + 120
local myKey = Q.Ask("Where's the Thousand Needles flight path?", "other")
check(myKey ~= nil, "I ask")
ns.UI.ShowQuestion(myKey)
Tick(1)
local cv = page.cardView
check(cv.mark:IsShown(), "Mark resolved shows on my question even with no answers")
-- The card: who and how long ago on top, the question under it; time left once, in the sidebar.
check(cv.info:GetText():find("ago", 1, true) and not cv.info:GetText():find("left", 1, true), "top line: who asked and how long ago")
check(cv.title:GetText():find("Thousand Needles", 1, true), "the question under it")
check(cv.left:GetText():find("left to answer", 1, true) and not cv.state:GetText():find("left", 1, true), "time left shows once, in the sidebar")
check(cv.cancel:IsShown() and cv.sideHint:GetText() == ns.L.Q_SIDE_ASKER, "Take it down and the asker's hint in the sidebar")
cv.mark:Click()
Tick(1)
check(cv.markDone:IsShown() and cv.markHint:GetText() == ns.L.Q_MARK_HINT_NONE, "no answers: just Done")
cv.markDone:Click()
Tick(1)
check(Q.State(Q.Get(myKey)) == "done" and #Q.Helpers(Q.Get(myKey)) == 0, "resolved, nobody to credit")
check(#Q.List("answered", nil, "Thousand Needles") == 1, "it's in Resolved")

-- Sim mode: Davo is the fake Lore Master; a minute in, Macca asks (the alert, if ticked).
ns.settings.qAlert = true
ns.devCommands.sim("on")
Tick(30)
check(Q.Points("Davo Thongs") == 3, "sim: Davo has 3 points (the Lore Master in a guild with no real points)")
Tick(40)
check(ns.QAlert.IsShown() and ns.QAlert.Key():find("Macca Ute", 1, true), "sim: Macca's new question alerts")
ns.devCommands.sim("off")
Tick(2)
check(Q.LoreMaster() == "Bandit Heeler", "sim off: back to the real one")

check(#ERRORS == 0, "no errors (" .. (ERRORS[1] or "none") .. ")")
