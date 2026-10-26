"""Print a class's Classic Era talents as Hekili RegisterTalents lines, straight from the client's Talent table.

Usage: python3 tools/era_talents.py [classID]      (1 = Warrior)
"""
import csv
import os
import re
import sys

DB = os.path.join(os.path.dirname(os.path.abspath(__file__)), ".era-api", "db2")
class_id = int(sys.argv[1]) if len(sys.argv) > 1 else 1

with open(os.path.join(DB, "SpellName.csv"), encoding="utf-8") as fh:
    names = {int(r["ID"]): r["Name_lang"] for r in csv.DictReader(fh)}

rows = []
with open(os.path.join(DB, "Talent.csv"), encoding="utf-8") as fh:
    for r in csv.DictReader(fh):
        if int(r["ClassID"] or 0) != class_id:
            continue
        ranks = [int(r[f"SpellRank_{i}"] or 0) for i in range(9)]
        ranks = [x for x in ranks if x]
        if not ranks:
            continue
        key = re.sub(r"[^a-z0-9]+", "_", names.get(ranks[0], "unknown").lower()).strip("_")
        rows.append((int(r["TabID"] or 0), int(r["TierID"] or 0), int(r["ColumnIndex"] or 0), key, int(r["ID"]), ranks))

rows.sort()
width = max(len(r[3]) for r in rows)
tab = None
for tab_id, tier, col, key, tid, ranks in rows:
    if tab_id != tab:
        tab = tab_id
        print(f"    -- Tab {tab_id}")
    print(f"    {key:<{width}} = {{ {tid:5d}, {len(ranks)}, {', '.join(str(x) for x in ranks)} }},  -- tier {tier} col {col}")
