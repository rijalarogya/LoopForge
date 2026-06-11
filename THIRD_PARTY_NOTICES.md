# Third-Party Notices

LoopForge is MIT-licensed software. The release bundle also contains separate
FFmpeg and x264 executables invoked as child processes.

## FFmpeg and x264

The distributed FFmpeg build enables `libx264` and is therefore provided under
the GNU General Public License version 3 or later. It is not covered by the
LoopForge MIT license.

Release downloads include:

- The exact FFmpeg and x264 source archives used for the build.
- SHA-256 checksums for source archives and bundled executables.
- [`scripts/build-ffmpeg.sh`](scripts/build-ffmpeg.sh), containing the complete
  build configuration.
- The GPLv3 license text and pinned build information.

FFmpeg: <https://ffmpeg.org/>

x264: <https://www.videolan.org/developers/x264.html>

GPLv3: <https://www.gnu.org/licenses/gpl-3.0.html>

Commercial distributors should obtain independent legal advice concerning
their obligations for all included codecs and third-party software.
