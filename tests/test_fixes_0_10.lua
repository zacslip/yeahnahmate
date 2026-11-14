-- Fixes from the code review of 0.9.11 + 0.10.0 (Nov 2026): one check per fix (sync counts, the recipe
-- index, letters not bytes, half-typed replies, quest links, the questions sync, saved search text).
math.randomseed(41)
YeahNahMateDB = nil
local ns = LoadAddon("YeahNahMate", "YeahNahMate")
LOGGED_IN = true
FireEvent("PLAYER_LOGIN")
local Ser = LibStub("AceSerializer-3.0")
local function Msg(t) return Ser:Serialize(t) end
ns.settings.sharePosition, ns.settings.shareProfessions = false, false
for _, name in ipairs({ "Bluey Heeler", "Chilli Heeler" }) do
    INJECT("YNM", Msg({ v = 1, t = "HI", ver = "0.10.0" }), "GUILD", name)
end
Tick(15)
local Q = ns.Questions
local now = GetServerTime()

-- 1. Requests: the sync counts only what it would send (not requests finished over a week ago).
local store = ns.Requests.Store()
store["Ned Jones:1"] = { owner = ns.me, id = 1, it = "Linen Bag", n = 1, u = now + 86400, at = now - 10 * 86400,
    ev = now - 9 * 86400, x = "done", endAt = now - 9 * 86400, cl = {} }
store["Ned Jones:2"] = { owner = ns.me, id = 2, it = "Linen Bag", n = 1, u = now + 86400, at = now - 3 * 86400,
    ev = now - 2 * 86400, x = "done", endAt = now - 2 * 86400, cl = {} }
local counted = ns.Sync.Versions("requests", ns.me)
check(#counted == 1 and counted[1] == now - 2 * 86400, "requests: an old finished one isn't counted (it isn't sent either)")
store["Ned Jones:1"], store["Ned Jones:2"] = nil, nil

-- 2. Professions: a saved list from someone the roster hadn't loaded yet joins the index when they show up.
local profs = ns.Prof.Store()
profs["Late Joiner"] = { pv = now, p = { [197] = { r = 100, m = 150, i = { 3755 } } } }
ns.Prof.Fresh()
local function Has(id, name)
    local r = ns.Prof.recipes[id]
    for _, n in ipairs(r and r.crafters or {}) do if n == name then return true end end
    return false
end
check(not Has(3755, "Late Joiner"), "not in the guild roster yet: not in the index")
FAKE.roster[#FAKE.roster + 1] = { "Late Joiner", "Member", 3, 20, "x", "Durotar", "", "", true, 0, "MAGE", 0, 0, false, false, 3, "Player-6797-00000099" }
FireEvent("GUILD_ROSTER_UPDATE")
Tick(10)
ns.Prof.Fresh()
check(Has(3755, "Late Joiner"), "on the roster now: their recipes are in the index")

-- 4. Letters, not bytes.
local curly = string.rep("\226\128\153", 10)          -- ten curly apostrophes, 3 bytes each
check(ns.Letters(curly) == 10 and ns.CutLetters(curly, 4) == string.rep("\226\128\153", 4), "letters are counted and cut whole")
check(ns.ShortText("caf\195\169 " .. string.rep("x", 70), 60):sub(-3) == "...", "shortened text ends in ...")
local long = string.rep("\195\169", 200)               -- 200 accented letters = 400 bytes
local key = Q.Ask(long, "other")
check(key and ns.Letters(Q.Get(key).tx) == 200 and #Q.Get(key).tx == 400, "a 200-letter question with accents keeps all 200 letters")

-- 5. A half-typed reply stays with its own card.
INJECT("YNM", Msg({ v = 1, t = "QQ", id = 50, tx = "Card A", tp = "other", u = now + 3600, at = now, ev = now }), "GUILD", "Bluey Heeler")
INJECT("YNM", Msg({ v = 1, t = "QQ", id = 51, tx = "Card B", tp = "other", u = now + 3600, at = now, ev = now }), "GUILD", "Chilli Heeler")
Tick(1)
ns.UI.ShowQuestion("Bluey Heeler:50")
Tick(1)
local page
for _, o in ipairs(CREATED) do if o.listView and o.cardView then page = o end end
local v = page.cardView
v.reply:SetText("half typed")
page.replyLinks = { { k = "d", id = "rfc" } }
ns.UI.ShowQuestion("Chilli Heeler:51")
Tick(1)
check((v.reply:GetText() or "") == "" and #page.replyLinks == 0, "another card: the reply box and its links start empty")

-- 6. A quest link whose title lookup fails shows "Quest <id>", not an error message.
C_QuestLog = C_QuestLog or {}
local was = C_QuestLog.GetTitleForQuestID
C_QuestLog.GetTitleForQuestID = function() error("bad argument #1") end
check(Q.LinkText({ k = "q", id = 870, n = "" }) == "Quest 870", "a failed title lookup isn't used as the name")
C_QuestLog.GetTitleForQuestID = was

-- 7/8. The questions sync doesn't count posts on others' finished-or-old cards, nor fakes' cards.
local q = Q.Get("Bluey Heeler:50")
q.posts[ns.me] = { p = { { tx = "hi", at = now } }, pv = now + 1 }
q.u = now - 1
local found = false
for _, ver in ipairs(ns.Sync.Versions("questions", ns.me)) do if ver == now + 1 then found = true end end
check(not found, "my post on someone else's card past its 48 hours isn't counted")
q.u = now + 3600
found = false
for _, ver in ipairs(ns.Sync.Versions("questions", ns.me)) do if ver == now + 1 then found = true end end
check(found, "within its 48 hours it is")

-- 10. The search text isn't saved.
Q.List("open", nil, "card")
check(Q.Get("Bluey Heeler:50").hay ~= nil, "searching builds the search text")
FireEvent("PLAYER_LOGOUT")
local any = false
for _, cq in pairs(Q.Store()) do if cq.hay or cq.key then any = true end end
check(not any, "logging out leaves it (and the keys) out of the saved file")
check(#ERRORS == 0, "no errors (" .. (ERRORS[1] or "none") .. ")")
