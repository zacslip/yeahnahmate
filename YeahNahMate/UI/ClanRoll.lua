-- The Clan roll panel (ClanRoll.lua has the rules), on the Clans tab's My Clan view, to the right of
-- the clan's list. 587 x 372.
--   Setup:   Message (default "Roll for"), Item (drag one from the bags, or type a name), the timer
--            < 30s > (Off, 10, 20, 30, 60), Countdown, Let non-clan members roll, Skip past winners.
--   Start:   the player's click; posts the Start line to party or raid chat.
--   Live:    rolls highest first (gold: the current highest; blue: not in the clan; grey: a past
--            winner, can't win), Who hasn't rolled, the time left. Stop closes it early.
--   After:   the winner (or the tie), Announce (+ Whisper winner) and Reroll ties.
--   History: the last 20 rolls with their date and time.
--   Asked:   when the guild master or a manager asks me to run my clan's part of an all-clans roll
--            (their own view, UI/ClanRollAll.lua), a pop-up and the roll window open with their setup,
--            which can't be changed (CU.Setup); I click Start. If they cancel, it's off.
-- The countdown shows big in the middle of the screen (CountShow), never in chat.
local ADDON, ns = ...
local L = ns.L
local UI = ns.UI
local Text, Button = UI.Text, UI.Button

local W, H = 587, 372
local ROW_H = 17
local RES_ROWS, MISS_ROWS, HIST_ROWS = 9, 9, 14
local BLUE = "|cff5fb4ff"

ns.ClanRollUI = {}
local CU = ns.ClanRollUI

-- What the leader last set, kept for next time.
function CU.Prefs()
    local s = ns.settings
    if type(s.clanRoll) ~= "table" then s.clanRoll = {} end
    local p = s.clanRoll
    if p.timer == nil then p.timer = 30 end
    if p.countdown == nil then p.countdown = true end
    if p.msg == nil then p.msg = L.CLANROLL_DEFAULT end
    return p
end

local function Tip(owner, lines)
    if not GameTooltip then return end
    GameTooltip:SetOwner(owner, "ANCHOR_TOP")
    for i, line in ipairs(lines) do
        if i == 1 then GameTooltip:AddLine(line) else GameTooltip:AddLine(line, 1, 1, 1, true) end
    end
    GameTooltip:Show()
end
local function NoTip() if GameTooltip then GameTooltip:Hide() end end
local function WithTip(f, lines)
    f:SetScript("OnEnter", function(self) Tip(self, lines) end)
    f:SetScript("OnLeave", NoTip)
    return f
end

-- Start roll's tooltip: what it does, or (greyed out) who can start one.
local function StartTip(f, getRace, tip)
    if f.SetMotionScriptsWhileDisabled then f:SetMotionScriptsWhileDisabled(true) end
    f:SetScript("OnEnter", function(self)
        if ns.ClanRoll.CanStart(getRace()) and ns.ClanRoll.Busy() then Tip(self, { L.CLANROLL_START_BTN, L.CLANROLL_BUSY_TIP })
        elseif ns.ClanRoll.CanStart(getRace()) then Tip(self, { L.CLANROLL_START_BTN, tip })
        else Tip(self, { L.CLANROLL_START_BTN, L.CLANROLL_ONLY_LEADERS }) end
    end)
    f:SetScript("OnLeave", NoTip)
    return f
end

local function Edit(parent, x, y, w, max)
    local e = CreateFrame("EditBox", nil, parent, "InputBoxTemplate")
    e:SetSize(w, 20)
    e:SetPoint("TOPLEFT", x + 6, y)
    e:SetAutoFocus(false)
    e:SetMaxLetters(max)
    e:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    e:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
    return e
end

-- A name in class colour (first name only, it's a small list).
local function Who(key)
    local m = ns.Guild.Get(key)
    local short = key:match("^%S+") or key
    if m and m.class and RAID_CLASS_COLORS and RAID_CLASS_COLORS[m.class] then
        local c = RAID_CLASS_COLORS[m.class]
        return string.format("|cff%02x%02x%02x%s|r", c.r * 255, c.g * 255, c.b * 255, short)
    end
    return short
end

-- The result line of a closed roll, the same in the panel and the pop-out. A followed roll shows
-- nothing until its starter's word is in.
function CU.ResultText(r)
    if not r or r.open then return "" end
    if r.cancelled then return ns.GREY .. L.CLANROLL_ALL_CANCELLED .. "|r" end
    if r.winner then return string.format(L.CLANROLL_WINNER, Who(r.winner), ns.GOLD .. (r.winRoll or "") .. "|r") end
    if r.ties then return string.format(L.CLANROLL_TIE, r.winRoll or 0) end
    if r.follower and not r.ended then return "" end
    return ns.GREY .. L.CLANROLL_NOBODY_SHORT .. "|r"
end

-- My closed roll, with something to announce (not one called off).
local function MineDone(r) return r ~= nil and not r.open and r.by == ns.me and not r.cancelled end

local function Rows(parent, x, y, w, n)
    local rows = {}
    for i = 1, n do
        local r = UI.Row(parent, x, y - (i - 1) * ROW_H, w, ROW_H)
        r.stripe:SetShown(i % 2 == 0)
        r.left = Text(r, "", "GameFontHighlightSmall", 4, -2, w - 50)
        r.right = Text(r, "", "GameFontHighlightSmall", w - 46, -2, 42, "RIGHT")
        rows[i] = r
    end
    return rows
end

-- Wheel scrolling for a list: p[key] is its offset.
local function Wheel(p, rows, key)
    for _, r in ipairs(rows) do
        r:EnableMouseWheel(true)
        r:SetScript("OnMouseWheel", function(_, d)
            p[key] = math.max(0, (p[key] or 0) - d * 3)
            UI.Dirty()
        end)
    end
end

---------------------------------------------------------------------------------------------------
-- Building

function CU.Build(parent, x, y)
    local R = ns.ClanRoll
    local p = UI.Box(parent, x, y, W, H)
    p.race = nil
    local prefs = CU.Prefs()

    p.title = Text(p, "", "GameFontNormal", 12, -10, 280)
    CU.panel = p
    p.histBtn = WithTip(Button(p, L.CLANROLL_HISTORY, 90, W - 100, -6, function()
        p.history = not p.history
        p.histOff = 0
        UI.Dirty()
    end, 22), { L.CLANROLL_HISTORY, L.CLANROLL_HISTORY_TIP })
    p.popBtn = WithTip(Button(p, L.CLANROLL_POP, 90, W - 194, -6, function() CU.OpenPop(false, p.race) end, 22),
        { L.CLANROLL_POP, L.CLANROLL_POP_TIP })

    -- Setup
    local sy = -34
    Text(p, L.CLANROLL_MSG, "GameFontNormalSmall", 12, sy - 4, 60)
    p.msg = Edit(p, 66, sy, 150, 40)
    p.msg:SetText(prefs.msg)
    p.msg:SetScript("OnTextChanged", function(self, user) if user then CU.Prefs().msg = self:GetText() end end)
    WithTip(p.msg, { L.CLANROLL_MSG, L.CLANROLL_MSG_TIP })
    Text(p, L.CLANROLL_ITEM, "GameFontNormalSmall", 236, sy - 4, 40)
    p.item = Edit(p, 272, sy, 230, 80)
    p.item:SetScript("OnReceiveDrag", function() CU.TakeItem(p) end)
    p.item:SetScript("OnMouseUp", function() if GetCursorInfo and GetCursorInfo() then CU.TakeItem(p) end end)
    WithTip(p.item, { L.CLANROLL_ITEM, L.CLANROLL_ITEM_TIP })
    p.itemClear = WithTip(Button(p, "x", 22, 512, sy, function() p.item:SetText(""); p.item:ClearFocus() end, 20),
        { L.CLANROLL_ITEM_CLEAR })

    sy = sy - 28
    Text(p, L.CLANROLL_TIMER, "GameFontNormalSmall", 12, sy - 5, 50)
    p.down = WithTip(Button(p, "<", 22, 60, sy, function()
        CU.Prefs().timer = R.StepTimer(CU.Prefs().timer, -1); UI.Dirty()
    end, 20), { L.CLANROLL_TIMER, L.CLANROLL_TIMER_TIP })
    p.timer = Text(p, "", "GameFontHighlight", 84, sy - 4, 40, "CENTER")
    p.up = WithTip(Button(p, ">", 22, 126, sy, function()
        CU.Prefs().timer = R.StepTimer(CU.Prefs().timer, 1); UI.Dirty()
    end, 20), { L.CLANROLL_TIMER, L.CLANROLL_TIMER_TIP })
    local function Tick(label, key, tip, cx, cy)
        local c, fs = UI.Check(p, label, cx, cy, CU.Prefs()[key] and true or false, function(on) CU.Prefs()[key] = on; UI.Dirty() end)
        c:SetHitRectInsets(0, -((fs:GetStringWidth() or 100) + 6), 0, 0)
        WithTip(c, { label, tip })
        return c, fs
    end
    p.countdown, p.countdownText = Tick(L.CLANROLL_COUNTDOWN, "countdown", L.CLANROLL_COUNTDOWN_TIP, 160, sy + 2)
    p.others, p.othersText = Tick(L.CLANROLL_OTHERS, "others", L.CLANROLL_OTHERS_TIP, 280, sy + 2)
    sy = sy - 24
    p.skip, p.skipText = Tick(L.CLANROLL_SKIP, "skip", L.CLANROLL_SKIP_TIP, 280, sy + 2)

    p.startY = sy - 2
    p.start = StartTip(Button(p, L.CLANROLL_START_BTN, 110, 12, sy - 2, function() CU.Start(p) end, 24),
        function() return p.race end, L.CLANROLL_START_TIP)
    p.stop = WithTip(Button(p, L.CLANROLL_STOP_BTN, 110, 12, sy - 2, function() R.Stop() end, 24),
        { L.CLANROLL_STOP_BTN, L.CLANROLL_STOP_TIP })
    p.status = Text(p, "", "GameFontHighlight", 130, sy - 7, 150)

    -- Results and who hasn't rolled
    local ly = -126
    local line = p:CreateTexture(nil, "ARTWORK")
    line:SetColorTexture(0.9, 0.76, 0.36, 0.35)
    line:SetPoint("TOPLEFT", 10, ly + 6)
    line:SetSize(W - 20, 1)
    p.resTitle = Text(p, "", "GameFontNormalSmall", 12, ly, 300)
    p.missTitle = Text(p, "", "GameFontNormalSmall", 340, ly, 230)
    p.res = Rows(p, 10, ly - 16, 310, RES_ROWS)
    p.miss = Rows(p, 338, ly - 16, 238, MISS_ROWS)
    Wheel(p, p.res, "resOff")
    Wheel(p, p.miss, "missOff")
    p.hist = Rows(p, 10, ly - 16, W - 20, HIST_ROWS)
    for _, r in ipairs(p.hist) do
        r.left:SetWidth(W - 170)
        r.right:ClearAllPoints()
        r.right:SetPoint("TOPLEFT", W - 170, -2)
        r.right:SetWidth(144)
    end
    Wheel(p, p.hist, "histOff")
    p.note = Text(p, "", "GameFontDisableSmall", 12, ly - 16 - RES_ROWS * ROW_H - 4, W - 24)

    -- After the roll
    local by = -H + 34
    p.announce = WithTip(Button(p, L.CLANROLL_ANNOUNCE, 100, 12, by, function()
        R.Announce(R.cur, CU.Prefs().whisper)
    end, 24), { L.CLANROLL_ANNOUNCE, L.CLANROLL_ANNOUNCE_TIP })
    p.whisper, p.whisperText = Tick(L.CLANROLL_WHISPER_WIN, "whisper", L.CLANROLL_WHISPER_WIN_TIP, 118, by)
    -- Reroll ties: only after my roll tied, and then first in Start's place (Start moves over one).
    p.reroll = WithTip(Button(p, L.CLANROLL_REROLL, 110, 12, p.startY, function() CU.Reroll() end, 24),
        { L.CLANROLL_REROLL, L.CLANROLL_REROLL_TIP })
    p.result = Text(p, "", "GameFontHighlight", 410, by - 5, W - 420)

    p.Refresh = function(race) CU.Refresh(p, race) end
    return p
end

-- Take the item on the cursor (dragged from the bags) as the roll's item.
function CU.TakeItem(p)
    local kind, _, link = GetCursorInfo()
    if kind ~= "item" then return end
    ClearCursor()
    if type(link) == "string" then
        p.item:SetText(link)
        p.item:ClearFocus()
    end
end

-- A roll of my own already open (a second click before the screen caught up): nothing (R.Start says no
-- too). One I'm only following (another clan's, or another leader's) gives way.
function CU.Start(p)
    local R = ns.ClanRoll
    if R.Busy() then return end
    local pr = CU.Prefs()
    if not R.AskedFor(p.race) then pr.msg = p.msg:GetText() end
    local r = R.Start({ race = p.race, msg = pr.msg, item = p.item:GetText(), timer = pr.timer,
        countdown = pr.countdown, others = pr.others, skip = pr.skip })
    if r then
        p.history, p.resOff, p.missOff = false, 0, 0
        R.PostStart(r)
    end
    UI.Dirty()
end

local STATUS_COL = { waiting = "|cffffffff", rolling = "|cff40ff40", won = "|cffe6c35c", tie = "|cffe6c35c", none = "|cff9d9d9d",
    offline = "|cffff6060", noleader = "|cff9d9d9d", cancelled = "|cff9d9d9d", noresult = "|cffff6060",
    noaddon = "|cffff6060", update = "|cffff9020", group = "|cffff9020", noanswer = "|cffff6060" }

-- One clan's row in plain words.
function CU.AllStatus(row)
    local s = row.status
    local text = L["CLANROLL_ALL_" .. string.upper(s or "waiting")] or s or ""
    if s == "won" and row.winner then text = string.format(text, Who(row.winner), row.roll or 0) end
    if s == "rolling" and row.endsAt then text = text .. " " .. math.max(0, math.ceil(row.endsAt - GetTime())) .. "s" end
    return (STATUS_COL[s] or "") .. text .. "|r"
end

function CU.Reroll()
    local R = ns.ClanRoll
    local r = R.Reroll()
    if r then R.PostStart(r) end
    UI.Dirty()
end

---------------------------------------------------------------------------------------------------
-- Refreshing

local function FillResults(p, r)
    local R = ns.ClanRoll
    local list = r and R.Results(r) or {}
    local off = math.max(0, math.min(p.resOff or 0, #list - RES_ROWS))
    p.resOff = off
    p.resTitle:SetText(string.format(L.CLANROLL_RESULTS, #list))
    for i, row in ipairs(p.res) do
        local e = list[off + i]
        row:SetShown(e ~= nil)
        if e then
            local name = Who(e.name)
            local tag = ""
            if e.past then name = ns.GREY .. (e.name:match("^%S+") or e.name) .. "|r"; tag = ns.GREY .. " " .. L.CLANROLL_PAST_TAG .. "|r"
            elseif e.outsider then name = BLUE .. (e.name:match("^%S+") or e.name) .. "|r"; tag = BLUE .. " " .. L.CLANROLL_OUTSIDER_TAG .. "|r" end
            row.left:SetText((off + i) .. ". " .. name .. tag)
            row.right:SetText((e.top and ns.GOLD or (e.past and ns.GREY or "")) .. e.roll .. "|r")
        end
    end
    local missing = (r and r.open) and R.Missing(r) or {}
    local moff = math.max(0, math.min(p.missOff or 0, #missing - MISS_ROWS))
    p.missOff = moff
    p.missTitle:SetText((r and r.open) and string.format(L.CLANROLL_MISSING, #missing) or "")
    for i, row in ipairs(p.miss) do
        local k = missing[moff + i]
        row:SetShown(k ~= nil)
        if k then row.left:SetText(Who(k)); row.right:SetText("") end
    end
end

local function FillHistory(p)
    local R = ns.ClanRoll
    local h = R.History()
    local n = #h
    local off = math.max(0, math.min(p.histOff or 0, n - HIST_ROWS))
    p.histOff = off
    p.resTitle:SetText(string.format(L.CLANROLL_HISTORY_TITLE, n))
    p.missTitle:SetText("")
    for i, row in ipairs(p.hist) do
        local e = h[n - off - i + 1]          -- newest first
        row:SetShown(e ~= nil)
        if e then
            local what = e.msg or ""
            if e.item then what = what .. " " .. e.item end
            if e.round and e.round > 1 then what = what .. " " .. ns.GREY .. L.CLANROLL_HIST_REROLL .. "|r" end
            local when = date("%d %b %H:%M", e.at or 0)
            row.left:SetText(ns.GREY .. when .. "|r  " .. what .. ns.GREY .. "  " .. string.format(L.CLANROLL_HIST_BY, (e.by or "?"):match("^%S+") or "?") .. "|r")
            local won
            if e.winner then won = Who(e.winner) .. " " .. ns.GOLD .. (e.roll or "") .. "|r"
            elseif e.ties then won = L.CLANROLL_HIST_TIE .. " " .. (e.roll or "")
            else won = ns.GREY .. L.CLANROLL_HIST_NONE .. "|r" end
            row.right:SetText(won)
        end
    end
end

function CU.Refresh(p, race)
    local R = ns.ClanRoll
    p.race = race
    local pr, set = CU.Setup(race)
    local can = R.CanStart(race)
    local r = R.cur
    if r and r.race ~= race then r = nil end
    local open = r and r.open
    CU.lastRace = race
    local asked = R.AskedFor(race)
    p.title:SetText(ns.GOLD .. string.format(L.CLANROLL_TITLE, ns.Clans.RaceName(race)) .. "|r"
        .. (asked and (ns.GREY .. " " .. string.format(L.CLANROLL_ASKED_BY, asked.from:match("^%S+") or asked.from) .. "|r") or ""))

    -- Setup: only before a roll, and only for those who may run one.
    local setup = can and not open
    for _, f in ipairs({ p.msg, p.item, p.itemClear, p.down, p.up, p.countdown, p.others, p.skip }) do
        f:SetEnabled(setup and not set or false)
    end
    -- lockedBy stays on while the asked roll runs, so my own setup comes back once it's over.
    if set and not open then
        p.msg:SetText(set.msg or "")
        p.item:SetText(set.item or "")
        p.lockedBy = true
    elseif p.lockedBy and not open then
        p.msg:SetText(CU.Prefs().msg or "")       -- the ask is used up: my own setup again
        p.item:SetText("")
        p.lockedBy = nil
    end
    p.timer:SetText(pr.timer > 0 and (pr.timer .. "s") or L.CLANROLL_TIMER_OFF)
    p.down:SetEnabled(setup and not set and pr.timer > 0 or false)
    p.up:SetEnabled(setup and not set and pr.timer < R.TIMERS[#R.TIMERS] or false)
    p.countdown:SetEnabled(setup and not set and pr.timer > 0 or false)
    p.countdown:SetChecked(pr.countdown and true or false)
    p.others:SetChecked(pr.others and true or false)
    p.skip:SetChecked(pr.skip and true or false)
    p.whisper:SetChecked(pr.whisper and true or false)

    p.start:SetText(L.CLANROLL_START_BTN)
    p.start:SetShown(not open)
    p.start:SetEnabled(can and not R.Busy() or false)     -- my own roll for another clan: Stop it first
    p.stop:SetShown(open and r.by == ns.me or false)

    -- Status: time left, unreadable rolls, or who can run it.
    local status = ""
    if R.unreadable and open then
        status = "|cffff6060" .. L.CLANROLL_UNREADABLE .. "|r"
    elseif open and r.endsAt then
        status = string.format(L.CLANROLL_LEFT, math.max(0, math.ceil(r.endsAt - GetTime())))
    elseif open then
        status = ns.GREEN .. L.CLANROLL_OPEN .. "|r"
    elseif not can then
        status = ns.GREY .. L.CLANROLL_WHO_CAN .. "|r"
    end
    p.status:SetText(status)

    p.histBtn:SetText(p.history and L.CLANROLL_BACK or L.CLANROLL_HISTORY)
    for _, row in ipairs(p.res) do row:SetShown(false) end
    for _, row in ipairs(p.miss) do row:SetShown(false) end
    for _, row in ipairs(p.hist) do row:SetShown(false) end
    if p.history then FillHistory(p) else FillResults(p, r) end

    -- After: the result, Announce and Reroll ties.
    p.result:SetText(CU.ResultText(r))
    local mine = MineDone(r)
    -- Announce and Whisper winner: only for those who may run this clan's rolls.
    for _, f in ipairs({ p.announce, p.whisper, p.whisperText }) do f:SetShown(can and true or false) end
    p.announce:SetEnabled(mine and true or false)
    p.whisper:SetEnabled(mine and r.winner ~= nil and r.winner ~= ns.me or false)
    -- A tie of mine: Reroll ties first, where Start is; Start one over; the status makes room.
    local tie = mine and r.ties ~= nil or false
    p.reroll:SetShown(tie)
    p.start:ClearAllPoints()
    p.start:SetPoint("TOPLEFT", tie and 128 or 12, p.startY)
    p.status:SetShown(not tie)
    p.note:SetText((not p.history and set and not open) and (ns.GREY .. string.format(L.CLANROLL_ASKED_SET, set.from:match("^%S+") or set.from) .. "|r")
        or (not p.history and pr.others) and (BLUE .. L.CLANROLL_OUTSIDER_TAG .. "|r " .. ns.GREY .. L.CLANROLL_OUTSIDER_NOTE .. "|r") or "")
end

---------------------------------------------------------------------------------------------------
-- While a roll is open: the time left ticks over; the countdown shows big in the middle of the screen.

-- Numbers over heads: each roll that counts, the highest of those who can win in gold.
local function PlateRolls()
    local R, Plates = ns.ClanRoll, ns.Plates
    if not Plates then return end
    local r = R.cur
    local map = {}
    if r and r.open then
        for _, e in ipairs(R.Results(r)) do map[e.name] = { n = e.roll, top = e.top } end
    end
    Plates.SetRolls(map)
end

local ticker
ns.Listen("CLANROLL", function()
    ns.Safe(PlateRolls)
    local r = ns.ClanRoll.cur
    if r and r.open and r.endsAt and not ticker then
        ticker = C_Timer.NewTicker(0.5, function()
            local cur = ns.ClanRoll.cur
            if not (cur and cur.open) then ticker:Cancel(); ticker = nil end
            UI.Dirty()
            if CU.RefreshPop then ns.Safe(CU.RefreshPop) end
        end)
    end
    UI.Dirty()
end)

local big
function CU.CountShow(text)
    if not big then
        big = CreateFrame("Frame", nil, UIParent)
        big:SetSize(400, 60)
        big:SetPoint("CENTER", 0, 180)
        big:SetFrameStrata("FULLSCREEN")       -- over the main window (DIALOG); pop-ups stay above
        big.text = big:CreateFontString(nil, "OVERLAY", "GameFontNormalHuge")
        big.text:SetPoint("CENTER")
    end
    big.text:SetText(text)
    big:Show()
    big.token = (big.token or 0) + 1
    local token = big.token
    C_Timer.After(0.9, function() if big.token == token then big:Hide() end end)
end
CU.Big = function() return big end

ns.Listen("CLANROLL_COUNT", function(left)
    if left == 5 then CU.CountShow(string.format(L.CLANROLL_ENDING_IN, left)) else CU.CountShow(tostring(left)) end
end)

-- The end: the winner's crowned die over their head, and a pop-up when it's me (no one sees their
-- own nameplate).
ns.Listen("CLANROLL_OVER", function(r)
    if ns.Plates then ns.Plates.SetRolls({}) end
    if not r.winner then return end
    if ns.Plates then ns.Plates.ShowWinner(r.winner, r.winRoll) end
    if r.winner == ns.me then
        ns.Toast.nextTab = "clans"
        ns.Toast.Show(L.TOAST_ROLL_WON, string.format(L.TOAST_ROLL_WON_TEXT, ns.ClanRoll.Head(r), r.winRoll or 0), nil)
    end
end)

---------------------------------------------------------------------------------------------------
-- The pop-out: a small movable window with the same roll (Pop out on the panel, or /ynm roll).
-- Members get it by themselves when a roll starts in their group and they can't see one already
-- (the main window isn't on Clans > My Clan, and this isn't open); one that opened by itself closes
-- by itself 15 s after the result. Closing it never stops a roll.

local PW, PH = 300, 340
local POP_ROWS = 8
CU.AUTO_CLOSE = 15
local pop

local function SavePos(f)
    local x, y = f:GetLeft(), f:GetTop()
    if x and y then ns.settings.rollPos = { x = x, y = y } end
end

local function BuildPop()
    local R = ns.ClanRoll
    local f = UI.Box(UIParent, 0, 0, PW, PH)
    f:ClearAllPoints()
    local pos = ns.settings.rollPos
    if type(pos) == "table" and pos.x and pos.y then f:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", pos.x, pos.y)
    else f:SetPoint("RIGHT", UIParent, "RIGHT", -60, 40) end
    f:SetFrameStrata("FULLSCREEN")             -- over the main window (DIALOG); pop-ups stay above
    f:SetClampedToScreen(true)
    f:SetMovable(true)
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", function(self) self:StopMovingOrSizing(); SavePos(self) end)
    f:SetBackdropColor(0, 0, 0, 0.8)

    f.title = Text(f, "", "GameFontNormal", 10, -9, PW - 44)
    f.close = WithTip(Button(f, "x", 22, PW - 28, -5, function() CU.ClosePop() end, 20), { L.CLANROLL_POP_CLOSE })

    -- Setup (whoever may run the roll, before one starts)
    f.setup = CreateFrame("Frame", nil, f)
    f.setup:SetPoint("TOPLEFT", 0, -28)
    f.setup:SetSize(PW, 80)
    Text(f.setup, L.CLANROLL_MSG, "GameFontNormalSmall", 10, -4, 56)
    f.msg = Edit(f.setup, 60, 0, 220, 40)
    f.msg:SetScript("OnTextChanged", function(self, user) if user then CU.Prefs().msg = self:GetText() end end)
    Text(f.setup, L.CLANROLL_ITEM, "GameFontNormalSmall", 10, -28, 56)
    f.item = Edit(f.setup, 60, -24, 220, 80)
    f.item:SetScript("OnReceiveDrag", function() CU.TakeItem(f) end)
    f.item:SetScript("OnMouseUp", function() if GetCursorInfo and GetCursorInfo() then CU.TakeItem(f) end end)
    WithTip(f.item, { L.CLANROLL_ITEM, L.CLANROLL_ITEM_TIP })
    Text(f.setup, L.CLANROLL_TIMER, "GameFontNormalSmall", 10, -53, 50)
    f.down = Button(f.setup, "<", 22, 56, -48, function() CU.Prefs().timer = R.StepTimer(CU.Prefs().timer, -1); CU.RefreshPop() end, 20)
    f.timer = Text(f.setup, "", "GameFontHighlight", 80, -52, 40, "CENTER")
    f.up = Button(f.setup, ">", 22, 122, -48, function() CU.Prefs().timer = R.StepTimer(CU.Prefs().timer, 1); CU.RefreshPop() end, 20)
    f.start = StartTip(Button(f.setup, L.CLANROLL_START_BTN, 120, 170, -46, function() CU.StartFrom(f) end, 24),
        function() return f.race end, L.CLANROLL_POP_START_TIP)

    -- During / after: what it's for and how long is left
    f.head = Text(f, "", "GameFontHighlight", 10, -32, PW - 20)
    f.status = Text(f, "", "GameFontHighlight", 10, -54, 170)
    f.stop = WithTip(Button(f, L.CLANROLL_STOP_BTN, 90, PW - 100, -50, function() R.Stop() end, 22),
        { L.CLANROLL_STOP_BTN, L.CLANROLL_STOP_TIP })

    f.resTitle = Text(f, "", "GameFontNormalSmall", 10, -112, PW - 20)
    f.rows = Rows(f, 8, -128, PW - 16, POP_ROWS)
    f.missing = CreateFrame("Button", nil, f)
    f.missing:SetPoint("TOPLEFT", 10, -128 - POP_ROWS * ROW_H - 4)
    f.missing:SetSize(PW - 20, 16)
    f.missText = Text(f.missing, "", "GameFontHighlightSmall", 0, -2, PW - 20)
    f.missing:SetScript("OnEnter", function(self)
        local r = ns.ClanRoll.cur
        local list = (r and r.open) and ns.ClanRoll.Missing(r) or {}
        if #list == 0 then return end
        local names = {}
        for _, k in ipairs(list) do names[#names + 1] = Who(k) end
        Tip(self, { string.format(L.CLANROLL_MISSING, #list), table.concat(names, ", ") })
    end)
    f.missing:SetScript("OnLeave", NoTip)

    f.result = Text(f, "", "GameFontHighlight", 10, -PH + 54, PW - 20)
    f.announce = WithTip(Button(f, L.CLANROLL_ANNOUNCE, 90, 10, -PH + 32, function()
        R.Announce(R.cur, CU.Prefs().whisper)
    end, 22), { L.CLANROLL_ANNOUNCE, L.CLANROLL_ANNOUNCE_TIP })
    local wc, wfs = UI.Check(f, L.CLANROLL_WHISPER_SHORT, 102, -PH + 31, CU.Prefs().whisper and true or false,
        function(on) CU.Prefs().whisper = on; UI.Dirty(); CU.RefreshPop() end)
    wc:SetHitRectInsets(0, -((wfs:GetStringWidth() or 60) + 6), 0, 0)
    WithTip(wc, { L.CLANROLL_WHISPER_WIN, L.CLANROLL_WHISPER_WIN_TIP })
    f.whisper, f.whisperText = wc, wfs
    f.reroll = WithTip(Button(f, L.CLANROLL_REROLL, 120, 170, -74, function() CU.Reroll() end, 24),
        { L.CLANROLL_REROLL, L.CLANROLL_REROLL_TIP })
    f:Hide()
    return f
end

function CU.StartFrom(f)
    local R = ns.ClanRoll
    if R.Busy() then return end
    local pr = CU.Prefs()
    if not R.AskedFor(f.race) then pr.msg = f.msg:GetText() end
    local r = R.Start({ race = f.race, msg = pr.msg, item = f.item:GetText(), timer = pr.timer,
        countdown = pr.countdown, others = pr.others, skip = pr.skip })
    if r then R.PostStart(r) end
    UI.Dirty()
    CU.RefreshPop()
end

function CU.RefreshPop()
    local f = pop
    if not f or not f:IsShown() then return end
    local R = ns.ClanRoll
    local r = R.cur
    -- An open roll shows, unless it's one I'm only following and this window was opened for another
    -- clan on purpose (an ask, or Pop out on that clan's panel: its setup and Start). Otherwise the clan
    -- it was opened for (OpenPop: that clan, or the latest roll's).
    local race
    if r and r.open and not (r.follower and f.pinned and f.pinned ~= r.race) then race = r.race
    else race = f.race or (r and r.race) or CU.lastRace or ns.Clans.MyRace() end
    if r and r.race ~= race then r = nil end
    f.race = race
    local pr, set = CU.Setup(race)
    local open = r and r.open
    local can = race and R.CanStart(race)
    local asked = R.AskedFor(race)
    f.title:SetText(ns.GOLD .. string.format(L.CLANROLL_TITLE, ns.Clans.RaceName(race)) .. "|r"
        .. (asked and (ns.GREY .. " " .. string.format(L.CLANROLL_ASKED_BY, asked.from:match("^%S+") or asked.from) .. "|r") or ""))

    local setup = can and not open
    f.setup:SetShown(setup and true or false)
    if setup then
        if set or not f.msg:HasFocus() then f.msg:SetText(pr.msg or "") end
        if set then f.item:SetText(set.item or "") elseif f.lockedBy then f.item:SetText("") end
        f.lockedBy = set or nil
        f.msg:SetEnabled(not set)
        f.item:SetEnabled(not set)
        f.timer:SetText(pr.timer > 0 and (pr.timer .. "s") or L.CLANROLL_TIMER_OFF)
        f.down:SetEnabled(not set and pr.timer > 0)
        f.up:SetEnabled(not set and pr.timer < R.TIMERS[#R.TIMERS])
        f.start:SetEnabled(not R.Busy())
    end
    f.head:SetShown(not setup)
    f.status:SetShown(not setup)
    if not setup then
        local head = r and R.Head(r) or ""
        if r and r.by ~= ns.me then head = string.format(L.CLANROLL_POP_BY, (r.by:match("^%S+") or r.by), head) end
        f.head:SetText(r and head or (ns.GREY .. L.CLANROLL_WHO_CAN .. "|r"))
        local status = ""
        if R.unreadable and open then status = "|cffff6060" .. L.CLANROLL_UNREADABLE .. "|r"
        elseif open and r.endsAt then status = string.format(L.CLANROLL_LEFT, math.max(0, math.ceil(r.endsAt - GetTime())))
        elseif open then status = ns.GREEN .. L.CLANROLL_ROLLING .. "|r"
        elseif r then status = ns.GREY .. L.CLANROLL_CLOSED .. "|r" end
        f.status:SetText(status)
    end
    f.stop:SetShown(open and r.by == ns.me or false)

    local list = r and R.Results(r) or {}
    f.resTitle:SetText(r and string.format(L.CLANROLL_RESULTS, #list) or "")
    for i, row in ipairs(f.rows) do
        local e = list[i]
        row:SetShown(e ~= nil)
        if e then
            local name = Who(e.name)
            if e.past then name = ns.GREY .. (e.name:match("^%S+") or e.name) .. "|r"
            elseif e.outsider then name = BLUE .. (e.name:match("^%S+") or e.name) .. "|r" end
            row.left:SetText(i .. ". " .. name)
            row.right:SetText((e.top and ns.GOLD or (e.past and ns.GREY or "")) .. e.roll .. "|r")
        end
    end
    local missing = open and R.Missing(r) or {}
    f.missText:SetText(open and string.format(L.CLANROLL_MISSING, #missing) .. (#missing > 0 and (ns.GREY .. "  " .. L.CLANROLL_HOVER .. "|r") or "") or "")

    f.result:SetText(CU.ResultText(r))
    local mine = MineDone(r)
    f.announce:SetShown(mine and can and true or false)
    f.whisper:SetShown(mine and can and true or false)
    f.whisperText:SetShown(mine and can and true or false)
    f.whisper:SetChecked(pr.whisper and true or false)
    f.whisper:SetEnabled(mine and r.winner ~= nil and r.winner ~= ns.me or false)
    -- A tie of mine: Reroll ties takes Start's place; Start moves to the bottom right.
    local tie = mine and r.ties ~= nil or false
    f.reroll:SetShown(tie)
    f.start:ClearAllPoints()
    if tie then
        f.start:SetPoint("TOPLEFT", f, "TOPLEFT", PW - 100, -PH + 32)
        f.start:SetWidth(90)
    else
        f.start:SetPoint("TOPLEFT", f.setup, "TOPLEFT", 170, -46)
        f.start:SetWidth(120)
    end
end

-- auto: opened by itself for a member (closes itself after the result).
function CU.OpenPop(auto, race)
    pop = pop or BuildPop()
    if not pop:IsShown() then pop.auto = auto and true or nil end
    -- No clan given (/ynm roll): the latest roll's, not whatever the window showed last time.
    local cur = ns.ClanRoll.cur
    pop.race = race or (cur and cur.race) or pop.race
    pop.pinned = (not auto and race) or nil
    if race and pop.msg then pop.msg:SetText(CU.Prefs().msg or "") end
    pop:Show()
    CU.RefreshPop()
end
function CU.ClosePop() if pop then pop:Hide(); pop.auto, pop.pinned = nil, nil end end
function CU.TogglePop()
    if pop and pop:IsShown() then CU.ClosePop() else CU.OpenPop(false) end
end
function CU.Pop() return pop end

-- Can I see this clan's roll already? The pop-out, or the main window on Clans > My Clan showing that
-- clan's roll (not its History; race nil: any clan).
function CU.RollVisible(race)
    if pop and pop:IsShown() then return true end
    if not (UI.Showing and UI.Showing("clans") and ns.settings.clanView == "mine") then return false end
    local p = CU.panel
    if not (p and p:IsShown() and not p.history) then return false end
    return race == nil or p.race == race
end

ns.Listen("CLANROLL_FOLLOW", function(r)
    if CU.RollVisible(r.race) then return end
    CU.OpenPop(true, r.race)
end)
ns.Listen("CLANROLL_OVER", function(r)
    if not (pop and pop:IsShown() and pop.auto) then return end
    local token = {}
    pop.closeToken = token
    C_Timer.After(CU.AUTO_CLOSE, function()
        local cur = ns.ClanRoll.cur
        if pop and pop.auto and pop.closeToken == token and not (cur and cur.open) then CU.ClosePop() end
    end)
end)
ns.Listen("CLANROLL", function() ns.Safe(CU.RefreshPop) end)

-- A leader asked to run their clan's roll (all clans): the roll filled in, the window open, a pop-up.
ns.Listen("CLANROLL_ASKED", function(a)
    CU.OpenPop(false, a.race)
    CU.RefreshPop()
    ns.Toast.nextTab = "clans"
    ns.Toast.Show(string.format(L.TOAST_ROLL_ASKED, a.from:match("^%S+") or a.from),
        string.format(L.TOAST_ROLL_ASKED_TEXT, string.format(L.CLAN_NAME, ns.Clans.RaceName(a.race))), nil)
    UI.Dirty()
end)
ns.Listen("CLANROLL_ALL", UI.Dirty)

-- All clans roll: the time left ticks over while a clan's roll runs.
local allTicker
ns.Listen("CLANROLL_ALL", function()
    if allTicker or not ns.ClanRoll.AllBusy() then return end
    allTicker = C_Timer.NewTicker(0.5, function()
        if not ns.ClanRoll.AllBusy() then allTicker:Cancel(); allTicker = nil end
        UI.Dirty()
    end)
end)

-- A leader: the one who asked called it off.
ns.Listen("CLANROLL_CANCELLED", function(from, race, handed)
    local clan = string.format(L.CLAN_NAME, ns.Clans.RaceName(race))
    ns.Toast.nextTab = "clans"
    if handed then
        ns.Toast.Show(L.TOAST_ROLL_HANDED, string.format(L.TOAST_ROLL_HANDED_TEXT, clan), nil)
    else
        ns.Toast.Show(string.format(L.TOAST_ROLL_CANCELLED, from:match("^%S+") or from),
            string.format(L.TOAST_ROLL_CANCELLED_TEXT, clan), nil)
    end
    CU.RefreshPop()
    UI.Dirty()
end)

-- Dev reset (/ynm dev rollreset): the setup back to the defaults, the windows closed, the heads clear.
ns.Listen("CLANROLL_RESET", function()
    ns.settings.clanRoll, ns.settings.clanRollAll = nil, nil
    local pr = CU.Prefs()
    for _, f in ipairs({ CU.panel or false, pop or false }) do
        if f then
            f.msg:SetText(pr.msg or "")
            f.msg:ClearFocus()
            f.item:SetText("")
            f.item:ClearFocus()
        end
    end
    if CU.panel then CU.panel.history, CU.panel.resOff, CU.panel.missOff, CU.panel.histOff = false, 0, 0, 0 end
    CU.ClosePop()
    if ns.Plates and ns.Plates.ClearRolls then ns.Plates.ClearRolls() end
    if big then big:Hide() end
    UI.Dirty()
end)

-- Shared with UI/ClanRollAll.lua (the all-clans view, laid out like this panel).
CU.W, CU.H, CU.ROW_H, CU.RES_ROWS, CU.HIST_ROWS = W, H, ROW_H, RES_ROWS, HIST_ROWS
CU.Edit, CU.Who, CU.Rows, CU.Wheel, CU.WithTip, CU.Tip, CU.NoTip = Edit, Who, Rows, Wheel, WithTip, Tip, NoTip

-- The all-clans roll: its own view on the Clans tab (UI/ClanRollAll.lua).
function CU.OpenAll()
    if not ns.ClanRoll.CanStartAll() then return end
    ns.settings.clanView = "roll"
    UI.Open("clans")
    UI.Dirty()
end

-- The setup to show for this clan: the guild master's or manager's when they asked me to run it (it
-- can't be changed then), else mine.
function CU.Setup(race)
    local a = race and ns.ClanRoll.AskedFor(race)
    if not a then return CU.Prefs(), nil end
    return { msg = a.msg, item = a.item, timer = a.timer, countdown = a.countdown, others = a.others, skip = a.skip,
        whisper = CU.Prefs().whisper }, a
end
