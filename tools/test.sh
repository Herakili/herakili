#!/usr/bin/env bash
# Run every offline check for the Classic Era flavor, for every class module in Era/.
# Needs tools/fetch-libs.sh and tools/fetch-era-api.sh first, and LIBS pointing at LibDeflate/ + Ace3/ checkouts
# for the pack check (see tools/packtool.lua).
#
#   tools/test.sh                  all classes, all builds, leveling runs
#   tools/test.sh quick            skip the leveling runs
#   tools/test.sh quick ROGUE      one class only (class token as in UnitClass, e.g. WARRIOR, DRUID)
#
# HARNESS_SAVEDVARS=<path to WTF/.../SavedVariables/Hekili.lua> additionally runs from that saved profile.
set -uo pipefail
cd "$(dirname "$0")/.."

MODE="${1:-full}"
ONLY="${2:-}"
fail=0
TMP="${TMPDIR:-/tmp}"
step() { printf '\n== %s\n' "$1"; }

declare -A CLASS_ID=( [WARRIOR]=1 [PALADIN]=2 [HUNTER]=3 [ROGUE]=4 [PRIEST]=5 [SHAMAN]=7 [MAGE]=8 [WARLOCK]=9 [DRUID]=11 )

step "Lua syntax (Lua 5.1, as in the client)"
n=0
while read -r f; do
    luac5.1 -p "$f" || fail=1
    n=$((n + 1))
done < <(grep -v '^#' Hekili_Vanilla.toc | grep '\.lua' | tr '\\' '/' | tr -d '\r')
echo "checked $n files"

step "Registered events exist on Era"
# Expected in this list: Chromie Time events (only registered on retail) and LEARNED_SPELL_IN_TAB (dropped at
# runtime by ns.IsEventValid before the display frames register their event tables).
python3 -I tools/check_events.py | grep -v -E "CHROMIE_TIME|LEARNED_SPELL_IN_TAB"

for module in Era/*.lua; do
    name=$(basename "$module" .lua)
    [ "$name" = "Classes" ] && continue
    CLASS=$(echo "$name" | tr '[:lower:]' '[:upper:]')
    [ -n "$ONLY" ] && [ "$ONLY" != "$CLASS" ] && continue
    id=${CLASS_ID[$CLASS]:-}
    [ -z "$id" ] && { echo "!! unknown class module $module"; fail=1; continue; }

    if ! grep -q "Era\\\\$name.lua" Hekili_Vanilla.toc; then
        echo "!! $module is not listed in Hekili_Vanilla.toc"; fail=1
    fi

    simcs=$(ls Era/APLs/"$name"*.simc 2>/dev/null)

    step "$name: priority lists reference only defined abilities, auras, talents and settings"
    if [ -n "$simcs" ]; then
        # shellcheck disable=SC2086
        python3 -I tools/check_apl.py "$module" $simcs || fail=1
    else
        echo "!! no Era/APLs/$name*.simc"; fail=1
    fi

    step "$name: spell, rank, aura and talent IDs match the Era client tables"
    luajit tools/dump_spec.lua "$module" "$CLASS" > "$TMP/hekili-era-ids.txt" && \
        python3 -I tools/check_ids.py "$TMP/hekili-era-ids.txt" "$id" || fail=1

    step "$name: built-in packs match their .simc sources"
    for simc in $simcs; do
        pack=$(basename "$simc" .simc); pack=${pack#"$name"}
        if [ -z "${LIBS:-}" ]; then echo "skipped (set LIBS)"; break; fi
        if ! LIBS="$LIBS" lua5.1 tools/packtool.lua decode "$module" "$pack" > "$TMP/hekili-era-pack.txt" 2>&1; then
            echo "!! cannot decode pack $pack from $module"; fail=1; continue
        fi
        LIBS="$LIBS" lua5.1 tools/packtool.lua encode "$simc" "$pack" "$id" > "$TMP/hekili-era-enc.txt"
        LIBS="$LIBS" lua5.1 tools/packtool.lua decodestr < "$TMP/hekili-era-enc.txt" > "$TMP/hekili-era-fresh.txt"
        if diff <(grep -E '"(action|criteria|value|list_name|var_name)"' "$TMP/hekili-era-pack.txt" | sort) \
                <(grep -E '"(action|criteria|value|list_name|var_name)"' "$TMP/hekili-era-fresh.txt" | sort) > /dev/null; then
            echo "$pack pack matches $simc"
        else
            echo "!! $pack pack is out of date; run: LIBS=... lua5.1 tools/packtool.lua embed $module $simc $pack $id"
            fail=1
        fi
    done

    scen="tools/scenarios/$CLASS.lua"
    if [ ! -f "$scen" ]; then echo "!! no $scen"; fail=1; continue; fi
    builds=$(luajit -e "local d = dofile('$scen'); local t = {} for k in pairs(d.builds) do if k ~= '0/0/0' then t[#t+1] = k end end table.sort(t) print(table.concat(t, ' '))")

    harness() {
        local label="$1" level="$2" build="$3"
        step "$name harness: $label"
        local out code
        out=$(HARNESS_LEVEL="$level" timeout 300 luajit tools/harness.lua Hekili_Vanilla.toc "$CLASS" "$build" 2>&1)
        code=$?
        echo "$out" | grep -E "^(Active priority|GCD tracked|Talents detected|Priority entries|Options panel|Loaded saved)|^  [A-Z]|^No errors|error\(s\)|^  [a-zA-Z/ ]+.*: " | grep -v '\[chat\]' | cut -c1-180
        [ "$code" -eq 0 ] || fail=1
    }

    for b in $builds; do harness "level 60, $b" 60 "$b"; done
    if [ "$MODE" != "quick" ]; then
        for lv in 40 20 12; do harness "level $lv, no talents" "$lv" 0/0/0; done
    fi
    if [ -n "${HARNESS_SAVEDVARS:-}" ] && [ "$CLASS" = "WARRIOR" ]; then
        harness "saved profile $HARNESS_SAVEDVARS" 60 "$(echo "$builds" | cut -d' ' -f1)"
    fi
done

echo
if [ "$fail" -eq 0 ]; then echo "ALL CHECKS PASSED"; else echo "SOME CHECKS FAILED"; fi
exit "$fail"
