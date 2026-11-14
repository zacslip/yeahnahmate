-- Craft requests: posting, the crafter's pop-up and "I'll make it", done/cancel (owner only), limits,
-- copies for late joiners, expiry, the Requests view and its Request button, sim.
math.randomseed(9)
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
local R = ns.Requests
ns.settings.sharePosition, ns.settings.shareProfessions = false, true
INJECT("YNM", Msg({ v = 1, t = "HI", ver = "0.7.0" }), "GUILD", "Bluey Heeler")
Tick(15)
-- I know Tailoring: Linen Bag (3755) and Woolen Bag (3757).
FAKE.trade = { line = 197, rank = 75, max = 150, recipes = { [3755] = true, [3757] = true } }
FireEvent("TRADE_SKILL_SHOW")
Tick(2)
FAKE.trade = nil
local now = GetServerTime()

-- Request alerts are off until I turn them on (opt in, like the Ask alert).
check(ns.settings.pop.request == false, "request alerts start off")
ns.settings.pop.request = true
-- Bluey asks for Linen Bags: I can make them, so I get a pop-up.
local pops = 0
ns.Listen("REQUEST_POSTED", function(r) if R.ICanMake(r) then pops = pops + 1 end end)
INJECT("YNM", Msg({ v = 1, t = "RQ", id = 100, rid = 3755, it = "Linen Bag", n = 2, note = "Have the cloth|cff", u = now + 999999, ev = now }), "GUILD", "Bluey Heeler")
Tick(1)
local key = "Bluey Heeler:100"
local r = R.Store()[key]
check(r and r.n == 2 and r.note == "Have the clothcff" and r.u <= GetServerTime() + R.LASTS, "Bluey's request kept (3 days at most, colour codes stripped)")
check(R.ICanMake(r) and pops == 1 and ns.Toast.IsShown(), "I can make it: pop-up")
check(R.Line(r) == 197, "it's a Tailoring request")

