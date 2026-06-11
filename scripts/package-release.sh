#!/bin/zsh
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
VERSION="${LOOPFORGE_VERSION:-1.0.0}"
TOOLS_DIR="${LOOPFORGE_TOOLS_DIR:-$ROOT/Vendor/ffmpeg/arm64}"
RELEASE_DIR="$ROOT/dist/release-$VERSION"

if [[ -z "${LOOPFORGE_SIGNING_IDENTITY:-}" ]]; then
    echo "Set LOOPFORGE_SIGNING_IDENTITY for the notarized release path." >&2
    echo "For a free unsigned build, run ./scripts/package-unsigned-release.sh." >&2
    exit 1
fi

LOOPFORGE_SIGNING_MODE=developer-id "$ROOT/scripts/build-app.sh"
"$ROOT/scripts/create-dmg.sh"

rm -rf "$RELEASE_DIR"
mkdir -p "$RELEASE_DIR/bin" "$RELEASE_DIR/scripts"
cp "$ROOT/dist/LoopForge-$VERSION-arm64.dmg" "$RELEASE_DIR/"
cp "$ROOT/dist/LoopForge-$VERSION-arm64.dmg.sha256" "$RELEASE_DIR/"
cp "$TOOLS_DIR/bin/ffmpeg" "$RELEASE_DIR/bin/"
cp "$TOOLS_DIR/bin/ffprobe" "$RELEASE_DIR/bin/"
cp "$TOOLS_DIR/ffmpeg-8.1.1.tar.xz" "$RELEASE_DIR/"
cp "$TOOLS_DIR/x264-b35605ace3ddf7c1a5d67a2eb553f034aef41d55.tar.gz" "$RELEASE_DIR/"
cp "$TOOLS_DIR/SHA256SUMS" "$RELEASE_DIR/FFmpeg-SHA256SUMS"
cp "$ROOT/scripts/build-ffmpeg.sh" "$RELEASE_DIR/scripts/"
cp "$ROOT/scripts/x264-pkg-config.sh" "$RELEASE_DIR/scripts/"
cp "$ROOT/THIRD_PARTY_NOTICES.md" "$RELEASE_DIR/"
cp "$ROOT/ThirdParty/FFmpeg/BUILD-INFO.txt" "$RELEASE_DIR/"
cp "$ROOT/ThirdParty/FFmpeg/COPYING.GPLv3" "$RELEASE_DIR/"

echo "$RELEASE_DIR"
