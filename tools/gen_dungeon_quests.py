"""Builds YeahNahMate_Quests/DungeonQuests.lua from an installed copy of Questie and QuestieDB.
It only reads the game's AddOns folder.

    python tools/gen_dungeon_quests.py <AddOns folder> YeahNahMate_Quests/DungeonQuests.lua <review.txt>

Keeps each quest's id, name, levels, who can do it, who starts it, where, and what comes before it.
The review file lists the result by dungeon, for checking by eye.

Works with data from Questie by the Questie contributors. Licensed under the GNU General Public License,
version 3, unlike the rest of this repository: see YeahNahMate_Quests/gpl-3.0.md and NOTICE.md."""
import base64, collections, os, re, struct, sys

ADDONS, OUT, REVIEW = sys.argv[1:4]
TOC = os.path.join(ADDONS, "QuestieDB", "QuestieDB_Forever.toc")


def cbor(b, i=0):
    ib = b[i]; i += 1
    mt, ai = ib >> 5, ib & 31
    if mt == 7:
        if ai == 20: return False, i
        if ai == 21: return True, i
        if ai in (22, 23): return None, i
        if ai == 25:
            h = struct.unpack(">H", b[i:i+2])[0]; s = -1 if h >> 15 else 1; e = (h >> 10) & 31; f = h & 1023
            return s * (f / 1024 * 2 ** -14 if e == 0 else (1 + f / 1024) * 2 ** (e - 15)), i + 2
        if ai == 26: return struct.unpack(">f", b[i:i+4])[0], i + 4
        if ai == 27: return struct.unpack(">d", b[i:i+8])[0], i + 8
        raise ValueError(ai)
    if ai < 24: n = ai
    else:
        size = {24: 1, 25: 2, 26: 4, 27: 8}[ai]
        n = int.from_bytes(b[i:i+size], "big"); i += size
    if mt == 0: return n, i
    if mt == 1: return -1 - n, i
    if mt in (2, 3): return b[i:i+n].decode("utf-8", "replace"), i + n
    if mt == 4:
        out = []
        for _ in range(n):
            v, i = cbor(b, i); out.append(v)
        return out, i
    if mt == 5:
        out = {}
        for _ in range(n):
            k, i = cbor(b, i); v, i = cbor(b, i); out[k] = v
        return out, i
    return cbor(b, i)


store = {}
with open(TOC, encoding="utf-8", errors="replace") as f:
    for l in f:
        if l.startswith(("## X-Quest-", "## X-Npc-", "## X-Object-", "## X-Item-")):
            k, _, v = l[3:].rstrip("\r\n").partition(":")
            store[k] = v.strip()


def dec(key):
    v = store.get(key)
    if v is None: return None
    m = re.fullmatch(r"~(\d+)~", v)
    if m: v = "".join(store[f"{key}-{n}"] for n in range(1, int(m.group(1)) + 1))
    return cbor(base64.b64decode(v))[0]


def row(kind, i):
    r = dec(f"X-{kind}-{i}-S") or {}
    return {n + 1: v for n, v in enumerate(r)} if isinstance(r, list) else r


def tbl(kind, i, field): return dec(f"X-{kind}-{i}-{field}")


def seq(t):
    if isinstance(t, list): return t
    if isinstance(t, dict): return [t[k] for k in sorted(k for k in t if isinstance(k, int))]
    return []


def at(t, i):
    if isinstance(t, list): return t[i - 1] if len(t) >= i else None
    if isinstance(t, dict): return t.get(i)
    return None


