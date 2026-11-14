-- Sim mode shows alt links and the Crafty Bugger (0.12.0): Mick is Shazza's alt, and between them
-- they made three requests. Nothing about the fakes goes out.
math.randomseed(53)
YeahNahMateDB = nil
local ns = LoadAddon("YeahNahMate", "YeahNahMate")
LOGGED_IN = true
FireEvent("PLAYER_LOGIN")
local Ser = LibStub("AceSerializer-3.0")
ns.settings.sharePosition, ns.settings.shareProfessions = false, false
Tick(15)
local A, R, UI = ns.Alts, ns.Requests, ns.UI

ns.devCommands.sim("on")
Tick(70)
check(A.Person("Mick Larrikin") == "Shazza Kettle", "sim: Mick is Shazza's alt")
check(R.CraftyBugger() == "Shazza Kettle" and R.Points("Mick Larrikin") == 3, "sim: Shazza is the Crafty Bugger (3 made between them)")
check(UI.Badges("Mick Larrikin"):find("Wrench", 1, true), "sim: the wrench shows on Mick too")

-- My request: Shazza (fake) says she'll make it; Done names her on my screen, but not in the message.
local key = R.Post(nil, "Linen Bag", 1, "")
Tick(6)
local first = #SENT + 1
R.Finish(key, "done")
Tick(1)
check(R.Store()[key].mk and R.Store()[key].mk["Shazza Kettle"], "sim: my Done names Shazza here")
local leaked = false
for i = first, #SENT do
    local ok, m = Ser:Deserialize(SENT[i].text)
    if ok and type(m) == "table" and type(m.mk) == "table" and #m.mk > 0 then leaked = true end
end
check(not leaked, "sim: her name doesn't go out")

ns.devCommands.sim("off")
Tick(1)
check(next(A.Store()) == nil and R.CraftyBugger() == nil, "sim off: the fakes' links and points are gone")
check(R.Store()[key].mk == nil, "sim off: and Shazza's name is off my request")
check(#ERRORS == 0, "no errors", ERRORS[1])
