-- Proximity voice: each guildie's voice volume set by distance, gliding,
-- their own volume as the top, put back afterwards, mutes left alone.
YeahNahMateDB = nil
local ns = LoadAddon("YeahNahMate", "YeahNahMate")
LOGGED_IN = true
FireEvent("PLAYER_LOGIN")
Tick(2)
local V = ns.Voice

-- Voice chat as the probe found it on Forever: guild club "503775341", stream 1 = guild voice,
-- volumes 0-100. Member 1 is me.
local vols, calls = {}, {}
local members = {}
local function Member(id, name, opts)
    members[#members + 1] = { memberID = id, isSpeaking = false, isMutedForAll = false, isSilenced = false }
    local m = members[#members]
    m.name, m.guid = name, "Player-1-" .. string.format("%08d", id)
    for k, v in pairs(opts or {}) do m[k] = v end
    vols[m.guid] = m.vol or 100
    return m
end
local function ById(id) for _, m in ipairs(members) do if m.memberID == id then return m end end end
local muted = {}
C_Club = { GetGuildClubId = function() return "503775341" end,
           GetStreams = function() return { { streamId = "1", streamType = 1 } } end }
C_VoiceChat = {
    IsEnabled = function() return true end, IsLoggedIn = function() return true end,
    CanPlayerUseVoiceChat = function() return true end, IsParentalDisabled = function() return false end,
    GetActiveChannelID = function() return 10001 end,
    GetChannel = function() return { channelID = 10001, clubId = "503775341", streamId = "1", members = members } end,
    IsMemberLocalPlayer = function(id) return id == 1 end,
    GetMemberGUID = function(id) return ById(id).guid end,
    GetMemberName = function(id) return ById(id).name end,
    GetMemberVolume = function(loc) return vols[loc.guid] end,
    SetMemberVolume = function(loc, v) vols[loc.guid] = v; calls[#calls + 1] = loc.guid end,
    IsMemberMuted = function(loc) return muted[loc.guid] == true end,
}
PlayerLocation = { CreateFromGUID = function(_, guid) return { guid = guid } end }

local me = Member(1, "Bruce Wombat")
local bazza = Member(2, "Bazza Stubbs", { vol = 65 })
local shazza = Member(3, "Shazza Kettle")
local robbo = Member(4, "Robbo Esky", { vol = 70 })
muted[shazza.guid] = true

-- They're online guildies (or the map drops their positions on the next roster read).
local realGet = ns.Guild.Get
ns.Guild.Get = function(name)
    for _, m in ipairs(members) do if m.name == name then return { name = name, online = true } end end
    if name and name:find("^Filler") then return { name = name, online = true } end
    return realGet(name)
end

-- Where everyone is: me in the middle of the map; positions as guildies' POS messages leave them.
FAKE.x, FAKE.y = 0.5, 0.5
local function Put(name, x) ns.Map.pos[name] = { m = 1413, x = x, y = 0.5, at = GetTime() } end
Put("Bazza Stubbs", 0.5)
Put("Shazza Kettle", 0.5)
-- (Robbo has no position: no addon, or not sharing.)
local function YardsAt(x) Put("Bazza Stubbs", x); return ns.Map.Distance("Bazza Stubbs") end
-- Find an x that puts Bazza about 72.5 yd away (half way through Normal's fade, 20 -> 125).
local x72 = 0.5
for i = 1, 400 do
    local x = 0.5 + i * 0.0005
    if YardsAt(x) >= 72.5 then x72 = x break end
end
Put("Bazza Stubbs", 0.5)

ns.settings.sharePosition = true
ns.settings.voiceOn = true
ns.Fire("VOICE")
Tick(1.1)
check(V.State() == "on", "on and in guild voice")
check(vols[bazza.guid] == 65 and #calls == 0, "Bazza right next to me: left at his own 65, nothing sent")
check(vols[robbo.guid] == 70, "Robbo can't be placed: normal volume (his own 70)")

-- Bazza walks off to ~72 yd: half of his 65 is ~33, reached by gliding at most 15 a second.
Put("Bazza Stubbs", x72)
Tick(1)
check(vols[bazza.guid] == 50, "one second later: down 15, not straight to the end (" .. tostring(vols[bazza.guid]) .. ")")
Tick(1)
check(vols[bazza.guid] == 35, "then 35")
Tick(1)
local want = math.floor(65 * V.Volume(ns.Map.Distance("Bazza Stubbs"), V.RANGES.normal) + 0.5)
check(math.abs(vols[bazza.guid] - want) <= 0 and want >= 30 and want <= 35, "then settles at about half his volume (" .. want .. ")")
check(ns.db.voice.saved[bazza.guid] == 65, "his own 65 is kept to put back")

-- Muted guildies are never touched.
for _, g in ipairs(calls) do check(g ~= shazza.guid, "Shazza (muted) never changed") break end
local touched = false
for _, g in ipairs(calls) do if g == shazza.guid then touched = true end end
check(not touched and vols[shazza.guid] == 100, "a guildie I muted is left alone")

-- Far away: silent.
Put("Bazza Stubbs", 0.5 + (x72 - 0.5) * 3)
Tick(5)
check(vols[bazza.guid] == 0, "past 125 yd: silent")
-- Close range shrinks it, Far spreads it out.
Put("Bazza Stubbs", x72)
ns.settings.voiceRange = "far"; ns.Fire("SETTINGS")
Tick(6)
local far = vols[bazza.guid]
ns.settings.voiceRange = "close"; ns.Fire("SETTINGS")
Tick(6)
check(far > want and vols[bazza.guid] < want, "Far is louder at the same spot, Close quieter (" .. far .. " / " .. vols[bazza.guid] .. ")")
ns.settings.voiceRange = "normal"; ns.Fire("SETTINGS")
Tick(6)

-- He changes Bazza's volume himself: that's the new top.
vols[bazza.guid] = 90
Tick(1.1)
check(ns.db.voice.saved[bazza.guid] == 90, "the player's own change becomes the volume to put back")

-- In my group: full volume (his own top) whatever the distance.
IsInGroup = function() return true end
IsInRaid = function() return false end
local realGUID = UnitGUID
UnitGUID = function(u) if u == "party1" then return bazza.guid end return realGUID and realGUID(u) end
Tick(8)
check(vols[bazza.guid] == 90, "in my group: full volume (" .. tostring(vols[bazza.guid]) .. ")")
ns.settings.voiceGroupFull = false; ns.Fire("SETTINGS")
Tick(8)
check(vols[bazza.guid] < 90, "with 'full volume for my group' off, distance counts again")
ns.settings.voiceGroupFull = true
IsInGroup = function() return false end

-- Turning it off puts everyone back.
ns.settings.voiceOn = false; ns.Fire("SETTINGS")
check(vols[bazza.guid] == 90 and vols[robbo.guid] == 70 and next(ns.db.voice.saved) == nil,
    "Proximity off: everyone back to their own volume, nothing left saved")
local n = #calls
Tick(5)
check(#calls == n, "and nothing runs while it's off")

ns.settings.voiceOn = true; ns.Fire("SETTINGS")
Tick(4)
check(vols[bazza.guid] < 90, "on again: Bazza fades")

-- Logging out with it on puts everyone back.
FireEvent("PLAYER_LOGOUT")
check(vols[bazza.guid] == 90 and next(ns.db.voice.saved) == nil, "logout puts everyone back")

-- A crash leaves saved volumes: next login (not on) puts them back.
ns.db.voice.saved[bazza.guid] = 65
vols[bazza.guid] = 12
ns.settings.voiceOn = false
ns.Fire("SETTINGS")
check(vols[bazza.guid] == 65 and next(ns.db.voice.saved) == nil, "leftovers from a crash go back")

-- A crowd far away: at most 8 volume changes a second.
for i = 10, 40 do
    local m = Member(i, "Filler " .. i)
    Put("Filler " .. i, 0.5 + (x72 - 0.5) * 3)
end
ns.settings.voiceOn = true; ns.Fire("SETTINGS")
local c0 = #calls
Tick(1.05)
check(#calls - c0 <= 8 + 1, "at most 8 volume changes a second (" .. (#calls - c0) .. ")")

-- Voice chat reports an error (e.g. too many requests): stop for 10 s.
FireEvent("VOICE_CHAT_ERROR")
c0 = #calls
Tick(5)
check(#calls == c0, "after a voice chat error: no changes for a while")
Tick(8)
check(#calls > c0, "then it carries on")

---------------------------------------------------------------------------------------------------
-- Step 4: smoother positions and the fast lane.
FireEvent("VOICE_CHAT_ERROR"); Tick(11)        -- (clear the error pause from above)
local Map = ns.Map

-- Guessing where a guildie is heading (Map.Estimate).
local now = GetTime()
Map.pos["Bazza Stubbs"] = { m = 1413, px = 0.50, py = 0.5, pm = 1413, pat = now - 3, x = 0.51, y = 0.5, at = now }
Tick(2)
local _, ex = Map.Estimate("Bazza Stubbs")
check(math.abs(ex - (0.51 + 0.01 * 2 / 3)) < 1e-6, "2 s after his last position: guessed 2 s further on the way he was going")
Tick(2)
_, ex = Map.Estimate("Bazza Stubbs")
check(math.abs(ex - 0.52) < 1e-6, "never guessed more than 3 s ahead")
Tick(3)
_, ex = Map.Estimate("Bazza Stubbs")
check(ex == 0.51, "nothing new for over 6 s: back to his last known spot (he stopped)")
now = GetTime()
Map.pos["Bazza Stubbs"] = { m = 1413, px = 0.10, py = 0.5, pm = 1413, pat = now - 3, x = 0.51, y = 0.5, at = now }
Tick(1)
_, ex = Map.Estimate("Bazza Stubbs")
check(ex == 0.51, "a jump too fast to be running (a hearth, a teleport): no guessing")

-- A POS message keeps the one before (the receiving side).
Map.pos["Bazza Stubbs"] = nil
local Ser = LibStub("AceSerializer-3.0")
local function Hear(x)
    ns.Comm.Receive(Ser:Serialize({ t = "POS", v = ns.PROTOCOL, m = 1413, x = x, y = 0.5 }), "GUILD", "Bazza Stubbs")
end
Hear(0.50); Tick(3); Hear(0.51)
local bp = Map.pos["Bazza Stubbs"]
check(bp and bp.px == 0.50 and bp.x == 0.51, "a new position keeps the one before for guessing")

-- The fast lane: count my own POS messages while I walk.
ns.Comm.OthersOnline = function() return 5 end
local sent = 0
local realSend = ns.Comm.Send
ns.Comm.Send = function(msg, ...)
    if msg.t == "POS" and not msg.off then sent = sent + 1 end
    return realSend(msg, ...)
end
local function Walk(seconds)
    for _ = 1, seconds do FAKE.x = FAKE.x + 0.003; Put("Bazza Stubbs", FAKE.x + 0.01); Tick(1) end
end
FAKE.x = 0.3
Walk(5)
sent = 0
Walk(60)
check(sent >= 15 and sent <= 21, "a guildie in voice nearby: my position goes about every 3 s while I move (" .. sent .. " a minute)")
check(ns.Voice.fast == true, "the fast lane says it's on")
-- I stop: one more (so guesses stop), then quiet until the minute keep-alive.
sent = 0
Tick(10)
check(sent >= 1 and sent <= 2, "stopping: my last spot, then one more so guesses stop (" .. sent .. ")")
sent = 0
Tick(30)
check(sent == 0, "then nothing while I stand still")
-- Nobody near (they're far off): the usual pace.
Put("Bazza Stubbs", 0.0)
for _, m in ipairs(members) do if m.name:find("^Filler") then Put(m.name, 0.0) end end
sent = 0
for _ = 1, 60 do FAKE.x = FAKE.x + 0.003; Tick(1) end
check(not ns.Voice.fast and sent <= 5, "no voice guildie within 400 yd: back to the usual 15 s pace (" .. sent .. " a minute)")
ns.Comm.Send = realSend

-- What it costs: 30 guildies in voice, all moving, once a second.
for _, m in ipairs(members) do if m.name:find("^Filler") then Put(m.name, 0.5 + math.random() * 0.1) end end
local t0 = os.clock()
for i = 1, 30 do
    for _, m in ipairs(members) do if m.name:find("^Filler") then
        local p = Map.pos[m.name]; p.pm, p.px, p.py, p.pat = p.m, p.x, p.y, p.at; p.x = p.x + 0.001; p.at = GetTime()
    end end
    ns.Voice.Tick()
    Tick(0.001)
end
local ms = (os.clock() - t0) * 1000 / 30
check(ms < 5, string.format("30 guildies in voice: %.2f ms a second (limit 5)", ms))

---------------------------------------------------------------------------------------------------
-- Step 5: the drawer: Near you in voice, the settings, the help folded away.
local UI, L = ns.UI, ns.L
-- Just a few in voice again: Bazza close, Shazza (muted), Robbo (no spot).
for i = #members, 1, -1 do if members[i].name:find("^Filler") then table.remove(members, i) end end
Put("Bazza Stubbs", FAKE.x + 0.01)
Put("Shazza Kettle", FAKE.x + 0.02)
UI.Open("home")
Tick(0.1)
UI.ToggleVoice(true)
Tick(1.5)
local p = UI.voicePanel
check(p.body:IsShown() and not p.help:IsShown(), "the settings and list show; the help is folded away")
local shown = {}
for _, row in ipairs(p.rows) do if row:IsShown() then shown[#shown + 1] = row end end
check(#shown == 3, "three other guildies in guild voice listed (" .. #shown .. ")")
check(shown[1].name:GetText():find("Bazza", 1, true) and shown[1].where:GetText():find("yd", 1, true), "nearest first, with yards")
local texts = {}
for _, row in ipairs(shown) do texts[#texts + 1] = row.name:GetText() .. "=" .. row.where:GetText() end
local all = table.concat(texts, " ")
check(all:find("Shazza[^=]*=" .. L.VOICE_MUTED) and all:find("Robbo[^=]*=" .. L.VOICE_NO_SPOT),
    "a muted guildie says muted; one with no position says can't tell: " .. all)
bazza.isSpeaking = true
Tick(1)
check(shown[1].talk:IsShown(), "a talking guildie gets the little speaker")
bazza.isSpeaking = false

-- Settings in the drawer.
p.quietButtons[2]:Click()
check(ns.settings.voiceQuietest == 20, "Far away: Faint keeps them at a fifth")
p.quietButtons[1]:Click()
check(ns.settings.voiceQuietest == 0, "Silent")
p.unplacedButtons[2]:Click()
check(ns.settings.voiceUnplaced == "quiet", "Can't tell: Quiet")
Tick(5)
check(vols[robbo.guid] == 0, "and Robbo (no position) goes quiet")
p.unplacedButtons[1]:Click()
Tick(5)
check(vols[robbo.guid] == 70, "Normal: back to his own volume")
p.groupCheck:SetChecked(false); p.groupCheck:Click()
check(ns.settings.voiceGroupFull == false, "Full volume for my group can be unticked")
p.groupCheck:SetChecked(true); p.groupCheck:Click()
-- Proximity unticked while in guild voice: says I'm still in guild voice at normal
-- volume, offers Leave voice; the list empties; Leave leaves the channel the way Blizzard's button does.
local deactivated
C_VoiceChat.DeactivateChannel = function(id) deactivated = id end
p.onCheck:SetChecked(false); p.onCheck:Click()
check(ns.settings.voiceOn == false and p.detail:GetText() == L.VOICE_ST_OFF_IN, "unticked in guild voice: says I'm still in it, everyone at normal volume")
check(p.leave:IsShown(), "and offers Leave voice")
local anyShown = false
for _, row in ipairs(p.rows) do if row:IsShown() then anyShown = true end end
check(not anyShown, "the list empties")
p.leave:Click()
check(deactivated == 10001, "Leave voice leaves the guild channel")
p.onCheck:SetChecked(true); p.onCheck:Click()
check(not p.leave:IsShown(), "ticked again: no Leave button (Proximity's running)")
Tick(1.5)

-- The help.
p.helpBtn:Click()
check(p.help:IsShown() and not p.body:IsShown() and p.notes:GetText() == L.VOICE_NOTES_TEXT, "? shows the help over the settings")
p.helpBtn:Click()
check(not p.help:IsShown() and p.body:IsShown(), "Back folds it away")

---------------------------------------------------------------------------------------------------
-- What we took from other proximity voice addons (research, 14 Nov).
-- Natural fade: quicker at first, tails off; same ends as Even.
local Rn = V.RANGES.normal
check(V.Volume(20, Rn, 0, "natural") == 1 and V.Volume(125, Rn, 0, "natural") == 0, "Natural: same full and silent points")
check(math.abs(V.Volume(72.5, Rn, 0, "natural") - 0.25) < 1e-9 and V.Volume(72.5, Rn, 0, "even") == 0.5,
    "half way: Natural a quarter, Even a half")
check(math.abs(V.Volume(72.5, Rn, 0.2, "natural") - (0.2 + 0.25 * 0.8)) < 1e-9, "Faint still the floor with Natural")
Put("Bazza Stubbs", x72)
p.curveButtons[2]:Click()
check(ns.settings.voiceCurve == "natural", "the Fade buttons pick the curve")
Tick(8)
check(math.abs(vols[bazza.guid] - math.floor(ns.db.voice.saved[bazza.guid] * V.Volume(ns.Map.Distance("Bazza Stubbs", true), Rn, 0, "natural") + 0.5)) <= 1,
    "and the volume follows it (" .. vols[bazza.guid] .. ")")
p.curveButtons[1]:Click()

-- Always hear: click a name in the list.
Put("Bazza Stubbs", 0.0)
Tick(8)
check(vols[bazza.guid] == 0, "Bazza far away: silent")
local brow
for _, row in ipairs(p.rows) do if row:IsShown() and row.who == "Bazza Stubbs" then brow = row end end
check(brow ~= nil, "his row knows who he is")
brow:Click()
check(ns.settings.voiceAlways["Bazza Stubbs"] == true, "clicking his name: always hear him")
Tick(8)
check(vols[bazza.guid] == ns.db.voice.saved[bazza.guid] and brow.where:GetText():find(L.VOICE_ALWAYS, 1, true),
    "full volume however far, and the list says always")
brow:Click()
check(ns.settings.voiceAlways["Bazza Stubbs"] == nil, "click again: back to distance")
Tick(8)
check(vols[bazza.guid] == 0, "and silent again")

-- The quick toggle: /ynm voice and the key binding.
local printed2 = {}
local realPrint2 = print
print = function(...) printed2[#printed2 + 1] = table.concat({ ... }, " ") end
SlashCmdList.YEAHNAHMATE("voice")
check(ns.settings.voiceOn == false, "/ynm voice turns it off")
YeahNahMate_VoiceToggle()
check(ns.settings.voiceOn == true, "the key binding turns it back on")
deactivated = nil
SlashCmdList.YEAHNAHMATE("voice leave")
check(deactivated == 10001, "/ynm voice leave")
SlashCmdList.YEAHNAHMATE("voice off")
check(ns.settings.voiceOn == false, "/ynm voice off")
SlashCmdList.YEAHNAHMATE("voice on")
check(ns.settings.voiceOn == true, "/ynm voice on")
print = realPrint2
check(BINDING_NAME_YEAHNAHMATE_VOICE ~= nil and BINDING_HEADER_YEAHNAHMATE ~= nil, "the key binding has a name in Options")
local f = io.open("YeahNahMate/Bindings.xml"):read("*a")
check(f:find('name="YEAHNAHMATE_VOICE"', 1, true) and f:find("YeahNahMate_VoiceToggle()", 1, true), "Bindings.xml calls the toggle")
check(L.VOICE_NOTES_TEXT:find("layer", 1, true), "Good to know mentions layers")

-- Right-click on the speaker tab: Proximity on/off; left-click still slides the drawer.
local tab = UI.voiceTab
local wasOpen = UI.VoiceOpen()
local on0 = ns.settings.voiceOn
print = function() end
tab:Click("RightButton")
check(ns.settings.voiceOn == not on0 and UI.VoiceOpen() == wasOpen, "right-click turns Proximity on/off, the drawer stays as it was")
tab:Click("RightButton")
print = realPrint2
check(ns.settings.voiceOn == on0, "right-click again: back")
tab:Click("LeftButton")
check(UI.VoiceOpen() ~= wasOpen, "left-click still slides the drawer")
check(L.VOICE_TIP:find("Right%-click"), "the tooltip explains right-click")

---------------------------------------------------------------------------------------------------
-- Group mode: Blizzard's party/raid voice; Proximity stops, volumes go back; guildies
-- in my group with the addon get a pop-up to join (their own click).
local joinedType, loginType, joined
C_VoiceChat.RequestJoinAndActivateCommunityStreamChannel = function(c, st) joined = c .. "/" .. st end
C_VoiceChat.SetActiveVoiceProvider = function() end
local realIsMember = ns.Guild.IsMember
ns.Guild.IsMember = function(name) return ns.Guild.Get(name) ~= nil or realIsMember(name) end
C_VoiceChat.GetActiveChannelType = function() return 4 end
C_VoiceChat.RequestJoinChannelByChannelType = function(t, auto) joinedType = t end
C_VoiceChat.RestoreActiveVoiceProvider = function() end
C_VoiceChat.GetActiveVoiceProviderID = function() return 0 end
C_VoiceChat.Login = function(t) loginType = t; return 1 end
local inGroup = false
IsInGroup = function() return inGroup end
IsInRaid = function() return false end
FAKE.party = {}
ns.settings.voiceOn = true; ns.Fire("SETTINGS")
Put("Bazza Stubbs", x72); Tick(8)
check(not p.groupBtn:IsShown(), "no Group voice button when I'm not in a group")
inGroup = true
FAKE.party = { "Bazza Stubbs" }
ns.Fire("VOICE")
Tick(8)
check(p.groupBtn:IsShown() and p.join:IsShown() == false, "in a group: Group voice button (and no Join: I'm in guild voice)")
check(vols[bazza.guid] == ns.db.voice.saved[bazza.guid], "Bazza is in my group: full volume")

-- Click Group voice: join the party channel, whisper the guildies in my group.
local whispers = {}
local realSend2 = ns.Comm.Send
ns.Comm.Send = function(msg, channel, target, prio)
    if msg.t == "VGRP" then whispers[#whispers + 1] = channel .. ":" .. tostring(target) end
    return realSend2(msg, channel, target, prio)
end
p.groupBtn:Click()
check(joinedType == 2, "joins the party/raid voice channel (PrivateParty)")
check(#whispers == 1 and whispers[1] == "WHISPER:Bazza Stubbs", "tells the guildie in my group, by whisper (" .. table.concat(whispers, ",") .. ")")
ns.Comm.Send = realSend2

-- Now in group voice: blue, Proximity waits, everyone's volume back.
Put("Bazza Stubbs", 0.0)
C_VoiceChat.GetActiveChannelType = function() return 2 end
ns.Fire("VOICE")
check(tab.state == "group" and p.detail:GetText() == L.VOICE_ST_GROUP, "in group voice: the Group voice state")
check(next(ns.db.voice.saved) == nil, "Proximity stops and every volume goes back")
check(p.join:IsShown() and p.join:GetText() == L.VOICE_BACK_BTN and p.leave:IsShown() and not p.groupBtn:IsShown(), "Back to guild voice and Leave voice buttons")
p.join:Click()
check(joined ~= nil, "Back joins guild voice")
C_VoiceChat.GetActiveChannelType = function() return 4 end
ns.Fire("VOICE")
check(tab.state == "on", "back in guild voice: Proximity again")

-- Not logged in to voice yet: log in first, join when that's done.
joinedType = nil
C_VoiceChat.IsLoggedIn = function() return false end
ns.Voice.JoinGroup()
check(joinedType == nil and loginType == 2, "not logged in: logs in first")
FireEvent("VOICE_CHAT_LOGIN")
check(joinedType == 2, "and joins group voice when the login is done")
C_VoiceChat.IsLoggedIn = function() return true end

-- A guildie in my group moves it to group voice: I get a pop-up; joining is my own click.
local toast
local realShow = ns.Toast.Show
ns.Toast.Show = function(title, text, kind, action) toast = { title = title, kind = kind, action = action } end
joinedType = nil
local Ser2 = LibStub("AceSerializer-3.0")
ns.Comm.Receive(Ser2:Serialize({ t = "VGRP", v = ns.PROTOCOL }), "WHISPER", "Bazza Stubbs")
check(toast and toast.title:find("Bazza", 1, true) and toast.kind == "voice", "Bazza's switch shows me a pop-up")
check(joinedType == nil, "nothing joined by itself")
toast.action[2]()
check(joinedType == 2, "its Join button joins group voice")
toast = nil
ns.Comm.Receive(Ser2:Serialize({ t = "VGRP", v = ns.PROTOCOL }), "WHISPER", "Robbo Esky")
check(toast == nil, "from a guildie not in my group: ignored")
ns.Toast.Show = realShow
inGroup = false
FAKE.party = {}
