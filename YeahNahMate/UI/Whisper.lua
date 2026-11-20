-- Our own small whisper box. The Whisper and Ask buttons open it, prefilled if there's something to
-- say; the player reads or edits it and presses Enter or Send. Nothing is ever sent without that
-- press (no automation: CONTRIBUTING.md, Rules).
--
-- Why not the game's chat box: opening it from addon code (ChatFrame_OpenChat, ChatFrame_SendTell,
-- ChatFrameUtil) writes the chat's own globals, and on Forever whatever the player types next then
-- runs tainted, so /cast and /use get blocked (seen on launch week; with the gamepad UI it froze the
-- game). This box is ours, so the game's chat is never touched.
--
-- Apart from milestone posts (Milestones.lua, GUILD), this is the only file allowed to send chat
-- (test_rules), and only as WHISPER.
local ADDON, ns = ...
local L = ns.L
local UI = ns.UI

local Whisper = {}
ns.Whisper = Whisper

local box, target

local function Send()
    if not target then return end
    local text = strtrim(box.edit:GetText() or "")
    if text == "" then return end
    if target.sim then
        ns.Print(string.format(L.WHISPER_FAKE, target.name))
        local to = target.name
        box:Hide()
        -- As if it went (Recruit.lua notes a share to a fake; Comm keeps anything about fakes on screen).
        ns.Fire("WHISPERED", to, text)
        return
    end
    if C_ChatInfo and C_ChatInfo.InChatMessagingLockdown and C_ChatInfo.InChatMessagingLockdown() then
        ns.Print(L.WHISPER_LOCKED)
        return
    end
    text = ns.CutBytes(text, 255)
    local send = (C_ChatInfo and C_ChatInfo.SendChatMessage) or SendChatMessage
    if not send then return end
    -- If the game refuses it, say so and keep the box open with the text, rather than a Lua error.
    local ok, err = pcall(send, text, "WHISPER", nil, target.name)
    if not ok then
        ns.Print(string.format(L.WHISPER_FAILED, tostring(err)))
        return
    end
    -- Recruit.lua notes a share only when it really went (the player pressed Enter or Send). The name is
    -- read first: hiding the box forgets who it was for.
    local to = target.name
    box:Hide()
    ns.Fire("WHISPERED", to, text)
end

local function Build()
    box = CreateFrame("Frame", "YeahNahMateWhisper", UIParent, "BasicFrameTemplateWithInset")
    box:SetSize(380, 110)
    box:SetPoint("CENTER", 0, 120)
    box:SetFrameStrata("FULLSCREEN_DIALOG")
    box:SetClampedToScreen(true)
    box:SetMovable(true)
    box:EnableMouse(true)
    box:RegisterForDrag("LeftButton")
    box:SetScript("OnDragStart", box.StartMoving)
    box:SetScript("OnDragStop", box.StopMovingOrSizing)
    UI.PlainClose(box)
    box:Hide()

    box.title = box:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    box.title:SetPoint("TOP", 0, -5)
    UI.Text(box, L.WHISPER_HINT, "GameFontDisableSmall", 14, -30, 352)

    local edit = CreateFrame("EditBox", nil, box, "InputBoxTemplate")
    edit:SetSize(340, 22)
    edit:SetPoint("TOPLEFT", 20, -46)
    edit:SetAutoFocus(false)
    edit:SetMaxLetters(255)
    edit:SetScript("OnEnterPressed", Send)
    edit:SetScript("OnEscapePressed", function() box:Hide() end)
    box.edit = edit

    UI.Button(box, L.SEND, 90, 186, -76, Send)
    UI.Button(box, L.CANCEL, 90, 280, -76, function() box:Hide() end)
    box:SetScript("OnHide", function() edit:ClearFocus(); target = nil end)
end

-- Open the box for a guildmate (a roster member table), with optional text already in it.
function Whisper.Open(m, text)
    if not m then return end
    if not box then Build() end
    target = m
    box.title:SetText(string.format(L.WHISPER_TO, "|c" .. ns.ClassHex(m.class) .. m.name .. "|r"))
    box.edit:SetText(text or "")
    box:Show()
    box.edit:SetFocus()
end
