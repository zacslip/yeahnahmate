# Changelog

## 0.28.0

- Clans tab: a new **My Clan / All clans** switch at the left of the bar. My Clan shows your clan's list next to the new Clan roll panel.
- New **Clan roll**: your clan's leader, second in command, moderators, managers and the guild master can run a /roll for an item, with an optional timer and an on-screen countdown. Results sort live, with who hasn't rolled yet, tie rerolls, Announce and Whisper winner, and the last 20 rolls saved.
- Only a normal /roll (1-100) counts, and only your first one. Rolls with another range, repeats and rolls outside the timer are ignored. If you roll again, your own screen tells you your first roll stands.
- Options to let non-clan members roll, and to skip people who already won this meeting.
- When a roll ends, the addon posts one "Roll over" line to group chat for the person who started it.
- Group members with the addon see each roll above that player's head, and the winner gets a gold crowned die for 10 seconds plus a pop-up. You can turn this off with **Show rolls above heads** in Settings.
- The roll panel can pop out into its own small window, also opened with `/ynm roll`. It opens by itself for group members when a roll starts and they can't see it.
- The guild master or a manager can run an **All clans roll** from its own view on the Clans tab. Tick the clans to include and set the roll up; each clan's leader gets that setup and clicks Start in their own group. If a leader isn't in a group or doesn't answer, the next leader or their second in command is asked instead.
- You see who'll be asked, how each clan is going, each clan's winner and the overall winner: the highest roll across the clans. Start roll turns into Cancel while it's going. Announce posts the winners to guild chat, or to group chat, and the last 20 all-clans rolls are saved.
- Several clans can roll in the same raid: each player's screen follows their own clan's roll.
- Fixed: the addon could sometimes stop you opening chat (typing / or pressing Enter did nothing). It happened after closing the window with Escape just as a fight started, or when a text box you were typing in got hidden.
- Every name on the roll lists has **Whisper** and **Target** buttons, and the lists show full names. Whisper opens a message to that player; the winner's has "You won" filled in, and nothing is sent until you press Send. Target targets the player if they're in your group (greyed out for anyone else), never during a fight. On the All clans roll, each clan's winner shows by name.
- **How it works** cards on the Clans tab: one on the Clan roll panel with the steps for clan leaders, and one on the All clans roll view showing how the roll goes out to each clan leader's addon and how the winners come back.
- Calendar: each guildie can have up to 15 upcoming events. A weekly event counts once. If you're at the limit, the new-event form tells you why.
- Professions: the first "Yeah" to sharing your professions now actually shares them.
- Milestone pop-ups: at most 3 a minute from any one guildie.

## 0.27.1

- Clan invites: "got an inv, cheers" no longer counts as someone asking for an invite. "got an inv?" and "got an inv pls" still do.
- Leveling guide: a closed storyline now points at the quest in your log, even when it's on a different branch.
- Addon recruiting: guildies on older versions no longer re-request a corrected credit every time that player logs in.

## 0.27.0

- Raids now has its own main tab, and the Leveling tab keeps its name at level 60.
- New Bag quests page: every quest that rewards a normal bag for your faction, as full storylines with each bag's slots. Needs QuestieDB.
- New Sleeping bag page: a step-by-step tracker for the Cozy Sleeping Bag chain, with your next step highlighted, tips for the tricky parts and a map pin. Map pins need QuestieDB.
- New Keys page: what each dungeon key and attunement opens, how to get it, and which ones you already have.
- New Mounts page: a riding checklist for your race and class, with your trainer, vendor and costs.

## 0.26.3

- Leveling guide: finishing one of two either-or quests now marks the other as done and unlocks the steps after it.
- Class quests: removed 12 quests that can't actually be obtained.
- Show entrance: Dire Maul East, West and North now each pin their own door.
- Clicking a zone now opens its map in every game language.
- Bosses: a kill still saves if the game hides your character's ID during the fight.
- Addon recruiting: Skip is gone while you're correcting a credit, so it can't remove the credit or use up your one change.
- Addon recruiting: a corrected credit now stays in the month of your original answer.

## 0.26.2

- Addon recruiting: picking who got you onto the addon now asks you to confirm the name first, so a slip while scrolling can't credit the wrong person.
- The Someone else list now has every guildie, including offline players, with a search box that narrows the list as you type.

## 0.26.1

- Addon recruiting: credited the wrong person? There's now a link under your answer to fix it. You can change it once, and your old answer stays until you pick someone new.

## 0.26.0

