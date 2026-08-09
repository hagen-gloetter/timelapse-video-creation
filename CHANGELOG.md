# Changelog

All notable changes to this project will be documented in this file.
Format follows [Keep a Changelog](https://keepachangelog.com/), versioning follows [Semantic Versioning](https://semver.org/).

## [Unreleased]

### Security
- **[High] `make_mp4.sh`** — Replaced `eval` on user-controlled command strings with direct `ffmpeg` invocation using a bash array. Filenames and sound file paths containing shell metacharacters could previously trigger command injection.
- **[High] `make_mp4_h265.sh`** — Same `eval`-based injection vector removed; `ffmpeg` is now called directly without string interpolation.

### Fixed
- **`make_mp4.sh`** — Undefined variable `$baseDir` caused a crash on exit (`cd "$baseDir" || exit 1`); removed the now-unnecessary `cd`.
- **`make_mp4.sh`** — Undefined variable `$OutFile` was printed in the status block; replaced with the defined `$OutFile720` / `$OutFile1080`.
- **`make_mp4.sh`** — Output filenames contained the typo "timeleape"; corrected to "timelapse".
- **`make_mp4.sh`** — Output subdirectory was hardcoded as `h265` in the H.264 script; changed to `h264`.
- **`make_mp4_h265.sh`** — Temporary audio file was not deleted on script failure; replaced `rm` call with a `trap … EXIT` handler.
- **`make_mp4_h265.sh`** — `ls` used to count images would exit non-zero under `set -e` when the glob matched nothing; replaced with a bash array.

### Changed
- **`make_mp4.sh`** — Added `set -euo pipefail` for fail-fast behaviour.
- **`make_mp4.sh`** — Removed large block of dead commented-out `ffmpeg` experiments.
- **`make_mp4_h265.sh`** — Replaced `bc` arithmetic with native bash `$(( ))` expressions (removes `bc` dependency).
- **`make_mp4_h265.sh`** — Fade-start calculation now uses bash integer arithmetic; `bc` dependency removed.

### Added
- **`README.md`** — Expanded from two lines to a full project description covering requirements, usage, configuration, and known caveats.
- **`CHANGELOG.md`** — This file.

## [1.0.0] — 2024-01-01

### Added
- Initial `make_mp4.sh` (H.264) and `make_mp4_h265.sh` (H.265) scripts.
- Sample royalty-free music in `music/`.
