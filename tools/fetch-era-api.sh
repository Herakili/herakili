#!/usr/bin/env bash
# Download the Classic Era API dumps used by tools/harness.lua into tools/.era-api/
# Sources: https://github.com/Ketho/BlizzardInterfaceResources (branch classic_era) for the native API and Enum,
#          https://github.com/Gethe/wow-ui-source (branch classic_era) for FrameXML global names.
set -euo pipefail

DIR="$(cd "$(dirname "$0")" && pwd)/.era-api"
mkdir -p "$DIR"

BASE="https://raw.githubusercontent.com/Ketho/BlizzardInterfaceResources/classic_era/Resources"
for f in GlobalAPI.lua LuaEnum.lua; do
    curl -fsSL -o "$DIR/$f" "$BASE/$f"
    echo "Fetched $f ($(wc -c < "$DIR/$f") bytes)"
done

SRC="$(mktemp -d)"
trap 'rm -rf "$SRC"' EXIT
git clone -q --depth 1 --branch classic_era https://github.com/Gethe/wow-ui-source.git "$SRC/wus"
python3 -I "$(dirname "$0")/framexml_globals.py" "$SRC/wus" > "$DIR/FrameXML.txt"
echo "FrameXML globals: $(wc -l < "$DIR/FrameXML.txt") (UI source $(cat "$SRC/wus/version.txt" 2>/dev/null || echo unknown))"
