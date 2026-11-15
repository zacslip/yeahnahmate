-- The voice drawer: a speaker tab on the main window's left edge slides a panel out and back, with
-- the voice state, the settings and who's near you in voice.
YeahNahMateDB = nil
local ns = LoadAddon("YeahNahMate", "YeahNahMate")
LOGGED_IN = true
FireEvent("PLAYER_LOGIN")
Tick(2)
local UI, L = ns.UI, ns.L

UI.Open("home")
Tick(0.1)
local holder, panel, tab = UI.voiceHolder, UI.voicePanel, UI.voiceTab
check(holder ~= nil and panel ~= nil and tab ~= nil, "the drawer is built with the window")
check(holder._pt[1] == "BOTTOMRIGHT" and holder._pt[3] == "BOTTOMLEFT", "it sits on the window's left edge")
check(L.VOICE_HOW_TEXT:find("Options > Audio", 1, true) and panel.notes:GetText() == L.VOICE_NOTES_TEXT, "it says how to turn voice chat on and where it can get in the way")
check(holder._parent == YeahNahMateFrame and tab._parent == YeahNahMateFrame, "it belongs to the main window, so it moves and hides with it")
check(panel._parent == holder and tab._parent ~= holder, "the panel is in the clipping holder, the tab isn't (or it would be clipped away)")
check(not UI.VoiceOpen() and not panel:IsShown() and holder._w == 1, "it starts shut")
check(panel.head:GetText() == L.VOICE_TITLE and panel.state:GetText() == L.VOICE_STATE_CANT and tab.state == "cant",
    "no voice chat in this game: Can't start (red)")

tab:Click()
Tick(0.5, 0.05)
check(UI.VoiceOpen() and panel:IsShown() and holder._w == 270, "clicking the tab slides it fully open")
check(holder._scripts.OnUpdate == nil, "and the slide stops once it's open")

tab:Click()
Tick(0.5, 0.05)
check(not UI.VoiceOpen() and not panel:IsShown() and holder._w == 1, "clicking again slides it shut")

-- Open, close the window, open it again: it's still open.
UI.ToggleVoice(true)
Tick(0.5, 0.05)
YeahNahMateFrame:Hide()
UI.Open("roster")
check(UI.VoiceOpen() and holder._w == 270, "it stays open when the window is closed and reopened")

-- The volume curve: full within `full` yards, straight fade to the quietest by `gone`.
local R = UI.VOICE_RANGES
check(UI.VoiceVolume(5, R.normal) == 1 and UI.VoiceVolume(20, R.normal) == 1, "full volume close by")
check(math.abs(UI.VoiceVolume(72.5, R.normal) - 0.5) < 1e-9, "half way through the fade, half volume")
check(UI.VoiceVolume(125, R.normal) == 0 and UI.VoiceVolume(500, R.normal) == 0, "silent from 125 yd on (Normal, Ned 14 Nov)")
check(UI.VoiceVolume(500, R.normal, 0.2) == 0.2, "never below the quietest volume")
check(R.close.gone < R.normal.gone and R.normal.gone < R.far.gone, "Close < Normal < Far")

