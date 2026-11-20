-- Settings tab. Only settings for features that exist; the rest arrive with their phase.
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
-- Pop-ups switched somewhere else: "voice" in the voice drawer (UI/Voice.lua). Every kind in
-- settings.pop must be in one of the two (tests/test_popswitch.lua).
UI.POP_ELSEWHERE = { voice = true }

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

local function Build(p)
    local s = ns.settings

    -- Map
    Header(p, L.SET_MAP, 0, -4, 350)
    p.share = UI.Check(p, L.SET_SHARE, 0, -26, s.sharePosition == true, function(on)
        s.sharePosition = on
        Changed()
    end)
    p.notAsked = Text(p, "", "GameFontDisableSmall", 248, -31, 120)
    -- World map and minimap side by side, to make room for the ring colour.
    p.world = UI.Check(p, L.SET_SHOW_WORLD, 0, -54, s.showWorld, function(on) s.showWorld = on; Changed() end)
    p.mini = UI.Check(p, L.SET_SHOW_MINI, 176, -54, s.showMinimap, function(on) s.showMinimap = on; Changed() end)
    Text(p, L.SET_DOT, "GameFontHighlight", 4, -90)
    UI.Choice(p, { L.DOT_SMALL, L.DOT_MEDIUM, L.DOT_LARGE }, 80, -86, 80, function(i)
        if s.dotSize ~= i then s.dotSize = i; Changed() end
    end)(s.dotSize or 2)
    -- Ring round the dots: red, blue or gold, gold by default.
    Text(p, L.SET_RING, "GameFontHighlight", 4, -122)
    p.pickRing, p.ringButtons = UI.Choice(p, { L.RING_RED, L.RING_BLUE, L.RING_GOLD }, 80, -118, 80, function(i)
        if s.dotRing ~= i then s.dotRing = i; Changed() end
    end)
    p.pickRing(s.dotRing or 3)

    -- Minimap button (left, under the map)
    Header(p, L.SET_BUTTON, 0, -156, 350)
    p.minimap = UI.Check(p, L.SET_MINIMAP, 0, -178, s.minimap, function(on) s.minimap = on; Changed() end)
    p.plates = UI.Check(p, L.SET_PLATES, 176, -178, s.guildPlates ~= false, function(on) s.guildPlates = on; Changed() end)
    p.plates:SetScript("OnEnter", function(self)
        if not GameTooltip then return end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:AddLine(L.SET_PLATES, 1, 0.82, 0)
        GameTooltip:AddLine(L.SET_PLATES_TIP, 1, 1, 1, true)
        GameTooltip:Show()
    end)
    p.plates:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
    -- How much memory the addon uses (a guildie asked). Only our own addon, only when Settings opens.
    p.memory = Text(p, "", "GameFontHighlightSmall", 4, -206, 346)
    p:HookScript("OnShow", function() ns.Safe(ShowMemory, p) end)
    ShowMemory(p)

    -- Your characters: linked automatically (Alts.lua), so titles and points go to you.
    Header(p, L.SET_ALTS, 0, -226, 350)
    p.linkAlts = UI.Check(p, L.SET_LINK_ALTS, 0, -246, ns.Alts.Linking(), function(on)
        ns.Alts.SetLinking(on)
        Changed()
    end)
    p.linkAlts:SetScript("OnEnter", function(self) AltsTip(self) end)
    p.linkAlts:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
    Text(p, L.SET_MAIN, "GameFontHighlightSmall", 4, -277)
    p.mainBtn = UI.Button(p, "", 120, 40, -271, NextMain, 20)
    p.mainBtn:SetScript("OnEnter", function(self)
        if not GameTooltip then return end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:AddLine(L.SET_MAIN_TIP, 1, 1, 1, true)
        GameTooltip:Show()
    end)
    p.mainBtn:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
    p.altsState = Text(p, "", "GameFontDisableSmall", 168, -268, 182)
    p.altsState:SetWordWrap(true)
    p.altsState:SetHeight(26)
    p.altsState:SetJustifyV("TOP")

    -- Professions
    Header(p, L.SET_PROF, 386, -4, 350)
    p.shareProf = UI.Check(p, L.SET_SHARE_PROF, 386, -26, s.shareProfessions == true, function(on)
        s.shareProfessions = on
        Changed()
    end)
    p.profNotAsked = Text(p, "", "GameFontDisableSmall", 640, -31, 96)

    -- Pop-ups and sounds, all in one place.
    Header(p, L.SET_NOTIFY, 386, -60, 350)
    -- One switch per kind of pop-up, two columns; then the reminder and the sound on one row.
    p.pops = {}
    for i, kind in ipairs(POP_KINDS) do
        local x, y = 386 + ((i - 1) % 2) * 176, -80 - math.floor((i - 1) / 2) * 22
        p.pops[kind[1]] = UI.Check(p, L[kind[2]], x, y, s.pop[kind[1]] ~= false, function(on)
            s.pop[kind[1]] = on
            Changed()
        end)
    end
    p.remind = UI.Check(p, L.SET_POP_REMIND, 386, -168, s.remind, function(on) s.remind = on; Changed() end)
    p.sound = UI.Check(p, L.SET_SOUND, 562, -168, s.popupSound, function(on) s.popupSound = on; Changed() end)
    local labels = {}
    for i, snd in ipairs(ns.Toast.SOUNDS) do labels[i] = snd[1] end
    Text(p, L.SET_WHICH_SOUND, "GameFontHighlightSmall", 390, -198)
    p.pickSound = UI.Choice(p, labels, 452, -192, 66, function(i)
        if s.sound ~= i then s.sound = i; ns.Toast.PlaySound() end
    end)
    p.pickSound(s.sound or 1)
    Text(p, L.SET_VOLUME, "GameFontHighlightSmall", 390, -222)
    p.pickChannel = UI.Choice(p, { L.CH_MASTER, L.CH_EFFECTS, L.CH_DIALOG }, 452, -216, 68, function(i)
        s.soundChannel = i
    end)
    p.pickChannel(s.soundChannel or 1)
    UI.Button(p, L.TEST_SOUND, 60, 676, -216, function() ns.Toast.PlaySound() end)
    local vol = Text(p, L.SET_VOLUME_TIP, "GameFontDisableSmall", 390, -242, 346)
    vol:SetWordWrap(true)
    vol:SetHeight(26)
    vol:SetJustifyV("TOP")
    -- Milestones: my own milestone lines in guild chat, on unless I untick it.
    p.msPost = UI.Check(p, L.SET_MS_POST, 386, -272, not s.msNoPost, function(on) s.msNoPost = (not on) or nil; Changed() end)
    p.msPost:SetScript("OnEnter", function(self)
        if not GameTooltip then return end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:AddLine(L.SET_MS_POST_TIP, 1, 1, 1, true)
        GameTooltip:Show()
    end)
    p.msPost:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)

    -- Addon recruiting (bottom, full width): what Share puts in the whisper (Recruit.lua); saved as typed,
    -- empty = the default.
    Header(p, L.SET_RECRUIT_HEAD, 0, -304, 736)
    local label = Text(p, L.SET_RECRUIT_MSG, "GameFontHighlightSmall", 4, -334)
    label:SetJustifyH("LEFT")
    -- From just after the label to the right edge, so as much of the message shows as fits.
    local e = CreateFrame("EditBox", nil, p, "InputBoxTemplate")
    e:SetHeight(20)
    e:SetPoint("LEFT", label, "RIGHT", 14, 0)
    e:SetPoint("RIGHT", p, "RIGHT", -6, 0)
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

    -- The welcome page (what the addon shares, and the first-run questions), under it. It replaced the
    -- Privacy box (21 Nov).
    Header(p, L.SET_ABOUT_HEAD, 0, -366, 736)
    Text(p, L.SET_WELCOME_HINT, "GameFontHighlightSmall", 4, -394)
    p.welcomeBtn = UI.Button(p, L.SET_WELCOME, 120, 612, -388, function() ns.Welcome.Show() end, 22)
end

local function Refresh(p)
    local s = ns.settings
    p.share:SetChecked(s.sharePosition == true)
    p.notAsked:SetText(s.sharePosition == nil and L.SHARE_NOT_ASKED or "")
    p.world:SetChecked(s.showWorld)
    p.mini:SetChecked(s.showMinimap)
    p.minimap:SetChecked(s.minimap)
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
