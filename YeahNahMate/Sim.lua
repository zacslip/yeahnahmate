-- Sim mode, for testing alone: /ynm dev sim on|off. Adds made-up guildmates to the roster and has
-- them "send" addon messages through Comm.Receive, the same path real messages take. They exist
-- only on this screen: nothing is sent to anyone because of them. It stays on across /reload
-- until turned off.
local ADDON, ns = ...
local L = ns.L
local Ser = LibStub("AceSerializer-3.0")

local Sim = {}
ns.Sim = Sim

-- name, level offset from mine, class, zone ("@zone" = my zone), online, has the addon
local PEOPLE = {
    { "Bazza Stubbs",    0,  "WARRIOR", "@zone",               true,  true  },
    { "Shazza Kettle",   1,  "PRIEST",  "@zone",               true,  true  },
    { "Davo Thongs",    -2,  "HUNTER",  "@zone",               true,  true  },
    { "Kezza Galah",    3,  "MAGE",    "Orgrimmar",           true,  true  },
    { "Robbo Esky",   -1,  "ROGUE",   "The Barrens",         true,  false },
    { "Macca Ute",    6,  "SHAMAN",  "Stranglethorn Vale",  true,  true  },
    { "Tezza Brolly",   -5,  "WARLOCK", "Silverpine Forest",   true,  true  },
    { "Johnno Snag",  12,  "DRUID",   "Desolace",            true,  true  },
    { "Sully Dunny",  -10,  "WARRIOR", "Durotar",             true,  false },
    { "Gazza Billabong",    2,  "PALADIN", "Ashenvale",           true,  true  },
    { "Trev Drongo",    20,  "PRIEST",  "Undercity",           true,  true  },
    { "Woody Stubby",    4,  "HUNTER",  "Hillsbrad Foothills", false, true  },
    { "Mick Larrikin",    -3,  "MAGE",    "Thousand Needles",    false, true  },
    { "Stevo Swag",   15,  "ROGUE",   "Tanaris",             false, false },
}
local ZONES = { "Durotar", "The Barrens", "Stonetalon Mountains", "Ashenvale", "Hillsbrad Foothills",
    "Thousand Needles", "Orgrimmar", "Silverpine Forest" }

-- Zone maps (uiMapID) so fake guildies elsewhere get a dot in the right zone.
local ZONE_MAP = {
    ["Durotar"] = 1411, ["Mulgore"] = 1412, ["The Barrens"] = 1413, ["Orgrimmar"] = 1454,
    ["Thunder Bluff"] = 1456, ["Undercity"] = 1458, ["Tirisfal Glades"] = 1420, ["Silverpine Forest"] = 1421,
    ["Hillsbrad Foothills"] = 1424, ["Stonetalon Mountains"] = 1442, ["Ashenvale"] = 1440,
    ["Thousand Needles"] = 1441, ["Desolace"] = 1443, ["Stranglethorn Vale"] = 1434, ["Tanaris"] = 1446,
}
-- Clans (Clans.lua): race, roles, and who leads their clan. Fakes without the addon have no race
-- (like real guildies whose race the game doesn't say).
local CLAN = {
    ["Bazza Stubbs"] = { "Orc", "t", true },     ["Shazza Kettle"] = { "Troll", "h", true },
    ["Davo Thongs"] = { "Tauren", "d" },        ["Kezza Galah"] = { "Scourge", "d", true },
    ["Macca Ute"] = { "Tauren", "hd", true },   ["Tezza Brolly"] = { "Orc", "d" },
    ["Johnno Snag"] = { "Tauren", "th" },       ["Gazza Billabong"] = { "Troll", "t" },
    ["Trev Drongo"] = { "Scourge", "h" },       ["Woody Stubby"] = { "Troll", "d" },
    ["Mick Larrikin"] = { "Scourge", "" },
}

-- What some of them are up to (status codes, Status.lua).
local DOING = { ["Davo Thongs"] = { "g", 3 }, ["Kezza Galah"] = { "t" }, ["Trev Drongo"] = { "t" },
    ["Macca Ute"] = { "g", 2 } }

local fakes = nil               -- the fake members while sim mode is on
local byName = {}
local FakeSend                  -- below: a fake message into the real receive path
local PurgeFakeEvents           -- below

-- Fake professions (from the mock-up): profession skill line -> { { guildie, skill }, ... }, and recipes
-- with made-up IDs (990001 and up) so they can't clash with real ones: name, skill line, crafters.
local SIM_PROFS = {
    [171] = { { "Shazza Kettle", 140 }, { "Tezza Brolly", 95 } },
    [164] = { { "Bazza Stubbs", 165 } },
    [333] = { { "Kezza Galah", 180 }, { "Trev Drongo", 265 } },
    [202] = { { "Woody Stubby", 150 } },
    [165] = { { "Davo Thongs", 120 }, { "Johnno Snag", 225 } },
    [197] = { { "Shazza Kettle", 150 }, { "Mick Larrikin", 110 }, { "Tezza Brolly", 75 } },
    [185] = { { "Macca Ute", 175 }, { "Davo Thongs", 90 } },
    [129] = { { "Shazza Kettle", 150 }, { "Bazza Stubbs", 120 }, { "Gazza Billabong", 140 } },
}
local SIM_RECIPES = {
    { "Minor Healing Potion", 171, { "Shazza Kettle", "Tezza Brolly" } },
    { "Lesser Healing Potion", 171, { "Shazza Kettle" } },
    { "Elixir of Lion's Strength", 171, { "Shazza Kettle", "Tezza Brolly" } },
    { "Swiftness Potion", 171, { "Shazza Kettle" } },
    { "Runed Copper Belt", 164, { "Bazza Stubbs" } },
    { "Copper Chain Vest", 164, { "Bazza Stubbs" } },
    { "Enchant Bracer - Minor Stamina", 333, { "Kezza Galah", "Trev Drongo" } },
    { "Enchant Chest - Lesser Health", 333, { "Kezza Galah", "Trev Drongo" } },
    { "Enchant Boots - Minor Agility", 333, { "Trev Drongo" } },
    { "Rough Boomstick", 202, { "Woody Stubby" } },
    { "Target Dummy", 202, { "Woody Stubby" } },
    { "Embossed Leather Vest", 165, { "Davo Thongs", "Johnno Snag" } },
    { "Dark Leather Cloak", 165, { "Johnno Snag" } },
    { "Linen Bag", 197, { "Shazza Kettle", "Mick Larrikin", "Tezza Brolly" } },
    { "Woolen Bag", 197, { "Shazza Kettle", "Mick Larrikin" } },
    { "Blue Linen Robe", 197, { "Shazza Kettle" } },
    { "Herb Baked Egg", 185, { "Macca Ute", "Davo Thongs" } },
    { "Smoked Bear Meat", 185, { "Macca Ute" } },
    { "Heavy Linen Bandage", 129, { "Shazza Kettle", "Bazza Stubbs", "Gazza Billabong" } },
    { "Wool Bandage", 129, { "Shazza Kettle", "Gazza Billabong" } },
}
local SIM_ID = 990000

function Sim.RecipeName(id)
    local r = SIM_RECIPES[id - SIM_ID]
    return r and r[1] or nil
end

-- The fake guildies' professions, while sim mode is on (Professions.lua adds them to the tab; they
-- are never saved or sent).
local simProfs = nil
local joined = {}               -- fake guildies who "joined" my party (I clicked Invite on them)