-- I say I'll make it: the guild hears; then I take it back.
local before = #SENT
R.Claim(key, true)
local cl = Sent("CL", before + 1)
check(#cl == 1 and cl[1]._channel == "GUILD" and cl[1].o == "Bluey Heeler" and cl[1].id == 100, "\"I'll make it\" sent to the guild")
check(R.Claimers(R.Store()[key])[1] == "Ned Jones", "I'm on it")
R.Claim(key, false)
check(#R.Claimers(R.Store()[key]) == 0 and Sent("CL", before + 1)[2].x == true, "taken back")
-- Someone else says they'll make it.
INJECT("YNM", Msg({ v = 1, t = "CL", o = "Bluey Heeler", id = 100 }), "GUILD", "Chilli Heeler")
INJECT("YNM", Msg({ v = 1, t = "CL", o = "Bluey Heeler", id = 100 }), "WHISPER", "Bingo Heeler")
INJECT("YNM", Msg({ v = 1, t = "CL", o = "Bluey Heeler", id = 100 }), "GUILD", "Bluey Heeler")
Tick(1)
local claimers = R.Claimers(R.Store()[key])
check(#claimers == 1 and claimers[1] == "Chilli Heeler", "Chilli's on it (a whisper, or the poster claiming their own, don't count)")

-- Only Bluey can finish Bluey's request.
INJECT("YNM", Msg({ v = 1, t = "RQ", id = 100, ev = now + 5, x = "done" }), "GUILD", "Bingo Heeler")
Tick(1)
check(not R.Store()[key].x, "Bingo can't mark Bluey's request done")
INJECT("YNM", Msg({ v = 1, t = "RQ", id = 100, ev = now + 5, x = "done" }), "GUILD", "Bluey Heeler")
Tick(1)
check(R.Store()[key].x == "done" and #R.List() == 0, "Bluey marked it done: off the list")
check(R.Store()["Bingo Heeler:100"] == nil, "Bingo's 'done' for a request nobody saw leaves no blank history row")

-- Junk.
INJECT("YNM", Msg({ v = 1, t = "RQ", id = 101, it = "", u = now + 100, ev = now }), "GUILD", "Bingo Heeler")
INJECT("YNM", Msg({ v = 1, t = "RQ", id = 102, it = "x", u = now + 100, ev = now + 99999 }), "GUILD", "Bingo Heeler")
INJECT("YNM", Msg({ v = 1, t = "RQ", id = 103, it = "x", n = 500, u = now + 100, ev = now }), "GUILD", "Stranger Danger")
Tick(1)
check(R.Store()["Bingo Heeler:101"] == nil and R.Store()["Bingo Heeler:102"] == nil, "empty and future requests dropped")

-- My own request: posted to the guild; at most 5 open; Done and Cancel.
before = #SENT
local mine = R.Post(nil, "Heavy Linen Bandage", 10, "will tip")
local rq = Sent("RQ", before + 1)
check(mine and #rq == 1 and rq[1].it == "Heavy Linen Bandage" and rq[1].n == 10 and rq[1]._channel == "GUILD", "my request posted")
check(R.Post(nil, "", 1, "") == nil, "a request needs an item")
for i = 2, 5 do R.Post(nil, "Thing " .. i, 1, "") end
local _, why = R.Post(nil, "One too many", 1, "")
check(why == "full", "at most 5 open requests")
local claimedPops = 0
ns.Listen("REQUEST_CLAIMED", function() claimedPops = claimedPops + 1 end)
INJECT("YNM", Msg({ v = 1, t = "CL", o = "Ned Jones", id = R.Store()[mine].id }), "GUILD", "Bluey Heeler")
Tick(1)
check(claimedPops == 1, "I get a pop-up when Bluey says they'll make mine")
before = #SENT
R.Finish(mine, "done")
rq = Sent("RQ", before + 1)
check(#rq == 1 and rq[1].x == "done" and R.Store()[mine].x == "done", "marked mine done; the guild hears")
check(R.Post(nil, "Now there's room", 1, "") ~= nil, "room for another after one's done")

-- A guildie logging in gets my open requests; asked for them, I send copies of others' too.
FAKE.roster[5][9] = true
ns.Guild.Scan()
INJECT("YNM", Msg({ v = 1, t = "RQ", id = 200, it = "Silk Bandage", n = 5, u = now + 86400, ev = now }), "GUILD", "Chilli Heeler")
Tick(1)
local logLine = #ns.GetLog() + 1
INJECT("YNM", Msg({ v = 1, t = "HI", ver = "0.7.0", ask = true }), "GUILD", "Bandit Heeler")
Tick(12)
local function LogCount(text)
    local n, log = 0, ns.GetLog()
    for i = logLine, #log do if log[i]:find(text, 1, true) then n = n + 1 end end
    return n
end
check(LogCount("sent my craft request (") >= 5 and LogCount("to Bandit Heeler") >= 5, "my open requests whispered to Bandit")
logLine = #ns.GetLog() + 1
INJECT("YNM", Msg({ v = 1, t = "REQ", w = "RQS" }), "WHISPER", "Bingo Heeler")
Tick(30)
check(LogCount("sent my Chilli Heeler's craft request") == 1, "asked for them: a copy of Chilli's goes to Bingo")

-- History: a request someone said they'd make, then nobody did (it runs out).
INJECT("YNM", Msg({ v = 1, t = "RQ", id = 300, it = "Silk Cloak", n = 1, u = GetServerTime() + 86400, ev = GetServerTime() }), "GUILD", "Bingo Heeler")
Tick(1)
INJECT("YNM", Msg({ v = 1, t = "CL", o = "Bingo Heeler", id = 300 }), "GUILD", "Bandit Heeler")
Tick(1)

-- Requests end after 3 days.
Tick(3 * 86400 + 60, 600)
check(#R.List() == 0, "three days later they've all ended")

-- History: what finished and how.
local hist = R.History(nil, "")
local function Find(owner, item)
    for _, r in ipairs(hist) do if r.owner == owner and R.ItemName(r) == item then return r end end
end
local bluey = Find("Bluey Heeler", "Linen Bag")
check(bluey and R.Outcome(bluey) == "done" and R.Claimers(bluey)[1] == "Chilli Heeler", "Bluey's Linen Bags: done, Chilli on it")
local silk = Find("Bingo Heeler", "Silk Cloak")
check(silk and R.Outcome(silk) == "expired" and R.Claimers(silk)[1] == "Bandit Heeler", "Bingo's Silk Cloak ran out; Bandit had said they'd make it")
check(#R.History(nil, "silk") >= 1 and #R.History(nil, "zzz") == 0, "filter by item")
local rec = R.Record("Bandit Heeler")
check(rec.letDown == 1, "Bandit's record: said they'd make one that ran out")
rec = R.Record("Chilli Heeler")
check(rec.made == 1 and rec.asked >= 1, "Chilli's record: made one for someone, asked for one")
rec = R.Record("Ned Jones")
check(rec.asked >= 6 and rec.done == 1, "my record: what I asked for and the one I marked done")
check(R.WhoIs("bluey") == "Bluey Heeler" and R.WhoIs("Bluey Heeler") == "Bluey Heeler" and R.WhoIs("b") == nil, "a filter of a first name means that guildie")

-- A guildie who asks gets last week's finished requests too, with what they were and who was on it.
logLine = #ns.GetLog() + 1
INJECT("YNM", Msg({ v = 1, t = "REQ", w = "RQS" }), "WHISPER", "Chilli Heeler")
Tick(40)
check(LogCount("sent my Bingo Heeler's craft request (Silk Cloak x1) to Chilli Heeler") == 1, "finished requests go in the copies, in full")
-- And we take a finished one we'd never seen from a copy (from a guildie we asked).
local reqPeer
for _, m in ipairs(Sent("REQ", 1, function(m) return m.w == "RQS" end)) do reqPeer = m._target end


-- The view: Request on a recipe row fills the form with that recipe; Post sends it.
ns.UI.Open("professions")
local page
for _, o in ipairs(CREATED) do if o.pickView and o.reqView then page = o end end
page.pickView(1)
Tick(1)
local rowBtn
for _, o in ipairs(CREATED) do if o.request and o.rid == 3755 and o:IsShown() then rowBtn = o.request end end
check(rowBtn ~= nil, "Linen Bag's row has a Request button")
rowBtn:Click()
Tick(1)
check(page.view == 2 and page.form and page.form.rid == 3755 and page.formFrame:IsShown(), "it opens the request form for Linen Bag")
before = #SENT
page.formFrame.post:Click()
rq = Sent("RQ", before + 1)
check(#rq == 1 and rq[1].rid == 3755, "posted a request for exactly that recipe")
Tick(1)
check(not page.formFrame:IsShown() and page.cards[1]:IsShown(), "back to the list, my request on it")

-- Picking the item: suggestions as you type, Enter takes the first, an exact typed name links the
-- recipe, and dropping an item from the bags fills it in.
page.newBtn:Click()
Tick(1)
local f = page.formFrame
f.item:SetText("bag")
f.item._scripts.OnTextChanged(f.item, true)
Tick(1)
check(f.suggBox:IsShown() and f.sugg[1].recipe == "Linen Bag" and f.sugg[2].recipe == "Woolen Bag", "typing 'bag' suggests Linen Bag and Woolen Bag")
f.sugg[2]:Click()
Tick(1)
check(page.form.rid == 3757 and f.fixed:IsShown() and not f.suggBox:IsShown(), "clicking a suggestion picks that recipe")
f.change:Click()
Tick(1)
check(page.form.rid == nil and f.item:IsShown(), "Change lets me pick again")
f.item:SetText("linen")
f.item._scripts.OnTextChanged(f.item, true)
Tick(1)
f.item._scripts.OnEnterPressed(f.item)
Tick(1)
check(page.form.rid == 3755, "Enter takes the first suggestion")
f.change:Click()
FAKE.cursor = { "item", 4245, "|cffffffff|Hitem:4245::::::::22:::::::|h[Woolen Bag]|h|r" }
f.item._scripts.OnReceiveDrag(f.item)
Tick(1)
check(page.form.rid == 3757 and FAKE.cursor == nil, "dropping a Woolen Bag from the bags picks the recipe")
f.change:Click()
FAKE.cursor = { "item", 2589, "|cffffffff|Hitem:2589::::::::22:::::::|h[Linen Cloth]|h|r" }
f.item._scripts.OnReceiveDrag(f.item)
Tick(1)
check(page.form.rid == nil and f.item:GetText() == "Linen Cloth", "an item nobody can make is kept as typed text")
f.item:SetText("woolen bag")
-- How many: typed into the box as well as - and +, kept to 1-20.
f.n:SetText("99"); f.n._scripts.OnEnterPressed(f.n)
check(page.form.n == 20 and f.n:GetText() == "20", "typing 99 in How many? gives 20 (the most)")
f.n:SetText(""); f.n._scripts.OnEditFocusLost(f.n)
check(page.form.n == 1 and f.n:GetText() == "1", "an empty How many? gives 1")
f.n:SetText("15"); f.n._scripts.OnEnterPressed(f.n)
check(page.form.n == 15, "typing 15 in How many? sets 15")
f.plus:Click()
check(page.form.n == 16, "and + still works from the typed number")
Tick(1)
f.minus:Click()
before = #SENT
f.post:Click()
rq = Sent("RQ", before + 1)
check(#rq == 1 and rq[1].rid == 3757, "a typed name that matches a recipe exactly is linked to it")
check(rq[1].n == 15, "the typed number goes out with the request (" .. tostring(rq[1].n) .. ")")
Tick(1)

-- The History view: rows and the summary; clicking a row shows that guildie's record.
page.pickView(3)
Tick(1)
check(page.histView:IsShown() and page.histRows[1]:IsShown(), "History view lists finished requests")
check(page.histSummary:GetText():find("Last 30 days", 1, true), "with a summary for the guild")
page.histFilter:SetText("silk")
ns.UI.Dirty()
Tick(1)
local silkRow
for _, row in ipairs(page.histRows) do if row:IsShown() and row.owner == "Bingo Heeler" then silkRow = row end end
check(silkRow and silkRow.what:GetText():find("said they'd make it", 1, true), "Bingo's row flags that Bandit said they'd make it")
silkRow:Click()
Tick(1)
check(page.histFilter:GetText() == "Bingo Heeler" and page.histSummary:GetText():find("asked for 1", 1, true), "clicking it shows Bingo's record")
page.histFilter:SetText("")
page.pickView(2)
Tick(1)

-- After 30 days, finished requests are forgotten.
Tick(31 * 86400, 3600)
FireEvent("PLAYER_LOGIN")
Tick(10)
local left = 0
for _, r in pairs(R.Store()) do if R.EndTime(r) and R.EndTime(r) < GetServerTime() - R.KEEP_LOG then left = left + 1 end end
check(left == 0, "finished requests older than 30 days are tidied away")

-- Sim: fake requests; a fake crafter says she'll make mine.
SlashCmdList.YEAHNAHMATE("dev sim on")
Tick(20)
local fakes = 0
for _, x in ipairs(R.List()) do if ns.Sim.IsFake(x.owner) then fakes = fakes + 1 end end
check(fakes == 2, "two fake requests (" .. fakes .. ")")
local fresh = R.Post(nil, "Sim test", 1, "")
Tick(8)
check(R.Claimers(R.Store()[fresh])[1] == "Shazza Kettle", "Shazza says she'll make mine")

ns.UI.Select("professions")
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
fakes = 0
for _, x in pairs(R.Store()) do if x.owner == "Davo Thongs" or x.owner == "Gazza Billabong" then fakes = fakes + 1 end end
check(fakes == 0, "sim off: fake requests gone")
for _, m in ipairs(SENT) do
    if m.channel == "WHISPER" and ns.Sim.IsFake(m.target) then check(false, "whispered a fake guildie: " .. m.target) end
end
check(#UISpecialFrames == 0 and PanelManagerCalls == 0, "no taint tripwires touched")
check(#ERRORS == 0, "no errors (" .. (ERRORS[1] or "none") .. ")")
