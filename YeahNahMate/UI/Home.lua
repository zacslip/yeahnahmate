-- Home tab: hello, the officers' message, four numbers, who's near you right now, what's next,
-- open questions (Ask tab), who's live.
local ADDON, ns = ...
local L = ns.L
local UI = ns.UI
local Text, Button, Box, Header, Row = UI.Text, UI.Button, UI.Box, UI.Header, UI.Row

local function Build(p)
    p.hello = Text(p, "", "GameFontNormalLarge", 6, -4)
    -- The officers' message (Info tab), else the game's guild message of the day.
    local banner = Box(p, 0, -26, 736, 64)
    banner:EnableMouse(true)
    banner:SetScript("OnMouseUp", function() UI.Select("info") end)
    p.sub = Text(banner, "", "GameFontHighlightSmall", 12, -8, 712)
    p.sub:SetWordWrap(true)
    p.sub:SetHeight(48)
    -- The guild's Discord invite, right under the message (up the top, near the message).
    p.dcLabel = Text(banner, ns.GOLD .. L.DISCORD .. "|r", "GameFontNormal", 12, -40, 104)
    p.dcBox = UI.CopyBox(banner, 112, -36, 230)
    p.dcHint = Text(banner, L.COPY_HINT, "GameFontDisableSmall", 362, -40, 300)
    p.sub:SetJustifyV("TOP")

    p.stats = {}
    local labels = {
        { L.STAT_ONLINE, "roster" }, { L.STAT_NEAR, "roster" },
        { L.STAT_GROUPS, "dungeons" }, { L.STAT_REQUESTS, "professions" },
    }
    local bw = (736 - 3 * 10) / 4
    for i, s in ipairs(labels) do
        local b = Box(p, (i - 1) * (bw + 10), -96, bw, 60)
        b:EnableMouse(true)
        b:SetScript("OnMouseUp", function()
            UI.Select(s[2])
            if s[1] == L.STAT_REQUESTS and UI.ShowRequests then UI.ShowRequests() end
        end)
        b.num = Text(b, "", "GameFontHighlightLarge", 12, -8)
        b.label = Text(b, s[1], "GameFontNormalSmall", 12, -31)
        b.extra = Text(b, "", "GameFontDisableSmall", 12, -43, bw - 20)
        p.stats[i] = b
    end
    -- "Guildies online" opens the guild breakdown (classes, levels, professions...).
    local online = p.stats[1]
    online:SetScript("OnMouseUp", function() UI.Select("breakdown") end)
    Text(online, ns.GOLD .. L.STAT_BREAKDOWN .. "|r", "GameFontNormalSmall", bw - 96, -10, 86, "RIGHT")
    online:SetScript("OnEnter", function(self)
        if not GameTooltip then return end
        GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
        GameTooltip:AddLine(L.STAT_BREAKDOWN_TIP, 1, 1, 1, true)
        GameTooltip:Show()
    end)
    online:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)

    Header(p, L.NEAR_HEADER, 0, -166, 440)
    p.near = {}
    for i = 1, 7 do
        local r = Row(p, 0, -188 - (i - 1) * 26, 440, 24)
        r.name = Text(r, "", "GameFontHighlight", 6, -5, 170)
        r.info = Text(r, "", "GameFontHighlightSmall", 180, -6, 112)
        r.whisper = Button(r, L.WHISPER, 66, 296, -1, nil, 22)
        r.invite = Button(r, L.INVITE, 66, 366, -1, nil, 22)
        r:SetScript("OnEnter", function(self) self.hl:Show(); if self.m then UI.MemberTooltip(self, self.m) end end)
        r:SetScript("OnLeave", function(self) self.hl:Hide(); if GameTooltip then GameTooltip:Hide() end end)
        r.whisper:SetScript("OnClick", function() if r.m then ns.Whisper.Open(r.m) end end)
        r.invite:SetScript("OnClick", function() if r.m then UI.Invite(r.m) end end)
        p.near[i] = r
    end
    p.nearNone = Text(p, "", "GameFontDisableSmall", 6, -192, 430)

    Header(p, L.NEXT_UP, 462, -166, 274)
    p.next = {}
    for i = 1, 4 do
        local r = UI.Row(p, 462, -188 - (i - 1) * 40, 274, 38)
        r.title = Text(r, "", "GameFontHighlight", 6, -4, 262)
        r.when = Text(r, "", "GameFontHighlightSmall", 6, -21, 262)
        r.ask = Button(r, L.ASK_SHORT, 60, 208, -8, function() if r.key then ns.Gather.AskInvite(r.key, r.at) end end, 22)
        r:SetScript("OnClick", function() UI.Select("calendar") end)
        p.next[i] = r
    end
    p.nextNone = Text(p, L.NEXT_NONE, "GameFontDisableSmall", 466, -192, 266)
    p.nextNone:SetWordWrap(true)
    p.nextNone:SetHeight(30)
    p.nextNone:SetJustifyV("TOP")
    -- Ask the Guild: open questions and the Lore Master; click for the Ask tab.
    p.ask = UI.Row(p, 462, -350, 274, 24)
    p.ask.text = Text(p.ask, "", "GameFontHighlightSmall", 6, -6, 262)
    p.ask:SetScript("OnClick", function() UI.ShowQuestions("open") end)
    -- Who's live on Twitch right now (Streamers tab).
    p.live = UI.Row(p, 462, -378, 274, 24)
    p.live.text = Text(p.live, "", "GameFontHighlightSmall", 6, -6, 262)
    p.live:SetScript("OnClick", function() UI.Select("streamers") end)
