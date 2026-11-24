-- The all-clans roll view on the Clans tab (the guild master and managers), laid out like My Clan:
--   Left column (where My Clan has the roster): every clan, each with a tick box (which clans roll),
--     who would be asked (or was) with a dot (green: online with the addon; orange: an old version;
--     red: offline or no addon; grey: no leader set), and how its roll is going. All / None at the
--     bottom. Hover a clan for the details.
--   Right panel (like the Clan roll panel, UI/ClanRoll.lua): Message, Item, Timer, Countdown, Skip past
--     winners, all sent to each leader (their setup is locked to it; never non-clan members),
--     and Start roll (asks each ticked clan's leader). Under it: Winners and Still waiting on. At the bottom:
--     Announce (party or raid chat, or guild chat with Guild chat ticked) and Clear. History: the last
--     20 all-clans rolls.
-- The rules and messages are in ClanRoll.lua (R.StartAll, R.AnnounceAll, R.AllHistory).
local ADDON, ns = ...
local L = ns.L
local UI = ns.UI
local Text, Button = UI.Text, UI.Button

ns.ClanRollAllUI = {}
local CA = ns.ClanRollAllUI

local COL_W, COL_H = 140, 372
local BLOCK_H = 54                   -- one clan in the left column: name, who, status
local BLOCKS = 6
local MISS_ROWS = 9
local DOT = {
    green = "|TInterface\\COMMON\\Indicator-Green:12:12|t",
    orange = "|TInterface\\COMMON\\Indicator-Yellow:12:12|t",
    red = "|TInterface\\COMMON\\Indicator-Red:12:12|t",
    grey = "|TInterface\\COMMON\\Indicator-Gray:12:12|t",
}
local CROWN = "|TInterface\\GroupFrame\\UI-Group-LeaderIcon:12:12|t"
local ROW_DOT = { offline = "red", noaddon = "red", noanswer = "red", update = "orange", group = "orange", noleader = "grey",
    cancelled = "grey", noresult = "red" }

-- The guild master's setup for all-clans rolls (apart from their own clan roll's).
function CA.Prefs()
    local s = ns.settings
    if type(s.clanRollAll) ~= "table" then s.clanRollAll = {} end
    local p = s.clanRollAll
    if p.timer == nil then p.timer = 30 end
    if p.countdown == nil then p.countdown = true end
    if p.msg == nil then p.msg = L.CLANROLL_DEFAULT end
    if p.guild == nil then p.guild = true end         -- I'm rarely in every clan's group: guild chat
    if type(p.allOff) ~= "table" then p.allOff = {} end
    return p
end

-- Is this clan ticked? Every clan is, until unticked.
function CA.Ticked(race) return not CA.Prefs().allOff[race] end
function CA.SetTicked(race, on)
    CA.Prefs().allOff[race] = (not on) or nil
    UI.Dirty()
end
-- The ticked clans: { race -> true }, how many, out of how many.
function CA.TickedSet()
    local only, n, total = {}, 0, 0
    for _, c in ipairs(ns.Clans.List()) do
        total = total + 1
        if CA.Ticked(c.race) then only[c.race] = true; n = n + 1 end
    end
    return only, n, total
end

-- The clan's name in its colour.
local function ClanName(race)
    local c = ns.Plates and ns.Plates.COLOURS and ns.Plates.COLOURS[race]
    local name = string.format(L.CLAN_NAME, ns.Clans.RaceName(race))
    if not c then return name end
    return string.format("|cff%02x%02x%02x%s|r", c[1] * 255, c[2] * 255, c[3] * 255, name)
end

-- Who runs this clan's roll and how they look: name (or nil), dot, a short grey reason line.
local function Runner(race, row)
    if row then
        local dot = ROW_DOT[row.status] or "green"
        return row.to, DOT[dot], ns.ClanRollUI.AllStatus(row)
    end
    local who, why = ns.ClanRoll.PickLeader(race)
    if who then
        if why == true then return who, DOT.orange, "|cffff9020" .. L.CLANROLL_ALL_OLD .. "|r" end
        return who, DOT.green, ""
    end
    local s = { offline = "offline", noaddon = "noaddon", noleader = "noleader" }
    return nil, DOT[ROW_DOT[why] or "grey"], ns.ClanRollUI.AllStatus({ status = s[why] or "noleader" })
