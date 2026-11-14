"""Multi-player simulation: several real copies of Yeah Nah Mate talking to each other.

Each player is a separate Lua runtime (tests/wow_stub.lua + the addon), like separate game clients.
This file plays the game server: it routes GUILD addon messages to everyone online and WHISPERs
to their target, keeps every client's clock in step, and logs players out and back in with their
saved data (YeahNahMateDB), the way the game does.

Random players log in and out and make, edit and cancel events, answer them, post and finish craft
requests (say "I'll make it", tick who made it), ask, answer and mark questions (Ask tab) and edit the
guild info. Managers (Ned, the guild master, names Bluey) make, edit, switch and delete milestone
cards and the welcome card (Phase 9); new members join (exactly one welcome must be posted, by
one client) and players level up (only they post their milestone). Bingo and Bandit share one WoW account (one saved file, never online together), so their
characters link up (Alts.lua) and pick mains. A ledger here records each author's own latest version. After
quiet spells it checks what every online client holds against the ledger:

  1. nobody holds a version newer than its author made (no time travel, no corruption);
  2. the same version always means the same content;
  3. while an author is online (and so are you), you have their current version;
  4. at the end everyone logs in and waits: every client must agree with the ledger, and on who's
     who (alt links), the Lore Master and the Crafty Bugger.

Offline only: nothing here touches the game. Run: python tests/multi.py [seeds] [minutes]
"""
import os
import random
import sys

import lupa.lua51 as lupa

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

# name, rank index (0 guild master, 1 officer = guild info editors by default), GUID
PLAYERS = [
    ("Ned Jones", 0), ("Bluey Heeler", 1), ("Chilli Heeler", 1),
    ("Bingo Heeler", 3), ("Bandit Heeler", 3), ("Muffin Heeler", 3),
]
RANK_NAMES = {0: "Guild Master", 1: "Officer", 3: "Member"}
# Characters sharing a WoW account (one saved file): character -> account.
ACCOUNT = {"Bandit Heeler": "Bingo Heeler"}


def account(name):
    return ACCOUNT.get(name, name)
STEP = 1.0          # seconds per world step
SETTLE = 150        # quiet seconds before checking (login asks happen 30-60 s after login)

SAVE_LUA = r"""
function SIM_SAVE(v)
    local t = type(v)
    if t == "string" then return string.format("%q", v) end
    if t == "number" then return string.format("%.17g", v) end
    if t == "boolean" then return tostring(v) end
    if t == "table" then
        local parts = {}
        for k, x in pairs(v) do
            local tx = type(x)
            if tx == "string" or tx == "number" or tx == "boolean" or tx == "table" then
                parts[#parts + 1] = "[" .. SIM_SAVE(k) .. "]=" .. SIM_SAVE(x)
            end
        end
        return "{" .. table.concat(parts, ",") .. "}"
    end
    return "nil"
end
"""


class Client:
    def __init__(self, world, name, saved):
        self.world, self.name = world, name
        self.lua = lupa.LuaRuntime(unpack_returned_tuples=True)
        lua, g = self.lua, self.lua.globals()
        lua.execute('dofile("tests/wow_stub.lua")')
        lua.execute(SAVE_LUA)
        lua.execute("function SIM_LEN(t) return t and #t or 0 end")
        first, last = name.split(" ", 1)
        g.PLAYER_NAME, g.PLAYER_SURNAME, g.PLAYER_FULL = first, last, name
        g.NOW = world.now
        guid = world.guid[name]
        lua.execute('function UnitGUID(u) if u == "player" then return "%s" end end' % guid)
        rank = world.rank[name]
        g.FAKE.myRank, g.FAKE.myRankName = rank, RANK_NAMES[rank]
        self.set_roster()
        if saved:
            lua.execute("YeahNahMateDB = " + saved)
        else:
            g.YeahNahMateDB = None
        self.ns = g.LoadAddon("YeahNahMate", "YeahNahMate")
        g.LOGGED_IN = True
        g.FireEvent("PLAYER_LOGIN")
        s = self.ns.settings
        s.sharePosition, s.shareProfessions = False, False
        self.seen = len(g.SENT)
        self.since = world.now

    def set_roster(self):
        rows = []
        for n, r in PLAYERS:
            online = "true" if n in self.world.online or n == self.name else "false"
            rows.append('{ "%s", "%s", %d, 30, "x", "Durotar", "", "", %s, 0, "WARRIOR", 0, 0, false, false, 3, "%s" }'
                        % (n, RANK_NAMES[r], r, online, self.world.guid[n]))
        self.lua.execute("FAKE.roster = {" + ",".join(rows) + "}")

    def roster_changed(self):
        self.set_roster()
        self.lua.globals().FireEvent("GUILD_ROSTER_UPDATE")

    def tick(self, dt):
        self.lua.globals().Tick(dt, 0.5)

    def outgoing(self):
        sent = self.lua.globals().SENT
        out = []
        n = len(sent)
        for i in range(self.seen + 1, n + 1):
            m = sent[i]
            out.append((m.prefix, m.text, m.channel, m.target))
        self.seen = n
        return out

    def inject(self, prefix, text, channel, sender):
        self.lua.globals().INJECT(prefix, text, channel, sender)

    def logout(self):
        g = self.lua.globals()
        g.FireEvent("PLAYER_LOGOUT")
        return g.SIM_SAVE(g.YeahNahMateDB)

    def errors(self):
        return list(self.lua.globals().ERRORS.values())


