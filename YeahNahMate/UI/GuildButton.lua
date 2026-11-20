-- A Yeah Nah Mate tab on Blizzard's Guild & Communities window (J), under its own column of tabs on the
-- window's right edge (chat, roster, guild info...), in the same style. Clicking it closes their window
-- and opens ours.
--
-- DEV ONLY for now (0.20.3 probe): off unless the dev console switches it on (ns.db.dev.guildButton).
-- What we don't know yet on Forever: whether hiding their window ourselves leaves the game's window
-- layout happy. We may not use the game's panel functions (they taint), so it's a plain Hide, never in
-- combat. We don't hook or change anything of Blizzard's: our button is our own frame, parented to
-- their window so it shows and hides with it, and placed by reading where their tabs are.
local ADDON, ns = ...
local UI = ns.UI

local GB = {}
ns.GuildButton = GB

-- Their tabs, top to bottom (Blizzard_Communities). Any may be missing or hidden on Forever.
local TABS = { "ChatTab", "RosterTab", "GuildBenefitsTab", "GuildInfoTab" }
local SIZE, GAP = 32, 17           -- retail's tab size and spacing; used when theirs can't be read

local button
GB.last = nil                      -- what the last click did, for the dev console

local function Their() return type(CommunitiesFrame) == "table" and CommunitiesFrame or nil end

local function Num(f, method)
    local fn = f and f[method]
    if type(fn) ~= "function" then return nil end
    local ok, v = pcall(fn, f)
    return ok and ns.Public(v, "number") or nil
end

local function Loaded()
    if C_AddOns and C_AddOns.IsAddOnLoaded then
        local ok, v = pcall(C_AddOns.IsAddOnLoaded, "Blizzard_Communities")
        return ok and v == true
    end
    return Their() ~= nil
end

-- Their lowest shown tab, the gap between their tabs, and how many we found.
local function LowestTab()
    local cf = Their()
    if not cf then return nil end
    local lowest, lowBottom, prev, gap, found = nil, nil, nil, nil, 0
    for _, key in ipairs(TABS) do
        local t = cf[key]
        if type(t) == "table" and t.IsShown then
            found = found + 1
            if t:IsShown() then
                local top, bottom = Num(t, "GetTop"), Num(t, "GetBottom")
                if prev and top and not gap then gap = prev - top end
                if bottom and (not lowBottom or bottom < lowBottom) then lowest, lowBottom = t, bottom end
                if not bottom and not lowest then lowest = t end
                prev = bottom
            end
        end
    end
    return lowest, (gap and gap > 0 and gap < 80) and gap or GAP, found
end

local function Place()
    if not button then return end
    local lowest, gap = LowestTab()
    if lowest == button.anchor and gap == button.gap then return end
    button.anchor, button.gap = lowest, gap
    button:ClearAllPoints()
    if lowest then
        button:SetPoint("TOP", lowest, "BOTTOM", 0, -gap)
    else
        button:SetPoint("TOPLEFT", Their(), "TOPRIGHT", 0, -36)
    end
end

local function Click(self)
    self:SetChecked(false)
    local cf = Their()
    if InCombatLockdown() then
        -- Hiding their window in combat could be blocked; leave it open, ours goes on top.
        GB.last = "in combat: their window left open, ours opened"
    elseif cf and cf:IsShown() then
        cf:Hide()
        GB.last = cf:IsShown() and "their window didn't close (the game kept it open); ours opened"
            or "their window closed, ours opened"
    else
        GB.last = "ours opened"
    end
    UI.Open()
    ns.Fire("GUILDBUTTON")
end

local function Build()
    local cf = Their()
    if not cf or button then return end
    -- A CheckButton like theirs: the spellbook-style tab border, our crest as the icon.
    button = CreateFrame("CheckButton", nil, cf)
    button:SetSize(SIZE, SIZE)
    local bg = button:CreateTexture(nil, "BACKGROUND")
    bg:SetTexture("Interface\\SpellBook\\SpellBook-SkillLineTab")
    bg:SetSize(64, 64)
    bg:SetPoint("TOPLEFT", -3, 11)
    button:SetNormalTexture(UI.ICON)
    button:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
    button:SetCheckedTexture("Interface\\Buttons\\CheckButtonHilight", "ADD")
    button:SetScript("OnClick", function(self) ns.Safe(Click, self) end)
    button:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText("Yeah Nah Mate")
        GameTooltip:AddLine("Close this window and open Yeah Nah Mate.", 1, 1, 1, true)
        GameTooltip:Show()
    end)
    button:SetScript("OnLeave", function() GameTooltip:Hide() end)
    -- Their tabs come and go (guild vs other communities): keep under the lowest, checked twice a second
    -- while the window is open (our own frame's OnUpdate; nothing of theirs is hooked).
    local wait = 0
    button:SetScript("OnUpdate", function(_, e)
        wait = wait - e
        if wait > 0 then return end
        wait = 0.5
        ns.Safe(Place)
    end)
    button:SetScript("OnShow", function() ns.Safe(Place) end)
    Place()
end

function GB.On() return ns.db and ns.db.dev and ns.db.dev.guildButton == true end

-- Show or hide our button (the dev console's switch).
function GB.Set(on)
    ns.db.dev.guildButton = on and true or nil
    -- Never load their window ourselves (code loaded by an addon is tainted): if it isn't loaded yet,
    -- the button is made when the game loads it (the first J).
    if on and Loaded() then Build() end
    if button then button:SetShown(on == true) end
    ns.Fire("GUILDBUTTON")
end

ns.OnEvent("ADDON_LOADED", function(name)
    if name == "Blizzard_Communities" and GB.On() then ns.Safe(Build) end
end)
ns.Listen("LOGIN", function() if GB.On() and Loaded() then ns.Safe(Build) end end)

-- For the dev console: what the game's guild window looks like to us, one line per finding; also
-- saved to ns.db.dev.guildProbe (written to disk on /reload).
function GB.Probe()
    local out = {}
    local function Add(s) out[#out + 1] = s end
    local cf = Their()
    Add("Blizzard_Communities loaded: " .. tostring(Loaded()))
    Add("CommunitiesFrame: " .. (cf and ("yes, " .. (cf:IsShown() and "open" or "closed")) or "NOT FOUND"))
    if cf then
        for _, key in ipairs(TABS) do
            local t = cf[key]
            if type(t) == "table" and t.IsShown then
                Add(string.format("  %s: %s, top %s, bottom %s", key, t:IsShown() and "shown" or "hidden",
                    tostring(Num(t, "GetTop")), tostring(Num(t, "GetBottom"))))
            else
                Add("  " .. key .. ": not found")
            end
        end
        local _, gap, found = LowestTab()
        Add(string.format("Tabs found: %d of %d; gap between them: %s", found or 0, #TABS, tostring(gap)))
        Add("In the game's window list (UIPanelWindows): " .. tostring(type(UIPanelWindows) == "table"
            and UIPanelWindows.CommunitiesFrame ~= nil))
    end
    Add("Dev switch: " .. (GB.On() and "ON" or "OFF (tick Add our button to the guild window)"))
    Add("Our button: " .. (button and (button:IsShown() and "made and shown" or "made, hidden") or "not made yet"))
    Add("Last click: " .. (GB.last or "none yet"))
    ns.db.dev.guildProbe = { at = date and date("%Y-%m-%d %H:%M") or "?", lines = out }
    return out
end

-- For tests.
function GB.Button() return button end
