-- A Yeah Nah Mate tab on Blizzard's Guild & Communities window (J), under its own column of tabs on the
-- window's right edge (chat, roster, guild info...), in the same style. Clicking it closes their window
-- and opens ours.
--
-- On by default; Settings (Minimap section) turns it off (settings.guildButton). Checked on Forever
-- (0.20.3): a plain Hide of their window closes it cleanly, and J, C and P open in the right place
-- after. We may not use the game's panel functions (they taint), so it's a plain Hide, never in
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

-- Other tabs in the same column that we don't know by name (Forever has a fifth, a settings tab, under
-- Guild info: our button sat hidden behind it). Any shown child of their window lined up with the chat
-- tab and the same width counts. Read only; nothing of theirs is changed.
local extras = {}
local function ColumnExtras(cf)
    wipe(extras)
    local chat = cf.ChatTab
    local left, width = Num(chat, "GetLeft"), Num(chat, "GetWidth")
    if not left or not width or type(cf.GetChildren) ~= "function" then return extras end
    local known = {}
    for _, key in ipairs(TABS) do if type(cf[key]) == "table" then known[cf[key]] = true end end
    local ok, kids = pcall(function() return { cf:GetChildren() } end)
    if not ok then return extras end
    for _, k in ipairs(kids) do
        if k ~= button and not known[k] and type(k.IsShown) == "function" and k:IsShown() then
            local l, w = Num(k, "GetLeft"), Num(k, "GetWidth")
            if l and w and Num(k, "GetTop") and math.abs(l - left) < 4 and math.abs(w - width) < 4 then
                extras[#extras + 1] = k
            end
        end
    end
    return extras
end

-- Their lowest shown tab, the gap between their tabs, and how many we found (named, extra).
local function LowestTab()
    local cf = Their()
    if not cf then return nil end
    local lowest, lowBottom, prev, gap, found = nil, nil, nil, nil, 0
    local function Consider(t)
        local top, bottom = Num(t, "GetTop"), Num(t, "GetBottom")
        if prev and top and not gap then gap = prev - top end
        if bottom and (not lowBottom or bottom < lowBottom) then lowest, lowBottom = t, bottom end
        if not bottom and not lowest then lowest = t end
        prev = bottom
    end
    for _, key in ipairs(TABS) do
        local t = cf[key]
        if type(t) == "table" and t.IsShown then
            found = found + 1
            if t:IsShown() then Consider(t) end
        end
    end
    local more = ColumnExtras(cf)
    for _, t in ipairs(more) do Consider(t) end
    return lowest, (gap and gap > 0 and gap < 80) and gap or GAP, found, #more
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

-- On unless the player unticks it in Settings (settings.guildButton).
function GB.On() return ns.settings ~= nil and ns.settings.guildButton ~= false end

-- Make, show or hide our button to match the setting.
function GB.Apply()
    local on = GB.On()
    -- Never load their window ourselves (code loaded by an addon is tainted): if it isn't loaded yet,
    -- the button is made when the game loads it (the first J).
    if on and Loaded() then Build() end
    if button then button:SetShown(on) end
    ns.Fire("GUILDBUTTON")
end

-- The dev console's switch and Settings' tick both land here.
function GB.Set(on)
    ns.settings.guildButton = on and true or false
    GB.Apply()
end

ns.OnEvent("ADDON_LOADED", function(name)
    if name == "Blizzard_Communities" and GB.On() then ns.Safe(Build) end
end)
ns.Listen("LOGIN", function() ns.Safe(GB.Apply) end)
ns.Listen("SETTINGS", function() if button or GB.On() then ns.Safe(GB.Apply) end end)

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
        local lowest, gap, found, more = LowestTab()
        Add(string.format("Tabs found: %d of %d named, %d more in the same column; gap between them: %s",
            found or 0, #TABS, more or 0, tostring(gap)))
        for i, t in ipairs(extras) do
            local name
            for k, v in pairs(cf) do if v == t then name = tostring(k) break end end
            Add(string.format("  extra %d: %s, top %s, bottom %s", i, name or (t.GetName and t:GetName()) or "no name",
                tostring(Num(t, "GetTop")), tostring(Num(t, "GetBottom"))))
        end
        local lowName
        for k, v in pairs(cf) do if v == lowest then lowName = tostring(k) break end end
        Add("Our button goes under: " .. (lowName or (lowest and "a tab with no name") or "none (top right)"))
        Add("In the game's window list (UIPanelWindows): " .. tostring(type(UIPanelWindows) == "table"
            and UIPanelWindows.CommunitiesFrame ~= nil))
    end
    Add("Setting: " .. (GB.On() and "ON" or "OFF (Settings, or the console's switch)"))
    Add("Our button: " .. (button and (button:IsShown() and "made and shown" or "made, hidden") or "not made yet"))
    Add("Last click: " .. (GB.last or "none yet"))
    ns.db.dev.guildProbe = { at = date and date("%Y-%m-%d %H:%M") or "?", lines = out }
    return out
end

-- For tests.
function GB.Button() return button end