# Dungeon groups: wings of one place share their quests.
GROUPS = {
    "rfc": [2437], "hot": [16919], "rol": [16611], "wc": [718], "dm": [1581, 10029],
    "sfk": [209, 10014, 10015, 10016, 10017, 10018, 10019], "bfd": [719, 10020, 10021], "stocks": [717],
    "exc": [16732, 16877, 16878, 16879, 16880], "dal": [16544, 16558, 16559, 16560, 16562],
    "gnomer": [721, 133, 10030, 10031, 10032], "rfk": [491, 1717], "scarlet": [796, 6109, 6386, 10008, 10009, 10010],
    "drown": [], "rfd": [722], "krol": [17780], "ulda": [1337, 1517, 10033], "zf": [1176, 978], "mara": [2100, 10000],
    "alcaz": [2079], "st": [1477, 1417], "brd": [1584, 1585], "spire": [1583, 10003, 10004, 10005, 10006, 10007],
    "diremaul": [2557, 10022, 10023, 10024, 10025, 10026, 10027], "blackmaw": [], "scholo": [2057, 10011, 10012, 10013],
    "strat": [2017, 10001], "shaper": [16985],
}
Z2G = {z: g for g, zs in GROUPS.items() for z in zs}
# The new dungeons' bosses have no spawn data, so quests are linked to them by name.
NEW_BOSSES = {
    "drown": ["Zul'Alai", "Var'Taka", "Captain Dreadrise", "Deathless Marrow", "Min'loth the Serpent", "Primeval Elemental", "Gill"],
    "krol": ["Slavecrusher Grox", "Twilight Commander Zarmok", "War Handler Ashka", "Nar'gurk", "Bossman Toof", "Overlord Mugg", "Kroog"],
    "alcaz": ["Overseer Wrex", "Tidemistress Ca'zass", "Katerina the Cleaner", "The Questioner", "Blazeroar"],
    "blackmaw": ["Withermaw", "Impaan the Imprisoner", "Bonesnout the Unbroken", "Varrox Bleakhoof", "Elder Shaman Bloodmane", "Blackmaw Behemoth", "Unbound Spirit", "Moontouched Wanderer", "Gortek the Apprentice", "Tunnelweb Matriarch"],
    "shaper": ["Titanosaur", "Venomridge", "Thunderhoof", "Direhorn Matriarch", "Cinder", "Bolt", "Snowtalon", "Vitrix", "Izha'Rel", "Tor'Rel", "Nanaya"],
}
NAME2G = {n: g for g, ns_ in NEW_BOSSES.items() for n in ns_}
# Level range of each group: quests far outside it only share a zone or a drop with the dungeon.
LEVELS = {"rfc": (13, 18), "hot": (13, 20), "rol": (15, 22), "wc": (15, 24), "dm": (17, 26), "sfk": (20, 30),
          "bfd": (24, 32), "stocks": (24, 32), "exc": (26, 33), "dal": (28, 35), "gnomer": (29, 38), "rfk": (29, 38),
          "scarlet": (30, 46), "drown": (35, 42), "rfd": (37, 46), "krol": (40, 47), "ulda": (41, 51), "zf": (44, 54),
          "mara": (46, 55), "alcaz": (48, 55), "st": (50, 60), "brd": (52, 60), "spire": (55, 60), "diremaul": (54, 60),
          "blackmaw": (55, 60), "scholo": (58, 60), "strat": (58, 60), "shaper": (58, 60)}
# Crafting and tier turn-ins that only need something a dungeon happens to drop.
NOT_DUNGEON_QUESTS = {"An Earnest Proposition", "Just Compensation", "Anthion's Parting Words", "Saving the Best for Last",
                      "Wild Leather Shoulders", "Breastplate of the Chromatic Flight", "Legplates of the Chromatic Defier",
                      "Snakestone of the Shadow Huntress"}

text = open(os.path.join(ADDONS, "QuestieDB", "support", "Forever", "Zones", "areaIdToUiMapId.lua"), encoding="utf-8").read()
UIMAP = {}
for a, u in re.findall(r"\[(\d+)\]\s*=\s*(\d+)", text):
    UIMAP.setdefault(int(a), int(u))

home, names = {}, {}
for k in list(store):
    m = re.fullmatch(r"X-Npc-(\d+)-S", k)
    if not m: continue
    n = int(m.group(1))
    r = row("Npc", n)
    names[n] = r.get(1)
    sp = tbl("Npc", n, 7)
    zones = [z for z in sp if isinstance(z, int)] if isinstance(sp, dict) else []
    gs = {Z2G.get(z) for z in zones}
    if zones and len(gs) == 1 and None not in gs: home[n] = gs.pop()
    elif not zones and r.get(1) in NAME2G: home[n] = NAME2G[r[1]]

black = open(os.path.join(ADDONS, "Questie", "Database", "Corrections", "QuestieQuestBlacklist.lua"), encoding="utf-8").read().split("if Questie.IsSoD then")[0]
BLACK = {int(x) for x in re.findall(r"^\s*\[(\d+)\]\s*=\s*true", black, re.M)}
A_MASK, H_MASK = 77 | (1 << 32), 178 | (1 << 33)


