#!/bin/zsh
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
WORK_DIR="${LOOPFORGE_FFMPEG_BUILD_DIR:-$ROOT/.release-build/ffmpeg}"
OUTPUT_DIR="${LOOPFORGE_TOOLS_DIR:-$ROOT/Vendor/ffmpeg/arm64}"
DOWNLOAD_DIR="$WORK_DIR/downloads"
SOURCE_DIR="$WORK_DIR/sources"
BUILD_DIR="$WORK_DIR/build"
MACOS_SDK="$(xcrun --sdk macosx --show-sdk-path)"

FFMPEG_VERSION="8.1.1"
FFMPEG_ARCHIVE="ffmpeg-$FFMPEG_VERSION.tar.xz"
FFMPEG_URL="https://ffmpeg.org/releases/$FFMPEG_ARCHIVE"
FFMPEG_SHA256="b6863adde98898f42602017462871b5f6333e65aec803fdd7a6308639c52edf3"

X264_COMMIT="b35605ace3ddf7c1a5d67a2eb553f034aef41d55"
X264_ARCHIVE="x264-$X264_COMMIT.tar.gz"
X264_URL="https://code.videolan.org/videolan/x264/-/archive/$X264_COMMIT/$X264_ARCHIVE"
X264_SHA256="cd71a7515b0e9a012e1ac9b1f8415bebcaf6fc97d4db32286642ac4c0fbe24f9"

if [[ "$(uname -m)" != "arm64" ]]; then
    echo "This script builds the Apple-silicon release tools and must run on arm64." >&2
    exit 1
fi

mkdir -p "$DOWNLOAD_DIR" "$SOURCE_DIR" "$BUILD_DIR"

download_and_verify() {
    local url="$1"
    local output="$2"
    local expected="$3"
    if [[ ! -f "$output" ]]; then
        curl --fail --location --retry 3 --output "$output" "$url"
    fi
    local actual
    actual="$(shasum -a 256 "$output" | awk '{print $1}')"
    if [[ "$actual" != "$expected" ]]; then
        echo "Checksum mismatch for $output" >&2
        echo "Expected: $expected" >&2
        echo "Actual:   $actual" >&2
        exit 1
    fi
}

download_and_verify "$FFMPEG_URL" "$DOWNLOAD_DIR/$FFMPEG_ARCHIVE" "$FFMPEG_SHA256"
download_and_verify "$X264_URL" "$DOWNLOAD_DIR/$X264_ARCHIVE" "$X264_SHA256"

rm -rf "$SOURCE_DIR/ffmpeg-$FFMPEG_VERSION" "$SOURCE_DIR/x264-$X264_COMMIT"
tar -xf "$DOWNLOAD_DIR/$FFMPEG_ARCHIVE" -C "$SOURCE_DIR"
tar -xf "$DOWNLOAD_DIR/$X264_ARCHIVE" -C "$SOURCE_DIR"

X264_PREFIX="$BUILD_DIR/x264"
PKG_CONFIG_SHIM="$ROOT/scripts/x264-pkg-config.sh"
rm -rf "$X264_PREFIX"
mkdir -p "$X264_PREFIX"
(
    cd "$SOURCE_DIR/x264-$X264_COMMIT"
    CC="$(xcrun --find clang)" \
    ./configure \
        --prefix="$X264_PREFIX" \
        --sysroot="$MACOS_SDK" \
        --extra-cflags="-arch arm64 -mmacosx-version-min=13.0" \
        --extra-ldflags="-arch arm64 -mmacosx-version-min=13.0" \
        --enable-static \
        --disable-cli \
        --disable-opencl \
        --disable-asm
    make -j"$(sysctl -n hw.logicalcpu)"
    make install
)

rm -rf "$OUTPUT_DIR"
mkdir -p "$OUTPUT_DIR"
(
    cd "$SOURCE_DIR/ffmpeg-$FFMPEG_VERSION"
    X264_PREFIX="$X264_PREFIX" \
    ./configure \
        --prefix="$OUTPUT_DIR" \
        --arch=arm64 \
        --target-os=darwin \
        --cc="$(xcrun --find clang)" \
        --sysroot="$MACOS_SDK" \
        --host-cc="$(xcrun --find clang)" \
        --host-cflags="--sysroot=$MACOS_SDK -mmacosx-version-min=13.0" \
        --host-ldflags="--sysroot=$MACOS_SDK -mmacosx-version-min=13.0" \
        --pkg-config="$PKG_CONFIG_SHIM" \
        --pkg-config-flags="--static" \
        --extra-cflags="-arch arm64 -mmacosx-version-min=13.0 -I$X264_PREFIX/include" \
        --extra-ldflags="-arch arm64 -mmacosx-version-min=13.0 -L$X264_PREFIX/lib" \
        --enable-gpl \
        --enable-version3 \
        --enable-libx264 \
        --enable-static \
        --disable-shared \
        --disable-debug \
        --disable-doc \
        --disable-ffplay \
        --disable-sdl2 \
        --enable-audiotoolbox \
        --enable-videotoolbox \
        --enable-avfoundation \
        --enable-securetransport
    make -j"$(sysctl -n hw.logicalcpu)"
    make install
)

strip -x "$OUTPUT_DIR/bin/ffmpeg" "$OUTPUT_DIR/bin/ffprobe"

file "$OUTPUT_DIR/bin/ffmpeg" "$OUTPUT_DIR/bin/ffprobe"
CAPABILITIES_DIR="$WORK_DIR/capabilities"
mkdir -p "$CAPABILITIES_DIR"
"$OUTPUT_DIR/bin/ffmpeg" -hide_banner -encoders > "$CAPABILITIES_DIR/encoders.txt"
"$OUTPUT_DIR/bin/ffmpeg" -hide_banner -filters > "$CAPABILITIES_DIR/filters.txt"
grep -q libx264 "$CAPABILITIES_DIR/encoders.txt"
grep -q overlay "$CAPABILITIES_DIR/filters.txt"
grep -q afade "$CAPABILITIES_DIR/filters.txt"
"$OUTPUT_DIR/bin/ffprobe" -version >/dev/null

cp "$DOWNLOAD_DIR/$FFMPEG_ARCHIVE" "$OUTPUT_DIR/"
cp "$DOWNLOAD_DIR/$X264_ARCHIVE" "$OUTPUT_DIR/"
(
    cd "$OUTPUT_DIR"
    shasum -a 256 \
        "bin/ffmpeg" \
        "bin/ffprobe" \
        "$FFMPEG_ARCHIVE" \
        "$X264_ARCHIVE" > SHA256SUMS
)

echo "$OUTPUT_DIR"
