#!/bin/zsh
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
VERSION="${LOOPFORGE_VERSION:-1.0.0}"
TOOLS_DIR="${LOOPFORGE_TOOLS_DIR:-$ROOT/Vendor/ffmpeg/arm64}"
RELEASE_DIR="$ROOT/dist/release-$VERSION-unsigned"
APP="$ROOT/dist/LoopForge.app"
ZIP="$ROOT/dist/LoopForge-$VERSION-arm64-unsigned.zip"
DMG="$ROOT/dist/LoopForge-$VERSION-arm64-unsigned.dmg"
STAGING="$ROOT/.release-build/unsigned-dmg"
COMPLIANCE_STAGING="$ROOT/.release-build/unsigned-compliance"
COMPLIANCE_ZIP="LoopForge-$VERSION-FFmpeg-Sources-and-Licenses.zip"

LOOPFORGE_SIGNING_MODE=unsigned "$ROOT/scripts/build-app.sh"

verify_no_developer_identity() {
    local item="$1"
    local details
    details="$(codesign -dvvv "$item" 2>&1)"
    if [[ "$details" != *"Signature=adhoc"* ]] ||
       [[ "$details" != *"TeamIdentifier=not set"* ]] ||
       [[ "$details" == *"Authority="* ]]; then
        echo "Expected an ad-hoc linker signature without a Developer ID: $item" >&2
        exit 1
    fi
}

verify_no_developer_identity "$APP"
verify_no_developer_identity "$APP/Contents/Resources/bin/ffmpeg"
verify_no_developer_identity "$APP/Contents/Resources/bin/ffprobe"

rm -rf \
    "$ZIP" \
    "$DMG" \
    "$DMG.sha256" \
    "$STAGING" \
    "$COMPLIANCE_STAGING" \
    "$RELEASE_DIR"

ditto -c -k --sequesterRsrc --keepParent "$APP" "$ZIP"

mkdir -p "$STAGING"
cp -R "$APP" "$STAGING/"
ln -s /Applications "$STAGING/Applications"
hdiutil create \
    -volname "LoopForge $VERSION Unsigned" \
    -srcfolder "$STAGING" \
    -format UDZO \
    -imagekey zlib-level=9 \
    "$DMG"

mkdir -p "$RELEASE_DIR/bin" "$RELEASE_DIR/scripts"
cp "$ZIP" "$DMG" "$RELEASE_DIR/"
cp "$TOOLS_DIR/bin/ffmpeg" "$TOOLS_DIR/bin/ffprobe" "$RELEASE_DIR/bin/"
cp "$TOOLS_DIR/ffmpeg-8.1.1.tar.xz" "$RELEASE_DIR/"
cp "$TOOLS_DIR/x264-b35605ace3ddf7c1a5d67a2eb553f034aef41d55.tar.gz" \
    "$RELEASE_DIR/"
cp "$TOOLS_DIR/SHA256SUMS" "$RELEASE_DIR/FFmpeg-SHA256SUMS"
cp "$ROOT/scripts/build-ffmpeg.sh" "$RELEASE_DIR/scripts/"
cp "$ROOT/scripts/x264-pkg-config.sh" "$RELEASE_DIR/scripts/"
cp "$ROOT/THIRD_PARTY_NOTICES.md" "$RELEASE_DIR/"
cp "$ROOT/ThirdParty/FFmpeg/BUILD-INFO.txt" "$RELEASE_DIR/"
cp "$ROOT/ThirdParty/FFmpeg/COPYING.GPLv3" "$RELEASE_DIR/"

mkdir -p "$COMPLIANCE_STAGING"
cp -R \
    "$RELEASE_DIR/bin" \
    "$RELEASE_DIR/scripts" \
    "$COMPLIANCE_STAGING/"
cp \
    "$RELEASE_DIR/ffmpeg-8.1.1.tar.xz" \
    "$RELEASE_DIR/x264-b35605ace3ddf7c1a5d67a2eb553f034aef41d55.tar.gz" \
    "$RELEASE_DIR/FFmpeg-SHA256SUMS" \
    "$RELEASE_DIR/THIRD_PARTY_NOTICES.md" \
    "$RELEASE_DIR/BUILD-INFO.txt" \
    "$RELEASE_DIR/COPYING.GPLv3" \
    "$COMPLIANCE_STAGING/"
ditto -c -k --sequesterRsrc \
    "$COMPLIANCE_STAGING" "$RELEASE_DIR/$COMPLIANCE_ZIP"

(
    cd "$RELEASE_DIR"
    shasum -a 256 \
        "$(basename "$ZIP")" \
        "$(basename "$DMG")" \
        "$COMPLIANCE_ZIP" > SHA256SUMS
)

echo "Verified: no Developer ID authority or team identifier is present."
echo "$RELEASE_DIR"
