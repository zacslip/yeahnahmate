-- Meeting places: a few words and a spot (map + x, y), from where I stand or picked on the world map;
-- kept through older versions' copies (missing = keep), cleared on purpose (pm = 0, pl = ""), junk
-- dropped; the card line, the hover text, and pinning it on the map.
math.randomseed(43)
YeahNahMateDB = nil
-- Map info with a real parent chain (zone -> continent -> world), so HereBeDragons' walks up end.
C_Map.GetMapInfo = function(id)
    local t = (id == 947 and 1) or ((id == 1414 or id == 1415) and 2) or 3
    local parent = (t == 3 and 1414) or (t == 2 and 947) or nil
    return { mapID = id, name = "Map " .. id, mapType = t, parentMapID = parent }
end
local ns = LoadAddon("YeahNahMate", "YeahNahMate")
LOGGED_IN = true
FireEvent("PLAYER_LOGIN")
local Ser = LibStub("AceSerializer-3.0")
local function Msg(t) return Ser:Serialize(t) end
local function Sent(t, from)
    local list = {}
    for i = (from or 1), #SENT do
        local ok, m = Ser:Deserialize(SENT[i].text)
        if ok and type(m) == "table" and m.t == t then list[#list + 1] = m end
    end
    return list
end
local C = ns.Calendar
ns.settings.sharePosition, ns.settings.shareProfessions = false, false
INJECT("YNM", Msg({ v = 1, t = "HI", ver = "0.17.2" }), "GUILD", "Bingo Heeler")
Tick(45)
local now = GetServerTime()
local store = C.Store()

-- Saving with a place: kept and sent.
local before = #SENT
local k = C.Save(nil, { title = "Meet", at = now + 7200, k = "s", pl = "Org bank|cff", pm = 1454, px = 512, py = 634 })
local e = store[k]
check(e.pl == "Org bankcff" and e.pm == 1454 and e.px == 512 and e.py == 634, "place kept (colour codes cut)")
local pl, pm, x, y = C.Place(e)
check(pl == "Org bankcff" and pm == 1454 and math.abs(x - 0.512) < 1e-9 and math.abs(y - 0.634) < 1e-9, "Place gives the spot as 0-1")
local evt = Sent("EVT", before + 1)
check(#evt == 1 and evt[1].pl == "Org bankcff" and evt[1].pm == 1454 and evt[1].px == 512, "sent with the event")
check(C.Save(k, { title = "Meet", at = now + 7200, k = "s", pl = string.rep("p", 50), pm = 1454, px = 2000, py = 5 }) == k,
    "saving with a bad spot still saves")
check(#store[k].pl == 30 and store[k].pm == nil, "the text is cut to 30, a spot off the map is dropped")
C.Save(k, { title = "Meet", at = now + 7200, k = "s", pl = "", pm = 0 })
check(store[k].pl == nil and store[k].pm == nil and C.Place(store[k]) == nil, "cleared")
before = #SENT
C.Save(k, { title = "Meet", at = now + 7200, k = "s", pl = "", pm = 0 })
evt = Sent("EVT", before + 1)
check(evt[1].pl == "" and evt[1].pm == 0, "no place goes out as \"\" / 0 (so copies can't bring an old one back)")

-- Someone's event with a place; junk spots are dropped, the event kept.
INJECT("YNM", Msg({ v = 1, t = "EVT", id = 1, ti = "Party", at = now + 86400, k = "s", pl = "Crossroads", pm = 1413, px = 515, py = 302, ev = now }), "GUILD", "Bluey Heeler")
INJECT("YNM", Msg({ v = 1, t = "EVT", id = 2, ti = "Junk", at = now + 86400, k = "s", pl = "x", pm = "1413", px = -5, py = 1.5, ev = now }), "GUILD", "Bluey Heeler")
Tick(1)
local bk = "Bluey Heeler:1"
check(store[bk].pl == "Crossroads" and store[bk].pm == 1413, "a guildie's place arrives")
check(store["Bluey Heeler:2"] and store["Bluey Heeler:2"].pm == nil and store["Bluey Heeler:2"].pl == "x", "a junk spot is dropped, the rest kept")

-- An older version's newer copy (no place fields) keeps the place; Bluey clearing it clears it.
INJECT("YNM", Msg({ v = 1, t = "EVT", o = "Bluey Heeler", id = 1, ti = "Party!", at = now + 86400, k = "s", ev = now + 5 }), "WHISPER", "Bingo Heeler")
Tick(1)
check(store[bk].title == "Party!" and store[bk].pl == "Crossroads" and store[bk].pm == 1413, "an older version's copy keeps the place")
INJECT("YNM", Msg({ v = 1, t = "EVT", id = 1, ti = "Party!", at = now + 86400, k = "s", pl = "", pm = 0, ev = now + 10 }), "GUILD", "Bluey Heeler")
Tick(1)
check(store[bk].pl == nil and store[bk].pm == nil, "the owner clearing it clears it")
INJECT("YNM", Msg({ v = 1, t = "EVT", id = 1, ti = "Party!", at = now + 86400, k = "s", pl = "Crossroads", pm = 1413, px = 515, py = 302, ev = now + 15 }), "GUILD", "Bluey Heeler")
Tick(1)

-- The words: "text (zone)", the zone alone, or the text alone.
local UI = ns.UI
check(UI.PlaceText(store[bk]) == "Crossroads (Map 1413)", "place text names the zone")
check(UI.PlaceText({ pm = 1413, px = 1, py = 1 }) == "Map 1413" and UI.PlaceText({ pl = "Org bank" }) == "Org bank"
    and UI.PlaceText({}) == nil, "zone alone, text alone, nothing")

-- The form: Here fills the spot (and the text, when it's empty); Save sends it; x clears.
ns.UI.Open("calendar")
local cal
for _, o in ipairs(CREATED) do if o.form and o.dayPager then cal = o end end
local f = cal.form
cal.mode, cal.editKey, cal.formLoaded = "new", nil, false
ns.UI.Select("calendar")
Tick(1)
check(f.spot == nil and f.place:GetText() == "", "a new event has no place")
FAKE.x, FAKE.y = 0.25, 0.75
f.here:Click()
Tick(1)
check(f.spot and f.spot[1] == 1413 and f.spot[2] == 250 and f.spot[3] == 750 and f.place:GetText() == "Map 1413", "Here: my spot, named after the map")
f.title:SetText("Here we go")
before = #SENT
f.save:Click()
Tick(1)
evt = Sent("EVT", before + 1)
check(#evt == 1 and evt[1].pm == 1413 and evt[1].px == 250 and evt[1].pl == "Map 1413", "saved with the place")
FAKE.instance = true
cal.mode, cal.editKey, cal.formLoaded = "new", nil, false
UI.Dirty()
Tick(1)
f.here:Click()
check(f.spot == nil, "Here inside a dungeon: no spot")
FAKE.instance = nil

-- Picking on the map: our layer only over a zone map; a left click sets the spot and stops picking.
local W = WorldMapFrame
local sc = CreateFrame("Frame")
sc.GetNormalizedCursorPosition = function() return 0.4, 0.6 end
W.ScrollContainer = sc
local shownMap = 1415
W.GetMapID = function() return shownMap end
f.place:SetText("")
f.spot = nil
f.pick:Click()
check(UI.MapPick.Active(), "Map: picking")
W:Show()
Tick(1)
local layer
for _, o in ipairs(CREATED) do if o._scripts and o._scripts.OnMouseUp and o:GetFrameStrata() == "FULLSCREEN_DIALOG" then layer = o end end
check(layer and not layer:IsShown(), "on a continent map our layer isn't there (left-click goes into a zone)")
shownMap = 1454
Tick(1)
check(layer:IsShown(), "on a zone map it is")
layer._scripts.OnMouseUp(layer, "RightButton")
check(UI.MapPick.Active(), "right-click doesn't pick")
layer._scripts.OnMouseUp(layer, "LeftButton")
Tick(1)
check(not UI.MapPick.Active() and f.spot and f.spot[1] == 1454 and f.spot[2] == 400 and f.spot[3] == 600, "left-click: the spot, picking stops")
check(f.place:GetText() == "Map 1454" and not layer:IsShown(), "named after the map; the layer's gone")
f.pick:Click()
Tick(200)
check(not UI.MapPick.Active(), "picking stops by itself after 3 minutes")
f.unspot:Click()
check(f.spot == nil and f.place:GetText() == "", "x clears it")
f.cancel:Click()

-- The card: Meet at line, Pin / Unpin.
local t = date("*t", store[bk].at)
cal.offset = (t.year - date("*t").year) * 12 + t.month - date("*t").month
cal.sel, cal.mode = t.day, nil
UI.Dirty()
Tick(1)
local card
for _, b in ipairs(cal.details) do if b.key == bk then card = b end end
check(card and card.place:GetText():find("Crossroads", 1, true) and card.pin:IsShown(), "the card says where, with Pin")
card.pin:Click()
Tick(1)
check(UI.MapPick.PinnedKey() == bk and card.pin:GetText() == ns.L.UNPIN, "pinned")
card.pin:Click()
Tick(1)
check(UI.MapPick.PinnedKey() == nil, "unpinned")

check(#ERRORS == 0, "no errors (" .. (ERRORS[1] or "none") .. ")")
