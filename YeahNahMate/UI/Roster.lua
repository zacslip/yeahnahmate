-- Roster tab: the real guild roster with four filters, scrolled with the mouse wheel. Each name has
-- the guildie's role icons in front; Race is a column (both from the Clans tab).
local ADDON, ns = ...
local L = ns.L
local UI = ns.UI
local Text, Button, Row = UI.Text, UI.Button, UI.Row

local ROWS = 14
-- label, x, width, sort key. The first column is the addon tick; the name has the guildie's role
-- icons (Clans tab) in front of it.
local COLS = {
    { UI.TICK, 4, 18, "addon" }, { L.COL_NAME, 24, 150, "name" }, { L.COL_LEVEL, 178, 30, "level" },
    { L.COL_CLASS, 210, 58, "class" }, { L.COL_RACE, 270, 62, "race" }, { L.COL_ZONE, 334, 100, "zone" },
    { L.COL_STATUS, 436, 68, "status" }, { L.COL_RANK, 506, 92, "rank" },
}
local NAME_COL = 2
local UP = " |TInterface\\Buttons\\Arrow-Up-Up:12:12:0:-2|t"
local DOWN = " |TInterface\\Buttons\\Arrow-Down-Up:12:12:0:2|t"

-- Click a column title to sort by it; click it again to reverse. A third click goes back to the
-- default order (closest level first). Online guildies always stay on top. Not kept after /reload.
local function ClickSort(p, key)
    if p.sortKey ~= key then
        p.sortKey, p.sortDesc = key, false
    elseif not p.sortDesc then
        p.sortDesc = true
    else
        p.sortKey, p.sortDesc = nil, nil
    end
    p.offset = 0
    UI.Dirty()
end

