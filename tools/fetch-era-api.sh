#!/usr/bin/env bash
# Download the Classic Era API dumps used by tools/harness.lua into tools/.era-api/
# Sources: https://github.com/Ketho/BlizzardInterfaceResources (branch classic_era) for the native API and Enum,
#          https://github.com/Gethe/wow-ui-source (branch classic_era) for FrameXML global names.
set -euo pipefail

DIR="$(cd "$(dirname "$0")" && pwd)/.era-api"
mkdir -p "$DIR"

BASE="https://raw.githubusercontent.com/Ketho/BlizzardInterfaceResources/classic_era/Resources"
for f in GlobalAPI.lua LuaEnum.lua Events.lua CVars.lua; do
    curl -fsSL -o "$DIR/$f" "$BASE/$f"
    echo "Fetched $f ($(wc -c < "$DIR/$f") bytes)"
done

# Client database tables (DB2) as CSV from wago.tools, for ID audits and GlobalStrings.
BUILD="${ERA_BUILD:-$(curl -fsSL https://wago.tools/api/builds | python3 -I -c 'import sys, json; print(json.load(sys.stdin)["wow_classic_era"][0]["version"])')}"
mkdir -p "$DIR/db2"
for t in GlobalStrings SpellName Spell SpellLevels SkillLineAbility Talent ItemSparse; do
    curl -fsSL -o "$DIR/db2/$t.csv" "https://wago.tools/db2/$t/csv?build=$BUILD"
    echo "Fetched db2/$t.csv for $BUILD ($(wc -l < "$DIR/db2/$t.csv") rows)"
done
echo "$BUILD" > "$DIR/db2/BUILD"

SRC="$(mktemp -d)"
trap 'rm -rf "$SRC"' EXIT
git clone -q --depth 1 --branch classic_era https://github.com/Gethe/wow-ui-source.git "$SRC/wus"
python3 -I "$(dirname "$0")/framexml_globals.py" "$SRC/wus" > "$DIR/FrameXML.txt"
echo "FrameXML globals: $(wc -l < "$DIR/FrameXML.txt") (UI source $(cat "$SRC/wus/version.txt" 2>/dev/null || echo unknown))"
python3 -I "$(dirname "$0")/deprecated_globals.py" "$SRC/wus" > "$DIR/Deprecated.txt"
echo "Deprecation fallbacks: $(wc -l < "$DIR/Deprecated.txt")"
python3 -I "$(dirname "$0")/era_data.py" "$SRC/wus"
