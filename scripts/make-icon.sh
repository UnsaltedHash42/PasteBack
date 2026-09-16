#!/bin/bash
# Renders the placeholder icon and packs Resources/AppIcon.icns.
set -euo pipefail

cd "$(dirname "$0")/.."
ROOT="$(pwd)"

WORK="$(mktemp -d)/AppIcon.iconset"
mkdir -p "$WORK"

PNG="$WORK/icon_1024.png"
swift "$ROOT/scripts/make-icon.swift" "$PNG"

for size in 16 32 64 128 256 512; do
    sips -z "$size" "$size" "$PNG" --out "$WORK/icon_${size}x${size}.png" >/dev/null
    sips -z $((size * 2)) $((size * 2)) "$PNG" --out "$WORK/icon_${size}x${size}@2x.png" >/dev/null
done
sips -z 1024 1024 "$PNG" --out "$WORK/icon_512x512@2x.png" >/dev/null

mkdir -p "$ROOT/Resources"
iconutil -c icns "$WORK" -o "$ROOT/Resources/AppIcon.icns"
echo "==> wrote Resources/AppIcon.icns"
