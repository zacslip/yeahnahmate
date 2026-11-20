-- The recruiting drawer (Phase 13; data in Recruit.lua): two tabs on the main window's RIGHT edge, up by
-- the version number, in the style of our tab on the game's guild window (UI/GuildButton.lua):
--   top:    Guild recruiting (the guild crest). A blank page for now; filled in after the addon page.
--   below:  Addon recruiting (the handshake). A gold "!" on it until I've said who got me onto the addon.
-- Clicking a tab slides a panel out to the right, from under the window, like the voice drawer does on the
-- left (UI/Voice.lua), on that tab's page; clicking the open tab again slides it shut.
--
-- Addon recruiting: who got me onto it (the question until answered, then a short note), the guildies
-- online without the addon (Share), and the leaderboard (All time / This month). Everything under the
-- top part moves up once I've answered, so there's no gap. The guild master and managers right-click a
-- leaderboard row to take a wrong claim off it.
local ADDON, ns = ...
local L = ns.L
local UI = ns.UI

local WIDTH = 280
local SPEED = WIDTH / 0.18      -- open or shut in about a fifth of a second
local TUCK = 3                  -- tucks under the window's border
local TOP = -26                 -- level with the top of the banner
local PANEL_H = 514             -- the window's 552, less TOP and the bottom gap (12)
local PAD = 14
local HANDSHAKE = "Interface\\Icons\\Achievement_Reputation_01"     -- picked in game, 21 Nov
local SHARE_ROWS, BOARD_MAX, PICK_ROWS = 6, 10, 14
local ROW_H = 17
local BODY_ANSWERED, BODY_ASKING = -82, -150   -- where Share starts: under my note, or under the question

local holder, panel, tabs
local open = false              -- starts shut each login
local page = "addon"            -- "addon" or "guild"
local period = "all"
local shareOffset, pickOffset = 0, 0

local function Backdrop(f, edge, alpha)
    if not f.SetBackdrop then return end
    f:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        edgeSize = edge, insets = { left = 3, right = 3, top = 3, bottom = 3 },
    })
    -- Solid, so the game's quest list or anything else behind doesn't show through.
    f:SetBackdropColor(0.05, 0.05, 0.06, alpha or 1)
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

local function Wrapped(parent, text, font, x, y, w, h)
    local fs = UI.Text(parent, text, font, x, y, w)
    fs:SetWordWrap(true)
    fs:SetHeight(h)
    fs:SetJustifyV("TOP")
    return fs
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

local function ShowPage()
    panel.addon:SetShown(page == "addon")
    panel.guild:SetShown(page == "guild")
    -- The open page's tab glows (as on hover). A "checked" overlay washed the icon out to blank.
    for key, t in pairs(tabs) do
        t.sel = open and key == page
        if t.sel then t:LockHighlight() else t:UnlockHighlight() end
    end
end

-- Open or shut the drawer. which = "addon" / "guild" picks the page (and a click on the page already
-- open shuts it); state = true / false forces it.
function UI.ToggleRecruit(state, which)
    if not holder then return end
    if which and which ~= page then
        page, open = which, true
    elseif state == nil then
        open = not open
    else
        open = state and true or false
    end
    holder:SetScript("OnUpdate", Step)
    ShowPage()
    if open then UI.RecruitRefresh() end
end

function UI.RecruitOpen() return open end
function UI.RecruitPage() return page end

---------------------------------------------------------------------------------------------------
-- Refresh (the addon page)

local function RefreshTabs()
    if not tabs then return end
    tabs.addon.bang:SetShown(ns.Recruit.NeedsAnswer())
end

