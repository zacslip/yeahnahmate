-- Calendar tab (from the mock-up): the month on the left, the chosen day's events on the right with
-- Going / Maybe / Can't, and a form for a new event (or editing your own).
local ADDON, ns = ...
local L = ns.L
local UI = ns.UI
local Text, Button, Box = UI.Text, UI.Button, UI.Box

local CELL_W, CELL_H = 64, 50
local X = 474
local RIGHT_W = 262
-- Levelling and other (older versions) show as social (Calendar.ShownKind).
local KIND = {
    s = { "ffff80ff", L.KIND_SOCIAL }, d = { "ffff9933", L.KIND_DUNGEON }, r = { "ffff5050", L.KIND_RAID },
}
local function KindOf(e) return KIND[ns.Calendar.ShownKind(e.k)] or KIND.s end
local KIND_ORDER = { "s", "d", "r" }
local KIND_READY = { s = true, d = true }           -- raid waits for the raid roster
local ROLE_ICON = {
    t = "|TInterface\\Icons\\INV_Shield_06:14|t",
    h = "|TInterface\\Icons\\Spell_Holy_Heal:14|t",
    d = "|TInterface\\Icons\\INV_Sword_04:14|t",
}
local MINUTES = { 0, 15, 30, 45 }

-- "7:30pm" in the player's local time.
function UI.TimeText(at)
    local t = date("*t", at)
    local h = t.hour % 12
    if h == 0 then h = 12 end
    return string.format("%d:%02d%s", h, t.min, t.hour < 12 and "am" or "pm")
end

-- "Tonight", "Tomorrow" or "Wed 12 Nov".
function UI.DayText(at)
    local t, now = date("*t", at), date("*t")
    local today = time({ year = now.year, month = now.month, day = now.day, hour = 12 })
    local that = time({ year = t.year, month = t.month, day = t.day, hour = 12 })
    local days = math.floor((that - today) / 86400 + 0.5)
    if days == 0 then return L.TODAY end
    if days == 1 then return L.TOMORROW end
    return date("%a %d %b", at)
end

local function Noon(y, m, d) return time({ year = y, month = m, day = d, hour = 12 }) end
local function Key(t) return date("%Y-%m-%d", t) end

