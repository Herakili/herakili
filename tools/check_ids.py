"""Verify a class module's spell, rank, aura and talent IDs against the Classic Era client tables.

Usage:
    luajit tools/dump_spec.lua Era/Warrior.lua WARRIOR > /tmp/ids.txt
    python3 tools/check_ids.py /tmp/ids.txt [classID]

Needs tools/.era-api/db2/{SpellName,Spell,SkillLineAbility,Talent}.csv (tools/fetch-era-api.sh).
Prints one line per problem and a summary; exit code 1 if anything needs attention.
"""
import csv
import os
import re
import sys

DB = os.path.join(os.path.dirname(os.path.abspath(__file__)), ".era-api", "db2")
dump_path = sys.argv[1]
class_id = int(sys.argv[2]) if len(sys.argv) > 2 else 1
class_mask = 1 << (class_id - 1)


def table(name):
    with open(os.path.join(DB, name + ".csv"), encoding="utf-8") as fh:
        return list(csv.DictReader(fh))


names = {int(r["ID"]): r["Name_lang"] for r in table("SpellName")}
subtext = {int(r["ID"]): r["NameSubtext_lang"] for r in table("Spell")}

# Rank chains from the class's skill line abilities: SupercedesSpell links rank N to rank N-1.
newer, older = {}, {}
for r in table("SkillLineAbility"):
    spell, sup, mask = int(r["Spell"]), int(r["SupercedesSpell"] or 0), int(r["ClassMask"] or 0)
    if sup and (mask == 0 or mask & class_mask):
        newer[sup] = spell
        older[spell] = sup


def chain(spell):
    first = spell
    while first in older:
        first = older[first]
    out = [first]
    while out[-1] in newer:
        out.append(newer[out[-1]])
    return out


talents = {}
for r in table("Talent"):
    if int(r["ClassID"] or 0) != class_id:
        continue
    ranks = [int(r[f"SpellRank_{i}"] or 0) for i in range(9)]
    ranks = [x for x in ranks if x]
    if ranks:
        talents[ranks[0]] = (int(r["ID"]), ranks)


def title(key):
    return " ".join(w.capitalize() for w in key.split("_"))


def norm(name):
    return re.sub(r"[^a-z0-9]", "", name.lower())


problems, notes = [], []
for line in open(dump_path, encoding="utf-8"):
    parts = line.split()
    if not parts:
        continue
    kind, key = parts[0], parts[1]

    if kind == "talent":
        tid, max_rank, ranks = int(parts[2]), int(parts[3]), [int(x) for x in parts[4:]]
        for x in ranks:
            if x not in names:
                problems.append(f"talent {key}: rank spell {x} does not exist")
        if len(ranks) != max_rank:
            problems.append(f"talent {key}: maxRank {max_rank} but {len(ranks)} rank IDs")
        row = talents.get(ranks[0]) if ranks else None
        if not row:
            problems.append(f"talent {key}: no Era talent starts with spell {ranks[0] if ranks else None} ({names.get(ranks[0] if ranks else 0)})")
        else:
            era_id, era_ranks = row
            if era_ranks != ranks:
                problems.append(f"talent {key}: ranks {ranks} but Era has {era_ranks}")
            if norm(names.get(ranks[0], "")) != norm(title(key)):
                notes.append(f"talent {key}: spell name is '{names.get(ranks[0])}'")
            if era_id != tid:
                notes.append(f"talent {key}: talentID {tid} (Era Talent.ID is {era_id}; informational only)")
        continue

    main = int(parts[2])
    copies = [int(x) for x in parts[3:]]
    all_ids = ([main] if main > 0 else []) + [c for c in copies if c != main]

    if main <= 0:
        if copies:
            problems.append(f"{kind} {key}: copies {copies} but no id")
        continue  # pseudo-aura / item ability

    missing = [x for x in all_ids if x not in names]
    for x in missing:
        problems.append(f"{kind} {key}: spell {x} does not exist in Era")
    present = [x for x in all_ids if x in names]
    if not present:
        continue

    distinct = sorted({names[x] for x in present})
    if norm(names[main] if main in names else "") != norm(title(key)):
        notes.append(f"{kind} {key}: id {main} is '{names.get(main)}'")
    if len(distinct) > 1:
        notes.append(f"{kind} {key}: IDs span several names {distinct}")

    if kind == "ability":
        c = chain(main)
        if len(c) > 1:
            if c[-1] != main:
                problems.append(f"ability {key}: id {main} ({subtext.get(main)}) is not the top rank; top is {c[-1]} ({subtext.get(c[-1])})")
            have = set(all_ids)
            lacking = [x for x in c if x not in have]
            extra = [x for x in all_ids if x not in c]
            if lacking:
                problems.append(f"ability {key}: missing ranks {lacking} ({[subtext.get(x) for x in lacking]})")
            if extra:
                notes.append(f"ability {key}: IDs outside the rank chain {extra} ({[names.get(x) for x in extra]})")
    elif kind == "aura":
        # Buffs/debuffs from ranked spells usually share the spell's ID per rank; every rank should be tracked.
        c = chain(main)
        if len(c) > 1:
            lacking = [x for x in c if x not in set(all_ids)]
            if lacking:
                problems.append(f"aura {key}: missing ranks {lacking} ({[subtext.get(x) for x in lacking]})")

print(f"{len(problems)} problem(s), {len(notes)} note(s)")
for p in problems:
    print("PROBLEM " + p)
for n in notes:
    print("note    " + n)
sys.exit(1 if problems else 0)
