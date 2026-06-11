# Releasing LoopForge

## Unsigned early tester release

- Apple-silicon Mac with Xcode 16 or newer.
- Authenticated GitHub CLI or equivalent GitHub access.

### Prepare

```sh
swift test
./scripts/build-ffmpeg.sh
./scripts/package-unsigned-release.sh
```

Confirm the tool validation checks pass and inspect
`Vendor/ffmpeg/arm64/SHA256SUMS`.

The unsigned release directory is `dist/release-1.0.0-unsigned`. It contains
clearly labeled ZIP and DMG downloads, SHA-256 checksums, licenses, build
scripts, bundled media binaries, and corresponding source archives.

### GitHub Release checklist

- [ ] Run the complete Swift test suite.
- [ ] Build FFmpeg from the pinned sources or verify the existing clean build.
- [ ] Run `./scripts/package-unsigned-release.sh`.
- [ ] Confirm `codesign -dvvv dist/LoopForge.app` reports `Signature=adhoc`,
      `TeamIdentifier=not set`, and no `Authority=` entry.
- [ ] Verify the DMG with `hdiutil verify`.
- [ ] Verify `SHA256SUMS` and `FFmpeg-SHA256SUMS`.
- [ ] Install from the packaged ZIP or DMG and complete a real render.
- [ ] Create a prerelease tag such as `v1.0.0-early.1`.
- [ ] Mark the GitHub Release as a **pre-release**.
- [ ] Put **Unsigned early tester build** at the top of the release notes.
- [ ] Upload the files from `dist/release-1.0.0-unsigned`.
- [ ] Include the right-click Open and Privacy & Security instructions.

Do not label an unsigned build as a stable or notarized release.

The app receives a free ad-hoc bundle seal so its downloaded structure can be
verified. This does not identify or verify the developer and does not replace
Developer ID signing. The unsigned packaging script verifies that no Developer
ID authority or team identifier is present.

## Future Developer ID release

The paid signing path is retained for a future release. It requires an active
Apple Developer Program membership, a Developer ID Application certificate,
and `notarytool` credentials stored in a Keychain profile.

### Sign and package

```sh
export LOOPFORGE_SIGNING_IDENTITY="Developer ID Application: Name (TEAMID)"
./scripts/package-release.sh
```

The app assembly script signs FFmpeg and ffprobe first, then signs LoopForge
with hardened runtime and verifies the nested signature.

### Notarize

```sh
xcrun notarytool store-credentials LoopForgeNotary
export LOOPFORGE_NOTARY_PROFILE="LoopForgeNotary"
./scripts/notarize.sh dist/LoopForge-1.0.0-arm64.dmg
```

The script waits for notarization, staples the ticket, validates it, runs
Gatekeeper assessment, and refreshes the DMG checksum.

### Publish

1. Test the stapled DMG on a clean macOS 13+ Apple-silicon account.
2. Confirm the app opens without Homebrew and completes a real render.
3. Tag the exact commit as `v1.0.0`.
4. Create a GitHub Release from that tag.
5. Upload every file in `dist/release-1.0.0`.
6. Do not publish an unsigned or unstapled artifact as a stable release.