function Sim.Joined() return joined end

-- Invite on a fake guildie: nothing is sent; they just count as having joined my party.
function Sim.Join(name)
    if not byName[name] then return end
    joined[name] = true
    ns.Dungeons.Recount()
end

-- Fake guildies' events and answers live in the real calendar store while sim mode is on; they go
-- whenever sim mode starts or stops (so a /reload during sim mode leaves nothing behind).
function PurgeFakeEvents()
    local store = ns.Calendar.Store()
    if not store then return end
    local fake = {}
    for _, p in ipairs(PEOPLE) do fake[p[1]] = true end
    -- The board too: fake guild info, fake streamer cards.
    local b = ns.Board.Store()
    if b then
        if b.info and fake[b.info.by] then b.info = nil end
        if b.rank and fake[b.rank.by] then b.rank = nil end
        for name in pairs(fake) do b.streamers[name] = nil end
        ns.Fire("BOARD")
    end
    local rq = ns.Requests.Store()
    if rq then
        for key, r in pairs(rq) do
            if fake[r.owner] then rq[key] = nil
            else
                for name in pairs(fake) do
                    if r.cl then r.cl[name] = nil end
                    if r.mk then r.mk[name] = nil end
                end
                if r.mk and not next(r.mk) then r.mk = nil end
            end
        end
        ns.Fire("REQUESTS")
    end
    for key, e in pairs(store) do
        if fake[e.owner] then store[key] = nil
        elseif e.rs then for name in pairs(fake) do e.rs[name] = nil end end
    end
    ns.Fire("CALENDAR")
end