def only(ids):
    got = {home.get(i) for i in ids}
    return got.pop() if ids and len(got) == 1 and None not in got else None


def spot(kind, i):
    sp = tbl(kind, i, 7 if kind == "Npc" else 4)
    if not isinstance(sp, dict): return None
    for z in sorted(k for k in sp if isinstance(k, int)):
        if z in Z2G or not UIMAP.get(z): continue
        pts = seq(sp[z])
        p = seq(pts[0]) if pts else []
        if len(p) >= 2 and isinstance(p[0], (int, float)) and p[0] > 0:
            return UIMAP[z], round(p[0], 1), round(p[1], 1)
    return None


def starter(q):
    st = tbl("Quest", q, 2)
    for kind, field in (("Npc", 1), ("Object", 2)):
        ids = seq(at(st, field))
        for i in ids:
            s = spot(kind, i)
            if s: return (row(kind, i).get(1), *s)
        if ids: return (row(kind, ids[0]).get(1), None, None, None)
    items = seq(at(st, 3))
    if items: return (row("Item", items[0]).get(1), None, None, None)
    return (None, None, None, None)


out = collections.defaultdict(list)
for k in list(store):
    m = re.fullmatch(r"X-Quest-(\d+)-S", k)
    if not m: continue
    q = int(m.group(1))
    if q in BLACK: continue
    r = row("Quest", q)
    lvl, zone, races, cls, special = r.get(5) or 0, r.get(17) or 0, r.get(6) or 0, r.get(7) or 0, r.get(24) or 0
    if not 1 <= lvl <= 60 or special & 1: continue
    g, how = Z2G.get(zone), "zone"
    ob = tbl("Quest", q, 10)
    if not g:
        how = "objective"
        for e in seq(at(ob, 1)):
            g = g or home.get(seq(e)[0] if seq(e) else None)
        if not g:
            for e in seq(at(ob, 3)):
                item = seq(e)[0] if seq(e) else None
                if item and not g: g = only(seq(tbl("Item", item, 2)))
    if not g: continue
    lo, hi = LEVELS[g]
    if r.get(1) in NOT_DUNGEON_QUESTS or lvl < lo - 8 or lvl > hi + 3: continue
    a, h = races == 0 or bool(races & A_MASK), races == 0 or bool(races & H_MASK)
    if not a and not h: continue
    side = "B" if a and h else "A" if a else "H"
    whole = {"B": A_MASK | H_MASK, "A": A_MASK, "H": H_MASK}[side]
    only_races = [] if races == 0 or races & whole == whole else [b + 1 for b in range(40) if races >> b & 1]
    giver, ui, x, y = starter(q)
    out[g].append(dict(id=q, name=r.get(1), lvl=lvl, req=r.get(4) or 0, side=side, cls=cls, races=only_races,
                       giver=giver, ui=ui, x=x, y=y, how=how,
                       pre=seq(tbl("Quest", q, 12)) + seq(tbl("Quest", q, 13))))


def lua(s): return '"' + str(s).replace("\\", "\\\\").replace('"', '\\"') + '"'


