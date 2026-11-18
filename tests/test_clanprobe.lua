-- The clan probe (/ynm dev clanprobe): reads races from roster GUIDs, notes whispers without saving
-- what they said or who sent them, never answers, and keeps watching after a reload until turned off.
YeahNahMateDB = nil
local ns = LoadAddon("YeahNahMate", "YeahNahMate")
LOGGED_IN = true
FireEvent("PLAYER_LOGIN")
Tick(5)

-- The game's race lookups (not in the stub): Bandit (offline) isn't cached, Chilli's comes back secret.
local SECRET = {}
local RACES = { ["Player-6797-0000NED1"] = "Orc", ["Player-6797-00000001"] = "Troll",
                ["Player-6925-00000002"] = "Tauren", ["Player-6797-00000003"] = SECRET }
function GetPlayerInfoByGUID(guid)
    local r = RACES[guid]
    if not r then return nil end
    return "Shaman", "SHAMAN", r, r, 2, "x", ""
end
function UnitRace() return "Orc", "Orc", 2 end
function UnitGUID() return "Player-6797-0000NED1" end
local realSecret = issecretvalue
issecretvalue = function(v) return v == SECRET end

SlashCmdList.YEAHNAHMATE("dev clanprobe")
local p = YeahNahMateDB.clanprobe
check(p and p.mine and p.mine.unitRace:find("Orc", 1, true), "my race is read")
check(p.now.members == 5 and p.now.byRace.Orc == 1 and p.now.byRace.Troll == 1 and p.now.byRace.Tauren == 1,
    "guildies' races counted by race")
check(p.now.race.secret == 1 and p.now.race["nil"] == 1, "secret and missing races counted, not crashed on")
check(p.now.raceKnownOffline == 0 and p.now.raceKnownOnline == 3, "online / offline split")
Tick(16)
check(p.after15s ~= nil, "read again 15 s later")
check(p.watch == true, "whisper watch on")

local sentBefore, chatBefore = #SENT, #(WHISPERS or {})
-- Whispers: one to myself, one from a guildie in a fight, a secret one, one from a stranger.
FireEvent("CHAT_MSG_WHISPER", "inv pls!", "Ned Jones", "", "", "", "", 0, 0, "", 0, 1, "Player-6797-0000NED1")
FAKE.combat = true
FireEvent("CHAT_MSG_WHISPER", "hey mate", "Bluey Heeler", "", "", "", "", 0, 0, "", 0, 2, "Player-6797-00000001")
FAKE.combat = false
FireEvent("CHAT_MSG_WHISPER", SECRET, SECRET, "", "", "", "", 0, 0, "", 0, 3, SECRET)
FireEvent("CHAT_MSG_WHISPER", "Invite", "Some Stranger", "", "", "", "", 0, 0, "", 0, 4, "Player-1-1")
local w = p.whispers
check(#w == 4, "four whispers noted")
check(w[1].me and w[1].inv and w[1].text == "ok", "a whisper to myself counts, 'inv pls!' is an invite ask")
check(w[2].guildie and not w[2].inv and w[2].where:find("combat", 1, true), "a guildie's whisper in a fight")
check(w[3].text == "secret" and w[3].sender == "secret" and w[3].inv == nil, "secret whispers noted as secret")
check(w[4].guildie == false and w[4].inv, "a stranger's 'Invite' noted as not a guildie")
local leaked = false
for _, row in ipairs(w) do for _, v in pairs(row) do
    if v == "inv pls!" or v == "hey mate" or v == "Bluey Heeler" or v == "Some Stranger" then leaked = true end
end end
check(not leaked, "no whisper text or sender names saved")
check(#SENT == sentBefore and #(WHISPERS or {}) == chatBefore, "nothing sent back")

-- The invite words.
local W = ns.ClanProbeInvWord
check(W("inv") and W("INV") and W("Invite") and W("inv plz") and W("invite please") and W("inv pls?"), "invite words")
check(not W("inventory") and not W("can i get an inv") and not W("hey") and not W(nil), "other words aren't")

-- Off, and on again after a reload.
SlashCmdList.YEAHNAHMATE("dev clanprobe off")
FireEvent("CHAT_MSG_WHISPER", "inv", "Ned Jones", "", "", "", "", 0, 0, "", 0, 5, "Player-6797-0000NED1")
check(#p.whispers == 4, "off: nothing more noted")
issecretvalue = realSecret