local function RefreshMine()
    local R = ns.Recruit
    local p = panel.addon
    local c = R.MyClaim()
    p.question:SetShown(c == nil)
    p.answer:SetShown(c ~= nil)
    p.body.top = c and BODY_ANSWERED or BODY_ASKING
    p.body:ClearAllPoints()
    p.body:SetPoint("TOPLEFT", 0, p.body.top)
    p.body:SetPoint("RIGHT")
    p.body:SetHeight(PANEL_H + (c and BODY_ANSWERED or BODY_ASKING))
    if c then
        if c.by == "" then p.answer:SetText(L.RECRUIT_SKIPPED)
        else p.answer:SetText(string.format(L.RECRUIT_YOU_SAID, Coloured(c.by))) end
        return
    end
    local q = p.question
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
    local p = panel.addon
    local list = ns.Recruit.Candidates()
    local maxOff = math.max(0, #list - SHARE_ROWS)
    if shareOffset > maxOff then shareOffset = maxOff end
    for i, r in ipairs(p.shareRows) do
        local c = list[i + shareOffset]
        r.c = c
        r:SetShown(c ~= nil)
        if c then
            r.name:SetText(Coloured(c.name) .. ns.GREY .. "  " .. (c.level or "") .. "|r")
            r.share:SetEnabled(ns.Recruit.CanShareTo(c.name))
            r.share:SetText(c.shared and L.RECRUIT_SHARED or L.RECRUIT_SHARE)
        end
    end
    p.shareEmpty:SetShown(#list == 0)
    p.shareMore:SetText(#list > SHARE_ROWS and string.format(L.RECRUIT_MORE, shareOffset + 1,
        math.min(#list, shareOffset + SHARE_ROWS), #list) or "")
end

-- How many leaderboard rows fit under the body's top (fewer while the question shows).
local function BoardRowsThatFit()
    local p = panel.addon
    local top = (ns.Recruit.MyClaim() and BODY_ANSWERED or BODY_ASKING) + p.boardTop
    return math.max(3, math.min(BOARD_MAX, math.floor((PANEL_H + top - 26) / ROW_H)))
end

local function RefreshBoard()
    local p = panel and panel.addon
    if not p or not p.boardRows then return end     -- still being built
    local R = ns.Recruit
    local list = R.Leaderboard(period)
    local me = ns.Alts.Person(ns.me)
    local fit = BoardRowsThatFit()
    for i, r in ipairs(p.boardRows) do
        local e = i <= fit and list[i] or nil
        r.e = e
        r:SetShown(e ~= nil)
        if e then
            r.place:SetText(i .. ".")
            r.name:SetText(e.name == me and (ns.GOLD .. Short(e.name) .. "|r") or Coloured(e.name))
            r.count:SetText(tostring(e.n))
        end
    end
    p.boardEmpty:SetShown(#list == 0)
    p.boardEmpty:SetText(period == "month" and L.RECRUIT_BOARD_EMPTY_MONTH or L.RECRUIT_BOARD_EMPTY)
    p.myPlace:ClearAllPoints()
    p.myPlace:SetPoint("TOPLEFT", PAD, p.boardTop - 50 - math.min(fit, math.max(#list, 1)) * ROW_H - 4)
    local place, n = R.MyPlace(period)
    if place and place > fit then p.myPlace:SetText(string.format(L.RECRUIT_MY_PLACE, place, n))
    elseif not place and #list > 0 then p.myPlace:SetText(L.RECRUIT_NOT_YET)
    else p.myPlace:SetText("") end
end

local function RefreshPick()
    local pk = panel.addon.picker
    if not pk:IsShown() then return end
    local names = {}
    for name in pairs(ns.Comm.users) do
        if ns.Recruit.CanBeRecruiter(name) then names[#names + 1] = name end
    end
    table.sort(names)
    local maxOff = math.max(0, #names - PICK_ROWS)
    if pickOffset > maxOff then pickOffset = maxOff end
    for i, r in ipairs(pk.rows) do
        local n = names[i + pickOffset]
        r.who = n
        r:SetShown(n ~= nil)
        if n then r.text:SetText(Coloured(n)) end
    end
    pk.empty:SetShown(#names == 0)
end

function UI.RecruitRefresh()
    RefreshTabs()
    if not panel or not open or page ~= "addon" then return end
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
        panel.addon.picker:Hide()
        UI.RecruitRefresh()
    end
end

local function PageHead(p, icon, title, sub)
    local t = p:CreateTexture(nil, "ARTWORK")
    t:SetTexture(icon)
    t:SetSize(24, 24)
    t:SetPoint("TOPLEFT", PAD, -12)
    p.title = UI.Text(p, title, "GameFontNormal", PAD + 30, -12)
    p.sub = UI.Text(p, sub, "GameFontDisableSmall", PAD + 30, -28, WIDTH - PAD * 2 - 30)
    return t
end

local function BuildQuestion(p)
    local q = CreateFrame("Frame", nil, p)
    q:SetPoint("TOPLEFT", 0, -50)
    q:SetSize(WIDTH, 96)
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
        p.picker:Show()
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

local function BuildPicker(p)
    local pk = CreateFrame("Frame", nil, p, BackdropTemplateMixin and "BackdropTemplate" or nil)
    pk:SetPoint("TOPLEFT", 6, -46)
    pk:SetPoint("BOTTOMRIGHT", -6, 6)
    pk:SetFrameLevel(p:GetFrameLevel() + 10)
    Backdrop(pk, 12)
    pk:EnableMouse(true)
    UI.Text(pk, ns.GOLD .. L.RECRUIT_PICK_TITLE .. "|r", "GameFontNormalSmall", 10, -10, WIDTH - 110)
    UI.Button(pk, L.CANCEL, 70, WIDTH - 12 - 82, -6, function() pk:Hide() end, 20)
    pk.rows = {}
    for i = 1, PICK_ROWS do
        local r = UI.Row(pk, 8, -34 - (i - 1) * 20, WIDTH - 28, 19)
        r.text = UI.Text(r, "", "GameFontHighlightSmall", 6, -3, WIDTH - 44)
        r:SetScript("OnClick", function(self) if self.who then Answer(self.who) end end)
        pk.rows[i] = r
    end
    pk.empty = UI.Text(pk, L.RECRUIT_PICK_EMPTY, "GameFontDisableSmall", 10, -36, WIDTH - 40)
    pk:EnableMouseWheel(true)
    pk:SetScript("OnMouseWheel", function(_, d) pickOffset = math.max(0, pickOffset - d * 3); RefreshPick() end)
    pk:Hide()
    return pk
end

-- Managers: right-click a leaderboard row to take one of that recruiter's claims off.
local function BuildHideMenu(p)
    local m = CreateFrame("Frame", nil, p, BackdropTemplateMixin and "BackdropTemplate" or nil)
    m:SetSize(WIDTH - 40, 40)
    m:SetFrameLevel(p:GetFrameLevel() + 12)
    Backdrop(m, 12)
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

-- Share and the leaderboard live in the body, which moves up once I've answered.
local function BuildBody(p)
    local b = CreateFrame("Frame", nil, p)
    b:SetPoint("TOPLEFT", 0, BODY_ASKING)
    b:SetPoint("RIGHT")
    b:SetHeight(PANEL_H + BODY_ASKING)
    p.body = b

    UI.Header(b, L.RECRUIT_SHARE_HEAD, PAD, 0, WIDTH - 2 * PAD)
    Wrapped(b, L.RECRUIT_SHARE_HINT, "GameFontDisableSmall", PAD, -20, WIDTH - 2 * PAD, 24)
    p.shareRows = {}
    for i = 1, SHARE_ROWS do
        local r = UI.Row(b, PAD - 4, -46 - (i - 1) * 21, WIDTH - 2 * PAD + 8, 20)
        r.name = UI.Text(r, "", "GameFontHighlightSmall", 6, -4, WIDTH - 2 * PAD - 80)
        r.share = UI.Button(r, L.RECRUIT_SHARE, 66, WIDTH - 2 * PAD - 66, -1, function()
            if r.c and ns.Recruit.Share(r.c.name) then UI.RecruitRefresh() end
        end, 18)
        Tip(r.share, { L.RECRUIT_SHARE, L.RECRUIT_SHARE_TIP })
        r:EnableMouseWheel(true)
        r:SetScript("OnMouseWheel", function(_, d) shareOffset = math.max(0, shareOffset - d); RefreshShare() end)
        p.shareRows[i] = r
    end
    p.shareEmpty = UI.Text(b, L.RECRUIT_SHARE_EMPTY, "GameFontDisableSmall", PAD, -50, WIDTH - 2 * PAD)
    p.shareMore = UI.Text(b, "", "GameFontDisableSmall", PAD, -48 - SHARE_ROWS * 21, WIDTH - 2 * PAD, "RIGHT")

    -- The leaderboard
    local y = -48 - SHARE_ROWS * 21 - 16
    p.boardTop = y
    UI.Header(b, L.RECRUIT_BOARD_HEAD, PAD, y, WIDTH - 2 * PAD)
    local pick = UI.Choice(b, { L.RECRUIT_ALL_TIME, L.RECRUIT_THIS_MONTH }, PAD, y - 22, 90, function(i)
        period = i == 2 and "month" or "all"
        RefreshBoard()
    end)
    pick(1)
    p.hideMenu = BuildHideMenu(p)
    p.boardRows = {}
    for i = 1, BOARD_MAX do
        local r = UI.Row(b, PAD - 4, y - 50 - (i - 1) * ROW_H, WIDTH - 2 * PAD + 8, ROW_H - 1)
        r.place = UI.Text(r, "", "GameFontDisableSmall", 4, -2, 24, "RIGHT")
        r.name = UI.Text(r, "", "GameFontHighlightSmall", 32, -2, WIDTH - 2 * PAD - 80)
        r.count = UI.Text(r, "", "GameFontNormalSmall", WIDTH - 2 * PAD - 40, -2, 36, "RIGHT")
        r:RegisterForClicks("LeftButtonUp", "RightButtonUp")
        r:SetScript("OnClick", function(self, button)
            if button == "RightButton" and self.e and ns.Recruit.ICanHide() then p.hideMenu.Open(self, self.e) end
        end)
        Tip(r, function(self)
            if not self.e then return nil end
            local lines = { string.format(L.RECRUIT_BROUGHT, self.e.name, self.e.n) }
            for _, who in ipairs(self.e.recruits) do lines[#lines + 1] = who end
            if ns.Recruit.ICanHide() then lines[#lines + 1] = ns.GREY .. L.RECRUIT_HIDE_HINT .. "|r" end
            return lines
        end)
        p.boardRows[i] = r
    end
    p.boardEmpty = UI.Text(b, "", "GameFontDisableSmall", PAD, y - 54, WIDTH - 2 * PAD)
    p.myPlace = UI.Text(b, "", "GameFontNormalSmall", PAD, y - 50 - ROW_H - 4, WIDTH - 2 * PAD)
end

local function BuildAddonPage()
    local p = CreateFrame("Frame", nil, panel)
    p:SetAllPoints()
    PageHead(p, HANDSHAKE, L.RECRUIT_TITLE, L.RECRUIT_SUB)
    -- Answered: a short note in the space the question takes (two lines at most).
    p.answer = Wrapped(p, "", "GameFontHighlightSmall", PAD, -50, WIDTH - 2 * PAD, 28)
    p.question = BuildQuestion(p)
    BuildBody(p)
    p.picker = BuildPicker(p)
    return p
end

-- Guild recruiting: blank for now (to be filled in after the addon page is settled).
local function BuildGuildPage()
    local p = CreateFrame("Frame", nil, panel)
    p:SetAllPoints()
    PageHead(p, UI.CREST, L.GUILDREC_TITLE, L.GUILDREC_SUB)
    p:Hide()
    return p
end

local function MakeTab(frame, key, icon, y, tip)
    local t = CreateFrame("Button", nil, frame)
    t:SetSize(32, 32)
    t:SetPoint("TOPLEFT", holder, "TOPRIGHT", -1, y)
    t:SetFrameLevel(holder:GetFrameLevel())
    local bg = t:CreateTexture(nil, "BACKGROUND")
    bg:SetTexture("Interface\\SpellBook\\SpellBook-SkillLineTab")
    bg:SetSize(64, 64)
    bg:SetPoint("TOPLEFT", -3, 11)
    t:SetNormalTexture(icon)
    t:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
    t:SetScript("OnClick", function() UI.ToggleRecruit(nil, key) end)
    Tip(t, tip)
    return t
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
    panel.addon = BuildAddonPage()
    panel.guild = BuildGuildPage()

    -- The tabs ride along the drawer's right edge. They belong to the window, not the holder (it clips).
    tabs = {}
    tabs.guild = MakeTab(frame, "guild", UI.CREST, -14, { L.GUILDREC_TITLE, L.GUILDREC_TAB_TIP })
    tabs.addon = MakeTab(frame, "addon", HANDSHAKE, -14 - 49, function()
        local lines = { L.RECRUIT_TITLE, L.RECRUIT_TAB_TIP }
        if ns.Recruit.NeedsAnswer() then lines[#lines + 1] = ns.GOLD .. L.RECRUIT_TAB_ASK .. "|r" end
        return lines
    end)
    tabs.addon.bang = tabs.addon:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    tabs.addon.bang:SetPoint("TOPRIGHT", 6, 6)
    tabs.addon.bang:SetText(ns.GOLD .. "!|r")
    tabs.addon.bang:Hide()

    UI.recruitHolder, UI.recruitPanel, UI.recruitTabs = holder, panel, tabs
    UI.recruitTab = tabs.addon
    ShowPage()
    RefreshTabs()
end
UI.BuildRecruitDrawer = Build
