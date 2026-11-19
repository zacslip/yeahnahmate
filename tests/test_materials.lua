-- Materials on the Professions tab: a recipe row's tooltip lists what it needs and how many I carry
-- (green when enough); asked once per recipe; names still loading fill in when the game sends them;
-- a recipe the game has nothing for, or a secret answer, shows no materials and no error.
YeahNahMateDB = nil
local ns = LoadAddon("YeahNahMate", "YeahNahMate")
LOGGED_IN = true
FireEvent("PLAYER_LOGIN")
local P, L = ns.Prof, ns.L
Tick(20)

-- The game: Linen Bag (3755) needs 3 Linen Cloth (2589) and 3 Coarse Thread (2320); I carry 5 cloth, 1 thread.
local asked = 0
C_TradeSkillUI.GetRecipeSchematic = function(id)
    asked = asked + 1
    if id == 3755 then
        return { outputItemID = 4238, reagentSlotSchematics = {
            { quantityRequired = 3, required = true, reagents = { { itemID = 2589 } } },
            { quantityRequired = 3, required = true, reagents = { { itemID = 2320 } } },
            { quantityRequired = 1, required = false, reagents = { { itemID = 9999 } } },     -- optional: not shown
        } }
    end
    return { reagentSlotSchematics = {} }
end
local names = { [2589] = "Linen Cloth" }           -- Coarse Thread not loaded yet
local requested = {}
C_Item.GetItemNameByID = function(id) return names[id] end
C_Item.RequestLoadItemDataByID = function(id) requested[id] = true end
C_Item.GetItemCount = function(id) return ({ [2589] = 5, [2320] = 1 })[id] or 0 end

