# timelapse-video-creation

Create timelapse MP4 videos (H.264 or H.265/HEVC) from a stack of JPEG images using `ffmpeg` on Linux/macOS.

## Requirements

- `bash` ≥ 4.0
- `ffmpeg` (available in `$PATH`)

## Scripts

| Script | Codec | Sound |
|---|---|---|
| `make_mp4.sh` | H.264 (libx264) | optional |
| `make_mp4_h265.sh` | H.265/HEVC (libx265) | required |

## Usage

### H.264 — `make_mp4.sh`

```bash
./make_mp4.sh <image-folder> [soundfile]
```

- `<image-folder>` — directory containing `.jpg` source frames (required)
- `[soundfile]` — audio file to mix in (optional)

Outputs `h264/ffmpeg-timelapse-<timestamp>_720p.mp4` and `_1080p.mp4` inside `<image-folder>`.

### H.265 — `make_mp4_h265.sh`

```bash
./make_mp4_h265.sh <image-folder> <soundfile>
```

Both arguments are required. The audio is automatically trimmed with a 3-second fade-out to match the video length.

Outputs `h265/ffmpeg-timelapse-<timestamp>_720p.mp4` and `_1080p.mp4` inside `<image-folder>`.

## Configuration

Edit the following variables at the top of each script to change defaults:

| Variable | Default | Description |
|---|---|---|
| `EXT` | `jpg` | Image file extension |
| `DIR_MP4` | `h264` / `h265` | Output subdirectory name |
| Framerate | `24` | Frames per second (passed to `-framerate`) |

## Sample Music

The `music/` directory contains royalty-free MP3 tracks for testing.

## Known Caveats

- Images must be sortable by filename to produce the correct frame order.
- `make_mp4_h265.sh` requires both a source folder and a sound file; use `/dev/null` or a silent MP3 if no audio is needed.
- H.265 output may not be playable on older devices or browsers without hardware decoding support.