local function Names(list)
    local out = {}
    for _, name in ipairs(list) do
        local m = ns.Guild.Get(name)
        out[#out + 1] = m and UI.Name(m) or name
    end
    return table.concat(out, ", ")
end

local function Stepper(parent, label, x, y, get, set, lw)
    local s = {}
    lw = lw or 34
    s.label = Text(parent, label, "GameFontHighlightSmall", x, y - 4, lw)
    s.minus = Button(parent, "-", 18, x + lw, y, function() set(-1) end, 18)
    s.value = Text(parent, "", "GameFontHighlight", x + lw + 20, y - 3, 22, "CENTER")
    s.plus = Button(parent, "+", 18, x + lw + 44, y, function() set(1) end, 18)
    function s.Refresh() s.value:SetText(tostring(get())) end
    function s.SetShown(v) for _, w in ipairs({ s.label, s.minus, s.value, s.plus }) do w:SetShown(v) end end
    return s
end

---------------------------------------------------------------------------------------------------
-- Build

local function BuildGrid(p)
    local function Move(by)
        p.offset, p.sel = p.offset + by, nil
        p.mode = nil
        UI.Dirty()
    end
    Button(p, "<", 30, 0, 0, function() Move(-1) end)
    Button(p, ">", 30, 430, 0, function() Move(1) end)
    p.month = Text(p, "", "GameFontNormalLarge", 34, -2, 392, "CENTER")
    for i, n in ipairs({ L.MON, L.TUE, L.WED, L.THU, L.FRI, L.SAT, L.SUN }) do
        Text(p, n, "GameFontNormalSmall", (i - 1) * (CELL_W + 2), -28, CELL_W, "CENTER")
    end
    p.cells = {}
    for i = 1, 42 do
        local col, row = (i - 1) % 7, math.floor((i - 1) / 7)
        local c = CreateFrame("Button", nil, p)
        c:SetSize(CELL_W, CELL_H)
        c:SetPoint("TOPLEFT", col * (CELL_W + 2), -44 - row * (CELL_H + 2))
        c.edge = c:CreateTexture(nil, "BACKGROUND", nil, 0)
        c.edge:SetAllPoints()
        c.bg = c:CreateTexture(nil, "BACKGROUND", nil, 1)
        c.bg:SetPoint("TOPLEFT", 1, -1)
        c.bg:SetPoint("BOTTOMRIGHT", -1, 1)
        c.hl = c:CreateTexture(nil, "BORDER")
        c.hl:SetAllPoints(c.bg)
        c.hl:SetColorTexture(1, 0.82, 0, 0.10)
        c.hl:Hide()
        c.num = Text(c, "", "GameFontHighlightSmall", 4, -3)
        c.e1 = Text(c, "", "GameFontHighlightSmall", 4, -18, CELL_W - 6)
        c.e2 = Text(c, "", "GameFontHighlightSmall", 4, -32, CELL_W - 6)
        c:SetScript("OnEnter", function(self) self.hl:Show() end)
        c:SetScript("OnLeave", function(self) self.hl:Hide() end)
        c:SetScript("OnClick", function(self)
            if not self.day then return end
            p.sel, p.mode, p.dayOffset = self.day, nil, 0
            UI.Dirty()
        end)
        p.cells[i] = c
    end
end

local function BuildDay(p)
    p.dayTitle = Text(p, "", "GameFontNormal", X, -4, 160)
    p.newBtn = Button(p, L.NEW_EVENT, 92, X + 170, 0, function() p.mode = "new"; p.editKey = nil; p.formLoaded = false; UI.Dirty() end)
    p.details = {}
    for i = 1, 2 do
        local b = Box(p, X - 4, -28 - (i - 1) * 180, RIGHT_W + 4, 176)
        b.title = Text(b, "", "GameFontNormal", 12, -10, 242)
        -- My own events: Edit, Cancel and Mute sit on the time line (where the leader's name would be).
        b.edit = Button(b, L.EDIT, 38, 122, -24, function()
            p.mode, p.editKey, p.formLoaded = "edit", b.key, false
            UI.Dirty()
        end, 18)
        -- Cancelling my own event can't be undone (it's gone for the whole guild): click twice.
        b.remove = Button(b, L.REMOVE, 48, 162, -24, function()
            if b.sureOwn ~= b.key then b.sureOwn = b.key; UI.Dirty() return end
            b.sureOwn = nil
            ns.Calendar.Cancel(b.key)
        end, 18)
        b.mute = Button(b, L.MUTE, 52, 212, -24, function() ns.Calendar.ToggleMute(b.key) end, 18)
        b.mute:SetScript("OnEnter", function(self)
            if not GameTooltip then return end
            GameTooltip:SetOwner(self, "ANCHOR_TOP")
            GameTooltip:AddLine(L.MUTE_TIP, 1, 1, 1, true)
            GameTooltip:Show()
        end)
        b.mute:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
        -- Editor ranks: Remove on other people's events, top right. Click twice.
        b.modEdit = Button(b, L.EDIT, 42, RIGHT_W - 116, -6, function()
            p.mode, p.editKey, p.formLoaded = "edit", b.key, false
            UI.Dirty()
        end, 18)
        b.modRemove = Button(b, L.CAL_REMOVE, 64, RIGHT_W - 70, -6, function(self)
            if b.sure ~= b.key then b.sure = b.key; UI.Dirty() return end
            b.sure = nil
            ns.Calendar.Remove(b.key)
        end, 18)
        b.modRemove:SetScript("OnEnter", function(self)
            if not GameTooltip then return end
            GameTooltip:SetOwner(self, "ANCHOR_TOP")
            GameTooltip:AddLine(L.CAL_REMOVE_TIP, 1, 1, 1, true)
            GameTooltip:Show()
        end)
        b.modRemove:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
        b.when = Text(b, "", "GameFontHighlightSmall", 12, -28, 242)
        b.note = Text(b, "", "GameFontHighlightSmall", 12, -44, 242)
        b.note:SetWordWrap(true)
        b.note:SetHeight(28)
        b.note:SetJustifyV("TOP")
        b.roles = Text(b, "", "GameFontHighlightSmall", 12, -76, 242)
        b.going = Text(b, "", "GameFontHighlightSmall", 12, -94, 242)
        b.going:SetWordWrap(true)
        b.going:SetHeight(46)
        b.going:SetJustifyV("TOP")
        b:EnableMouseWheel(true)
        b:SetScript("OnMouseWheel", function(_, delta) p.dayOffset = math.max(0, (p.dayOffset or 0) - delta); UI.Dirty() end)
        b.yes = Button(b, L.GOING, 78, 10, -148, function()
            local e = b.key and ns.Calendar.Store()[b.key]
            if e and (e.nt + e.nh + e.nd) > 0 then b.picking = true; UI.Dirty()
            else ns.Calendar.Answer(b.key, b.at, "y") end
        end)
        b.maybe = Button(b, L.MAYBE, 78, 94, -148, function() ns.Calendar.Answer(b.key, b.at, "m") end)
        b.no = Button(b, L.CANT, 78, 178, -148, function() ns.Calendar.Answer(b.key, b.at, "n") end)
        b.pickT = Button(b, L.ROLE_TANK, 60, 10, -148, function() b.picking = false; ns.Calendar.Answer(b.key, b.at, "y", "t") end)
        b.pickH = Button(b, L.ROLE_HEALER_SHORT, 60, 74, -148, function() b.picking = false; ns.Calendar.Answer(b.key, b.at, "y", "h") end)
        b.pickD = Button(b, L.ROLE_DPS, 60, 138, -148, function() b.picking = false; ns.Calendar.Answer(b.key, b.at, "y", "d") end)
        b.pickBack = Button(b, "x", 24, 206, -148, function() b.picking = false; UI.Dirty() end)
        -- Gathering: the organiser's Gather button (in place of Can't, on the day), and everyone
        -- else's "Ask for an invite" while a gathering is on.
        b.gather = Button(b, L.GATHER, 78, 178, -148, function()
            local mine = ns.Gather.Mine()
            if (mine and mine.key == b.key and mine.at == b.at) or ns.Gather.Start(b.key, b.at) then
                p.mode = "gather"
                UI.Dirty()
            end
        end)
        b.askInv = Button(b, L.ASK_INVITE, 246, 10, -148, function() ns.Gather.AskInvite(b.key, b.at) end)
        p.details[i] = b
    end
    p.empty = Text(p, L.NOTHING_ON, "GameFontDisableSmall", X, -40, 256)
    p.empty:SetWordWrap(true)
    p.empty:SetHeight(30)
    p.empty:SetJustifyV("TOP")
    p.more = Text(p, "", "GameFontNormalSmall", X, -393, 120)
    p.dayPager = UI.Pager(p, X + RIGHT_W - 142, -390, function(d)
        p.dayOffset = math.max(0, (p.dayOffset or 0) + d * 2); UI.Dirty()
    end)
