#!/bin/bash
# Assembles dist/Pasteback.app from the swift build products.
# Usage: scripts/build-app.sh [debug|release]
set -euo pipefail

cd "$(dirname "$0")/.."
ROOT="$(pwd)"
CONFIG="${1:-release}"
CONFIG_CAP="$(printf '%s' "$CONFIG" | cut -c1 | tr '[:lower:]' '[:upper:]')$(printf '%s' "$CONFIG" | cut -c2-)"
echo "==> swift build -c $CONFIG"
swift build -c "$CONFIG"

BIN="$ROOT/.build/$CONFIG/Pasteback"
# New SwiftPM layouts keep products under .build/out/Products/<Config>.
if [ ! -f "$BIN" ]; then
    BIN="$(find "$ROOT/.build" -type f -path "*$CONFIG_CAP/Pasteback" -perm -111 | head -1)"
fi
if [ ! -f "$BIN" ]; then
    echo "error: built Pasteback binary not found" >&2
    exit 1
fi

SPARKLE_FW="$(find "$ROOT/.build" -type d -path "*Products/$CONFIG_CAP/Sparkle.framework" | head -1)"
APP="$ROOT/dist/Pasteback.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Frameworks" "$APP/Contents/Resources"

cp "$BIN" "$APP/Contents/MacOS/Pasteback"

PUBKEY=""
if [ -f "$ROOT/Resources/SparklePublicED.key" ]; then
    PUBKEY="$(tr -d '[:space:]' < "$ROOT/Resources/SparklePublicED.key")"
else
    echo "warning: Resources/SparklePublicED.key missing; embedding empty update key" >&2
fi
sed -e "s|__SPARKLE_PUBLIC_KEY__|$PUBKEY|" \
    -e "s|__SU_FEED_URL__|file://$APP/Contents/Resources/appcast.xml|" \
    "$ROOT/scripts/Resources/App-Info.plist" > "$APP/Contents/Info.plist"
cp "$ROOT/docs/appcast.xml" "$APP/Contents/Resources/appcast.xml"

if [ -n "$SPARKLE_FW" ]; then
    ditto "$SPARKLE_FW" "$APP/Contents/Frameworks/Sparkle.framework"
else
    echo "error: Sparkle.framework not found in build products" >&2
    exit 1
fi

if [ -f "$ROOT/Resources/AppIcon.icns" ]; then
    cp "$ROOT/Resources/AppIcon.icns" "$APP/Contents/Resources/AppIcon.icns"
else
    echo "warning: Resources/AppIcon.icns missing; run 'make icon'" >&2
fi

# Ensure the executable can locate the embedded framework.
install_name_tool -add_rpath "@executable_path/../Frameworks" "$APP/Contents/MacOS/Pasteback" 2>/dev/null || true

echo "==> codesign (adhoc)"
codesign --force --sign - "$APP/Contents/Frameworks/Sparkle.framework" >/dev/null
codesign --force --sign - "$APP" >/dev/null

echo "==> built $APP"
