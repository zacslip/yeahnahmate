-- /ynm dev rank 0 (see the addon as the guild master) shows the All clans roll button, like the GM
-- tab; another rank hides it again. My real rank is a Member, so nothing more is sent.
math.randomseed(26)
YeahNahMateDB = nil
FAKE.myRank = 3
local ns = LoadAddon("YeahNahMate", "YeahNahMate")
LOGGED_IN = true
FireEvent("PLAYER_LOGIN")
ns.settings.sharePosition, ns.settings.shareProfessions = false, false
Tick(15)
local R, UI = ns.ClanRoll, ns.UI
UI.Open("clans"); Tick(1)
local cp
for _, o in ipairs(CREATED) do if o.cols and o.roleBtns then cp = o end end
check(not R.CanStartAll() and not cp.rollBtn:IsShown(), "a Member: no All clans roll")
ns.devCommands.rank("0"); UI.Dirty(); Tick(1)
check(R.CanStartAll() and cp.rollBtn:IsShown() and ns.Board.CanManage(), "dev rank 0: the button shows, like the GM tab")
ns.devCommands.rank("2"); UI.Dirty(); Tick(1)
check(not cp.rollBtn:IsShown(), "dev rank 2: hidden again")
ns.devCommands.rank("off"); UI.Dirty(); Tick(1)
check(not cp.rollBtn:IsShown(), "off: hidden (my real rank)")
check(#ERRORS == 0, "no errors (" .. tostring(ERRORS[1]) .. ")")