local function Build(p)
    p.filter = ns.Roster.ONLINE
    p.offset = 0
    local pick = UI.Choice(p, { L.FILTER_ONLINE, L.FILTER_NEAR, L.FILTER_ZONE, L.FILTER_ALL }, 0, 0, 100, function(i)
        p.filter, p.offset = i, 0
        if p:IsShown() then UI.Dirty() end
    end)
    -- Search by name: looks through every member, online or not, whatever the filter.
    local box = CreateFrame("EditBox", nil, p, "InputBoxTemplate")
    box:SetSize(130, 22)
    box:SetPoint("TOPLEFT", 424, 0)
    box:SetAutoFocus(false)
    box:SetMaxLetters(40)
    box:SetScript("OnEscapePressed", function(self) self:SetText(""); self:ClearFocus() end)
    box:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
    box:SetScript("OnTextChanged", function() p.offset = 0; if p:IsShown() then UI.Dirty() end end)
    box:SetScript("OnEditFocusGained", function() p.hint:Hide() end)
    box:SetScript("OnEditFocusLost", function(self) p.hint:SetShown((self:GetText() or "") == "") end)
    p.search = box
    p.hint = Text(p, L.ROSTER_SEARCH_HINT, "GameFontDisableSmall", 428, -6, 124)
    p.count = Text(p, "", "GameFontDisableSmall", 560, -6, 130, "RIGHT")
    p.up = Button(p, "^", 22, 694, -1, function() p.offset = math.max(0, p.offset - ROWS); UI.Dirty() end, 20)
    p.down = Button(p, "v", 22, 716, -1, function() p.offset = p.offset + ROWS; UI.Dirty() end, 20)

    p.heads = {}
    for _, c in ipairs(COLS) do
        local h = CreateFrame("Button", nil, p)
        h:SetPoint("TOPLEFT", c[2] - 2, -28)
        h:SetSize(c[3] + 4, 18)
        h.label = Text(h, c[1], "GameFontNormalSmall", 2, -4, c[3] + 2)
        h.key = c[4]
        h:SetScript("OnClick", function() ClickSort(p, c[4]) end)
        h:SetScript("OnEnter", function(self)
            self.label:SetTextColor(1, 1, 1)
            if GameTooltip then
                GameTooltip:SetOwner(self, "ANCHOR_TOP")
                GameTooltip:AddLine(L.SORT_TIP, 1, 1, 1)
                GameTooltip:Show()
            end
        end)
        h:SetScript("OnLeave", function(self)
            self.label:SetTextColor(1, 0.82, 0)
            if GameTooltip then GameTooltip:Hide() end
        end)
        p.heads[#p.heads + 1] = h
    end
    local line = p:CreateTexture(nil, "ARTWORK")
    line:SetColorTexture(0.9, 0.76, 0.36, 0.35)
    line:SetPoint("TOPLEFT", 0, -46)
    line:SetSize(736, 1)

    p.rows = {}
    for i = 1, ROWS do
        local r = Row(p, 0, -50 - (i - 1) * 23, 736, 22)
        r.cells = {}
        for j, c in ipairs(COLS) do
            r.cells[j] = Text(r, "", j == NAME_COL and "GameFontHighlight" or "GameFontHighlightSmall", c[2], j == NAME_COL and -4 or -5, c[3])
        end
        r.invite = Button(r, L.INVITE, 60, 602, 0, function() if r.m then UI.Invite(r.m) end end, 20)
        r.whisper = Button(r, L.WHISPER, 66, 666, 0, function() if r.m then ns.Whisper.Open(r.m) end end, 20)
        r:SetScript("OnEnter", function(self) self.hl:Show(); if self.m then UI.MemberTooltip(self, self.m) end end)
        r:SetScript("OnLeave", function(self) self.hl:Hide(); if GameTooltip then GameTooltip:Hide() end end)
        p.rows[i] = r
    end
    p.empty = Text(p, "", "GameFontDisableSmall", 8, -56, 720)

    p:EnableMouseWheel(true)
    p:SetScript("OnMouseWheel", function(_, delta)
        p.offset = math.max(0, p.offset - delta * 3)
        UI.Dirty()
    end)

    p.key = Text(p, "", "GameFontDisableSmall", 4, -376, 732)
    p.ranks = Text(p, "", "GameFontDisableSmall", 4, -392, 732)
    pick(ns.Roster.ONLINE)
end

-- The rank markers' key: the guild's own rank names, from the roster.
local function RankKey()
    local names = {}
    for _, r in ipairs(ns.Board.Ranks()) do names[r.index] = r.name end
    local parts = { UI.RANK_GM .. " " .. (names[0] or L.RANK_GM) }
    if names[1] then parts[#parts + 1] = UI.RANK_SECOND .. " " .. names[1] end
    local more = {}
    for i = 2, 9 do if names[i] and ns.Board.RankModeratesAny(i) then more[#more + 1] = names[i] end end
    if #more > 0 then parts[#parts + 1] = UI.RANK_OFFICER .. " " .. table.concat(more, ", ") end
    return table.concat(parts, "     ")
end

local function Refresh(p)
    local me, zone = ns.Roster.MyLevel(), ns.Roster.MyZone()
    local sortKey, desc = p.sortKey, p.sortDesc
    if sortKey and not ns.Roster.SORTS[sortKey] then sortKey = nil end
    for i, h in ipairs(p.heads) do
        h.label:SetText(COLS[i][1] .. ((h.key == sortKey) and (desc and DOWN or UP) or ""))
    end
    local query = p.search:GetText() or ""
    p.hint:SetShown(query == "" and not p.search:HasFocus())
    local list = ns.Roster.Get(p.filter, sortKey, desc, query)
    local maxOffset = math.max(0, #list - ROWS)
    if p.offset > maxOffset then p.offset = maxOffset end
    p.up:SetEnabled(p.offset > 0)
    p.down:SetEnabled(p.offset < maxOffset)
    if #list == 0 then
        p.count:SetText(L.SHOWN_NONE)
    else
        p.count:SetText(string.format(L.SHOWN, p.offset + 1, math.min(#list, p.offset + ROWS), #list))
    end
    local empty = ""
    if not ns.Guild.loaded and ns.Guild.name then empty = L.ROSTER_LOADING
    elseif #list == 0 and strtrim(query) ~= "" then empty = string.format(L.ROSTER_NO_MATCH, strtrim(query)) end
    p.empty:SetText(empty)

    for i, r in ipairs(p.rows) do
        local m = list[p.offset + i]
        r.m = m
        if m then
            local isMe = m.name == ns.me
            local near = ns.Roster.IsNear(m, me)
            local dim = m.online and "" or ns.GREY
            r.cells[1]:SetText(ns.Roster.HasAddon(m) and UI.TICK or "")
            local icon = UI.RankIcon(m)
            local roles = UI.RoleIcons(ns.Clans.Roles(m.name))
            r.cells[2]:SetText((roles ~= "" and (roles .. " ") or "") .. UI.Name(m, true) .. (icon and (" " .. icon) or "")
                .. (isMe and (ns.GREY .. " (" .. L.YOU .. ")|r") or ""))
            r.cells[3]:SetText((near and ns.GREEN or dim) .. m.level .. "|r")
            r.cells[4]:SetText(dim .. ns.ClassName(m.class) .. "|r")
            local race = ns.Clans.Race(m.name)
            r.cells[5]:SetText(dim .. (race and ns.Clans.RaceName(race) or "") .. "|r")
            if m.online then
                r.cells[6]:SetText(((m.zone == zone) and ns.GREEN or "") .. m.zone .. "|r")
                r.cells[7]:SetText(ns.Status.Text(m))
            else
                r.cells[6]:SetText(ns.GREY .. L.OFFLINE .. "|r")
                r.cells[7]:SetText("")
            end
            r.cells[8]:SetText(dim .. m.rank .. "|r")
            if near then r.stripe:SetColorTexture(0.25, 1, 0.25, 0.10)
            else r.stripe:SetColorTexture(1, 1, 1, (i % 2 == 0) and 0.04 or 0) end
            local canAct = m.online and not isMe
            r.invite:SetShown(canAct)
            r.whisper:SetShown(canAct)
            r:Show()
        else
            r:Hide()
        end
    end
    p.key:SetText(string.format(L.ROSTER_KEY, ns.Roster.Range(), UI.TICK))
    p.ranks:SetText(RankKey())
end

UI.AddPage("roster", Build, Refresh)
