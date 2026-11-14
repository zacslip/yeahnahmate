# Bundled libraries

Copied unchanged from their official sources. Update by copying newer files over these and
running the tests (`python tests/run.py`).

| Library | Version | Source | Licence |
|---|---|---|---|
| LibStub | Ace3 Release-r1403 | https://github.com/WoWUIDev/Ace3 (commit d295b12f) | Public domain |
| CallbackHandler-1.0 | Ace3 Release-r1403 | same | Ace3 licence (BSD-style), see `LICENSE-Ace3.txt` |
| AceComm-3.0 + ChatThrottleLib | Ace3 Release-r1403 | same | Ace3 licence, see `LICENSE-Ace3.txt` (ChatThrottleLib: public domain) |
| AceSerializer-3.0 | Ace3 Release-r1403 | same | Ace3 licence, see `LICENSE-Ace3.txt` |
| HereBeDragons-2.0 + Pins | 2.18-release | https://github.com/Nevcairiel/HereBeDragons (commit 90a7b2d8) | BSD (Copyright Hendrik "Nevcairiel" Leppkes) |

Notes:
- HereBeDragons 2.18 knows WoW Forever by name (`WOW_PROJECT_CAMELOT`).
- ChatThrottleLib adds `hooksecurefunc` post-hooks to the chat send functions to measure traffic.
  That is Blizzard's sanctioned, taint-free way to hook and is accepted under the project rules;
  our own code still never hooks Blizzard functions.
- The Ace3 licence forbids redistributing the libraries *on their own*; embedding them inside an
  addon, as here, is the normal and allowed use.
