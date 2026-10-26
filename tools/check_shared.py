"""Check every ability/aura the engine registered (shared + class) against the Classic Era client tables.

Usage:
    HARNESS_DUMP=/tmp/reg.txt luajit tools/harness.lua Hekili_Vanilla.toc WARRIOR 17/34/0
    python3 tools/check_shared.py /tmp/reg.txt

Lists registered spell IDs and item IDs that don't exist on Era.  Those can't work there: a missing spell has
no name/icon, a missing item is skipped.  Pseudo entries (id <= 0) are ignored.
"""
import csv
import os
import sys

DB = os.path.join(os.path.dirname(os.path.abspath(__file__)), ".era-api", "db2")


def ids(name, col):
    with open(os.path.join(DB, name + ".csv"), encoding="utf-8") as fh:
        return {int(r["ID"]): r[col] for r in csv.DictReader(fh)}


spells = ids("SpellName", "Name_lang")
items = ids("ItemSparse", "Display_lang")

bad_spells, bad_items, ok = [], [], 0
for line in open(sys.argv[1], encoding="utf-8"):
    parts = line.rstrip("\n").split("\t")
    kind, key, item = parts[0], parts[1], parts[3]
    # Alias entries carry another key's name as their id; only numeric IDs are spells.
    sid = int(parts[2]) if parts[2].lstrip("-").isdigit() else 0
    copies = [int(x) for x in parts[4].split() if x.lstrip("-").isdigit()] if len(parts) > 4 else []
    if sid > 0:
        if sid in spells:
            ok += 1
        else:
            bad_spells.append(f"{kind} {key}: spell {sid}")
    for c in copies:
        if c > 0 and c not in spells:
            bad_spells.append(f"{kind} {key}: copy spell {c}")
    if item.isdigit() and int(item) not in items:
        bad_items.append(f"{kind} {key}: item {item}")

print(f"{ok} registered spell IDs exist on Era; {len(bad_spells)} spell and {len(bad_items)} item references don't")
for b in bad_spells:
    print("  missing " + b)
for b in bad_items:
    print("  missing " + b)
