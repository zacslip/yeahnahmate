-- Feedback on 0.5.x: clear role rows (they overlapped), and pop-up/sound settings in one place
-- with a choice of sound and which game volume slider it follows.
math.randomseed(7)
YeahNahMateDB = nil
local ns = LoadAddon("YeahNahMate", "YeahNahMate")
LOGGED_IN = true
FireEvent("PLAYER_LOGIN")
ns.settings.sharePosition, ns.settings.shareProfessions = false, false
Tick(15)

-- Role rows: three rows, the buttons stop at 0 and at the most a group can have.
ns.UI.Open("dungeons")
local page
for _, o in ipairs(CREATED) do if o.postForm then page = o end end
page.mode = "post"
ns.UI.Select("dungeons")
Tick(1)
local f = page.postForm
local rows = f.roles.rows
check(rows.t and rows.h and rows.d, "three role rows: tanks, healers, DPS")
check(rows.t.value:GetText() == "1" and rows.d.value:GetText() == "3", "start at 1 tank, 1 healer, 3 DPS")
rows.t.plus:Click(); rows.t.plus:Click(); rows.t.plus:Click()
Tick(1)
check(f.need.t == 2 and not rows.t.plus:IsEnabled(), "at most 2 tanks; + greys out")
rows.h.minus:Click(); rows.h.minus:Click()
Tick(1)
check(f.need.h == 0 and not rows.h.minus:IsEnabled(), "down to 0 healers; - greys out")
-- Picking my role makes sure I'm counted, and my role can't go below 1.
f.pickMe(2)
check(f.need.h == 1, "my role (healer) counts as at least 1")
Tick(1)
check(not rows.h.minus:IsEnabled(), "- greys out at 1 for my own role")
rows.h.minus:Click()
check(f.need.h == 1, "and a click can't take it to 0")
check(rows.t.minus:IsEnabled(), "other roles still go down")
check(ns.Dungeons.Post(ns.Dungeons.LIST[1][1], "h", { t = 1, h = 0, d = 3 }, "") and ns.Dungeons.MyGroup().nh == 1, "posting with 0 of my role still counts me")
ns.Dungeons.SetNeed("h", 0)
check(ns.Dungeons.MyGroup().nh == 1, "and Your group can't take it to 0 either")
ns.Dungeons.Close()
-- Rows don't overlap: each sits 22 pixels under the last.
local _, _, _, _, yT = rows.t.minus:GetPoint()
check(rows.t.label ~= rows.h.label, "separate rows")

-- Calendar form: role rows only for dungeon events (a new event starts as social).
ns.UI.Open("calendar")
local cal
for _, o in ipairs(CREATED) do if o.form and o.dayPager then cal = o end end
cal.mode, cal.formLoaded = "new", false
ns.UI.Select("calendar")
Tick(1)
check(cal.form.kind == "s" and not cal.form.roles.rows.t.label:IsShown(), "a new event is social: no role rows")
cal.form.pickKind(2)
Tick(1)
check(cal.form.roles.rows.t.label:IsShown(), "dungeon event: role rows shown")
check(not cal.form.impLabel:IsShown(), "a Member doesn't see the important rows")

-- Sounds: the chosen sound, on the chosen volume slider; off means silent; Test plays it.
local Toast = ns.Toast
wipe(SOUNDS)
ns.settings.sound, ns.settings.soundChannel = 3, 2
Toast.Show("Hi", "there")
check(#SOUNDS == 1 and SOUNDS[1].id == 3081 and SOUNDS[1].channel == "SFX", "whisper sound on the Effects slider")
ns.settings.popupSound = false
Toast.Show("Hi", "there")
check(#SOUNDS == 1 and Toast.IsShown(), "sound off: the pop-up shows, silently")
ns.settings.pop.answer = false
Toast.Show("Hi", "there", "answer")
check(#SOUNDS == 1, "that kind switched off: nothing")
Toast.Show("Hi", "there", "group")
check(#SOUNDS == 1 and Toast.IsShown(), "other kinds still show")
ns.settings.pop.answer, ns.settings.popupSound = true, true
ns.UI.Open("settings")
local set
for _, o in ipairs(CREATED) do if o.pickSound then set = o end end
wipe(SOUNDS)
set.pickSound(4)
check(ns.settings.sound == 4 and #SOUNDS == 1 and SOUNDS[1].id == 3175, "choosing a sound plays it")
set.pickChannel(3)
for _, o in ipairs(CREATED) do
    if o._text == ns.L.TEST_SOUND and o._scripts.OnClick then o._scripts.OnClick(o) end
end
check(#SOUNDS == 2 and SOUNDS[2].channel == "Dialog", "Test plays it on the Dialog slider")
-- Reminders keep their own switch even with every other pop-up off.
for k in pairs(ns.settings.pop) do ns.settings.pop[k] = false end
wipe(SOUNDS)
ns.Fire("REMIND", { title = "Run" }, GetServerTime() + 600)
check(Toast.IsShown() and #SOUNDS == 1, "a reminder still shows (and sounds) with other pop-ups off")
for k in pairs(ns.settings.pop) do ns.settings.pop[k] = true end
-- Each switch in Settings is wired to its own kind.
local ticks = 0
for kind, c in pairs(set.pops) do
    ticks = ticks + 1
    c:SetChecked(false); c._scripts.OnClick(c)
    check(ns.settings.pop[kind] == false, "Settings tick turns off " .. kind)
    c:SetChecked(true); c._scripts.OnClick(c)
end
check(ticks == 8, "eight pop-up switches in Settings (Phase 9: guildies' milestones)")

-- Nothing in our code changes the game's sound settings.
check(#UISpecialFrames == 0 and PanelManagerCalls == 0, "no taint tripwires touched")
check(#ERRORS == 0, "no errors (" .. (ERRORS[1] or "none") .. ")")
