#!/usr/bin/env bash
# Assemble the installable Herakili addon (Classic Era) at dist/Herakili, plus a zip for distribution.
# Run tools/fetch-libs.sh first.
#
#   tools/build.sh                       build dist/Herakili and dist/Herakili-<version>.zip
#   tools/build.sh "<.../_classic_era_/Interface/AddOns>"   also install it there
#
# Only what the Era client loads is shipped: the Wrath modules, the Wrath TOC and the development tools are left out.
# The licence and the notices required by the GPL and the bundled libraries are included.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
NAME="Herakili"
OUT="$REPO_ROOT/dist/$NAME"
VERSION="$(sed -n 's/^## Version: //p' "$REPO_ROOT/Herakili_Vanilla.toc" | tr -d '\r')"

rm -rf "$OUT"
mkdir -p "$OUT"

rsync -a \
    --exclude '.git*' --exclude '.claude' --exclude '.github' --exclude '.vscode' --exclude '.pkgmeta' \
    --exclude '.editorconfig' --exclude '.luacheckrc' --exclude '.travis.yml' \
    --exclude 'dist' --exclude 'tools' --exclude '*.simc' --exclude 'cspell.json' \
    --exclude 'Wrath' --exclude 'Hekili.toc' --exclude 'Wrath Plan.md' --exclude 'CHANGES.txt' \
    --exclude 'README.md' --exclude 'ERA.md' --exclude 'PORTING.md' \
    "$REPO_ROOT/" "$OUT/"

# Notices shipped with the addon.
for f in LICENSE NOTICE.md; do
    [ -f "$REPO_ROOT/$f" ] && cp "$REPO_ROOT/$f" "$OUT/$f"
done

echo "Built $OUT ($VERSION)"

( cd "$REPO_ROOT/dist" && rm -f "$NAME-$VERSION.zip" && zip -qr "$NAME-$VERSION.zip" "$NAME" )
echo "Packaged $REPO_ROOT/dist/$NAME-$VERSION.zip"

if [ "${1:-}" != "" ]; then
    DEST="$1/$NAME"
    if [ -e "$DEST" ]; then
        echo "Replacing existing $DEST"
        rm -rf "$DEST"
    fi
    cp -r "$OUT" "$DEST"
    echo "Installed to $DEST"
    if [ -e "$1/Hekili/Hekili_Vanilla.toc" ] && grep -q "X-Flavor: Era" "$1/Hekili/Hekili_Vanilla.toc"; then
        echo "Note: $1/Hekili is an earlier build of this port (pre-rename); remove it so the two don't both load."
    fi
fi
