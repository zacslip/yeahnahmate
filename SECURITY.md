# Security

Yeah Nah Mate runs inside World of Warcraft and only talks to guildmates through the game's own addon
messages. The kind of problem worth reporting privately is one that lets someone else's addon do
something to yours, for example:

- a message that makes other guildies' addons throw errors, freeze, or use lots of memory
- a way for a guildie to change things that should be theirs alone (someone else's event, request or
  question) or that only the guild master and managers may change
- anything that makes the addon send chat, invites or anything else without the player's own click

Please report these privately, not as a public issue: use **Report a vulnerability** on the repository's
Security tab (GitHub's private reporting). Say what happens and how to make it happen; a test in the
style of `tests/` is ideal but not needed.

Known limits that are documented rather than fixed are listed in
[docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) (for example, relayed copies can't be proven to come from
their author).

Bugs that aren't security problems go in the normal issues.