-- Fake craft requests: Davo wants bandages, Gazza wants a vest; when I post one, Shazza says she'll make it.
local function FakeRequests()
    if not fakes then return end
    local now = GetServerTime()
    ns.Safe(FakeSend, byName["Davo Thongs"], { t = "RQ", id = now, rid = SIM_ID + 19, it = "Heavy Linen Bandage", n = 10,
        note = "Have the linen, will tip", u = now + 86400, ev = now })
    ns.Safe(FakeSend, byName["Gazza Billabong"], { t = "RQ", id = now + 1, it = "Copper Chain Vest", n = 1,
        note = "No rush", u = now + 2 * 86400, ev = now })
    -- Some history: one done (Davo made it), one cancelled, one that ran out after Gazza said he'd make it.
    ns.Safe(FakeSend, byName["Johnno Snag"], { t = "RQ", id = now + 2, rid = SIM_ID + 12, it = "Embossed Leather Vest", n = 1,
        note = "", u = now + 86400, ev = now })
    ns.Safe(FakeSend, byName["Davo Thongs"], { t = "CL", o = "Johnno Snag", id = now + 2 })
    ns.Safe(FakeSend, byName["Johnno Snag"], { t = "RQ", id = now + 2, ev = now + 1, x = "done", mk = { "Davo Thongs" } })
    ns.Safe(FakeSend, byName["Macca Ute"], { t = "RQ", id = now + 3, rid = SIM_ID + 5, it = "Runed Copper Belt", n = 1,
        note = "", u = now + 86400, ev = now })
    ns.Safe(FakeSend, byName["Macca Ute"], { t = "RQ", id = now + 3, ev = now + 1, x = "cancel" })
    ns.Safe(FakeSend, byName["Tezza Brolly"], { t = "RQ", id = now + 4, rid = SIM_ID + 20, it = "Wool Bandage", n = 20,
        note = "for the raid", u = now + 3, ev = now })
    ns.Safe(FakeSend, byName["Gazza Billabong"], { t = "CL", o = "Tezza Brolly", id = now + 4 })
    -- Shazza and Mick are one person (Mick is her alt): both say so. Between them they made three
    -- requests, so Shazza is the Crafty Bugger, and Mick wears the wrench too.
    ns.Safe(FakeSend, byName["Shazza Kettle"], { t = "ALT", al = { "Mick Larrikin" }, mn = "Shazza Kettle", ev = now })
    ns.Safe(FakeSend, byName["Mick Larrikin"], { t = "ALT", al = { "Shazza Kettle" }, mn = "Shazza Kettle", ev = now })
    local function Made(owner, id, rid, item, maker, days)
        local at = now - days * 86400
        ns.Safe(FakeSend, byName[owner], { t = "RQ", id = id, rid = SIM_ID + rid, it = item, n = 1, note = "",
            u = at + 86400, at = at, ev = at })
        ns.Safe(FakeSend, byName[owner], { t = "RQ", id = id, ev = at + 3600, x = "done", mk = { maker } })
    end
    Made("Gazza Billabong", now + 5, 14, "Linen Bag", "Shazza Kettle", 2)
    Made("Macca Ute", now + 6, 20, "Wool Bandage", "Mick Larrikin", 4)
    Made("Bazza Stubbs", now + 7, 15, "Woolen Bag", "Shazza Kettle", 6)
end

ns.Listen("SENT", function(msg, channel)
    if not fakes or msg.t ~= "RQ" or msg.x or channel ~= "GUILD" then return end
    C_Timer.After(5, function()
        if fakes then ns.Safe(FakeSend, byName["Shazza Kettle"], { t = "CL", o = ns.me, id = msg.id }) end
    end)
end)

-- Ask the Guild: two open questions (one answered, one not), one answered last week with Davo's
-- answer ticked, and one of Kezza's that I can answer.
local function FakeQuestions()
    if not fakes then return end
    local now = GetServerTime()
    local function Say(name, msg) if byName[name] then ns.Safe(FakeSend, byName[name], msg) end end
    Say("Bazza Stubbs", { t = "QQ", id = now, tx = "What level should I be for Shadowfang Keep? Going with Shazza tonight.",
        tp = "dungeons", lk = { { k = "d", id = "sfk" } }, u = now + 40 * 3600, at = now - 8 * 3600, ev = now })
    Say("Davo Thongs", { t = "QA", o = "Bazza Stubbs", id = now, pv = now,
        p = { { tx = "22 is fine with a good tank. 24 if you want it comfy, the wolves hit hard.", at = now - 6 * 3600 } } })
    Say("Bazza Stubbs", { t = "QA", o = "Bazza Stubbs", id = now, pv = now,
        p = { { tx = "Legend. Is the quest from the Undercity worth grabbing first?", at = now - 5 * 3600 } } })
    Say("Kezza Galah", { t = "QQ", id = now + 1, tx = "Where do I hand this in? The quest log just says the Crossroads.",
        tp = "quests", lk = { { k = "q", id = 870, lv = 20, n = "The Forgotten Pools" } }, u = now + 46 * 3600, at = now - 2 * 3600, ev = now })
    Say("Johnno Snag", { t = "QQ", id = now + 2, tx = "Best spot to farm wool cloth around level 25?", tp = "other",
        lk = { { k = "i", id = 2592, n = "Wool Cloth" } }, u = now - 4 * 86400, at = now - 6 * 86400, ev = now - 5 * 86400 })
    Say("Gazza Billabong", { t = "QA", o = "Johnno Snag", id = now + 2, pv = now - 5 * 86400,
        p = { { tx = "Hillsbrad, the farmers and the shore murlocs. Southshore is close for repairs.", at = now - 6 * 86400 + 3600 } } })
    Say("Davo Thongs", { t = "QA", o = "Johnno Snag", id = now + 2, pv = now - 5 * 86400,
        p = { { tx = "Shadowfang trash drops heaps too if you've got a group.", at = now - 6 * 86400 + 7200 } } })
    Say("Johnno Snag", { t = "QQ", id = now + 2, tx = "Best spot to farm wool cloth around level 25?", tp = "other",
        lk = { { k = "i", id = 2592, n = "Wool Cloth" } }, u = now - 4 * 86400, at = now - 6 * 86400,
        ev = now - 5 * 86400 + 1, x = "done", hp = { "Gazza Billabong", "Davo Thongs" } })
    -- Two more Davo helped with, so he's the Lore Master (3 points).
    local function Done(name, id, tx, tp, days, answer)
        Say(name, { t = "QQ", id = id, tx = tx, tp = tp, u = now - (days - 2) * 86400, at = now - days * 86400,
            ev = now - days * 86400 + 60, x = "done", hp = { "Davo Thongs" } })
        Say("Davo Thongs", { t = "QA", o = name, id = id, pv = now - days * 86400 + 30,
            p = { { tx = answer, at = now - days * 86400 + 30 } } })
    end
    Done("Macca Ute", now + 3, "Where's the warlock trainer in Orgrimmar?", "class", 9,
        "Cleft of Shadow, down the ramp near the bank.")
    Done("Shazza Kettle", now + 4, "Who sells Mageweave thread?", "professions", 12,
        "Tailoring supplies in the Drag. Bit pricey but always there.")
