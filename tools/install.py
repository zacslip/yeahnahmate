"""Copy the addon into WoW Forever's AddOns folder, after the offline tests pass.

    python tools/install.py              the addon (YeahNahMate/ and YeahNahMate_Quests/)
    python tools/install.py --no-tests   skip the tests (don't, unless you know why)

Then /reload in game. Only those two folders inside AddOns are ever touched.

A copy newer than the last release (version tag) is stamped with that release (X-Released in the
installed .toc), so it doesn't tell guildies an unreleased version is out. The game reads a .toc at
startup: a changed stamp needs a full restart. The repo's .toc and CurseForge builds have no stamp.

Where WoW Forever is (its _forever_ folder), first that's set:
    the WOW_FOREVER environment variable
    tools/wow_path.txt (one line; not in git, so each PC keeps its own)
    the Battle.net default, C:\\Program Files (x86)\\World of Warcraft\\_forever_
"""
import os
import re
import shutil
import subprocess
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DEFAULT = r"C:\Program Files (x86)\World of Warcraft\_forever_"


def wow_folder():
    if os.environ.get("WOW_FOREVER"):
        return os.environ["WOW_FOREVER"]
    local = os.path.join(ROOT, "tools", "wow_path.txt")
    if os.path.isfile(local):
        with open(local, encoding="utf-8") as f:
            line = f.read().strip()
        if line:
            return line
    return DEFAULT


WOW = wow_folder()
TARGET = os.path.join(WOW, "Interface", "AddOns", "YeahNahMate")


def version_key(version):
    return tuple(int(n) for n in version.split("."))


def last_release():
    """The highest vX.Y.Z tag in this clone, or None."""
    out = subprocess.run(["git", "tag", "--list", "v*"], cwd=ROOT, capture_output=True, text=True).stdout
    versions = [m.group(1) for m in (re.fullmatch(r"v(\d+\.\d+\.\d+)", t.strip()) for t in out.splitlines()) if m]
    return max(versions, key=version_key) if versions else None


def stamped_toc(text, released):
    """The .toc with X-Released added if its version is newer than the last release; else unchanged."""
    m = re.search(r"^## Version: (\d+\.\d+\.\d+)(\r?\n)", text, re.M)
    if not m or version_key(m.group(1)) <= version_key(released):
        return text
    return text[:m.end()] + f"## X-Released: {released}{m.group(2)}" + text[m.end():]


def main():
    args = sys.argv[1:]
    released = last_release()
    if not released:
        sys.exit("No version tags found, so a test copy could announce an unreleased version: not installing.")
    if "--no-tests" not in args:
        r = subprocess.run([sys.executable, os.path.join(ROOT, "tests", "run.py")])
        if r.returncode != 0:
            sys.exit("Tests failed: not installing.")
    addons = os.path.dirname(TARGET)
    if not os.path.isdir(addons):
        sys.exit(f"WoW Forever AddOns folder not found: {addons}\nSet WOW_FOREVER to the _forever_ folder.")
    # Only ever replace our own folders.
    assert os.path.basename(TARGET) == "YeahNahMate" and os.path.basename(addons) == "AddOns"
    for name in ("YeahNahMate", "YeahNahMate_Quests"):
        source, target = os.path.join(ROOT, name), os.path.join(addons, name)
        if os.path.isdir(target):
            shutil.rmtree(target)
        shutil.copytree(source, target)
        count = sum(len(f) for _, _, f in os.walk(target))
        print(f"Installed {name} -> {target} ({count} files). /reload in game.")
    toc = os.path.join(TARGET, "YeahNahMate.toc")
    with open(toc, encoding="utf-8", newline="") as f:
        text = f.read()
    stamped = stamped_toc(text, released)
    if stamped != text:
        with open(toc, "w", encoding="utf-8", newline="") as f:
            f.write(stamped)
        print(f"Test copy: it tells the guild v{released}, the last release. A full game restart applies this.")


if __name__ == "__main__":
    main()