end

---------------------------------------------------------------------------------------------------
-- Left: the clans

function CA.BuildColumn(parent, x, y)
    local CU = ns.ClanRollUI
    local c = UI.Box(parent, x, y, COL_W, COL_H)
    c.title = Text(c, ns.GOLD .. L.CLANROLL_ALL_CLANS .. "|r", "GameFontNormal", 8, -8, 60)
    c.count = Text(c, "", "GameFontDisableSmall", 60, -10, COL_W - 68, "RIGHT")
    local line = c:CreateTexture(nil, "ARTWORK")
    line:SetColorTexture(0.9, 0.76, 0.36, 0.5)
    line:SetPoint("TOPLEFT", 6, -26)
    line:SetSize(COL_W - 12, 1)
    c.blocks = {}
    for i = 1, BLOCKS do
        local b = UI.Row(c, 4, -30 - (i - 1) * BLOCK_H, COL_W - 8, BLOCK_H - 2)
        b.stripe:SetShown(i % 2 == 0)
        b.name = Text(b, "", "GameFontNormal", 26, -5, COL_W - 38)
        b.who = Text(b, "", "GameFontHighlightSmall", 8, -22, COL_W - 20)
        b.status = Text(b, "", "GameFontHighlightSmall", 8, -36, COL_W - 20)
        b.tick = UI.Check(b, "", 2, -1, true, function(on) if b.race then CA.SetTicked(b.race, on) end end)
        b.tick:SetSize(22, 22)
        b.tick:SetFrameLevel(b:GetFrameLevel() + 2)
        CU.WithTip(b.tick, { L.CLANROLL_ALL_TITLE, L.CLANROLL_ALL_PICK_TIP })
        b:SetScript("OnEnter", function(self)
            self.hl:Show()
            if not self.race then return end
            local all = ns.ClanRoll.all
            local row = all and all.clans[self.race]
            local who, _, why = Runner(self.race, row)
            local lines = { ClanName(self.race) }
            if who then lines[#lines + 1] = string.format(row and L.CLANROLL_ALL_WHO or L.CLANROLL_ALL_WOULD, who) end
            if why ~= "" then lines[#lines + 1] = why end
            if not row then lines[#lines + 1] = ns.GREY .. L.CLANROLL_ALL_PICK_TIP .. "|r" end
            CU.Tip(self, lines)
        end)
        b:SetScript("OnLeave", function(self) self.hl:Hide(); CU.NoTip() end)
        b:SetScript("OnClick", function(self)
            if self.race then CA.SetTicked(self.race, not CA.Ticked(self.race)) end
        end)
        b:Hide()
        c.blocks[i] = b
    end
    c.all = Button(c, L.CLANROLL_ALL_TICK_ALL, 60, 6, -COL_H + 30, function()
        wipe(CA.Prefs().allOff)
        UI.Dirty()
    end, 22)
    c.none = Button(c, L.CLANROLL_ALL_TICK_NONE, 60, COL_W - 66, -COL_H + 30, function()
        for _, cl in ipairs(ns.Clans.List()) do CA.Prefs().allOff[cl.race] = true end
        UI.Dirty()
    end, 22)
    return c
end

function CA.RefreshColumn(c)
    local list = ns.Clans.List()
    local all = ns.ClanRoll.all
    local _, n, total = CA.TickedSet()
    c.count:SetText(string.format(L.CLANROLL_ALL_PICKED, n, total))
    for i, b in ipairs(c.blocks) do
        local cl = list[i]
        b.race = cl and cl.race
        b:SetShown(cl ~= nil)
        if cl then
            local row = all and all.clans[cl.race]
            b.tick:SetChecked(CA.Ticked(cl.race))
            b.name:SetText(ClanName(cl.race))
            local who, dot, why = Runner(cl.race, row)
            b.who:SetText(dot .. " " .. (who and ns.ClanRollUI.Who(who) or (ns.GREY .. "-|r")))
            b.status:SetText(why)
        end
    end
end

---------------------------------------------------------------------------------------------------
-- Right: the roll, laid out like the Clan roll panel

function CA.BuildPanel(parent, x, y)
    local CU = ns.ClanRollUI
    local R = ns.ClanRoll
    local W, H = CU.W, CU.H
    local Edit, WithTip, Rows = CU.Edit, CU.WithTip, CU.Rows
    local p = UI.Box(parent, x, y, W, H)
    local prefs = CA.Prefs()

    p.title = Text(p, ns.GOLD .. L.CLANROLL_ALL_TITLE .. "|r", "GameFontNormal", 12, -10, 280)
    p.histBtn = WithTip(Button(p, L.CLANROLL_HISTORY, 90, W - 100, -6, function()
        p.history = not p.history
        p.histOff = 0
        UI.Dirty()
    end, 22), { L.CLANROLL_HISTORY, L.CLANROLL_ALL_HIST_TIP })

    -- Setup: everything here goes to each leader.
    local sy = -34
    Text(p, L.CLANROLL_MSG, "GameFontNormalSmall", 12, sy - 4, 60)
    p.msg = Edit(p, 66, sy, 150, 40)
    p.msg:SetText(prefs.msg)
    p.msg:SetScript("OnTextChanged", function(self, user) if user then CA.Prefs().msg = self:GetText() end end)
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
        CA.Prefs().timer = R.StepTimer(CA.Prefs().timer, -1); UI.Dirty()
    end, 20), { L.CLANROLL_TIMER, L.CLANROLL_TIMER_TIP })
    p.timer = Text(p, "", "GameFontHighlight", 84, sy - 4, 40, "CENTER")
    p.up = WithTip(Button(p, ">", 22, 126, sy, function()
        CA.Prefs().timer = R.StepTimer(CA.Prefs().timer, 1); UI.Dirty()
    end, 20), { L.CLANROLL_TIMER, L.CLANROLL_TIMER_TIP })
    local function Tick(label, key, tip, cx, cy)
        local c, fs = UI.Check(p, label, cx, cy, CA.Prefs()[key] and true or false, function(on) CA.Prefs()[key] = on; UI.Dirty() end)
        c:SetHitRectInsets(0, -((fs:GetStringWidth() or 100) + 6), 0, 0)
        WithTip(c, { label, tip })
        return c, fs
    end
    p.countdown = Tick(L.CLANROLL_COUNTDOWN, "countdown", L.CLANROLL_COUNTDOWN_TIP, 160, sy + 2)
    -- No "Let non-clan members roll": in one raid, someone's /roll would count in every clan's roll.
    p.skip = Tick(L.CLANROLL_SKIP, "skip", L.CLANROLL_SKIP_TIP, 280, sy + 2)
    sy = sy - 24
    -- Start roll (asks the ticked clans); while it's going, Cancel (the time left beside it).
    p.start = Button(p, L.CLANROLL_ALL_START, 130, 12, sy - 2, function()
        if R.AllBusy() then R.CancelAll() else CA.Ask(p) end
        UI.Dirty()
    end, 24)
    p.start:SetScript("OnEnter", function(self)
        if R.AllBusy() then CU.Tip(self, { L.CLANROLL_ALL_CANCEL, L.CLANROLL_ALL_CANCEL_TIP })
        else CU.Tip(self, { L.CLANROLL_ALL_START, L.CLANROLL_ALL_START_TIP }) end
    end)
    p.start:SetScript("OnLeave", CU.NoTip)
    p.status = Text(p, "", "GameFontHighlight", 150, sy - 7, 125)

    -- Winners and who's still going
    local ly = -126
    local line = p:CreateTexture(nil, "ARTWORK")
    line:SetColorTexture(0.9, 0.76, 0.36, 0.35)
    line:SetPoint("TOPLEFT", 10, ly + 6)
    line:SetSize(W - 20, 1)
    p.resTitle = Text(p, L.CLANROLL_ALL_WINNERS, "GameFontNormalSmall", 12, ly, 300)
    p.missTitle = Text(p, L.CLANROLL_ALL_PENDING, "GameFontNormalSmall", 340, ly, 230)
    p.res = Rows(p, 10, ly - 16, 310, CU.RES_ROWS)
    p.miss = Rows(p, 338, ly - 16, 238, MISS_ROWS)
    for _, r in ipairs(p.miss) do
        r.left:SetWidth(100)
        r.right:ClearAllPoints()
        r.right:SetPoint("TOPLEFT", 104, -2)
        r.right:SetWidth(130)
    end
    p.hist = Rows(p, 10, ly - 16, W - 20, CU.HIST_ROWS)
    for _, r in ipairs(p.hist) do
        r.left:SetWidth(W - 130)
        r.right:ClearAllPoints()
        r.right:SetPoint("TOPLEFT", W - 124, -2)
        r.right:SetWidth(100)
        r:SetScript("OnEnter", function(self)
            self.hl:Show()
            local e = self.entry
            if not e then return end
            local lines = { (e.msg or "") .. (e.item and (" " .. R.ItemName(e.item)) or "") }
            for _, cl in ipairs(ns.Clans.List()) do
                local res = e.clans and e.clans[cl.race]
                if res then
                    local st = CU.AllStatus({ status = res.st, winner = res.w, roll = res.n })
                    lines[#lines + 1] = ClanName(cl.race) .. "  " .. st
                end
            end
            CU.Tip(self, lines)
        end)
        r:SetScript("OnLeave", function(self) self.hl:Hide(); CU.NoTip() end)
    end
    CU.Wheel(p, p.hist, "histOff")

    -- After: Announce (+ Guild chat), Clear
    local by = -H + 34
    p.announce = WithTip(Button(p, L.CLANROLL_ANNOUNCE, 100, 12, by, function()
        R.AnnounceAll(R.all, CA.Prefs().guild)
    end, 24), { L.CLANROLL_ANNOUNCE, L.CLANROLL_ALL_ANNOUNCE_TIP })
    p.guild = Tick(L.CLANROLL_ALL_GUILD, "guild", L.CLANROLL_ALL_GUILD_TIP, 118, by)
    p.clear = WithTip(Button(p, L.CLANROLL_ALL_CLEAR, 80, 290, by, function() R.ClearAll() end, 24),
        { L.CLANROLL_ALL_CLEAR, L.CLANROLL_ALL_CLEAR_TIP })
    p.result = Text(p, "", "GameFontHighlight", 380, by - 5, W - 392, "RIGHT")   -- the overall winner
    return p
end

function CA.Ask(p)
    if ns.ClanRoll.AllBusy() then return end        -- one at a time: Cancel first
    local pr = CA.Prefs()
    pr.msg = p.msg:GetText()
    local only = CA.TickedSet()
    ns.ClanRoll.StartAll({ msg = pr.msg, item = p.item:GetText(), timer = pr.timer, countdown = pr.countdown,
        skip = pr.skip, only = only })
    p.history = false
    UI.Dirty()
end

-- The overall winner in words: "Winner: Bingo (Orc) 88", "Tied on 88: Bingo (Orc), Muffin (Scourge)", or
-- while clans are still going "Leading: ...".
function CA.TopText(clans, going)
    local top, roll = ns.ClanRoll.TopOf(clans)
    if not top then return "" end
    local CU = ns.ClanRollUI
    local function One(t) return CU.Who(t.winner) .. ns.GREY .. " (" .. ns.Clans.RaceName(t.race) .. ")|r" end
    local gold = ns.GOLD .. roll .. "|r"
    if going then return string.format(L.CLANROLL_ALL_LEADING, One(top[1]), gold) end
    if #top > 1 then
        local names = {}
        for _, t in ipairs(top) do names[#names + 1] = One(t) end
        return string.format(L.CLANROLL_ALL_TOP_TIE, gold, table.concat(names, ", "))
    end
    return ns.GOLD .. string.format(L.CLANROLL_ALL_TOP, One(top[1]), gold) .. "|r"
end

local function Done(row) return row.status == "won" or row.status == "none" end

function CA.RefreshPanel(p)
    local R, CU = ns.ClanRoll, ns.ClanRollUI
    local pr = CA.Prefs()
    if not p.msg:HasFocus() then p.msg:SetText(pr.msg or "") end
    p.timer:SetText(pr.timer > 0 and (pr.timer .. "s") or L.CLANROLL_TIMER_OFF)
    p.down:SetEnabled(pr.timer > 0)
    p.up:SetEnabled(pr.timer < R.TIMERS[#R.TIMERS])
    p.countdown:SetEnabled(pr.timer > 0)
    p.countdown:SetChecked(pr.countdown and true or false)
    p.skip:SetChecked(pr.skip and true or false)
    p.guild:SetChecked(pr.guild and true or false)
    local _, n = CA.TickedSet()
    local all = R.all
    local busy = R.AllBusy(all)
    p.start:SetText(busy and ("|cffff6060" .. L.CLANROLL_ALL_CANCEL .. "|r") or L.CLANROLL_ALL_START)
    p.start:SetEnabled(busy or n > 0)
    local left = busy and R.AllLeft(all)
    if left then p.status:SetText(string.format(L.CLANROLL_LEFT, left))
    elseif all then p.status:SetText(string.format(L.CLANROLL_ALL_ASKED, #all.order))
    else p.status:SetText(ns.GREY .. L.CLANROLL_ALL_HINT .. "|r") end
    p.histBtn:SetText(p.history and L.CLANROLL_BACK or L.CLANROLL_HISTORY)

    local hist = p.history
    for _, f in ipairs({ p.resTitle, p.missTitle }) do f:SetShown(not hist) end
    for _, r in ipairs(p.res) do r:Hide() end
    for _, r in ipairs(p.miss) do r:Hide() end
    for _, r in ipairs(p.hist) do r:Hide() end
    if hist then
        local h = R.AllHistory()
        local off = math.max(0, math.min(p.histOff or 0, #h - #p.hist))
        p.histOff = off
        for i, row in ipairs(p.hist) do
            local e = h[#h - off - i + 1]
            row.entry = e
            row:SetShown(e ~= nil)
            if e then
                local won, asked = 0, 0
                for _, x in pairs(e.clans or {}) do
                    asked = asked + 1
                    if Done({ status = x.st }) then won = won + 1 end
                end
                local what = (e.msg or "") .. (e.item and (" " .. R.ItemName(e.item)) or "")
                local clans = {}
                for race, x in pairs(e.clans or {}) do clans[race] = { status = x.st, winner = x.w, roll = x.n } end
                local top = R.TopOf(clans) and CA.TopText(clans, false) or (ns.GREY .. string.format(L.CLANROLL_ALL_DONE, won, asked) .. "|r")
                row.left:SetText(ns.GREY .. date("%d %b %H:%M", e.at or 0) .. "|r  " .. what .. "  " .. top)
                row.right:SetText(ns.GREY .. string.format(L.CLANROLL_HIST_BY, (e.by or "?"):match("^%S+") or "?") .. "|r")
            end
        end
    else
        local winners, pending = {}, {}
        for _, race in ipairs(all and all.order or {}) do
            local row = all.clans[race]
            if Done(row) then winners[#winners + 1] = race else pending[#pending + 1] = race end
        end
        table.sort(winners, function(a, b) return (all.clans[a].roll or -1) > (all.clans[b].roll or -1) end)
        local top, roll = R.TopOf(all and all.clans)
        for i, row in ipairs(p.res) do
            local race = winners[i]
            row:SetShown(race ~= nil)
            if race then
                local x = all.clans[race]
                local crown = (top and roll == x.roll and x.winner) and (CROWN .. " ") or ""
                row.left:SetText(crown .. ClanName(race) .. "  " .. (x.winner and CU.Who(x.winner) or (ns.GREY .. L.CLANROLL_ALL_NONE .. "|r")))
                row.right:SetText(x.roll and (ns.GOLD .. x.roll .. "|r") or "")
            end
        end
        for i, row in ipairs(p.miss) do
            local race = pending[i]
            row:SetShown(race ~= nil)
            if race then
                row.left:SetText(ClanName(race))
                row.right:SetText(CU.AllStatus(all.clans[race]))
            end
        end
        p.resTitle:SetText(all and string.format(L.CLANROLL_ALL_WINNERS_DONE, #winners, #all.order) or L.CLANROLL_ALL_WINNERS)
        p.result:SetText(all and CA.TopText(all.clans, R.AllBusy(all)) or "")
    end
    p.result:SetShown(not hist and all ~= nil)
    p.announce:SetEnabled(all ~= nil and #R.AllLines(all) > 0)
    p.clear:SetShown(all ~= nil and not busy)          -- while it's going, Cancel is the way
end

function CA.Refresh(col, panel)
    CA.RefreshColumn(col)
    CA.RefreshPanel(panel)
end
