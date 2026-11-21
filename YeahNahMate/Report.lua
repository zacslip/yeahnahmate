-- Better error reports: /ynm errors says which version each error came from and marks old ones,
-- /ynm errors clear wipes the list, and Report.Text() builds the block the About panel lets a player copy.
-- Nothing here sends anything: the player chooses where to paste it. No character or guild names are added.
local ADDON, ns = ...
local L = ns.L

local Report = {}
ns.Report = Report

local SHOW = 3                  -- errors printed in chat, and in a report
local MSG_MAX, STACK_MAX, STACK_LINES = 200, 100, 2
local ADDONS_MAX = 260          -- characters of addon names
-- A Discord message holds 2000 characters; the longest possible report stays under this.
Report.MAX_LENGTH = 1900

local function IsCurrent(e) return e.ver == ns.VERSION end

-- A copy of the list: this version's first, then whatever happened most recently.
local function Sorted()
    local list, order = {}, {}
    for i, e in ipairs(ns.db and ns.db.errors or {}) do
        if type(e) == "table" then
            list[#list + 1] = e
            order[e] = i
        end
    end
    table.sort(list, function(a, b)
        local ca, cb = IsCurrent(a), IsCurrent(b)
        if ca ~= cb then return ca end
        local la, lb = a.last or a.at or 0, b.last or b.at or 0
        if la ~= lb then return la > lb end
        return order[a] > order[b]
    end)
    return list
end

local function Counts(list)
    local current = 0
    for _, e in ipairs(list) do if IsCurrent(e) then current = current + 1 end end
    return current, #list - current
end

local function When(t)
    if type(t) ~= "number" or not date then return "?" end
    return date("%d %b %H:%M", t)
end

local function Version(e) return e.ver and ("v" .. tostring(e.ver)) or L.ERRORS_NO_VERSION end

-- Cut to n bytes without splitting a letter in two.
local function Cut(s, n)
    if #s <= n then return s end
    local stop = n - 3
    while stop > 0 do
        local b = s:byte(stop + 1)
        if not b or b < 128 or b >= 192 then break end
        stop = stop - 1
    end
    return s:sub(1, stop) .. "..."
end

-- Plain text for the copy box: no colour codes (a stray | changes what an edit box shows), one line,
-- and short file paths.
local function Clean(s)
    s = tostring(s or "")
    s = s:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):gsub("|", "/")
    s = s:gsub('%[string "@?([^"]*)"%]', "%1"):gsub("Interface[/\\]AddOns[/\\]", "")
    s = s:gsub("%s+", " ")
    return strtrim(s)
end

local function StackLines(stack)
    local out = {}
    if type(stack) ~= "string" then return out end
    for line in stack:gmatch("[^\n]+") do
        if not line:find("[C]:", 1, true) then
            local text = Clean(line)
            if text ~= "" then out[#out + 1] = Cut(text, STACK_MAX) end
            if #out >= STACK_LINES then break end
        end
    end
    return out
end

-- The other addons running now, by name, not Blizzard's own.
function Report.OtherAddons()
    local out = {}
    local A = C_AddOns
    if not (A and A.GetNumAddOns and A.GetAddOnInfo and A.IsAddOnLoaded) then return out end
    local ok, count = pcall(A.GetNumAddOns)
    count = ok and ns.Public(count, "number") or 0
    for i = 1, count do
        local okName, name = pcall(A.GetAddOnInfo, i)
        name = okName and ns.Public(name, "string") or nil
        local okLoaded, loading, loaded = pcall(A.IsAddOnLoaded, i)
        if name and name ~= ADDON and not name:find("^Blizzard_") and okLoaded and (loading or loaded) then
            out[#out + 1] = name
        end
    end
    table.sort(out)
    return out
end

local function AddonLine()
    local names = Report.OtherAddons()
    if #names == 0 then return L.REPORT_NO_ADDONS end
    local shown, length = {}, 0
    for _, name in ipairs(names) do
        name = Cut(Clean(name), 40)
        if length + #name + 2 > ADDONS_MAX then break end
        shown[#shown + 1] = name
        length = length + #name + 2
    end
    local line = string.format(L.REPORT_ADDONS, #names, table.concat(shown, ", "))
    if #shown < #names then line = line .. " " .. string.format(L.REPORT_MORE, #names - #shown) end
    return line
end

-- The block to paste, in a Discord code block so it keeps its lines.
function Report.Text()
    local list = Sorted()
    local current, older = Counts(list)
    local out = { "```", string.format(L.REPORT_TITLE, tostring(ns.VERSION)) }
    local ok, _, _, _, interface = pcall(GetBuildInfo)
    if not ok then interface = nil end
    out[#out + 1] = string.format(L.REPORT_GAME, tostring(ns.ClientBuild() or "?"), tostring(interface or "?"))
    out[#out + 1] = string.format(L.REPORT_COUNTS, current, older)
    for i = 1, math.min(SHOW, #list) do
        local e = list[i]
        out[#out + 1] = string.format("[%d] x%d, %s, last %s, game %s%s", i, e.count or 1, Version(e), When(e.last or e.at),
            tostring(e.build or "?"), IsCurrent(e) and "" or (" " .. L.REPORT_OLDER))
        out[#out + 1] = Cut(Clean(e.msg), MSG_MAX)
        for _, line in ipairs(StackLines(e.stack)) do out[#out + 1] = "  " .. line end
    end
    out[#out + 1] = AddonLine()
    out[#out + 1] = "```"
    return table.concat(out, "\n")
end

local function ShowErrors()
    local list = Sorted()
    if #list == 0 then ns.Print(L.ERRORS_NONE) return end
    local current, older = Counts(list)
    if current > 0 then
        ns.Print(string.format(L.ERRORS_HEADER, current, tostring(ns.VERSION), older))
    else
        ns.Print(string.format(L.ERRORS_ONLY_OLD, tostring(ns.VERSION), older))
    end
    for i = 1, math.min(SHOW, #list) do
        local e = list[i]
        local count = (e.count or 1) > 1 and ("x" .. e.count .. ", ") or ""
        local line = "(" .. count .. Version(e) .. ", " .. When(e.last or e.at) .. ") " .. tostring(e.msg)
        if IsCurrent(e) then
            print("  " .. line)
        else
            print("  " .. ns.GREY .. L.ERRORS_OLD .. " " .. line .. "|r")
        end
    end
    print("  " .. ns.GREY .. L.ERRORS_HINT .. "|r")
end

-- /ynm errors [clear]
function Report.Command(arg)
    if arg == "clear" then
        local n = #ns.db.errors
        wipe(ns.db.errors)
        ns.Print(n > 0 and string.format(L.ERRORS_CLEARED, n) or L.ERRORS_NONE)
    elseif arg == nil or arg == "" then
        ShowErrors()
    else
        ns.Print(L.ERRORS_HELP)
    end
end

--@do-not-package@
-- /ynm dev errtest now | old: for the Errors page of /ynmdev.
ns.devCommands.errtest = function(arg)
    if arg == "now" then
        ns.Safe(function() error("Test error from the dev console (safe to ignore)") end)
    elseif arg == "old" then
        local now = GetServerTime()
        table.insert(ns.db.errors, { msg = "Old.lua:59: pretend error from an older version", count = 343,
            at = now - 86400, last = now - 86400, ver = "0.20.1", stack = "Old.lua:59: in function 'Pretend'" })
    else
        ns.Print("/ynm dev errtest now | old")
    end
end
--@end-do-not-package@
