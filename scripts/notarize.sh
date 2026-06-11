#!/bin/zsh
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
VERSION="${LOOPFORGE_VERSION:-1.0.0}"
DMG="${1:-$ROOT/dist/LoopForge-$VERSION-arm64.dmg}"
PROFILE="${LOOPFORGE_NOTARY_PROFILE:-}"

if [[ -z "$PROFILE" ]]; then
    echo "Set LOOPFORGE_NOTARY_PROFILE to a notarytool Keychain profile." >&2
    exit 1
fi
if [[ ! -f "$DMG" ]]; then
    echo "Missing DMG: $DMG" >&2
    exit 1
fi

xcrun notarytool submit "$DMG" --keychain-profile "$PROFILE" --wait
xcrun stapler staple "$DMG"
xcrun stapler validate "$DMG"
spctl --assess --type open --context context:primary-signature --verbose=4 "$DMG"
shasum -a 256 "$DMG" > "$DMG.sha256"
