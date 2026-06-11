# Contributing

## Development requirements

- macOS 13 or newer
- Xcode 16 or newer
- Swift 6 toolchain
- FFmpeg and ffprobe for the real render test

## Workflow

1. Create a focused branch.
2. Keep model output constrained to intent JSON. Never execute model-generated
   shell commands.
3. Add tests for deterministic planning, validation, or FFmpeg argument changes.
4. Run `swift test`.
5. Run `./scripts/build-ffmpeg.sh` only when changing the pinned media toolchain.
6. Do not commit generated apps, DMGs, media binaries, certificates, or secrets.

Release builds are Apple-silicon-only for version 1.0.0.