end

local function BuildForm(p)
    local f = CreateFrame("Frame", nil, p)
    f:SetPoint("TOPLEFT", X, 0)
    f:SetSize(RIGHT_W, 410)
    p.form = f
    f.hour, f.minute, f.pm, f.kind, f.weekly = 7, 30, true, "s", false
    f.need = { t = 1, h = 1, d = 3 }
    f.im, f.an = 0, false

    f.header = UI.Header(f, "", 0, -4, RIGHT_W)
    Text(f, L.EVENT_TITLE, "GameFontHighlightSmall", 2, -30)
    f.title = CreateFrame("EditBox", nil, f, "InputBoxTemplate")
    f.title:SetSize(RIGHT_W - 50, 20)
    f.title:SetPoint("TOPLEFT", 48, -26)
    f.title:SetAutoFocus(false)
    f.title:SetMaxLetters(40)
    f.title:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    f.title:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)

    Text(f, L.EVENT_TIME, "GameFontHighlightSmall", 2, -58)
    f.hourStep = Stepper(f, "", 40, -54, function() return f.hour end, function(d)
        f.hour = (f.hour + d - 1) % 12 + 1; UI.Dirty()
    end, 0)
    f.minStep = Stepper(f, ":", 104, -54, function() return string.format("%02d", f.minute) end, function(d)
        local i = 1
        for j, m in ipairs(MINUTES) do if m == f.minute then i = j end end
        f.minute = MINUTES[(i + d - 1) % #MINUTES + 1]; UI.Dirty()
    end, 8)
    f.pickPm = UI.Choice(f, { L.AM, L.PM }, 180, -54, 38, function(i) f.pm = (i == 2) end)

    Text(f, L.EVENT_KIND, "GameFontHighlightSmall", 2, -88)
    local kindButtons
    f.pickKind, kindButtons = UI.Choice(f, { L.KIND_SOCIAL, L.KIND_DUNGEON, L.KIND_RAID }, 0, -102, 84, function(i)
        f.kind = KIND_ORDER[i] or "s"; UI.Dirty()
    end)
    for i, k in ipairs(KIND_ORDER) do
        if not KIND_READY[k] then
            local b = kindButtons[i]
            b:Disable()
            b:SetMotionScriptsWhileDisabled(true)
            b:SetScript("OnEnter", function(self)
                if not GameTooltip then return end
                GameTooltip:SetOwner(self, "ANCHOR_TOP")
                GameTooltip:AddLine(L.KIND_RAID_TIP, 1, 1, 1, true)
                GameTooltip:Show()
            end)
            b:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
        end
    end
    f.rolesLabel = Text(f, L.ROLES_WANTED, "GameFontHighlightSmall", 2, -130)
    f.roles = UI.RoleCounts(f, 0, -144, function(r) return f.need[r] end, function(r, n) f.need[r] = n; UI.Dirty() end)
    f.weeklyCheck = UI.Check(f, L.EVERY_WEEK, 0, -212, false, function(on) f.weekly = on end)
    f.muteCheck = UI.Check(f, L.MUTE_ANSWERS, 120, -212, false, function(on) f.mute = on end)
    f.muteCheck:SetScript("OnEnter", function(self)
        if not GameTooltip then return end
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:AddLine(L.MUTE_TIP, 1, 1, 1, true)
        GameTooltip:Show()
    end)
    f.muteCheck:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
    Text(f, L.NOTE, "GameFontHighlightSmall", 2, -246)
    f.note = CreateFrame("EditBox", nil, f, "InputBoxTemplate")
    f.note:SetSize(RIGHT_W - 50, 20)
    f.note:SetPoint("TOPLEFT", 48, -242)
    f.note:SetAutoFocus(false)
    f.note:SetMaxLetters(100)
    f.note:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    f.note:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
    -- Important (Calendar moderators only): remind everyone at any of 15 / 30 / 60 minutes before, and
    -- tell everyone now. Shown only to those who can set it.
    local function ImpTip(self)
        if not GameTooltip then return end
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:AddLine(L.IMPORTANT)
        GameTooltip:AddLine(L.IMP_TIP, 1, 1, 1, true)
        GameTooltip:Show()
    end
    local function NoTip() if GameTooltip then GameTooltip:Hide() end end
    f.imp = {}
    f.impLabel = Text(f, ns.GOLD .. L.IMP_REMIND .. "|r", "GameFontHighlightSmall", 2, -278)
    f.impChecks = {}
    for i, bt in ipairs(ns.Calendar.IM_TIMES) do
        local c, fs = UI.Check(f, string.format(L.IMP_MINUTES, bt[2]), 66 + (i - 1) * 60, -272, false, function(on)
            local has = math.floor(f.im / bt[1]) % 2 == 1
            if on and not has then f.im = f.im + bt[1] elseif not on and has then f.im = f.im - bt[1] end
        end)
        c:SetScript("OnEnter", ImpTip); c:SetScript("OnLeave", NoTip)
        f.impChecks[i] = c
        f.imp[#f.imp + 1] = c; f.imp[#f.imp + 1] = fs
    end
    local an, anText = UI.Check(f, L.IMP_ANNOUNCE, 0, -296, false, function(on) f.an = on end)
    an:SetScript("OnEnter", ImpTip); an:SetScript("OnLeave", NoTip)
    f.anCheck = an
    f.imp[#f.imp + 1] = f.impLabel; f.imp[#f.imp + 1] = an; f.imp[#f.imp + 1] = anText

    f.save = Button(f, L.SAVE, 110, 0, -272, function()
        local d = date("*t", p.formDay)
        local hour24 = (f.hour % 12) + (f.pm and 12 or 0)
        local at = time({ year = d.year, month = d.month, day = d.day, hour = hour24, min = f.minute, sec = 0 })
        local fields = { title = f.title:GetText() or "", at = at, k = f.kind,
            nt = f.need.t, nh = f.need.h, nd = f.need.d, note = f.note:GetText() or "", w = f.weekly, mute = f.mute }
        if f.canImp then fields.im, fields.an = f.im, f.an end
        local key, why = ns.Calendar.Save(p.editKey, fields)
        if not key then ns.Print(L.EVENT_SAVE_FAILED[why] or L.EVENT_NEEDS_TITLE) return end
        p.mode = nil
        UI.Dirty()
    end, 24)
    f.cancel = Button(f, L.CANCEL, 90, 120, -272, function() p.mode = nil; UI.Dirty() end, 24)
    f.tip = Text(f, L.EVENT_TIP, "GameFontDisableSmall", 2, -304, RIGHT_W)
    f.tip:SetWordWrap(true)
    f.tip:SetHeight(42)
    f.tip:SetJustifyV("TOP")
end

local function Build(p)
    p.offset, p.sel, p.dayOffset = 0, nil, 0
    BuildGrid(p)
    BuildDay(p)
    BuildForm(p)
    UI.GatherBuild(p, X, RIGHT_W)
    -- Raid roster: a placeholder for now. The button sits under the month.
    p.raidBtn = Button(p, L.RAID_ROSTER, 110, 0, -364, function()
        p.mode = (p.mode ~= "raids") and "raids" or nil
        UI.Dirty()
    end, 22)
    local r = Box(p, X - 4, -28, RIGHT_W + 4, 220)
    r.title = Text(r, ns.GOLD .. L.RAID_ROSTER .. "|r", "GameFontNormalLarge", 12, -12, 240)
    r.soon = Text(r, L.COMING_SOON, "GameFontHighlight", 12, -40, 240)
    r.text = Text(r, L.RAID_SOON_TEXT, "GameFontHighlightSmall", 12, -66, 240)
    r.text:SetWordWrap(true)
    r.text:SetHeight(110)
    r.text:SetJustifyV("TOP")
    Button(r, L.BACK, 70, 12, -184, function() p.mode = nil; UI.Dirty() end, 22)
    r:Hide()
    p.raidBox = r
end

---------------------------------------------------------------------------------------------------
-- Refresh

local function LoadForm(p)
    local f = p.form
    if p.formLoaded then return end
    p.formLoaded = true
    local e = p.editKey and ns.Calendar.Store()[p.editKey]
    if e then
        local t = date("*t", e.at)
        p.formDay = Noon(t.year, t.month, t.day)
        f.hour = t.hour % 12; if f.hour == 0 then f.hour = 12 end
        f.minute = t.min - t.min % 15
        f.pm = t.hour >= 12
        f.kind = ns.Calendar.ShownKind(e.k)
        f.need = { t = e.nt > 0 and e.nt or 1, h = e.nh > 0 and e.nh or 1, d = e.nd > 0 and e.nd or 3 }
        f.weekly = e.w and true or false
        f.mute = e.mute and true or false
        f.im, f.an = e.im or 0, e.an and true or false
        f.title:SetText(e.title)
        f.note:SetText(e.note or "")
    else
        f.hour, f.minute, f.pm, f.kind, f.weekly = 7, 30, true, "s", false
        f.mute = false
        f.im, f.an = 0, false
        f.need = { t = 1, h = 1, d = 3 }
        f.title:SetText("")
        f.note:SetText("")
    end
    f.pickPm(f.pm and 2 or 1)
    for i, k in ipairs(KIND_ORDER) do if k == f.kind then f.pickKind(i) end end
    f.weeklyCheck:SetChecked(f.weekly)
    f.muteCheck:SetChecked(f.mute)
    for i, bt in ipairs(ns.Calendar.IM_TIMES) do f.impChecks[i]:SetChecked(math.floor(f.im / bt[1]) % 2 == 1) end
    f.anCheck:SetChecked(f.an)
end

local function RefreshForm(p)
    local f = p.form
    LoadForm(p)
    f.header:SetText(string.format(p.editKey and L.EDIT_EVENT_ON or L.NEW_EVENT_ON, date("%a %d %b", p.formDay)))
    f.hourStep.Refresh()
    f.minStep.Refresh()
    local roles = f.kind == "d"
    f.rolesLabel:SetShown(roles)
    f.roles.SetShown(roles)
    f.roles.Refresh()
    -- The important rows only for Calendar moderators; Save moves up when they're hidden.
    f.canImp = ns.Calendar.CanRemove()
    for _, w in ipairs(f.imp) do w:SetShown(f.canImp) end
    local y = f.canImp and -326 or -272
    f.save:SetPoint("TOPLEFT", 0, y)
    f.cancel:SetPoint("TOPLEFT", 120, y)
    f.tip:SetPoint("TOPLEFT", 2, y - 32)
end

local function RefreshDetails(p, evs, past)
    local C = ns.Calendar
    local now = GetServerTime()
    local off = math.min(p.dayOffset or 0, math.max(0, #evs - 2))
    p.dayOffset = off
    for i, b in ipairs(p.details) do
        local item = evs[off + i]
        if item then
            local e, at = item.e, item.at
            if b.key ~= item.key then b.picking = false end
            b.key, b.at = item.key, at
            local k = KindOf(e)
            -- Important: a gold "Important:" before the title (own events' time line has no room).
            b.title:SetText((C.IsImportant(e) and (ns.GOLD .. L.IMP_MARK .. ":|r ") or "") .. "|c" .. k[1] .. e.title .. "|r")
            local leader = ns.Guild.Get(e.owner)
            local own = e.owner == ns.me
            b.when:SetWidth(own and 108 or 242)
            b.when:SetText(UI.TimeText(at) .. "   " .. ns.GREY .. k[2] .. (e.w and (", " .. L.EVERY_WEEK_LOWER) or "")
                .. "|r" .. (own and "" or ("   " .. (leader and UI.Name(leader) or e.owner))))
            b.note:SetText(e.note or "")
            local ans = C.Answers(e, at)
            if (e.nt + e.nh + e.nd) > 0 then
                local function R(r, need)
                    local have = ans.roles[r]
                    return ROLE_ICON[r] .. " " .. ((have >= need) and ns.GREEN or "|cffff8040") .. have .. "/" .. need .. "|r"
                end
                b.roles:SetText(R("t", e.nt) .. "    " .. R("h", e.nh) .. "    " .. R("d", e.nd))
            else
                b.roles:SetText(ns.GREY .. L.NO_ROLES .. "|r")
            end
            local over = at < now - 3 * 3600
            b.going:SetText((over and L.WENT or L.GOING_N) .. " (" .. #ans.y .. "): " .. Names(ans.y)
                .. (#ans.m > 0 and ("\n" .. ns.GREY .. L.MAYBE .. ":|r " .. Names(ans.m)) or "")
                .. (#ans.n > 0 and ("\n" .. ns.GREY .. L.CANT .. ": " .. #ans.n .. "|r") or ""))
            local mine, myRole = C.MyAnswer(e, at)
            local canAnswer = not over
            local picking = b.picking and canAnswer
            for _, btn in ipairs({ b.yes, b.maybe, b.no }) do btn:SetShown(not picking); btn:SetEnabled(canAnswer) end
            for _, btn in ipairs({ b.pickT, b.pickH, b.pickD, b.pickBack }) do btn:SetShown(picking) end
            b.yes:SetText(mine == "y" and (L.GOING .. (myRole and (" " .. ROLE_ICON[myRole]) or "") .. " *") or L.GOING)
            b.maybe:SetText(mine == "m" and (L.MAYBE .. " *") or L.MAYBE)
            b.no:SetText(mine == "n" and (L.CANT .. " *") or L.CANT)
            -- Gathering
            local G = ns.Gather
            local active = G.ActiveFor(item.key, at)
            local organiser = G.CanGather(ns.me, e) and G.Today(at) and not over
            if active and active.organiser ~= ns.me then
                for _, btn in ipairs({ b.yes, b.maybe, b.no, b.pickT, b.pickH, b.pickD, b.pickBack, b.gather }) do btn:Hide() end
                local asked = G.HaveAsked(item.key, at)
                b.askInv:Show()
                b.askInv:SetEnabled(not asked)
                b.askInv:SetText(asked and L.ASKED_INVITE or L.ASK_INVITE)
                b.roles:SetText(ns.GOLD .. string.format(L.GATHERING_BY, active.organiser:match("^%S+") or active.organiser) .. "|r")
            else
                b.askInv:Hide()
                b.gather:SetShown(organiser and not picking)
                if organiser and not picking then
                    b.no:Hide()
                    local mineG = G.Mine()
                    local open = mineG and mineG.key == item.key and mineG.at == at
                    b.gather:SetText(open and L.GATHER_OPEN or L.GATHER)
                end
            end
            b.edit:SetShown(own and not over)
            b.remove:SetShown(own)
            if b.sureOwn ~= b.key then b.sureOwn = nil end
            b.remove:SetText(b.sureOwn and L.MS_SURE or L.REMOVE)
            local mod = not own and C.CanRemove()
            if b.sure ~= b.key then b.sure = nil end
            b.modRemove:SetShown(mod)
            b.modRemove:SetText(b.sure and L.MS_SURE or L.CAL_REMOVE)
            b.modEdit:SetShown(mod and not over)
            b.title:SetWidth(mod and 130 or 242)
            b.mute:SetShown(own)
            b.mute:SetText(e.mute and L.UNMUTE or L.MUTE)
            b:Show()
        else
            b.key = nil
            b:Hide()
        end
    end
    local hidden = #evs - 2
    p.more:SetText(hidden > 0 and string.format(L.MORE_EVENTS, hidden) or "")
    p.dayPager.Set(off + 1, math.min(#evs, off + 2), #evs)
end

local function Refresh(p)
    local C = ns.Calendar
    local now = date("*t")
    local y, m = now.year, now.month + p.offset
    while m > 12 do m = m - 12; y = y + 1 end
    while m < 1 do m = m + 12; y = y - 1 end
    local first = Noon(y, m, 1)
    local days = date("*t", Noon(y, m + 1, 0)).day
    local startCol = (date("*t", first).wday + 5) % 7        -- Monday first
    local todayKey = Key(Noon(now.year, now.month, now.day))
    p.month:SetText(date("%B %Y", first))
    if not p.sel then p.sel = (p.offset == 0) and now.day or 1 end
    if p.sel > days then p.sel = days end

    for i, c in ipairs(p.cells) do
        local d = i - startCol
        if d >= 1 and d <= days then
            c.day = d
            local t = Noon(y, m, d)
            local k = Key(t)
            local evs = C.OnDay(y, m, d)
            local past = k < todayKey
            c.num:SetText((past and ns.GREY or "") .. d .. "|r")
            for j, fs in ipairs({ c.e1, c.e2 }) do
                local item = evs[j]
                if j == 2 and #evs > 2 then
                    fs:SetText(ns.GREY .. "+" .. (#evs - 1) .. " " .. L.MORE .. "|r")
                elseif item then
                    local kind = KindOf(item.e)
                    fs:SetText((ns.Calendar.IsImportant(item.e) and not past and (ns.GOLD .. "!|r") or "")
                        .. "|c" .. (past and "ff808080" or kind[1]) .. item.e.title .. "|r")
                else
                    fs:SetText("")
                end
            end
            -- today and the picked day in the same green as the active cards (was gold).
            if k == todayKey then c.edge:SetColorTexture(0.3, 0.9, 0.4, 1) else c.edge:SetColorTexture(0.3, 0.3, 0.3, 1) end
            if d == p.sel then c.bg:SetColorTexture(0.07, 0.2, 0.09, 0.95)
            else c.bg:SetColorTexture(0.06, 0.06, 0.06, past and 0.6 or 0.9) end
            c:Show()
        else
            c.day = nil
            c:Hide()
        end
    end

    local selT = Noon(y, m, p.sel)
    local past = Key(selT) < todayKey
    -- Raid roster (coming soon) takes the right side while it's open.
    local inRaids = p.mode == "raids"
    p.raidBox:SetShown(inRaids)
    if inRaids then
        p.form:Hide()
        p.gatherFrame:Hide()
        for _, w in ipairs({ p.dayTitle, p.newBtn, p.empty, p.more }) do w:Hide() end
        for _, b in ipairs(p.details) do b:Hide() end
        p.dayPager.Set(1, 1, 1)
        return
    end
    -- The Gather list takes the right side while the organiser has it open.
    if p.mode == "gather" and not ns.Gather.Mine() then p.mode = nil end
    local inGather = p.mode == "gather"
    p.gatherFrame:SetShown(inGather)
    if inGather then
        p.form:Hide()
        for _, w in ipairs({ p.dayTitle, p.newBtn, p.empty, p.more }) do w:Hide() end
        for _, b in ipairs(p.details) do b:Hide() end
        p.dayPager.Set(1, 1, 1)
        UI.GatherRefresh(p)
        return
    end
    local inForm = p.mode == "new" or p.mode == "edit"
    if p.mode == "new" and not p.formLoaded then p.formDay = selT end
    p.form:SetShown(inForm)
    for _, w in ipairs({ p.dayTitle, p.newBtn, p.empty, p.more }) do w:SetShown(not inForm) end
    if inForm then p.dayPager.Set(1, 1, 1) end
    if inForm then
        for _, b in ipairs(p.details) do b:Hide() end
        RefreshForm(p)
        return
    end
    p.dayTitle:SetText(date("%A %d %B", selT))
    p.newBtn:SetEnabled(not past)
    local evs = C.OnDay(y, m, p.sel)
    p.empty:SetShown(#evs == 0)
    p.empty:SetText(past and L.NOTHING_WAS_ON or L.NOTHING_ON)
    RefreshDetails(p, evs, past)
end

UI.AddPage("calendar", Build, Refresh)
ns.Listen("CALENDAR", UI.Dirty)
ns.Listen("GATHER", UI.Dirty)