class World:
    def __init__(self, seed):
        self.rng = random.Random(seed)
        self.seed = seed
        self.now = 1000.0
        self.epoch = 1762700000
        self.guid = {n: "Player-6797-%08X" % (i + 1) for i, (n, _) in enumerate(PLAYERS)}
        self.rank = dict(PLAYERS)
        self.online = {}          # name -> Client
        self.saved = {}           # name -> saved data (Lua source) while offline
        self.ledger = {}          # ("evt"|"rq", key) -> {v, x, title, at, at_time}; ("ans", key, name) -> {v, a}
        self.info = None          # newest guild info: {ev, motd, by}
        self.ms = {}              # milestone card id -> {v, x, m, n, on, tie}
        self.wel = None           # newest welcome card: {v, m, on, wr, tie}
        self.welcomes = 0         # welcomes posted (each join must give exactly one, when it should)
        self.joins = 0
        self.levelups = 0
        self.fails = []
        self.actions = 0
        self.routed = 0
        self.log = []

    def server_time(self):
        return int(self.epoch + (self.now - 1000))

    # ----- logging in and out
    def login(self, name):
        c = Client(self, name, self.saved.pop(account(name), None))
        self.online[name] = c
        for other in self.online.values():
            if other is not c:
                other.roster_changed()
        self.note("login " + name)

    def logout(self, name):
        self.record_alt(self.online[name])
        c = self.online.pop(name)
        self.saved[account(name)] = c.logout()
        self.check_errors(c)
        for other in self.online.values():
            other.roster_changed()
        self.note("logout " + name)

    # ----- the server
    def step(self):
        self.now += STEP
        for c in list(self.online.values()):
            c.tick(STEP)
        for c in list(self.online.values()):
            for prefix, text, channel, target in c.outgoing():
                self.routed += 1
                if channel == "GUILD":
                    for other in self.online.values():
                        if other is not c:
                            other.inject(prefix, text, "GUILD", c.name)
                elif channel == "WHISPER":
                    other = self.online.get(target)
                    if other is not None and other is not c:
                        other.inject(prefix, text, "WHISPER", c.name)

    def run(self, seconds):
        for _ in range(int(seconds / STEP)):
            self.step()

    def note(self, s):
        self.log.append("%6d s  %s" % (self.now - 1000, s))

    # ----- random actions
    def act(self):
        rng = self.rng
        busy = {account(n) for n in self.online}
        offline = [n for n, _ in PLAYERS if n not in self.online and account(n) not in busy]
        roll = rng.random()
        if (roll < 0.12 and offline) or not self.online:
            self.login(rng.choice(offline))
            return
        if roll < 0.20 and len(self.online) > 1:
            self.logout(rng.choice(sorted(self.online)))
            return
        name = rng.choice(sorted(self.online))
        c = self.online[name]
        ns = c.ns
        st = self.server_time()
        kind = rng.random()
        self.actions += 1
        if rng.random() < 0.3:
            self.act_question(c, name)
            return
        if ns.Board.IsManager(name) and rng.random() < 0.35:
            self.act_milestone(c, name)
            return
        if account(name) != name or name in ACCOUNT.values():
            if rng.random() < 0.08:
                A = ns.Alts
                mine = list(A.MyCharacters().values())
                if rng.random() < 0.2:
                    A.SetLinking(not A.Linking())
                    self.note("%s turns linking %s" % (name, "on" if A.Linking() else "off"))
                elif len(mine) > 1:
                    A.SetMain(rng.choice(mine))
                    self.note("%s picks %s as main" % (name, A.MyMain()))
                self.record_alt(c)
                return
        if kind < 0.12:
            key = ns.Calendar.Save(None, c.lua.table_from({"title": "Ev%d" % self.actions, "at": st + rng.randint(2, 48) * 3600, "k": "s"}))
            if key:
                self.record_event(c, key)
                self.note("%s makes %s" % (name, key))
        elif kind < 0.24:
            mine = self.own_events(c, live=True)
            if mine:
                key = rng.choice(mine)
                e = ns.Calendar.Store()[key]
                ns.Calendar.Save(key, c.lua.table_from({"title": e.title + "+", "at": e.at + 1800, "k": e.k}))
                self.record_event(c, key)
                self.note("%s edits %s" % (name, key))
        elif kind < 0.30:
            mine = self.own_events(c, live=True)
            if mine:
                key = rng.choice(mine)
                ns.Calendar.Cancel(key)
                self.record_event(c, key)
                self.note("%s cancels %s" % (name, key))
        elif kind < 0.44:
            store = ns.Calendar.Store()
            keys = sorted(k for k, e in store.items() if not e.x)
            if keys:
                key = rng.choice(keys)
                e = store[key]
                a = rng.choice(["y", "m", "n"])
                ns.Calendar.Answer(key, e.at, a)
                mine = e.rs[name]
                if mine is not None:
                    self.ledger[("ans", key, name)] = {"v": mine.v, "a": mine.a, "at": e.at, "t": self.now}
                    self.note("%s answers %s %s" % (name, key, a))
        elif kind < 0.62:
            store = ns.Requests.Store()
            others = sorted(k for k, r in store.items() if r.owner != name and not r.x and r.u > st)
            if others:
                key = rng.choice(others)
                ns.Requests.Claim(key, True)
                self.note("%s will make %s" % (name, key))
        elif kind < 0.76:
            key = ns.Requests.Post(None, "Item%d" % self.actions, 1, "")
            if isinstance(key, tuple):          # (nil, "full"): already 5 open
                key = key[0]
            if key:
                self.record_request(c, key)
                self.note("%s posts %s" % (name, key))
        elif kind < 0.92:
            store = ns.Requests.Store()
            mine = sorted(k for k, r in store.items() if r.owner == name and not r.x)
            if mine:
                key = rng.choice(mine)
                how = rng.choice(["done", "done", "cancel"])
                on = list(ns.Requests.Claimers(store[key]).values())
                makers = None
                if how == "done" and len(on) >= 2:
                    makers = c.lua.table_from([n for n in on if rng.random() < 0.6])
                ns.Requests.Finish(key, how, makers)
                self.record_request(c, key)
                self.note("%s finishes %s (%s, made by %s)" % (name, key, how, ",".join(self.makers(store[key]))))
        else:
            if ns.Board.CanEdit():
                motd = "Info %d by %s" % (self.actions, name)
                ok = ns.Board.SetInfo(motd, "", "")
                if ok:
                    info = ns.Board.Store().info
                    self.info = {"ev": info.ev, "motd": info.motd, "by": name, "t": self.now}
                    self.note("%s sets the guild info (v%d)" % (name, info.ev))

    def act_milestone(self, c, name):
        rng, MS = self.rng, c.ns.Milestones
        cards = sorted(card.id for card in MS.List().values())
        roll = rng.random()
        t = c.lua.table_from
        if roll < 0.35 or not cards:
            card = MS.Save(t({"ty": "lvl", "v": rng.randint(2, 60), "m": "M%d {name} {level}" % self.actions,
                              "gc": True, "pu": rng.random() < 0.5, "on": rng.random() < 0.8}))
            if isinstance(card, tuple):
                card = card[0]
            if card:
                self.record_ms(c, card.id)
                self.note("%s makes milestone %s" % (name, card.id))
        elif roll < 0.55:
            cid = rng.choice(cards)
            old = MS.Get(cid)
            card = MS.Save(t({"id": cid, "ty": "lvl", "v": rng.randint(2, 60), "m": old.m + "+", "gc": True, "pu": old.pu, "on": old.on}))
            if isinstance(card, tuple):
                card = card[0]
            if card:
                self.record_ms(c, cid)
                self.note("%s edits milestone %s" % (name, cid))
        elif roll < 0.70:
            cid = rng.choice(cards)
            MS.SetOn(cid, not MS.Get(cid).on)
            self.record_ms(c, cid)
            self.note("%s switches milestone %s" % (name, cid))
        elif roll < 0.82:
            cid = rng.choice(cards)
            MS.Delete(cid)
            self.record_ms(c, cid)
            self.note("%s deletes milestone %s" % (name, cid))
        else:
            ok = MS.SetWelcome(t({"m": "Welcome {name} %d" % self.actions, "on": rng.random() < 0.8, "gc": True, "wr": rng.choice([0, 1])}))
            if ok:
                w = MS.Store().wel
                self.record_slot("wel", None, {"v": w.ev, "m": w.m, "on": bool(w.on), "wr": w.wr})
                self.note("%s sets the welcome (v%d, on=%s, wr=%d)" % (name, w.ev, w.on, w.wr))

    def record_ms(self, c, cid):
        card = c.ns.Milestones.Store().ms[cid]
        if card is not None:
            self.record_slot("ms", cid, {"v": card.ev, "x": bool(card.x), "m": card.m, "n": card.v, "on": bool(card.on)})

    # Milestone cards and the welcome are shared slots (any manager writes): newest wins. Two edits in
    # the same second by different managers are a tie; content isn't compared for a tied version.
    def record_slot(self, kind, cid, truth):
        truth["t"] = self.now
        old = self.ms.get(cid) if kind == "ms" else self.wel
        if old is not None and truth["v"] < old["v"]:
            return
        if old is not None and truth["v"] == old["v"] and {k: old[k] for k in truth if k != "t"} != {k: v for k, v in truth.items() if k != "t"}:
            truth["tie"] = True
        if kind == "ms":
            self.ms[cid] = truth
        else:
            self.wel = truth

    # A new member joins: every online client sees the game's line. After a minute, exactly one
    # welcome must have gone to guild chat (when everyone agrees the card is on and someone of those
    # ranks is online), or none (when it's off).
    def event_join(self):
        self.joins += 1
        newbie = "Newbie%d Person" % self.joins
        marks = {n: len(c.lua.globals().WHISPERS) for n, c in self.online.items()}
        views = set()
        for c in self.online.values():
            w = c.ns.Milestones.Welcome()
            views.add((bool(w.on), w.wr, w.m))
        for c in self.online.values():
            c.lua.globals().FireEvent("CHAT_MSG_SYSTEM", newbie + " has joined the guild.")
        self.run(80)
        posts = []
        for n, c in self.online.items():
            wh = c.lua.globals().WHISPERS
            for i in range(marks.get(n, 0) + 1, len(wh) + 1):
                m = wh[i]
                if m.kind == "GUILD" and m.text.startswith("[Yeah Nah Mate] ") and "Newbie%d" % self.joins in m.text:
                    posts.append(n)
        self.welcomes += len(posts)
        self.note("Newbie%d joins: welcomed by %s" % (self.joins, ",".join(posts) or "nobody"))
        if len(views) != 1:
            return                                   # clients disagree about the card (not settled)
        on, wr, _ = next(iter(views))
        eligible = [n for n in self.online if self.rank[n] <= wr]
        if on and eligible and len(posts) != 1:
            self.fail("Newbie%d: %d welcomes posted (%s), want exactly 1" % (self.joins, len(posts), ",".join(posts)))
        if (not on or not eligible) and posts:
            self.fail("Newbie%d: welcome posted by %s while it's off or nobody of rank <= %d is on" % (self.joins, ",".join(posts), wr))

    # Someone levels up to a card's level: only they post, at most once per card.
    def event_level(self):
        name = self.rng.choice(sorted(self.online))
        c = self.online[name]
        cards = [card for card in c.ns.Milestones.List().values() if card.on and card.ty == "lvl" and card.gc]
        if not cards:
            return
        card = self.rng.choice(cards)
        marks = {n: len(o.lua.globals().WHISPERS) for n, o in self.online.items()}
        ch = c.ns.db.chars[name]
        done = ch is not None and ch.msDone is not None and ch.msDone[card.id] is not None
        recent = 0
        if ch is not None and ch.msPosts is not None:
            recent = sum(1 for t in ch.msPosts.values() if self.server_time() - t < 3600)
        others = sum(1 for o in c.ns.Milestones.List().values() if o.on and o.ty == "lvl" and o.gc and o.v == card.v and o.id != card.id)
        c.lua.globals().FireEvent("PLAYER_LEVEL_UP", card.v)
        self.run(5)
        self.levelups += 1
        for n, o in self.online.items():
            wh = o.lua.globals().WHISPERS
            mine = [wh[i].text for i in range(marks[n] + 1, len(wh) + 1)
                    if wh[i].kind == "GUILD" and wh[i].text.startswith("[Yeah Nah Mate] M")]
            if n != name and mine:
                self.fail("%s posted a milestone when %s levelled up: %s" % (n, name, mine[0]))
            if n == name and len(mine) > 1 + others:
                self.fail("%s posted %d lines for one level-up" % (name, len(mine)))
            if n == name and not done and recent + others < 3 and not mine:
                self.fail("%s reached level %d (card %s) but posted nothing" % (name, card.v, card.id))
            if n == name and done and others == 0 and mine:
                self.fail("%s posted card %s again" % (name, card.id))

    def act_question(self, c, name):
        rng, ns, Q = self.rng, c.ns, c.ns.Questions
        g = c.lua.globals()
        store = Q.Store()
        live = sorted(k for k, q in store.items() if not q.stub and Q.Live(q))
        if self.rank[name] <= 1 and rng.random() < 0.25:
            self.act_remove(c, name)
            return
        r = rng.random()
        if r < 0.3:
            key = Q.Ask("Question %d from %s" % (self.actions, name), rng.choice(["dungeons", "quests", "other"]))
            if isinstance(key, tuple):          # (nil, "full" / "wait")
                key = key[0]
            if key:
                self.record_question(c, key)
                self.note("%s asks %s" % (name, key))
        elif r < 0.7:
            if live:
                key = rng.choice(live)
                ok = Q.Post(key, "Answer %d from %s" % (self.actions, name))
                if isinstance(ok, tuple):
                    ok = ok[0]
                if ok:
                    self.record_posts(c, key)
                    self.note("%s posts on %s" % (name, key))
        elif r < 0.8:
            mine = sorted(k for k in live if store[k].posts[name] is not None and g.SIM_LEN(store[k].posts[name].p) > 0)
            if mine:
                key = rng.choice(mine)
                Q.DeletePost(key, 1)
                self.record_posts(c, key)
                self.note("%s takes back a post on %s" % (name, key))
        elif r < 0.95:
            mine = [k for k in live if store[k].owner == name]
            if mine:
                key = rng.choice(mine)
                names = [n for n in Q.Answerers(store[key]).values()]
                helpers = [n for n in names if rng.random() < 0.6]
                Q.Finish(key, c.lua.table_from(helpers))
                self.record_question(c, key)
                self.note("%s marks %s answered (%s)" % (name, key, ",".join(helpers)))
        else:
            mine = [k for k in live if store[k].owner == name]
            if mine:
                key = rng.choice(mine)
                Q.Cancel(key)
                self.record_question(c, key)
                self.note("%s takes down %s" % (name, key))

    def act_remove(self, c, name):
        """An officer removes someone's question, or one guildie's posts on it."""
        rng, Q = self.rng, c.ns.Questions
        store = Q.Store()
        keys = sorted(k for k, q in store.items() if not q.stub and q.owner != name and Q.RemovedBy(q) is None)
        if not keys:
            return
        key = rng.choice(keys)
        poster = None
        if rng.random() < 0.6:
            names = [n for n in Q.Answerers(store[key]).values() if n != name]
            if not names:
                return
            poster = rng.choice(names)
        if not Q.Remove(key, poster):
            return
        rk = key + ("|" + poster if poster else "")
        r = Q.Removed()[rk]
        old = self.ledger.get(("rm", rk))
        if not old or r.ev < old["v"] or (r.ev == old["v"] and name < old["by"]):
            self.ledger[("rm", rk)] = {"v": r.ev, "by": name, "t": self.now, "owner": name}
        self.note("%s (officer) removes %s" % (name, rk))

    def record_question(self, c, key):
        q = c.ns.Questions.Store()[key]
        hp = sorted(q.hp.keys()) if q.hp else []
        self.ledger[("q", key)] = {"v": q.ev, "x": q.x, "tx": q.tx, "hp": hp, "t": self.now, "owner": c.name}

    def record_posts(self, c, key):
        q = c.ns.Questions.Store()[key]
        e = q.posts[c.name]
        self.ledger[("qa", key, c.name)] = {"v": e.pv, "n": c.lua.globals().SIM_LEN(e.p), "t": self.now,
                                            "owner": q.owner}

    def own_events(self, c, live):
        return sorted(k for k, e in c.ns.Calendar.Store().items()
                      if e.owner == c.name and (not live or not e.x))

    def record_event(self, c, key):
        e = c.ns.Calendar.Store()[key]
        self.ledger[("evt", key)] = {"v": e.v, "x": bool(e.x), "title": e.title, "at": e.at, "t": self.now,
                                    "owner": c.name}

    def makers(self, r):
        return sorted(r.mk.keys()) if r.mk else []

    def record_request(self, c, key):
        r = c.ns.Requests.Store()[key]
        self.ledger[("rq", key)] = {"v": r.ev, "x": r.x, "t": self.now, "owner": c.name, "mk": self.makers(r)}

    def record_alt(self, c):
        r = c.ns.Alts.Store()[c.name]
        if r is not None:
            self.ledger[("alt", c.name)] = {"v": r.ev, "al": sorted(r.al.keys()), "mn": r.mn, "owner": c.name}

    # ----- checks
    def fail(self, msg):
        self.fails.append("seed %d, %d s: %s" % (self.seed, self.now - 1000, msg))

    def check_errors(self, c):
        for e in c.errors():
            self.fail("%s: Lua error: %s" % (c.name, e))
        c.lua.globals().ERRORS = c.lua.table()

    def check(self, final=False):
        for c in self.online.values():
            self.record_alt(c)
        for c in self.online.values():
            self.check_errors(c)
            settled = self.now - c.since >= SETTLE
            cal = c.ns.Calendar.Store()
            rqs = c.ns.Requests.Store()
            qs = c.ns.Questions.Store()
            for lk, truth in self.ledger.items():
                if lk[0] == "evt":
                    key = lk[1]
                    owner = truth["owner"]
                    if owner == c.name:
                        continue
                    e = cal[key]
                    author_on = owner in self.online and self.now - self.online[owner].since >= SETTLE
                    if e is None:
                        if (final or (author_on and settled)) and not truth["x"]:
                            self.fail("%s doesn't have %s's event %s (v%d)" % (c.name, owner, key, truth["v"]))
                        continue
                    if e.v > truth["v"]:
                        self.fail("%s holds %s v%d, newer than its author's v%d" % (c.name, key, e.v, truth["v"]))
                    elif e.v == truth["v"]:
                        if bool(e.x) != truth["x"] or (not truth["x"] and (e.title != truth["title"] or e.at != truth["at"])):
                            self.fail("%s: %s v%d differs from its author's (x=%s title=%s)" % (c.name, key, e.v, e.x, e.title))
                    elif final or (author_on and settled):
                        self.fail("%s has %s v%d, its author %s has v%d%s" % (
                            c.name, key, e.v, owner, truth["v"], " (cancelled)" if truth["x"] else ""))
                elif lk[0] == "ans":
                    key, who = lk[1], lk[2]
                    if who == c.name:
                        continue
                    e = cal[key]
                    if e is None or e.rs is None or e.x or self.ledger.get(("evt", key), {}).get("x"):
                        continue                      # answers to a cancelled event don't matter
                    a = e.rs[who]
                    if a is None:
                        continue
                    if a.v > truth["v"]:
                        self.fail("%s holds %s's answer to %s v%d, newer than theirs v%d" % (c.name, who, key, a.v, truth["v"]))
                    elif a.v == truth["v"] and a.a != truth["a"]:
                        self.fail("%s: %s's answer to %s v%d is %s, theirs is %s" % (c.name, who, key, a.v, a.a, truth["a"]))
                    elif a.v < truth["v"]:
                        owner = self.ledger.get(("evt", key), {}).get("owner")
                        both_on = (who in self.online and owner in self.online
                                   and self.now - self.online[who].since >= SETTLE)
                        if c.name == owner and both_on:
                            self.fail("%s (the event's owner) has %s's old answer v%d, theirs is v%d" % (c.name, who, a.v, truth["v"]))
                elif lk[0] == "rq":
                    key = lk[1]
                    owner = truth["owner"]
                    if owner == c.name:
                        continue
                    r = rqs[key]
                    author_on = owner in self.online and self.now - self.online[owner].since >= SETTLE
                    if r is None:
                        if author_on and settled and not truth["x"]:
                            self.fail("%s doesn't have %s's open request %s" % (c.name, owner, key))
                        continue
                    if r.ev > truth["v"]:
                        self.fail("%s holds request %s v%d, newer than its author's v%d" % (c.name, key, r.ev, truth["v"]))
                    elif r.ev == truth["v"]:
                        if (r.x or None) != (truth["x"] or None) or self.makers(r) != truth["mk"]:
                            self.fail("%s: request %s v%d is %s made by %s, its author's is %s made by %s" % (
                                c.name, key, r.ev, r.x, self.makers(r), truth["x"], truth["mk"]))
                    elif final or (author_on and settled):
                        self.fail("%s has request %s v%d, its author has v%d (%s)" % (c.name, key, r.ev, truth["v"], truth["x"]))
                elif lk[0] == "alt":
                    who = lk[1]
                    if account(who) == account(c.name):
                        continue                      # the same saved file: always the same
                    a = c.ns.Alts.Store()[who]
                    author_on = who in self.online and self.now - self.online[who].since >= SETTLE
                    if a is None:
                        if final or (author_on and settled):
                            self.fail("%s doesn't have %s's alt links v%d" % (c.name, who, truth["v"]))
                    elif a.ev > truth["v"]:
                        self.fail("%s holds %s's alt links v%d, newer than theirs v%d" % (c.name, who, a.ev, truth["v"]))
                    elif a.ev == truth["v"]:
                        if sorted(a.al.keys()) != truth["al"] or a.mn != truth["mn"]:
                            self.fail("%s: %s's alt links v%d differ" % (c.name, who, a.ev))
                    elif final or (author_on and settled):
                        self.fail("%s has %s's alt links v%d, theirs is v%d" % (c.name, who, a.ev, truth["v"]))
                elif lk[0] == "rm":
                    rk, by = lk[1], truth["by"]
                    r = c.ns.Questions.Removed()[rk]
                    by_on = by in self.online and self.now - self.online[by].since >= SETTLE
                    if r is None:
                        if c.name != by and (final or (by_on and settled)):
                            self.fail("%s doesn't know %s removed %s" % (c.name, by, rk))
                        elif c.name == by:
                            self.fail("%s lost their own removal %s" % (c.name, rk))
                    elif r.ev > truth["v"] and (final or (by_on and settled)):
                        self.fail("%s holds removal %s v%d by %s, the first was v%d by %s" % (c.name, rk, r.ev, r.by, truth["v"], by))
                    elif r.ev < truth["v"]:
                        self.fail("%s holds removal %s v%d, earlier than any made (v%d)" % (c.name, rk, r.ev, truth["v"]))
                    elif r.ev == truth["v"] and r.by != by:
                        self.fail("%s: removal %s v%d is by %s, made by %s" % (c.name, rk, r.ev, r.by, by))
                elif lk[0] == "q":
                    key = lk[1]
                    owner = truth["owner"]
                    if owner == c.name or ("rm", key) in self.ledger:
                        continue
                    q = qs[key]
                    author_on = owner in self.online and self.now - self.online[owner].since >= SETTLE
                    if q is None or q.stub:
                        if (final or (author_on and settled)) and not truth["x"]:
                            self.fail("%s doesn't have %s's question %s" % (c.name, owner, key))
                        continue
                    if q.ev > truth["v"]:
                        self.fail("%s holds question %s v%d, newer than its author's v%d" % (c.name, key, q.ev, truth["v"]))
                    elif q.ev == truth["v"]:
                        hp = sorted(q.hp.keys()) if q.hp else []
                        if (q.x or None) != (truth["x"] or None) or q.tx != truth["tx"] or hp != truth["hp"]:
                            self.fail("%s: question %s v%d is x=%s hp=%s, its author's x=%s hp=%s" % (
                                c.name, key, q.ev, q.x, hp, truth["x"], truth["hp"]))
                    elif final or (author_on and settled):
                        self.fail("%s has question %s v%d, its author has v%d (%s)" % (c.name, key, q.ev, truth["v"], truth["x"]))
                elif lk[0] == "qa":
                    key, who = lk[1], lk[2]
                    if who == c.name or ("rm", key) in self.ledger or ("rm", key + "|" + who) in self.ledger:
                        continue
                    q = qs[key]
                    if q is None or q.posts is None:
                        continue
                    e = q.posts[who]
                    qtruth = self.ledger.get(("q", key), {})
                    still_live = not qtruth.get("x") and not q.stub and c.ns.Questions.Live(q)
                    if e is None:
                        if final and still_live and truth["n"] > 0:
                            self.fail("%s doesn't have %s's posts on live question %s" % (c.name, who, key))
                        continue
                    n = c.lua.globals().SIM_LEN(e.p)
                    if e.pv > truth["v"]:
                        self.fail("%s holds %s's posts on %s v%d, newer than theirs v%d" % (c.name, who, key, e.pv, truth["v"]))
                    elif e.pv == truth["v"] and n != truth["n"]:
                        self.fail("%s: %s's posts on %s v%d are %d, theirs %d" % (c.name, who, key, e.pv, n, truth["n"]))
                    elif e.pv < truth["v"] and final and still_live:
                        self.fail("%s has %s's posts on live %s v%d, theirs v%d" % (c.name, who, key, e.pv, truth["v"]))
            # Milestone cards and the welcome (shared slots): never newer than written, the same version
            # means the same card, and in the end everyone holds the newest.
            held = c.ns.Milestones.Store().ms
            for cid, truth in self.ms.items():
                card = held[cid]
                if card is None:
                    if final:
                        self.fail("%s doesn't have milestone card %s (v%d)" % (c.name, cid, truth["v"]))
                    continue
                if card.ev > truth["v"]:
                    self.fail("%s holds milestone %s v%d, newer than written (v%d)" % (c.name, cid, card.ev, truth["v"]))
                elif card.ev == truth["v"] and not truth.get("tie"):
                    got = (bool(card.x), card.m if not card.x else truth["m"], card.v if not card.x else truth["n"], bool(card.on) if not card.x else truth["on"])
                    want = (truth["x"], truth["m"], truth["n"], truth["on"])
                    if got != want:
                        self.fail("%s: milestone %s v%d is %s, written as %s" % (c.name, cid, card.ev, got, want))
                elif card.ev < truth["v"] and final:
                    self.fail("%s has milestone %s v%d, newest is v%d" % (c.name, cid, card.ev, truth["v"]))
            if self.wel:
                w = c.ns.Milestones.Store().wel
                if w is None:
                    if final:
                        self.fail("%s has no welcome card; newest is v%d" % (c.name, self.wel["v"]))
                elif w.ev > self.wel["v"]:
                    self.fail("%s's welcome v%d is newer than written (v%d)" % (c.name, w.ev, self.wel["v"]))
                elif w.ev == self.wel["v"] and not self.wel.get("tie") and (w.m, bool(w.on), w.wr) != (self.wel["m"], self.wel["on"], self.wel["wr"]):
                    self.fail("%s's welcome v%d differs" % (c.name, w.ev))
                elif w.ev < self.wel["v"] and final:
                    self.fail("%s's welcome is v%d, newest is v%d" % (c.name, w.ev, self.wel["v"]))
            # Guild info: the newest edit wins.
            if self.info:
                info = c.ns.Board.Store().info
                by_on = self.info["by"] in self.online and self.now - self.online[self.info["by"]].since >= SETTLE
                if info is None:
                    if final or (by_on and settled):
                        self.fail("%s has no guild info; newest is v%d by %s" % (c.name, self.info["ev"], self.info["by"]))
                elif info.ev > self.info["ev"]:
                    self.fail("%s's guild info v%d is newer than anyone wrote (v%d)" % (c.name, info.ev, self.info["ev"]))
                elif info.ev == self.info["ev"] and info.motd != self.info["motd"]:
                    self.fail("%s's guild info v%d says %r, written as %r" % (c.name, info.ev, info.motd, self.info["motd"]))
                elif info.ev < self.info["ev"] and (final or (by_on and settled)):
                    self.fail("%s's guild info is v%d (%r); newest is v%d by %s" % (
                        c.name, info.ev, info.motd, self.info["ev"], self.info["by"]))


