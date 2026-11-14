-- Milestones (Phase 9 step 2): cards the guild master and managers make on the GM tab,
-- and the Welcome card. Only managers may write them (every reader checks), newest wins, deleted
-- cards stay deleted, at most 20. Plus the pages: the list, the editor, the Welcome page.
math.randomseed(31)
YeahNahMateDB = nil
local ns = LoadAddon("YeahNahMate", "YeahNahMate")
LOGGED_IN = true
FireEvent("PLAYER_LOGIN")
local Ser = LibStub("AceSerializer-3.0")
local function Msg(t) t.v = 1; return Ser:Serialize(t) end
local function Sent(t, from)
    local list = {}
    for i = (from or 1), #SENT do
        local ok, m = Ser:Deserialize(SENT[i].text)
        if ok and type(m) == "table" and m.t == t then m._target = SENT[i].target; m._channel = SENT[i].channel; list[#list + 1] = m end
    end
    return list
end
local B, MS, UI, L = ns.Board, ns.Milestones, ns.UI, ns.L
ns.settings.sharePosition, ns.settings.shareProfessions = false, false
INJECT("YNM", Msg({ t = "HI", ver = "0.13.0" }), "GUILD", "Bluey Heeler")
Tick(15)
local now = GetServerTime()

-- A member can't make cards; cards from someone who isn't a manager are dropped.
check(not MS.CanEdit() and MS.Save({ ty = "lvl", v = 12, m = "Grats {name}", gc = true, on = true }) == nil, "a member can't make a card")
INJECT("YNM", Msg({ t = "BRD", k = "ms", id = "Bluey Heeler:1", ty = "lvl", n = 12, m = "hi", gc = true, on = true, ev = now }), "GUILD", "Bluey Heeler")
Tick(1)
check(#MS.List() == 0, "a card from a non-manager is dropped")

-- Chilli is guild master and names Bingo and me as managers.
FAKE.roster[4][3] = 0
ns.Guild.Scan()
INJECT("YNM", Msg({ t = "BRD", k = "mgr", mg = { "Bingo Heeler", "Ned Jones" }, ev = now + 1 }), "GUILD", "Chilli Heeler")
Tick(1)
check(MS.CanEdit(), "a manager can make cards")

-- Bingo's card comes in.
INJECT("YNM", Msg({ t = "BRD", k = "ms", id = "Bingo Heeler:5", ty = "prof", n = 300, p = "Tailoring", m = "{name} hit {skill} {prof}!",
    gc = true, pu = true, on = true, ev = now + 2 }), "GUILD", "Bingo Heeler")
Tick(1)
local c = MS.Get("Bingo Heeler:5")
check(c and c.ty == "prof" and c.v == 300 and c.p == "Tailoring" and c.by == "Bingo Heeler", "a manager's card is taken")
check(MS.Describe(c) == "Reaches 300 Tailoring", "described: " .. MS.Describe(c))

-- Junk is dropped: a level out of range, an unknown profession, an empty message.
for i, bad in ipairs({
    { ty = "lvl", n = 1, m = "x" }, { ty = "lvl", n = 99, m = "x" }, { ty = "prof", n = 100, p = "Cheese", m = "x" },
    { ty = "lvl", n = 10, m = "" }, { ty = "pvp", n = 3, m = "x" }, { ty = "title", ti = "king", m = "x" },
}) do
    bad.t, bad.k, bad.id, bad.ev = "BRD", "ms", "Bingo Heeler:bad" .. i, now + 3
    INJECT("YNM", Msg(bad), "GUILD", "Bingo Heeler")
end
Tick(1)
check(#MS.List() == 1, "bad cards are dropped (" .. #MS.List() .. ")")

-- I make a level card: cleaned and sent to the guild.
local before = #SENT + 1
local mine = MS.Save({ ty = "lvl", v = 12, m = "Grats {name} on {level}! |cffff0000red|r", gc = true, on = true })
Tick(1)
local out = Sent("BRD", before)
check(mine and mine.v == 12 and not mine.m:find("|", 1, true) and #out == 1 and out[1].k == "ms" and out[1]._channel == "GUILD"
    and out[1].id == mine.id, "my card is saved (no | codes) and sent to the guild")
check(MS.Preview(mine.m, mine):find("^%[Yeah Nah Mate%] Grats Ned on 12!"), "preview has the tag and fill-ins: " .. MS.Preview(mine.m, mine))

-- Editing keeps the id; an older copy from Bingo doesn't roll it back; a newer edit by Bingo wins.
local id, ev1 = mine.id, mine.ev
local edited = MS.Save({ id = id, ty = "lvl", v = 15, m = "Fifteen!", gc = true, on = true })
check(edited.id == id and edited.v == 15 and edited.ev > ev1 and #MS.List() == 2, "editing keeps the card")
INJECT("YNM", Msg({ t = "BRD", k = "ms", id = id, ty = "lvl", n = 12, m = "old", gc = true, on = true, ev = ev1 }), "GUILD", "Bingo Heeler")
Tick(1)
check(MS.Get(id).v == 15, "an older version doesn't roll it back")
INJECT("YNM", Msg({ t = "BRD", k = "ms", id = id, ty = "lvl", n = 20, m = "Bingo's edit", gc = true, on = true, ev = edited.ev + 5 }), "GUILD", "Bingo Heeler")
Tick(1)
check(MS.Get(id).v == 20 and MS.Get(id).by == "Bingo Heeler", "a newer edit by another manager wins")

-- On/off.
check(MS.SetOn(id, false) and not MS.Get(id).on and MS.ActiveCount() == 1, "turned off")

-- Delete: gone, sent, and a late copy of the old card doesn't bring it back.
before = #SENT + 1
local evDel = MS.Get(id).ev
check(MS.Delete(id) and MS.Get(id) == nil and #MS.List() == 1, "deleted")
out = Sent("BRD", before)
check(#out == 1 and out[1].x == true and out[1].id == id, "the delete goes to the guild")
INJECT("YNM", Msg({ t = "BRD", k = "ms", id = id, ty = "lvl", n = 20, m = "zombie", gc = true, on = true, ev = evDel }), "GUILD", "Bingo Heeler")
Tick(1)
check(MS.Get(id) == nil, "a late copy doesn't bring it back")

-- At most 20 cards.
for i = 1, 25 do MS.Save({ ty = "lvl", v = 2 + i, m = "L" .. i, gc = true, on = true }) end
check(#MS.List() == MS.MAX_CARDS, "at most 20 cards (" .. #MS.List() .. ")")
local _, why = MS.Save({ ty = "lvl", v = 50, m = "one more", gc = true })
check(why == "full", "the 21st is refused")
for _, card in ipairs(MS.List()) do if card.by == "Ned Jones" then MS.Delete(card.id) end end
check(#MS.List() == 1, "cleared mine again")

-- The welcome card: defaults, a manager's save, a non-manager's dropped.
local w = MS.Welcome()
check(not w.on and w.gc and w.wr == 1 and w.m:find("{name}", 1, true), "welcome defaults: off, guild chat, officers and up")
before = #SENT + 1
check(MS.SetWelcome({ m = "Welcome {name}!", on = true, gc = true, wr = 2 }), "I save the welcome")
Tick(20)            -- behind the 25 deletes in the send queue
out = Sent("BRD", before)
local wels = {}
for _, m in ipairs(out) do if m.k == "wel" then wels[#wels + 1] = m end end
check(#wels == 1 and wels[1].wr == 2 and wels[1].on == true and wels[1]._channel == "GUILD", "the welcome goes to the guild")
INJECT("YNM", Msg({ t = "BRD", k = "wel", m = "Bluey's welcome", on = true, gc = true, wr = 0, ev = now + 999 }), "GUILD", "Bluey Heeler")
Tick(1)
check(MS.Welcome().m == "Welcome {name}!", "a non-manager's welcome is dropped")

-- Sync: a guildie who asks for the board gets the cards (and the welcome) I wrote; nobody gets the
-- cards pushed at every log-in.
before = #SENT + 1
INJECT("YNM", Msg({ t = "REQ", w = "BRD" }), "WHISPER", "Bandit Heeler")
Tick(30)
local kinds = {}
for _, m in ipairs(Sent("BRD", before)) do if m._target == "Bandit Heeler" then kinds[m.k] = (kinds[m.k] or 0) + 1 end end
check(kinds.wel == 1 and (kinds.ms or 0) >= 1, "asked for the board: the welcome and the cards I hold (incl. tombstones)")
before = #SENT + 1
INJECT("YNM", Msg({ t = "HI", ver = "0.13.0", ask = true }), "GUILD", "Chilli Heeler")
Tick(30)
local pushed = 0
for _, m in ipairs(Sent("BRD", before)) do if m.k == "ms" and m._channel == "WHISPER" and m.o == nil and m._target == "Chilli Heeler" then pushed = pushed + 1 end end
check(pushed == 0, "cards aren't pushed at log-in (" .. pushed .. ")")

---------------------------------------------------------------------------------------------------
-- The pages
UI.Open("gm")
Tick(1)
local gm
for _, o in ipairs(CREATED) do if o.viewCards and o.msCards then gm = o end end
check(gm and #gm.viewCards == 4, "GM tab: Managers, Moderators, Milestones, Welcome cards")
check(gm.viewCards[4].green:IsShown() and gm.viewCards[4].text:GetText():find(L.MS_CARD_WEL_ON, 1, true), "Welcome card green while it's on")
gm.viewCards[3]:Click()
Tick(1)
check(gm.milestonesView:IsShown() and gm.msList:IsShown() and gm.msCards[1]:IsShown() and not gm.msCards[2]:IsShown(), "Milestones: Bingo's card listed")
check(gm.msCards[1].title:GetText() == "Reaches 300 Tailoring" and gm.msCards[1].green:IsShown(), "the card says what it waits for, green while on")

-- New milestone: the editor, a level card.
gm.msNew:Click()
Tick(1)
check(gm.msForm:IsShown() and not gm.msList:IsShown() and gm.viewTitle:GetText() == L.MS_EDITOR_NEW, "New milestone opens the editor")
check(gm.msE.level:IsShown() and not gm.msE.skill:IsShown() and not gm.msE.rideText:IsShown(), "Level shows the level box only")
gm.msE.level:SetText("24")
gm.msE.msg:SetText("Grats {name}")
gm.msE.fills.level:Click()
UI.Dirty(); Tick(1)
check(gm.msE.msg:GetText() == "Grats {name}{level}" and gm.msE.preview:GetText():find("Grats Ned24", 1, true), "fill-in buttons add to the message; preview fills them")
gm.msE.pickType(2)
Tick(1)
check(gm.msE.msg:GetText() == "", "picking another trigger clears the message")
-- The shown fill-ins sit side by side from the first slot, none off the edge.
local fx = gm.msE.fills
check(fx.name.fillX == fx.x and fx.class.fillX == fx.x + 68 and fx.prof.fillX == fx.x + 136 and fx.skill.fillX == fx.x + 204,
    "Profession's fill-ins sit side by side with no gaps")
check(gm.msE.skill:IsShown() and gm.msE.prof:IsShown() and not gm.msE.level:IsShown() and gm.msE.fills.skill:IsShown() and not gm.msE.fills.level:IsShown(),
    "Profession shows skill + profession and its fill-ins")
gm.msE.pickType(5)
Tick(1)
check(gm.msE.titleButtons[1]:IsShown() and not gm.msE.skill:IsShown(), "Title shows the title choice")
check(fx.title:IsShown() and fx.title.fillX == fx.x + 136 and not fx.item:IsShown(), "{title} sits third, not off the edge")
gm.msE.msg:SetText("Grats {title}")
gm.msE.pickType(5)
Tick(1)
check(gm.msE.msg:GetText() == "Grats {title}", "picking the same trigger again keeps the message")
gm.msE.pickType(1)
Tick(1)
gm.msE.msg:SetText("Grats {name} on {level}!")
before = #SENT + 1
gm.msE.save:Click()
Tick(1)
check(not gm.msForm:IsShown() and #MS.List() == 2 and #Sent("BRD", before) == 1, "Save makes the card and goes back to the list")
local newCard
for _, card in ipairs(MS.List()) do if card.by == "Ned Jones" then newCard = card end end
check(newCard and newCard.v == 24 and newCard.gc and newCard.pu and newCard.on, "the card holds what was picked")

-- Edit it; Cancel leaves it alone.
local row
for _, cbox in ipairs(gm.msCards) do if cbox.id == newCard.id then row = cbox end end
row.edit:Click()
Tick(1)
check(gm.msForm:IsShown() and gm.msE.level:GetText() == "24" and gm.viewTitle:GetText() == L.MS_EDITOR_EDIT, "Edit opens the card")
gm.msE.level:SetText("30")
gm.msE.cancel:Click()
Tick(1)
check(MS.Get(newCard.id).v == 24, "Cancel changes nothing")

-- Turn off, then Delete (asks once).
row.toggle:Click()
Tick(1)
check(not MS.Get(newCard.id).on and not row.green:IsShown(), "Turn off: not green")
row.delete:Click()
Tick(1)
check(MS.Get(newCard.id) and row.delete:GetText() == L.MS_SURE, "Delete asks Sure? first")
row.delete:Click()
Tick(1)
check(MS.Get(newCard.id) == nil and #MS.List() == 1, "the second click deletes")

-- Welcome page: loads what's saved, rank stepper, Save.
gm.viewCards[4]:Click()
Tick(1)
check(gm.welcomeView:IsShown() and gm.welE.msg:GetText() == "Welcome {name}!" and gm.welE.on:GetChecked(), "Welcome page loads the saved card")
check(gm.welE.preview:GetText() == "[Yeah Nah Mate] Welcome Ned!", "welcome preview: " .. gm.welE.preview:GetText())
gm.welE.less:Click()
Tick(1)
gm.welE.save:Click()
Tick(1)
check(MS.Welcome().wr < 2, "the rank stepper changes who posts it (" .. MS.Welcome().wr .. ")")

---------------------------------------------------------------------------------------------------
-- Firing: a level card (step 3). Chat sends land in WHISPERS (the stub's SendChatMessage).
local lvlCard = MS.Save({ ty = "lvl", v = 34, m = "{name} the {class} hit {level}!", gc = true, pu = true, on = true })
Tick(5)
local function Chats(from) local n = {} for i = from, #WHISPERS do n[#n + 1] = WHISPERS[i] end return n end

-- A dry run (the editor's Test path): nothing sent, nothing marked done.
local w0, s0 = #WHISPERS + 1, #SENT + 1
MS.OnLevel(34, "dry")
Tick(1)
check(#Chats(w0) == 0 and #Sent("MSF", s0) == 0 and not ns.db.chars[ns.me].msDone[lvlCard.id], "dry run: nothing sent, not marked done")

-- A real level-up to 34: one tagged GUILD line, the pop-up to the guild, marked done.
w0, s0 = #WHISPERS + 1, #SENT + 1
FireEvent("PLAYER_LEVEL_UP", 34)
Tick(1)
local ch = Chats(w0)
check(#ch == 1 and ch[1].kind == "GUILD" and ch[1].text:find("^%[Yeah Nah Mate%] Ned the .- hit 34!"), "level 34: one tagged guild line (" .. tostring(ch[1] and ch[1].text) .. ")")
local pops = Sent("MSF", s0)
check(#pops == 1 and pops[1]._channel == "GUILD" and pops[1].m:find("hit 34!", 1, true) and not pops[1].m:find("[Yeah Nah Mate]", 1, true), "the pop-up goes to the guild (no tag)")
check(ns.db.chars[ns.me].msDone[lvlCard.id], "marked done for this character")
w0 = #WHISPERS + 1
FireEvent("PLAYER_LEVEL_UP", 34)
Tick(1)
check(#Chats(w0) == 0, "once only")
FireEvent("PLAYER_LEVEL_UP", 35)
Tick(1)
check(#Chats(w0) == 0, "another level: no card, nothing")

-- live test: really posts, not marked done; then the 3-an-hour limit stops the guild line.
w0 = #WHISPERS + 1
MS.OnLevel(34, "live")
MS.OnLevel(34, "live")
MS.OnLevel(34, "live")
Tick(1)
check(#Chats(w0) == 2, "live tests post, up to 3 an hour (1 real + 2 tests = 3)", #Chats(w0))

-- Opt-out: no guild line, the pop-up still goes.
ns.db.chars[ns.me].msPosts = {}
ns.settings.msNoPost = true
w0, s0 = #WHISPERS + 1, #SENT + 1
MS.OnLevel(34, "live")
Tick(1)
check(#Chats(w0) == 0 and #Sent("MSF", s0) == 1, "posting switched off: pop-up only")
ns.settings.msNoPost = nil

-- A guildie's pop-up arrives: shown, if the switch is on.
INJECT("YNM", Msg({ t = "MSF", m = "Bluey hit 40!" }), "GUILD", "Bluey Heeler")
Tick(1)
check(ns.Toast.IsShown(), "a guildie's milestone pops up")
ns.settings.pop.milestone = false
check(not ns.Toast.Allowed("milestone"), "and the Settings switch turns it off")
ns.settings.pop.milestone = true
INJECT("YNM", Msg({ t = "MSF", m = "Stranger!" }), "GUILD", "Nobody Atall")
Tick(1)

---------------------------------------------------------------------------------------------------
-- The welcome (step 3): one online addon user at or above the rank posts it; backups wait.
ns.db.chars[ns.me].msPosts = {}
check(MS.SetWelcome({ m = "Welcome {name}! Say g'day", on = true, gc = true, wr = 1 }), "welcome on, officers and up")
Tick(20)
local function Join(name) FireEvent("CHAT_MSG_SYSTEM", name .. " has joined the guild.") end

-- I'm rank 4: not one of the posters (Chilli the GM, Bluey the officer are).
local posters = MS.Posters(1)
check(#posters == 2 and posters[1] == "Chilli Heeler" and posters[2] == "Bluey Heeler", "posters: GM then officer (" .. table.concat(posters, ",") .. ")")
w0 = #WHISPERS + 1
Join("Newbie Person")
Tick(60)
check(#Chats(w0) == 0, "not my rank: I don't post it")

-- Now I'm an officer too: third in line (Chilli 0, Bluey 1, Ned 1). Chilli posts first: I stand down.
FAKE.myRank = 1
ns.Guild.Scan()
check(MS.Posters(1)[3] == "Ned Jones", "I'm third in line")
w0 = #WHISPERS + 1
Join("Second Newbie")
Tick(5)
INJECT("YNM", Msg({ t = "MSW", n = "Second Newbie" }), "GUILD", "Chilli Heeler")
Tick(60)
check(#Chats(w0) == 0, "the first in line posted it: I don't")

-- Nobody ahead of me posts: after my turn (3 + 2 x 15 s) I do, and tell the guild's addons.
w0, s0 = #WHISPERS + 1, #SENT + 1
Join("Third Newbie")
Tick(20)
check(#Chats(w0) == 0, "still waiting my turn at 20 s")
Tick(20)
ch = Chats(w0)
check(#ch == 1 and ch[1].kind == "GUILD" and ch[1].text == "[Yeah Nah Mate] Welcome Third! Say g'day", "backup: I post it (" .. tostring(ch[1] and ch[1].text) .. ")")
local msw = Sent("MSW", s0)
check(#msw == 1 and msw[1].n == "Third Newbie" and msw[1]._channel == "GUILD", "and tell the guild's addons it's done")
w0 = #WHISPERS + 1
FireEvent("CHAT_MSG_SYSTEM", "Third Newbie has left the guild.")
Join("Third Newbie")
Tick(60)
check(#Chats(w0) == 0, "a quick leave and rejoin isn't welcomed twice")

-- Welcome switched off, or my posting switched off: nothing from me.
ns.settings.msNoPost = true
w0 = #WHISPERS + 1
Join("Fourth Newbie")
Tick(60)
check(#Chats(w0) == 0, "my posting switched off: I step aside")
ns.settings.msNoPost = nil
check(MS.SetWelcome({ m = "Hi {name}", on = false, gc = true, wr = 1 }), "welcome off")
Tick(20)
w0 = #WHISPERS + 1
Join("Fifth Newbie")
Tick(60)
check(#Chats(w0) == 0, "welcome off: nothing")

-- Other system lines don't count; the dev test posts nothing without live.
w0 = #WHISPERS + 1
FireEvent("CHAT_MSG_SYSTEM", "You have learned a new spell.")
MS.PostWelcome("Testy", "dry")
Tick(60)
check(#Chats(w0) == 0, "a dry welcome and other system lines send nothing")
MS.PostWelcome("Testy", "live")
Tick(1)
ch = Chats(w0)
check(#ch == 1 and ch[1].text == "[Yeah Nah Mate] Hi Testy", "a live welcome posts now " .. #ch .. " " .. tostring(ch[1] and ch[1].text))
FAKE.myRank = nil
ns.Guild.Scan()

---------------------------------------------------------------------------------------------------
-- Step 4: professions, riding, legendary items, titles. Only changes seen live fire.
ns.db.chars[ns.me].msPosts = {}
local function Card(t) t.gc, t.on = true, true; local c = MS.Save(t); Tick(5); return c end
local profCard = Card({ ty = "prof", v = 150, p = "Tailoring", m = "{name} hit {skill} {prof}" })
local anyCard = Card({ ty = "prof", v = 200, p = "any", m = "{name}: {skill} in {prof}" })
local rideCard = Card({ ty = "ride", m = "{name} can ride!" })
local legCard = Card({ ty = "leg", m = "{name} got {item}!" })
local loreCard = Card({ ty = "title", ti = "lore", m = "{name} is our {title}" })
local function Lines(from) local out = {} for i = from, #WHISPERS do out[#out + 1] = WHISPERS[i].text end return out end
local function Burst(e) FireEvent(e); Tick(2) end

-- Professions: the first reading is the starting point; crossing the number fires, once.
FAKE.profNames, FAKE.profRanks = { "Tailoring", "Cooking" }, { 140, 190 }
Burst("SKILL_LINES_CHANGED")
w0 = #WHISPERS + 1
FAKE.profRanks = { 149, 195 }
Burst("SKILL_LINES_CHANGED")
check(#Lines(w0) == 0, "skills going up but not reaching a card: nothing")
FAKE.profRanks = { 151, 195 }
Burst("SKILL_LINES_CHANGED")
local ls = Lines(w0)
check(#ls == 1 and ls[1] == "[Yeah Nah Mate] Ned hit 150 Tailoring", "Tailoring 149 -> 151 fires the 150 card (" .. tostring(ls[1]) .. ")")
FAKE.profRanks = { 160, 200 }
Burst("SKILL_LINES_CHANGED")
ls = Lines(w0)
check(#ls == 2 and ls[2] == "[Yeah Nah Mate] Ned: 200 in Cooking", "an 'any profession' card fires for Cooking (" .. tostring(ls[2]) .. ")")
FAKE.profRanks = { 210, 200 }
ns.db.chars[ns.me].msPosts = {}
Burst("SKILL_LINES_CHANGED")
ls = Lines(w0)
check(#ls == 3 and ls[3] == "[Yeah Nah Mate] Ned: 200 in Tailoring", "and again for Tailoring (each profession once)")
FAKE.profRanks = { 140, 190 }
Burst("SKILL_LINES_CHANGED")
FAKE.profRanks = { 220, 210 }
Burst("SKILL_LINES_CHANGED")
check(#Lines(w0) == 3, "never twice for the same card and profession")

-- Riding: the "learned a new spell" line (Forever's riding spell numbers aren't known yet).
ns.db.chars[ns.me].msPosts = {}
w0 = #WHISPERS + 1
FireEvent("CHAT_MSG_SYSTEM", "You have learned a new spell: Mining.")
Tick(1)
check(#Lines(w0) == 0, "another spell: nothing")
FireEvent("CHAT_MSG_SYSTEM", "You have learned a new spell: Apprentice Riding.")
Tick(1)
ls = Lines(w0)
check(#ls == 1 and ls[1] == "[Yeah Nah Mate] Ned can ride!", "learning to ride fires (" .. tostring(ls[1]) .. ")")
FAKE.spells = { [33388] = true }
Burst("SPELLS_CHANGED")
check(#Lines(w0) == 1, "and only once")
-- Forever's own riding (13 Nov, from its game files): Galestrider Riding and the Classic racial
-- skills count too, by spell or by the learned line.
local mk = ns.Milestones
check(mk.RidingName("You have learned a new spell: Galestrider Riding.")
    and mk.RidingName("You have learned a new spell: Undead Horsemanship.")
    and mk.RidingName("You have learned a new spell: Mechanostrider Piloting.")
    and not mk.RidingName("You have learned a new spell: Mining."), "Forever's riding names are recognised")
check(mk.RIDING_SPELLS[1285849] and mk.RIDING_SPELLS[824] and not mk.RIDING_SPELLS[90265],
    "Forever's riding spells: Galestrider and racial riding in, Master Riding (not on Forever) out")

-- Legendary: my own loot line with an orange link; the guild line keeps the link, the pop-up shows the name.
local link = "|cffff8000|Hitem:19019::::::::60:::::|h[Thunderfury, Blessed Blade of the Windseeker]|h|r"
w0, s0 = #WHISPERS + 1, #SENT + 1
FireEvent("CHAT_MSG_LOOT", "You receive loot: |cffa335ee|Hitem:12345::::|h[Some Epic]|h|r.")
FireEvent("CHAT_MSG_LOOT", "Bluey receives loot: " .. link .. ".")
Tick(1)
check(#Lines(w0) == 0, "an epic, or someone else's legendary: nothing")
FireEvent("CHAT_MSG_LOOT", "You receive loot: " .. link .. "x1.")
Tick(1)
ls = Lines(w0)
check(#ls == 1 and ls[1] == "[Yeah Nah Mate] Ned got " .. link .. "!", "my legendary: the line carries the item link")
local pop = Sent("MSF", s0)
check(#pop == 0 or not pop[1].m:find("|", 1, true), "pop-ups carry the name, not the link")
FireEvent("CHAT_MSG_LOOT", "You receive item: " .. link)
Tick(1)
check(#Lines(w0) == 1, "the same legendary again: nothing")

-- Titles: becoming the Lore Master fires; losing it and winning it back within 7 days doesn't.
ns.db.chars[ns.me].msPosts = {}
local realLore = ns.Questions.LoreMaster
local holder = "Bluey Heeler"
ns.Questions.LoreMaster = function() return holder end
w0 = #WHISPERS + 1
ns.Fire("QUESTIONS")
holder = "Ned Jones"
ns.Fire("QUESTIONS")
Tick(1)
ls = Lines(w0)
check(#ls == 1 and ls[1] == "[Yeah Nah Mate] Ned is our Lore Master", "winning Lore Master fires (" .. tostring(ls[1]) .. ")")
holder = "Bluey Heeler"
ns.Fire("QUESTIONS")
holder = "Ned Jones"
ns.Fire("QUESTIONS")
Tick(1)
check(#Lines(w0) == 1, "won back within 7 days: not again")
ns.db.titleHeld.lore = GetServerTime() - 8 * 86400
holder = "Bluey Heeler"
ns.Fire("QUESTIONS")
holder = "Ned Jones"
ns.Fire("QUESTIONS")
Tick(1)
check(#Lines(w0) == 2, "won back after more than 7 days: yes")
ns.Questions.LoreMaster = realLore

-- Dry runs of each kind send nothing.
w0 = #WHISPERS + 1
MS.OnSkill("Tailoring", 149, 150, "dry"); MS.OnRiding("dry"); MS.OnTitle("lore", "dry")
Tick(1)
check(#Lines(w0) == 0, "dry runs of each kind: nothing sent")
-- The temporary test commands are gone for release (take them out before uploading).
check(ns.devCommands.mstest == nil and ns.devCommands.weltest == nil, "no mstest / weltest in the release")

-- Out of date: the banner's top right says what I have and what to update to.
local realVersion = ns.VERSION
ns.VERSION = "0.14.0"                      -- a "test" build never nags
INJECT("YNM", Msg({ t = "HI", ver = "99.0.0" }), "GUILD", "Bluey Heeler")
Tick(1)
UI.Open("home")
UI.Dirty(); Tick(1)
local verLine
for _, o in ipairs(CREATED) do
    local t = o.GetText and o:GetText()
    if type(t) == "string" and t:find("Out of date", 1, true) then verLine = t end
end
check(verLine and verLine:find("you have v" .. ns.VERSION, 1, true) and verLine:find("update to v99.0.0", 1, true),
    "the banner says I'm out of date: " .. tostring(verLine))
ns.VERSION, ns.Comm.newest = realVersion, nil

check(#ERRORS == 0, "no errors (" .. tostring(ERRORS[1]) .. ")")
