#!/usr/bin/env bash
# Run every offline check for the Classic Era flavor.
# Needs tools/fetch-libs.sh and tools/fetch-era-api.sh first, and LIBS pointing at LibDeflate/ + Ace3/ checkouts
# for the pack check (see tools/packtool.lua).
#
#   tools/test.sh            all checks and scenarios
#   tools/test.sh quick      skip the leveling runs
#
# HARNESS_SAVEDVARS=<path to WTF/.../SavedVariables/Hekili.lua> additionally runs from that saved profile.
set -uo pipefail
cd "$(dirname "$0")/.."

fail=0
TMP="${TMPDIR:-/tmp}"
step() { printf '\n== %s\n' "$1"; }

step "Lua syntax (Lua 5.1, as in the client)"
n=0
while read -r f; do
    luac5.1 -p "$f" || fail=1
    n=$((n + 1))
done < <(grep -v '^#' Hekili_Vanilla.toc | grep '\.lua' | tr '\\' '/' | tr -d '\r')
echo "checked $n files"

step "Priority lists reference only defined abilities, auras, talents and settings"
python3 -I tools/check_apl.py Era/Warrior.lua Era/APLs/WarriorFury.simc Era/APLs/WarriorArms.simc || fail=1

step "Spell, rank, aura and talent IDs match the Era client tables"
luajit tools/dump_spec.lua Era/Warrior.lua WARRIOR > "$TMP/hekili-era-ids.txt" && \
    python3 -I tools/check_ids.py "$TMP/hekili-era-ids.txt" 1 || fail=1

step "Registered events exist on Era"
# Expected in this list: Chromie Time events (only registered on retail) and LEARNED_SPELL_IN_TAB (dropped at
# runtime by ns.IsEventValid before the display frames register their event tables).
python3 -I tools/check_events.py | grep -v -E "CHROMIE_TIME|LEARNED_SPELL_IN_TAB"

step "Built-in packs match their .simc sources"
for pack in Fury:WarriorFury Arms:WarriorArms; do
    name=${pack%%:*}
    simc=Era/APLs/${pack##*:}.simc
    if [ -z "${LIBS:-}" ]; then echo "skipped (set LIBS)"; break; fi
    LIBS="$LIBS" lua5.1 tools/packtool.lua decode Era/Warrior.lua "$name" > "$TMP/hekili-era-pack.txt" 2>&1 || { echo "!! cannot decode $name"; fail=1; continue; }
    # The pack stores its source profile; compare it with the .simc file.
    LIBS="$LIBS" lua5.1 tools/packtool.lua encode "$simc" "$name" 1 > "$TMP/hekili-era-enc.txt"
    LIBS="$LIBS" lua5.1 tools/packtool.lua decodestr < "$TMP/hekili-era-enc.txt" > "$TMP/hekili-era-fresh.txt"
    if diff <(grep -E '"(action|criteria|value|list_name|var_name)"' "$TMP/hekili-era-pack.txt" | sort) \
            <(grep -E '"(action|criteria|value|list_name|var_name)"' "$TMP/hekili-era-fresh.txt" | sort) > /dev/null; then
        echo "$name pack matches $simc"
    else
        echo "!! $name pack is out of date; run: LIBS=... lua5.1 tools/packtool.lua embed Era/Warrior.lua $simc $name 1"
        fail=1
    fi
done

harness() {
    local label="$1" level="$2" build="$3"
    step "Harness: $label"
    local out code
    out=$(HARNESS_LEVEL="$level" timeout 300 luajit tools/harness.lua Hekili_Vanilla.toc WARRIOR "$build" 2>&1)
    code=$?
    echo "$out" | grep -E "^(Active priority|GCD tracked|Talents detected|Priority entries|Options panel|Loaded saved)|^  [A-Z]|^No errors|error\(s\)|^  [a-zA-Z/ ]+.*: " | grep -v '\[chat\]' | cut -c1-180
    [ "$code" -eq 0 ] || fail=1
}

harness "level 60 Fury (17/34/0)" 60 17/34/0
harness "level 60 Arms (31/20/0)" 60 31/20/0
if [ "${1:-}" != "quick" ]; then
    harness "level 40, no talents" 40 0/0/0
    harness "level 20, no talents" 20 0/0/0
    harness "level 12, no talents" 12 0/0/0
fi
if [ -n "${HARNESS_SAVEDVARS:-}" ]; then
    harness "saved profile $HARNESS_SAVEDVARS" 60 17/34/0
fi

echo
if [ "$fail" -eq 0 ]; then echo "ALL CHECKS PASSED"; else echo "SOME CHECKS FAILED"; fi
exit "$fail"
