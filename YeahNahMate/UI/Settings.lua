-- Settings page, opened from the gear in the window's header. Only settings for features that exist.
local ADDON, ns = ...
local L = ns.L
local UI = ns.UI
local Text, Header = UI.Text, UI.Header

local function Changed() ns.Fire("SETTINGS") end

-- The pop-up switches: settings.pop key, label (UI/Toast.lua says which pop-up is which).
local POP_KINDS = {
    { "group", "SET_POP_GROUP" }, { "signup", "SET_POP_SIGNUP" },
    { "request", "SET_POP_REQUEST" }, { "claim", "SET_POP_CLAIM" },
    { "gather", "SET_POP_GATHER" }, { "answer", "SET_POP_ANSWER" },
    { "qanswer", "SET_POP_QANSWER" }, { "milestone", "SET_POP_MILESTONE" },
}
UI.POP_KINDS = POP_KINDS

-- Our own memory use. UpdateAddOnMemoryUsage walks every addon and can hitch for a moment, so it
-- runs only when the Settings tab is shown (not on redraws), at most every 10 s, never in combat.
local lastMemory = nil
local function ShowMemory(p)
    if not (UpdateAddOnMemoryUsage and GetAddOnMemoryUsage) then p.memory:SetText(""); return end
    if InCombatLockdown() then return end
    local now = GetTime()
    if lastMemory and now - lastMemory < 10 and p.memory:GetText() ~= "" then return end
    lastMemory = now
    UpdateAddOnMemoryUsage()
    local kb = GetAddOnMemoryUsage(ADDON)
    if type(kb) ~= "number" then p.memory:SetText(""); return end
    local text = kb >= 1024 and string.format("%.1f MB", kb / 1024) or string.format("%d KB", kb)
    p.memory:SetText(string.format(L.SET_MEMORY, text) .. ns.GREY .. "  " .. L.SET_MEMORY_TIP .. "|r")
end

