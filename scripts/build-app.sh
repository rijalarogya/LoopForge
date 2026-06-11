#!/bin/zsh
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP_NAME="LoopForge"
EXECUTABLE="LoopForge"
BUILD_DIR="$ROOT/dist"
APP_DIR="$BUILD_DIR/$APP_NAME.app"
TOOLS_DIR="${LOOPFORGE_TOOLS_DIR:-$ROOT/Vendor/ffmpeg/arm64/bin}"
SIGNING_IDENTITY="${LOOPFORGE_SIGNING_IDENTITY:--}"
SIGNING_MODE="${LOOPFORGE_SIGNING_MODE:-adhoc}"

if [[ "$(uname -m)" != "arm64" ]]; then
    echo "LoopForge 1.0.0 release builds currently support Apple silicon only." >&2
    exit 1
fi

for tool in ffmpeg ffprobe; do
    if [[ ! -x "$TOOLS_DIR/$tool" ]]; then
        echo "Missing bundled $tool at $TOOLS_DIR/$tool." >&2
        echo "Run ./scripts/build-ffmpeg.sh first." >&2
        exit 1
    fi
done

cd "$ROOT"
swift build -c release --arch arm64

rm -rf "$APP_DIR"
mkdir -p \
    "$APP_DIR/Contents/MacOS" \
    "$APP_DIR/Contents/Resources/bin" \
    "$APP_DIR/Contents/Resources/Licenses"

cp "$ROOT/.build/arm64-apple-macosx/release/$EXECUTABLE" \
    "$APP_DIR/Contents/MacOS/$EXECUTABLE"
cp "$ROOT/Support/Info.plist" "$APP_DIR/Contents/Info.plist"
cp "$ROOT/Support/LoopForge.icns" "$APP_DIR/Contents/Resources/LoopForge.icns"
cp "$TOOLS_DIR/ffmpeg" "$TOOLS_DIR/ffprobe" "$APP_DIR/Contents/Resources/bin/"
cp "$ROOT/LICENSE" "$APP_DIR/Contents/Resources/Licenses/LoopForge-MIT.txt"
cp "$ROOT/THIRD_PARTY_NOTICES.md" "$APP_DIR/Contents/Resources/Licenses/"
cp "$ROOT/ThirdParty/FFmpeg/COPYING.GPLv3" \
    "$APP_DIR/Contents/Resources/Licenses/FFmpeg-GPLv3.txt"
cp "$ROOT/ThirdParty/FFmpeg/BUILD-INFO.txt" \
    "$APP_DIR/Contents/Resources/Licenses/FFmpeg-BUILD-INFO.txt"

chmod +x \
    "$APP_DIR/Contents/MacOS/$EXECUTABLE" \
    "$APP_DIR/Contents/Resources/bin/ffmpeg" \
    "$APP_DIR/Contents/Resources/bin/ffprobe"

case "$SIGNING_MODE" in
    unsigned)
        echo "Building unsigned early-tester app with an ad-hoc bundle seal."
        codesign --force --sign - "$APP_DIR/Contents/Resources/bin/ffmpeg"
        codesign --force --sign - "$APP_DIR/Contents/Resources/bin/ffprobe"
        codesign --force --sign - "$APP_DIR"
        codesign --verify --deep --strict --verbose=2 "$APP_DIR"
        ;;
    adhoc)
        codesign --force --options runtime --sign - \
            "$APP_DIR/Contents/Resources/bin/ffmpeg"
        codesign --force --options runtime --sign - \
            "$APP_DIR/Contents/Resources/bin/ffprobe"
        codesign --force --options runtime --sign - "$APP_DIR"
        codesign --verify --deep --strict --verbose=2 "$APP_DIR"
        ;;
    developer-id)
        if [[ "$SIGNING_IDENTITY" == "-" || -z "$SIGNING_IDENTITY" ]]; then
            echo "Set LOOPFORGE_SIGNING_IDENTITY for a Developer ID build." >&2
            exit 1
        fi
        codesign --force --options runtime --timestamp \
            --sign "$SIGNING_IDENTITY" "$APP_DIR/Contents/Resources/bin/ffmpeg"
        codesign --force --options runtime --timestamp \
            --sign "$SIGNING_IDENTITY" "$APP_DIR/Contents/Resources/bin/ffprobe"
        codesign --force --options runtime --timestamp \
            --sign "$SIGNING_IDENTITY" "$APP_DIR"
        codesign --verify --deep --strict --verbose=2 "$APP_DIR"
        ;;
    *)
        echo "Unknown LOOPFORGE_SIGNING_MODE: $SIGNING_MODE" >&2
        exit 1
        ;;
esac

echo "$APP_DIR"
