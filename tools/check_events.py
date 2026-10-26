"""List events Hekili registers that the Classic Era client doesn't have (registering them errors in-game).

Covers direct RegisterEvent( "X" ) / RegisterUnitEvent( "X" ) calls and lookup tables whose keys are
registered in a loop ( for k in pairs( tbl ) do self:RegisterEvent( k ) ).  Combat log sub-events
(SPELL_DAMAGE, ...) are table keys, not events, and are not checked.

Usage: python3 tools/check_events.py      (run tools/fetch-era-api.sh first)
"""
import glob
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
EVENTS = os.path.join(ROOT, "tools", ".era-api", "Events.lua")

known = set(re.findall(r'"([A-Z][A-Z0-9_]+)"', open(EVENTS, encoding="utf-8").read()))

DIRECT = re.compile(r'Register(?:Unit)?Event\(\s*"([A-Z][A-Z0-9_]+)"')
LOOP = re.compile(r"for\s+(\w+)\s+in\s+pairs\(\s*(\w+)\s*\)\s+do\s*\n\s*[\w:.]*RegisterEvent\(\s*\1\s*\)")

used = {}
files = sorted(glob.glob(os.path.join(ROOT, "*.lua")) + glob.glob(os.path.join(ROOT, "Era", "*.lua")))
for path in files:
    src = open(path, encoding="utf-8").read()
    name = os.path.relpath(path, ROOT)

    for m in DIRECT.finditer(src):
        line = src.count("\n", 0, m.start()) + 1
        used.setdefault(m.group(1), []).append(f"{name}:{line}")

    for loop in LOOP.finditer(src):
        table = loop.group(2)
        t = re.search(r"local\s+%s\s*=\s*\{(.*?)\n\s*\}" % re.escape(table), src, re.S)
        if not t:
            continue
        base = src.count("\n", 0, t.start()) + 1
        for k in re.finditer(r"^\s*([A-Z][A-Z0-9_]+)\s*=", t.group(1), re.M):
            used.setdefault(k.group(1), []).append(f"{name}:{table}@{base}")

bad = {k: v for k, v in used.items() if k not in known}
print(f"{len(known)} Era events; {len(used)} registered by Hekili; {len(bad)} unknown on Era")
for k in sorted(bad):
    print(f"  {k}: {', '.join(sorted(set(bad[k])))}")
sys.exit(1 if bad else 0)
