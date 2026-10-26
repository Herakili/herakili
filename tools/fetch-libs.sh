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
    if [ -e "$REPO_ROOT/Libs/$name" ]; then
        echo "  keep    Libs/$name"
    else
        cp -r "$lib" "$REPO_ROOT/Libs/$name"
        echo "  added   Libs/$name"
        added=$((added + 1))
    fi
done

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
