"""Copy the addon into WoW Forever's AddOns folder, after the offline tests pass.

    python tools/install.py              the addon (YeahNahMate/ and YeahNahMate_Quests/)
    python tools/install.py --no-tests   skip the tests (don't, unless you know why)

Then /reload in game. Only those two folders inside AddOns are ever touched.

Where WoW Forever is (its _forever_ folder), first that's set:
    the WOW_FOREVER environment variable
    tools/wow_path.txt (one line; not in git, so each PC keeps its own)
    the Battle.net default, C:\\Program Files (x86)\\World of Warcraft\\_forever_
"""
import os
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


def main():
    args = sys.argv[1:]
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


if __name__ == "__main__":
    main()
