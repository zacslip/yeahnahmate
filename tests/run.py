"""Run every tests/test_*.lua in its own fresh Lua 5.1 (through lupa), with tests/wow_stub.lua loaded.

    python tests/run.py            all tests
    python tests/run.py libs ui    only tests whose name contains one of the words

Exit code 0 when everything passes. No `lua` binary is needed.
"""
import glob
import os
import sys

try:
    import lupa.lua51 as lupa
except ImportError:
    sys.exit("lupa with Lua 5.1 is needed: pip install lupa")

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))


def run(path):
    lua = lupa.LuaRuntime(unpack_returned_tuples=True)
    try:
        # LIST_LUA(dir): every .lua under dir (recursive), repo-relative with forward slashes. Works on
        # Windows and on the GitHub runner (io.popen isn't available there).
        def list_lua(d):
            found = sorted(glob.glob(os.path.join(d, "**", "*.lua"), recursive=True))
            return lua.table_from([f.replace("\\", "/") for f in found])
        lua.globals().LIST_LUA = list_lua
        lua.execute('dofile("tests/wow_stub.lua")')
        lua.execute('dofile(...)', path.replace("\\", "/"))
        return int(lua.globals().FAILS or 0), None
    except Exception as e:  # a Lua error is a failure of that test file
        return 1, str(e)


def main():
    os.chdir(ROOT)
    words = sys.argv[1:]
    files = sorted(glob.glob("tests/test_*.lua"))
    if words:
        files = [f for f in files if any(w in os.path.basename(f) for w in words)]
    total = 0
    for f in files:
        print(f"== {os.path.basename(f)}", flush=True)
        fails, err = run(f)
        if err:
            print(f"  ERROR {err}", flush=True)
        total += fails
    # Several real copies of the addon talking to each other (tests/multi.py).
    if not words or "multi" in words:
        print("== multi.py (6 players, 8 runs of 2 game hours each)", flush=True)
        sys.path.insert(0, os.path.join(ROOT, "tests"))
        import multi
        sys.argv = [sys.argv[0], "8", "120"]
        total += multi.main()
    print("\nALL PASS" if total == 0 else f"\n{total} FAILED")
    sys.exit(0 if total == 0 else 1)


if __name__ == "__main__":
    main()
