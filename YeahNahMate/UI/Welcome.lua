-- The first-run welcome page: what Yeah Nah Mate is, what it always shares, and the two things it
-- only shares if you say so (your position on the map, your professions), on one page. Nothing
-- personal is sent until those are answered (CONTRIBUTING.md, Rules). Our own frame (game popups break under
-- Forever's gamepad UI). Closing it with the X answers nothing: it comes back next login.
-- Settings has a button to open it again.
local ADDON, ns = ...
local L = ns.L
local UI = ns.UI

local Welcome = {}
ns.Welcome = Welcome

local W, H = 540, 390
local box
local choice = {}               -- position / professions: true, false or nil (not picked yet)

local function Refresh()
    if not box then return end
    box.hello:SetText(ns.GOLD .. string.format(L.WELCOME_HELLO, ns.Guild.name or L.ADDON) .. "|r")
    box.intro:SetText(string.format(L.WELCOME_INTRO, ns.Guild.name or L.WELCOME_YOUR_GUILD))
    for _, q in ipairs(box.questions) do
        local v = choice[q.key]
        if v == true then q.yes:LockHighlight(); q.yes.sel:Show() else q.yes:UnlockHighlight(); q.yes.sel:Hide() end
        if v == false then q.no:LockHighlight(); q.no.sel:Show() else q.no:UnlockHighlight(); q.no.sel:Hide() end
    end
    local ready = choice.position ~= nil and choice.professions ~= nil
    box.done:SetEnabled(ready)
    box.waiting:SetShown(not ready)
end

local function Underline(b)
    b.sel = b:CreateTexture(nil, "OVERLAY")
    b.sel:SetColorTexture(1, 0.82, 0, 1)
    b.sel:SetPoint("BOTTOMLEFT", 6, 2)
    b.sel:SetPoint("BOTTOMRIGHT", -6, 2)
    b.sel:SetHeight(2)
    b.sel:Hide()
end

local function Build()
    box = CreateFrame("Frame", "YeahNahMateWelcome", UIParent, "BasicFrameTemplateWithInset")
    box:SetSize(W, H)
    box:SetPoint("CENTER", 0, 60)
    -- Above the main window (Settings opens it from there), like the whisper box.
    box:SetFrameStrata("FULLSCREEN_DIALOG")
    box:SetToplevel(true)
    box:SetClampedToScreen(true)
    box:SetMovable(true)
    box:EnableMouse(true)
    box:RegisterForDrag("LeftButton")
    box:SetScript("OnDragStart", box.StartMoving)
    box:SetScript("OnDragStop", box.StopMovingOrSizing)
    UI.PlainClose(box)
    box:Hide()
    local title = box:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    title:SetPoint("TOP", 0, -6)
    title:SetText(ns.GREY .. L.ADDON .. "|r")

    local icon = box:CreateTexture(nil, "ARTWORK")
    icon:SetSize(80, 80)
    icon:SetPoint("TOPLEFT", 14, -30)
    icon:SetTexture(UI.CREST)
    box.hello = UI.Text(box, "", "GameFontNormalLarge", 106, -40, W - 124)
    box.intro = UI.Text(box, "", "GameFontHighlightSmall", 106, -64, W - 124)
    box.intro:SetWordWrap(true)
    box.intro:SetHeight(58)
    box.intro:SetJustifyV("TOP")

    UI.Header(box, L.WELCOME_ALWAYS, 16, -142, W - 32)
    local always = UI.Text(box, L.WELCOME_ALWAYS_TEXT, "GameFontHighlightSmall", 18, -164, W - 36)
    always:SetWordWrap(true)
    always:SetHeight(30)
    always:SetJustifyV("TOP")

    UI.Header(box, L.WELCOME_CHOICE, 16, -204, W - 32)
    box.questions = {}
    local qs = {
        { key = "position", text = L.WELCOME_Q_POSITION, y = -228 },
        { key = "professions", text = L.WELCOME_Q_PROF, y = -266 },
    }
    for _, q in ipairs(qs) do
        local t = UI.Text(box, q.text, "GameFontHighlight", 20, q.y - 2, 320)
        t:SetWordWrap(true)
        t:SetHeight(32)
        t:SetJustifyV("TOP")
        q.yes = UI.Button(box, L.YEAH, 64, W - 156, q.y, function() choice[q.key] = true; Refresh() end, 24)
        q.no = UI.Button(box, L.NAH, 64, W - 86, q.y, function() choice[q.key] = false; Refresh() end, 24)
        Underline(q.yes)
        Underline(q.no)
        box.questions[#box.questions + 1] = q
    end

    UI.Text(box, L.WELCOME_CHANGE_LATER, "GameFontDisableSmall", 18, -314, W - 36)
    box.waiting = UI.Text(box, L.WELCOME_PICK_BOTH, "GameFontDisableSmall", 18, -354, 300)
    box.done = UI.Button(box, L.WELCOME_DONE, 130, W - 150, -346, function()
        if choice.position == nil or choice.professions == nil then return end
        local s = ns.settings
        local before = { s.sharePosition, s.shareProfessions }
        s.sharePosition, s.shareProfessions = choice.position, choice.professions
        box:Hide()
        ns.Print(L.WELCOME_SAVED)
        if before[1] ~= s.sharePosition or before[2] ~= s.shareProfessions then ns.Fire("SETTINGS") end
    end, 28)
end

function Welcome.Show()
    if not box then Build() end
    choice.position, choice.professions = ns.settings.sharePosition, ns.settings.shareProfessions
    Refresh()
    box:Show()
    box:Raise()
end

function Welcome.IsShown() return box ~= nil and box:IsShown() end

-- A little after login (once the game has settled), if something hasn't been answered. In combat it
-- waits until the fight is over.
local waiting = false
local function MaybeShow()
    if not IsInGuild() then return end
    if ns.settings.sharePosition ~= nil and ns.settings.shareProfessions ~= nil then return end
    if InCombatLockdown() then waiting = true return end
    waiting = false
    if not Welcome.IsShown() then Welcome.Show() end
end

ns.Listen("LOGIN", function() C_Timer.After(8, function() ns.Safe(MaybeShow) end) end)
ns.OnEvent("PLAYER_REGEN_ENABLED", function() if waiting then ns.Safe(MaybeShow) end end)
ns.Listen("ROSTER", function() if box and box:IsShown() then Refresh() end end)