def simulate(seed, minutes):
    w = World(seed)
    for name in ("Ned Jones", "Bluey Heeler", "Bingo Heeler"):
        w.login(name)
    w.run(SETTLE)
    zac = w.online["Ned Jones"]
    zac.ns.Board.SetManager("Bluey Heeler", True)       # the guild master names a manager
    zac.ns.Milestones.SetWelcome(zac.lua.table_from({"m": "Welcome {name} 0", "on": True, "gc": True, "wr": 1}))
    wel = zac.ns.Milestones.Store().wel
    w.record_slot("wel", None, {"v": wel.ev, "m": wel.m, "on": True, "wr": 1})
    w.run(10)
    end = minutes * 60
    while w.now - 1000 < end:
        w.act()
        w.run(w.rng.randint(5, 90))
        if w.rng.random() < 0.15:
            w.run(SETTLE)
            w.check()
            if w.rng.random() < 0.5:
                w.event_join()
            else:
                w.event_level()
    # Finally everyone logs in and waits; then they must all agree.
    for name, _ in PLAYERS:
        if name not in w.online and account(name) not in {account(n) for n in w.online}:   # one character per account
            w.login(name)
            w.run(20)
    w.run(SETTLE * 2)
    # A shared account's other characters can't be online with it: each takes a turn (so what they
    # wrote while nobody was around gets out, as it would when they next log in), then the first is back.
    for name, _ in PLAYERS:
        if name not in w.online:
            sibling = next(n for n in list(w.online) if account(n) == account(name))
            w.logout(sibling)
            w.login(name)
            w.run(SETTLE * 2)
            w.logout(name)
            w.login(sibling)
            w.run(SETTLE * 2)
    w.check(final=True)
    w.event_join()
    w.event_level()
    w.cards = len(w.ms)
    # Everyone names the same people: who's whose alt, the Lore Master, the Crafty Bugger.
    views = {}
    for c in w.online.values():
        A = c.ns.Alts
        views[c.name] = (tuple(A.Person(n) for n, _ in PLAYERS), c.ns.Questions.LoreMaster(), c.ns.Requests.CraftyBugger(),
                         tuple(c.ns.Requests.Points(n) for n, _ in PLAYERS), tuple(c.ns.Questions.Points(n) for n, _ in PLAYERS))
    if len(set(views.values())) > 1:
        for n, v in sorted(views.items()):
            w.fail("final views differ: %s sees people %s, Lore Master %s, Crafty Bugger %s, made %s, helped %s" % (n, v[0], v[1], v[2], v[3], v[4]))
    one = next(iter(views.values()))
    w.linked = one[0][[n for n, _ in PLAYERS].index("Bandit Heeler")] == one[0][[n for n, _ in PLAYERS].index("Bingo Heeler")]
    w.crafty = one[2]
    # How much the clients actually hold of each other's (proves messages really flowed).
    w.held = 0
    for c in w.online.values():
        for k, e in c.ns.Calendar.Store().items():
            if e.owner != c.name:
                w.held += 1
    w.events = sum(1 for k in w.ledger if k[0] == "evt")
    w.questions = sum(1 for k in w.ledger if k[0] == "q")
    w.posts = sum(1 for k in w.ledger if k[0] == "qa")
    w.removals = sum(1 for k in w.ledger if k[0] == "rm")
    w.made = sum(1 for k, t in w.ledger.items() if k[0] == "rq" and t.get("mk"))
    w.qheld = 0
    for c in w.online.values():
        for k, q in c.ns.Questions.Store().items():
            if q.owner != c.name and not q.stub:
                w.qheld += 1
    return w


def main():
    os.chdir(ROOT)
    seeds = int(sys.argv[1]) if len(sys.argv) > 1 else 6
    minutes = int(sys.argv[2]) if len(sys.argv) > 2 else 120
    total = 0
    for seed in range(1, seeds + 1):
        w = simulate(seed, minutes)
        print("  %s seed %d: %d actions, %d events by %d players, %d messages sent, %d copies of others' events held, %d questions (%d posters' threads, %d copies held, %d officer removals), %d requests with makers (Crafty Bugger %s), Bingo+Bandit %s, %d milestone cards, %d joins -> %d welcomes, %d level-ups, %d checks failed" % (
            "PASS" if not w.fails else "FAIL", seed, w.actions, w.events, len(PLAYERS), w.routed, w.held,
            w.questions, w.posts, w.qheld, w.removals, w.made, w.crafty or "nobody", "linked" if w.linked else "apart", w.cards, w.joins, w.welcomes, w.levelups, len(w.fails)))
        for f in w.fails[:8]:
            print("      " + f)
        if w.fails:
            print("      last actions:")
            for line in w.log[-12:]:
                print("        " + line)
        total += len(w.fails)
    return total


if __name__ == "__main__":
    sys.exit(1 if main() else 0)
