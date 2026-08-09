#!/bin/bash

# Hagen@gloetter.de 2020
# ideas taken from:
#   https://trac.ffmpeg.org/wiki/Slideshow
#   http://hamelot.io/visualization/using-ffmpeg-to-convert-a-set-of-images-into-a-video/

set -euo pipefail
shopt -s nullglob

_self="${0##*/}"
echo "$_self is called"

if [[ $# -lt 1 ]]; then
    echo "Usage: $(basename "$0") <foldername> [soundfile]"
    exit 1
fi

DIR_SRCIMG="$1"
DIR_MP4="h264"
EXT="jpg"
FN_SOUND=""

if [[ $# -ge 2 ]]; then
    FN_SOUND="$2"
    echo "Soundfile used: $FN_SOUND"
fi

if ! command -v ffmpeg &>/dev/null; then
    echo "ffmpeg NOT found"
    exit 1
fi
FFMPEG=$(command -v ffmpeg)

if [ ! -d "$DIR_SRCIMG" ]; then
    echo "Error: Directory ${DIR_SRCIMG} not found --> EXIT."
    exit 1
fi

timestamp=$(date +"-%Y-%m-%d--%H-%M")
OutFile720="$DIR_SRCIMG/$DIR_MP4/ffmpeg-timelapse${timestamp}_720p.mp4"
OutFile1080="$DIR_SRCIMG/$DIR_MP4/ffmpeg-timelapse${timestamp}_1080p.mp4"

check_and_create_DIR() {
    local DIR="$1"
    if [ ! -d "$DIR" ]; then
        mkdir -p "$DIR"
        echo "Info: ${DIR} not found. Creating."
    else
        echo "${DIR} exists -> OK"
    fi
    if [ ! -d "$DIR" ]; then
        echo "Error: ${DIR} CANNOT BE CREATED --> EXIT."
        exit 1
    fi
}

check_and_create_DIR "$DIR_SRCIMG/$DIR_MP4"

echo "-----------------------------------------"
echo "Processing Dir: $DIR_SRCIMG"
echo "OutFile720=$OutFile720"
echo "OutFile1080=$OutFile1080"
echo "Sound=${FN_SOUND:-<none>}"
echo "-----------------------------------------"

# Build sound args array to avoid eval and prevent injection via filenames
sound_args=()
if [[ -n "$FN_SOUND" ]]; then
    sound_args=(-i "$FN_SOUND" -shortest)
fi

base_args=(-thread_queue_size 1024 -framerate 24 -pattern_type glob -i "$DIR_SRCIMG/*.$EXT")
video_args=(-c:v libx264 -acodec copy -flags global_header -pix_fmt yuv420p)

"$FFMPEG" "${base_args[@]}" "${sound_args[@]}" "${video_args[@]}" -s 1280x720  "$OutFile720"
"$FFMPEG" "${base_args[@]}" "${sound_args[@]}" "${video_args[@]}" -s 1920x1080 "$OutFile1080"

echo "Video creation completed successfully."

