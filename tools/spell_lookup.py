"""Show every Classic Era spell with a given name: ID, rank, learn level and skill-line entries.

Usage: python3 tools/spell_lookup.py "Execute" ["Heroic Strike" ...]
"""
import csv
import os
import sys

DB = os.path.join(os.path.dirname(os.path.abspath(__file__)), ".era-api", "db2")


def rows(name):
    with open(os.path.join(DB, name + ".csv"), encoding="utf-8") as fh:
        yield from csv.DictReader(fh)


names = {int(r["ID"]): r["Name_lang"] for r in rows("SpellName")}
sub = {int(r["ID"]): r["NameSubtext_lang"] for r in rows("Spell")}
level = {int(r["SpellID"]): r["BaseLevel"] for r in rows("SpellLevels") if r["DifficultyID"] == "0"}
sla = {}
for r in rows("SkillLineAbility"):
    sla.setdefault(int(r["Spell"]), []).append(
        f"line {r['SkillLine']} mask {r['ClassMask']} acquire {r['AcquireMethod']} supersedes {r['SupercedesSpell']}")

for wanted in sys.argv[1:]:
    print(f"== {wanted}")
    for sid in sorted(i for i, n in names.items() if n == wanted):
        print(f"  {sid:6d}  {sub.get(sid, ''):10s} level {level.get(sid, '-'):>3}  {'; '.join(sla.get(sid, ['(no skill line)']))}")
