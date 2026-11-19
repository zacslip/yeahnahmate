"""Stop private names going into this public repo: a maintainer's own name, guildies' names.

    python tools/check_private.py staged          the lines a commit adds (pre-commit hook)
    python tools/check_private.py message FILE    a commit message (commit-msg hook)
    python tools/check_private.py all             every tracked file as it is now

What counts as private comes from outside this repo, so the list itself is never published:
    private/private_words.txt   one word or name per line (# comments); matched as whole words, any case
    WoW's SavedVariables        every guildie's "First Surname" on the guild roster the addon saved
                                (found through tools/wow_path.txt or WOW_FOREVER), matched exactly

With neither there (a contributor's clone, the GitHub runner), nothing is checked. Exit 1 on a hit.
To install the hooks in a clone that has private/: python private/install_hooks.py
"""
import glob
import os
import re
import subprocess
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(ROOT, "tools"))


def words():
    out = []
    path = os.path.join(ROOT, "private", "private_words.txt")
    if os.path.isfile(path):
        with open(path, encoding="utf-8") as f:
            for line in f:
                line = line.split("#", 1)[0].strip()
                if line:
                    out.append(re.compile(r"(?<![A-Za-z0-9])" + re.escape(line) + r"(?![A-Za-z0-9])", re.I))
    return out


def guildies():
    """Full names from the saved data: every two-word key like ["First Surname"] in it (guildies show
    up as keys across many tables). A two-word key that isn't a name would also be refused: add it to
    ALLOWED below."""
    try:
        import install
        wow = install.wow_folder()
    except Exception:
        return set()
    names = set()
    for f in glob.glob(os.path.join(wow, "WTF", "Account", "*", "SavedVariables", "YeahNahMate.lua")):
        try:
            text = open(f, encoding="utf-8", errors="replace").read()
        except OSError:
            continue
        for m in re.finditer(r'\["([A-Z][\w\'-]+ [A-Z][\w\'-]+)"\]', text):
            names.add(m.group(1))
    return names


# Fake guildies used in tests and sim mode are made up on purpose: never a hit.
ALLOWED = {"Ned Jones", "Bluey Heeler", "Bingo Heeler", "Chilli Heeler", "Bandit Heeler", "Bazza Stubbs"}


BINARY = {".png", ".tga", ".blp", ".jpg", ".jpeg", ".gif", ".ogg", ".mp3", ".ttf", ".zip"}


def hits(text, pats, names):
    found = []
    for p in pats:
        m = p.search(text)
        if m:
            found.append(m.group(0))
    for n in names:
        if n not in ALLOWED and n in text:
            found.append(n)
    return found


def staged_added():
    diff = subprocess.run(["git", "diff", "--cached", "-U0", "--no-color"], cwd=ROOT,
                          capture_output=True, text=True, encoding="utf-8", errors="replace").stdout
    out, current = [], None
    for line in diff.splitlines():
        if line.startswith("+++ "):
            current = line[6:] if line.startswith("+++ b/") else line[4:]
        elif line.startswith("+") and not line.startswith("+++"):
            out.append((current, line[1:]))
    return out


def main():
    mode = sys.argv[1] if len(sys.argv) > 1 else "staged"
    pats, names = words(), guildies()
    if not pats and not names:
        return 0
    bad = []
    if mode == "message":
        with open(sys.argv[2], encoding="utf-8", errors="replace") as f:
            for i, line in enumerate(f, 1):
                if line.startswith("#"):
                    continue
                for h in hits(line, pats, names):
                    bad.append(f"commit message line {i}: {h}")
    elif mode == "all":
        files = subprocess.run(["git", "ls-files"], cwd=ROOT, capture_output=True, text=True).stdout.split()
        for path in files:
            if os.path.splitext(path)[1].lower() in BINARY:
                continue
            try:
                text = open(os.path.join(ROOT, path), encoding="utf-8", errors="replace").read()
            except (OSError, IsADirectoryError):
                continue
            for i, line in enumerate(text.splitlines(), 1):
                for h in hits(line, pats, names):
                    bad.append(f"{path}:{i}: {h}")
    else:
        for path, line in staged_added():
            if path and os.path.splitext(path)[1].lower() in BINARY:
                continue
            for h in hits(line, pats, names):
                bad.append(f"{path}: {h}  ->  {line.strip()[:100]}")
    if bad:
        print("Private name found; not committed (tools/check_private.py):")
        for b in bad[:30]:
            print("  " + b)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
