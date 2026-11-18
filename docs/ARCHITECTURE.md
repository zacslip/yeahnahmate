# How Yeah Nah Mate works

A guild addon for WoW Forever. Everything is shared only between guildmates who run it, through the
game's own addon messages. There is no server: each player's addon keeps its own copy of the guild's
shared things and passes copies on to guildmates who log in later.

## Files

Load order is the `.toc`. Each feature is one module (logic) plus one UI file.

| File | What it does |
|---|---|
| `Strings.lua` | Every piece of text the player reads (`ns.L`). |
| `Core.lua` | Namespace, saved data and defaults, our own events (`ns.Listen` / `ns.Fire`), game events (`ns.OnEvent`), the error catcher (`ns.Safe`), the message log, names (`ns.Key`), version rules (`ns.Newer`, `ns.Future`), slash commands. |
| `Guild.lua` | Reads the game's guild roster. Fires `ROSTER`. |
| `Comm.lua` | The only file that sends or receives addon messages. `HI` (who has the addon). |
| `Sync.lua` | Catching up on changes an author made while you were online but missed. |
| `Alts.lua` | Linking one player's characters (both characters must say so). |
| `Roster.lua`, `Status.lua` | The roster tab's data; level, zone and what a guildie is doing (`ST`). |
| `Map.lua` | Guildies' dots on the world map and minimap (`POS`, HereBeDragons). |
| `Professions.lua`, `Data/RecipeItems.lua` | Everyone's recipes and the guild's search index (`PROF`, `IDX`). |
| `Requests.lua` | Craft requests and the Crafty Bugger title (`RQ`, `CL`, `RQX`). |
| `Questions.lua` | Ask the Guild and the Lore Master title (`QQ`, `QA`, `QM`). |
| `Dungeons.lua` | Group posts, sign-ups and "I'm available" (`GRP`, `SIGN`, `ANS`, `AVL`, `DMX`). |
| `Calendar.lua`, `Gather.lua` | Guild events and answers (`EVT`, `RSVP`, `EVR`, `EVM`); gathering for an event (`GTH`, `GAK`). |
| `Board.lua` | Guild info, managers, which ranks moderate each tab, streamer cards (`BRD`). |
| `Milestones.lua` | Milestone and welcome cards (`BRD` kinds `ms`, `wel`), posting them (`MSF`, `MSW`). |
| `Voice.lua` | Proximity voice: guildies' voice volume by distance, on Blizzard's voice chat (`VGRP`). |
| `Breakdown.lua` | The guild breakdown page's numbers. |
| `Bindings.xml` | The key binding for proximity voice on/off (Options > Keybindings > AddOns). |
| `Sim.lua`, `Probe.lua`, `VoiceProbe.lua` | Developer tools (`/ynm dev ...`), left out of the CurseForge build. |
| `UI/*.lua` | The window, one file per tab, the minimap button, pop-ups (`Toast`), the whisper box. |
| `libs/` | Third-party libraries, unchanged (`libs/LIBRARIES.md`). |

Modules talk through `ns` (`ns.Calendar`, `ns.Board`, ...) and internal events: a module changes its
data, fires an event (`CALENDAR`, `BOARD`, `DUNGEONS`, ...), and the UI redraws on it.

## Messages

Prefix `YNM`. Each message is a small table, serialised with AceSerializer and sent with AceComm,
which splits long ones into pieces and throttles everything through ChatThrottleLib:

```lua
{ v = ns.PROTOCOL, t = "EVT", ... }
```

`v` is the protocol version on every message (never reuse the name). `t` is the type. Receivers drop
unknown types, newer protocols, oversized or unreadable messages, and whispers from anyone not on
their guild roster, without errors. Each module's header lists its message types and fields.

`REQ { w = ... }` asks one guildie by whisper for something big: `CAL` events, `RQS` requests, `QS`
questions, `BRD` the board, `ALT` alt links, `IDX` / `PROF` / `PROFS` recipe lists, `SYNC` catch-up.

## Sharing without a server

Each guildie's addon holds a copy of the shared things per guild (`YeahNahMateDB.guilds[<guild>]`).

- **Authors.** Everything shared has an author: the player whose addon sent it (the game says who).
  Only the author changes or ends it, except where a moderator may (below).
- **Versions.** Everything carries a version: the server time it last changed. `ns.Newer` decides
  whether a message replaces what we hold: the author's own message always wins over a copy, and
  otherwise the newer version wins. `ns.Future` refuses versions from the future (an author's own get
  10 minutes of slack, copies one minute).
- **Logging in.** A guildie who logs in says `HI` to the guild. Others whisper back their own things
  (and a hello). Over the next minute the newcomer asks one random online guildie for each kind of
  data (recipe lists, events, the board, alt links, requests, questions; not always the same
  guildie) for copies of everything they hold (`REQ`), so things whose authors are offline still arrive. Copies are only accepted by whisper,
  from a guildie we asked in the last few minutes.
- **Catching up (`Sync.lua`).** The log-in `HI` carries, for each kind, the newest version, how many
  changed in the last 30 days and a checksum of those versions. Anyone already online who is behind
  asks the author for them. From three askers up, the author sends once to the guild instead of
  whispering each.
- **Tidying.** Things end (groups after 2 hours, events a week after they're over, requests after 3
  days); finished things are kept a while for history; departed guildies' things go after a full
  roster read.

## Rights

The guild master, managers (named by the guild master or a manager) and each tab's moderator ranks
(ticked on the GM tab) can edit or remove other people's things on their tab. Every reader checks
the sender against **their own** copy of the guild roster and the board, never against anything the
message claims. A moderator's removal is final; their edit beats the author's older copy.

### Known limit: relayed copies

Copies passed on by another guildie name their author in the message (`o = author`), and the reader
can't prove the author really wrote it: there's no signing. The rights check still runs against the
claimed author, but a deliberately modified addon could relay a made-up copy in someone else's name.
For the guild-wide settings (guild info, managers, moderator ranks), where the newest version wins
whoever wrote it, it could hand out a fake managers list to the guildies who ask it for copies.

What limits it: copies are only taken by whisper from a guildie we asked (one random online guildie
per kind of data at log-in), a copy can't run more than a minute ahead of the clock, and the next real change by the
guild master or a manager replaces it for everyone. It takes someone in the guild running a modified
addon on purpose. Fixing it properly would need signed messages, which WoW's addon API doesn't make
practical.

### Known limit: new event fields and older versions

Fields added later (an important event's reminders, `im` and `an`) are unknown to older versions,
which leave them out of the copies they pass on. A field missing from a message therefore means
"keep what I have", never "switched off" (an updated owner always sends it, `0` / `false` when off).
Older versions don't show important pop-ups at all.

### Known limit: weekly events and daylight saving

A weekly event happens every 7 x 24 hours after its first start, so every guildie's addon agrees on
the exact moment of each week (answers are matched to that moment). Where clocks change for
daylight saving, it shows an hour earlier or later in local time until they change back. Keeping it
at the same local time instead would make players in different time zones disagree on the moment.

## Saved data

`YeahNahMateDB` (per account): `settings`, `window`, `chars` (per character: my group, my
availability, my recipes, milestones done), `guilds[<guild name>]` (everything shared), `errors` and
`log` (the last 50 errors and 300 message log lines, for bug reports), `voice` (volumes to put back).
Positions are never saved.

## Testing

See [CONTRIBUTING.md](../CONTRIBUTING.md#tests). `tests/wow_stub.lua` is the fake game; `tests/run.py`
runs each `tests/test_*.lua` in a fresh Lua; `tests/multi.py` runs several copies of the addon
against each other.
