-- Better error reports (Report.lua, About panel): which version an error came from, old ones marked,
-- /ynm errors clear, and a report that fits one Discord message.
local LONG = string.rep("x", 900)
YeahNahMateDB = { errors = {
    { msg = "Old.lua:5: stale", count = 343, ver = "0.20.1", at = 100, last = 200, stack = "Old.lua:5: in function 'A'" },
    { msg = "NoVersion.lua:1: from long ago", count = 2, at = 50, last = 60 },
} }
local addons = { "Questie", "Blizzard_Communities", "YeahNahMate", "NotLoaded", "Details" }
for i = 1, 60 do addons[#addons + 1] = "SomeLongAddonName" .. i end
C_AddOns.GetNumAddOns = function() return #addons end
C_AddOns.GetAddOnInfo = function(i) return addons[i] end
C_AddOns.IsAddOnLoaded = function(i) return addons[i] ~= "NotLoaded", addons[i] ~= "NotLoaded" end

local ns = LoadAddon("YeahNahMate", "YeahNahMate")
LOGGED_IN = true
FireEvent("PLAYER_LOGIN")
Tick(15)
local UI, L, R = ns.UI, ns.L, ns.Report

local printed = {}
local realPrint = print
local function Run(cmd)
    printed = {}
    print = function(...) printed[#printed + 1] = table.concat({ ... }, " ") end
    ns.Slash(cmd)
    print = realPrint
    return table.concat(printed, "\n")
end

-- Only old errors: says this version is clean.
local out = Run("errors")
check(out:find(string.format(L.ERRORS_ONLY_OLD, ns.VERSION, 2), 1, true), "only old errors: this version is clean")
check(out:find("x343, v0.20.1", 1, true), "the version is on the line")
check(out:find(L.ERRORS_OLD, 1, true), "and it's marked as older")
check(out:find(L.ERRORS_NO_VERSION, 1, true), "an entry with no version says so")

-- The same error in this version is a new entry: an old count can't look current.
ns.Safe(function() error("Old.lua:5: stale", 0) end)
check(#ns.db.errors == 3, "same text in a new version: its own entry (" .. #ns.db.errors .. ")")
check(ns.db.errors[1].count == 343, "the old count is left alone")
local new = ns.db.errors[3]
check(new.ver == ns.VERSION and new.count == 1 and new.build == "1.60.1.70790", "the new one has this version and the game build")
ns.Safe(function() error("Old.lua:5: stale", 0) end)
check(#ns.db.errors == 3 and new.count == 2, "a repeat in the same version is counted")

out = Run("errors")
check(out:find(string.format(L.ERRORS_HEADER, 1, ns.VERSION, 2), 1, true), "header counts this version and older")
check(printed[2]:find("x2, v" .. ns.VERSION, 1, true) and not printed[2]:find(L.ERRORS_OLD, 1, true), "this version's error comes first, unmarked")

-- The report.
ns.db.errors[3].stack = '[string "@Interface/AddOns/YeahNahMate/Old.lua"]:5: in function |cffff0000Red|r\n[C]: in function error\nCore.lua:64: in Safe\nThird.lua:1: too many'
local text = R.Text()
check(text:find("^```\n") and text:find("\n```$"), "in a code block for Discord")
check(text:find("v" .. ns.VERSION, 1, true) and text:find("1.60.1.70790", 1, true) and text:find("16001", 1, true), "has my version and the game's")
check(text:find("1 in this version, 2 older", 1, true), "counts them")
check(text:find("YeahNahMate/Old.lua:5", 1, true) and not text:find("Interface/AddOns", 1, true), "short file paths")
check(not text:find("|", 1, true), "no colour codes or stray bars")
check(text:find("Core.lua:64", 1, true) and not text:find("Third.lua", 1, true) and not text:find("[C]", 1, true), "the first two useful stack lines")
check(text:find(L.REPORT_OLDER, 1, true), "old errors are marked")
check(text:find("Details", 1, true) and text:find("Questie", 1, true), "lists other addons")
check(not text:find("NotLoaded", 1, true) and not text:find("Blizzard_", 1, true) and not text:find("Other addons on (%d+): YeahNahMate"), "not unloaded ones, Blizzard's or ours")
check(text:find("more", 1, true), "a long addon list says how many more")
check(not text:find(ns.me or "\0", 1, true), "no character name")

-- The longest report still fits one Discord message.
for i = 1, 40 do
    table.insert(ns.db.errors, { msg = "Long" .. i .. ".lua:1: " .. LONG, count = 99999, ver = ns.VERSION, at = i, last = i,
        build = "1.60.1.70790", stack = LONG .. "\n" .. LONG .. "\n" .. LONG })
end
text = R.Text()
check(#text <= R.MAX_LENGTH, "the longest report fits one Discord message (" .. #text .. ")")
-- A cut never splits a letter.
ns.db.errors[#ns.db.errors].msg = string.rep("é", 400)
text = R.Text()
check(not text:find("\195%.%.%."), "a long line isn't cut through a letter")

-- The copy box in the About panel.
UI.Open("home")
UI.aboutButton:Click()
local p = UI.AboutPanel()
check(p.copyBtn and p.copyBtn:GetText() == L.REPORT_BTN, "the About panel has the report button")
p.copyBtn:Click()
local c = p.copy
check(c:IsShown() and c.edit:GetText() == R.Text(), "the box holds the report")
c.edit:SetText("typed over it")
c.edit:GetScript("OnTextChanged")(c.edit, true)
check(c.edit:GetText() == R.Text(), "typing in it can't change the report")
c.edit:GetScript("OnEscapePressed")(c.edit)
check(not c:IsShown() and p:IsShown(), "Esc goes back to the About panel")
p.copyBtn:Click()
c.back:Click()
check(not c:IsShown(), "Back too")
p.copyBtn:Click()
p:Hide()
check(not c:IsShown(), "closing About closes the box")
UI.OpenErrorReport()
check(p:IsShown() and c:IsShown(), "the console can open it directly")

-- Clearing.
local n = #ns.db.errors
out = Run("errors clear")
check(#ns.db.errors == 0 and out:find(string.format(L.ERRORS_CLEARED, n), 1, true), "/ynm errors clear wipes them and says how many")
out = Run("errors")
check(out:find(L.ERRORS_NONE, 1, true), "then no errors")
out = Run("errors nonsense")
check(out:find(L.ERRORS_HELP, 1, true), "a wrong word shows how to use it")
text = R.Text()
check(text:find("0 in this version, 0 older", 1, true), "a report with no errors still works")

check(ns.ClientBuild() == "1.60.1.70790", "reads the game build")
