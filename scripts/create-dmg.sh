#!/bin/zsh
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
VERSION="${LOOPFORGE_VERSION:-1.0.0}"
APP="$ROOT/dist/LoopForge.app"
STAGING="$ROOT/.release-build/dmg"
DMG="$ROOT/dist/LoopForge-$VERSION-arm64.dmg"

if [[ ! -d "$APP" ]]; then
    echo "Missing $APP. Run ./scripts/build-app.sh first." >&2
    exit 1
fi

rm -rf "$STAGING" "$DMG"
mkdir -p "$STAGING"
cp -R "$APP" "$STAGING/"
ln -s /Applications "$STAGING/Applications"

hdiutil create \
    -volname "LoopForge $VERSION" \
    -srcfolder "$STAGING" \
    -format UDZO \
    -imagekey zlib-level=9 \
    "$DMG"

shasum -a 256 "$DMG" > "$DMG.sha256"
echo "$DMG"