with open(OUT, "w", encoding="utf-8", newline="\n") as f, open(REVIEW, "w", encoding="utf-8") as rv:
    f.write("-- Yeah Nah Mate Quests: dungeon quest data for Yeah Nah Mate's leveling guide.\n")
    f.write("-- Adapted from Questie and QuestieDB by the Questie contributors. Licensed under GPLv3: see gpl-3.0.md and NOTICE.md.\n")
    f.write("--\n-- QUESTS, the quests of each dungeon: { id, name, level, required level, side (A, H, B), class mask,\n")
    f.write("--   races (or false), who starts it, map id, x, y }. No map position: it starts inside the dungeon or from an item.\n")
    f.write("YeahNahMateQuestData = {}\nlocal D = YeahNahMateQuestData\n\nD.QUESTS = {\n")
    variants, earlier = collections.defaultdict(list), set()
    for g in GROUPS:
        seen, rows = {}, []
        named = collections.defaultdict(set)
        for q in out[g]: named[q["name"]].add(q["id"])
        for q in out[g]:
            earlier.update(p for p in q["pre"] if p in named[q["name"]] and p != q["id"])
        for q in sorted(out[g], key=lambda e: (e["lvl"], e["name"], e["id"])):
            key = (q["name"], q["side"], tuple(q["races"]), q["cls"])
            if key in seen:
                if q["id"] not in variants[seen[key]]: variants[seen[key]].append(q["id"])
                continue
            seen[key] = q["id"]; rows.append(q)
        rv.write(f"\n== {g}: A {sum(q['side'] != 'H' for q in rows)}, H {sum(q['side'] != 'A' for q in rows)}\n")
        f.write(f"    {g} = {{\n")
        for q in rows:
            rv.write(f"{q['lvl']:>2} {q['side']} {'C' if q['cls'] else ' '}{'R' if q['races'] else ' '} {q['how'][0]} {q['name']} <- {q['giver']} {'' if q['ui'] else '(no map)'}\n")
            races = "{" + ",".join(map(str, q["races"])) + "}" if q["races"] else "false"
            where = f"{q['ui']},{q['x']},{q['y']}" if q["ui"] else "false"
            f.write(f"        {{{q['id']},{lua(q['name'])},{q['lvl']},{q['req']},\"{q['side']}\",{q['cls']},{races},{lua(q['giver'] or '')},{where}}},\n")
        f.write("    },\n")
    f.write("}\n\n-- Other ids of the same quest name: another version, or another step with that name.\n")
    f.write("D.VARIANTS = {\n")
    for k in sorted(variants):
        if variants[k]: f.write(f"    [{k}] = {{{','.join(map(str, sorted(variants[k])))}}},\n")
    f.write("}\n\n-- Ids that are an earlier step of a quest with the same name: finishing one isn't finishing the quest.\n")
    f.write("D.EARLIER = {\n")
    for k in sorted(earlier): f.write(f"    [{k}] = true,\n")
    f.write("}\n")

    # Every quest on the way to a listed one, outdoor lead-ins included.
    steps, negative = {}, 0


    def add_step(i):
        global negative
        if i in steps or i in BLACK or f"X-Quest-{i}-S" not in store: return
        steps[i] = None             # guards against a loop in the data
        r = row("Quest", i)
        races = r.get(6) or 0
        a, h = races == 0 or bool(races & A_MASK), races == 0 or bool(races & H_MASK)
        if not a and not h: a = h = True
        side = "B" if a and h else "A" if a else "H"
        whole = {"B": A_MASK | H_MASK, "A": A_MASK, "H": H_MASK}[side]
        only_races = [] if races == 0 or races & whole == whole else [b + 1 for b in range(40) if races >> b & 1]
        need_all, need_any = seq(tbl("Quest", i, 12)), seq(tbl("Quest", i, 13))
        negative += sum(p < 0 for p in need_all + need_any)
        need_all, need_any = [p for p in need_all if p > 0], [p for p in need_any if p > 0]
        giver, ui, x, y = starter(i)
        for p in need_all + need_any: add_step(p)
        steps[i] = dict(name=r.get(1), lvl=r.get(5) or 0, side=side, cls=r.get(7) or 0, races=only_races, giver=giver,
                        ui=ui, x=x, y=y, all=need_all, any=need_any, alt=[p for p in seq(tbl("Quest", i, 16)) if p > 0])


    sys.setrecursionlimit(5000)
    for g in GROUPS:
        for q in out[g]: add_step(q["id"])


    def ids(v):
        kept = [p for p in v if steps.get(p)]
        return "{" + ",".join(map(str, kept)) + "}" if kept else "false"


    f.write("\n-- Each quest on the way to a listed one: { name, level, side, class mask, races, who starts it, map id, x, y,\n")
    f.write("--   needs all of these first, needs one of these first, doing one of these counts as doing this }.\n")
    f.write("D.STEPS = {\n")
    for i in sorted(k for k, v in steps.items() if v):
        s = steps[i]
        races = "{" + ",".join(map(str, s["races"])) + "}" if s["races"] else "false"
        where = f"{s['ui']},{s['x']},{s['y']}" if s["ui"] else "false,false,false"
        alt = "{" + ",".join(map(str, s["alt"])) + "}" if s["alt"] else "false"
        f.write(f"    [{i}] = {{{lua(s['name'])},{s['lvl']},\"{s['side']}\",{s['cls']},{races},{lua(s['giver'] or '')},{where},{ids(s['all'])},{ids(s['any'])},{alt}}},\n")
    f.write("}\n")
    print("chain steps", sum(1 for v in steps.values() if v), "negative prerequisites skipped", negative)
print("done", sum(len(v) for v in out.values()), "rows before de-dupe")
