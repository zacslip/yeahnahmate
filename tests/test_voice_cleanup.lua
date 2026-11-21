-- Proximity voice was removed in 0.22.0: what it left behind is cleaned up, carefully.
local GOOD, LATE, GONE = "Player-1-00000002", "Player-1-00000003", "Player-1-00000004"
YeahNahMateDB = {
    settings = { voiceOn = true, voiceRange = "far", voiceQuietest = 20, voiceGroupFull = false, voiceUnplaced = "quiet",
        voiceCurve = "natural", voiceAlways = { ["Bazza Stubbs"] = true }, voicePause = false, pop = { voice = false, answer = false } },
    voice = { saved = { [GOOD] = 65, [LATE] = 80, [GONE] = 50 } },
    errors = {
        { msg = "Voice.lua:59: attempt to compare a secret string value", count = 343 },
        { msg = "Interface/AddOns/YeahNahMate/UI/Voice.lua:12: oops", count = 1 },
        { msg = "Interface/AddOns/ForeverVoice/Voice.lua:7: not ours", count = 1 },
        { msg = "ForeverVoice.lua:7: not ours either", count = 1 },
        { msg = "Map.lua:10: says Voice.lua:59 in the text", count = 1 },
    },
}

-- Voice chat: GOOD answers at once, LATE only shows a new volume a moment later, GONE can't be read yet.
local vols = { [GOOD] = 10, [LATE] = 20 }
local pendingLate, sets = nil, {}
C_VoiceChat = {
    GetMemberVolume = function(loc) return vols[loc.guid] end,
    SetMemberVolume = function(loc, v)
        sets[#sets + 1] = loc.guid
        if loc.guid == LATE then pendingLate = v else vols[loc.guid] = v end
    end,
}
PlayerLocation = { CreateFromGUID = function(_, guid) return { guid = guid } end }

local ns = LoadAddon("YeahNahMate", "YeahNahMate")
local s = ns.settings

check(s.voiceOn == nil and s.voiceRange == nil and s.voiceQuietest == nil and s.voiceGroupFull == nil and s.voiceUnplaced == nil
    and s.voiceCurve == nil and s.voiceAlways == nil and s.voicePause == nil and s.pop.voice == nil, "old voice settings are gone")
check(s.pop.answer == false, "other pop-up choices are kept")
local kept = {}
for _, e in ipairs(ns.db.errors) do kept[#kept + 1] = e.msg end
check(#kept == 3, "our two old voice errors are cleared, three others stay (" .. #kept .. ")")
check(kept[1]:find("ForeverVoice/Voice.lua", 1, true) and kept[2]:find("^ForeverVoice") and kept[3]:find("^Map.lua"),
    "another addon's Voice.lua and an error that only mentions it are kept")
check(ns.db.voice.saved[GOOD] == 65, "volumes wait for login")

LOGGED_IN = true
FireEvent("PLAYER_LOGIN")
Tick(14)
check(vols[GOOD] == 10, "nothing touched before voice chat has had time")
Tick(1.1)
check(vols[GOOD] == 65 and ns.db.voice.saved[GOOD] == nil, "a volume that reads back right is put back and forgotten")
check(ns.db.voice.saved[LATE] == 80, "a volume that hasn't read back yet is still kept")
check(ns.db.voice.saved[GONE] == 50, "someone it can't read is kept")
for _, g in ipairs(sets) do check(g ~= GONE, "never set blind") end

vols[LATE], pendingLate = pendingLate, nil
Tick(1.1)
check(ns.db.voice.saved[LATE] == nil, "the late answer is confirmed on the next pass")

-- GONE turns up in voice later.
Tick(30)
check(ns.db.voice.saved[GONE] == 50, "still waiting for them")
vols[GONE] = 5
FireEvent("VOICE_CHAT_CHANNEL_MEMBER_ADDED")
Tick(3.1)
check(vols[GONE] == 50 and ns.db.voice == nil, "they join voice: put back, and the voice data is gone")

local n = #sets
FireEvent("VOICE_CHAT_CHANNEL_MEMBER_ADDED")
Tick(10)
check(#sets == n, "nothing runs once it's all done")

-- The minimap glide still knows how long the last gap between positions was.
local Map = ns.Map
local Ser = LibStub("AceSerializer-3.0")
local function Hear(x)
    ns.Comm.Receive(Ser:Serialize({ t = "POS", v = ns.PROTOCOL, m = 1413, x = x, y = 0.5 }), "GUILD", "Bazza Stubbs")
end
local realGet = ns.Guild.Get
ns.Guild.Get = function(name) if name == "Bazza Stubbs" then return { name = name, online = true } end return realGet(name) end
Hear(0.50); Tick(3); Hear(0.51)
local p = Map.pos["Bazza Stubbs"]
check(p and p.x == 0.51 and math.abs(p.gap - 3) < 0.01, "a new position remembers the gap since the last one")

-- Nothing of the feature is left in the code.
check(ns.Voice == nil and Map.Estimate == nil and YeahNahMate_VoiceToggle == nil and ns.UI.BuildVoiceDrawer == nil, "the feature's functions are gone")
local toc = io.open("YeahNahMate/YeahNahMate.toc"):read("*a")
check(not toc:find("Voice.lua", 1, true) and not toc:find("VoiceProbe", 1, true) and not toc:lower():find("proximity", 1, true), "the toc doesn't list it")
check(io.open("YeahNahMate/Bindings.xml") == nil, "no key binding file")
local printed
local realPrint = ns.Print
ns.Print = function(t) printed = t end
ns.Slash("voice")
ns.Print = realPrint
check(printed == ns.L.HELP, "/ynm voice just shows the help")
