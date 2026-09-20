#!/bin/bash
# Packs Resources/AppIcon.png into Resources/AppIcon.icns.
set -euo pipefail

cd "$(dirname "$0")/.."
ROOT="$(pwd)"

SRC="$ROOT/Resources/AppIcon.png"
if [ ! -f "$SRC" ]; then
    echo "error: Resources/AppIcon.png missing" >&2
    exit 1
fi

WORK="$(mktemp -d)/AppIcon.iconset"
mkdir -p "$WORK"

PNG="$WORK/icon_1024.png"
sips -s format png -z 1024 1024 "$SRC" --out "$PNG" >/dev/null

for size in 16 32 128 256 512; do
    sips -s format png -z "$size" "$size" "$PNG" --out "$WORK/icon_${size}x${size}.png" >/dev/null
    sips -s format png -z $((size * 2)) $((size * 2)) "$PNG" --out "$WORK/icon_${size}x${size}@2x.png" >/dev/null
done

mkdir -p "$ROOT/Resources"
iconutil -c icns "$WORK" -o "$ROOT/Resources/AppIcon.icns"
echo "==> wrote Resources/AppIcon.icns"
