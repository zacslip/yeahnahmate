-- No broken backslashes in our Lua: "Interface\Icons\X" written with single backslashes loses them
-- (in Lua 5.1 and in the game), so the texture silently doesn't load. Shell-written files lost theirs
-- once (the minimap button, 0.4.0). Only real escapes are allowed; paths need \\.
local function listLua(dir)
    local out = {}
    for _, f in ipairs(LIST_LUA(dir)) do                      -- recursive, from tests/run.py
        if not f:find("/libs/", 1, true) then out[#out + 1] = f end
    end
    return out
end

local VALID = { a = true, b = true, f = true, n = true, r = true, t = true, v = true,
    ["\\"] = true, ['"'] = true, ["'"] = true, ["\n"] = true }

local files = {}
for _, dir in ipairs({ "YeahNahMate", "tests" }) do
    for _, f in ipairs(listLua(dir)) do files[#files + 1] = f end
end
check(#files > 10, #files .. " files checked")

local bad = 0
for _, f in ipairs(files) do
    local h = assert(io.open(f, "rb"))
    local code = h:read("*a")
    h:close()
    code = code:gsub("%-%-[^\n]*", "")          -- comments may say anything
    local i = 1
    while true do
        local a = code:find("\\", i, true)
        if not a then break end
        local c = code:sub(a + 1, a + 1)
        if not VALID[c] and not c:match("%d") then
            local line = select(2, code:sub(1, a):gsub("\n", "")) + 1
            check(false, f .. ":" .. line .. " has a broken backslash before '" .. c .. "'")
            bad = bad + 1
        end
        i = a + 2
    end
end
check(bad == 0, "no broken backslashes in strings")