end

-- A minute in, Macca asks something new (for the small alert, if it's ticked on the Ask tab).
local function FakeNewQuestion()
    if not fakes or not byName["Macca Ute"] then return end
    local now = GetServerTime()
    ns.Safe(FakeSend, byName["Macca Ute"], { t = "QQ", id = now + 5, tx = "Anyone know where the Ragefire Chasm entrance is?",
        tp = "dungeons", lk = { { k = "d", id = "rfc" } }, u = now + 48 * 3600, at = now, ev = now })
    -- Officer removal: Kezza posts rubbish on it, and a bit later Bazza (an officer) removes it.
    local id = now + 5
    C_Timer.After(20, function()
        if not fakes or not byName["Kezza Galah"] then return end
        ns.Safe(FakeSend, byName["Kezza Galah"], { t = "QA", o = "Macca Ute", id = id, pv = GetServerTime(),
            p = { { tx = "lol just follow the smell. WTS gold cheap, whisper me", at = GetServerTime() } } })
    end)
    C_Timer.After(50, function()
        if not fakes or not byName["Bazza Stubbs"] then return end
        ns.Safe(FakeSend, byName["Bazza Stubbs"], { t = "QM", o = "Macca Ute", id = id, who = "Kezza Galah", ev = GetServerTime() })
    end)
end

-- When I ask, Shazza answers after a few seconds and Bazza a bit later; when I answer a fake's
-- question, they reply.
local fakeReplies = {}
ns.Listen("SENT", function(msg, channel)
    if not fakes or channel ~= "GUILD" then return end
    if msg.t == "QQ" and not msg.x then
        local id = msg.id
        C_Timer.After(6, function()
            if fakes and byName["Shazza Kettle"] then ns.Safe(FakeSend, byName["Shazza Kettle"], { t = "QA", o = ns.me, id = id,
                pv = GetServerTime(), p = { { tx = "Not sure mate, but Bazza would know.", at = GetServerTime() } } }) end
        end)
        C_Timer.After(14, function()
            if fakes and byName["Bazza Stubbs"] then ns.Safe(FakeSend, byName["Bazza Stubbs"], { t = "QA", o = ns.me, id = id,
                pv = GetServerTime(), p = { { tx = "Easy, I'll show you. Whisper me when you're on.", at = GetServerTime(),
                lk = { { k = "d", id = "wc" } } } } }) end
        end)
    elseif msg.t == "QA" and msg.o ~= ns.me and byName[msg.o] then
        local key = msg.o .. ":" .. msg.id
        if fakeReplies[key] then return end
        fakeReplies[key] = true
        local owner, id = msg.o, msg.id
        C_Timer.After(8, function()
            local q = ns.Questions.Get(key)
            if not (fakes and byName[owner] and q) then return end
            local p = {}
            for _, old in ipairs(q.posts[owner] and q.posts[owner].p or {}) do p[#p + 1] = old end
            p[#p + 1] = { tx = "Cheers, that's exactly what I needed!", at = GetServerTime() }
            ns.Safe(FakeSend, byName[owner], { t = "QA", o = owner, id = id, pv = GetServerTime(), p = p })
        end)
    end
end)

-- Gathering: when I gather, five fake guildies ask for an invite; /ynm dev gather has Bazza (a fake
-- officer) gather for a "Guild meeting" a few minutes from now so I can try asking.
ns.Listen("SENT", function(msg, channel)
    if not fakes or msg.t ~= "GTH" or not msg.on or channel ~= "GUILD" then return end
    local who = { "Shazza Kettle", "Davo Thongs", "Kezza Galah", "Macca Ute", "Gazza Billabong" }
    for i, name in ipairs(who) do
        C_Timer.After(1 + i * 1.5, function()
            if fakes and byName[name] then ns.Safe(FakeSend, byName[name], { t = "GAK", o = msg.o, id = msg.id, at = msg.at }, "WHISPER") end
        end)
    end
end)

-- Clan meetings: when I start one, the clan's online fakes ask (one by whispering "inv"), and a fake
-- from another clan whispers "inv pls" too. /ynm dev clanmeet has my clan's fake leader start one.
ns.Listen("SENT", function(msg, channel)
    if not fakes or msg.t ~= "CMT" or not msg.on or channel ~= "GUILD" then return end
    local delay, whispered = 1, false
    for _, m in ipairs(fakes) do
        if m.online and m.addon and m.race == msg.r then
            delay = delay + 1.5
            local byWhisper = not whispered
            whispered = true
            C_Timer.After(delay, function()
                if not (fakes and byName[m.name]) then return end
                if byWhisper then ns.Safe(ns.ClanMeet.Whispered, "inv", m.name)
                else ns.Safe(FakeSend, m, { t = "CAK", r = msg.r }, "WHISPER") end
            end)
        end
    end
    for _, m in ipairs(fakes) do
        if m.online and m.addon and m.race and m.race ~= msg.r then
            C_Timer.After(delay + 2, function()
                if fakes and byName[m.name] then ns.Safe(ns.ClanMeet.Whispered, "inv pls", m.name) end
            end)
            break
        end
    end
end)

function Sim.FakeClanMeet()
    if not fakes then return end
    local race = ns.Clans.MyRace()
    for _, m in ipairs(fakes) do
        if m.simLeader and m.race == race and m.online then
            ns.Safe(FakeSend, m, { t = "CMT", r = race, on = true })
            ns.Print(string.format(L.SIM_CLANMEET, m.name))
            return
        end
    end
    ns.Print(L.SIM_CLANMEET_NONE)
end

-- Challenges: one online fake (not a leader) from my clan and from two other clans challenge for
-- the leadership; 20 s later Bazza (a fake officer) marks the first other-clan one Lost.
function Sim.FakeChallenges()
    if not fakes then return end
    local now = GetServerTime()
    local myRace = ns.Clans.MyRace()
    local picks, seen = {}, {}
    for _, m in ipairs(fakes) do
        if m.online and m.addon and m.race and not m.simLeader and m.race == myRace and not seen[m.race] then
            picks[#picks + 1] = m; seen[m.race] = true
        end
    end
    for _, m in ipairs(fakes) do
        if #picks >= 3 then break end
        if m.online and m.addon and m.race and not m.simLeader and not seen[m.race] then
            picks[#picks + 1] = m; seen[m.race] = true
        end
    end
    for i, m in ipairs(picks) do
        ns.Safe(FakeSend, m, { t = "CHG", id = now + i, r = m.race, st = "o", at = now - i * 3600, ev = now })
    end
    local loser
    for _, m in ipairs(picks) do if m.race ~= myRace then loser = m; break end end
    if loser then
        C_Timer.After(20, function()
            if not (fakes and byName["Bazza Stubbs"]) then return end
            local id
            for i, m in ipairs(picks) do if m == loser then id = now + i end end
            ns.Safe(FakeSend, byName["Bazza Stubbs"], { t = "CHG", o = loser.name, id = id, r = loser.race, st = "lost",
                sb = "Bazza Stubbs", at = now - 3600, ev = GetServerTime() })
        end)
    end
    ns.Print(L.SIM_CHALLENGES)
end

-- Disband in sim mode: a fake who "joined" my party leaves it.
function Sim.Leave(name)
    if not joined[name] then return end
    joined[name] = nil
    ns.Dungeons.Recount()
end

function Sim.FakeGather()
    if not fakes then return end
    local now = GetServerTime()
    local at = now + 300
    local id = now + 7
    ns.Safe(FakeSend, byName["Bazza Stubbs"], { t = "EVT", id = id, ti = "Guild meeting", at = at, k = "s",
        nt = 0, nh = 0, nd = 0, note = "Meet at the Orgrimmar bank. Ask for an invite to get on one layer.",
        im = 1, an = true, ev = now })                       -- important (Bazza's an officer): the pop-ups everyone gets
    ns.Safe(FakeSend, byName["Bazza Stubbs"], { t = "GTH", o = "Bazza Stubbs", id = id, at = at, on = true })
    ns.Print(L.SIM_GATHER)
end

function Sim.AskedForInvite(organiser)
    C_Timer.After(3, function()
        if fakes then ns.Print(string.format(L.SIM_WOULD_INVITE, organiser)) end
    end)
end

-- Fake board: Bazza (an officer) writes the Home message and the guild info; two fake streamers.
local function FakeBoard()
    if not fakes then return end
    local now = GetServerTime()
    ns.Safe(FakeSend, byName["Bazza Stubbs"], { t = "BRD", k = "info", ev = now,
        motd = "Levelling night is Wednesday 7pm. Grab the addon from Discord and say g'day!", dc = "discord.gg/fakeinvite",
        text = "Welcome to " .. (ns.Guild.name or "the guild") .. "!\n\nWe level together, run dungeons together and help each other out.\n\n"
            .. "Rules\n- Be nice.\n- Ask in guild chat before buying crafted gear: someone can probably make it.\n- Need rolls on gear you'll wear, greed the rest.\n\n"
            .. "Weekly\n- Wednesday 7pm: Levelling night.\n- Saturday 2pm: dungeon day.\n\nOfficers: Bazza, Shazza. Whisper us anytime." })
    ns.Safe(FakeSend, byName["Kezza Galah"], { t = "BRD", k = "strm", ev = now, tw = "kezza_galah", when = "Most nights 8pm",
        about = "Mage levelling, dungeons with the guild", live = true })
    ns.Safe(FakeSend, byName["Trev Drongo"], { t = "BRD", k = "strm", ev = now, tw = "trevdrongo", when = "Weekends",
        about = "Priest healing, chill vibes" })
end

-- Fake events: a dungeon run tonight, a weekly levelling night (kind "l", as older versions send it:
-- it shows as social), a party in five days; with answers.
local function LocalTime(daysAhead, hour, min)
    local t = date("*t")
    return time({ year = t.year, month = t.month, day = t.day + daysAhead, hour = hour, min = min, sec = 0 })
end

local function FakeEvents()
    if not fakes then return end
    local now = GetServerTime()
    local run = LocalTime(0, 20, 30)
    if run < now + 1800 then run = LocalTime(1, 20, 30) end
    local wd = tonumber(date("%w")) or 0                     -- 0 Sunday ... 6 Saturday
    local toWed = (3 - wd) % 7
    local events = {
        { "Bazza Stubbs", { t = "EVT", id = now, ti = "The Deadmines", at = run, k = "d", nt = 1, nh = 1, nd = 3,
            note = "Quick run after levelling night. Bring potions.", ev = now } },
        { "Macca Ute", { t = "EVT", id = now + 1, ti = "Levelling night", at = LocalTime(toWed, 19, 0), k = "l",
            nt = 0, nh = 0, nd = 0, note = "Everyone online groups up by level and quests together.", w = true, ev = now } },
        { "Kezza Galah", { t = "EVT", id = now + 2, ti = "Level 30 party", at = LocalTime(5, 20, 0), k = "s",
            nt = 0, nh = 0, nd = 0, note = "Meet at the Orgrimmar bank, drinks on Kezza.", ev = now } },
    }
    for _, ev in ipairs(events) do ns.Safe(FakeSend, byName[ev[1]], ev[2]) end
    local answers = {
        { "Shazza Kettle", 1, "y", "h" }, { "Davo Thongs", 1, "y", "d" }, { "Gazza Billabong", 1, "m" },
        { "Shazza Kettle", 2, "y" }, { "Bazza Stubbs", 2, "y" }, { "Tezza Brolly", 2, "y" }, { "Johnno Snag", 2, "n" },
        { "Trev Drongo", 3, "y" }, { "Davo Thongs", 3, "m" },
    }
    for _, a in ipairs(answers) do
        local ev = events[a[2]]
        ns.Safe(FakeSend, byName[a[1]], { t = "RSVP", o = ev[1], id = ev[2].id, at = ns.Calendar.NextAt(
            { at = ev[2].at, w = ev[2].w }, now), a = a[3], r = a[4], rv = now })
    end
end

-- Fake dungeon activity: two groups near my level and two guildies marked available.
local function FakeDungeons()
    if not fakes then return end
    local near = ns.Dungeons.ForLevel(UnitLevel("player") or 1)
    local now = GetServerTime()
    local shazza, macca = byName["Shazza Kettle"], byName["Macca Ute"]
    local davo, gazza = byName["Davo Thongs"], byName["Gazza Billabong"]
    ns.Safe(FakeSend, shazza, { t = "GRP", id = now, d = near[1].key, me = "h", nt = 1, nh = 1, nd = 3,
        ht = 0, hh = 1, hd = 1, note = "Quests too, bring your SM quests", u = now + 7200 })
    ns.Safe(FakeSend, macca, { t = "GRP", id = now + 1, d = near[2].key, me = "d", nt = 1, nh = 1, nd = 3,
        ht = 1, hh = 0, hd = 2, note = "", u = now + 5400 })
    ns.Safe(FakeSend, davo, { t = "AVL", r = "h", ds = { near[1].key, near[2].key, near[3].key }, u = now + 5100,
        note = "Up for anything tonight" })
    ns.Safe(FakeSend, gazza, { t = "AVL", r = "td", ds = { near[2].key }, u = now + 2400, note = "" })
end
function Sim.Profs()
    if not fakes then return {} end
    if not simProfs then
        simProfs = {}
        for line, people in pairs(SIM_PROFS) do
            for _, pr in ipairs(people) do
                simProfs[pr[1]] = simProfs[pr[1]] or {}
                simProfs[pr[1]][line] = { r = pr[2], m = 300, i = {} }
            end
        end
        for i, rec in ipairs(SIM_RECIPES) do
            for _, who in ipairs(rec[3]) do
                local d = simProfs[who] and simProfs[who][rec[2]]
                if d then d.i[#d.i + 1] = SIM_ID + i end
            end
        end
    end
    return simProfs
end


local ticker, walker = nil, nil

function Sim.IsOn() return fakes ~= nil end
-- Screenshot mode (/ynm dev shots on|off, needs sim): the roster views show only the fake guildies
-- (and me), so screenshots for the CurseForge page have no real guildmates' names. Only what's on
-- screen changes; the roster and saved data are untouched. Not saved: off after a /reload.
Sim.shots = false
function Sim.Hides(m) return Sim.shots and fakes ~= nil and not m.sim and m.name ~= ns.me end
function Sim.IsFake(name) return byName[name] ~= nil end

-- A fake message from a fake guildie, into the real receive path.
function FakeSend(m, msg, channel)
    msg.v = msg.v or ns.PROTOCOL
    ns.Comm.Receive(Ser:Serialize(msg), channel or "GUILD", m.name)
end

-- A fake guildie's status message fields.
local function StatusOf(m)
    local d = DOING[m.name] or {}
    return { l = m.level, z = m.zone, st = d[1] or "", n = d[2], ra = m.race, ro = m.roles }
end

-- Give a fake guildie a spot: near me if they're in my zone (so they show on the minimap),
-- otherwise somewhere in the middle of their zone.
local function Spot(m, myMap, myX, myY)
    if m.zone == ((GetRealZoneText and GetRealZoneText()) or GetZoneText()) and myMap then
        local a = math.random() * math.pi * 2
        local r = 0.005 + math.random() * 0.02
        m.pm, m.px, m.py = myMap, myX + math.cos(a) * r, myY + math.sin(a) * r
    elseif ZONE_MAP[m.zone] then
        m.pm, m.px, m.py = ZONE_MAP[m.zone], 0.3 + math.random() * 0.4, 0.3 + math.random() * 0.4
    else
        m.pm = nil
    end
end

local function Build()
    local me = UnitLevel("player") or 1
    local zone = (GetRealZoneText and GetRealZoneText()) or GetZoneText() or ""
    if zone == "" then zone = "Durotar" end
    local list = {}
    for i, p in ipairs(PEOPLE) do
        local name = p[1]
        local m = {
            name = name, rank = (i == 1) and "Officer" or "Member", rankIndex = (i == 1) and 1 or 3,
            level = math.max(1, math.min(60, me + p[2])), class = p[3],
            zone = (p[4] == "@zone") and zone or p[4], note = "", online = p[5], status = 0,
            sim = true, addon = p[6],
        }
        local c = p[6] and CLAN[name]
        if c then m.race, m.roles, m.simLeader = c[1], c[2], c[3] or nil end
        list[#list + 1] = m
        byName[name] = m
    end
    local myMap, myX, myY = ns.Map.MyPosition()
    for _, m in ipairs(list) do Spot(m, myMap, myX, myY) end
    return list
end

-- Every 5 s the online fakes with the addon wander a few yards; every 15 s each sends its position,
-- through the real receive path (so the dots, expiry and tooltips are the real code).
local walkTicks = 0
local function Walk()
    if not fakes then return end
    walkTicks = walkTicks + 1
    for i, m in ipairs(fakes) do
        if m.online and m.addon and m.pm then
            m.px = math.min(0.99, math.max(0.01, m.px + (math.random() - 0.5) * 0.004))
            m.py = math.min(0.99, math.max(0.01, m.py + (math.random() - 0.5) * 0.004))
            if (walkTicks + i) % 3 == 0 then
                ns.Safe(FakeSend, m, { t = "POS", m = m.pm, x = m.px, y = m.py })
            end
        end
    end
end

-- Every 30 s one fake guildie moves zone, and now and then one levels up.
local function Drift()
    if not fakes then return end
    local m = fakes[math.random(#fakes)]
    if m.online then
        m.zone = ZONES[math.random(#ZONES)]
        if math.random() < 0.3 and m.level < 60 then m.level = m.level + 1 end
        Spot(m, ns.Map.MyPosition())
        ns.Guild.SetFakes(fakes)
        if m.addon then
            local st = StatusOf(m)
            st.t = "ST"
            ns.Safe(FakeSend, m, st)
        end
    end
end

function Sim.Start(quiet)
    if fakes then return end
    fakes = Build()
    ns.db.dev.sim = true
    ns.Guild.SetFakes(fakes)
    -- The online ones with the addon say hi, a few seconds apart.
    local delay = 0
    for _, m in ipairs(fakes) do
        if m.online and m.addon then
            delay = delay + 0.7
            local ver = (m.name == "Sully Dunny") and "0.0.9" or ns.VERSION
            C_Timer.After(delay, function()
                if not fakes then return end
                local hi = StatusOf(m)
                hi.t, hi.ver, hi.ask = "HI", ver, true
                ns.Safe(FakeSend, m, hi)
            end)
        end
    end
    ns.Prof.MarkDirty()
    C_Timer.After(9, function() ns.Safe(FakeDungeons) end)
    PurgeFakeEvents()
    C_Timer.After(11, function() ns.Safe(FakeEvents) end)
    C_Timer.After(13, function() ns.Safe(FakeBoard) end)
    C_Timer.After(15, function() ns.Safe(FakeRequests) end)
    C_Timer.After(17, function() ns.Safe(FakeQuestions) end)
    C_Timer.After(60, function() ns.Safe(FakeNewQuestion) end)
    ticker = C_Timer.NewTicker(30, function() ns.Safe(Drift) end)
    walker = C_Timer.NewTicker(5, function() ns.Safe(Walk) end)
    if not quiet then ns.Print(string.format(L.SIM_ON, #fakes)) end
    ns.Log("(sim) " .. #fakes .. " fake guildies added")
end

function Sim.Stop()
    if not fakes then return end
    fakes = nil
    Sim.shots = false
    if ticker then ticker:Cancel(); ticker = nil end
    if walker then walker:Cancel(); walker = nil end
    for name in pairs(byName) do ns.Status.extra[name] = nil end
    PurgeFakeEvents()
    if ns.Questions then ns.Questions.PurgeFakes(function(name) return byName[name] ~= nil end) end
    if ns.Alts then ns.Alts.PurgeFakes(function(name) return byName[name] ~= nil end) end
    wipe(byName)
    ns.db.dev.sim = false
    ns.Guild.SetFakes(nil)
    ns.Comm.ForgetSims()
    simProfs = nil
    ns.Prof.MarkDirty()
    wipe(joined)
    ns.Dungeons.Recount()
    ns.Print(L.SIM_OFF)
    ns.Log("(sim) fake guildies removed")
end

-- When we say hi to the guild, the fake guildies with the addon whisper theirs back.
-- When I make an event, two fake guildies say they're going a few seconds later.
ns.Listen("SENT", function(msg, channel)
    if not fakes or msg.t ~= "EVT" or msg.x or channel ~= "GUILD" or not msg.at then return end
    local at = ns.Calendar.NextAt({ at = msg.at, w = msg.w }, GetServerTime())
    for i, who in ipairs({ { "Shazza Kettle", "h" }, { "Bazza Stubbs", "t" } }) do
        C_Timer.After(3 + i * 3, function()
            if fakes then
                ns.Safe(FakeSend, byName[who[1]], { t = "RSVP", o = ns.me, id = msg.id, at = at, a = "y",
                    r = (msg.nt or 0) + (msg.nh or 0) + (msg.nd or 0) > 0 and who[2] or nil, rv = GetServerTime() })
            end
        end)
    end
end)

-- When I post a group, two fake guildies sign up a few seconds later (by whisper, the real path).
ns.Listen("SENT", function(msg, channel)
    if not fakes or msg.t ~= "GRP" or msg.x or channel ~= "GUILD" then return end
    local g = ns.Dungeons.MyGroup()
    if not g or g.simAsked == g.id then return end
    g.simAsked = g.id
    C_Timer.After(4, function()
        if fakes then ns.Safe(FakeSend, byName["Bazza Stubbs"], { t = "SIGN", id = g.id, r = "t" }, "WHISPER") end
    end)
    C_Timer.After(8, function()
        if fakes then ns.Safe(FakeSend, byName["Tezza Brolly"], { t = "SIGN", id = g.id, r = "d" }, "WHISPER") end
    end)
end)

ns.Listen("SENT", function(msg, channel)
    if not fakes or msg.t ~= "HI" or msg.ask ~= true or channel ~= "GUILD" then return end
    local delay = 1
    for _, m in ipairs(fakes) do
        if m.online and m.addon then
            delay = delay + 0.5
            C_Timer.After(delay, function()
                if not fakes then return end
                local hi = StatusOf(m)
                hi.t, hi.ver = "HI", ns.VERSION
                ns.Safe(FakeSend, m, hi, "WHISPER")
            end)
        end
    end
end)

-- Dev only: the CurseForge build leaves this out (BigWigs packager's do-not-package markers).
-- A copy installed from source keeps it.
--@do-not-package@
ns.Listen("LOGIN", function()
    if ns.db.dev.sim then
        C_Timer.After(3, function() ns.Safe(Sim.Start, true) end)
    end
end)

ns.devCommands.sim = function(arg)
    if arg == "on" then Sim.Start()
    elseif arg == "off" then Sim.Stop()
    else ns.Print("/ynm dev sim on  or  /ynm dev sim off") end
end
ns.devCommands.shots = function(arg)
    if arg ~= "on" and arg ~= "off" then ns.Print("/ynm dev shots on  or  /ynm dev shots off") return end
    if arg == "on" and not Sim.IsOn() then ns.Print("/ynm dev sim on first") return end
    Sim.shots = (arg == "on")
    ns.Print(Sim.shots and "Screenshot mode on: only fake guildies are shown." or "Screenshot mode off.")
    ns.Fire("ROSTER")
end
--@end-do-not-package@