- Leveling guide: new Bosses column on the Dungeons page, like 3/4. It turns gold when you've started a dungeon and green when every main boss is dead. Kills are saved for each character for good, starting from this update.
- Optional and secret bosses count as a bonus, like 3/3 +1. Rare spawns aren't counted. Hover a dungeon to see every boss, ticked off as you kill them.
- New Show all button on Zones and Dungeons, to see everything for your faction, not just your level.
- New Show entrance button on a dungeon's page: opens the map with the entrance pinned. Most entrances need QuestieDB.
- New Dungeon map button, on dungeons where the game has an inside map. Needs QuestieDB.
- The map pin is bigger, pulses and sits on top of other map icons, so it's easier to find.
- Hall of Thanes is no longer listed for Horde.

## 0.25.0

- Leveling tab: Zones, Dungeons, Class quests and Raid roster now each have their own full-width page.
- New Class quests page: your class's quests for your faction and race, with the same In log, Done, Locked, quest chains and Show on map as the dungeon lists. Needs QuestieDB.
- Click a zone to open it on the world map.
- Quest lists are now a tree: each storyline is one row with its progress, like 2/6. Click + to see its steps. A closed storyline points you at the next quest to do.
- Quest rows are coloured by status: green for Done, gold for In log, orange for Locked. A storyline's top row shows the furthest you've got.
- Quest lists have a new Location column showing the zone a quest starts in.
- Sort quest lists by clicking a column heading.
- Clan meetings: whispering for an invite now understands more ways of asking, like "invite me" or "can I get an inv".

## 0.24.1

- Dungeon quest lists are now powered directly by QuestieDB, the free quest database made by the Questie team, so they stay up to date with all their work. Install QuestieDB and keep it ticked in your AddOns list to see them. Everything else works without it. The Yeah Nah Mate Quests folder is gone, so it's safe to delete if it's still in your AddOns.
- Leveling guide: quest givers in Dun Morogh can now be shown on the map.
- Show on map no longer closes the addon. The window waits behind the map and comes back when you close it.
- Leveling guide: quests with a quest giver in each faction's city now send you to your own, not the enemy's.
- Leveling guide: Skyborne players now see their own versions of quests.
- If a guildie turns off recipe sharing, that now reaches guildies who were offline at the time.
- Guildies who just logged in no longer lose part of their catch-up (events, requests, questions).
- A broken addon message from someone else no longer causes an error.
- Clans: Ask for an invite no longer stays stuck on Asked when a new organiser starts the meeting.

## 0.24.0