local mats = P.Materials(3755)
check(mats and #mats == 2 and mats[1].id == 2589 and mats[1].n == 3 and mats[2].id == 2320, "Linen Bag: 3 Linen Cloth, 3 Coarse Thread (optional left out)")
P.Materials(3755)
check(asked == 1, "asked the game once per recipe")
check(P.Materials(3757) == nil and P.Materials(3757) == nil and asked == 2, "a recipe with no materials: none, asked once")
check(P.ItemName(2320) == nil and requested[2320], "a name not loaded yet: the game is asked for it")
check(P.Carried(2589) == 5, "how many I carry")
local realSecret = issecretvalue
issecretvalue = function(v) return v == 77 end
C_TradeSkillUI.GetRecipeSchematic = function() return { reagentSlotSchematics = { { quantityRequired = 77, reagents = { { itemID = 1 } } } } } end
check(P.Materials(4000) == nil, "a secret count: nothing shown")
issecretvalue = realSecret

-- The tooltip on the tab. Record what the tooltip is given.
local lines = {}
local owner
GameTooltip.SetOwner = function(self, o) owner = o; lines = {} end
GameTooltip.GetOwner = function() return owner end
GameTooltip.AddLine = function(self, t) lines[#lines + 1] = t end
GameTooltip.AddDoubleLine = function(self, a, b, r1, g1, b1, r2, g2) lines[#lines + 1] = a .. " || " .. b .. ((g2 == 1) and " [green]" or "") end
GameTooltip.IsShown = function() return true end
FAKE.trade = { line = 197, rank = 75, max = 150, recipes = { [3755] = true } }
ns.settings.shareProfessions = true
FireEvent("TRADE_SKILL_SHOW"); Tick(2)
SlashCmdList.YEAHNAHMATE("")
ns.UI.Select("professions"); Tick(1)
local row
for _, o in ipairs(CREATED) do if o.rid == 3755 and not o.cat and o:IsShown() then row = o end end
if not row then
    -- Sections start closed: open them all.
    for _, o in ipairs(CREATED) do if o.cat and o:IsShown() and not o.isOpen then o._scripts.OnClick(o) end end
    Tick(1)
    for _, o in ipairs(CREATED) do if o.rid == 3755 and not o.cat and o:IsShown() then row = o end end
end
check(row ~= nil, "the Linen Bag row")
row._scripts.OnEnter(row)
local all = table.concat(lines, "\n")
check(all:find(L.PROF_MATS, 1, true), "the tooltip has a Materials heading")
check(all:find("Linen Cloth x3 || " .. string.format(L.PROF_MATS_HAVE, 5) .. " [green]", 1, true), "Linen Cloth x3, you have 5, green", all)
check(all:find(L.PROF_MATS_LOADING .. " x3 || " .. string.format(L.PROF_MATS_HAVE, 1), 1, true)
    and not all:find(L.PROF_MATS_HAVE:format(1) .. " [green]", 1, true), "thread: loading, you have 1, not green")
-- The thread's name arrives: the tooltip is drawn again with it.
names[2320] = "Coarse Thread"
FireEvent("ITEM_DATA_LOAD_RESULT", 2320, true)
Tick(0.1)
all = table.concat(lines, "\n")
check(all:find("Coarse Thread x3", 1, true), "the name fills in when it loads")
row._scripts.OnLeave(row)
lines = {}
FireEvent("ITEM_DATA_LOAD_RESULT", 2320, true)
Tick(0.1)
check(#lines == 0, "after leaving the row nothing is redrawn")

-- The crash (20 Nov): another addon's item-tooltip hook loads item data from inside SetItemByID, so the
-- game says "an item loaded" while we draw. That must never start a loop: at most one more draw per
-- material shown as loading, and other items' loads don't redraw at all.
names[2320] = nil
local draws = 0
GameTooltip.SetItemByID = function()
    draws = draws + 1
    if draws > 50 then error("tooltip loop") end
    FireEvent("ITEM_DATA_LOAD_RESULT", 4238, true)          -- the made item (not a material)
    FireEvent("ITEM_DATA_LOAD_RESULT", 2320, true)          -- the thread, still not loaded
end
row._scripts.OnEnter(row)
for _ = 1, 20 do Tick(0.1) end
check(draws <= 2, "another addon loading items inside our tooltip: no loop (" .. draws .. " draws)")
row._scripts.OnLeave(row)

-- First hover, the made item not loaded: when it arrives the game rebuilds the tooltip (our lines go);
-- we draw once more, next frame, so the materials come back without hovering again.
names[2320] = "Coarse Thread"
local cached = false
C_Item.IsItemDataCachedByID = function(id) if id == 4238 then return cached end return true end
GameTooltip.SetItemByID = function() end
row._scripts.OnEnter(row)
check(table.concat(lines, "\n"):find(L.PROF_MATS, 1, true), "first draw has the materials")
cached = true
lines = {}                                                 -- the game's rebuild wipes our lines
FireEvent("ITEM_DATA_LOAD_RESULT", 4238, true)
Tick(0.1)
check(table.concat(lines, "\n"):find("Coarse Thread x3", 1, true), "made item loaded: drawn again with the materials")
row._scripts.OnLeave(row)

-- A made item that never loads, with the game firing loads all the time: still at most one redraw.
cached = false
draws = 0
GameTooltip.SetItemByID = function()
    draws = draws + 1
    if draws > 50 then error("tooltip loop") end
    FireEvent("ITEM_DATA_LOAD_RESULT", 4238, true)
end
row._scripts.OnEnter(row)
for _ = 1, 20 do Tick(0.1) end
check(draws <= 2, "the made item's load redraws once at most (" .. draws .. " draws)")
row._scripts.OnLeave(row)
C_Item.IsItemDataCachedByID = nil
GameTooltip.SetItemByID = function() end

-- The game had no materials the first time: tried once more half a second later.
local ready = false
C_TradeSkillUI.GetRecipeSchematic = function(id)
    if not ready then return nil end
    return { reagentSlotSchematics = { { quantityRequired = 2, reagents = { { itemID = 2589 } } } } }
end
P.Materials(3756)                                          -- nothing yet, not remembered
row.rid = 3756
row._scripts.OnEnter(row)
check(not table.concat(lines, "\n"):find(L.PROF_MATS, 1, true), "no materials yet")
ready = true
Tick(0.6)
check(table.concat(lines, "\n"):find("Linen Cloth x2", 1, true), "tried again: the materials show")
row._scripts.OnLeave(row)
row.rid = 3755

check(#ns.db.errors == 0, "no errors " .. tostring(ns.db.errors[1] and ns.db.errors[1].msg))
