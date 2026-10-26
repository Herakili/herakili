#!/usr/bin/env bash
# Assemble an installable addon folder at dist/Hekili (run tools/fetch-libs.sh first).
# Optionally copy it into a WoW AddOns folder: tools/build.sh "<.../_classic_era_/Interface/AddOns>"
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT="$REPO_ROOT/dist/Hekili"

rm -rf "$OUT"
mkdir -p "$OUT"

rsync -a \
    --exclude '.git*' --exclude '.claude' --exclude '.github' --exclude '.vscode' --exclude '.pkgmeta' \
    --exclude 'dist' --exclude 'tools' --exclude '*.simc' --exclude '*.md' --exclude 'cspell.json' \
    "$REPO_ROOT/" "$OUT/"

echo "Built $OUT"

if [ "${1:-}" != "" ]; then
    DEST="$1/Hekili"
    if [ -e "$DEST" ]; then
        echo "Replacing existing $DEST"
        rm -rf "$DEST"
    fi
    cp -r "$OUT" "$DEST"
    echo "Installed to $DEST"
fi
