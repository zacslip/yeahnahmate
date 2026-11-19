-- Clans tab: every clan side by side (Clans.lua), one list each: the clan's name, how many (online),
-- its leader; then its members, online first, each with their role badges on the left and their name
-- in class colour (offline ones grey). Mouse wheel scrolls a list. Hover a name for the usual guildie
-- tooltip.
-- During my clan meeting (ClanMeet.lua) that clan's list is the invite list: green = asked (ready to
-- invite), gold = was in the group before Disband, a tick = in my group; click a name to invite them.
-- Along the bottom, one bar: My roles (icons), then the buttons for the picked clan (my own unless I
-- click another clan's name, which only someone who may run that clan's meetings can do), and
-- Challenge / Withdraw (two clicks) for my own clan.
-- Challenges (ClanChallenge.lua): crossed swords after a challenger's name; the list's title shows how
-- many, hover it for the order. Right-click a name for what I may do: Invite, Whisper, and for the
-- guild master / Clan moderators: Won / Lost on a challenger, give or end second in command.
local ADDON, ns = ...
local L = ns.L
local UI = ns.UI
local Text, Button, Row = UI.Text, UI.Button, UI.Row

local COLS = 5
local COL_W, GAP = 140, 9            -- 5 x 140 + 4 x 9 = 736, the whole page
local COL_H = 372
local ROW_H = 17
local ROWS = 17
local SURE_FOR = 5                   -- seconds a "Sure? Disband" waits for the second click
local LEADER_ICON = "|TInterface\\GroupFrame\\UI-Group-LeaderIcon:12:12|t"
local TICK = "|TInterface\\RaidFrame\\ReadyCheck-Ready:12:12|t"
local SWORDS = "|TInterface\\Icons\\Ability_DualWield:12:12|t"
local DEPUTY_ICON = "|TInterface\\GroupFrame\\UI-Group-AssistantIcon:12:12|t"
local ROLE_NAME = { t = L.ROLE_TANK, h = L.ROLE_HEALER, d = L.ROLE_DPS }
-- Row tints during my meeting.
local TINT = { asked = { 0.2, 0.85, 0.3, 0.30 }, here = { 1, 0.82, 0, 0.22 } }

local thePage

local function Tip(owner, lines)
    if not GameTooltip then return end
    GameTooltip:SetOwner(owner, "ANCHOR_TOP")
    for i, line in ipairs(lines) do
        if i == 1 then GameTooltip:AddLine(line) else GameTooltip:AddLine(line, 1, 1, 1, true) end
    end
    GameTooltip:Show()
end
local function NoTip() if GameTooltip then GameTooltip:Hide() end end

-- The clan the bar's buttons act on.
local function Picked(p)
    local Cl, CM = ns.Clans, ns.ClanMeet
    local mine = Cl.MyRace()
    if p.sel and p.sel ~= mine and not CM.CanRun(ns.me, p.sel) then p.sel = nil end
    return p.sel or mine
end