-- Your characters (Alts.lua): the main cycles through this account's characters in the guild.
local function NextMain()
    local mine = ns.Alts.MyCharacters()
    if #mine < 2 then return end
    local cur = ns.Alts.MyMain()
    local i = 1
    for j, n in ipairs(mine) do if n == cur then i = j end end
    ns.Alts.SetMain(mine[i % #mine + 1])
    Changed()
end

local function AltsTip(owner)
    if not GameTooltip then return end
    GameTooltip:SetOwner(owner, "ANCHOR_RIGHT")
    GameTooltip:AddLine(L.SET_ALTS, 1, 0.82, 0)
    GameTooltip:AddLine(L.SET_ALTS_TIP, 1, 1, 1, true)
    GameTooltip:Show()
end

local function BuildGeneral(p, g)
    local s = ns.settings

    -- Map
    Header(g, L.SET_MAP, 0, -4, 350)
    p.share = UI.Check(g, L.SET_SHARE, 0, -26, s.sharePosition == true, function(on)
        s.sharePosition = on
        Changed()
    end)
    p.notAsked = Text(g, "", "GameFontDisableSmall", 248, -31, 120)
    -- World map and minimap side by side, to make room for the ring colour.
    p.world = UI.Check(g, L.SET_SHOW_WORLD, 0, -54, s.showWorld, function(on) s.showWorld = on; Changed() end)
    p.mini = UI.Check(g, L.SET_SHOW_MINI, 176, -54, s.showMinimap, function(on) s.showMinimap = on; Changed() end)
    Text(g, L.SET_DOT, "GameFontHighlight", 4, -90)
    UI.Choice(g, { L.DOT_SMALL, L.DOT_MEDIUM, L.DOT_LARGE }, 80, -86, 80, function(i)
        if s.dotSize ~= i then s.dotSize = i; Changed() end
    end)(s.dotSize or 2)
    -- Ring round the dots: red, blue or gold, gold by default.
    Text(g, L.SET_RING, "GameFontHighlight", 4, -122)
    p.pickRing, p.ringButtons = UI.Choice(g, { L.RING_RED, L.RING_BLUE, L.RING_GOLD }, 80, -118, 80, function(i)
        if s.dotRing ~= i then s.dotRing = i; Changed() end
    end)
    p.pickRing(s.dotRing or 3)

    -- Minimap button (left, under the map)
    Header(g, L.SET_BUTTON, 0, -156, 350)
    p.minimap = UI.Check(g, L.SET_MINIMAP, 0, -178, s.minimap, function(on) s.minimap = on; Changed() end)
    -- How much memory the addon uses (a guildie asked). Only our own addon, only when Settings opens.
    p.memory = Text(g, "", "GameFontHighlightSmall", 4, -206, 168)
    p:HookScript("OnShow", function() ns.Safe(ShowMemory, p) end)
    ShowMemory(p)

    -- Your characters: linked automatically (Alts.lua), so titles and points go to you.
    Header(g, L.SET_ALTS, 0, -226, 350)
    p.linkAlts = UI.Check(g, L.SET_LINK_ALTS, 0, -246, ns.Alts.Linking(), function(on)
        ns.Alts.SetLinking(on)
        Changed()
    end)
    p.linkAlts:SetScript("OnEnter", function(self) AltsTip(self) end)
    p.linkAlts:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
    Text(g, L.SET_MAIN, "GameFontHighlightSmall", 4, -277)
    p.mainBtn = UI.Button(g, "", 120, 40, -271, NextMain, 20)
    p.mainBtn:SetScript("OnEnter", function(self)
        if not GameTooltip then return end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:AddLine(L.SET_MAIN_TIP, 1, 1, 1, true)
        GameTooltip:Show()
    end)
    p.mainBtn:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
    p.altsState = Text(g, "", "GameFontDisableSmall", 168, -268, 182)
    p.altsState:SetWordWrap(true)
    p.altsState:SetHeight(26)
    p.altsState:SetJustifyV("TOP")

    -- Professions
    Header(g, L.SET_PROF, 386, -4, 350)
    p.shareProf = UI.Check(g, L.SET_SHARE_PROF, 386, -26, s.shareProfessions == true, function(on)
        s.shareProfessions = on
        Changed()
    end)
    p.profNotAsked = Text(g, "", "GameFontDisableSmall", 640, -31, 96)

    -- Pop-ups and sounds, all in one place.
    Header(g, L.SET_NOTIFY, 386, -60, 350)
    -- One switch per kind of pop-up, two columns; then the reminder and the sound on one row.
    p.pops = {}
    for i, kind in ipairs(POP_KINDS) do
        local x, y = 386 + ((i - 1) % 2) * 176, -80 - math.floor((i - 1) / 2) * 22
        p.pops[kind[1]] = UI.Check(g, L[kind[2]], x, y, s.pop[kind[1]] ~= false, function(on)
            s.pop[kind[1]] = on
            Changed()
        end)
    end
    p.remind = UI.Check(g, L.SET_POP_REMIND, 386, -168, s.remind, function(on) s.remind = on; Changed() end)
    p.sound = UI.Check(g, L.SET_SOUND, 562, -168, s.popupSound, function(on) s.popupSound = on; Changed() end)
    local labels = {}
    for i, snd in ipairs(ns.Toast.SOUNDS) do labels[i] = snd[1] end
    Text(g, L.SET_WHICH_SOUND, "GameFontHighlightSmall", 390, -198)
    p.pickSound = UI.Choice(g, labels, 452, -192, 66, function(i)
        if s.sound ~= i then s.sound = i; ns.Toast.PlaySound() end
    end)
    p.pickSound(s.sound or 1)
    Text(g, L.SET_VOLUME, "GameFontHighlightSmall", 390, -222)
    p.pickChannel = UI.Choice(g, { L.CH_MASTER, L.CH_EFFECTS, L.CH_DIALOG }, 452, -216, 68, function(i)
        s.soundChannel = i
    end)
    p.pickChannel(s.soundChannel or 1)
    UI.Button(g, L.TEST_SOUND, 60, 676, -216, function() ns.Toast.PlaySound() end)
    local vol = Text(g, L.SET_VOLUME_TIP, "GameFontDisableSmall", 390, -242, 346)
    vol:SetWordWrap(true)
    vol:SetHeight(26)
    vol:SetJustifyV("TOP")
    -- Milestones: my own milestone lines in guild chat, on unless I untick it.
    p.msPost = UI.Check(g, L.SET_MS_POST, 386, -272, not s.msNoPost, function(on) s.msNoPost = (not on) or nil; Changed() end)
    p.msPost:SetScript("OnEnter", function(self)
        if not GameTooltip then return end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:AddLine(L.SET_MS_POST_TIP, 1, 1, 1, true)
        GameTooltip:Show()
    end)
    p.msPost:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)

    -- Addon recruiting (bottom, full width): what Share puts in the whisper (Recruit.lua); saved as typed,
    -- empty = the default.
    Header(g, L.SET_RECRUIT_HEAD, 0, -304, 736)
    local label = Text(g, L.SET_RECRUIT_MSG, "GameFontHighlightSmall", 4, -334)
    label:SetJustifyH("LEFT")
    -- From just after the label to the right edge, so as much of the message shows as fits.
    local e = CreateFrame("EditBox", nil, g, "InputBoxTemplate")
    e:SetHeight(20)
    e:SetPoint("LEFT", label, "RIGHT", 14, 0)
    e:SetPoint("RIGHT", g, "RIGHT", -6, 0)
    e:SetAutoFocus(false)
    e:SetMaxLetters(240)
    e:SetScript("OnEscapePressed", function(self)
        self:SetText(ns.Recruit.Message())
        self:ClearFocus()
    end)
    e:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
    e:SetScript("OnEditFocusLost", function(self)
        local t = strtrim(self:GetText() or "")
        ns.settings.recruitMsg = (t ~= "" and t ~= L.RECRUIT_MSG_DEFAULT) and t or nil
        self:SetText(ns.Recruit.Message())
        self:SetCursorPosition(0)
    end)
    e:SetScript("OnEnter", function(self)
        if not GameTooltip then return end
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:AddLine(L.SET_RECRUIT_MSG, 1, 0.82, 0)
        GameTooltip:AddLine(L.SET_RECRUIT_MSG_TIP, 1, 1, 1, true)
        GameTooltip:Show()
    end)
    e:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
    p.recruitMsg = e

end


local function Tip(widget, title, text, anchor)
    widget:SetScript("OnEnter", function(self)
        if not GameTooltip then return end
        GameTooltip:SetOwner(self, anchor or "ANCHOR_RIGHT")
        if title then GameTooltip:AddLine(title, 1, 0.82, 0) end
        GameTooltip:AddLine(text, 1, 1, 1, true)
        GameTooltip:Show()
    end)
    widget:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
    return widget
end

-- Nameplates tab: the switches, then the bracket fit with < > per number for the kind picked
-- (game or Plater), and a preview on a sample bar.
-- Which look the player's game nameplates have: the game's Nameplates "Style" option (only read).
-- "classic" = the old gold border; every other style uses the modern bar.
local function GameStyle()
    local E = Enum and Enum.NamePlateStyle
    local ok, v = pcall(GetCVar, "nameplateStyle")
    if ok and E and E.Classic ~= nil and tonumber(v) == E.Classic then return "classic" end
    return "modern"
end

-- Sample nameplates for the preview, drawn with the game's own nameplate art and sizes (from the
-- game's Blizzard_NamePlates code, Medium size). Each returns { frame, around = the part the real
-- brackets go round: the bar's background for the game's plates, the health bar for Plater's }.
local GREEN = { 0.1, 0.8, 0.1 }
local function PreviewPlates(box)
    local kinds = {}
    local function Holder()
        local f = CreateFrame("Frame", nil, box)
        f:SetAllPoints()
        f:Hide()
        return f
    end
    -- Modern (the game's default): grey bar coloured by the game, on a dark backing that reaches
    -- 2 left, 3 up, 6 right and 6 down (its shadow); the name sits inside the bar on the left.
    do
        local f = Holder()
        local bar = f:CreateTexture(nil, "ARTWORK")
        bar:SetAtlas("UI-HUD-CoolDownManager-Bar")
        bar:SetVertexColor(GREEN[1], GREEN[2], GREEN[3])
        bar:SetSize(166, 20)
        bar:SetPoint("CENTER", 0, -14)
        local bg = f:CreateTexture(nil, "BACKGROUND")
        bg:SetAtlas("UI-HUD-CoolDownManager-Bar-BG")
        bg:SetPoint("TOPLEFT", bar, "TOPLEFT", -2, 3)
        bg:SetPoint("BOTTOMRIGHT", bar, "BOTTOMRIGHT", 6, -6)
        local name = f:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        name:SetPoint("LEFT", bar, "LEFT", 4, 0)
        name:SetText(L.PF_PREVIEW_NAME)
        kinds.modern = { frame = f, around = bg }
    end
    -- Classic: the old gold border (128 x 16, level box on the right) over a 10 high bar; the name
    -- centred above.
    do
        local f = Holder()
        local border = f:CreateTexture(nil, "ARTWORK", nil, 1)
        border:SetTexture("Interface\\Tooltips\\Nameplate-Border")
        border:SetTexCoord(0, 1, 0.5, 1)
        border:SetSize(128, 16)
        border:SetPoint("CENTER", 0, -14)
        local bar = f:CreateTexture(nil, "ARTWORK", nil, 0)
        bar:SetTexture("Interface\\TargetingFrame\\UI-TargetingFrame-BarFill")
        bar:SetVertexColor(GREEN[1], GREEN[2], GREEN[3])
        bar:SetPoint("TOPLEFT", border, "CENTER", -64 + 3.5, 5.5)
        bar:SetPoint("BOTTOMRIGHT", border, "CENTER", 64 - 20.75, -4.5)
        local name = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        name:SetPoint("BOTTOM", border, "CENTER", 0, 9)
        name:SetText(L.PF_PREVIEW_NAME)
        kinds.classic = { frame = f, around = border }
    end
    -- Plater: its own flat bar with a thin black edge and the name above.
    do
        local f = Holder()
        local bar = f:CreateTexture(nil, "ARTWORK")
        bar:SetSize(140, 10)
        bar:SetPoint("CENTER", 0, -14)
        bar:SetColorTexture(GREEN[1], GREEN[2], GREEN[3], 0.95)
        local back = f:CreateTexture(nil, "BORDER")
        back:SetPoint("TOPLEFT", bar, "TOPLEFT", -1, 1)
        back:SetPoint("BOTTOMRIGHT", bar, "BOTTOMRIGHT", 1, -1)
        back:SetColorTexture(0, 0, 0, 0.9)
        local name = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        name:SetPoint("BOTTOM", bar, "TOP", 0, 2)
        name:SetText(L.PF_PREVIEW_NAME)
        name:SetTextColor(0.25, 1, 0.25)
        kinds.plater = { frame = f, around = bar }
    end
    return kinds
end

local FIT_ROWS = {
    { "x", "PF_WIDTH" }, { "dx", "PF_SIDEWAYS" }, { "dy", "PF_UPDOWN" }, { "top", "PF_TOP" }, { "y", "PF_BOTTOM" },
}
local function BuildPlates(p, n)
    local s = ns.settings
    local P = ns.Plates
    Header(n, L.PF_HEAD, 0, -4, 350)
    p.plates = Tip(UI.Check(n, L.SET_PLATES, 0, -26, s.guildPlates ~= false, function(on) s.guildPlates = on; Changed() end),
        L.SET_PLATES, L.SET_PLATES_TIP)
    p.rollPlates = Tip(UI.Check(n, L.SET_ROLL_PLATES, 0, -50, s.rollPlates ~= false, function(on) s.rollPlates = on; Changed() end),
        L.SET_ROLL_PLATES, L.SET_ROLL_PLATES_TIP)
    local needs = Text(n, L.PF_NEEDS, "GameFontDisableSmall", 4, -80, 346)
    needs:SetWordWrap(true)
    needs:SetHeight(28)
    needs:SetJustifyV("TOP")

    Header(n, L.PF_FIT_HEAD, 0, -116, 350)
    Text(n, L.PF_FOR, "GameFontHighlight", 4, -142)
    p.fitKind = p.fitKind or ((P.Rounds().plater or 0) > 0 and "plater" or "game")
    p.pickKind, p.kindButtons = UI.Choice(n, { L.PF_GAME, L.PF_PLATER }, 90, -136, { 130, 80 }, function(i)
        local kind = i == 2 and "plater" or "game"
        if p.fitKind ~= kind then p.fitKind = kind; UI.Dirty() end
    end)
    for _, b in ipairs(p.kindButtons) do Tip(b, L.PF_FOR, L.PF_FOR_TIP) end
    p.using = Text(n, "", "GameFontHighlightSmall", 4, -166, 346)

    p.fitRows = {}
    for i, row in ipairs(FIT_ROWS) do
        local key, name = row[1], row[2]
        local y = -188 - (i - 1) * 26
        local hit = CreateFrame("Frame", nil, n)
        hit:SetPoint("TOPLEFT", 0, y)
        hit:SetSize(150, 22)
        hit:EnableMouse(true)
        Tip(hit, L[name], L[name .. "_TIP"])
        Text(n, L[name], "GameFontHighlight", 4, y - 4, 146)
        local function Step(d)
            local cur = P.Fit(p.fitKind)[key] or 0
            P.SetFit(p.fitKind, key, cur + d)
        end
        Tip(UI.Button(n, "<", 26, 150, y, function() Step(-1) end, 22), L[name], L.PF_LESS .. ": " .. L[name .. "_TIP"])
        local val = Text(n, "", "GameFontHighlight", 178, y - 4, 44, "CENTER")
        Tip(UI.Button(n, ">", 26, 222, y, function() Step(1) end, 22), L[name], L.PF_MORE .. ": " .. L[name .. "_TIP"])
        p.fitRows[i] = { key = key, val = val }
    end
    p.fitReset = Tip(UI.Button(n, L.PF_RESET, 80, 150, -322, function() P.SetFit(p.fitKind, nil) end, 22), L.PF_RESET, L.PF_RESET_TIP)
    p.fitState = Text(n, "", "GameFontDisableSmall", 236, -327, 114)

    -- Preview: a sample nameplate with brackets in my clan's colour, moved by the same numbers.
    Header(n, L.PF_PREVIEW, 386, -4, 350)
    local box = Tip(UI.Box(n, 386, -26, 350, 150), L.PF_PREVIEW, L.PF_PREVIEW_TIP)
    box:EnableMouse(true)
    p.previewKinds = PreviewPlates(box)
    -- The game's plates come in two looks (the game's Nameplates "Style" option): pick which to show.
    p.previewStyle = p.previewStyle or GameStyle()
    p.pickStyle, p.styleButtons = UI.Choice(box, { L.PF_MODERN, L.PF_CLASSIC }, 8, -8, 80, function(i)
        local style = i == 2 and "classic" or "modern"
        if p.previewStyle ~= style then p.previewStyle = style; UI.Dirty() end
    end)
    for _, b in ipairs(p.styleButtons) do Tip(b, L.PF_STYLE, L.PF_STYLE_TIP) end
    p.preview = P.NewMarker(box)
end

local function Build(p)
    -- Two tabs: General (everything else) and Nameplates. The Welcome page button sits on the tab row.
    local g = CreateFrame("Frame", nil, p)
    g:SetPoint("TOPLEFT", 0, -32)
    g:SetPoint("BOTTOMRIGHT")
    local n = CreateFrame("Frame", nil, p)
    n:SetPoint("TOPLEFT", 0, -32)
    n:SetPoint("BOTTOMRIGHT")
    n:Hide()
    p.general, p.platesTab = g, n
    p.pickTab, p.tabButtons = UI.Choice(p, { L.SET_TAB_GENERAL, L.SET_TAB_PLATES }, 0, 0, 120, function(i)
        p.tab = i
        g:SetShown(i ~= 2)
        n:SetShown(i == 2)
    end)
    p.welcomeBtn = Tip(UI.Button(p, L.SET_WELCOME, 120, 616, 0, function() ns.Welcome.Show() end, 22),
        L.SET_ABOUT_HEAD, L.SET_WELCOME_HINT, "ANCHOR_LEFT")
    BuildGeneral(p, g)
    BuildPlates(p, n)
    p.pickTab(1)
end

local function Refresh(p)
    local s = ns.settings
    p.share:SetChecked(s.sharePosition == true)
    p.notAsked:SetText(s.sharePosition == nil and L.SHARE_NOT_ASKED or "")
    p.world:SetChecked(s.showWorld)
    p.mini:SetChecked(s.showMinimap)
    p.minimap:SetChecked(s.minimap)
    -- Nameplates tab
    local P = ns.Plates
    p.plates:SetChecked(s.guildPlates ~= false)
    p.rollPlates:SetChecked(s.rollPlates ~= false)
    p.pickKind(p.fitKind == "plater" and 2 or 1)
    local fit = P.Fit(p.fitKind)
    for _, r in ipairs(p.fitRows) do r.val:SetText(tostring(fit[r.key] or 0)) end
    local isDefault = P.IsDefault(p.fitKind)
    p.fitReset:SetEnabled(not isDefault)
    p.fitState:SetText(isDefault and L.PF_DEFAULT or (ns.GOLD .. L.PF_CHANGED .. "|r"))
    local rounds = P.Rounds()
    p.using:SetText(((rounds.plater or 0) > 0 and L.PF_USING_PLATER) or ((rounds.bg or 0) > 0 and L.PF_USING_GAME) or L.PF_USING_NONE)
    local myRace = ns.Clans and ns.Clans.Race and ns.Clans.Race(ns.me)
    local col = (myRace and P.COLOURS[myRace]) or P.GOLD
    for _, b in ipairs(p.preview.bars) do b:SetColorTexture(col[1], col[2], col[3], 0.95) end
    local game = p.fitKind ~= "plater"
    for _, b in ipairs(p.styleButtons) do b:SetShown(game) end
    if game then p.pickStyle(p.previewStyle == "classic" and 2 or 1) end
    local shown = game and p.previewStyle or "plater"
    for kind, s in pairs(p.previewKinds) do s.frame:SetShown(kind == shown) end
    p.preview:ClearAllPoints()
    P.Anchor(p.preview, p.previewKinds[shown].around, fit)
    p.preview:Show()
    p.shareProf:SetChecked(s.shareProfessions == true)
    for kind, c in pairs(p.pops) do c:SetChecked(s.pop[kind] ~= false) end
    p.sound:SetChecked(s.popupSound)
    p.remind:SetChecked(s.remind)
    p.msPost:SetChecked(not s.msNoPost)
    p.profNotAsked:SetText(s.shareProfessions == nil and L.SHARE_NOT_ASKED or "")
    if p.recruitMsg and not p.recruitMsg:HasFocus() then
        p.recruitMsg:SetText(ns.Recruit.Message())
        p.recruitMsg:SetCursorPosition(0)
    end
    -- Your characters
    local A = ns.Alts
    local on = A.Linking()
    p.linkAlts:SetChecked(on)
    local mine = A.MyCharacters()
    local main = A.MyMain()
    p.mainBtn:SetText(main or "?")
    p.mainBtn:SetEnabled(on and #mine > 1)
    if #mine < 2 then
        p.altsState:SetText(L.SET_ALTS_ONLY_ONE)
    elseif not on then
        p.altsState:SetText(L.SET_ALTS_OFF)
    else
        local linked, waiting = {}, {}
        for _, n in ipairs(mine) do
            if n ~= ns.me then
                local first = n:match("^%S+") or n
                if A.IsLinked(n) then linked[#linked + 1] = first else waiting[#waiting + 1] = first end
            end
        end
        local text = #linked > 0 and (ns.GREEN .. string.format(L.SET_ALTS_LINKED, table.concat(linked, ", ")) .. "|r") or ""
        if #waiting > 0 then
            text = text .. (text ~= "" and "\n" or "") .. string.format(L.SET_ALTS_WAITING, table.concat(waiting, ", "))
        end
        p.altsState:SetText(text)
    end
end

UI.AddPage("settings", Build, Refresh)
ns.Listen("ALTS", UI.Dirty)
