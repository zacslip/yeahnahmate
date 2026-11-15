-- The voice drawer: a small speaker tab on the main window's LEFT edge, level with the
-- guild banner. Clicking it slides a panel out from behind the window (and back in). It's for
-- proximity voice on Blizzard's own voice chat (Voice.lua).
--
-- The speaker icon (tab and panel) shows the state: grey off, red can't work, gold on but not in
-- guild voice, green on and in guild voice; it shows sound waves while a guildie is talking.
--
-- How it's layered: the drawer is part of the main window (a child of YeahNahMateFrame), so it moves,
-- hides and comes to the front with it. It sits just outside the window's left edge, in a holder
-- that clips what's inside it; the holder grows from nothing to the drawer's width and the panel,
-- pinned to the holder's LEFT edge, looks like it slides out from under the window.
local ADDON, ns = ...
local L = ns.L
local UI = ns.UI

local WIDTH = 270           -- the open drawer
local SPEED = WIDTH / 0.18  -- fully open or shut in about a fifth of a second
local TUCK = 3              -- how far the drawer tucks under the window's border
local TOP = -26             -- level with the top of the guild banner (Window.lua's header)
local PAD = 16

local SPEAKER = "Interface\\Common\\VoiceChat-Speaker"
local SPEAKER_ON = "Interface\\Common\\VoiceChat-On"     -- with sound waves
local COLOURS = {
    off = { 0.55, 0.55, 0.55 },
    cant = { 1, 0.3, 0.3 },
    notin = { 1, 0.82, 0 },
    on = { 0.3, 1, 0.3 },
    group = { 0.4, 0.7, 1 },    -- in my group's own voice chat (group mode)
}

-- The ranges and the volume curve live in Voice.lua (kept here under their old names too).
UI.VOICE_RANGES = ns.Voice.RANGES
UI.VoiceVolume = ns.Voice.Volume

local holder, panel, tab
local open = false          -- stays as you left it while you play; starts shut each login

local function Arrow()
    tab.arrow:SetText(open and ">" or "<")
end

local function Step(self, elapsed)
    local w = self.shown + (open and 1 or -1) * SPEED * elapsed
    if w >= WIDTH then w = WIDTH elseif w <= 1 then w = 1 end
    self.shown = w
    self:SetWidth(w)
    panel:SetShown(w > 1)
    if (open and w >= WIDTH) or (not open and w <= 1) then self:SetScript("OnUpdate", nil) end
end

function UI.ToggleVoice(state)
    if not holder then return end
    if state == nil then open = not open else open = state and true or false end
    Arrow()
    holder:SetScript("OnUpdate", Step)
end

function UI.VoiceOpen() return open end


local ROWS = 9              -- guildies shown in the "Near you in voice" list
local ROW_H = 18

local function Backdrop(f, edge)
    if not f.SetBackdrop then return end
    f:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background-Dark",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        edgeSize = edge, insets = { left = 3, right = 3, top = 3, bottom = 3 },
    })
    f:SetBackdropColor(0, 0, 0, 0.92)
    f:SetBackdropBorderColor(0.6, 0.6, 0.6, 1)
end

-- A wrapped paragraph under `below`, in `parent`.
local function Para(parent, below, text, font, gap)
    local fs = parent:CreateFontString(nil, "OVERLAY", font or "GameFontHighlightSmall")
    fs:SetPoint("TOPLEFT", below, "BOTTOMLEFT", 0, -(gap or 6))
    fs:SetWidth(WIDTH - 2 * PAD)
    fs:SetJustifyH("LEFT")
    fs:SetWordWrap(true)
    fs:SetText(text)
    return fs
end

local function Hover(b, text)
    b:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:SetText(text, 1, 1, 1, 1, true)
        GameTooltip:Show()
    end)
    b:SetScript("OnLeave", function() GameTooltip:Hide() end)
end

