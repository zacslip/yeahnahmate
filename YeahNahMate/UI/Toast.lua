-- Pop-ups: a small notice at the top of the screen for a new guild group at your level (or for one of
-- the dungeons you said you're available for) and, for a leader, someone signing up. Our own frame
-- (game popups break under Forever's gamepad UI). It goes away by itself; Settings has a switch for
-- each kind, and one for the sound. It never does anything by itself: Show only opens the Dungeons tab.
local ADDON, ns = ...
local L = ns.L
local UI = ns.UI

local Toast = {}
ns.Toast = Toast

local frame, hideTimer
local AfterHide                 -- below: what shows after a pop-up goes
-- Important event pop-ups wait here (in a fight, or behind another important one). Each has valid(),
-- false once its event has started (then it's dropped). While one shows, a normal pop-up waits too
-- (only the latest) instead of replacing it.
local important = {}
local importantUp = false
local deferred = nil

-- The pop-up sounds to choose from (the game's own), and the volume slider each can follow. Addons
-- can't set a sound's volume themselves; changing the game's volume settings for the player is
-- against our rules, so the player picks which of the game's sliders (Master / Effects / Dialog)
-- controls it.
Toast.SOUNDS = { { L.SOUND_READY, 8960 }, { L.SOUND_RAID, 8959 }, { L.SOUND_WHISPER, 3081 }, { L.SOUND_PING, 3175 } }
Toast.CHANNELS = { "Master", "SFX", "Dialog" }

function Toast.PlaySound()
    if not PlaySound then return end
    local snd = Toast.SOUNDS[ns.settings.sound] or Toast.SOUNDS[1]
    pcall(PlaySound, snd[2], Toast.CHANNELS[ns.settings.soundChannel] or "Master")
end

local function Build()
    frame = UI.Box(UIParent, 0, 0, 420, 58)
    frame:ClearAllPoints()
    frame:SetPoint("TOP", UIParent, "TOP", 0, -120)
    frame:SetFrameStrata("FULLSCREEN_DIALOG")      -- pop-ups sit above the main window
    frame:EnableMouse(true)
    frame:Hide()
    local icon = frame:CreateTexture(nil, "ARTWORK")
    icon:SetSize(32, 32)
    icon:SetPoint("TOPLEFT", 12, -13)
    icon:SetTexture(UI.ICON)
    frame.title = UI.Text(frame, "", "GameFontNormal", 52, -10, 256)
    frame.text = UI.Text(frame, "", "GameFontHighlightSmall", 52, -30, 300)
    frame.show = UI.Button(frame, L.SHOW, 60, 306, -8, function()
        frame:Hide()
        if frame.action then frame.action() else ns.UI.Open(frame.tab or "dungeons") end
    end)
    frame.close = UI.Button(frame, "x", 24, 0, 0, function() frame:Hide() end, 20)
    -- Both kept inside the right edge, whatever the button says (Show hung off the side).
    frame.show:ClearAllPoints()
    frame.show:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -10, -8)
    frame.close:ClearAllPoints()
    frame.close:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -12, -32)
    -- Not from inside OnHide itself: a moment later.
    frame:SetScript("OnHide", function()
        importantUp = false
        C_Timer.After(0.5, function() if not frame:IsShown() then ns.Safe(AfterHide) end end)
    end)
end

-- kind: which switch in Settings covers it (a key of settings.pop, or "remind"); nil always shows.
-- action (optional): { label, fn } puts a button of its own in place of Show.
function Toast.Allowed(kind)
    if kind == "remind" then return ns.settings.remind ~= false end
    return kind == nil or ns.settings.pop[kind] ~= false
end


local function Display(title, text, action, tab, sound, secs)
    if not frame then Build() end
    frame.action = action and action[2] or nil
    frame.show:SetText(action and action[1] or L.SHOW)
    frame.show:SetWidth(action and 92 or 60)
    frame.tab = tab or "dungeons"
    frame.title:SetText(title)
    frame.text:SetText(text)
    frame:Show()
    if sound then Toast.PlaySound() end
    if hideTimer then hideTimer:Cancel() end
    hideTimer = C_Timer.NewTimer(secs or 20, function() hideTimer = nil; frame:Hide() end)
end

local function NextImportant()
    if InCombatLockdown() then return false end
    while #important > 0 do
        local it = table.remove(important, 1)
        if it.valid() then
            Display(it.title, it.text, nil, "calendar", true, 40)
            importantUp = true
            return true
        end
    end
    return false
end

-- After a pop-up goes: the next important one, else the normal one that waited.
function AfterHide()
    if NextImportant() then return end
    local d = deferred
    deferred = nil
    if d and not InCombatLockdown() then Display(d[1], d[2], d[3], d[4], ns.settings.popupSound) end
end

function Toast.Show(title, text, kind, action)
    if not Toast.Allowed(kind) then Toast.nextTab = nil; return end
    local tab = Toast.nextTab
    Toast.nextTab = nil
    if importantUp and frame and frame:IsShown() then
        deferred = { title, text, action, tab }
        return
    end
    Display(title, text, action, tab, ns.settings.popupSound)
end

-- An important event's pop-up: no switch turns it off and it always plays the sound. In a fight it
-- waits until the fight is over. valid() says whether it's still worth showing.
function Toast.Important(title, text, valid)
    important[#important + 1] = { title = ns.GOLD .. title .. "|r", text = text, valid = valid or function() return true end }
    if importantUp and frame and frame:IsShown() then return end
    NextImportant()                 -- takes the place of a normal pop-up that's showing
end

ns.OnEvent("PLAYER_REGEN_ENABLED", function()
    if not (frame and frame:IsShown() and importantUp) then NextImportant() end
end)

function Toast.IsShown() return frame ~= nil and frame:IsShown() end
function Toast.Title() return frame and frame:IsShown() and frame.title:GetText() or nil end

local function Needs(g)
    local parts = {}
    if g.ht < g.nt then parts[#parts + 1] = L.ROLE_TANK end
    if g.hh < g.nh then parts[#parts + 1] = L.ROLE_HEALER end
    if g.hd < g.nd then parts[#parts + 1] = L.ROLE_DPS end
    return #parts > 0 and string.format(L.TOAST_NEEDS, table.concat(parts, ", ")) or L.FULL
end

-- A new group: at my level, or for one of the dungeons I'm available for.
ns.Listen("GROUP_POSTED", function(g)
    local D = ns.Dungeons
    local mine = D.MyAvail()
    local wanted = false
    if mine then for _, k in ipairs(mine.ds) do if k == g.d then wanted = true end end end
    if not wanted and not D.AtMyLevel(g.d) then return end
    if D.MyGroup() then return end            -- busy leading my own
    Toast.Show(string.format(L.TOAST_GROUP, g.owner:match("^%S+") or g.owner, D.Name(g.d)), Needs(g), "group")
end)

-- Someone signed up for my group.
ns.Listen("SIGNED_UP", function(name, role, g)
    local roleName = (role == "t" and L.ROLE_TANK) or (role == "h" and L.ROLE_HEALER) or L.ROLE_DPS
    Toast.Show(string.format(L.TOAST_SIGNED, name, roleName), ns.Dungeons.Name(g.d), "signup")
end)

-- A guildie asked for something I can make.
ns.Listen("REQUEST_POSTED", function(r)
    if not ns.Requests.ICanMake(r) then return end
    Toast.nextTab = "professions"
    local item = ns.Requests.ItemName(r) .. (r.n > 1 and (" x" .. r.n) or "")
    Toast.Show(string.format(L.TOAST_REQUEST, r.owner:match("^%S+") or r.owner, item), L.TOAST_REQUEST_CAN, "request")
end)

-- Someone said they'll make my request.
ns.Listen("REQUEST_CLAIMED", function(name, r)
    Toast.nextTab = "professions"
    Toast.Show(string.format(L.TOAST_CLAIMED, name:match("^%S+") or name, ns.Requests.ItemName(r)), "", "claim")
end)

-- A gathering started for an event I said I'm going to (or maybe): ask for an invite from the pop-up.
ns.Listen("GATHER_STARTED", function(a, e)
    local mine = ns.Calendar.MyAnswer(e, a.at)
    if mine ~= "y" and mine ~= "m" then return end
    Toast.Show(string.format(L.TOAST_GATHER, a.organiser:match("^%S+") or a.organiser, e.title), L.TOAST_GATHER_TEXT, "gather",
        { L.ASK_SHORT, function() ns.Gather.AskInvite(a.key, a.at) end })
end)

-- 15 minutes before an event I'm going to.
ns.Listen("REMIND", function(e, at)
    Toast.nextTab = "calendar"
    Toast.Show(L.REMIND_TITLE, e.title .. "  " .. ns.UI.TimeText(at), "remind")
end)

-- Important events (Calendar.lua): the reminders everyone gets, and "tell everyone now".
ns.Listen("IMPORTANT", function(e, at, mins)
    Toast.Important(string.format(L.TOAST_IMPORTANT_SOON, e.title),
        string.format(L.TOAST_IMPORTANT_IN, mins, ns.UI.TimeText(at)),
        function() return not e.x and GetServerTime() < at end)
end)

ns.Listen("IMPORTANT_NEW", function(e, at)
    Toast.Important(string.format(L.TOAST_IMPORTANT_NEW, e.title),
        ns.UI.DayText(at) .. " " .. ns.UI.TimeText(at),
        function() return not e.x and GetServerTime() < at end)
end)

-- Someone said they're going to my event.
ns.Listen("ANSWERED", function(name, answer, e, at)
    if answer ~= "y" then return end
    at = at or e.at                      -- the occurrence they answered (a weekly event has many)
    Toast.nextTab = "calendar"
    Toast.Show(string.format(L.TOAST_ANSWER, name, e.title), ns.UI.DayText(at) .. " " .. ns.UI.TimeText(at), "answer")
end)

-- Ask the Guild: an answer to my question, the asker replying to my answer, and questions of mine
-- waiting to be marked (once, after logging in). Show opens the card.
local function Short(s) return ns.ShortText(s, 60) end

ns.Listen("QUESTION_ANSWERED", function(name, q)
    Toast.Show(string.format(L.TOAST_Q_ANSWER, name:match("^%S+") or name), Short(q.tx), "qanswer",
        { L.SHOW, function() ns.UI.ShowQuestion(q.key) end })
end)

ns.Listen("QUESTION_REPLY", function(q)
    Toast.Show(string.format(L.TOAST_Q_REPLY, q.owner:match("^%S+") or q.owner), Short(q.tx), "qanswer",
        { L.SHOW, function() ns.UI.ShowQuestion(q.key) end })
end)

ns.Listen("QUESTIONS_WAITING", function(n)
    Toast.Show(string.format(L.TOAST_Q_WAITING, n), L.TOAST_Q_WAITING_TEXT, "qanswer",
        { L.SHOW, function() ns.UI.ShowQuestions("mine") end })
end)
