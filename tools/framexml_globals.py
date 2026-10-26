"""List the global names defined by Blizzard's FrameXML Lua (top-level assignments and functions).

Usage: python3 tools/framexml_globals.py <wow-ui-source checkout> > tools/.era-api/FrameXML.txt
"""
import os
import re
import sys

ASSIGN = re.compile(r"^([A-Za-z_][A-Za-z0-9_]*)\s*=(?!=)")
FUNC = re.compile(r"^function\s+([A-Za-z_][A-Za-z0-9_]*)\s*[\(\.:]")

names = set()
for root, _, files in os.walk(sys.argv[1]):
    for f in files:
        if not f.endswith(".lua"):
            continue
        with open(os.path.join(root, f), encoding="utf-8", errors="replace") as fh:
            for line in fh:
                m = ASSIGN.match(line) or FUNC.match(line)
                if m:
                    names.add(m.group(1))

for n in sorted(names):
    print(n)
