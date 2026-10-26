#!/usr/bin/env bash
# Fill Libs/ with the third-party libraries that the BigWigs packager would normally pull in
# (see .pkgmeta), taken from an official Hekili release zip.  Folders already in Libs/ are left alone.
#
# Usage: tools/fetch-libs.sh [release-tag]     (default: v11.2.5-1.0.0)
set -euo pipefail

TAG="${1:-v11.2.5-1.0.0}"
REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

URL="https://github.com/Hekili/hekili/releases/download/${TAG}/Hekili-${TAG}.zip"
echo "Downloading ${URL}"
curl -fsSL -o "$WORK/hekili.zip" "$URL"
unzip -q "$WORK/hekili.zip" -d "$WORK/x"

added=0
for lib in "$WORK"/x/Hekili/Libs/*/; do
    name="$(basename "$lib")"
    # Not bundled with Herakili (GPLv3): LibCompress is GPLv2-only; AceGUI-3.0_SFX-Widgets' licence forbids
    # redistribution; LibDataBroker-1.1 is "All Rights Reserved" (and LibDBIcon needs it) -- the minimap button uses
    # copies other addons load.
    if [ "$name" = "LibCompress" ] || [ "$name" = "AceGUI-3.0_SFX-Widgets" ] || [ "$name" = "LibDataBroker-1.1" ] \
        || [ "$name" = "LibDBIcon-1.0" ]; then
        echo "  skip    Libs/$name (not used)"
        continue
    fi
    if [ -e "$REPO_ROOT/Libs/$name" ]; then
        echo "  keep    Libs/$name"
    else
        cp -r "$lib" "$REPO_ROOT/Libs/$name"
        echo "  added   Libs/$name"
        added=$((added + 1))
    fi
done

# LibRangeCheck-3.0 comes from its own repository (as in .pkgmeta): the copy in older retail release zips
# registers LEARNED_SPELL_IN_TAB unconditionally, which errors on Classic Era.
if [ ! -e "$REPO_ROOT/Libs/LibRangeCheck-3.0/LibRangeCheck-3.0/LibRangeCheck-3.0.lua" ]; then
    rm -rf "$REPO_ROOT/Libs/LibRangeCheck-3.0"
    git clone -q --depth 1 https://github.com/WeakAuras/LibRangeCheck-3.0.git "$WORK/lrc"
    rm -rf "$WORK/lrc/.git"
    cp -r "$WORK/lrc" "$REPO_ROOT/Libs/LibRangeCheck-3.0"
    echo "  added   Libs/LibRangeCheck-3.0 (from GitHub)"
fi

# Every library referenced by embeds.xml must now exist.
missing=0
while read -r path; do
    if [ ! -e "$REPO_ROOT/${path//\\//}" ]; then
        echo "  MISSING $path"
        missing=$((missing + 1))
    fi
done < <(grep -oE 'file="Libs\\[^"]+"' "$REPO_ROOT/embeds.xml" | sed -E 's/file="([^"]+)"/\1/')

echo "Added ${added} libraries; ${missing} file(s) referenced by embeds.xml are missing."
[ "$missing" -eq 0 ]
