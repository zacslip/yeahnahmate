-- The tab row: each tab is at least as wide as its own label plus a margin (no label runs off its button),
-- the row fills the window's width exactly, and tabs never overlap. Labels are "measured" here at 7.5 per
-- letter, wider than the game's font, so the row is as tight as it gets with the GM tab showing.
local ns = LoadAddon("YeahNahMate", "YeahNahMate")
local UI = ns.UI

local PER = 7.5
local function X(b) return type(b._pt[2]) == "number" and b._pt[2] or b._pt[4] end
local function Tabs()
    local list = {}
    for _, o in ipairs(CREATED) do
        if o.sel and o._kind == "Button" and o._parent == YeahNahMateFrame and o._pt and o:IsShown() then list[#list + 1] = o end
    end
    table.sort(list, function(a, b) return X(a) < X(b) end)
    return list
end

UI.Open("home")
Tick(1)
for _, o in ipairs(CREATED) do
    if o.sel and o._kind == "Button" and o._parent == YeahNahMateFrame then
        o.GetTextWidth = function(self)
            local f = self._font == GameFontNormalSmall and 0.85 or 1
            return #(self:GetText() or "") * PER * f
        end
        local set = o.SetNormalFontObject
        o.SetNormalFontObject = function(self, font) self._font = font; if set then set(self, font) end end
    end
end

local function CheckRow(what)
    UI.TabsChanged(); UI.Dirty(); Tick(1)
    local tabs = Tabs()
    check(#tabs >= 12, what .. ": " .. #tabs .. " tabs showing")
    local x, ok, fits = 12, true, true
    for _, b in ipairs(tabs) do
        if math.abs(X(b) - x) > 0.01 then ok = false end
        if b._w < b:GetTextWidth() + 12 - 0.01 then fits = false; print("  too narrow: " .. b:GetText(), b._w, b:GetTextWidth()) end
        x = X(b) + b._w + 2
    end
    check(ok, what .. ": tabs side by side, 2 apart, no overlap")
    check(fits, what .. ": every label fits its button with a margin")
    check(math.abs((x - 2) - (12 + 760 - 24)) < 0.01, what .. ": the row ends at the window's right edge (" .. (x - 2) .. ")")
end

CheckRow("normal")
-- As guild master the GM tab shows too: 13 tabs in the same row.
SlashCmdList.YEAHNAHMATE("dev rank 0")
CheckRow("with the GM tab")
check(#Tabs() == 13, "with the GM tab: 13 tabs (" .. #Tabs() .. ")")
-- Much longer labels (a translation): the font steps down rather than running off.
PER = 8.0
CheckRow("long labels")
local small = 0
for _, b in ipairs(Tabs()) do if b._font == GameFontNormalSmall then small = small + 1 end end
check(small == #Tabs(), "long labels: every tab on the smaller font")
PER = 7.5
CheckRow("back to normal")
local normal = 0
for _, b in ipairs(Tabs()) do if b._font == GameFontNormal then normal = normal + 1 end end
check(normal == #Tabs(), "normal labels: back on the normal font")
check(#ERRORS == 0, "no errors (" .. (ERRORS[1] or "none") .. ")")
