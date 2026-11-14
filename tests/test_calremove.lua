-- Calendar removals, like Ask's officer removals: the guild's editor
-- ranks can remove anyone's event. Ned (me) is the guild master in the fake roster, Bluey an Officer,
-- Chilli and Bandit plain Members.
math.randomseed(31)
YeahNahMateDB = nil
FAKE.myRank, FAKE.myRankName = 0, "Guild Master"        -- the stub makes me a Member otherwise
local ns = LoadAddon("YeahNahMate", "YeahNahMate")
LOGGED_IN = true
FireEvent("PLAYER_LOGIN")
local Ser = LibStub("AceSerializer-3.0")
local function Msg(t) return Ser:Serialize(t) end
local function Sent(t, from)
    local list = {}
    for i = (from or 1), #SENT do
        local ok, m = Ser:Deserialize(SENT[i].text)
        if ok and type(m) == "table" and m.t == t then
            m._target = SENT[i].target; m._channel = SENT[i].channel
            list[#list + 1] = m
        end
    end
    return list
end
local C = ns.Calendar
ns.settings.sharePosition, ns.settings.shareProfessions = false, false
Tick(15)
local now = GetServerTime()
local store = C.Store()

-- Bluey's event and Chilli's event arrive.
INJECT("YNM", Msg({ v = 1, t = "EVT", id = 900, ti = "Spam run", at = now + 86400, k = "o", ev = now - 100 }), "GUILD", "Bluey Heeler")
INJECT("YNM", Msg({ v = 1, t = "EVT", id = 901, ti = "Chilli's run", at = now + 86400, k = "d", ev = now - 100 }), "GUILD", "Chilli Heeler")
Tick(1)
local bk, ck = "Bluey Heeler:900", "Chilli Heeler:901"
check(store[bk] and not store[bk].x and store[ck] and not store[ck].x, "two guildies' events arrived")

-- I'm the guild master: I can remove; my own event I cancel instead.
check(C.CanRemove(), "the guild master can remove events")
local mine = C.Save(nil, { title = "Mine", at = now + 7200, k = "s" })
check(C.Remove(mine) == false and not store[mine].x, "Remove isn't for my own event")
local before = #SENT
check(C.Remove(ck) == true, "remove Chilli's event")
local evr = Sent("EVR", before + 1)
check(#evr == 1 and evr[1]._channel == "GUILD" and evr[1].o == "Chilli Heeler" and evr[1].id == 901,
    "the removal goes to the guild")
check(store[ck].x and store[ck].rm == ns.me, "it's gone here, marked removed by me")
check(C.Remove(ck) == false, "removing twice does nothing")

-- Chilli comes back with the old event (or even an edit): it stays removed, and I tell Chilli.
before = #SENT
INJECT("YNM", Msg({ v = 1, t = "EVT", id = 901, ti = "Chilli's run", at = now + 86400, k = "d", ev = now - 100 }), "WHISPER", "Chilli Heeler")
INJECT("YNM", Msg({ v = 1, t = "EVT", id = 901, ti = "Chilli's run again", at = now + 86400, k = "d", ev = now + 30 }), "GUILD", "Chilli Heeler")
Tick(3)
check(store[ck].x and store[ck].title == "Chilli's run", "the owner's old copy or a later edit can't bring it back")
local told = Sent("EVR", before + 1)
check(#told == 1 and told[1]._channel == "WHISPER" and told[1]._target == "Chilli Heeler", "the owner is told it was removed (once)")

-- Copies carry who removed it, so a guildie who logs in later can't be given the old one.
before = #SENT
INJECT("YNM", Msg({ v = 1, t = "REQ", w = "CAL" }), "WHISPER", "Bandit Heeler")
Tick(5)
local copy
for _, m in ipairs(Sent("EVT", before + 1)) do if m.o == "Chilli Heeler" and m.id == 901 then copy = m end end
check(copy and copy.x and copy.rm == ns.me, "a copy of the removal says who removed it")

-- Removals from a plain Member are dropped.
INJECT("YNM", Msg({ v = 1, t = "EVR", o = "Bluey Heeler", id = 900, ev = now }), "GUILD", "Bandit Heeler")
Tick(1)
check(not store[bk].x, "a Member can't remove someone's event")
-- An Officer (an editor rank) can, and an event of mine removed by them goes for me too.
INJECT("YNM", Msg({ v = 1, t = "EVR", o = "Ned Jones", id = store[mine].id, ev = GetServerTime() }), "GUILD", "Bluey Heeler")
Tick(1)
check(store[mine].x and store[mine].rm == "Bluey Heeler", "an Officer removed my event: gone for me too")
local said = false
for _, p in ipairs(PRINTED) do if p:find("Bluey Heeler removed your calendar event: Mine", 1, true) then said = true end end
check(said, "and I'm told who removed it")
before = #SENT
local saved = C.Save(mine, { title = "Mine back", at = now + 7200, k = "s" })
check(not saved or store[mine].x, "I can't edit it back")

-- The tab: Remove (top right) on other people's events for an editor rank, click twice.
ns.UI.Open("calendar")
local cal
for _, o in ipairs(CREATED) do if o.dayPager then cal = o end end
local dt = date("*t", now + 86400)
cal.offset, cal.sel, cal.mode = 0, dt.day, nil
if dt.month ~= date("*t").month then cal.offset = 1 end
ns.UI.Select("calendar")
Tick(1)
local card
for _, b in ipairs(cal.details) do if b:IsShown() and b.key == bk then card = b end end
check(card and card.modRemove:IsShown() and not card.remove:IsShown(), "Remove shows on Bluey's event, not Cancel")
card.modRemove:Click()
Tick(1)
check(not store[bk].x and card.modRemove:GetText() == ns.L.MS_SURE, "first click asks Sure?")
card.modRemove:Click()
Tick(1)
check(store[bk].x and store[bk].rm == ns.me, "second click removes it")

-- A plain Member doesn't get the button.
INJECT("YNM", Msg({ v = 1, t = "EVT", id = 902, ti = "Bingo's run", at = now + 86400, k = "s", ev = now - 50 }), "GUILD", "Bingo Heeler")
ns.Guild.myRank = 4
ns.UI.Dirty(); Tick(1)
local any = false
for _, b in ipairs(cal.details) do if b:IsShown() and b.modRemove:IsShown() then any = true end end
check(not C.CanRemove() and not any, "a Member sees no Remove on other people's events")
ns.Guild.myRank = 0

-- The temporary /ynm dev calrm test command is gone for release (take it out before uploading).
check(ns.devCommands.calrm == nil, "no /ynm dev calrm in the release")

check(#ERRORS == 0, "no errors (" .. (ERRORS[1] or "none") .. ")")
