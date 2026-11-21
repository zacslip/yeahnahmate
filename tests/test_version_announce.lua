-- A test copy of an unreleased version must not tell the guild that version is out: guildies treat
-- the highest version they hear as the latest (a guildie on the real latest was told to update).
math.randomseed(25)
YeahNahMateDB = nil
local realMeta = C_AddOns.GetAddOnMetadata
C_AddOns.GetAddOnMetadata = function(_, key)
    if key == "Version" then return "0.24.0" end
    if key == "X-Released" then return "0.23.1" end
end
local ns = LoadAddon("YeahNahMate", "YeahNahMate")
C_AddOns.GetAddOnMetadata = realMeta
LOGGED_IN = true
FireEvent("PLAYER_LOGIN")
Tick(15)
local Ser = LibStub("AceSerializer-3.0")
local function Hellos(from)
    local list = {}
    for i = from or 1, #SENT do
        local ok, m = Ser:Deserialize(SENT[i].text)
        if ok and type(m) == "table" and m.t == "HI" then list[#list + 1] = m end
    end
    return list
end

check(ns.VERSION == "0.24.0" and ns.ANNOUNCED_VERSION == "0.23.1", "a stamped test copy knows both versions")
local hellos = Hellos()
check(#hellos > 0, "it says hello to the guild")
local leaked = false
for _, m in ipairs(hellos) do if m.ver ~= "0.23.1" then leaked = true end end
check(not leaked, "every hello announces the last release, never the test version")

-- A whispered reply to someone logging in says the same.
local before = #SENT
INJECT("YNM", Ser:Serialize({ v = 1, t = "HI", ver = "0.23.1", ask = true }), "GUILD", "Bluey Heeler")
Tick(8)
local replies = Hellos(before + 1)
check(#replies > 0 and replies[#replies].ver == "0.23.1", "the reply to a guildie announces the last release too")

-- My own window still knows what I'm running, and a real newer release still gets noticed.
INJECT("YNM", Ser:Serialize({ v = 1, t = "HI", ver = "0.23.1" }), "GUILD", ns.me)
Tick(1)
check(ns.Comm.users[ns.me] and ns.Comm.users[ns.me].ver == "0.24.0", "my own entry keeps my real version")
check(ns.Comm.newest == nil, "the last release isn't 'newer' than my test copy")
INJECT("YNM", Ser:Serialize({ v = 1, t = "HI", ver = "0.25.0" }), "GUILD", "Bingo Heeler")
Tick(1)
check(ns.Comm.newest == "0.25.0", "a higher version from a guildie is still noticed")

-- The rule itself: ordinary copies and bad stamps announce their own version.
local A = ns.AnnouncedVersion
check(A("0.24.0", nil) == "0.24.0", "no stamp (CurseForge): its own version")
check(A("0.24.0", "0.24.0") == "0.24.0", "released version: its own")
check(A("0.24.0", "0.25.0") == "0.24.0", "a stamp can't raise the version")
check(A("0.24.0", "junk") == "0.24.0" and A("0.24.0", 23) == "0.24.0", "a bad stamp is ignored")
check(A("test", "0.23.1") == "test", "a version without numbers is left alone")

-- The stamp only exists in installed test copies, never in the repo's .toc.
local f = assert(io.open("YeahNahMate/YeahNahMate.toc", "rb"))
local toc = f:read("*a")
f:close()
check(not toc:find("X-Released", 1, true), "the repo's .toc has no stamp, so CurseForge builds can't have one")
check(#ERRORS == 0, "no errors (" .. (ERRORS[1] or "none") .. ")")
