-- Message handlers run one by one: an error in one module's handler doesn't stop the others for the
-- same message type (pre-release review, 15 Nov 2026).
YeahNahMateDB = nil
local ns = LoadAddon("YeahNahMate", "YeahNahMate")
LOGGED_IN = true
FireEvent("PLAYER_LOGIN")
local Ser = LibStub("AceSerializer-3.0")

local ran = {}
ns.Comm.On("ZZT", function() ran[#ran + 1] = "first"; error("boom") end)
ns.Comm.On("ZZT", function() ran[#ran + 1] = "second" end)

local guildie = ns.Guild.list[1] and ns.Guild.list[1].name
check(guildie ~= nil, "the fake roster has a guildie")
INJECT("YNM", Ser:Serialize({ v = 1, t = "ZZT" }), "GUILD", guildie)
Tick(1)

check(#ran == 2 and ran[2] == "second", "the second handler still ran after the first one failed")
check(#ERRORS == 1 and ERRORS[1]:find("boom", 1, true) ~= nil, "the failure is still reported (once)")
ERRORS = {}
