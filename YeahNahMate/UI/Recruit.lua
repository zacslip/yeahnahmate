-- The Recruiters drawer (Phase 13; data in Recruit.lua): a handshake tab on the main window's RIGHT edge,
-- up by the version number, in the style of our tab on the game's guild window (UI/GuildButton.lua).
-- Clicking it slides a panel out to the right, from under the window, like the voice drawer does on the
-- left (UI/Voice.lua). A gold "!" on the tab until I've said who got me onto the addon.
--
-- Inside: who got me onto it (or the question), the guildies online without the addon (Share), and the
-- leaderboard (All time / This month). The guild master and managers right-click a leaderboard row to
-- take a wrong claim off it.
local ADDON, ns = ...
local L = ns.L
local UI = ns.UI

local WIDTH = 280
local SPEED = WIDTH / 0.18      -- open or shut in about a fifth of a second
local TUCK = 3                  -- tucks under the window's border
local TOP = -26                 -- level with the top of the banner
local PAD = 14
local ICON = "Interface\\Icons\\Achievement_Reputation_01"     -- the handshake (picked in game, 21 Nov)
local SHARE_ROWS, BOARD_ROWS, PICK_ROWS = 6, 10, 14

local holder, panel, tab
local open = false              -- starts shut each login
local period = "all"
local shareOffset, pickOffset = 0, 0

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

local function Tip(f, lines)
    f:SetScript("OnEnter", function(self)
        if self.hl then self.hl:Show() end
        local l = lines
        if type(lines) == "function" then l = lines(self) end
        if type(l) ~= "table" or #l == 0 then return end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:AddLine(l[1], 1, 0.82, 0)
        for i = 2, #l do GameTooltip:AddLine(l[i], 1, 1, 1, true) end
        GameTooltip:Show()
    end)
    f:SetScript("OnLeave", function(self)
        if self.hl then self.hl:Hide() end
        GameTooltip:Hide()
    end)
end

local function Coloured(name)
    local m = ns.Guild.Get(name)
    if m and m.class then return "|c" .. ns.ClassHex(m.class) .. name .. "|r" end
    return name
end

local function Short(name) return name and (name:match("^%S+") or name) or "?" end

local function Step(self, elapsed)
    local w = self.shown + (open and 1 or -1) * SPEED * elapsed
    if w >= WIDTH then w = WIDTH elseif w <= 1 then w = 1 end
    self.shown = w
    self:SetWidth(w)
    panel:SetShown(w > 1)
    if (open and w >= WIDTH) or (not open and w <= 1) then self:SetScript("OnUpdate", nil) end
end

function UI.ToggleRecruit(state)
    if not holder then return end
    if state == nil then open = not open else open = state and true or false end
    holder:SetScript("OnUpdate", Step)
    if open then UI.RecruitRefresh() end
end

function UI.RecruitOpen() return open end

---------------------------------------------------------------------------------------------------
-- Refresh

local function RefreshTab()
    if not tab then return end
    tab.bang:SetShown(ns.Recruit.NeedsAnswer())
end

