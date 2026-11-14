-- Alt links and the Crafty Bugger (0.12.0, 12 Nov 2026). A guildie's characters on one WoW account
-- link up by themselves (each character says which others are its own; a link counts only when both
-- say so), and points (Lore Master, Crafty Bugger) go to the person.
math.randomseed(47)
-- This account has played Bandit Heeler (in the guild) and Old Toon (not in it) before.
YeahNahMateDB = { chars = { ["Bandit Heeler"] = {}, ["Old Toon"] = {} } }
local ns = LoadAddon("YeahNahMate", "YeahNahMate")
LOGGED_IN = true
FireEvent("PLAYER_LOGIN")
local Ser = LibStub("AceSerializer-3.0")
local function Msg(t) t.v = 1; return Ser:Serialize(t) end
local function Sent(from, t)
    local out = {}
    for i = from, #SENT do
        local ok, m = Ser:Deserialize(SENT[i].text)
        if ok and type(m) == "table" and (not t or m.t == t) then m._target = SENT[i].target; out[#out + 1] = m end
    end
    return out
end
local function Has(list, x) for _, v in ipairs(list) do if v == x then return true end end return false end
ns.settings.sharePosition, ns.settings.shareProfessions = false, false
for _, name in ipairs({ "Bluey Heeler", "Chilli Heeler", "Bingo Heeler" }) do
    INJECT("YNM", Msg({ t = "HI", ver = "0.11.0" }), "GUILD", name)
end
local start = #SENT + 1
Tick(15)
local A, R, Q, UI = ns.Alts, ns.Requests, ns.Questions, ns.UI
local now = GetServerTime()
local function Say(from, msg, channel) INJECT("YNM", Msg(msg), channel or "GUILD", from) end

-- My characters ------------------------------------------------------------------------------------
local mine = A.MyCharacters()
check(#mine == 2 and mine[1] == "Bandit Heeler" and mine[2] == "Ned Jones", "my characters: this one and Bandit (Old Toon isn't in the guild)", table.concat(mine, ","))
local alt = Sent(start, "ALT")
check(#alt == 1 and alt[1].al[1] == "Bandit Heeler" and #alt[1].al == 1 and alt[1]._target == nil,
    "I tell the guild Bandit is mine")
check(alt[1].mn == "Bandit Heeler", "the main is the highest level one (Bandit, 24) until I pick", tostring(alt[1].mn))
check(not A.IsLinked("Bandit Heeler") and A.Person("Ned Jones") == "Ned Jones", "not linked until Bandit says so too")
-- A roster change doesn't send it again.
FireEvent("GUILD_ROSTER_UPDATE"); Tick(2)
check(#Sent(start, "ALT") == 1, "said once, not on every roster update")

-- Bandit logs in (on this account, some other time): now both sides say so.
Say("Bandit Heeler", { t = "ALT", al = { "Ned Jones" }, mn = "Bandit Heeler", ev = now })
Tick(1)
check(A.IsLinked("Bandit Heeler") and A.Person("Ned Jones") == "Bandit Heeler" and A.Person("Bandit Heeler") == "Bandit Heeler",
    "linked: I'm Bandit's alt")
local chars = A.Characters("Ned Jones")
check(#chars == 2 and chars[1] == "Bandit Heeler" and chars[2] == "Ned Jones", "the person's characters, main first")

-- Picking my main.
A.SetMain("Ned Jones")
Tick(1)
local last = Sent(start, "ALT")
check(last[#last].mn == "Ned Jones" and last[#last].ev > now, "picking a main tells the guild")
check(A.Person("Bandit Heeler") == "Ned Jones", "and the newest record's main wins")

-- Nobody can claim someone else's character -------------------------------------------------------
Say("Chilli Heeler", { t = "ALT", al = { "Ned Jones", "Bluey Heeler" }, mn = "Chilli Heeler", ev = now })
Tick(1)
check(A.Person("Chilli Heeler") == "Chilli Heeler" and A.Person("Bluey Heeler") == "Bluey Heeler" and A.Person("Ned Jones") == "Ned Jones",
    "Chilli saying she's me (or Bluey) links nothing")
-- Bluey and Bingo are one person: both say so.
Say("Bluey Heeler", { t = "ALT", al = { "Bingo Heeler" }, mn = "Bluey Heeler", ev = now })
Say("Bingo Heeler", { t = "ALT", al = { "Bluey Heeler" }, mn = "Bluey Heeler", ev = now })
Tick(1)
check(A.Person("Bingo Heeler") == "Bluey Heeler" and A.Same("Bingo Heeler", "Bluey Heeler"), "Bluey and Bingo link up")
-- Bingo, newer, says Bingo's the main now (Bluey hasn't logged in since).
Say("Bingo Heeler", { t = "ALT", al = { "Bluey Heeler" }, mn = "Bingo Heeler", ev = now + 5 })
Tick(1)
check(A.Person("Bluey Heeler") == "Bingo Heeler", "the newest record says who's the main")
-- An older one doesn't roll it back.
Say("Bingo Heeler", { t = "ALT", al = { "Bluey Heeler" }, mn = "Bluey Heeler", ev = now + 1 })
Tick(1)
check(A.Person("Bluey Heeler") == "Bingo Heeler", "an older record doesn't win")

-- Turning linking off breaks it for everyone.
local before = #SENT + 1
A.SetLinking(false)
Tick(1)
local off = Sent(before, "ALT")
check(#off == 1 and #off[1].al == 0 and off[1].mn == nil, "unticking sends an empty list")
check(A.Person("Bandit Heeler") == "Bandit Heeler" and A.Person("Ned Jones") == "Ned Jones", "and we're apart")
A.SetLinking(true)
Tick(1)
check(A.Person("Bandit Heeler") == "Ned Jones", "ticking it again links us again")

-- Copies -------------------------------------------------------------------------------------------
-- An unasked copy is dropped.
Say("Chilli Heeler", { t = "ALT", o = "Bandit Heeler", al = {}, ev = now + 999 }, "WHISPER")
Tick(1)
check(A.Person("Bandit Heeler") == "Ned Jones", "a copy nobody asked for is dropped")
-- At 55 s I ask one guildie for everyone's links; their copy counts.
Tick(60)
local asks = Sent(start, "REQ")
local peer
for _, m in ipairs(asks) do if m.w == "ALT" then peer = m._target end end
check(peer ~= nil, "after logging in I ask one guildie for the alt links")
Say(peer, { t = "ALT", o = "Bandit Heeler", al = { "Ned Jones" }, mn = "Ned Jones", ev = now + 2 }, "WHISPER")
Tick(1)
check(A.Store()["Bandit Heeler"].ev == now + 2, "the asked-for copy is taken (newer)")
-- They ask me: my record goes as mine, Bandit's (saved on this account) as a copy.
before = #SENT + 1
Say("Chilli Heeler", { t = "REQ", w = "ALT" }, "WHISPER")
Tick(1)
local mineMsg, banditMsg
for _, m in ipairs(Sent(before, "ALT")) do
    if m.o == nil then mineMsg = m elseif m.o == "Bandit Heeler" then banditMsg = m end
end
check(mineMsg and banditMsg and mineMsg._target == "Chilli Heeler", "asked, I whisper mine and the copies I hold")
local v = ns.Sync.Versions("alts", "Bingo Heeler")
check(#v == 1 and v[1] == now + 5, "Sync counts each guildie's record")

-- Lore Master: points go to the person ---------------------------------------------------------------
local function Done(owner, id, hp, daysAgo)
    local at = now - daysAgo * 86400
    Say(owner, { t = "QQ", id = id, tx = "Q" .. id, tp = "other", u = at + 3600, at = at, ev = at + 60, x = "done", hp = hp })
end
Done("Chilli Heeler", 200, { "Bluey Heeler" }, 5)
Done("Chilli Heeler", 201, { "Bingo Heeler" }, 4)
Done("Chilli Heeler", 202, { "Bluey Heeler", "Bingo Heeler" }, 3)       -- one person: one point
Done("Bluey Heeler", 203, { "Bingo Heeler" }, 2)                        -- your own alt: no point
Tick(1)
check(Q.Points("Bluey Heeler") == 3 and Q.Points("Bingo Heeler") == 3, "both characters' answers count for the person (3, not 4 or 5)", Q.Points("Bluey Heeler"))
check(Q.LoreMaster() == "Bingo Heeler" and Q.IsLoreMaster("Bluey Heeler"), "the Lore Master is the person (named by their main)")
check(UI.Badges("Bluey Heeler"):find("Book", 1, true) and UI.Badges("Bingo Heeler"):find("Book", 1, true), "the book shows on both characters")

-- The Crafty Bugger --------------------------------------------------------------------------------
local function Made(owner, id, mk, daysAgo)
    local at = now - daysAgo * 86400
    Say(owner, { t = "RQ", id = id, it = "Thing " .. id, n = 1, note = "", u = at + 86400, at = at, ev = at })
    Say(owner, { t = "RQ", id = id, ev = at + 60, x = "done", mk = mk })
end
Made("Chilli Heeler", 300, { "Bluey Heeler" }, 5)
Made("Chilli Heeler", 301, { "Bingo Heeler" }, 4)
Made("Chilli Heeler", 302, { "Bluey Heeler" }, 3)
Made("Bluey Heeler", 303, { "Bingo Heeler" }, 2)                        -- made for your own alt: no point
Made("Chilli Heeler", 304, { "Chilli Heeler" }, 2)                      -- yourself: not even kept
Tick(1)
check(R.Points("Bluey Heeler") == 3 and R.CraftyBugger() == "Bingo Heeler", "3 made between Bluey and Bingo: Crafty Bugger", R.Points("Bluey Heeler"))
check(R.IsCraftyBugger("Bluey Heeler") and UI.Badges("Bluey Heeler"):find("Wrench", 1, true), "the wrench shows on both characters")
check(R.Store()["Chilli Heeler:304"].mk == nil, "nobody makes their own request")
check(not R.IsCraftyBugger("Chilli Heeler") and R.Points("Chilli Heeler") == 0, "Chilli has none")

-- My requests: one guildie on it is named automatically; with two, I tick who made it.
local k1 = R.Post(nil, "Linen Bag", 1, "")
Say("Chilli Heeler", { t = "CL", o = "Ned Jones", id = R.Store()[k1].id })
Tick(1)
before = #SENT + 1
R.Finish(k1, "done")
local fin = Sent(before, "RQ")
check(#fin == 1 and fin[1].x == "done" and fin[1].mk and fin[1].mk[1] == "Chilli Heeler", "one on it: Done names them")
local k2 = R.Post(nil, "Woolen Bag", 1, "")
Say("Chilli Heeler", { t = "CL", o = "Ned Jones", id = R.Store()[k2].id })
Say("Bluey Heeler", { t = "CL", o = "Ned Jones", id = R.Store()[k2].id })
Tick(1)

-- The Professions tab: Done asks who made it first.
UI.Open("professions")
Tick(1)
local page
for _, o in ipairs(CREATED) do if o.histView and o.reqView then page = o end end
page.pickView(2)
UI.Dirty(); Tick(1)
local card
for _, c in ipairs(page.cards) do if c:IsShown() and c.key == k2 then card = c end end
check(card ~= nil, "my request with two on it is listed")
card.done:Click()
UI.Dirty(); Tick(1)
check(page.picking and page.picking.key == k2 and R.Store()[k2].x == nil, "Done first asks who made it")
check(card.makers[1].box:IsShown() and card.makers[2].box:IsShown() and not card.makers[3].box:IsShown()
    and card.cancel:GetText() == ns.L.BACK, "a tick for each of the two, and Back")
local bluey
for j = 1, 2 do if card.makers[j].name == "Bluey Heeler" then bluey = card.makers[j] end end
bluey.box:SetChecked(true)
bluey.box:Click()
before = #SENT + 1
card.done:Click()
UI.Dirty(); Tick(1)
fin = Sent(before, "RQ")
check(#fin == 1 and fin[1].mk and #fin[1].mk == 1 and fin[1].mk[1] == "Bluey Heeler" and page.picking == nil,
    "Done again sends who was ticked")
check(R.Points("Bluey Heeler") == 4, "Bluey's person gets the point", R.Points("Bluey Heeler"))

-- The Crafty Bugger box in the sidebar, and its title on the Legends tab.
UI.ShowLegend("crafty")
UI.Dirty(); Tick(1)
local leg
for _, o in ipairs(CREATED) do if o.titles and o.titleCards then leg = o end end
check(leg:IsShown() and leg.titles[leg.pick].key == "crafty" and leg.who:GetText():find("Bingo Heeler", 1, true),
    "clicking it opens Legends at the Crafty Bugger")
check(leg.rows[1].name:GetText():find("+1 alts", 1, true), "and says they have an alt")
UI.Open("professions")
UI.Dirty(); Tick(1)

-- History says who made it.
page.pickView(3)
UI.Dirty(); Tick(1)
local hist = ""
for _, r in ipairs(page.histRows) do if r:IsShown() then hist = hist .. (r.what:GetText() or "") .. "\n" end end
check(hist:find("Bluey Heeler", 1, true), "History names who made it")

-- A "done" heard without makers (by 0.11 before updating) takes them from a later copy. The copy
-- comes from the guildie I asked for the requests, about someone else's request.
local rqPeer
for _, m in ipairs(Sent(start, "REQ")) do if m.w == "RQS" then rqPeer = m._target end end
check(rqPeer ~= nil, "I asked someone for the requests")
local poster = rqPeer ~= "Chilli Heeler" and "Chilli Heeler" or "Bluey Heeler"
Say(poster, { t = "RQ", id = 305, it = "Old one", n = 1, note = "", u = now + 86400, at = now - 100, ev = now - 100 })
Say(poster, { t = "RQ", id = 305, ev = now - 50, x = "done" })
Tick(1)
check(R.Store()[poster .. ":305"].mk == nil, "a done without makers")
Say(rqPeer, { t = "RQ", o = poster, id = 305, it = "Old one", n = 1, u = now + 86400, ev = now - 50, x = "done",
    mk = { "Bandit Heeler" } }, "WHISPER")
Tick(1)
check(R.Store()[poster .. ":305"].mk and R.Store()[poster .. ":305"].mk["Bandit Heeler"], "the copy's makers are taken (same version)")

-- Done ones with makers are shared for the full 30 days (others for a week), so everyone counts the same.
local store = R.Store()
store["Chilli Heeler:400"] = { owner = "Chilli Heeler", id = 400, it = "Ten days", n = 1, note = "", u = now - 9 * 86400,
    at = now - 10 * 86400, ev = now - 10 * 86400 + 60, endAt = now - 10 * 86400 + 60, x = "done", mk = { ["Bluey Heeler"] = true }, cl = {} }
store["Chilli Heeler:401"] = { owner = "Chilli Heeler", id = 401, it = "Ten days", n = 1, note = "", u = now - 9 * 86400,
    at = now - 10 * 86400, ev = now - 10 * 86400 + 61, endAt = now - 10 * 86400 + 61, x = "cancel", cl = {} }
local rv = ns.Sync.Versions("requests", "Chilli Heeler")
check(Has(rv, now - 10 * 86400 + 60) and not Has(rv, now - 10 * 86400 + 61), "a 10-day-old done with makers still counts; a cancelled one doesn't")

-- Tooltip and Settings ------------------------------------------------------------------------------
local lines = {}
GameTooltip.AddLine = function(_, t) lines[#lines + 1] = t end
UI.MemberTooltip(UIParent, ns.Guild.Get("Bluey Heeler"))
local tip = table.concat(lines, "\n")
check(tip:find("Alt of Bingo Heeler", 1, true) and tip:find(ns.L.CRAFTY_BUGGER, 1, true) and tip:find(ns.L.LORE_MASTER, 1, true),
    "Bluey's tooltip: alt of Bingo, both titles")
lines = {}
UI.MemberTooltip(UIParent, ns.Guild.Get("Bingo Heeler"))
check(table.concat(lines, "\n"):find("Alts: Bluey Heeler", 1, true), "Bingo's tooltip lists the alts")
UI.Open("settings")
UI.Dirty(); Tick(1)
local set
for _, o in ipairs(CREATED) do if o.altsState and o.mainBtn then set = o end end
check(set.altsState:GetText():find("Linked: Bandit", 1, true) and set.mainBtn:GetText() == "Ned Jones", "Settings: linked to Bandit, I'm the main")
set.mainBtn:Click()
Tick(1)
check(A.MyMain() == "Bandit Heeler" and A.Person("Ned Jones") == "Bandit Heeler", "clicking the main button picks the next character")

-- Leavers go ------------------------------------------------------------------------------------------
local keep = FAKE.roster
local without = {}
for _, r in ipairs(keep) do if not r[1]:find("Chilli", 1, true) then without[#without + 1] = r end end
FAKE.roster = without
FireEvent("GUILD_ROSTER_UPDATE"); Tick(2)
check(A.Store()["Chilli Heeler"] == nil, "a guildie who left: their record goes")
FAKE.roster = keep
FireEvent("GUILD_ROSTER_UPDATE"); Tick(2)

check(#ERRORS == 0, "no errors", ERRORS[1])
