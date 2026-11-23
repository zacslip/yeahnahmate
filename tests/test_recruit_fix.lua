-- Credited the wrong person: "Click here", "Are you sure? Yes / No", then one correction, which reaches
-- everyone on this version and doesn't break older ones.
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
local function Count(board, name)
    for _, e in ipairs(board) do if e.name == name then return e.n end end
    return 0
end
local R, UI = ns.Recruit, ns.UI
ns.settings.sharePosition, ns.settings.shareProfessions = false, false
Tick(15)
INJECT("YNM", Msg({ t = "HI", ver = ns.VERSION }), "GUILD", "Bluey Heeler")
INJECT("YNM", Msg({ t = "HI", ver = ns.VERSION }), "GUILD", "Bingo Heeler")
Tick(2)
UI.Open("home")
UI.ToggleRecruit(true)
Tick(1)
local p = UI.recruitPanel.addon

-- Nothing to fix yet, or after a skip.
check(not R.CanFix() and not p.fix:IsShown(), "no answer yet: no link")

-- I credit the wrong person.
check(R.Claim("Bluey Heeler"), "I credit Bluey by mistake")
UI.RecruitRefresh()
check(R.CanFix() and p.fix:IsShown() and p.fix.ask:IsShown() and not p.fix.yes:IsShown(), "the link shows under my answer")
check(p.body.top == -100, "Share moves down to make room for it")

-- Click here, then No: nothing changed.
local before = #SENT
p.fix.ask:Click()
check(p.fix.sure:IsShown() and p.fix.yes:IsShown() and p.fix.no:IsShown() and not p.fix.ask:IsShown(), "Are you sure? Yes / No")
p.fix.no:Click()
check(p.fix.ask:IsShown() and not p.fix.yes:IsShown() and not R.Fixing(), "No: back to the link")

-- Yes: the question comes back, without Bluey. Nothing changes until I pick.
p.fix.ask:Click()
p.fix.yes:Click()
check(R.Fixing() and p.question:IsShown() and not p.answer:IsShown() and p.question.keep:IsShown(), "Yes: the question is back")
check(p.body.top == -150, "the body makes room for the question")
check(not R.CanPick("Bluey Heeler") and R.CanPick("Bingo Heeler"), "I can't re-pick the person I'm correcting")
check(not R.Claim("Bluey Heeler"), "Bluey is refused")
check(#Sent("RCL", before + 1) == 0 and R.MyClaim().by == "Bluey Heeler", "nothing sent, my answer still stands")
check(Count(R.Leaderboard("all"), "Bluey Heeler") == 1, "and Bluey keeps the count for now")

-- Keep my answer.
p.question.keep:Click()
check(not R.Fixing() and p.answer:IsShown() and R.CanFix(), "Keep my answer: back as it was, the change not used")

-- The correction.
p.fix.ask:Click()
p.fix.yes:Click()
Tick(5)
check(R.Claim("Bingo Heeler"), "I pick the right person")
Tick(2)
local sent = Sent("RCL", before + 1)
check(#sent == 1 and sent[1].by == "Bingo Heeler" and sent[1].fx == 1, "the correction goes to the guild")
check(R.MyClaim().by == "Bingo Heeler" and R.MyClaim().fx == 1, "my answer changed")
check(Count(R.Leaderboard("all"), "Bluey Heeler") == 0 and Count(R.Leaderboard("all"), "Bingo Heeler") == 1, "the leaderboard moved")
UI.RecruitRefresh()
check(not R.CanFix() and not p.fix:IsShown() and p.body.top == -82, "one change only: the link is gone")
check(not R.StartFix() and not R.Claim("Bluey Heeler"), "and it can't be changed again")

-- Other people's corrections: order of arrival doesn't matter, and an old copy can't undo one.
local now = GetServerTime()
INJECT("YNM", Msg({ t = "RCL", by = "Ned Jones", at = now - 500 }), "GUILD", "Bandit Heeler")
Tick(1)
INJECT("YNM", Msg({ t = "RCL", by = "Bluey Heeler", at = now - 100, fx = 1 }), "GUILD", "Bandit Heeler")
Tick(1)
check(R.ClaimOf("Bandit Heeler").by == "Bluey Heeler", "a later correction beats a first answer")
INJECT("YNM", Msg({ t = "RCL", by = "Ned Jones", at = now - 500 }), "GUILD", "Bandit Heeler")
Tick(1)
check(R.ClaimOf("Bandit Heeler").by == "Bluey Heeler", "a copy of the first answer can't undo it")
INJECT("YNM", Msg({ t = "RCL", by = "Bingo Heeler", at = now - 50 }), "GUILD", "Bandit Heeler")
Tick(1)
check(R.ClaimOf("Bandit Heeler").by == "Bluey Heeler", "a plain later answer can't either")
-- Someone on an older version: a later plain answer is still ignored, as it always was.
INJECT("YNM", Msg({ t = "RCL", by = "Ned Jones", at = now - 400 }), "GUILD", "Chilli Heeler")
INJECT("YNM", Msg({ t = "RCL", by = "Bluey Heeler", at = now - 300 }), "GUILD", "Chilli Heeler")
Tick(1)
check(R.ClaimOf("Chilli Heeler").by == "Ned Jones", "no correction: the first answer still stands")

-- A claim a manager took off can't be brought back by correcting it.
check(R.Hide("Chilli Heeler"), "a manager takes Chilli's claim off")
local realMe = ns.me
ns.me = "Chilli Heeler"
check(not R.CanFix(), "so Chilli gets no link")
ns.me = realMe

-- The dev console's pretend credit is never saved or sent.
before = #SENT
local saved = ns.Recruit.Store().claims["Ned Jones"]
R.devClaim = { owner = "Ned Jones", by = "Bluey Heeler", at = now }
check(R.CanFix() and R.StartFix(), "pretend credit: the link works")
check(R.Claim("Bingo Heeler") and R.MyClaim().fx == 1, "pretend correction")
check(#Sent("RCL", before + 1) == 0 and ns.Recruit.Store().claims["Ned Jones"] == saved, "nothing sent or saved")
R.devClaim = nil
check(R.MyClaim().by == "Bingo Heeler", "my real answer is untouched")

check(#ns.db.errors == 0, "no errors " .. tostring(ns.db.errors[1] and ns.db.errors[1].msg))
