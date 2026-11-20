-- 0.9.7: the guild breakdown behind Home's "Online" box (classes, levels, professions, at a glance).
math.randomseed(7)
YeahNahMateDB = nil
local ns = LoadAddon("YeahNahMate", "YeahNahMate")
LOGGED_IN = true
FireEvent("PLAYER_LOGIN")
Tick(3)
local B = ns.Breakdown

-- The fake roster: Ned (Shaman 22), Bluey (Warrior 23), Bingo (Priest 20), Chilli (Mage 40) online;
-- Bandit (Rogue 24) offline for 10 days.
local all = B.Get(B.ALL)
check(all.total == 5 and all.online == 4, "all members: 5, 4 online")
check(#all.classes == 5, "five classes")
check(all.bands[3] == 4 and all.bands[5] == 1, "levels: four in their 20s, one in their 40s")
check(all.tanks == 1 and all.healers == 2, "could tank 1 (warrior), could heal 2 (shaman, priest)")
check(all.top == 40 and all.topN == 1, "highest level 40")
check(all.myBand == 3, "my band (level 22) is the 20s")
check(#all.ranks == 3 and all.ranks[1].index == 0, "ranks listed guild master first")

local online = B.Get(B.ONLINE)
check(online.total == 4, "online now: 4")
check(B.HasLastOnline(), "the game says when members were last on")
check(B.Get(B.ACTIVE).total == 4, "on this week: Bandit (10 days ago) left out")
FAKE.lastOnlineDays = 2
ns.Guild.Scan()
check(B.Get(B.ACTIVE).total == 5, "on this week: Bandit (2 days ago) counted")

-- 0.9.8 Roster search: part of a name, any case, through every member whatever the filter.
local R = ns.Roster
local found = R.Get(R.ONLINE, nil, nil, "bandit")
check(#found == 1 and found[1].name == "Bandit Heeler", "search finds an offline guildie even on the Online filter")
check(#R.Get(R.ALL, nil, nil, "HEELER") == 4, "search ignores case: four Heelers")
check(#R.Get(R.ALL, nil, nil, "nobody like this") == 0, "no match: empty list")
check(#R.Get(R.ONLINE, nil, nil, "  ") == 4, "a blank search is no search (online filter applies)")

-- Professions: mine once read; crafts nobody has are named.
FAKE.trade = { line = 197, rank = 75, max = 150, recipes = { [3755] = true } }
FireEvent("TRADE_SKILL_SHOW")
Tick(2)
FAKE.trade = nil
local d = B.Get(B.ALL)
check(#d.profs == 1 and d.profs[1].line == 197 and d.profs[1].n == 1 and d.profs[1].top == 75, "Tailoring: 1 guildie, top 75")
local missingAlchemy = false
for _, n in ipairs(d.missing) do if n == "Alchemy" then missingAlchemy = true end end
check(missingAlchemy, "Alchemy named as missing")
check(d.addon >= 1, "I count as an addon user")

-- The page: open it from Home's Online box, switch views, no errors.
ns.UI.Open("home")
Tick(1)
ns.UI.Select("breakdown")
Tick(1)
for _, o in ipairs(CREATED) do
    for _, s in ipairs({ "OnClick", "OnEnter", "OnLeave" }) do
        if o._scripts[s] and not IsInside(o, "YeahNahMateWhisper") and o._name ~= "YeahNahMateWelcome"
            and o._template ~= "UIPanelCloseButton" then
            o._scripts[s](o, "LeftButton")
        end
    end
end
Tick(2)
check(#(YeahNahMateDB.errors or {}) == 0, "no errors on the breakdown page (" .. tostring((YeahNahMateDB.errors or {})[1]) .. ")")