local function BuildColumn(p, i)
    local x = (i - 1) * (COL_W + GAP)
    local c = UI.Box(p, x, 0, COL_W, COL_H)
    c.offset = 0
    -- My own clan: a gold wash over the whole list and a brighter band behind its name.
    c.wash = c:CreateTexture(nil, "BORDER")
    c.wash:SetPoint("TOPLEFT", 3, -3)
    c.wash:SetPoint("BOTTOMRIGHT", -3, 3)
    c.wash:SetColorTexture(1, 0.82, 0, 0.07)
    c.wash:Hide()
    c.band = c:CreateTexture(nil, "BORDER")
    c.band:SetPoint("TOPLEFT", 3, -3)
    c.band:SetSize(COL_W - 6, 54)
    c.band:SetColorTexture(1, 0.82, 0, 0.18)
    c.band:Hide()
    -- The clan's name: a click picks it for the bar (for those who may run its meetings).
    c.head = CreateFrame("Button", nil, c)
    c.head:SetPoint("TOPLEFT", 4, -4)
    c.head:SetSize(COL_W - 8, 20)
    c.head:SetScript("OnClick", function()
        if c.race and ns.ClanMeet.CanRun(ns.me, c.race) then p.sel = c.race; UI.Dirty() end
    end)
    c.head:SetScript("OnEnter", function(self)
        if c.race and ns.ClanMeet.CanRun(ns.me, c.race) and c.race ~= Picked(p) then Tip(self, { L.CLAN_PICK_TIP }) end
    end)
    c.head:SetScript("OnLeave", NoTip)
    c.title = Text(c, "", "GameFontNormal", 8, -8, COL_W - 16)
    c.chal = CreateFrame("Frame", nil, c)
    c.chal:SetPoint("TOPLEFT", COL_W - 44, -6)
    c.chal:SetSize(40, 18)
    c.chal.text = Text(c.chal, "", "GameFontHighlightSmall", 0, -3, 38, "RIGHT")
    c.chal:EnableMouse(true)
    c.chal:SetScript("OnEnter", function(self)
        if not c.race then return end
        local X = ns.ClanChallenge
        local lines = { string.format(L.CHAL_TIP_HEAD, string.format(L.CLAN_NAME, ns.Clans.RaceName(c.race))) }
        for i, ch in ipairs(X.Open(c.race)) do
            lines[#lines + 1] = string.format(L.CHAL_TIP_ROW, i, ch.owner, UI.DayText(ch.at))
        end
        if #lines == 1 then lines[#lines + 1] = L.CHAL_TIP_NONE end
        local recent = X.Recent(c.race)
        if #recent > 0 then
            lines[#lines + 1] = " "
            lines[#lines + 1] = ns.GOLD .. L.CHAL_TIP_RECENT .. "|r"
            for i = 1, math.min(5, #recent) do
                local ch = recent[i]
                lines[#lines + 1] = string.format(ch.st == "won" and L.CHAL_TIP_WON or L.CHAL_TIP_LOST, ch.owner, UI.DayText(ch.ev))
            end
        end
        Tip(self, lines)
    end)
    c.chal:SetScript("OnLeave", NoTip)
    c.count = Text(c, "", "GameFontDisableSmall", 8, -26, COL_W - 16)
    c.leader = Text(c, "", "GameFontHighlightSmall", 8, -41, COL_W - 16)
    local line = c:CreateTexture(nil, "ARTWORK")
    line:SetColorTexture(0.9, 0.76, 0.36, 0.5)
    line:SetPoint("TOPLEFT", 6, -57)
    line:SetSize(COL_W - 12, 1)
    c.rows = {}
    local function Wheel(_, d)
        c.offset = math.max(0, c.offset - d * 3)
        UI.Dirty()
    end
    c:EnableMouseWheel(true)
    c:SetScript("OnMouseWheel", Wheel)
    for j = 1, ROWS do
        local r = Row(c, 4, -61 - (j - 1) * ROW_H, COL_W - 8, ROW_H - 1)
        r.tint = r:CreateTexture(nil, "BORDER")
        r.tint:SetAllPoints()
        r.tint:Hide()
        r.roles = Text(r, "", "GameFontHighlightSmall", 2, -1, 32)
        r.name = Text(r, "", "GameFontHighlightSmall", 34, -2, COL_W - 44)
        r:SetScript("OnEnter", function(self)
            self.hl:Show()
            if self.m then
                UI.MemberTooltip(self, self.m)
                if self.meet and GameTooltip then
                    local extra = self.meet.state == "asked" and (self.meet.how == "w" and L.CLAN_ROW_ASKED_W or L.CLAN_ROW_ASKED_B)
                        or self.meet.state == "here" and L.CLAN_ROW_HERE
                        or self.meet.state == "ingroup" and L.CLAN_ROW_INGROUP or nil
                    if extra then GameTooltip:AddLine(extra, 0.3, 1, 0.4) end
                    if self.meet.other then
                        GameTooltip:AddLine(string.format(L.CLAN_ROW_OTHER,
                            string.format(L.CLAN_NAME, ns.Clans.RaceName(ns.Clans.Race(self.m.name)))), 1, 0.6, 0.2)
                    end
                    if ns.ClanMeet.Invitable(self.meet.state) then GameTooltip:AddLine(L.CLAN_ROW_INVITE, 0.3, 1, 0.4) end
                    GameTooltip:Show()
                end
            end
        end)
        r:SetScript("OnLeave", function(self)
            self.hl:Hide()
            NoTip()
        end)
        r:RegisterForClicks("LeftButtonUp", "RightButtonUp")
        r:SetScript("OnClick", function(self, button)
            if button == "RightButton" then
                if self.m then p.OpenMenu(self, self.m) end
                return
            end
            if self.meet and ns.ClanMeet.Invitable(self.meet.state) then ns.ClanMeet.Invite(self.m.name) end
        end)
        r:EnableMouseWheel(true)
        r:SetScript("OnMouseWheel", Wheel)
        c.rows[j] = r
    end
    c.empty = Text(c, L.CLAN_EMPTY, "GameFontDisableSmall", 8, -64, COL_W - 16)
    c.empty:SetWordWrap(true)
    c.empty:SetHeight(42)
    c.empty:SetJustifyV("TOP")
    c.shown = Text(c, "", "GameFontDisableSmall", 8, -61 - ROWS * ROW_H - 2, COL_W - 16, "RIGHT")
    return c
end

local function BuildBar(p)
    local y = -COL_H - 8
    Text(p, ns.GOLD .. L.CLAN_MY_ROLES .. "|r", "GameFontNormalSmall", 4, y - 6, 60)
    p.roleBtns = {}
    for i, r in ipairs(ns.Clans.ROLES) do
        local b = Button(p, UI.ROLE_ICON[r], 30, 62 + (i - 1) * 32, y, function() ns.Clans.ToggleRole(r) end, 24)
        b.sel = b:CreateTexture(nil, "OVERLAY")
        b.sel:SetColorTexture(1, 0.82, 0, 1)
        b.sel:SetPoint("BOTTOMLEFT", 4, 2)
        b.sel:SetPoint("BOTTOMRIGHT", -4, 2)
        b.sel:SetHeight(2)
        b.sel:Hide()
        b:SetScript("OnEnter", function(self) Tip(self, { ROLE_NAME[r], string.format(L.CLAN_ROLE_TIP, ROLE_NAME[r]) .. "\n" .. L.CLAN_ROLES_TIP }) end)
        b:SetScript("OnLeave", NoTip)
        p.roleBtns[r] = b
    end
    local line = p:CreateTexture(nil, "ARTWORK")
    line:SetColorTexture(0.9, 0.76, 0.36, 0.5)
    line:SetPoint("TOPLEFT", 164, y - 2)
    line:SetSize(1, 20)

    local CM = ns.ClanMeet
    p.bar = {
        start = Button(p, "", 170, 0, y, function() CM.Start(Picked(p)) end, 24),
        next = Button(p, L.CLAN_INVITE_NEXT, 100, 0, y, function() CM.InviteNext() end, 24),
        raid = Button(p, L.MAKE_RAID, 110, 0, y, function() ns.Gather.MakeRaid() end, 24),
        disband = Button(p, L.CLAN_DISBAND, 104, 0, y, function()
            if p.sureAt and GetTime() - p.sureAt < SURE_FOR then
                p.sureAt = nil
                CM.Disband()
            else
                p.sureAt = GetTime()
                C_Timer.After(SURE_FOR + 0.1, UI.Dirty)
            end
            UI.Dirty()
        end, 24),
        stop = Button(p, L.CLAN_STOP, 60, 0, y, function() CM.Stop() end, 24),
        ask = Button(p, L.CLAN_ASK, 130, 0, y, function() CM.AskInvite(ns.Clans.MyRace()) end, 24),
        challenge = Button(p, SWORDS .. " " .. L.CHAL_BTN, 104, 0, y, function() ns.ClanChallenge.Challenge() end, 24),
        withdraw = Button(p, L.CHAL_WITHDRAW, 120, 0, y, function()
            if p.wdAt and GetTime() - p.wdAt < SURE_FOR then
                p.wdAt = nil
                ns.ClanChallenge.Withdraw()
            else
                p.wdAt = GetTime()
                C_Timer.After(SURE_FOR + 0.1, UI.Dirty)
            end
            UI.Dirty()
        end, 24),
    }
    p.bar.challenge:SetScript("OnEnter", function(self) Tip(self, { L.CHAL_BTN, L.CHAL_BTN_TIP }) end)
    p.bar.challenge:SetScript("OnLeave", NoTip)
    local widths = { start = 170, next = 100, raid = 110, disband = 104, stop = 60, ask = 130, challenge = 104, withdraw = 120 }
    for k, btn in pairs(p.bar) do btn._barW = widths[k] end
    p.barHint = Text(p, "", "GameFontDisableSmall", 0, y - 6, 300)
    p.barY = y
end

-- Right-click on a name: what I may do with them.
local function BuildMenu(p)
    p.menu = UI.PickMenu(p, 200, 6)
    function p.OpenMenu(anchor, m)
        local X, CM = ns.ClanChallenge, ns.ClanMeet
        local items, acts = {}, {}
        local function Add(label, fn) items[#items + 1] = label; acts[#acts + 1] = fn end
        if m.name ~= ns.me and m.online then
            Add(L.INVITE, function() if CM.Mine() then CM.Invite(m.name) else UI.Invite(m) end end)
            Add(L.CLAN_MENU_WHISPER, function() ns.Whisper.Open(m) end)
        end
        local race = ns.Clans.Race(m.name)
        local ch = race and X.OpenOf(m.name, race)
        if ch and X.CanSettle(ns.me) then
            Add(ns.GREEN .. L.CHAL_MENU_WON .. "|r", function() X.Settle(ch.owner, ch.id, "won") end)
            Add("|cffff6060" .. L.CHAL_MENU_LOST .. "|r", function() X.Settle(ch.owner, ch.id, "lost") end)
        end
        if race and m.name ~= ns.me and X.CanSettle(ns.me) and not ns.Clans.IsLeader(m.name, race) then
            if ns.Clans.IsDeputy(m.name, race) then
                Add(L.DEP_MENU_END, function() X.SetDeputy(m.name, false) end)
            elseif m.online then
                Add(string.format(L.DEP_MENU_GIVE, X.DEPUTY_FOR / 60), function() X.SetDeputy(m.name, true) end)
            end
        end
        if #items == 0 then return end
        p.menu.Open(anchor, items, function(i) acts[i](); UI.Dirty() end)
    end
end

local function Build(p)
    thePage = p
    p.cols = {}
    for i = 1, COLS do p.cols[i] = BuildColumn(p, i) end
    BuildBar(p)
    BuildMenu(p)
end

local function RefreshColumn(p, c, info, picked)
    local Cl, CM = ns.Clans, ns.ClanMeet
    c:SetShown(info ~= nil)
    if not info then return end
    local race = info.race
    c.race = race
    local mineClan = race == Cl.MyRace()
    c.title:SetText(string.format(L.CLAN_NAME, Cl.RaceName(race)) .. (mineClan and (ns.GREY .. "  " .. L.CLAN_YOU .. "|r") or ""))
    local meeting = CM.Mine()
    local myMeeting = meeting and meeting.race == race
    local active = CM.ActiveFor(race)
    if myMeeting then
        c.count:SetText(ns.GREEN .. string.format(L.CLAN_MEETING_MINE, CM.Counts()) .. "|r")
    elseif active then
        c.count:SetText(ns.GREEN .. string.format(L.CLAN_MEETING_ON, active.organiser:match("^%S+") or active.organiser) .. "|r")
    else
        c.count:SetText(string.format(L.CLAN_COUNT, info.n, info.online))
    end
    local leaders = info.leaders or {}
    if #leaders == 0 then
        c.leader:SetText(ns.GREY .. L.CLAN_NO_LEADER .. "|r")
    else
        local m = ns.Guild.Get(leaders[1])
        local name = m and UI.Name(m, true) or leaders[1]
        c.leader:SetText(LEADER_ICON .. " " .. name .. (#leaders > 1 and (ns.GREY .. " +" .. (#leaders - 1) .. "|r") or ""))
    end
    local open = ns.ClanChallenge.Open(race)
    local challengers = {}
    for _, ch in ipairs(open) do challengers[ch.owner] = true end
    c.chal.text:SetText(#open > 0 and (SWORDS .. " " .. #open) or "")
    c.chal:SetShown(#open > 0 or #ns.ClanChallenge.Recent(race) > 0)
    if #open == 0 and c.chal:IsShown() then c.chal.text:SetText(ns.GREY .. SWORDS .. "|r") end
    local deputy = ns.ClanChallenge.Deputy(race)
    c.wash:SetShown(mineClan)
    c.band:SetShown(mineClan)
    if c.SetBackdropBorderColor then
        if mineClan then c:SetBackdropBorderColor(1, 0.82, 0, 1)
        elseif race == picked then c:SetBackdropBorderColor(0.9, 0.9, 0.9, 1)
        else c:SetBackdropBorderColor(0.55, 0.55, 0.55, 0.9) end
    end

    -- My meeting: the invite list. Otherwise the members.
    local rows = {}
    if myMeeting then
        rows = CM.List()
    else
        for _, m in ipairs(Cl.Members(race)) do rows[#rows + 1] = { m = m } end
    end
    local off = math.min(c.offset, math.max(0, #rows - ROWS))
    c.offset = off
    c.empty:SetShown(#rows == 0)
    for j, r in ipairs(c.rows) do
        local row = rows[off + j]
        r.m = row and row.m
        r.meet = myMeeting and row or nil
        if row then
            local m = row.m
            r.roles:SetText(UI.RoleIcons(Cl.Roles(m.name)))
            local name = UI.Name(m, true)
            if r.meet and row.state == "ingroup" then name = TICK .. " " .. ns.GREY .. m.name .. "|r" end
            if r.meet and row.other then name = name .. ns.GREY .. " *|r" end
            if deputy and deputy.who == m.name then name = name .. " " .. DEPUTY_ICON end
            if challengers[m.name] then name = name .. " " .. SWORDS end
            r.name:SetText(name)
            local tint = r.meet and TINT[row.state]
            r.tint:SetShown(tint ~= nil)
            if tint then r.tint:SetColorTexture(tint[1], tint[2], tint[3], tint[4]) end
            r.stripe:SetColorTexture(1, 1, 1, (m.name == ns.me) and 0.1 or ((j % 2 == 0) and 0.04 or 0))
            r:Show()
        else
            r:Hide()
        end
    end
    c.shown:SetText(#rows > ROWS and string.format(L.SHOWN, off + 1, math.min(#rows, off + ROWS), #rows) or "")
end

-- The bar's buttons, left to right after the roles: what I can do for the picked clan.
local function RefreshBar(p, picked)
    local Cl, CM = ns.Clans, ns.ClanMeet
    local b = p.bar
    for _, btn in pairs(b) do btn:Hide() end
    local show = {}
    local meeting = CM.Mine()
    if meeting and meeting.race == picked then
        b.next:SetEnabled(CM.Next() ~= nil)
        show = { b.next }
        if ns.Gather.CanMakeRaid() then show[#show + 1] = b.raid end
        local sure = p.sureAt and GetTime() - p.sureAt < SURE_FOR
        b.disband:SetText(sure and ("|cffff6060" .. L.CLAN_DISBAND_SURE .. "|r") or L.CLAN_DISBAND)
        b.disband:SetEnabled(CM.CanDisband())
        show[#show + 1] = b.disband
        show[#show + 1] = b.stop
    elseif CM.CanRun(ns.me, picked) then
        b.start:SetText(L.CLAN_START .. ": " .. Cl.RaceName(picked))
        show = { b.start }
    end
    local myRace = Cl.MyRace()
    local active = CM.ActiveFor(myRace)
    if active and active.organiser ~= ns.me then
        local asked = CM.HaveAsked(myRace)
        b.ask:SetText(asked and (TICK .. " " .. L.CLAN_ASKED) or L.CLAN_ASK)
        b.ask:SetEnabled(not asked)
        show[#show + 1] = b.ask
    end
    local X = ns.ClanChallenge
    if myRace and X.OpenOf(ns.me, myRace) then
        local sure = p.wdAt and GetTime() - p.wdAt < SURE_FOR
        b.withdraw:SetText(sure and ("|cffff6060" .. L.CHAL_WITHDRAW_SURE .. "|r") or L.CHAL_WITHDRAW)
        show[#show + 1] = b.withdraw
    elseif X.CanChallenge() then
        show[#show + 1] = b.challenge
    end
    local x = 172
    for _, btn in ipairs(show) do
        btn:ClearAllPoints()
        btn:SetPoint("TOPLEFT", x, p.barY)
        btn:Show()
        x = x + btn._barW + 4
    end
    p.barHint:SetText((meeting and meeting.race == picked) and L.CLAN_BAR_HINT or "")
    p.barHint:ClearAllPoints()
    p.barHint:SetPoint("TOPLEFT", x + 6, p.barY - 6)
    p.barHint:SetWidth(math.max(40, 736 - x - 6))
end

local function Refresh(p)
    local Cl = ns.Clans
    local list = Cl.List()
    local picked = Picked(p)
    for i, c in ipairs(p.cols) do RefreshColumn(p, c, list[i], picked) end

    local roles = Cl.MyRoles()
    for _, r in ipairs(Cl.ROLES) do
        local on = roles:find(r, 1, true) ~= nil
        local b = p.roleBtns[r]
        b.sel:SetShown(on)
        if on then b:LockHighlight() else b:UnlockHighlight() end
    end
    RefreshBar(p, picked)
end

UI.AddPage("clans", Build, Refresh)

ns.Listen("CLANS", UI.Dirty)
ns.Listen("CLANMEET", UI.Dirty)
ns.Listen("BOARD", UI.Dirty)
ns.Listen("STATUS", UI.Dirty)

-- Pop-ups: my clan's meeting started (Ask for an invite from the pop-up); someone asked me.
ns.Listen("CLANMEET_STARTED", function(race, organiser)
    if race ~= ns.Clans.MyRace() then return end
    ns.Toast.nextTab = "clans"
    ns.Toast.Show(string.format(L.TOAST_CLANMEET, organiser:match("^%S+") or organiser,
        string.format(L.CLAN_NAME, ns.Clans.RaceName(race))), L.TOAST_CLANMEET_TEXT, "gather",
        { L.ASK_SHORT, function() ns.ClanMeet.AskInvite(race) end })
end)
ns.Listen("CLANMEET_ASKED", function(name)
    if thePage and thePage:IsShown() then return end         -- the list shows it already
    ns.Toast.nextTab = "clans"
    ns.Toast.Show(string.format(L.TOAST_CLANMEET_ASKED, name:match("^%S+") or name), "", "gather")
end)

-- A challenge in a clan I lead (or every clan, for those who settle them); second in command for me.
ns.Listen("CLAN_CHALLENGE", function(c)
    if not (ns.Clans.IsLeader(ns.me, c.r) or ns.ClanChallenge.CanSettle(ns.me)) or c.owner == ns.me then return end
    ns.Toast.nextTab = "clans"
    ns.Toast.Show(string.format(L.TOAST_CHALLENGE, c.owner:match("^%S+") or c.owner,
        string.format(L.CLAN_NAME, ns.Clans.RaceName(c.r))), L.TOAST_CHALLENGE_TEXT, nil)
end)
ns.Listen("CLAN_DEPUTY", function(race, by)
    ns.Toast.nextTab = "clans"
    ns.Toast.Show(string.format(L.TOAST_DEPUTY, string.format(L.CLAN_NAME, ns.Clans.RaceName(race))),
        string.format(L.TOAST_DEPUTY_TEXT, by:match("^%S+") or by, ns.ClanChallenge.DEPUTY_FOR / 60), nil)
end)