-- "Near you in voice": the other guildies in guild voice, nearest first.
function UI.VoiceList()
    if not panel or not panel.rows then return end
    local list = ns.Voice.list or {}
    local on = tab.state == "on"
    for i, row in ipairs(panel.rows) do
        local r = on and list[i]
        row:SetShown(r ~= nil and r ~= false)
        if r then
            local m = ns.Guild.Get(r.name)
            local grey = r.muted or (not r.yards and r.why ~= "always" and r.why ~= "group")
            row.name:SetText(grey and (ns.GREY .. r.name .. "|r") or (m and UI.Name(m) or r.name))
            row.who = r.name ~= "?" and r.name or nil
            local where
            if r.muted then where = L.VOICE_MUTED
            elseif r.why == "always" then where = "|cffffd100" .. L.VOICE_ALWAYS .. "|r"
            elseif r.yards then where = string.format(L.VOICE_YARDS, math.floor(r.yards + 0.5))
            elseif r.why == "group" then where = L.VOICE_IN_GROUP
            else where = L.VOICE_NO_SPOT end
            row.where:SetText(where)
            local vol = r.volume or 0
            row.bar:SetWidth(math.max(1, 40 * math.min(1, vol / 100)))
            row.bar:SetShown(not r.muted)
            row.talk:SetShown(r.speaking == true)
        end
    end
    local extra = on and math.max(0, #list - ROWS) or 0
    panel.more:SetText(extra > 0 and string.format(L.VOICE_MORE, extra) or "")
    panel.empty:SetShown(on and #list == 0)
end

-- Show the voice state on both speakers, the status lines and the buttons.
function UI.VoiceRefresh()
    if not tab or not ns.Voice then return end
    local state, line, joining = ns.Voice.State()
    local s = ns.settings
    local c = COLOURS[state]
    local talking = state == "on" and ns.Voice.SomeoneTalking()
    for _, icon in ipairs({ tab.icon, panel.icon }) do
        icon:SetTexture(talking and SPEAKER_ON or SPEAKER)
        icon:SetVertexColor(c[1], c[2], c[3])
    end
    panel.state:SetText(L["VOICE_STATE_" .. state:upper()])
    panel.state:SetTextColor(c[1], c[2], c[3])
    panel.detail:SetText(line)
    panel.onCheck:SetChecked(s.voiceOn == true)
    -- Join guild voice when that's the next step, or Back to guild voice from group voice.
    local back = state == "group"
    panel.join:SetText(back and L.VOICE_BACK_BTN or L.VOICE_JOIN)
    panel.join:SetShown((state == "notin" and not joining) or back)
    -- Group voice whenever I'm in a group and voice works.
    local canGroup = IsInGroup and IsInGroup() and state ~= "cant" and state ~= "group"
    panel.groupBtn:SetShown(canGroup and true or false)
    -- Leave voice once Proximity is unticked, and from group voice.
    panel.leave:SetShown((state == "off" and ns.Voice.InGuildVoice()) or back)
    -- The buttons that show, left to right (never more than two).
    local x = PAD
    for _, b in ipairs({ panel.join, panel.leave, panel.groupBtn }) do
        if b:IsShown() then
            b:ClearAllPoints()
            b:SetPoint("TOPLEFT", x, -116)
            x = x + b:GetWidth() + 4
        end
    end
    panel.groupCheck:SetChecked(s.voiceGroupFull ~= false)
    panel.popCheck:SetChecked(s.pop.voice ~= false)
    tab.state, tab.line, tab.talking = state, line, talking
    UI.VoiceList()
end

-- The help (how to turn voice chat on, where it can get in the way) folds over the settings.
local function ShowHelp(show)
    panel.help:SetShown(show)
    panel.body:SetShown(not show)
    panel.helpBtn:SetText(show and L.VOICE_HELP_CLOSE or "?")
end

-- Called once by Window.lua when the main window is built.
function UI.BuildVoiceDrawer(frame)
    holder = CreateFrame("Frame", nil, frame)
    holder:SetPoint("TOPRIGHT", frame, "TOPLEFT", TUCK, TOP)
    holder:SetPoint("BOTTOMRIGHT", frame, "BOTTOMLEFT", TUCK, 12)
    holder:SetWidth(1)
    holder.shown = 1
    holder:SetClipsChildren(true)
    -- Under the window's own parts, so the border overlaps the drawer's tucked-in edge.
    holder:SetFrameLevel(math.max(frame:GetFrameLevel() - 1, 0))

    panel = CreateFrame("Frame", nil, holder, BackdropTemplateMixin and "BackdropTemplate" or nil)
    panel:SetPoint("TOPLEFT")
    panel:SetPoint("BOTTOMLEFT")
    panel:SetWidth(WIDTH)
    Backdrop(panel, 14)
    panel:EnableMouse(true)     -- clicks on the drawer don't fall through to the world
    panel:Hide()
    local s = ns.settings

    panel.icon = panel:CreateTexture(nil, "ARTWORK")
    panel.icon:SetTexture(SPEAKER)
    panel.icon:SetSize(20, 20)
    panel.icon:SetPoint("TOPLEFT", PAD, -14)
    panel.head = UI.Text(panel, L.VOICE_TITLE, "GameFontNormal", PAD + 26, -17)
    panel.state = UI.Text(panel, "", "GameFontNormalSmall", PAD + 26, -33)
    panel.helpBtn = UI.Button(panel, "?", 44, WIDTH - PAD - 44, -14, function() ShowHelp(not panel.help:IsShown()) end)
    Hover(panel.helpBtn, L.VOICE_HELP_TIP)

    -- Proximity on/off, what the state means, and Join guild voice when that's the next step.
    panel.onCheck = UI.Check(panel, L.VOICE_ON_LABEL, PAD - 4, -56, s.voiceOn == true,
        function(v) ns.Voice.SetOn(v) end)
    panel.detail = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    panel.detail:SetPoint("TOPLEFT", PAD, -86)
    panel.detail:SetWidth(WIDTH - 2 * PAD)
    panel.detail:SetJustifyH("LEFT")
    panel.detail:SetWordWrap(true)
    panel.join = UI.Button(panel, L.VOICE_JOIN, 140, PAD, -116, function()
        if ns.Voice.Join() then C_Timer.After(1, UI.VoiceRefresh) end
    end)
    -- Group mode: my party/raid's own voice chat (Voice.SwitchToGroup).
    panel.groupBtn = UI.Button(panel, L.VOICE_GROUP_BTN, 94, PAD + 144, -116, function()
        ns.Voice.SwitchToGroup()
        C_Timer.After(1, UI.VoiceRefresh)
    end)
    Hover(panel.groupBtn, L.VOICE_GROUPBTN_TIP)
    panel.leave = UI.Button(panel, L.VOICE_LEAVE, 94, PAD, -116, function()
        ns.Voice.Leave()
        C_Timer.After(1, UI.VoiceRefresh)
    end)
    Hover(panel.leave, L.VOICE_LEAVE_TIP)

    -- Everything under the status: the settings and the list (the help folds over this).
    local body = CreateFrame("Frame", nil, panel)
    body:SetPoint("TOPLEFT", 0, -144)
    body:SetPoint("BOTTOMRIGHT")
    panel.body = body

    -- How far voices carry, in plain words (players think in near/far, not yards).
    UI.Text(body, L.VOICE_RANGE, "GameFontNormalSmall", PAD, -11)
    local order = ns.Voice.RANGE_ORDER
    local pickRange
    pickRange, panel.rangeButtons = UI.Choice(body, { L.VOICE_CLOSE, L.VOICE_NORMAL, L.VOICE_FAR }, PAD + 62, -6, 54,
        function(i)
            if order[i] and s.voiceRange ~= order[i] then s.voiceRange = order[i]; ns.Fire("SETTINGS") end
        end)
    for i, key in ipairs(order) do
        local r = ns.Voice.RANGES[key]
        Hover(panel.rangeButtons[i], string.format(L.VOICE_RANGE_TIP, r.full, r.gone))
        if key == (s.voiceRange or "normal") then pickRange(i) end
    end
    -- How quiet far-away guildies get.
    UI.Text(body, L.VOICE_FAR_AWAY, "GameFontNormalSmall", PAD, -37)
    local pickQuiet
    pickQuiet, panel.quietButtons = UI.Choice(body, { L.VOICE_SILENT, L.VOICE_FAINT }, PAD + 62, -32, 82,
        function(i)
            local v = i == 2 and 20 or 0
            if s.voiceQuietest ~= v then s.voiceQuietest = v; ns.Fire("SETTINGS") end
        end)
    Hover(panel.quietButtons[1], L.VOICE_SILENT_TIP)
    Hover(panel.quietButtons[2], L.VOICE_FAINT_TIP)
    pickQuiet((s.voiceQuietest or 0) > 0 and 2 or 1)
    -- Guildies it can't place (no addon, not sharing, another continent).
    UI.Text(body, L.VOICE_UNPLACED, "GameFontNormalSmall", PAD, -63)
    local pickUnplaced
    pickUnplaced, panel.unplacedButtons = UI.Choice(body, { L.VOICE_NORMAL_VOL, L.VOICE_QUIET }, PAD + 62, -58, 82,
        function(i)
            local v = i == 2 and "quiet" or "normal"
            if s.voiceUnplaced ~= v then s.voiceUnplaced = v; ns.Fire("SETTINGS") end
        end)
    Hover(panel.unplacedButtons[1], L.VOICE_UNPLACED_TIP)
    Hover(panel.unplacedButtons[2], L.VOICE_UNPLACED_TIP)
    pickUnplaced(s.voiceUnplaced == "quiet" and 2 or 1)
    -- How the volume fades (a straight line can sound loud, then vanish).
    UI.Text(body, L.VOICE_FADE, "GameFontNormalSmall", PAD, -89)
    local curves = ns.Voice.CURVE_ORDER
    local pickCurve
    pickCurve, panel.curveButtons = UI.Choice(body, { L.VOICE_EVEN, L.VOICE_NATURAL }, PAD + 62, -84, 82,
        function(i)
            if curves[i] and s.voiceCurve ~= curves[i] then s.voiceCurve = curves[i]; ns.Fire("SETTINGS") end
        end)
    Hover(panel.curveButtons[1], L.VOICE_EVEN_TIP)
    Hover(panel.curveButtons[2], L.VOICE_NATURAL_TIP)
    pickCurve(s.voiceCurve == "natural" and 2 or 1)
    -- Full volume for my own party/raid, whatever the distance.
    panel.groupCheck = UI.Check(body, L.VOICE_GROUP_FULL, PAD - 4, -110, s.voiceGroupFull ~= false,
        function(v) s.voiceGroupFull = v; ns.Fire("SETTINGS") end)
    Hover(panel.groupCheck, L.VOICE_GROUP_TIP)
    -- The pop-up a guildie's Group voice button sends (settings.pop.voice; Settings has no room for it).
    panel.popCheck = UI.Check(body, L.VOICE_POP_LABEL, PAD - 4, -132, s.pop.voice ~= false,
        function(v) s.pop.voice = v; ns.Fire("SETTINGS") end)
    Hover(panel.popCheck, L.VOICE_POP_TIP)

    -- Near you in voice. Click a name to always hear them (like ForeverVoice and WakVoice).
    UI.Header(body, L.VOICE_NEAR, PAD, -164, WIDTH - 2 * PAD)
    panel.rows = {}
    for i = 1, ROWS do
        local row = CreateFrame("Button", nil, body)
        row:SetPoint("TOPLEFT", PAD, -186 - (i - 1) * ROW_H)
        row:SetSize(WIDTH - 2 * PAD, ROW_H)
        row:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")
        row:SetScript("OnClick", function(self)
            if self.who then ns.Voice.ToggleAlways(self.who); UI.VoiceList() end
        end)
        row:SetScript("OnEnter", function(self)
            if not self.who then return end
            local on = ns.settings.voiceAlways and ns.settings.voiceAlways[self.who]
            GameTooltip:SetOwner(self, "ANCHOR_LEFT")
            GameTooltip:SetText(string.format(on and L.VOICE_ROW_TIP_ON or L.VOICE_ROW_TIP, self.who), 1, 1, 1, 1, true)
            GameTooltip:Show()
        end)
        row:SetScript("OnLeave", function() GameTooltip:Hide() end)
        row.talk = row:CreateTexture(nil, "ARTWORK")
        row.talk:SetTexture(SPEAKER_ON)
        row.talk:SetVertexColor(0.3, 1, 0.3)
        row.talk:SetSize(12, 12)
        row.talk:SetPoint("LEFT", 0, 0)
        row.name = UI.Text(row, "", "GameFontHighlightSmall", 14, -3, 108)
        row.where = UI.Text(row, "", "GameFontDisableSmall", 124, -3, 62)
        row.barBg = row:CreateTexture(nil, "BACKGROUND")
        row.barBg:SetColorTexture(1, 1, 1, 0.12)
        row.barBg:SetSize(40, 6)
        row.barBg:SetPoint("RIGHT", 0, 0)
        row.bar = row:CreateTexture(nil, "ARTWORK")
        row.bar:SetColorTexture(0.3, 1, 0.3, 0.85)
        row.bar:SetHeight(6)
        row.bar:SetPoint("LEFT", row.barBg, "LEFT", 0, 0)
        row:Hide()
        panel.rows[i] = row
    end
    panel.more = UI.Text(body, "", "GameFontDisableSmall", PAD, -188 - ROWS * ROW_H)
    panel.empty = UI.Text(body, L.VOICE_NOBODY, "GameFontDisableSmall", PAD, -188, WIDTH - 2 * PAD)
    panel.empty:SetWordWrap(true)
    panel.empty:Hide()

    -- The help, folded away until "?" is clicked.
    local help = CreateFrame("Frame", nil, panel)
    help:SetPoint("TOPLEFT", 0, -144)
    help:SetPoint("BOTTOMRIGHT")
    help:Hide()
    panel.help = help
    local anchor = CreateFrame("Frame", nil, help)
    anchor:SetPoint("TOPLEFT", PAD, -6)
    anchor:SetSize(1, 1)
    panel.howHead = Para(help, anchor, L.VOICE_HOW, "GameFontNormal", 0)
    panel.how = Para(help, panel.howHead, L.VOICE_HOW_TEXT)
    panel.noteHead = Para(help, panel.how, L.VOICE_NOTES, "GameFontNormal", 12)
    panel.notes = Para(help, panel.noteHead, L.VOICE_NOTES_TEXT)

    -- The tab: a little speaker sticking out of the drawer's left edge, so it rides along as the
    -- drawer opens. It belongs to the window, not the holder, or the holder's clipping would hide it.
    tab = CreateFrame("Button", nil, frame, BackdropTemplateMixin and "BackdropTemplate" or nil)
    -- Sticks out about 30 px past the window's edge, so it's easy to see and click.
    tab:SetSize(36, 52)
    tab:SetPoint("TOPRIGHT", holder, "TOPLEFT", 2, 0)
    tab:SetFrameLevel(holder:GetFrameLevel())
    Backdrop(tab, 12)
    tab.icon = tab:CreateTexture(nil, "ARTWORK")
    tab.icon:SetTexture(SPEAKER)
    tab.icon:SetSize(18, 18)
    tab.icon:SetPoint("TOP", -1, -8)
    tab.arrow = tab:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    tab.arrow:SetPoint("BOTTOM", -1, 7)
    tab:SetHighlightTexture("Interface\\Buttons\\UI-Common-MouseHilight", "ADD")
    -- Left-click slides the drawer; right-click turns Proximity on/off.
    tab:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    tab:SetScript("OnClick", function(self, button)
        if button == "RightButton" then
            ns.Voice.Command("")
            if GameTooltip:IsOwned(self) then self:GetScript("OnEnter")(self) end
        else
            UI.ToggleVoice()
        end
    end)
    tab:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:SetText(L.VOICE_TITLE)
        if self.state then
            local c = COLOURS[self.state]
            GameTooltip:AddLine(L["VOICE_STATE_" .. self.state:upper()], c[1], c[2], c[3])
            GameTooltip:AddLine(self.line, 1, 1, 1, true)
        end
        GameTooltip:AddLine(L.VOICE_TIP, 0.7, 0.7, 0.7, true)
        GameTooltip:Show()
    end)
    tab:SetScript("OnLeave", function() GameTooltip:Hide() end)
    Arrow()

    UI.voiceHolder, UI.voicePanel, UI.voiceTab = holder, panel, tab
    UI.VoiceRefresh()
end

UI.ShowVoiceHelp = function(show) if panel then ShowHelp(show) end end

ns.Listen("VOICE", function() ns.Safe(UI.VoiceRefresh) end)
ns.Listen("SETTINGS", function() ns.Safe(UI.VoiceRefresh) end)
-- The list changes every second while it's on; only redraw it when the drawer is open.
ns.Listen("VOICE_LIST", function() if open and panel then ns.Safe(UI.VoiceList) end end)
