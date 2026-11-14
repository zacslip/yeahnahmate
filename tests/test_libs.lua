-- The bundled libraries load under the fake API, and AceComm/AceSerializer carry a message from
-- us back to us over GUILD, including one long enough to be split into pieces.
local ns = LoadAddon("YeahNahMate", "YeahNahMate")

check(LibStub ~= nil, "LibStub loaded")
local AceComm = LibStub("AceComm-3.0", true)
local AceSer = LibStub("AceSerializer-3.0", true)
local HBD = LibStub("HereBeDragons-2.0", true)
local Pins = LibStub("HereBeDragons-Pins-2.0", true)
check(AceComm and AceSer and HBD and Pins, "AceComm, AceSerializer, HereBeDragons and Pins loaded")
check(ns.PREFIX == "YNM" and ns.PROTOCOL == 1, "core namespace set up")

-- Serializer round trip.
local msg = { v = 1, t = "HI", ver = "0.0.1", n = 42, list = { "a", "b" }, ok = true }
local ok, back = AceSer:Deserialize(AceSer:Serialize(msg))
check(ok and back.t == "HI" and back.n == 42 and back.list[2] == "b" and back.ok == true, "AceSerializer round trip")

-- AceComm over GUILD comes back to the sender (as the game does).
-- ChatThrottleLib throttles hard for the first seconds after login, as in the game: wait it out.
Tick(10)
local got = {}
local me = {}
AceComm:Embed(me)
me:RegisterComm("YNM", function(prefix, text, channel, sender) got[#got + 1] = { text = text, channel = channel, sender = sender } end)
me:SendCommMessage("YNM", AceSer:Serialize(msg), "GUILD")
Tick(3)
check(#got == 1 and got[1].channel == "GUILD" and got[1].sender == "Ned Jones", "short message delivered back over GUILD")

-- A long message (recipes) is split under 255 bytes and rebuilt.
local long = {}
for i = 1, 300 do long[i] = 2000 + i end
got = {}
local before = #SENT
me:SendCommMessage("YNM", AceSer:Serialize({ v = 1, t = "PROF", ids = long }), "GUILD")
Tick(30)
local pieces = #SENT - before
local ok2, back2 = false, nil
if got[1] then ok2, back2 = AceSer:Deserialize(got[1].text) end
check(pieces > 1, "long message split into " .. pieces .. " pieces")
check(#got == 1 and ok2 and #back2.ids == 300 and back2.ids[300] == 2300, "long message rebuilt intact")
for i = before + 1, #SENT do
    if #SENT[i].text > 255 then check(false, "piece over 255 bytes") end
end

check(#ERRORS == 0, "no errors reported (" .. (ERRORS[1] or "none") .. ")")
