# Releasing LoopForge

## Prerequisites

- Apple-silicon Mac with Xcode 16 or newer.
- Active Apple Developer Program membership.
- Developer ID Application certificate installed in the login Keychain.
- `notarytool` credentials stored in a Keychain profile.
- Authenticated GitHub CLI or equivalent GitHub access.

## Prepare

```sh
swift test
./scripts/build-ffmpeg.sh
```

Confirm the tool validation checks pass and inspect
`Vendor/ffmpeg/arm64/SHA256SUMS`.

## Sign and package

```sh
export LOOPFORGE_SIGNING_IDENTITY="Developer ID Application: Name (TEAMID)"
./scripts/package-release.sh
```

The app assembly script signs FFmpeg and ffprobe first, then signs LoopForge
with hardened runtime and verifies the nested signature.

## Notarize

```sh
xcrun notarytool store-credentials LoopForgeNotary
export LOOPFORGE_NOTARY_PROFILE="LoopForgeNotary"
./scripts/notarize.sh dist/LoopForge-1.0.0-arm64.dmg
```

The script waits for notarization, staples the ticket, validates it, runs
Gatekeeper assessment, and refreshes the DMG checksum.

## Publish

1. Test the stapled DMG on a clean macOS 13+ Apple-silicon account.
2. Confirm the app opens without Homebrew and completes a real render.
3. Tag the exact commit as `v1.0.0`.
4. Create a GitHub Release from that tag.
5. Upload every file in `dist/release-1.0.0`.
6. Do not publish an unsigned or unstapled artifact as a stable release.
