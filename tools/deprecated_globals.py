"""List the API globals that Blizzard's deprecation fallbacks define on Classic Era (game type vanilla).

These exist only while the loadDeprecationFallbacks CVar is on (the default).

Usage: python3 tools/deprecated_globals.py <wow-ui-source checkout> > tools/.era-api/Deprecated.txt
"""
import glob
import os
import re
import sys

GAME, FAMILY = "Vanilla", "Classic"
ALLOWED = {"vanilla", "classic"}


def allowed(spec):
    """True if an AllowLoadGameType list (comma separated) admits Classic Era."""
    return not spec or bool(ALLOWED & {s.strip().lower() for s in spec.split(",")})


DEFS = [
    re.compile(r"^\s*([A-Z][A-Za-z0-9_]*)\s*=\s*(?:function\b|[A-Za-z_][\w.]*\s*[;,]?\s*$|[A-Za-z_][\w.]*\s*or\b)", re.M),
    re.compile(r"^\s*function\s+([A-Z][A-Za-z0-9_]*)\s*\(", re.M),
]

names = set()
for toc in glob.glob(os.path.join(sys.argv[1], "Interface", "AddOns", "Blizzard_Deprecated*", "*.toc")):
    text = open(toc, encoding="utf-8", errors="replace").read()
    m = re.search(r"^##\s*AllowLoadGameType:\s*(.+)$", text, re.M)
    if m and not allowed(m.group(1)):
        continue
    base = os.path.dirname(toc)
    for line in text.splitlines():
        line = line.strip()
        if not line or line.startswith("#"):
            continue
        cond = re.search(r"\[AllowLoadGameType\s+([^\]]+)\]", line)
        if cond and not allowed(cond.group(1)):
            continue
        rel = re.sub(r"\s*\[AllowLoadGameType[^\]]*\]", "", line).replace("[Game]", GAME).replace("[Family]", FAMILY)
        path = os.path.join(base, *rel.replace("\\", "/").split("/"))
        if not os.path.exists(path) or not path.endswith(".lua"):
            continue
        src = open(path, encoding="utf-8", errors="replace").read()
        for rx in DEFS:
            names.update(rx.findall(src))

for n in sorted(names):
    print(n)
