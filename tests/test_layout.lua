-- The tab layout (every tab follows the Ask tab's): Professions and Dungeons
-- in Ask's sidebar layout. The main action at the top of the sidebar, the views as rows, a box under
-- them; forms open over the content on the right.
math.randomseed(13)
YeahNahMateDB = nil
local ns = LoadAddon("YeahNahMate", "YeahNahMate")
LOGGED_IN = true
FireEvent("PLAYER_LOGIN")
ns.settings.sharePosition, ns.settings.shareProfessions = false, false
Tick(15)
SlashCmdList.YEAHNAHMATE("dev sim on")
Tick(16)
local UI, L = ns.UI, ns.L

-- Everything on a page sits inside the content area (736 wide): the sidebar 0-168, the right 184-736.
local function Inside(page, what)
    local bad = {}
    for _, o in ipairs(CREATED) do
        local parent, depth = o._parent, 0
        while parent and parent ~= page and depth < 6 do parent, depth = parent._parent, depth + 1 end
        if parent == page and o._pt and o._w and type(o._pt[2]) == "number" and o._pt[1] == "TOPLEFT" then
            -- x relative to the page: add up the TOPLEFT offsets of the frames in between.
            local x, f = o._pt[2], o._parent
            while f and f ~= page do
                x = x + ((f._pt and f._pt[1] == "TOPLEFT" and type(f._pt[2]) == "number") and f._pt[2] or 0)
                f = f._parent
            end
            if x + o._w > 737 then bad[#bad + 1] = (o._text or o._kind) .. " at " .. x .. "+" .. o._w end
        end
    end
    check(#bad == 0, what .. ": nothing past the right edge " .. table.concat(bad, "; "))
end

-- Professions: New request, the views (Recipes, Requests, History), the Crafty Bugger box.
UI.Open("professions")
Tick(1)
local pp
for _, o in ipairs(CREATED) do if o.histView and o.reqView and o.profMenu then pp = o end end
check(pp.newBtn:GetText() == L.NEW_REQUEST and #pp.viewCards == 3 and pp.viewCards[1].bar:IsShown() and not pp.viewCards[2].bar:IsShown(),
    "Professions: New request, three view cards, Recipes picked")
check(pp.viewCards[1].text:GetText() == L.PROF_ALL and pp.viewCards[1].pts:GetText():find("recipes", 1, true), "the Recipes card: all professions, how many recipes")
check(pp.viewCards[3].text:GetText():find("finished", 1, true), "the History card: how many finished")
check(pp.viewTitle:GetText() == L.WHO_MAKES_TAB and pp.whoView:IsShown(), "the Recipes view, titled")
check(pp.bugger == nil, "no Crafty Bugger box here (it's on Legends)")
-- The profession menu (was the list down the left).
check(not pp.profMenu:IsShown() and pp.profBtn:GetText():find(L.PROF_ALL, 1, true), "the profession button says all professions")
pp.profBtn:Click()
check(pp.profMenu:IsShown(), "it opens the menu")
local row = pp.lineRows[2]
check(row:IsShown() and row.line ~= nil, "the guild's professions are in it")
row:Click()
Tick(1)
check(pp.line == row.line and not pp.profMenu:IsShown() and pp.profBtn:GetText():find(ns.Prof.LineName(row.line), 1, true),
    "picking one filters and shuts the menu")
pp.profBtn:Click()
pp.lineRows[1]:Click()
Tick(1)
check(pp.line == nil, "All professions again")
-- New request opens the form on the Requests view.
pp.newBtn:Click()
Tick(1)
check(pp.view == 2 and pp.form ~= nil and pp.formFrame:IsShown() and pp.viewCards[2].bar:IsShown(), "New request: the form, on Requests")
pp.viewCards[3]:Click()
Tick(1)
check(pp.view == 3 and pp.form == nil and pp.histView:IsShown() and not pp.reqView:IsShown(), "History; the form is gone")
pp.viewCards[2]:Click()
Tick(1)
-- Ask on a recipe (let people pick who): with several crafters online, a list to pick from,
-- highest skill first; one click opens the whisper box for that one, nothing sent by itself.
pp.pickView(1)
pp.search:SetText("")
UI.Dirty(); Tick(1)
local two
for _, o in ipairs(pp.rows) do
    if o:IsShown() and not o.cat and o.askList and #o.askList >= 2 then two = o break end
end
if not two then
    for _, o in ipairs(pp.rows) do if o:IsShown() and o.cat and not o.isOpen then o:Click(); break end end
    UI.Dirty(); Tick(1)
    for _, o in ipairs(pp.rows) do if o:IsShown() and not o.cat and o.askList and #o.askList >= 2 then two = o break end end
end
check(two ~= nil, "a recipe with several crafters online (sim)")
if two then
    check(two.ask:GetText() == "Ask (" .. #two.askList .. ")", "the button says how many are online")
    local whispers = #WHISPERS
    two.ask:Click()
    check(pp.askMenu:IsShown() and pp.askMenu.rows[2]:IsShown(), "Ask opens the list of who's online")
    check(two.askList[1].skill >= two.askList[2].skill, "highest skill first")
    local pick = pp.askMenu.rows[2]
    pick:Click()
    local wbox = _G.YeahNahMateWhisper
    check(not pp.askMenu:IsShown() and wbox and wbox:IsShown()
        and wbox.edit:GetText():find("Hey " .. pick.who:match("^%S+"), 1, true), "clicking one opens the whisper box for them")
    check(#WHISPERS == whispers, "nothing sent by itself")
    if wbox then wbox:Hide() end
    two.ask:Click()
    pp.pickView(2)
    check(not pp.askMenu:IsShown(), "changing view shuts the list")
end
-- The request alert card (opt in): off, a click turns it on (the Settings switch too), again off.
check(ns.settings.pop.request == false and pp.reqAlert.text:GetText():find("Off", 1, true) and not pp.reqAlert.green:IsShown(), "the request alert card starts off (not green)")
pp.reqAlert:Click()
UI.Dirty(); Tick(1)
check(ns.settings.pop.request == true and pp.reqAlert.text:GetText():find("On", 1, true) and pp.reqAlert.green:IsShown(), "clicking it turns request alerts on (green)")
pp.reqAlert:Click()
UI.Dirty(); Tick(1)
check(ns.settings.pop.request == false, "and off again")
Inside(pp, "Professions")

-- Dungeons: Post a group, the views (Open groups, Available guildies), my status box.
UI.Open("dungeons")
Tick(1)
local dp
for _, o in ipairs(CREATED) do if o.postForm and o.availForm then dp = o end end
-- Four cards: me available, my group | a line | open groups, available guildies.
check(dp.side == nil and dp.groupsView:IsShown() and dp.mode == nil and dp.groupsCard.bar:IsShown() and not dp.availCard.bar:IsShown(),
    "Dungeons: no Post button; the groups showing, their card lit")
check(dp.groupsCard.text:GetText():find("open", 1, true) and dp.groupsCard.pts:GetText():find("your level", 1, true), "Open groups: how many, how many at my level (sim)")
check(dp.availCard.pts:GetText():find("INV_Shield_06", 1, true), "Available guildies: the roles between them")
check(dp.status.text:GetText():find(L.DUNGEON_STATUS_NOT, 1, true), "my status: not available")
check(not dp.status.green:IsShown() and not dp.groupCard.green:IsShown(), "neither of my cards is green")
check(dp.groupCard.text:GetText():find(L.DUNGEON_NO_GROUP, 1, true), "my group: none posted")
dp.status:Click()
Tick(1)
check(dp.mode == "avail" and dp.availForm:IsShown() and not dp.groupsView:IsShown() and dp.status.bar:IsShown() and not dp.groupsCard.bar:IsShown(),
    "clicking my status opens Make me available over the list")
local af = dp.availForm
check(not af.dungeonLine.ok and not af.roleLine.ok and not af.go:IsEnabled(), "available form: both lines red, button off")
for n = 1, 3 do af.picked[ns.Dungeons.LIST[n][1]] = true end
af.roleChecks.t:SetChecked(true); af.roleChecks.t:Click()
Tick(1)
check(af.dungeonLine.ok and af.dungeonLine.text:GetText():find("+1 more", 1, true) and af.roleLine.ok
    and af.roleLine.text:GetText():find(L.ROLE_TANK, 1, true) and af.go:IsEnabled(), "dungeons and a role picked: both green, button on")
wipe(af.picked); af.roleChecks.t:SetChecked(false); af.roleChecks.t:Click()
Tick(1)
dp.availCard:Click()
Tick(1)
check(dp.mode == nil and dp.availView:IsShown() and not dp.availForm:IsShown() and dp.availCard.bar:IsShown(), "the guildies card shows the list")
dp.groupCard:Click()
Tick(1)
check(dp.mode == "post" and dp.postForm:IsShown() and dp.groupCard.bar:IsShown(), "my group card opens Post a group")
local f = dp.postForm
-- the picker lists dungeons lowest level first (not sorted by closeness to me),
-- opened at the first one for my level.
do
    local shown, inOrder, prevMin = {}, true, -1
    for i = 1, #f.rows do
        local key = f.rows[i].key
        local d = key and ns.Dungeons.BY_KEY[key]
        if d then
            shown[#shown + 1] = d
            if d.min < prevMin then inOrder = false end
            prevMin = d.min
        end
    end
    local _, first = ns.Dungeons.ByLevel(UnitLevel("player"))
    check(#shown > 0 and inOrder, "dungeon picker rows go up in level")
    check(first and shown[1].key == ns.Dungeons.LIST[math.min(first, #ns.Dungeons.LIST - #f.rows + 1)][1],
        "the picker opens at my level (" .. tostring(shown[1] and shown[1].name) .. ")")
end
-- both lines start red and Post is off until a dungeon and my role are picked.
check(f.me == nil and not f.dungeonLine.ok and not f.roleLine.ok and not f.post:IsEnabled()
    and f.dungeonLine.text:GetText() == L.READY_NO_DUNGEON, "post form: both lines red, Post off")
f.picked[ns.Dungeons.LIST[1][1]] = true
UI.Dirty(); Tick(1)
check(f.dungeonLine.ok and f.dungeonLine.text:GetText():find(ns.Dungeons.Name(ns.Dungeons.LIST[1][1]), 1, true)
    and not f.roleLine.ok and not f.post:IsEnabled(), "dungeon picked: its line goes green, Post still off")
f.pickMe(2)
Tick(1)
check(f.roleLine.ok and f.roleLine.text:GetText():find(L.ROLE_HEALER, 1, true) and f.post:IsEnabled(), "role picked too: both green, Post on")
f.post:Click()
Tick(1)
check(ns.Dungeons.MyGroup() ~= nil and dp.mode == "group" and dp.myGroup:IsShown(), "posting shows Your group")
check(dp.groupCard.text:GetText():find(ns.Dungeons.Name(ns.Dungeons.MyGroup().d), 1, true) and dp.groupCard.pts:GetText():find("waiting", 1, true) and dp.groupCard.green:IsShown(),
    "the card names the dungeon and who's waiting")
dp.groupsCard:Click()
Tick(1)
check(dp.mode == nil and dp.groupsView:IsShown(), "back to the groups while leading")
dp.groupCard:Click()
Tick(1)
check(dp.mode == "group" and dp.myGroup:IsShown(), "my group card opens it again")
Inside(dp, "Dungeons")
dp.myGroup.close:Click()
Tick(1)
check(ns.Dungeons.MyGroup() == nil and dp.mode == nil and dp.groupCard.text:GetText():find(L.DUNGEON_NO_GROUP, 1, true) and not dp.groupCard.green:IsShown(), "closing the group: back to the list")

-- Legends and Ask fit too.
UI.Open("legends")
Tick(1)
local lp
for _, o in ipairs(CREATED) do if o.titles and o.titleCards then lp = o end end
check(lp:IsShown() and #lp.titleCards == 2 and lp.titleCards[1].bar:IsShown() and lp.viewTitle:GetText() == L.LORE_MASTER, "Legends: two titles, the Lore Master first")
lp.titleCards[2]:Click()
Tick(1)
check(lp.viewTitle:GetText() == L.CRAFTY_BUGGER and lp.who:GetText():find("Shazza", 1, true), "the Crafty Bugger's page")
Inside(lp, "Legends")
UI.Open("ask")
Tick(1)
local ap
for _, o in ipairs(CREATED) do if o.listView and o.viewCards and o.browse then ap = o end end
Inside(ap, "Ask")

-- Dungeons has a Group alert card, the same switch as Settings' "New groups for me".
ns.UI.Select("dungeons"); Tick(1)
check(dp.groupAlert:IsShown() and ns.settings.pop.group ~= false and dp.groupAlert.text:GetText():find(L.Q_ALERT_ON, 1, true),
    "Dungeons: Group alert card, on by default")
dp.groupAlert:Click(); Tick(1)
check(ns.settings.pop.group == false and dp.groupAlert.text:GetText():find(L.Q_ALERT_OFF, 1, true), "clicking it turns group pop-ups off")
dp.groupAlert:Click(); Tick(1)
check(ns.settings.pop.group == true, "and back on")
Inside(dp, "Dungeons")

check(#ERRORS == 0, "no errors", ERRORS[1])
