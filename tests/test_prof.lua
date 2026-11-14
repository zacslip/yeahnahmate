-- Phase 3: reading my professions, the share question, sending and receiving recipe lists, asking
-- for lists by version, copies of offline guildies' lists, the Professions tab and the Ask button.
math.randomseed(3)
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
local P = ns.Prof

-- Bluey has the addon (so there's someone to hear us).
INJECT("YNM", Msg({ v = 1, t = "HI", ver = "0.3.0" }), "GUILD", "Bluey Heeler")
Tick(20)

-- Both first-run questions, one after the other.
local ask = _G.YeahNahMateWelcome
check(ask and ask:IsShown() and #ask.questions == 2, "the welcome page asks both on one page")
ask.questions[1].no:Click()
ask.questions[2].yes:Click()
local before = #SENT
ask.done:Click()
check(ns.settings.shareProfessions == true and ns.settings.sharePosition == false, "answers saved (position no, professions yes)")
Tick(5)
check(#Sent("PROF", before + 1) == 0, "nothing to send before any profession window was opened")

-- Opening Tailoring reads the learned recipes only.
FAKE.trade = { line = 197, rank = 75, max = 150, recipes = { [3755] = true, [3757] = true, [2387] = false } }
FireEvent("TRADE_SKILL_SHOW")
Tick(2)
local mine = P.MyData()
check(mine.profs[197] and #mine.profs[197].i == 2 and mine.profs[197].r == 75, "Tailoring read: 2 learned recipes, skill 75")
check(mine.pv > 0, "my list has a version")
check(YeahNahMateDB.probe and YeahNahMateDB.probe.professions and YeahNahMateDB.probe.professions["197"], "profession probe saved")
-- 0.9.6: each recipe knows the item it makes (Data/RecipeItems.lua), its icon and its section.
local bag
for _, e in ipairs(P.Search(197, "")) do if e.id == 3755 then bag = e end end
check(bag and bag.item == 4238 and bag.cat == "bags" and bag.icon == 133000 + 4238,
    "Linen Bag recipe: makes item 4238, in Bags, with the item's icon")
check(ns.RecipeItem and ns.RecipeItem[3757] == 4240, "recipe -> item table loaded")
local _, cat = P.ItemInfo(7418, 333)
check(cat == "enchants", "an enchant (no item) goes in Enchants")
-- A linked profession (someone else's) never changes my list.
FAKE.tradeLinked = true
FAKE.trade = { line = 171, rank = 300, max = 300, recipes = { [9999] = true } }
FireEvent("TRADE_SKILL_SHOW")
Tick(2)
check(mine.profs[171] == nil, "a linked profession is ignored")
FAKE.tradeLinked = false
FAKE.trade = nil

-- New recipes go to the guild once, a little later (several windows in a row = one message).
before = #SENT
FAKE.trade = { line = 129, rank = 60, max = 75, recipes = { [3275] = true, [3276] = true } }
FireEvent("TRADE_SKILL_SHOW")
Tick(2)
FAKE.trade = nil
Tick(23)
local profs = Sent("PROF", before + 1)
check(#profs == 1 and profs[1]._channel == "GUILD" and profs[1].p[197] and profs[1].p[129], "one recipe list sent to the guild with both professions")
check(#profs[1].p[197].i == 2, "only recipe IDs are sent")
-- Reopening with nothing new sends nothing.
before = #SENT
FAKE.trade = { line = 197, rank = 75, max = 150, recipes = { [3755] = true, [3757] = true, [2387] = false } }
FireEvent("TRADE_SKILL_SHOW")
Tick(2)
FAKE.trade = nil
Tick(23)
check(#Sent("PROF", before + 1) == 0, "nothing new: nothing sent")

-- Our hello carries the list's version.
local hi = {}
ns.Fire("HI_OUT", hi)
check(hi.pv == mine.pv and hi.ps == true, "HI carries my list version and that I share")

-- Receiving Bluey's list (the owner's own, on GUILD).
INJECT("YNM", Msg({ v = 1, t = "PROF", pv = 500, p = { [171] = { r = 120, m = 150, i = { 2330, 2337 } } } }), "GUILD", "Bluey Heeler")
Tick(1)
local store = P.Store()
check(store["Bluey Heeler"] and store["Bluey Heeler"].direct and store["Bluey Heeler"].pv == 500, "Bluey's list cached")
check(YeahNahMateDB.guilds["The Good Sorts"].profs["Bluey Heeler"] ~= nil, "cached in saved data (searchable when Bluey's offline)")
-- An older version is ignored; junk is dropped.
INJECT("YNM", Msg({ v = 1, t = "PROF", pv = 400, p = { [171] = { r = 1, m = 1, i = { 1 } } } }), "GUILD", "Bluey Heeler")
INJECT("YNM", Msg({ v = 1, t = "PROF", pv = 600, p = { [171] = { r = 1, m = 1, i = { "x" } } } }), "GUILD", "Bingo Heeler")
INJECT("YNM", Msg({ v = 1, t = "PROF", pv = 600, p = "lots" }), "GUILD", "Bingo Heeler")
Tick(1)
check(store["Bluey Heeler"].pv == 500 and store["Bingo Heeler"] == nil, "older versions and junk ignored")
-- A copy nobody asked for is dropped.
INJECT("YNM", Msg({ v = 1, t = "PROF", o = "Bandit Heeler", pv = 700, p = { [164] = { r = 50, m = 75, i = { 2662 } } } }), "WHISPER", "Chilli Heeler")
INJECT("YNM", Msg({ v = 1, t = "PROF", o = "Bandit Heeler", pv = 700, p = { [164] = { r = 50, m = 75, i = { 2662 } } } }), "GUILD", "Chilli Heeler")
Tick(1)
check(store["Bandit Heeler"] == nil, "a copy we didn't ask for is dropped")

-- A hello with a newer version than ours: we ask that guildie for their list (whisper).
before = #SENT
INJECT("YNM", Msg({ v = 1, t = "HI", ver = "0.3.0", pv = 800, ps = true }), "GUILD", "Bluey Heeler")
Tick(5)
local reqs = Sent("REQ", before + 1)
check(#reqs == 1 and reqs[1].w == "PROF" and reqs[1]._target == "Bluey Heeler", "asked Bluey for the newer list")
-- A hello from someone who stopped sharing: their list is forgotten.
INJECT("YNM", Msg({ v = 1, t = "HI", ver = "0.3.0", pv = 900 }), "GUILD", "Bluey Heeler")
Tick(1)
check(store["Bluey Heeler"].off == true, "stopped sharing: Bluey's list forgotten")
-- They share again and send it.
INJECT("YNM", Msg({ v = 1, t = "PROF", pv = 950, p = { [171] = { r = 125, m = 150, i = { 2330, 2337, 3447 } } } }), "WHISPER", "Bluey Heeler")
Tick(1)
check(store["Bluey Heeler"].p and #store["Bluey Heeler"].p[171].i == 3, "a fresh list replaces the forgotten one")

-- Copies of offline guildies' lists: after login we ask one online guildie which lists they have,
-- then for the ones we're missing.
reqs = Sent("REQ", 1, function(m) return m.w == "IDX" end)   -- 30 s after login
check(#reqs == 1 and reqs[1]._target == "Bluey Heeler", "asked Bluey which lists they have")
before = #SENT
INJECT("YNM", Msg({ v = 1, t = "IDX", l = { ["Bandit Heeler"] = 700, ["Ned Jones"] = 5, ["Stranger Danger"] = 9 } }), "WHISPER", "Bluey Heeler")
Tick(5)
reqs = Sent("REQ", before + 1, function(m) return m.w == "PROFS" end)
check(#reqs == 1 and #reqs[1].n == 1 and reqs[1].n[1] == "Bandit Heeler", "asked for Bandit's list only (not mine, not a stranger's)")
INJECT("YNM", Msg({ v = 1, t = "PROF", o = "Bandit Heeler", pv = 700, p = { [164] = { r = 50, m = 75, i = { 2662 } } } }), "WHISPER", "Bluey Heeler")
Tick(1)
check(store["Bandit Heeler"] and not store["Bandit Heeler"].direct, "Bandit's list taken as a copy from Bluey")
-- The owner's own list beats a copy of the same version.
INJECT("YNM", Msg({ v = 1, t = "PROF", pv = 700, p = { [164] = { r = 55, m = 75, i = { 2662, 2663 } } } }), "GUILD", "Bandit Heeler")
Tick(1)
check(store["Bandit Heeler"].direct and #store["Bandit Heeler"].p[164].i == 2, "the owner's own list beats a copy")

-- Answering requests (whispers from guildmates).
before = #SENT
INJECT("YNM", Msg({ v = 1, t = "REQ", w = "PROF" }), "WHISPER", "Chilli Heeler")
INJECT("YNM", Msg({ v = 1, t = "REQ", w = "IDX" }), "WHISPER", "Chilli Heeler")
INJECT("YNM", Msg({ v = 1, t = "REQ", w = "PROFS", n = { "Bluey Heeler", "Bandit Heeler", "Chilli Heeler" } }), "WHISPER", "Chilli Heeler")
Tick(15)
local mineBack = Sent("PROF", before + 1, function(m, s) return s.target == "Chilli Heeler" and not m.o end)
local idx = Sent("IDX", before + 1)
local copies = Sent("PROF", before + 1, function(m, s) return s.target == "Chilli Heeler" and m.o end)
check(#mineBack == 1, "sent my list to Chilli when asked")
check(#idx == 1 and idx[1].l["Bluey Heeler"] == 950, "sent Chilli the index of lists I have")
check(#copies == 2, "sent Chilli copies of Bluey's and Bandit's lists, not Chilli's own (" .. #copies .. ")")
before = #SENT
INJECT("YNM", Msg({ v = 1, t = "REQ", w = "PROF" }), "WHISPER", "Stranger Danger")
Tick(5)
check(#Sent("PROF", before + 1) == 0, "requests from outside the guild are ignored")

-- Search: the tab's data.
local found = P.Search(nil, "bag")
check(#found == 2 and found[1].name == "Linen Bag", "search 'bag' finds Linen Bag and Woolen Bag")
found = P.Search(171, "")
check(#found == 3 and found[1].crafters[1] == "Bluey Heeler", "Alchemy shows Bluey's 3 recipes")
check(P.RecipeName(2330) == "Recipe 2330", "unknown recipe names fall back to 'Recipe <id>'")

-- The tab and the Ask button: whisper box prefilled for the first online crafter, nothing sent.
SlashCmdList.YEAHNAHMATE("")
ns.UI.Select("professions")
local page
for _, o in ipairs(CREATED) do if o.ask and o.recipe then page = page or o end end
local askRow
for _, o in ipairs(CREATED) do
    if o.ask and o.askTo == "Bluey Heeler" and o:IsShown() then askRow = o break end
end
check(askRow ~= nil, "a recipe row offers Ask to Bluey")
for _, o in ipairs(CREATED) do if o.askMenu then page = o end end
local whispersBefore = #WHISPERS
askRow.ask:Click()
local wbox = _G.YeahNahMateWhisper
check(wbox:IsShown() and wbox.edit:GetText():find("Hey Bluey, could you make me", 1, true), "Ask opens the whisper box prefilled: " .. tostring(wbox.edit:GetText()))
check(#WHISPERS == whispersBefore, "and sends nothing by itself")
wbox:Hide()

-- Sharing off: one 'not shared' to the guild; requests get 'not shared' too.
before = #SENT
ns.settings.shareProfessions = false
ns.Fire("SETTINGS")
Tick(3)
local offMsg = Sent("PROF", before + 1)
check(#offMsg == 1 and offMsg[1].p == false, "sharing off tells the guild to forget my list")
hi = {}
ns.Fire("HI_OUT", hi)
check(hi.ps == nil, "HI no longer says I share")
before = #SENT
INJECT("YNM", Msg({ v = 1, t = "REQ", w = "PROF" }), "WHISPER", "Bingo Heeler")
Tick(5)
offMsg = Sent("PROF", before + 1)
check(#offMsg == 1 and offMsg[1].p == false, "asked while not sharing: 'not shared', no recipes")
check(#P.Search(197, "") == 2, "I still see my own recipes in the tab")

-- Unlearning a profession drops it.
FAKE.professions = { 197 }
FireEvent("SKILL_LINES_CHANGED")
Tick(3)
check(mine.profs[129] == nil and mine.profs[197] ~= nil, "unlearned First Aid dropped from my list")

-- 0.9.5: my crafting professions not read yet are named on the tab (gathering ones never are).
check(#P.Unread() == 0, "every profession read: nothing to open")
FAKE.professions = { 197, 171 }
local unread = P.Unread()
check(#unread == 1 and unread[1] == "Alchemy", "Alchemy not opened yet: named")
FAKE.professions = { 182, 197 }
check(#P.Unread() == 0, "Herbalism has no window to open: never named")
FAKE.professions = { 197 }

-- Sim mode: fake crafters show up; nothing is sent or saved for them; nothing whispered to them.
SlashCmdList.YEAHNAHMATE("dev sim on")
Tick(10)
found = P.Search(nil, "bag")
local simBag
for _, e in ipairs(found) do if e.name == "Woolen Bag" then simBag = e end end
check(simBag and #simBag.crafters >= 2, "fake crafters show in the search")
check(YeahNahMateDB.guilds["The Good Sorts"].profs["Shazza Kettle"] == nil, "fake lists are never saved")

-- Click everything with all of it in (the "open your windows" note too).
SlashCmdList.YEAHNAHMATE("dev profhint on")
for pass = 1, 2 do
    local n = #CREATED
    for i = 1, n do
        local o = CREATED[i]
        if o._template == "UIPanelCloseButton" then o = { _scripts = {} } end   -- X buttons have their own test
        if o._name ~= "YeahNahMateWhisper" and o._name ~= "YeahNahMateWelcome" then
            for _, s in ipairs({ "OnClick", "OnMouseUp", "OnEnter", "OnLeave" }) do
                if o._scripts[s] then o._scripts[s](o, "LeftButton") end
            end
            if o._scripts.OnTextChanged then
                o._text = "bag"; o._scripts.OnTextChanged(o)
                o._text = ""; o._scripts.OnTextChanged(o)
            end
        end
    end
    Tick(1)
end
SlashCmdList.YEAHNAHMATE("dev profhint off")
for _, m in ipairs(SENT) do
    if m.channel == "WHISPER" and ns.Sim.IsFake(m.target) then check(false, "whispered a fake guildie: " .. m.target) end
    if #m.text > 255 then check(false, "message over 255 bytes") end
end
SlashCmdList.YEAHNAHMATE("dev sim off")
Tick(1)
check(#P.Search(nil, "Woolen") == 1, "sim off: fake crafters gone (my Woolen Bag stays)")

check(#UISpecialFrames == 0 and PanelManagerCalls == 0, "no taint tripwires touched")
check(#ERRORS == 0, "no errors (" .. (ERRORS[1] or "none") .. ")")