end

local function Refresh(p)
    p.hello:SetText(string.format(L.HELLO, UnitName("player") or "mate"))
    local msg, by = ns.Board.HomeMessage()
    if msg then
        p.sub:SetText(ns.GOLD .. (by and string.format(L.HOME_FROM, by:match("^%S+") or by) or L.HOME_MOTD) .. "|r " .. msg)
    else
        p.sub:SetText(ns.GREY .. (ns.Guild.name and string.format(L.HELLO_SUB, ns.Guild.name) or L.HELLO_SUB_NOGUILD) .. "|r")
    end

    local s = ns.Roster.Stats()
    local zone = ns.Roster.MyZone()
    local st = p.stats
    st[1].num:SetText(s.online);   st[1].extra:SetText(string.format(L.STAT_ONLINE_EXTRA, s.onlineAddon))
    st[2].num:SetText(s.near);     st[2].extra:SetText(string.format(L.STAT_NEAR_EXTRA, s.nearZone, zone))
    st[3].num:SetText(#ns.Dungeons.Groups()); st[3].extra:SetText(string.format(L.STAT_GROUPS_EXTRA, ns.Dungeons.CountAtMyLevel()))
    local open = ns.Requests.List()
    local canMake = 0
    for _, r in ipairs(open) do if r.owner ~= ns.me and ns.Requests.ICanMake(r) then canMake = canMake + 1 end end
    st[4].num:SetText(#open)
    st[4].extra:SetText(string.format(L.STAT_REQUESTS_EXTRA, canMake))

    local list, dist = ns.Roster.NearMe()
    for i, r in ipairs(p.near) do
        local m = list[i]
        r.m = m
        if m then
            r.name:SetText(UI.Name(m) .. "  " .. ns.GREY .. m.level .. "|r")
            local d = dist[m.name]
            if d then
                r.info:SetText(ns.GREEN .. string.format(L.YARDS, d) .. "|r")
            else
                r.info:SetText(m.zone == zone and (ns.GREEN .. string.format(L.HERE_IN, zone) .. "|r") or m.zone)
            end
            r.stripe:SetColorTexture(1, 1, 1, (i % 2 == 0) and 0.04 or 0)
            r:Show()
        else
            r:Hide()
        end
    end
    p.nearNone:SetText(#list == 0 and string.format(L.NEAR_NONE, ns.Roster.Range()) or "")

    local dc = ns.Board.Discord()
    for _, w in ipairs({ p.dcLabel, p.dcBox, p.dcHint }) do w:SetShown(dc ~= nil) end
    if dc then p.dcBox.SetValue(dc) end
    p.sub:SetHeight(dc and 26 or 48)          -- two lines of message with the Discord row, four without

    local live = {}
    for _, e in ipairs(ns.Board.Streamers()) do
        if e.live and e.name ~= ns.me then live[#live + 1] = e.name:match("^%S+") or e.name end
    end
    p.live.text:SetText(#live > 0 and ("|cffff3030" .. L.LIVE_NOW .. "|r  " .. table.concat(live, ", ")) or "")
    p.live:SetShown(#live > 0)

    local Q = ns.Questions
    local nOpen, lore = Q.OpenCount(), Q.LoreMaster()
    local waiting = Q.MyWaiting()
    local line = (nOpen > 0 and ns.GOLD or "") .. string.format(L.HOME_QUESTIONS, nOpen) .. (nOpen > 0 and "|r" or "")
    if waiting > 0 then
        line = line .. "  " .. ns.GOLD .. string.format(L.HOME_Q_WAITING, waiting) .. "|r"
    elseif lore then
        line = line .. "  " .. ns.GREY .. L.LORE_MASTER .. ":|r " .. (lore:match("^%S+") or lore) .. " " .. UI.LORE_ICON
    end
    p.ask.text:SetText(line .. ns.GREY .. "  »|r")
    p.ask.stripe:SetColorTexture(1, 1, 1, 0.04)

    local up = ns.Calendar.Upcoming(4)
    p.nextNone:SetShown(#up == 0)
    for i, r in ipairs(p.next) do
        local u = up[i]
        if u then
            local going = #ns.Calendar.Answers(u.e, u.at).y
            r.key, r.at = u.key, u.at
            r.title:SetText(u.e.title)
            local g = ns.Gather.ActiveFor(u.key, u.at)
            if g and g.organiser ~= ns.me then
                r.when:SetText(ns.GOLD .. string.format(L.GATHERING_NOW, g.organiser:match("^%S+") or g.organiser) .. "|r")
                r.ask:Show()
                r.ask:SetEnabled(not ns.Gather.HaveAsked(u.key, u.at))
            else
                r.when:SetText(UI.DayText(u.at) .. " " .. UI.TimeText(u.at) .. "   " .. ns.GREY .. going .. " " .. L.GOING_N:lower() .. "|r")
                r.ask:Hide()
            end
            r.stripe:SetColorTexture(1, 1, 1, (i % 2 == 0) and 0.04 or 0)
            r:Show()
        else
            r:Hide()
        end
    end
end

UI.AddPage("home", Build, Refresh)