- Dungeon level ranges now match the game's Group Finder, and dungeons your faction can't use are no longer listed.
- Settings moved out of the tab row to a gear icon at the top right, next to the "i".
- New Leveling tab, which becomes Raids at level 60, with buttons inside to see either. The raid roster moved here from the Calendar and is still coming soon.
- Leveling guide: the zones and dungeons for your level and faction. Zones show their range and the levels they're best at. Dungeons show their range, boss level, the level they're best from, where they are and anything you need to get in.
- Click a dungeon to see its quests for your faction and class, marked In log or Done. Click a quest to pin where it starts and open the map there.
- Quest chains: a quest you can't take yet says what it needs next, hovering shows the whole chain with your progress, and the map pin goes to the next quest you need.
- The quest lists come in a small second addon, Yeah Nah Mate Quests, included in the same download. Its quest data is adapted from [Questie](https://github.com/Questie/Questie) (GPLv3). You don't need Questie installed.

## 0.23.1

- No more "No player named ... is currently playing" spam when a guildie logs off while the addon is sharing data with them. The addon now stops whispering them, and hides any leftover line. If you whisper someone offline yourself through the addon's whisper box, you still get told.

## 0.23.0

- Better error reports. `/ynm errors` now shows the version and time of each error and marks ones from older versions, which may already be fixed.
- `/ynm errors clear` wipes the list, so you can see whether an error comes back.
- **Copy error report** in the About panel (the "i" by the version): your addon and game versions, recent errors and other addons, ready to paste into Discord or a CurseForge comment. Nothing is sent by itself.

## 0.22.0

- Proximity voice is gone, with its speaker tab, group voice button, `/ynm voice` and key binding. The guild wasn't using it and the game's own voice chat does the job. Blizzard's voice chat itself isn't touched.
- If a crash ever left a guildie's voice volume turned down, the addon puts it back. Old voice settings and old voice errors are cleared.

## 0.21.1

- Settings tidied: the share message box uses the whole width; the Welcome page button sits at the bottom under "What the addon shares"; "Minimap button" no longer runs into the nameplates tick.

## 0.21.0

Recruiters:

- **Addon recruiting**: the handshake tab on the right of the window, by the version (getting guildies onto the addon, not recruiting to the guild). It slides out with three things:
  - **Share the addon**: guildies online who don't have Yeah Nah Mate yet. Click Share and a whisper opens with your recruitment message; read it, change it if you like, and press Enter. Once a week per guildie.
  - **Who got you onto it?** A gold "!" on the tab until you answer, once. Anyone who shared it with you is suggested; or pick someone else, or skip.
  - **Top recruiters**: who's brought the most guildies on, all time and this month. Hover a name to see who.
- Your **share message** is in Settings, under Addon recruiting at the bottom. It points guildies to the guild Discord, as WoW chat links can't be clicked.
- Settings: the Privacy box is gone (the Welcome page says it all); its **Welcome page** button is now at the top right.
- Right-click a guildie on the Clans tab: **Share the addon** (if they haven't got it).
- Fair counting: people, not characters (alts count once), nobody recruits themselves, and the guild master and managers can take a wrong claim off the board.

## 0.20.5

- Testing tools only: seeing the addon as a clan's leader rank now shows that clan's Start meeting (and no Challenge button for it), like the real leader sees.
- Settings: the nameplate tooltip now says Shift+V (the friendly nameplates key), not Ctrl+V.

## 0.20.4

- **About panel**: a small round "i" next to the version (top right of the window) shows your version, whether a guildie has a newer one, every / command, and how to report a problem.

## 0.20.3

- **A Yeah Nah Mate button on the game's guild window**: open Guild & Communities (J) and there's a Yeah Nah Mate tab under the tabs on the right, in the same style. Click it to close the game's window and open Yeah Nah Mate. In combat the game's window stays open and Yeah Nah Mate opens on top.

## 0.20.2

- **Fixed a voice chat error** that could repeat hundreds of times ("attempt to compare a secret string value" in Voice.lua). On some setups the game hides details of the voice channel you're in from addons; the addon now treats a hidden channel as not the guild's instead of erroring, so Proximity just waits.

## 0.20.1

- **Guildies near you on the minimap, smoother and closer to real time**: while a guildie with the addon is close by (about minimap range), you both now send your position every second while moving (it was every 3), and their dot moves smoothly every frame towards their newest position instead of guessing ahead, so it no longer runs past them and snaps back. It's about a second behind them. With 7 to 15 close by it slows down a bit, and in a crowd (more than 15, like a guild meeting) it works as before, so the guild's traffic stays in check. These go on their own addon message channel, so they never hold up anything else.
- **Guildies in your group use the game's own dots**: the game already shows your party and raid members on the map and minimap, live, so the addon no longer draws a second dot on top of theirs. Leave the group and the addon's dot comes back. Group members don't make you send your position faster either.
- Works alongside 0.20.0: guildies who haven't updated still see you every 3 seconds, as before.

## 0.20.0

- **Guildies near you keep up on the minimap**: while a guildie with the addon is close by (about minimap range), you both send your position every 3 seconds while moving instead of every 15 or more, and their dot glides smoothly the way they're going instead of standing still and jumping. In a crowd (more than 15 close by, like a guild meeting) it all works as before, so the guild's traffic doesn't grow.
- **Materials on the Professions tab**: hover a recipe to see what it needs and how many of each you're carrying (green when you have enough). Works for every recipe in the list, not just your own.
- **Guildies stand out on their nameplates**: corner brackets round the name and health bar in their clan's colour (Orc red, Troll teal, Tauren orange, Undead purple, Skyborne blue). The guild master and the rank under them get a crown on each side of theirs. Needs the game's friendly nameplates on (Shift+V). The game locks nameplates in some places (like dungeons); there they show as normal. Switch it off in Settings (Minimap, Mark guildies' nameplates). Never on your own bar (the personal resource display), or on someone from another guild who shares a guildie's name.

## 0.19.0

Clans:

- **A new Clans tab.** The guild by race: each character is in the clan of its own race. Every clan side by side, one list each: who leads it, how many are online, and its members with their role badges and names in class colour (online first; scroll with the mouse wheel; hover a name for more). Your own clan is lit up in gold.
- **Clan leaders come from the guild ranks, by themselves.** Under the guild's top two ranks, each rank held by one guildie leads that guildie's clan, shown with a crown. If that ever picks wrong, the guild master or a manager can set it by hand on the GM tab (Moderators, then Clan leaders).
- **Clan meetings**: a clan's leader (or the guild master, a manager or a Clan moderator rank) clicks **Start meeting** on the bar at the top of the Clans tab. The clan gets a pop-up with **Ask for an invite**, or anyone can just **whisper the leader "inv"** (also "invite", "inv pls"). While it's on, the clan's list is the invite list: **green** = asked, ready to invite; **gold** = was in the group before a Disband; a tick = in your group. **Click a name to invite them**, or use **Invite next**. Nothing is ever whispered back.
- **Disband** (click twice): everyone out of your group, for layer trouble. Who was in it goes back to the top of the list for 30 minutes.
- The guild master and Clan moderators can click another clan's name to run that clan's meeting.
- **Challenges for the leadership**: click **Challenge** on the bar to challenge for your clan's leadership at the next guild meeting (not against anyone in particular: challengers go in sign-up order, each against whoever leads at that moment). **Withdraw** any time (click twice). Challengers get crossed swords by their name; hover the swords on a clan's title for the order and the last 30 days' results. The guild master, managers and Clan moderators **right-click a challenger** to mark them **Won** or **Lost**; a win is made real by promoting them to the clan's rank in the guild roster.
- **Second in command**: the guild master, a manager or a Clan moderator right-clicks a clan member to give them the leader's meeting buttons for 30 minutes (or end it early). They get a silver mark by their name.
- **Right-click any name** on the Clans tab: Invite, Whisper, and whatever else you may do.
- **Your roles**: pick up to two of Tank, Healer and DPS on the Clans tab. They show next to your name and in your tooltip for guildies with the addon.
- Guildies' tooltips say which clan they're in and their roles.
- Under each clan's name: the guild rank title that leads it.
- **Sort the clan lists** by **Roles** (Tank, Healer, DPS) or **Name**: click the title over any list (it sorts them all), again to reverse, a third time for the usual order (leaders first). Online guildies stay on top.
- **Roster tab**: new **Roles** and **Race** columns (click either to sort).
- GM tab, Clan leaders: a warning when two ranks would lead the same clan (e.g. "2 leaders for Troll: Warband leads"); hover the row for what to do.
- GM tab: a Clans column for moderator ranks: those ranks can run any clan's meeting.
- The tab row is a little tighter to fit the new tab.

## 0.18.0

Calendar events, round 2:

- **Event types are now Social, Dungeon and Raid** (picked at the top of the event form, above the time). New events start as Social. Levelling and Other are gone (they were only a different label); events made with them still show, as Social. **Raid** is greyed out for now: it arrives with the raid roster.
- **Important events** (the guild master, managers and Calendar moderators only): two new rows in the event form.
  - **Remind all: 15m / 30m / 60m**: tick any of them. Everyone in the guild with the addon gets a pop-up that long before the event, whatever their pop-up settings, and every week for a weekly event. Logging in late only shows the next one (no late "60 minutes" reminder 20 minutes before).
  - **Tell everyone now**: a pop-up for everyone when you save it, and for guildies who were offline when they next log in (until it starts).
  - Important pop-ups wait until a fight is over, and other pop-ups don't cover them up.
  - Important events say so in gold on the calendar.
- **Meeting places**: "Meet at" in the event form: a few words (like "Org bank") and, if you like, the exact spot.
  - **Here** uses the spot where you're standing (the button gets a tick). **x** clears it.
  - The event shows "Meet at: Org bank (Orgrimmar)", and **Pin** puts a star on your world map and minimap (at the minimap's edge when you're further away). Click Unpin to take it off.
- **The event form fits the event**: a Social event has no empty space where the Dungeon roles go.
- **Longer notes**: the note box has three lines (150 letters). The calendar shows the title; hover over an event (or a day) to read its note.
- **"Tell me who's going"** replaces "Mute answers", and it's off for new events: tick it to get a pop-up when someone says they're going. On your own events, Notify / Quiet switches it later. Events you've already made keep how they were.
- Saving an event that can't be saved now says why (no title, cancelled or removed, not yours to change).
- Guildies still on an older version don't get the important pop-ups: everyone should update.

## 0.17.2

Fixes from a review of the whole addon before opening it up to contributors:

- **Group voice pop-ups can be switched off**: a new tick in the voice panel ("Group voice pop-ups").
- **Settings: the guild chat switch now says what it covers**: "Post milestones & welcomes from my character". Untick it and the addon never posts in guild chat from your character, including the welcome for new members (another officer posts it instead).
- **Cancelling your own calendar event asks first** (click Remove twice), so a mis-click can't cancel it for the whole guild.
- **Craft requests: up to five "who made it" ticks** when marking one done (was three), so everyone who helped can get their Crafty Bugger point.
- **Accented letters and emoji are never cut in half** at the end of a long milestone, welcome or whisper (the game refuses a chat line that ends in half a letter), or in event titles, notes, guild info and streamer cards.
- If the game refuses a whisper, the whisper box says so and keeps your text instead of showing an error.
- The window comes to the front when you open it, even with other addons' windows open.
- The two first-time questions (share your position? your professions?) now show when you join a guild, not only at the next login.
- New request opens empty after a cancelled one; clicking Post twice on Ask no longer shows an error.
- Players' copies no longer include the developer test tools (they only listened, but there's no reason for them to run).

## 0.17.1

- Behind the scenes: if one part of the addon hits an error on a guildie's message, the other parts still get it (before, one error could stop the rest, e.g. a recipe list not arriving).
- Tidied up for going open source: the code is now on GitHub (https://github.com/zacslip/yeahnahmate) for anyone who wants to report a bug or help build it. Nothing else changes in game.

## 0.17.0

- **Proximity voice** (new, off until you tick it): hear guildies louder the closer they are, in Blizzard's own guild voice chat. The addon turns each guildie's volume up and down by how far away they are; Blizzard carries the voice.
  - A speaker tab on the left of the window, next to the banner. Click it to slide the voice panel out; right-click to turn Proximity on or off. Its colour shows the state: grey off, red can't start (it says why), gold not in guild voice yet (with a Join guild voice button), green on, blue group voice.
  - Settings in the panel: Range (Close, Normal, Far), Far away (Silent or Faint), Not on map (guildies the addon can't place: Normal or Quiet), Fade (Even or Natural), Full volume for my group.
  - **Near you in voice**: who's in guild voice, nearest first, with distance, volume and who's talking. Click a name to always hear them at full volume.
  - **Group voice**: in a party or raid, move to your group's own private voice chat. Guildies in the group with the addon get a pop-up to join (their own click); Back to guild voice returns you.
  - Unticking Proximity keeps you in guild voice at normal volume; **Leave voice** takes you out.
  - Your own volume for each guildie stays the top, mutes are never touched, and every volume goes back when you turn it off, leave guild voice or log out (or at the next login after a crash).
  - Volumes glide (no jumps), and guildies' positions are guessed between updates. With Proximity on and a guildie in voice within 400 yards, your position goes every 3 seconds while you move.
  - `/ynm voice` (on/off), `/ynm voice join | group | guild | leave`, and a key binding (Options > Keybindings > AddOns). The ? in the panel explains how to turn on voice chat and where it can get in the way.
  - Everyone who wants proximity needs this version: guildies without it stay at normal volume.

## 0.13.0

- **One layout for Dungeons, Professions and Ask.** Each has a sidebar on the left: the main button at the top (Post a group, New request, Ask a question), the views under it with counts, then a box (your dungeon status, the Crafty Bugger, the Lore Master). The lists and forms are on the right.
  - Professions: the profession list is now a menu at the top of the list ("All professions"). Under New request, Recipes, Requests and History are cards like the Dungeons tab's, each saying how things stand (recipes, open requests and how many you can make, finished and made). The Crafty Bugger is on the Legends tab.
  - Dungeons: the sidebar is four cards. At the top, yours: whether you're available, and your group (where, and who's waiting to join; click to post one). Under a line, what's out there: open groups (how many, how many at your level) and available guildies (how many, and their roles). Click a card to open it on the right; the forms are two columns.
  - Ask: under Ask a question, Open, Mine and Resolved are cards (how many open and how many have no answer yet; how many of yours and how many wait for you to mark; how many resolved). Under a line, the new question alert is a card too: click it to turn the alert on or off. The Lore Master is on the Legends tab.
  - Professions: Ask on a recipe lets you pick who. With one crafter online it opens the whisper box for them; with more, the button says how many ("Ask (3)") and opens a list of who's online, highest skill first. Click one to open the whisper box.
  - Professions: **request pop-ups are now opt in**, like the Ask alert. They're off for everyone after updating; the new Request alert card (under a line on the Professions tab) turns them on or off. Settings has the same switch.
- **New Legends tab**: the guild's titles (Lore Master, Crafty Bugger), each with its holder, the top 10, your points and how it's earned. Click a title box on Ask or Professions to get there.
- **New GM tab**, only for the guild master and the managers they name. The guild master can name managers (any rank). Managers can do what officers can (edit the guild info, take down questions, gather for events), get a shield next to their name, and see the tab. The "who can edit" ranks setting moved here from the Info tab.
- Dungeons: when you post a group, your own role counts as at least 1 (a healer's group has at least 1 healer), on the form and in Your group.
- Tabs: Calendar moved before Dungeons; each tab is as wide as its name so they all fit.

## 0.12.0

- **Crafty Bugger**: a new title for whoever makes the most craft requests. You get a point each time a guildie marks their request done with your name on it. The most points over the last 30 days (at least 3) makes you the Crafty Bugger, with a wrench next to your name everywhere in the addon. A new **Crafty Bugger** view on the Professions tab lists the top 10.
  - If only one guildie said "I'll make it", Done names them by itself. If several did, Done first asks who made it: tick them, then Done again.
  - History now shows who actually made each request.
- **Your characters link up by themselves.** The addon knows which characters you've played on your WoW account. Each one tells the guild about the others, and they only count as one person when both characters say so, so nobody can claim someone else's character. Each character joins in the first time it logs in with this version.
  - Answers and requests made on any of your characters count for you, and your Lore Master book and Crafty Bugger wrench show on all of them. Your own alts can't earn you points by answering or making your own requests.
  - Guildies see "Alt of ..." (or your list of alts) in your tooltip.
  - Settings > Your characters: pick your main, see which characters are linked, or untick "Link my characters in this guild" to keep them apart.
- Settings: the memory line moved under the minimap button to make room.

## 0.11.0

- Officers can remove a question, or one guildie's posts on a question, for everyone with the addon. Open the question on the Ask tab: **Remove question** in the sidebar, or the **x** by someone's post. It asks first, and can't be undone.
  - Officers are the ranks that can edit the guild info (the guild master chooses on the Info tab).
  - Removed answers don't count towards the Lore Master, and a removed question's points go too.
  - Someone whose posts were removed can't post on that question again.
  - A removed question still counts towards its asker's 3 open questions until its 48 hours are up.
- Rank markers on the Roster: a gold crown for the guild master, a silver one for the rank under them, and a shield for any other officer rank. A key under the list names your guild's ranks, and the tooltip shows it too.

## 0.10.0

- New **Ask** tab: ask the guild a question ("what level for Deadmines?") and anyone with the addon can answer.
  - Open, Mine and Answered views, topic filters and a search box. Answered questions stay searchable for 30 days, and similar past questions show up while you type a new one.
  - Link an item (drag it from your bags), a quest from your quest log, or a dungeon (shows its level range).
  - A question takes answers for 48 hours. You get a pop-up for each answer and can reply. When it's sorted, click Mark resolved and tick the answers that helped (or none, if you worked it out yourself).
  - The tab has a sidebar: a big Ask a question button, the views with how many are in each, the Lore Master and the alert tick. One Topic button and a search box sit over the cards.
  - Up to 3 open questions each. A new switch in Settings > Pop-ups covers answers to your questions.
  - **Lore Master**: you get a point each time an asker ticks your answer as one that helped. The most points over the last 30 days (at least 3) makes you the Lore Master, with a book next to your name everywhere in the addon. The Lore Master view on the Ask tab lists the top 10.
  - **Alert me when someone asks a question** (tick it at the bottom of the Ask tab; off until you do): a small alert you can drag anywhere shows each new question for 15 seconds. Click it to open the card, right-click to close it. It waits until you're out of combat and out of dungeons, and makes no sound.
  - Home shows how many questions are open (and yours waiting to be marked); click it for the Ask tab. The guild breakdown names the Lore Master.
- Older versions of the addon simply don't see questions; everything else keeps working between versions.
- Catching up at log-in now also notices an old copy of something a guildie changed while you were away (found while testing questions).
- Fixes from a code review before release: guildies whose saved recipes were left out of Professions search at log-in now show up once the roster loads; a craft request finished over a week ago no longer makes guildies' addons keep asking for it; text with accented letters, curly apostrophes or emoji is no longer cut short; the small alert answers the first click after you drag it; a half-typed reply no longer follows you to another question; sim mode keeps everything about fake guildies on your screen.

## 0.9.11

- Professions: when a guildie's recipe list arrives or changes, only their recipes are updated instead of rebuilding the whole guild's list. No more hitch with the Professions tab open in a big guild.

## 0.9.10

- Map: a guildie's card on the world map no longer shows the distance (the minimap card still does).

## 0.9.9

- Guild breakdown: the professions chart now says plainly that it only counts what guildies with the addon have shared (the game doesn't show other players' professions). "Nobody has yet" was misleading and now reads "No addon user has shared yet".

## 0.9.8

- Roster: a search box. Type part of a name to find a guildie, online or offline, whichever filter is picked. Escape clears it.
- Professions: the "Who can make..." list redraws faster in big guilds.

## 0.9.7

- Home: the "Guildies online" box now opens a **Guild breakdown** page with four charts: classes (bars in class colours), levels (your band in gold), professions (guildies with the addon, and crafts nobody has yet) and the guild at a glance (members, addon users, could tank/heal, highest level, ranks).
- Switch between all members, those online now, and those on this week.

## 0.9.6

- Professions: a friendlier "Who can make..." list. Each recipe shows the item's icon, its name in the item's quality colour, and the real item tooltip on hover.
- Recipes are grouped into sections (Bags, Potions and elixirs, Cloth armour, Weapons and shields, Enchants...) that open and close with a click. With nothing searched, you start with just the section list.
- Filter buttons along the top: All, Bags, Armour, Weapons, Potions, Food, Enchants, Other.

## 0.9.5

- Professions: the tab now names any of your crafting professions it hasn't read yet ("Open your Tailoring window once...") in a gold box at the top of the tab, even when guildies' recipes fill the list. Before, the hint only showed while the list was empty.

## 0.9.4

- Fixed: a guildie in another zone or far away could stay stuck on your minimap. Minimap dots now only show guildies who are actually in range.

## 0.9.3

- The guild's own crest in the window banner, the welcome box and the pop-ups; the owl on the minimap button and in the AddOns list.
- Calendar: a Raid roster button, coming soon (raid sign-ups, confirmed and bench, the raid's mix, groups).

## 0.9.2

- For testers: `/ynm dev wipe yes` clears everything the addon has saved and reloads, like a fresh install.

## 0.9.1

- Settings: the Privacy text was cut off; it now shows in full.

## 0.9.0 (first Beta)

First public test version. Map dots, roster, dungeon groups and "I'm available", guild calendar with
Gather, professions with craft requests, guild info and streamers, all shared only within your guild.
Thanks for testing! Please report anything odd in the comments (`/ynm errors` shows any errors).

### Development history before the Beta

- 0.8.10: craft requests: you can type how many you need (1 to 20) as well as using - and +.
- 0.8.9: lighter on memory. In a big guild the addon was throwing away about 6 MB of memory a minute
  (the game sweeps it up, so the memory figure in Settings rose and fell, up to 12 MB in a play test).
  Now about a sixth of that: guild roster updates reuse what they already have, map dots only redraw
  when they move, and the window redraws at most once a second for guildies moving about (clicks are
  still instant).
- 0.8.8: keeping everyone in step, found by a new test that runs six copies of the addon together.
  When you log in, guildies already online catch up on anything you changed while they were away
  (events, craft requests, guild info). Answers to your events given while you were offline now reach
  you. A new craft request is no longer lost when an older one was finished while you were away.
- 0.8.7: fixes from a third full code review. Changes made while you were offline now reach you:
  cancelled or moved events, finished craft requests, changed answers and newer guild info. An
  officer's older guild info can no longer roll back a newer one. A gathering stopped early no
  longer pops up later. Long-running weekly events always get passed on to guildies who log in.
- 0.8.6: Settings shows how much memory Yeah Nah Mate is using (checked when you open it). Ready for
  a whole guild on the addon: when a guildie logs in, everyone tells them where they are directly
  instead of telling the whole guild; when lots of guildies ask for your recipe list at once, it goes
  to the guild once instead of to each of them.
- 0.8.5: Settings has a switch for each kind of pop-up (new groups, sign-ups, craft requests,
  someone making yours, gatherings, guildies going to your events, reminders). The gathering pop-up
  can now be turned off too. If you had pop-ups off, they all stay off.
- 0.8.4: the welcome page (and pop-ups) sit above the main window instead of mixing with it.
- 0.8.3: fixes from a second full code review: cancelled weekly events stay cancelled; copies at login
  are no longer cut off; a gathering reaches guildies who log in before its event does; nobody can
  claim or answer on someone else's behalf, and copies can't overrule the author; moving an event
  keeps its answers; faster Requests list; the "going" pop-up names the right week; "I'm live now"
  after 6 hours works first click.
- 0.8.2: one welcome page on first run (what's shared, Yeah/Nah for your map dot and your
  professions; reopen it from Settings). Faster Professions tab in big guilds. Home's fourth box shows
  open craft requests; the banner says when a newer version is out; tidier footer.
- 0.8.0: gathering. On the day of an event, its organiser (or an officer) clicks Gather: guildies who
  said they're going get a pop-up to ask for an invite, and the organiser's Gather list shows who
  asked, who's going and online, and who's in the group, with Invite, "Invite next" (one per click)
  and "Make it a raid". Everyone who joins is moved onto the organiser's layer by the game. Home and
  the event card show "Gathering now" with an Ask button.
- 0.7.2: a History view on the Professions tab: the last 30 days of finished requests (done and who
  made it, cancelled, or ran out, flagging anyone who said they'd make one that ran out). Filter by a
  name to see that guildie's record, or by an item. "Who can make" is now called "Recipes".
- 0.7.1: easier to say what you need in a request: suggestions from the guild's recipes as you type
  (click one, or Enter for the first), drag an item from your bags onto the box, and a typed name that
  matches a recipe exactly is linked to it.
- 0.7.0: craft requests. Professions has a Requests view: ask the guild for something to be made
  (Request on any recipe, or type it), how many, and a note. Crafters who know the recipe get a
  pop-up and can say "I'll make it" so everyone knows it's taken; mark it Done when you've got it.
- 0.6.4: the window is branded with the guild: a banner across the top with your faction's crest,
  the guild's name big and gold, members / online / with the addon, and you and your rank. "Near my
  level" is a fixed 3 levels (the setting is gone).
- 0.6.3: "Who can edit" is one tidy control (< Officer and above >) so rank names always fit.
- 0.6.2: the Discord invite sits right under the guild message at the top of Home.
- 0.6.1: the guild Discord invite: officers set it with the guild info; everyone can copy it from
  the Info tab and the bottom of Home.
- 0.6.0: guild board. Officers can set a message for the top of everyone's Home tab and write a
  longer Info page (new Info tab); the guild master chooses which ranks may edit. New Streamers tab:
  post your Twitch name, when you stream and what, and mark yourself live; guildies can copy your
  Twitch address. Home shows who's live.
- 0.5.3: tank / healer / DPS counts are three clear rows ("Tanks  -  1  +") in the event form, the
  post-a-group form and "Your group"; "My role" for the leader. Settings has one "Pop-ups and sounds"
  section: pop-ups, reminders and sound switches, a choice of four sounds (with Test), and which of
  the game's volume sliders the sound follows.
- 0.5.2: "Mute answers" can be ticked when making or editing an event.
- 0.5.1: your own Available card has a "Take me off the list" button; long dungeon lists wrap and
  say "+N more" (hover the card for all of them); your own events have a Mute button for the
  "X is going" pop-ups; lists that scroll show "1-2 of 4" with up/down buttons (calendar day,
  open groups, available guildies, recipes).
- 0.5.0 (Phase 5): guild calendar. Make events (title, time, kind, roles for dungeons, note, every
  week), answer Going / Maybe / Can't with your role, see who's coming. A reminder 15 minutes before
  events you're going to (switchable). Home shows what's next up. Times show in your own time zone.
- 0.4.1: fixes from a full code review: the window could eat key presses if opened in combat after
  closing it with Escape; the minimap button's border and glow were missing; recipe lists of offline
  guildies fill in reliably in big guilds and can't be overwritten by a bad copy; fewer messages and
  less work in big guilds.
- 0.4.0 (Phase 4): guild dungeons. Post a group (dungeon, your role, who's needed, note); guildies sign
  up as tank, healer or DPS and you invite them with one click. Mark yourself available (roles,
  dungeons, how long, note) so guildies can whisper or invite you. Pop-ups for new groups at your
  level, for your dungeons, and for sign-ups (switchable, with or without sound). Home shows how many
  groups are open.
- 0.3.1: the window can be closed in combat (X button and Escape); the whisper box and question
  box X buttons fixed the same way.
- 0.3.0 (Phase 3): guild professions. Your recipes are read when you open a profession window and
  shared only if you say yes (asked once; change it in Settings). The Professions tab lists the
  guild's professions and searches "who can make..."; Ask opens a whisper prefilled for the first
  online crafter. Offline guildies' recipes stay searchable.
- 0.2.2: clearer log wording when sharing is switched off.
- 0.2.1: `/ynm log` reads in plain English ("sent my position to the guild", "position OFF"),
  with a clear totals line at the end.
- 0.2.0 (Phase 2): guildmates with the addon as class-coloured dots on the world map and minimap,
  with a tooltip (level, zone, what they're up to, how far away). Your position is only shared if
  you say yes (asked once; change it in Settings), never from inside dungeons. Roster has a Status
  column (in a dungeon, group 3/5, in town, away). Home shows who's near you right now, closest first.
  Settings: share position, show on world map / minimap, dot size. Roster sort resets on /reload.
- 0.1.2: Roster columns sort when you click their titles (click again to reverse, a third time for the
  usual order). Online guildies stay on top. Your choice is remembered.
- 0.1.1: names fixed for Forever ("First Surname"): your own messages are recognised, whispers and
  invites use the plain name, and longer names fit in the Roster and Home lists.
- 0.1.0 (test build, Phase 1): the real window replaces the mock-up. Home and Roster tabs with your
  real guild (filters: online, near my level, in my zone, everyone); who has the addon (a tick, and
  their version); Whisper (our own small box: you press Send) and Invite buttons; minimap button;
  Settings for the "near my level" range and the minimap button. Dungeons, Calendar and Professions
  say what's coming. Test tools: `/ynm log`, `/ynm errors`, `/ynm dev sim on|off`, `/ynm dev probe`.

- 0.0.1: project set up (libraries, offline tests, install script). Nothing usable in game yet;
  the clickable mock-up lives in `mockup/`.
