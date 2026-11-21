-- Dungeons tab, in the Ask tab's layout. The sidebar is four cards, in two parts with a
-- line between: what I'm putting up (am I available; my posted group) and what's out there (open
-- groups; available guildies). Each card says how things stand; a click opens its page on the right:
-- Make me available, Post a group or Your group with its applicants, or the list of groups or
-- guildies. Forms are two columns: the dungeon list on the left.
local ADDON, ns = ...
local L = ns.L
local UI = ns.UI
local Text, Button, Box, Header, Row = UI.Text, UI.Button, UI.Box, UI.Header, UI.Row

local RX, RW = UI.RX, UI.RW
local RIGHT_W = 246             -- a form's left column (the dungeon list)
local CX = 270                  -- a form's right column
local CW = RW - CX
local FORM_ROWS = 14
local CARDS = 4
local AVAIL_CARDS = 4
local AVAIL_SHOWN = 6            -- dungeon names on a card before "+N more" (hover for all)
local DROWS = 8
local ROLE_ICON = {
    t = "|TInterface\\Icons\\INV_Shield_06:14|t",
    h = "|TInterface\\Icons\\Spell_Holy_Heal:14|t",
    d = "|TInterface\\Icons\\INV_Sword_04:14|t",
}
local ROLE_NAME = { t = L.ROLE_TANK, h = L.ROLE_HEALER, d = L.ROLE_DPS }
local ORANGE = "|cffff8040"

local function Duration(secs)
    local mins = math.max(0, math.floor(secs / 60))
    if mins >= 60 then return math.floor(mins / 60) .. "h " .. (mins % 60) .. "m" end
    return mins .. "m"
end

local function FirstName(name) return name:match("^%S+") or name end

local function MemberLine(name)
    local m = ns.Guild.Get(name)
    if not m then return name end
    return UI.Name(m) .. " " .. ns.GREY .. m.level .. "|r"
end

