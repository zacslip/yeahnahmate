-- The "How it works" cards: a button on the Clan roll panel (My Clan) and on the All clans roll panel
-- opens a card over the panel; Close (or the button again) shuts it. Everything on a card stays
-- inside the panel, and the pictures on it are look-alikes that can't be clicked.
math.randomseed(5)
YeahNahMateDB = nil
FAKE.myRank = 0
local ns = LoadAddon("YeahNahMate", "YeahNahMate")
LOGGED_IN = true
FireEvent("PLAYER_LOGIN")
local L, UI = ns.L, ns.UI
ns.settings.sharePosition, ns.settings.shareProfessions = false, false
function UnitRace() return "Orc", "Orc", 2 end
Tick(15)

ns.settings.clanView = "mine"
UI.Open("clans")
Tick(1)
local cp
for _, o in ipairs(CREATED) do if o.cols and o.roleBtns then cp = o end end
local W, H = ns.ClanRollUI.W, ns.ClanRollUI.H

-- Every frame, text and texture made after `from` that sits on `card` (any depth) stays inside W x H.
local function Inside(card, from, name)
    local bad, seen = 0, 0
    local function Root(o)
        local x, y, n = 0, 0, 0
        while o and o ~= card and n < 10 do
            local pt = o._pt
            if not pt or type(pt[2]) ~= "number" or pt[1] ~= "TOPLEFT" then return nil end
            x, y = x + pt[2], y + pt[3]
            o = o._parent
            n = n + 1
        end
        if o ~= card then return nil end
        return x, y
    end
    for i = from, #CREATED do
        local o = CREATED[i]
        local x, y = Root(o)
        if x and o._w then
            seen = seen + 1
            local right, bottom = x + o._w, -y + (o._h or 0)
            if x < 0 or right > W + 0.5 or y > 0 or bottom > H + 0.5 then
                bad = bad + 1
                print("  outside: " .. tostring(o.GetText and o:GetText() or o._tex or "?") .. " x=" .. x .. " y=" .. y .. " w=" .. o._w)
            end
        end
    end
    check(seen >= 20 and bad == 0, name .. ": everything on the card is inside the panel (" .. seen .. " checked)")
end

local p = cp.roll
check(p.howBtn and p.howBtn:IsShown() and p.howBtn:GetText() == L.CLANROLL_HOW, "My Clan: a How it works button")
check(p.how == nil, "the card is built on the first click")
local from = #CREATED + 1
p.howBtn:Click(); Tick(1)
check(p.how and p.how:IsShown() and p.how.title:GetText():find(L.CLANROLL_HOW_TITLE, 1, true), "the leader's card opens")
check(#p.how.steps == 5 and p.how.steps[3].head:GetText():find(L.CLANROLL_HOW_3, 1, true), "five steps, step 3 Start roll")
check(p.how.start:GetText() == L.CLANROLL_START_BTN and p.how.announce:GetText() == L.CLANROLL_ANNOUNCE
    and p.how.reroll:GetText() == L.CLANROLL_REROLL, "pictures of Start roll, Announce and Reroll ties")
check(p.how:GetFrameLevel() > p:GetFrameLevel(), "the card sits over the panel")
Inside(p.how, from, "leader card")
p.how.close:Click(); Tick(1)
check(not p.how:IsShown(), "Close shuts it")
p.howBtn:Click(); Tick(1)
check(p.how:IsShown(), "the button opens it again")
p.howBtn:Click(); Tick(1)
check(not p.how:IsShown(), "and the button again shuts it")
check(ns.ClanRoll.cur == nil, "nothing on the card started a roll")

-- The all-clans card, on the guild master's All clans roll view.
ns.ClanRollUI.OpenAll(); Tick(1)
local ap = cp.allPanel
check(ap.howBtn and ap.howBtn:GetText() == L.CLANROLL_HOW, "All clans roll: a How it works button")
from = #CREATED + 1
ap.howBtn:Click(); Tick(1)
check(ap.how and ap.how:IsShown() and ap.how.title:GetText():find(L.CLANROLL_HOW_ALL_TITLE, 1, true), "the all-clans card opens")
check(#ap.how.clans == 4, "four clan leaders' addons in the diagram")
check(ap.how.step2:GetText() == L.CLANROLL_HOW_ALL_2, "step 2 says what each leader's addon does")
Inside(ap.how, from, "all-clans card")
ap.how.close:Click(); Tick(1)
check(not ap.how:IsShown(), "Close shuts the all-clans card")
check(ns.ClanRoll.all == nil or not ns.ClanRoll.all.open, "nothing on the card started an all-clans roll")