-- Dev: the voice probe and the sound test, against a fake voice chat.
local spoken, printed = {}, {}
local realPrint = print
print = function(...) printed[#printed + 1] = table.concat({ ... }, " ") end
local vols = {}
C_VoiceChat = {
    IsEnabled = function() return true end, IsLoggedIn = function() return true end,
    GetActiveChannelID = function() return 7 end,
    GetChannel = function() return { channelID = 7, name = "Guild", members = {
        { memberID = 1, isActive = true, isSpeaking = false }, { memberID = 2, isActive = true, isSpeaking = true } } } end,
    IsMemberLocalPlayer = function(id) return id == 1 end,
    GetMemberGUID = function(id) return "Player-1-0000000" .. id end,
    GetMemberName = function(id) return id == 1 and "Bruce Wombat" or "Bazza Stubbs" end,
    GetMemberVolume = function(loc) return vols[loc.guid] or 1 end,
    SetMemberVolume = function(loc, v) vols[loc.guid] = v end,
    IsMemberMuted = function() return false end,
    GetTtsVoices = function() return { { voiceID = 3, name = "Fake Voice" } } end,
    SpeakText = function(voice, text, rate, volume) spoken[#spoken + 1] = volume end,
}
PlayerLocation = { CreateFromGUID = function(_, guid) return { guid = guid } end }
SlashCmdList.YEAHNAHMATE("dev vprobe")
local vp = YeahNahMateDB.vprobe
check(vp and vp.members == 2 and vp["member 2"]:find("Bazza", 1, true) and vp["member 2"]:find("volume=1", 1, true),
    "the voice probe lists the channel's members with their volume")
SlashCmdList.YEAHNAHMATE("dev vprobe set")
check(vols["Player-1-00000002"] == 0.5 and vols["Player-1-00000001"] == nil, "set: the other member at half, not me")
SlashCmdList.YEAHNAHMATE("dev vprobe check")
check(vols["Player-1-00000002"] == 1 and vp.check:find("put back", 1, true), "check: put back to what it was")

FAKE.x, FAKE.y = 0.5, 0.5
SlashCmdList.YEAHNAHMATE("dev vtest")
check(spoken[1] == 100, "the sound test speaks at full volume on the mark")
FAKE.x = 0.52
Tick(3.1)
check(#spoken >= 2 or printed[#printed]:find("yd", 1, true), "it speaks again after walking off: " .. tostring(printed[#printed]))
local n = #spoken
SlashCmdList.YEAHNAHMATE("dev vtest stop")
Tick(10)
check(#spoken == n, "stop stops it")
print = realPrint

-- The voice state (step 2), as the probe found it on Forever: the guild is club "503775341", its
-- stream 1 ("Guild", type 1) carries the guild voice channel.
local active, joined, speaking = 10001, nil, false
C_Club = { GetGuildClubId = function() return "503775341" end,
           GetStreams = function() return { { streamId = "1", streamType = 1, name = "Guild" } } end }
C_VoiceChat.CanPlayerUseVoiceChat = function() return true end
C_VoiceChat.IsParentalDisabled = function() return false end
C_VoiceChat.GetActiveChannelID = function() return active end
C_VoiceChat.GetChannel = function(id) return { channelID = id, clubId = "503775341", streamId = "1", members = {
    { memberID = 1, isSpeaking = false }, { memberID = 2, isSpeaking = speaking } } } end
C_VoiceChat.RequestJoinAndActivateCommunityStreamChannel = function(club, stream) joined = club .. "/" .. stream; active = 10001 end
ns.settings.sharePosition = true
ns.settings.voiceOn = false
ns.Fire("VOICE")
check(tab.state == "off" and panel.state:GetText() == L.VOICE_STATE_OFF and not panel.join:IsShown(), "Proximity off: grey, Off")
panel.onCheck:SetChecked(true); panel.onCheck:Click()
check(ns.settings.voiceOn == true and tab.state == "on" and panel.detail:GetText() == L.VOICE_ST_ON, "ticked, in guild voice: green, On")
check(not tab.talking, "nobody talking: plain speaker")
speaking = true; ns.Fire("VOICE")
check(tab.talking, "a guildie talking: the speaker shows sound waves")
speaking = false
active = nil; ns.Fire("VOICE")
check(tab.state == "notin" and panel.join:IsShown(), "not in a voice channel: gold, and the Join guild voice button")
panel.join:Click()
Tick(1.5)
check(joined == "503775341/1" and tab.state == "on" and not panel.join:IsShown(), "Join joins the guild's stream; then it's on")
active = 20002
C_VoiceChat.GetChannel = function(id) return { channelID = id, clubId = "999", streamId = "1", members = {} } end
ns.Fire("VOICE")
check(tab.state == "notin", "in some other voice channel (party, another community): not guild voice")
ns.settings.sharePosition = false; ns.Fire("SETTINGS")
check(tab.state == "cant" and panel.detail:GetText() == L.VOICE_ST_SHARING, "map sharing off: red, says why")
C_VoiceChat.IsEnabled = function() return false end
ns.settings.voiceOn = false; ns.Fire("SETTINGS")
check(tab.state == "off" and panel.detail:GetText() == L.VOICE_ST_DISABLED, "voice chat switched off in Options: says where to turn it on")


-- not in any voice channel, the game isn't logged in to voice, and it said "Can't
-- start" for ever. Not logged in is fine: Join logs in. Join first picks Blizzard's own voice
-- service, as Blizzard's own guild voice button does.
C_VoiceChat.IsEnabled = function() return true end
C_VoiceChat.IsLoggedIn = function() return false end
local pending, provider = false, nil
C_VoiceChat.IsChannelJoinPending = function() return pending end
C_VoiceChat.SetActiveVoiceProvider = function(p) provider = p end
active = nil
ns.settings.sharePosition = true; ns.settings.voiceOn = true; ns.Fire("SETTINGS")
check(tab.state == "notin" and panel.join:IsShown(), "logged out of voice: gold with the Join button, not Can't start")
panel.join:Click()
check(provider == 0, "Join picks Blizzard's own voice service first")
pending = true; ns.Fire("VOICE")
check(tab.state == "notin" and panel.detail:GetText() == L.VOICE_ST_JOINING and not panel.join:IsShown(), "while joining: says so, no second Join")