-- A list of dungeon rows with tick boxes, scrolled with the mouse wheel. single = only one ticked.
local function DungeonRows(p, parent, y, single, picked, count)
    count = count or DROWS
    local rows = { offset = nil, picked = picked }   -- nil: first look scrolls to my level
    for i = 1, count do
        local r = Row(parent, 0, y - (i - 1) * 22, RIGHT_W, 21)
        r.check = CreateFrame("CheckButton", nil, r, "UICheckButtonTemplate")
        r.check:SetSize(20, 20)
        r.check:SetPoint("LEFT", 2, 0)
        r.name = Text(r, "", "GameFontHighlightSmall", 26, -5, 160)
        r.range = Text(r, "", "GameFontDisableSmall", 186, -5, 56, "RIGHT")
        r.check:SetScript("OnClick", function(self)
            if not r.key then return end
            if single then wipe(rows.picked) end
            rows.picked[r.key] = self:GetChecked() and true or nil
            UI.Dirty()
        end)
        r:SetScript("OnClick", function() r.check:Click() end)
        rows[i] = r
    end
    local wheel = CreateFrame("Frame", nil, parent)
    wheel:SetPoint("TOPLEFT", 0, y)
    wheel:SetSize(RIGHT_W, count * 22)
    wheel:EnableMouseWheel(true)
    wheel:SetScript("OnMouseWheel", function(_, delta)
        rows.offset = math.max(0, math.min(#ns.Dungeons.MyList() - count, (rows.offset or 0) - delta))
        UI.Dirty()
    end)
    function rows.Refresh()
        -- Level order, lowest first; the ones at my level are green and in view to start with.
        local list, first = ns.Dungeons.ByLevel(UnitLevel("player") or 1)
        if not rows.offset then
            rows.offset = math.max(0, math.min(#list - count, (first or 1) - 1))
        end
        for i = 1, count do
            local r, d = rows[i], list[rows.offset + i]
            r.key = d and d.key
            if d then
                r.name:SetText((d.dist == 0 and ns.GREEN or "") .. d.name .. "|r")
                r.range:SetText(d.min .. "-" .. d.max)
                r.check:SetChecked(rows.picked[d.key] == true)
                r.stripe:SetColorTexture(1, 1, 1, (i % 2 == 0) and 0.04 or 0)
                r:Show()
            else
                r:Hide()
            end
        end
    end
    return rows
end

local function EditBox(parent, x, y, w)
    local box = CreateFrame("EditBox", nil, parent, "InputBoxTemplate")
    box:SetSize(w, 20)
    box:SetPoint("TOPLEFT", x + 6, y)
    box:SetAutoFocus(false)
    box:SetMaxLetters(60)
    box:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    box:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
    return box
end

---------------------------------------------------------------------------------------------------
-- Build

local VIEW_NAMES = { L.OPEN_GROUPS, L.AVAILABLE_GUILDIES }

local function BuildLeft(p)
    p.view = 1
    p.offset = 0
    function p.pickView(i)
        p.view, p.offset, p.mode = i, 0, nil
        if p:IsShown() then UI.Dirty() end
    end
    -- Mine: am I available, and my group.
    p.status = UI.SideBox(p, 0, "Interface\\Icons\\INV_Shield_06", L.DUNGEON_STATUS, function()
        p.mode = "avail"
        UI.Dirty()
    end)
    p.groupCard = UI.SideBox(p, -72, "Interface\\GroupFrame\\UI-Group-LeaderIcon", L.YOUR_GROUP, function()
        p.mode = ns.Dungeons.MyGroup() and "group" or "post"
        UI.Dirty()
    end)
    -- The line between putting up and looking.
    local line = p:CreateTexture(nil, "ARTWORK")
    line:SetColorTexture(0.9, 0.76, 0.36, 0.5)
    line:SetPoint("TOPLEFT", 0, -149)
    line:SetSize(UI.SIDE_W, 1)
    -- What's out there.
    p.groupsCard = UI.SideBox(p, -158, "Interface\\Icons\\Ability_Warrior_BattleShout", L.OPEN_GROUPS, function() p.pickView(1) end)
    p.availCard = UI.SideBox(p, -230, "Interface\\Icons\\Ability_Rogue_Sprint", L.AVAILABLE_GUILDIES, function() p.pickView(2) end)
    -- the group pop-up's switch here too (Settings has the same one).
    p.groupAlert = UI.SideBox(p, -310, "Interface\\Icons\\INV_Misc_Note_01", L.GROUP_ALERT_CARD, function()
        ns.settings.pop.group = ns.settings.pop.group == false
        ns.Fire("SETTINGS")
        UI.Dirty()
    end)
    p.groupAlert:SetScript("OnEnter", function(self)
        if not GameTooltip then return end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:AddLine(L.GROUP_ALERT_TIP, 1, 1, 1, true)
        GameTooltip:Show()
    end)
    p.groupAlert:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
    p.viewTitle = UI.ViewTitle(p, 400)
    -- Opening the tab while leading a group shows it (an applicant's pop-up brings you here).
    p:HookScript("OnShow", function() if ns.Dungeons.MyGroup() then p.mode = "group" end end)

    p.groupsView = CreateFrame("Frame", nil, p)
    p.groupsView:SetPoint("TOPLEFT", RX, -28)
    p.groupsView:SetSize(RW, 380)
    p.availView = CreateFrame("Frame", nil, p)
    p.availView:SetPoint("TOPLEFT", RX, -28)
    p.availView:SetSize(RW, 380)
    for _, v in ipairs({ p.groupsView, p.availView }) do
        v:EnableMouseWheel(true)
        v:SetScript("OnMouseWheel", function(_, delta) p.offset = math.max(0, p.offset - delta); UI.Dirty() end)
    end


    p.groupPager = UI.Pager(p.groupsView, RW - 142, -368, function(d)
        p.offset = math.max(0, p.offset + d * CARDS); UI.Dirty()
    end)
    p.availPager = UI.Pager(p.availView, RW - 142, -360, function(d)
        p.offset = math.max(0, p.offset + d * AVAIL_CARDS); UI.Dirty()
    end)
    p.cards = {}
    for i = 1, CARDS do
        local c = Box(p.groupsView, 0, -(i - 1) * 90, RW, 86)
        c.title = Text(c, "", "GameFontNormal", 12, -10, 400)
        c.ago = Text(c, "", "GameFontDisableSmall", 412, -11, 128, "RIGHT")
        c.leader = Text(c, "", "GameFontHighlightSmall", 12, -30, 528)
        c.roles = Text(c, "", "GameFontHighlightSmall", 12, -56, 300)
        c.status = Text(c, "", "GameFontHighlightSmall", 332, -56, 150, "RIGHT")
        c.signT = Button(c, L.ROLE_TANK, 46, 398, -50, function() ns.Dungeons.SignUp(c.key, "t") end)
        c.signH = Button(c, L.ROLE_HEALER_SHORT, 46, 446, -50, function() ns.Dungeons.SignUp(c.key, "h") end)
        c.signD = Button(c, L.ROLE_DPS, 46, 494, -50, function() ns.Dungeons.SignUp(c.key, "d") end)
        c.cancel = Button(c, L.CANCEL, 70, 470, -50, function() ns.Dungeons.CancelSign(c.key) end)
        c.modX = UI.ModRemove(c, RW - 72, -6, function() return c.key end, function(k) ns.Dungeons.ModClose(k) end)
        p.cards[i] = c
    end
    p.groupsEmpty = Text(p.groupsView, L.NO_GROUPS, "GameFontDisableSmall", 4, -8, RW - 8)

    p.avail = {}
    for i = 1, AVAIL_CARDS do
        local c = Box(p.availView, 0, -(i - 1) * 88, RW, 84)
        c.name = Text(c, "", "GameFontHighlight", 12, -10, 380)
        c.left = Text(c, "", "GameFontDisableSmall", 394, -11, 146, "RIGHT")
        -- Up to two lines of dungeons, then "+N more"; hovering the card lists them all.
        c.what = Text(c, "", "GameFontHighlightSmall", 12, -28, 380)
        c.what:SetWordWrap(true)
        c.what:SetHeight(26)
        c.what:SetJustifyV("TOP")
        c.note = Text(c, "", "GameFontHighlightSmall", 12, -60, 380)
        c:EnableMouse(true)
        c:SetScript("OnEnter", function(self)
            if not self.allDungeons or not GameTooltip then return end
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:AddLine(L.UP_FOR)
            for _, n in ipairs(self.allDungeons) do GameTooltip:AddLine(n, 1, 1, 1) end
            GameTooltip:Show()
        end)
        c:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
        c.whisper = Button(c, L.WHISPER, 66, 404, -52, function()
            local m = c.who and ns.Guild.Get(c.who)
            if m then ns.Whisper.Open(m, string.format(L.AVAIL_WHISPER, FirstName(m.name), c.firstDungeon or "")) end
        end, 22)
        c.invite = Button(c, L.INVITE, 66, 474, -52, function()
            local m = c.who and ns.Guild.Get(c.who)
            if m then UI.Invite(m) end
        end, 22)
        -- On my own card: take me off the list right here (Stop on the right was hard to find).
        c.stop = Button(c, L.STOP_LISTING, 136, 404, -52, function() ns.Dungeons.StopAvailable() end, 22)
        c.modX = UI.ModRemove(c, RW - 72, -6, function() return c.who end, function(k) ns.Dungeons.ModUnavail(k) end)
        p.avail[i] = c
    end
    p.availEmpty = Text(p.availView, L.NO_AVAILABLE, "GameFontDisableSmall", 4, -8, RW - 8)
end

local function BuildAvailForm(p)
    local f = CreateFrame("Frame", nil, p)
    f:SetPoint("TOPLEFT", RX, 0)
    f:SetSize(RW, 410)
    p.availForm = f
    f.roles = { t = false, h = false, d = false }
    f.picked = {}
    f.forIndex = 2

    Header(f, L.MAKE_AVAILABLE, 0, -4, RW)
    Text(f, L.DUNGEONS_ID_RUN, "GameFontHighlightSmall", 2, -26)
    f.rows = DungeonRows(p, f, -40, false, f.picked, FORM_ROWS)
    Text(f, L.I_CAN_GO_AS, "GameFontHighlightSmall", CX + 2, -26)
    f.roleChecks = {}
    for _, r in ipairs({ { "t", 0 }, { "h", 80 }, { "d", 176 } }) do
        local c = CreateFrame("CheckButton", nil, f, "UICheckButtonTemplate")
        c:SetSize(22, 22)
        c:SetPoint("TOPLEFT", CX + r[2], -38)
        Text(f, ROLE_ICON[r[1]] .. " " .. ROLE_NAME[r[1]], "GameFontHighlightSmall", CX + r[2] + 22, -43)
        c:SetScript("OnClick", function(self) f.roles[r[1]] = self:GetChecked() and true or false; UI.Dirty() end)
        f.roleChecks[r[1]] = c
    end
    Text(f, L.FOR, "GameFontHighlightSmall", CX + 2, -76)
    f.pickFor = UI.Choice(f, { L.FOR_1H, L.FOR_2H, L.FOR_TONIGHT }, CX + 34, -70, 68, function(i) f.forIndex = i end)
    f.pickFor(2)
    Text(f, L.NOTE, "GameFontHighlightSmall", CX + 2, -104)
    f.note = EditBox(f, CX + 34, -100, CW - 44)
    -- What you've picked: red until there's a dungeon and a role, then green.
    f.dungeonLine = UI.ReadyLine(f, CX, -128, CW)
    f.roleLine = UI.ReadyLine(f, CX, -156, CW)
    f.go = Button(f, L.IM_AVAILABLE, 140, CX, -188, function()
        local ds = {}
        for _, d in ipairs(ns.Dungeons.LIST) do if f.picked[d[1]] then ds[#ds + 1] = d[1] end end
        if not ns.Dungeons.SetAvailable(f.roles, ds, ns.Dungeons.FOR[f.forIndex], f.note:GetText() or "") then
            ns.Print(L.PICK_ROLE_AND_DUNGEON)
            return
        end
        p.pickView(2)
    end, 24)
    f.stop = Button(f, L.STOP, 90, CX + 150, -188, function() ns.Dungeons.StopAvailable() end, 24)
    f.status = Text(f, "", "GameFontHighlightSmall", CX + 2, -222, CW - 4)
    local tip = Text(f, L.AVAIL_TIP, "GameFontDisableSmall", CX + 2, -242, CW - 4)
    tip:SetWordWrap(true)
    tip:SetHeight(56)
    tip:SetJustifyV("TOP")
end

local function BuildPostForm(p)
    local f = CreateFrame("Frame", nil, p)
    f:SetPoint("TOPLEFT", RX, 0)
    f:SetSize(RW, 410)
    p.postForm = f
    f.picked = {}
    f.me = nil                     -- no role until the leader picks one (starts red)
    f.need = { t = 1, h = 1, d = 3 }

    Header(f, L.POST_GROUP, 0, -4, RW)
    Text(f, L.PICK_DUNGEON, "GameFontHighlightSmall", 2, -26)
    f.rows = DungeonRows(p, f, -40, true, f.picked, FORM_ROWS)
    Text(f, L.MY_ROLE, "GameFontHighlightSmall", CX + 2, -32)
    f.pickMe = UI.Choice(f, { L.ROLE_TANK, L.ROLE_HEALER_SHORT, L.ROLE_DPS }, CX + 64, -26, 56, function(i)
        f.me = ({ "t", "h", "d" })[i]
        -- Counting me: make sure my own role is at least 1.
        if f.me and f.need[f.me] < 1 then f.need[f.me] = 1 end
        UI.Dirty()
    end)
    Text(f, L.GROUP_NEEDS, "GameFontHighlightSmall", CX + 2, -60)
    -- Counting me: my own role can't go below 1 (a healer leading is at least 1 healer).
    f.roles = UI.RoleCounts(f, CX, -74, function(r) return f.need[r] end, function(r, n) f.need[r] = n; UI.Dirty() end,
        function(r) return r == f.me and 1 or 0 end)
    Text(f, L.NOTE, "GameFontHighlightSmall", CX + 2, -152)
    f.note = EditBox(f, CX + 34, -148, CW - 44)
    -- What you've picked: red until there's a dungeon and your role, then green.
    f.dungeonLine = UI.ReadyLine(f, CX, -176, CW)
    f.roleLine = UI.ReadyLine(f, CX, -204, CW)
    f.post = Button(f, L.POST, 110, CX, -236, function()
        local key = next(f.picked)
        if not key then ns.Print(L.PICK_A_DUNGEON) return end
        if not f.me then ns.Print(L.READY_NO_ROLE) return end
        if ns.Dungeons.Post(key, f.me, f.need, f.note:GetText() or "") then
            wipe(f.picked)
            f.note:SetText("")
            f.pickMe(0)
            p.mode = "group"
            UI.Dirty()
        end
    end, 24)
    f.cancel = Button(f, L.CANCEL, 90, CX + 120, -236, function() p.mode = nil; UI.Dirty() end, 24)
    local tip = Text(f, L.POST_TIP, "GameFontDisableSmall", CX + 2, -270, CW - 4)
    tip:SetWordWrap(true)
    tip:SetHeight(56)
    tip:SetJustifyV("TOP")
end

local function BuildMyGroup(p)
    local f = CreateFrame("Frame", nil, p)
    f:SetPoint("TOPLEFT", RX, 0)
    f:SetSize(RW, 410)
    p.myGroup = f
    local function Need(r) local g = ns.Dungeons.MyGroup(); return g and g["n" .. r] or 0 end
    f.header = Header(f, "", 0, -4, RW)
    f.left = Text(f, "", "GameFontDisableSmall", 2, -26, RIGHT_W)
    Text(f, L.GROUP_NEEDS, "GameFontHighlightSmall", 2, -46)
    f.roles = UI.RoleCounts(f, 0, -60, function(r) return Need(r) end, function(r, n) ns.Dungeons.SetNeed(r, n) end,
        function(r) local g = ns.Dungeons.MyGroup(); return g and g.me == r and 1 or 0 end)
    f.inGroup = Text(f, "", "GameFontHighlightSmall", 2, -130, RIGHT_W)
    Header(f, L.APPLICANTS, CX, -26, CW)
    f.apps = {}
    for i = 1, 5 do
        local r = Row(f, CX, -48 - (i - 1) * 26, CW, 24)
        r.name = Text(r, "", "GameFontHighlightSmall", 4, -6, 128)
        r.invite = Button(r, L.INVITE, 56, 136, -1, function()
            local m = r.who and ns.Guild.Get(r.who)
            if m then UI.Invite(m) end
        end, 22)
        r.decline = Button(r, "x", 24, 196, -1, function() if r.who then ns.Dungeons.Decline(r.who) end end, 22)
        r.joined = Text(r, "", "GameFontHighlightSmall", 136, -6, 106)
        f.apps[i] = r
    end
    f.noApps = Text(f, L.NO_APPLICANTS, "GameFontDisableSmall", CX + 4, -52, CW - 8)
    f.noApps:SetWordWrap(true)
    f.noApps:SetHeight(40)
    f.noApps:SetJustifyV("TOP")
    f.close = Button(f, L.CLOSE_GROUP, 120, 0, -160, function() ns.Dungeons.Close() end, 24)
end

local function Build(p)
    BuildLeft(p)
    BuildAvailForm(p)
    BuildPostForm(p)
    BuildMyGroup(p)
    p.pickView(1)
end

---------------------------------------------------------------------------------------------------
-- Refresh

local function RoleSlots(g)
    local function Slot(r, n, h)
        if n == 0 and h == 0 then return nil end
        local c = (h >= n) and ns.GREEN or ORANGE
        return ROLE_ICON[r] .. " " .. c .. h .. "/" .. n .. "|r"
    end
    local parts = {}
    for _, s in ipairs({ Slot("t", g.nt, g.ht), Slot("h", g.nh, g.hh), Slot("d", g.nd, g.hd) }) do
        if s then parts[#parts + 1] = s end
    end
    return table.concat(parts, "   ")
end

local function RefreshGroups(p)
    local D = ns.Dungeons
    local list = D.Groups()
    local now = GetServerTime()
    if p.offset > math.max(0, #list - CARDS) then p.offset = math.max(0, #list - CARDS) end
    p.groupsEmpty:SetShown(#list == 0)
    p.groupPager.Set(p.offset + 1, math.min(#list, p.offset + CARDS), #list)
    for i, c in ipairs(p.cards) do
        local g = list[p.offset + i]
        c.key = g and g.key
        if g then
            local d = D.BY_KEY[g.d]
            c.title:SetText((D.AtMyLevel(g.d) and ns.GREEN or "") .. d.name .. "|r  " .. ns.GREY .. "(" .. d.min .. "-" .. d.max .. ")|r")
            c.ago:SetText(string.format(L.POSTED_AGO, Duration(now - (g.at or now))))
            local note = (g.note ~= "" and ("   \"" .. g.note .. "\"") or "")
            c.leader:SetText(L.LEADER .. " " .. MemberLine(g.owner) .. " " .. ROLE_ICON[g.me] .. note)
            c.roles:SetText(RoleSlots(g))
            local signed = D.signed[g.key]
            local show = { t = false, h = false, d = false }
            if g.mine then
                c.status:SetText(ns.GOLD .. L.YOUR_GROUP .. "|r")
            elseif signed == "x" then
                c.status:SetText(ns.GREY .. L.NOT_THIS_TIME .. "|r")
            elseif signed then
                c.status:SetText(string.format(L.SIGNED_AS, ROLE_NAME[signed]))
            else
                c.status:SetText("")
                show.t, show.h, show.d = g.ht < g.nt, g.hh < g.nh, g.hd < g.nd
                if not (show.t or show.h or show.d) then c.status:SetText(ns.GREEN .. L.FULL .. "|r") end
            end
            c.signT:SetShown(show.t)
            c.signH:SetShown(show.h)
            c.signD:SetShown(show.d)
            c.cancel:SetShown(signed ~= nil and signed ~= "x" and not g.mine)
            if signed and signed ~= "x" then c.status:SetPoint("TOPLEFT", 312, -56) else c.status:SetPoint("TOPLEFT", 392, -56) end
            local mod = not g.mine and D.CanRemove()
            c.modX.Sync(mod)
            c.ago:SetPoint("TOPLEFT", mod and 340 or 412, -11)
            c:Show()
        else
            c:Hide()
        end
    end
end

local function RefreshAvail(p)
    local D = ns.Dungeons
    local list = D.Available()
    local now = GetServerTime()
    if p.offset > math.max(0, #list - AVAIL_CARDS) then p.offset = math.max(0, #list - AVAIL_CARDS) end
    p.availEmpty:SetShown(#list == 0)
    p.availPager.Set(p.offset + 1, math.min(#list, p.offset + AVAIL_CARDS), #list)
    for i, c in ipairs(p.avail) do
        local e = list[p.offset + i]
        c.who = e and e.name
        if e then
            local a = e.a
            local icons = ""
            for _, r in ipairs({ "t", "h", "d" }) do if a.r[r] then icons = icons .. ROLE_ICON[r] .. " " end end
            c.name:SetText(MemberLine(e.name) .. "   " .. icons .. (a.mine and (ns.GREEN .. "(" .. L.YOU .. ")|r") or ""))
            c.left:SetText(string.format(L.FOR_ANOTHER, Duration(a.u - now)))
            local names = {}
            for _, k in ipairs(a.ds) do names[#names + 1] = D.Name(k) end
            c.firstDungeon = names[1]
            c.allDungeons = names
            local shown = {}
            for j = 1, math.min(#names, AVAIL_SHOWN) do shown[j] = names[j] end
            local extra = #names > AVAIL_SHOWN and ("  " .. ns.GREY .. string.format(L.PLUS_MORE, #names - AVAIL_SHOWN) .. "|r") or ""
            c.what:SetText(L.UP_FOR .. " " .. table.concat(shown, ", ") .. extra)
            c.note:SetText(a.note ~= "" and ("\"" .. a.note .. "\"") or (ns.GREY .. L.NO_NOTE .. "|r"))
            local m = ns.Guild.Get(e.name)
            c.whisper:SetShown(not a.mine and m ~= nil)
            c.invite:SetShown(not a.mine and m ~= nil)
            c.stop:SetShown(a.mine == true)
            local mod = not a.mine and D.CanRemove()
            c.modX.Sync(mod)
            c.left:SetPoint("TOPLEFT", mod and 322 or 394, -11)
            c:Show()
        else
            c:Hide()
        end
    end
end

local function RefreshAvailForm(f)
    local a = ns.Dungeons.MyAvail()
    if a and not f.loaded then
        -- Show what I'm available for (once, so the player can then change it).
        f.loaded = true
        for r in pairs(f.roles) do f.roles[r] = a.r[r] or false end
        wipe(f.picked)
        for _, k in ipairs(a.ds) do f.picked[k] = true end
        f.note:SetText(a.note or "")
    end
    if not a then f.loaded = false end
    for r, c in pairs(f.roleChecks) do c:SetChecked(f.roles[r]) end
    f.rows.Refresh()
    local names, roles = {}, {}
    for _, d in ipairs(ns.Dungeons.LIST) do if f.picked[d[1]] then names[#names + 1] = ns.Dungeons.Name(d[1]) end end
    for _, r in ipairs({ "t", "h", "d" }) do if f.roles[r] then roles[#roles + 1] = ROLE_ICON[r] .. " " .. ROLE_NAME[r] end end
    local shown = table.concat(names, ", ", 1, math.min(#names, 2)) .. (#names > 2 and ("  " .. string.format(L.READY_MORE, #names - 2)) or "")
    local okD = f.dungeonLine.Set(#names > 0 and (L.READY_DUNGEONS .. " " .. shown) or nil, L.READY_NO_DUNGEONS)
    local okR = f.roleLine.Set(#roles > 0 and (L.READY_ROLES .. " " .. table.concat(roles, ", ")) or nil, L.READY_NO_ROLES)
    f.go:SetEnabled(okD and okR)
    f.stop:SetEnabled(a ~= nil)
    f.go:SetText(a and L.UPDATE or L.IM_AVAILABLE)
    if a then
        f.status:SetText(ns.GREEN .. L.YOURE_AVAILABLE .. "|r " .. string.format(L.FOR_ANOTHER, Duration(a.u - GetServerTime())))
    else
        f.status:SetText(ns.GREY .. L.NOT_AVAILABLE .. "|r")
    end
end

local function RefreshMyGroup(f)
    local D = ns.Dungeons
    local g = D.MyGroup()
    if not g then return end
    f.header:SetText(string.format(L.YOUR_GROUP_FOR, D.Name(g.d)))
    f.left:SetText(string.format(L.ENDS_IN, Duration(g.u - GetServerTime())))
    f.roles.Refresh()
    local shown = D.groups[ns.me .. ":" .. g.id]
    f.inGroup:SetText(shown and (L.IN_GROUP_NOW .. " " .. RoleSlots(shown)) or "")
    local apps = D.Applicants()
    f.noApps:SetShown(#apps == 0)
    for i, r in ipairs(f.apps) do
        local a = apps[i]
        r.who = a and a.name
        if a then
            r.name:SetText(ROLE_ICON[a.r] .. " " .. MemberLine(a.name))
            r.invite:SetShown(not a.joined)
            r.decline:SetShown(not a.joined)
            r.joined:SetText(a.joined and (ns.GREEN .. L.JOINED .. "|r") or "")
            r.stripe:SetColorTexture(1, 1, 1, (i % 2 == 0) and 0.04 or 0)
            r:Show()
        else
            r:Hide()
        end
    end
end

-- The sidebar: the action (Post a group, or Your group while I lead one), the views with counts, and
-- my status (leading, available, or not) in the box.
local function RefreshSide(p)
    local D = ns.Dungeons
    local g = D.MyGroup()
    p.status.SetPicked(p.mode == "avail")
    p.groupCard.SetPicked(p.mode == "post" or p.mode == "group")
    p.groupsCard.SetPicked(p.mode == nil and p.view == 1)
    p.availCard.SetPicked(p.mode == nil and p.view == 2)
    local a = D.MyAvail()
    local now = GetServerTime()

    p.groupCard.SetActive(g ~= nil)
    p.status.SetActive(a ~= nil)
    local on = ns.settings.pop.group ~= false
    p.groupAlert.SetActive(on)
    p.groupAlert.text:SetText(on and (ns.GREEN .. L.Q_ALERT_ON .. "|r") or (ns.GREY .. L.Q_ALERT_OFF .. "|r"))
    p.groupAlert.pts:SetText(on and L.Q_ALERT_CLICK_OFF or L.Q_ALERT_CLICK_ON)
    -- My group: posted (where, how many waiting) or not.
    if g then
        local apps = 0
        for _, e in ipairs(D.Applicants()) do if not e.joined then apps = apps + 1 end end
        p.groupCard.text:SetText(ns.GOLD .. D.Name(g.d) .. "|r")
        p.groupCard.pts:SetText(string.format(L.DUNGEON_STATUS_LEADING, apps))
    else
        p.groupCard.text:SetText(ns.GREY .. L.DUNGEON_NO_GROUP .. "|r")
        p.groupCard.pts:SetText(L.DUNGEON_POST_CLICK)
    end

    -- Open groups: how many, and how many at my level.
    local groups = D.Groups()
    local mine = 0
    for _, e in ipairs(groups) do if D.AtMyLevel(e.d) then mine = mine + 1 end end
    p.groupsCard.text:SetText(#groups > 0 and string.format(L.DUNGEON_N_OPEN, #groups) or (ns.GREY .. L.DUNGEON_NONE_NOW .. "|r"))
    p.groupsCard.pts:SetText(#groups > 0 and string.format(L.DUNGEON_AT_LEVEL, mine) or "")

    -- Available guildies: how many, and the roles between them.
    local avail = D.Available()
    local roles = { t = 0, h = 0, d = 0 }
    for _, e in ipairs(avail) do for r in pairs(roles) do if e.a.r[r] then roles[r] = roles[r] + 1 end end end
    p.availCard.text:SetText(#avail > 0 and string.format(L.DUNGEON_N_AVAILABLE, #avail) or (ns.GREY .. L.DUNGEON_NONE_NOW .. "|r"))
    p.availCard.pts:SetText(#avail > 0 and (ROLE_ICON.t .. " " .. roles.t .. "   " .. ROLE_ICON.h .. " " .. roles.h .. "   " .. ROLE_ICON.d .. " " .. roles.d) or "")

    -- Me: available or not.
    if a then
        p.status.text:SetText(ns.GREEN .. L.YOURE_AVAILABLE .. "|r")
        p.status.pts:SetText(string.format(L.FOR_ANOTHER, Duration(a.u - now)) .. "  " .. L.DUNGEON_STATUS_CHANGE)
    else
        p.status.text:SetText(ns.GREY .. L.DUNGEON_STATUS_NOT .. "|r")
        p.status.pts:SetText(L.DUNGEON_STATUS_CLICK)
    end
end

local function Refresh(p)
    local D = ns.Dungeons
    local leading = D.MyGroup() ~= nil
    if leading and p.mode == "post" then p.mode = "group" end
    if not leading and p.mode == "group" then p.mode = nil end
    RefreshSide(p)
    local list = p.mode == nil
    p.viewTitle:SetText(list and VIEW_NAMES[p.view] or "")
    p.groupsView:SetShown(list and p.view == 1)
    p.availView:SetShown(list and p.view == 2)
    p.myGroup:SetShown(p.mode == "group")
    p.postForm:SetShown(p.mode == "post")
    p.availForm:SetShown(p.mode == "avail")
    if list then
        if p.view == 1 then RefreshGroups(p) else RefreshAvail(p) end
    elseif p.mode == "group" then
        RefreshMyGroup(p.myGroup)
    elseif p.mode == "post" then
        local f = p.postForm
        f.rows.Refresh()
        f.roles.Refresh()
        local key = next(f.picked)
        local okD = f.dungeonLine.Set(key and (L.READY_DUNGEON .. " " .. D.Name(key)) or nil, L.READY_NO_DUNGEON)
        local okR = f.roleLine.Set(f.me and (L.READY_MY_ROLE .. " " .. ROLE_ICON[f.me] .. " " .. ROLE_NAME[f.me]) or nil, L.READY_NO_ROLE)
        f.post:SetEnabled(okD and okR)
    else
        RefreshAvailForm(p.availForm)
    end
end

UI.AddPage("dungeons", Build, Refresh)
ns.Listen("DUNGEONS", UI.Dirty)
