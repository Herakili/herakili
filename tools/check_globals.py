"""Find global names the addon reads that don't exist on the Classic Era client.

Uses `luac5.1 -l` to list every GETGLOBAL per file and line, then removes names provided by the client
(native API, FrameXML, deprecation fallbacks), the Lua standard library, and globals the addon and its
libraries define themselves.  What's left is either a real problem or guarded (`_G.X or ...`, `if X then`),
so each hit is printed with its source line for review.

Usage: python3 tools/check_globals.py [Herakili_Vanilla.toc]     (run tools/fetch-era-api.sh first)
"""
import os
import re
import subprocess
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
API = os.path.join(ROOT, "tools", ".era-api")
TOC = os.path.join(ROOT, sys.argv[1] if len(sys.argv) > 1 else "Herakili_Vanilla.toc")

LUA_STD = set("""
_G _VERSION assert collectgarbage coroutine debug error gcinfo getfenv getmetatable ipairs load loadstring math
next os pairs pcall print rawequal rawget rawlen rawset require select setfenv setmetatable string table tonumber
tostring type unpack xpcall bit newproxy arg self
""".split())


def names_from(path, pattern):
    if not os.path.exists(path):
        sys.exit(f"missing {path}; run tools/fetch-era-api.sh")
    return set(re.findall(pattern, open(path, encoding="utf-8", errors="replace").read()))


client = set()
client |= {n.split(".")[0] for n in names_from(os.path.join(API, "GlobalAPI.lua"), r'"([\w.:]+)"')}
client |= names_from(os.path.join(API, "FrameXML.txt"), r"(?m)^(\w+)$")
client |= names_from(os.path.join(API, "Deprecated.txt"), r"(?m)^(\w+)$")
client |= {"Enum"}

# Localized UI strings (ACCEPT, ITEM_HEROIC, ...) come from the client's GlobalStrings table.
GLOBALSTRINGS = os.path.join(API, "db2", "GlobalStrings.csv")
if os.path.exists(GLOBALSTRINGS):
    import csv
    with open(GLOBALSTRINGS, encoding="utf-8") as fh:
        client |= {row["BaseTag"] for row in csv.DictReader(fh)}
else:
    print("(no db2/GlobalStrings.csv; localized strings will be reported)")


def toc_files(toc):
    files = []
    base = os.path.dirname(toc)
    for line in open(toc, encoding="utf-8"):
        line = line.strip()
        if line and not line.startswith("#"):
            files.append(os.path.join(base, *line.replace("\\", "/").split("/")))
    return files


def xml_files(xml):
    out = []
    base = os.path.dirname(xml)
    src = re.sub(r"<!--.*?-->", "", open(xml, encoding="utf-8", errors="replace").read(), flags=re.S)
    for kind, f in re.findall(r'<(\w+)\s+file\s*=\s*"([^"]+)"', src):
        p = os.path.join(base, *f.replace("\\", "/").split("/"))
        out += xml_files(p) if kind == "Include" else [p]
    return out


lua_files = []
for f in toc_files(TOC):
    lua_files += xml_files(f) if f.endswith(".xml") else [f]

reads, defined = {}, set()
for path in lua_files:
    out = subprocess.run(["luac5.1", "-l", "-p", path], capture_output=True, text=True)
    if out.returncode:
        print(out.stderr.strip())
        continue
    for line in out.stdout.splitlines():
        m = re.search(r"\[(\d+)\]\s+(GETGLOBAL|SETGLOBAL)\s+.*;\s*(\S+)", line)
        if not m:
            continue
        lineno, op, name = int(m.group(1)), m.group(2), m.group(3)
        if op == "SETGLOBAL":
            defined.add(name)
        else:
            reads.setdefault(name, set()).add((path, lineno))
    # Globals defined through _G[ "Name" ] = ... or frames created with a global name.
    src = open(path, encoding="utf-8", errors="replace").read()
    defined |= set(re.findall(r'_G\[\s*"(\w+)"\s*\]\s*=', src))
    defined |= set(re.findall(r'CreateFrame\(\s*"\w+"\s*,\s*"(\w+)"', src))

addon_files = {p for p in lua_files if "/Libs/" not in p}
missing = {n: locs for n, locs in reads.items() if n not in client and n not in LUA_STD and n not in defined}

cache = {}
def source_line(path, n):
    if path not in cache:
        cache[path] = open(path, encoding="utf-8", errors="replace").read().split("\n")
    return cache[path][n - 1].strip()

print(f"{len(lua_files)} files, {len(reads)} globals read; {len(missing)} not provided by the Era client\n")
for name in sorted(missing):
    locs = sorted(missing[name])
    in_addon = [l for l in locs if l[0] in addon_files]
    tag = "addon" if in_addon else "libs"
    print(f"{name}  [{tag}, {len(locs)} use(s)]")
    for path, n in (in_addon or locs)[:6]:
        print(f"    {os.path.relpath(path, ROOT)}:{n}: {source_line(path, n)[:140]}")
