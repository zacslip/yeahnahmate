-- Fixes from the review of 0.17.1 (Nov 2026), one block per finding: Ask's Post clicked twice, up to five
-- "who made it" ticks, cancelling my own event asks first, the request form opens empty, the first-run
-- questions after joining a guild, the milestone/welcome switch says what it covers.
YeahNahMateDB = nil
local ns = LoadAddon("YeahNahMate", "YeahNahMate")
LOGGED_IN = true
FireEvent("PLAYER_LOGIN")
Tick(15)
local UI, L = ns.UI, ns.L
ns.settings.sharePosition, ns.settings.shareProfessions = false, false

local function Page(test)
    for _, o in ipairs(CREATED) do if test(o) then return o end end
end

-- 1. Ask: a second click on Post before the redraw does nothing (no error).
UI.Open("ask")
Tick(1)
local ask = Page(function(o) return o.formFrame and o.listView and o.cardView end)
ask.askBtn:Click()
ask.formFrame.text:SetText("What level is Deadmines?")
ask.formFrame.post:Click()
ask.formFrame.post:Click()          -- the form is still up for a moment
Tick(1)
check(#ERRORS == 0, "Post twice: no error (" .. tostring(ERRORS[1]) .. ")")
local mine = 0
for _, q in pairs(ns.Questions.Store()) do if q.owner == ns.me then mine = mine + 1 end end
check(mine == 1, "and one question, not two")

-- 2. Requests: five people on it, five ticks to credit them.
UI.Open("professions")
Tick(1)
local pp = Page(function(o) return o.histView and o.reqView and o.profMenu end)
local key = ns.Requests.Post(nil, "Linen Bag", 1, "")
local r = ns.Requests.Store()[key]
for _, n in ipairs({ "Bluey Heeler", "Bingo Heeler", "Chilli Heeler", "Bandit Heeler", "Muffin Heeler" }) do
    if ns.Guild.IsMember(n) then r.cl[n] = GetServerTime() end
end
local on = #ns.Requests.Claimers(r)
pp.pickView(2)
Tick(1)
local card
for _, c in ipairs(pp.cards) do if c.key == key then card = c end end
check(card ~= nil and #card.makers == 5, "five tick boxes on a request card")
card.done:Click()
Tick(1)
local shown = 0
for _, mk in ipairs(card.makers) do if mk.box:IsShown() then shown = shown + 1 end end
check(shown == math.min(on, 5) and on >= 4, "Done with " .. on .. " on it: a tick for each (" .. shown .. ")")
pp.picking = nil

-- 3. The request form opens empty after a cancelled one.
pp.newBtn:Click()
Tick(1)
pp.formFrame.item:SetText("Wool Bandage"); pp.formFrame.note:SetText("asap")
pp.formFrame.cancel:Click()
Tick(1)
pp.newBtn:Click()
Tick(1)
check(pp.formFrame.item:GetText() == "" and pp.formFrame.note:GetText() == "", "New request opens empty after a cancel")

-- 4. Cancelling my own event: the first click asks, the second cancels.
local at = GetServerTime() + 86400
local ek = ns.Calendar.Save(nil, { title = "Guild night", at = at, k = "s" })
UI.Open("calendar")
local cal = Page(function(o) return o.dayPager end)
local dt = date("*t", at)
cal.offset, cal.sel, cal.mode = (dt.month ~= date("*t").month) and 1 or 0, dt.day, nil
UI.Select("calendar")
Tick(1)
local box
for _, b in ipairs(cal.details) do if b:IsShown() and b.key == ek then box = b end end
check(box and box.remove:IsShown(), "my event shows Remove")
box.remove:Click()
Tick(1)
check(not ns.Calendar.Store()[ek].x and box.remove:GetText() == L.MS_SURE, "first click asks Sure?")
box.remove:Click()
Tick(1)
check(ns.Calendar.Store()[ek].x == true, "second click cancels it")

-- 5. The milestone switch names welcomes too.
check(L.SET_MS_POST:find("welcomes", 1, true) and L.SET_MS_POST_TIP:find("welcome", 1, true), "the switch says it covers welcomes")

-- 6. Joining a guild mid-session asks the two sharing questions.
local guild = FAKE.guild
if YeahNahMateWelcome then YeahNahMateWelcome:Hide() end       -- the one from this login
FAKE.guild = nil
ns.settings.sharePosition, ns.settings.shareProfessions = nil, nil
FireEvent("PLAYER_GUILD_UPDATE")
Tick(10)
check(not ns.Welcome.IsShown(), "no guild: not asked")
FAKE.guild = guild
FireEvent("PLAYER_GUILD_UPDATE")
Tick(10)
check(ns.Welcome.IsShown(), "joined a guild: asked straight away")

check(#ERRORS == 0, "no errors (" .. tostring(ERRORS[1]) .. ")")
