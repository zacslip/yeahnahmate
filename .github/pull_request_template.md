**What this changes, and why**


**How I checked it**
- [ ] `python tests/run.py` passes, with a test for this change
- [ ] Tried in game (say what), or it doesn't touch anything the tests can't show

**Rules** (CONTRIBUTING.md)
- [ ] No automation: anything sent is the player's own click or Enter
- [ ] No Blizzard globals, panel functions, game chat box or game pop-ups
- [ ] Older versions of the addon still work alongside this one (new fields only, or `ns.PROTOCOL` bumped and explained)
- [ ] Player-facing text is in `Strings.lua`; a line in `CHANGELOG.md` if players will notice
