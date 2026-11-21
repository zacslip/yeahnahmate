-- Removing proximity voice: a long list of volumes to put back stays within 8 calls a second.
-- (Its own file: a second copy of the addon in one test would answer the same events.)
local big = {}
for i = 1, 30 do big["Player-1-1" .. string.format("%07d", i)] = 70 end
YeahNahMateDB = { voice = { saved = big } }
local vols, calls = {}, 0
C_VoiceChat = {
    GetMemberVolume = function(loc) return vols[loc.guid] or 10 end,
    SetMemberVolume = function(loc, v) calls = calls + 1; vols[loc.guid] = v end,
}
PlayerLocation = { CreateFromGUID = function(_, guid) return { guid = guid } end }
local ns = LoadAddon("YeahNahMate", "YeahNahMate")
LOGGED_IN = true
FireEvent("PLAYER_LOGIN")
Tick(15.05)
check(calls == 8, "8 volume calls in the first second (" .. calls .. ")")
Tick(1)
check(calls == 16, "8 more in the next (" .. calls .. ")")
Tick(5)
check(calls == 30 and ns.db.voice == nil, "everyone gets their turn, then it's done (" .. calls .. ")")