local function RefreshMine()
    local R = ns.Recruit
    local c = R.MyClaim()
    local q = panel.question
    if c then
        q:Hide()
        panel.answer:Show()
        if c.by == "" then panel.answer:SetText(L.RECRUIT_SKIPPED)
        else panel.answer:SetText(string.format(L.RECRUIT_YOU_SAID, Coloured(c.by))) end
        return
    end
    panel.answer:Hide()
    q:Show()
    local sw = R.SharedWithMe()
    for i, b in ipairs(q.suggest) do
        local s = sw[i]
        b.name = s and s.name
        b:SetShown(s ~= nil and R.CanBeRecruiter(s.name))
        if s then b:SetText(Short(s.name)) end
    end
    q.none:SetShown(#sw == 0)
end

local function RefreshShare()
    local list = ns.Recruit.Candidates()
    local maxOff = math.max(0, #list - SHARE_ROWS)
    if shareOffset > maxOff then shareOffset = maxOff end
    for i, r in ipairs(panel.shareRows) do
        local c = list[i + shareOffset]
        r.c = c
        r:SetShown(c ~= nil)
        if c then
            r.name:SetText(Coloured(c.name) .. ns.GREY .. "  " .. (c.level or "") .. "|r")
            local can = ns.Recruit.CanShareTo(c.name)
            r.share:SetEnabled(can)
            r.share:SetText(c.shared and L.RECRUIT_SHARED or L.RECRUIT_SHARE)
        end
    end
    panel.shareEmpty:SetShown(#list == 0)
    panel.shareMore:SetText(#list > SHARE_ROWS and string.format(L.RECRUIT_MORE, shareOffset + 1,
        math.min(#list, shareOffset + SHARE_ROWS), #list) or "")
end

local function RefreshBoard()
    if not panel.boardRows then return end      -- still being built
    local R = ns.Recruit
    local list = R.Leaderboard(period)
    local me = ns.Alts.Person(ns.me)
    for i, r in ipairs(panel.boardRows) do
        local e = list[i]
        r.e = e
        r:SetShown(e ~= nil)
        if e then
            local name = e.name == me and (ns.GOLD .. Short(e.name) .. "|r") or Coloured(e.name)
            r.place:SetText(i .. ".")
            r.name:SetText(name)
            r.count:SetText(tostring(e.n))
        end
    end
    panel.boardEmpty:SetShown(#list == 0)
    panel.boardEmpty:SetText(period == "month" and L.RECRUIT_BOARD_EMPTY_MONTH or L.RECRUIT_BOARD_EMPTY)
    local place, n = R.MyPlace(period)
    if place and place > BOARD_ROWS then panel.myPlace:SetText(string.format(L.RECRUIT_MY_PLACE, place, n))
    elseif not place and #list > 0 then panel.myPlace:SetText(L.RECRUIT_NOT_YET)
    else panel.myPlace:SetText("") end
end

local function RefreshPick()
    local p = panel.picker
    if not p:IsShown() then return end
    local names = {}
    for name in pairs(ns.Comm.users) do
        if ns.Recruit.CanBeRecruiter(name) and not (ns.Comm.users[name].sim and not (ns.Sim and ns.Sim.IsOn())) then
            names[#names + 1] = name
        end
    end
    table.sort(names)
    local maxOff = math.max(0, #names - PICK_ROWS)
    if pickOffset > maxOff then pickOffset = maxOff end
    for i, r in ipairs(p.rows) do
        local n = names[i + pickOffset]
        r.who = n
        r:SetShown(n ~= nil)
        if n then r.text:SetText(Coloured(n)) end
    end
    p.empty:SetShown(#names == 0)
end

function UI.RecruitRefresh()
    RefreshTab()
    if not panel or not open then return end
    RefreshMine()
    RefreshShare()
    RefreshBoard()
    RefreshPick()
end

for _, e in ipairs({ "RECRUIT", "USERS", "ROSTER", "LOGIN" }) do
    ns.Listen(e, function() ns.Safe(UI.RecruitRefresh) end)
end

---------------------------------------------------------------------------------------------------
-- Build

local function Answer(by)
    if ns.Recruit.Claim(by) then
        panel.picker:Hide()
        UI.RecruitRefresh()
    end
end

local function BuildQuestion(y)
    local q = CreateFrame("Frame", nil, panel)
    q:SetPoint("TOPLEFT", 0, y)
    q:SetSize(WIDTH, 92)
    UI.Text(q, ns.GOLD .. L.RECRUIT_QUESTION .. "|r", "GameFontNormalSmall", PAD, 0, WIDTH - 2 * PAD)
    q.none = UI.Text(q, L.RECRUIT_NOBODY_SHARED, "GameFontDisableSmall", PAD, -18, WIDTH - 2 * PAD)
    q.suggest = {}
    local bw = math.floor((WIDTH - 2 * PAD - 8) / 3)
    for i = 1, 3 do
        local b = UI.Button(q, "", bw, PAD + (i - 1) * (bw + 4), -16, function(self) if self.name then Answer(self.name) end end, 22)
        Tip(b, function(self) return self.name and { self.name, L.RECRUIT_SUGGEST_TIP } end)
        q.suggest[i] = b
    end
    local w2 = math.floor((WIDTH - 2 * PAD - 4) / 2)
    local other = UI.Button(q, L.RECRUIT_SOMEONE_ELSE, w2, PAD, -42, function()
        pickOffset = 0
        panel.picker:Show()
        RefreshPick()
    end, 22)
    Tip(other, { L.RECRUIT_SOMEONE_ELSE, L.RECRUIT_SOMEONE_ELSE_TIP })
    local skip = UI.Button(q, L.RECRUIT_SKIP, w2, PAD + w2 + 4, -42, function(self)
        if self.armed then Answer("") else self.armed = true; self:SetText(L.MS_SURE) end
    end, 22)
    skip:HookScript("OnHide", function(self) self.armed = nil; self:SetText(L.RECRUIT_SKIP) end)
    Tip(skip, { L.RECRUIT_SKIP, L.RECRUIT_SKIP_TIP })
    UI.Text(q, L.RECRUIT_ONCE, "GameFontDisableSmall", PAD, -70, WIDTH - 2 * PAD)
    return q
end

local function BuildPicker()
    local p = CreateFrame("Frame", nil, panel, BackdropTemplateMixin and "BackdropTemplate" or nil)
    p:SetPoint("TOPLEFT", 6, -44)
    p:SetPoint("BOTTOMRIGHT", -6, 6)
    p:SetFrameLevel(panel:GetFrameLevel() + 10)
    Backdrop(p, 12)
    p:SetBackdropColor(0.04, 0.04, 0.04, 0.98)
    p:EnableMouse(true)
    UI.Text(p, ns.GOLD .. L.RECRUIT_PICK_TITLE .. "|r", "GameFontNormalSmall", 10, -10, WIDTH - 40)
    UI.Button(p, L.CANCEL, 70, WIDTH - 12 - 82, -6, function() p:Hide() end, 20)
    p.rows = {}
    for i = 1, PICK_ROWS do
        local r = UI.Row(p, 8, -34 - (i - 1) * 20, WIDTH - 28, 19)
        r.text = UI.Text(r, "", "GameFontHighlightSmall", 6, -3, WIDTH - 44)
        r:SetScript("OnClick", function(self) if self.who then Answer(self.who) end end)
        p.rows[i] = r
    end
    p.empty = UI.Text(p, L.RECRUIT_PICK_EMPTY, "GameFontDisableSmall", 10, -36, WIDTH - 40)
    p:EnableMouseWheel(true)
    p:SetScript("OnMouseWheel", function(_, d) pickOffset = math.max(0, pickOffset - d * 3); RefreshPick() end)
    p:Hide()
    return p
end

-- Managers: right-click a leaderboard row to take one of that recruiter's claims off.
local function BuildHideMenu()
    local m = CreateFrame("Frame", nil, panel, BackdropTemplateMixin and "BackdropTemplate" or nil)
    m:SetSize(WIDTH - 40, 40)
    m:SetFrameLevel(panel:GetFrameLevel() + 12)
    Backdrop(m, 12)
    m:SetBackdropColor(0.04, 0.04, 0.04, 0.98)
    m:EnableMouse(true)
    m.title = UI.Text(m, "", "GameFontNormalSmall", 10, -8, WIDTH - 60)
    m.rows = {}
    m:Hide()
    function m.Open(anchor, e)
        m.title:SetText(ns.GOLD .. string.format(L.RECRUIT_HIDE_TITLE, Short(e.name)) .. "|r")
        for _, r in ipairs(m.rows) do r:Hide() end
        for i, who in ipairs(e.recruits) do
            local r = m.rows[i]
            if not r then
                r = UI.Row(m, 6, -26 - (i - 1) * 18, WIDTH - 52, 17)
                r.text = UI.Text(r, "", "GameFontHighlightSmall", 6, -2, WIDTH - 70)
                r:SetScript("OnClick", function(self)
                    if self.armed then
                        ns.Recruit.Hide(self.who); m:Hide(); UI.RecruitRefresh()
                    else
                        self.armed = true
                        self.text:SetText("|cffff6060" .. string.format(L.RECRUIT_HIDE_SURE, self.who) .. "|r")
                    end
                end)
                m.rows[i] = r
            end
            r.who, r.armed = who, nil
            r.text:SetText(string.format(L.RECRUIT_HIDE_ROW, who))
            r:Show()
        end
        m:SetHeight(34 + #e.recruits * 18)
        m:ClearAllPoints()
        m:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 10, -2)
        m:Show()
    end
    return m
end

local function Build(frame)
    holder = CreateFrame("Frame", nil, frame)
    holder:SetPoint("TOPLEFT", frame, "TOPRIGHT", -TUCK, TOP)
    holder:SetPoint("BOTTOMLEFT", frame, "BOTTOMRIGHT", -TUCK, 12)
    holder:SetWidth(1)
    holder.shown = 1
    holder:SetClipsChildren(true)
    -- Under the window's own parts, so the border overlaps the drawer's tucked-in edge.
    holder:SetFrameLevel(math.max(frame:GetFrameLevel() - 1, 0))

    -- Pinned to the holder's RIGHT edge: as the holder grows the panel looks like it slides out.
    panel = CreateFrame("Frame", nil, holder, BackdropTemplateMixin and "BackdropTemplate" or nil)
    panel:SetPoint("TOPRIGHT")
    panel:SetPoint("BOTTOMRIGHT")
    panel:SetWidth(WIDTH)
    Backdrop(panel, 14)
    panel:EnableMouse(true)
    panel:Hide()

    local icon = panel:CreateTexture(nil, "ARTWORK")
    icon:SetTexture(ICON)
    icon:SetSize(22, 22)
    icon:SetPoint("TOPLEFT", PAD, -12)
    UI.Text(panel, L.RECRUIT_TITLE, "GameFontNormal", PAD + 28, -13)
    UI.Text(panel, L.RECRUIT_SUB, "GameFontDisableSmall", PAD + 28, -28, WIDTH - PAD * 2 - 28)

    -- Who got me onto it
    local y = -48
    panel.answer = UI.Text(panel, "", "GameFontHighlightSmall", PAD, y - 2, WIDTH - 2 * PAD)
    panel.question = BuildQuestion(y)

    -- Share
    y = -146
    UI.Header(panel, L.RECRUIT_SHARE_HEAD, PAD, y, WIDTH - 2 * PAD)
    local shareTip = UI.Text(panel, L.RECRUIT_SHARE_HINT, "GameFontDisableSmall", PAD, y - 20, WIDTH - 2 * PAD)
    shareTip:SetWordWrap(true)
    shareTip:SetHeight(24)
    shareTip:SetJustifyV("TOP")
    panel.shareRows = {}
    for i = 1, SHARE_ROWS do
        local r = UI.Row(panel, PAD - 4, y - 46 - (i - 1) * 21, WIDTH - 2 * PAD + 8, 20)
        r.name = UI.Text(r, "", "GameFontHighlightSmall", 6, -4, WIDTH - 2 * PAD - 80)
        r.share = UI.Button(r, L.RECRUIT_SHARE, 66, WIDTH - 2 * PAD - 66, -1, function()
            if r.c and ns.Recruit.Share(r.c.name) then UI.RecruitRefresh() end
        end, 18)
        Tip(r.share, function() return { L.RECRUIT_SHARE, L.RECRUIT_SHARE_TIP } end)
        r:EnableMouseWheel(true)
        r:SetScript("OnMouseWheel", function(_, d) shareOffset = math.max(0, shareOffset - d); RefreshShare() end)
        panel.shareRows[i] = r
    end
    panel.shareEmpty = UI.Text(panel, L.RECRUIT_SHARE_EMPTY, "GameFontDisableSmall", PAD, y - 50, WIDTH - 2 * PAD)
    panel.shareMore = UI.Text(panel, "", "GameFontDisableSmall", PAD, y - 50 - SHARE_ROWS * 21, WIDTH - 2 * PAD, "RIGHT")

    -- The leaderboard
    y = y - 50 - SHARE_ROWS * 21 - 18
    UI.Header(panel, L.RECRUIT_BOARD_HEAD, PAD, y, WIDTH - 2 * PAD)
    local pick = UI.Choice(panel, { L.RECRUIT_ALL_TIME, L.RECRUIT_THIS_MONTH }, PAD, y - 22, 90, function(i)
        period = i == 2 and "month" or "all"
        RefreshBoard()
    end)
    pick(1)
    panel.hideMenu = BuildHideMenu()
    panel.boardRows = {}
    local by = y - 50
    for i = 1, BOARD_ROWS do
        local r = UI.Row(panel, PAD - 4, by - (i - 1) * 17, WIDTH - 2 * PAD + 8, 16)
        r.place = UI.Text(r, "", "GameFontDisableSmall", 4, -2, 24, "RIGHT")
        r.name = UI.Text(r, "", "GameFontHighlightSmall", 32, -2, WIDTH - 2 * PAD - 80)
        r.count = UI.Text(r, "", "GameFontNormalSmall", WIDTH - 2 * PAD - 40, -2, 36, "RIGHT")
        r:RegisterForClicks("LeftButtonUp", "RightButtonUp")
        r:SetScript("OnClick", function(self, button)
            if button == "RightButton" and self.e and ns.Recruit.ICanHide() then panel.hideMenu.Open(self, self.e) end
        end)
        Tip(r, function(self)
            if not self.e then return nil end
            local lines = { string.format(L.RECRUIT_BROUGHT, self.e.name, self.e.n) }
            for _, who in ipairs(self.e.recruits) do lines[#lines + 1] = who end
            if ns.Recruit.ICanHide() then lines[#lines + 1] = ns.GREY .. L.RECRUIT_HIDE_HINT .. "|r" end
            return lines
        end)
        panel.boardRows[i] = r
    end
    panel.boardEmpty = UI.Text(panel, "", "GameFontDisableSmall", PAD, by - 4, WIDTH - 2 * PAD)
    panel.myPlace = UI.Text(panel, "", "GameFontNormalSmall", PAD, by - BOARD_ROWS * 17 - 4, WIDTH - 2 * PAD)

    panel.picker = BuildPicker()

    -- The tab: our handshake in a spellbook-style tab, sticking out of the drawer's right edge so it rides
    -- along as the drawer opens. It belongs to the window, not the holder (the holder clips).
    tab = CreateFrame("Button", nil, frame)
    tab:SetSize(32, 32)
    tab:SetPoint("TOPLEFT", holder, "TOPRIGHT", -1, -14)
    tab:SetFrameLevel(holder:GetFrameLevel())
    local bg = tab:CreateTexture(nil, "BACKGROUND")
    bg:SetTexture("Interface\\SpellBook\\SpellBook-SkillLineTab")
    bg:SetSize(64, 64)
    bg:SetPoint("TOPLEFT", -3, 11)
    tab:SetNormalTexture(ICON)
    tab:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
    tab.bang = tab:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    tab.bang:SetPoint("TOPRIGHT", 6, 6)
    tab.bang:SetText(ns.GOLD .. "!|r")
    tab.bang:Hide()
    tab:SetScript("OnClick", function() UI.ToggleRecruit() end)
    Tip(tab, function()
        local lines = { L.RECRUIT_TITLE, L.RECRUIT_TAB_TIP }
        if ns.Recruit.NeedsAnswer() then lines[#lines + 1] = ns.GOLD .. L.RECRUIT_TAB_ASK .. "|r" end
        return lines
    end)

    UI.recruitHolder, UI.recruitPanel, UI.recruitTab = holder, panel, tab
    RefreshTab()
end
UI.BuildRecruitDrawer = Build
