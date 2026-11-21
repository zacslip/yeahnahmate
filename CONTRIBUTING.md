# Contributing to Yeah Nah Mate

Thanks for helping. This page covers how to set up, the rules every change must keep, and how a
change gets in. How the addon works inside is in [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md).

## Setting up

You need **Python 3.10+** and **git**. No Lua install is needed: the tests run Lua 5.1 through
[lupa](https://pypi.org/project/lupa/).

```
pip install lupa
python tests/run.py              # every test (a minute or two)
python tests/run.py voice board  # only tests whose file name contains one of the words
```

The Tests workflow also runs [luacheck](https://github.com/lunarmodules/luacheck) (settings in
`.luacheckrc`), which catches globals written by mistake and unused or shadowed names. To run it
yourself you need Lua and LuaRocks: `luarocks install luacheck`, then `luacheck YeahNahMate`. If you
don't have them, that's fine: the workflow runs it on your pull request and shows what it found.

To try your change in the game, install from source (this also runs the tests first):

```
python tools/install.py
```

It copies `YeahNahMate/` into WoW Forever's `Interface/AddOns`. It looks for the game's `_forever_`
folder in this order: the `WOW_FOREVER` environment variable, then `tools/wow_path.txt` (one line,
ignored by git), then the Battle.net default `C:\Program Files (x86)\World of Warcraft\_forever_`.
Then `/reload` in game.

A copy installed from source keeps the developer commands (`/ynm dev ...`), which the CurseForge
build leaves out. The most useful one: **`/ynm dev sim on`** adds made-up guildmates who post groups,
events, questions and positions, so most features can be tried alone. `/ynm dev sim off` removes them.
`/ynm log` shows the last addon messages sent and received; `/ynm errors` the last errors.

## The rules

These aren't style preferences. Breaking the first two can get players' accounts in trouble or break
the game's own interface, and pull requests that break them can't be merged.

### Blizzard's rules

From Blizzard's [UI Add-On Development Policy](https://us.forums.blizzard.com/en/wow/t/ui-add-on-development-policy/24534)
and the WoW Terms of Use:

- **No automation.** Every invite, whisper, sign-up, trade or chat line is the player's own click or
  Enter. No auto-accept, no auto-invite, no auto-reply, nothing on a timer that plays the game for
  them. The one deliberate exception is milestone and welcome posts in guild chat, which the guild's
  managers switch on per card (`Milestones.lua`, tagged `[Yeah Nah Mate]`, rate-limited). A welcome is
  posted from an online officer's character; each player can stop the addon posting from theirs
  with the Settings tick "Post milestones & welcomes from my character".
- **No workarounds.** If the game blocks something (protected functions, hardware-event
  requirements, layer detection through GUIDs, secret values), the feature is dropped.
- **Free and readable.** Plain Lua: no obfuscation, no minifying, no encoded blobs, no paid features.
- **No adverts or donation asks in game**, including links to our own pages.
- **Player data stays in the game.** Nothing leaves it except through the game's own guild and whisper
  addon messages, to guildmates. Position and professions are only shared after the player says yes,
  and "off" means nothing is sent.

### WoW Forever's technical rules

Forever is not Classic Era. It has its own client, API and taint rules:

- **Never touch Blizzard's globals or panels**: no `UISpecialFrames`, no `ShowUIPanel` /
  `HideUIPanel`, no hooking or replacing Blizzard functions. A stray write taints Blizzard's own code,
  which then errors on secret values. Templates whose X button calls `HideUIPanel` get
  `UI.PlainClose(frame)`. Escape-to-close is our own `OnKeyDown`.
- **Never open the game's chat box** from addon code (`ChatFrame_OpenChat`, `ChatFrame_SendTell`,
  `ChatFrameUtil`): whatever the player types next runs tainted and `/cast` gets blocked. Whispers
  go through our own box, `UI/Whisper.lua`.
- **Secret values**: read anything the game may hide through `ns.Public(value, type)`.
- **No combat log** (`COMBAT_LOG_EVENT_UNFILTERED` is Blizzard-only on Forever).
- **Addon messages on GUILD and WHISPER only** (custom channels are never delivered), always through
  `Comm.lua`. Everything is throttled; big data goes as `BULK`.
- **No game pop-ups** (`StaticPopup_Show`): they break under Forever's gamepad UI. Use our own frames.
- **Players are "First Surname"** on Forever. Key every player with `ns.Key(name)`.
- **Take game content from Forever's own files**, never from Classic memory: its dungeons, riding
  skills, races and level cap differ (`Dungeons.lua` lists its 35 dungeons).

`tests/test_rules.lua` checks most of these on the source itself, and luacheck catches globals
written by mistake.

### Project rules

- **Mixed versions must never break anyone.** Every message carries the protocol version `v`
  (`ns.PROTOCOL`); unknown types and newer protocols are ignored, not errors. Add new fields rather
  than changing old ones. If a change can't be read by older versions, bump `ns.PROTOCOL` and say so
  in the pull request. Never use the field name `v` for anything else.
- **Trust the game, not the message.** Who sent a message comes from the game. Rights (guild master,
  managers, moderators) are checked by every reader against their own guild roster.
- **Works for any guild.** Nothing hard-codes a guild, realm or player.
- **Light.** Nothing runs every frame unless a window is open.
- **Plain English** in everything the player reads, and every piece of text in `Strings.lua`.
- **Times are server time** (`GetServerTime()`), shown in local time.
- **Lua files use LF line endings.** `.gitattributes` and `.editorconfig` handle it; `test_rules` checks.

## Tests

Every change comes with a test. `tests/wow_stub.lua` is a fake WoW API: a game clock (`Tick(seconds)`),
addon messages with loopback (`INJECT(...)` delivers a message as if a guildie sent it), a fake guild
roster, and frames that record what they show so a test can click through the UI. Look at a test close
to your change and copy its shape. Tests use made-up names only.

`tests/multi.py` runs six real copies of the addon talking through a fake server for a few game hours
(log in and out, events, requests, questions, milestones) and checks everyone ends up agreeing. Any
change to how data is shared between guildmates must keep it passing. `run.py` runs eight short
sessions; `python tests/multi.py 100 360` is the long soak.

## Using AI tools

Most of this addon was written with Claude (Anthropic's AI) in Claude Code, and the maintainer keeps
working that way: commits made with it end with a `Co-Authored-By: Claude` line. Contributions made
with AI tools are welcome on the same terms as any other: you understand the change and can explain
it, it keeps the rules above, it comes with a test, and you tried it. Just say in the pull request
that you used one (there's a tick box for it).

## Making a change

1. Fork the repo and make a branch.
2. Make the change, with a test. Run `python tests/run.py`.
3. Try it in game if it touches the UI or anything the stub can't show.
4. Open a pull request saying what changed, why, and how you checked it. The Tests workflow runs the
   tests and luacheck on it.
5. The maintainer reviews it. `main` only takes changes through reviewed pull requests with passing
   tests.

Releases are tagged `vX.Y.Z` by the maintainer; the Package workflow then builds the zip with the
BigWigs packager and uploads it to CurseForge. Add a line to `CHANGELOG.md` under a heading for the
next version when your change is something players will notice.

## Reporting bugs and ideas

Use the issue templates. For a bug, the About panel's **Copy error report** gives the version, game build, recent errors and
other addons in one block; `/ynm errors` shows the last errors, and the full text is in
`WTF/Account/<account>/SavedVariables/YeahNahMate.lua` (`errors` and `log`) after a `/reload`.
Please remove other players' names before posting.
