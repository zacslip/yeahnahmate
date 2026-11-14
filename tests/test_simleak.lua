-- Sim mode stays on my screen : fake guildies' messages never go out, and nothing
-- about a fake guildie's event, request or question goes out either: my answers to them, my claims,
-- my "going", or copies for a real guildie catching up. The fakes still react as if it had gone.
math.randomseed(31)
YeahNahMateDB = nil
local ns = LoadAddon("YeahNahMate", "YeahNahMate")
LOGGED_IN = true
FireEvent("PLAYER_LOGIN")
local Ser = LibStub("AceSerializer-3.0")
local function Msg(t) return Ser:Serialize(t) end
ns.settings.sharePosition, ns.settings.shareProfessions = false, false
INJECT("YNM", Msg({ v = 1, t = "HI", ver = "0.10.0" }), "GUILD", "Bluey Heeler")
Tick(15)

ns.devCommands.sim("on")
Tick(70)
local first = #SENT + 1

-- About fakes' things: answer Bazza's question, say I'm going to a fake event, claim a fake request.
local Q = ns.Questions
local bazza
for _, q in ipairs(Q.List("open")) do if q.owner == "Bazza Stubbs" then bazza = q end end
check(bazza ~= nil, "Bazza's fake question is there")
Q.Post(bazza.key, "Go at 22, you'll be right")
for key, e in pairs(ns.Calendar.Store()) do
    if ns.Sim.IsFake(e.owner) and not e.x then ns.Calendar.Answer(key, e.at, "y"); break end
end
for key, r in pairs(ns.Requests.Store()) do
    if ns.Sim.IsFake(r.owner) and not r.x then ns.Requests.Claim(key, true); break end
end
-- A real guildie catching up asks me for everything I know.
for _, w in ipairs({ "QS", "CAL", "RQS", "BRD" }) do
    INJECT("YNM", Msg({ v = 1, t = "REQ", w = w }), "WHISPER", "Bluey Heeler")
end
Tick(30)

local leaks, out = {}, 0
for i = first, #SENT do
    local ok, m = Ser:Deserialize(SENT[i].text)
    if ok and type(m) == "table" then
        out = out + 1
        if ns.Sim.IsFake(m.o) or ns.Sim.IsFake(m.by) or ns.Sim.IsFake(SENT[i].target) then leaks[#leaks + 1] = m.t .. " " .. tostring(m.o) end
        for _, name in ipairs(type(m.hp) == "table" and m.hp or {}) do
            if ns.Sim.IsFake(name) then leaks[#leaks + 1] = "hp " .. name end
        end
    end
end
check(#leaks == 0, "nothing about a fake guildie went out (" .. (leaks[1] or "none") .. ", " .. #leaks .. " of " .. out .. ")")
check(#Q.Get(bazza.key).posts[ns.me].p == 1, "my answer to Bazza still shows on my screen")
check(#Q.Get(bazza.key).posts["Bazza Stubbs"].p == 2, "and Bazza still replies to it")

-- My own real question does go out (that's real), but a fake I tick as helping is left off.
NOW = NOW + 120
local key = Q.Ask("Real question while testing", "other")
Tick(20)
local mark = #SENT + 1
Q.Finish(key, { "Shazza Kettle" })
local sentDone
for i = mark, #SENT do
    local ok, m = Ser:Deserialize(SENT[i].text)
    if ok and m.t == "QQ" and m.x == "done" then sentDone = m end
end
check(key and sentDone and #sentDone.hp == 0, "my question went out; the fake helper's name didn't")
ns.devCommands.sim("off")

-- Pre-release test questions: forgotten once, at the next log-in after this version; never again after that.
check(#Q.List("mine") >= 1, "my test question is there")
ns.db.questionsCleared1 = nil
ns.Fire("LOGIN")
check(next(Q.Store()) == nil and ns.db.questionsCleared1 == true, "the one-time clear-out forgets every question")
NOW = NOW + 120
local again = Q.Ask("A question after the clear-out", "other")
ns.Fire("LOGIN")
check(again and Q.Get(again) ~= nil, "it only happens once")
check(#ERRORS == 0, "no errors (" .. (ERRORS[1] or "none") .. ")")
