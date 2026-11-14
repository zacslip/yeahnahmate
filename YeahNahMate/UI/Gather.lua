-- The organiser's Gather list, shown on the right of the Calendar tab while they gather for an event:
-- who asked for an invite, who's going and online, who's in the group. Invite on each, "Invite next"
-- (one invite per click), "Make it a raid". Everyone the organiser invites lands on their layer.
local ADDON, ns = ...
local L = ns.L
local UI = ns.UI
local Text, Button, Row = UI.Text, UI.Button, UI.Row

local ROWS = 10
local STATE = {
    asked = { "|cffffd100", "ASKED" }, going = { "|cffffffff", "GOING_ONLINE" },
    ingroup = { "|cff40ff40", "IN_GROUP" }, offline = { "|cff9d9d9d", "OFFLINE" },
}

-- Builds the list into the Calendar page p, at x, w wide.
function UI.GatherBuild(p, x, w)
    local f = CreateFrame("Frame", nil, p)
    f:SetAllPoints()
    f:Hide()
    p.gatherFrame = f
    f.offset = 0
    f.title = Text(f, "", "GameFontNormal", x, -4, w - 64)
    Button(f, L.BACK, 56, x + w - 56, 0, function() p.mode = nil; UI.Dirty() end, 22)
    f.counts = Text(f, "", "GameFontHighlightSmall", x, -28, w)
    f.raid = Button(f, L.MAKE_RAID, 124, x, -44, function() ns.Gather.MakeRaid() end, 22)
    f.stop = Button(f, L.STOP_GATHER, 128, x + w - 128, -44, function()
        ns.Gather.Stop()
        p.mode = nil
        UI.Dirty()
    end, 22)
    f.rows = {}
    for i = 1, ROWS do
        local r = Row(f, x, -72 - (i - 1) * 26, w, 24)
        r.name = Text(r, "", "GameFontHighlightSmall", 4, -6, 124)
        r.state = Text(r, "", "GameFontHighlightSmall", 130, -6, 70)
        r.invite = Button(r, L.INVITE, 56, w - 58, -1, function() if r.who then ns.Gather.Invite(r.who) end end, 22)
        r:EnableMouseWheel(true)
        r:SetScript("OnMouseWheel", function(_, d) f.offset = math.max(0, f.offset - d); UI.Dirty() end)
        f.rows[i] = r
    end
    f.empty = Text(f, L.GATHER_EMPTY, "GameFontDisableSmall", x + 4, -78, w - 8)
    f.empty:SetWordWrap(true)
    f.empty:SetHeight(56)
    f.empty:SetJustifyV("TOP")
    f.pager = UI.Pager(f, x + w - 142, -334, function(d) f.offset = math.max(0, f.offset + d * ROWS); UI.Dirty() end)
    f.next = Button(f, "", w, x, -358, function() ns.Gather.InviteNext() end, 28)
    f.tip = Text(f, L.GATHER_TIP, "GameFontDisableSmall", x, -390, w)
end

function UI.GatherRefresh(p)
    local f = p.gatherFrame
    local G = ns.Gather
    local mine = G.Mine()
    if not mine then return end
    local e = ns.Calendar.Store()[mine.key]
    f.title:SetText(string.format(L.GATHERING_FOR, e and e.title or "?", UI.TimeText(mine.at)))
    local list = G.List()
    local asked, going = 0, 0
    for _, row in ipairs(list) do
        if row.state == "asked" then asked = asked + 1 elseif row.state == "going" then going = going + 1 end
    end
    f.counts:SetText(string.format(L.GATHER_COUNTS, G.InGroupCount(), asked, going))
    f.raid:SetShown(G.CanMakeRaid())
    local off = math.min(f.offset, math.max(0, #list - ROWS))
    f.offset = off
    f.empty:SetShown(#list == 0)
    f.pager.Set(off + 1, math.min(#list, off + ROWS), #list)
    for i, r in ipairs(f.rows) do
        local row = list[off + i]
        r.who = row and row.name
        if row then
            local m = ns.Guild.Get(row.name)
            local st = STATE[row.state]
            r.name:SetText(m and UI.Name(m, true) or row.name)
            r.state:SetText(st[1] .. L["GATHER_" .. st[2]] .. "|r")
            r.invite:SetShown(row.state == "asked" or row.state == "going")
            r.stripe:SetColorTexture(1, 1, 1, (i % 2 == 0) and 0.04 or 0)
            r:Show()
        else
            r:Hide()
        end
    end
    local nextName = G.Next()
    f.next:SetEnabled(nextName ~= nil)
    f.next:SetText(nextName and string.format(L.INVITE_NEXT, nextName:match("^%S+") or nextName) or L.NOBODY_WAITING)
end
