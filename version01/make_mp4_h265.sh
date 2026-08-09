#!/bin/bash

# Hagen@gloetter.de 2020
# Optimierte Version 2024

# Beende das Skript bei Fehlern oder unbenutzten Variablen
set -euo pipefail

# Schaltet nullglob ein, damit Globbing-Pattern zu leeren Arrays werden, wenn keine Treffer vorhanden sind
shopt -s nullglob

_self="${0##*/}"
echo "$_self is called"

# Argumente überprüfen
if [[ $# -lt 2 ]]; then
    echo "Usage: $(basename "$0") [foldername] [soundfile]"
    exit 1
fi

# Variablen festlegen
DIR_SRCIMG="$1"
FN_SOUND="$2"
DIR_MP4="h265"
EXT="jpg"

# Überprüfen, ob ffmpeg installiert ist
if ! command -v ffmpeg &>/dev/null; then
    echo "ffmpeg NOT found"
    exit 1
fi

FFMPEG=$(command -v ffmpeg) # Initialisiere FFMPEG korrekt

# Überprüfen, ob das Quellbildverzeichnis existiert
if [ ! -d "$DIR_SRCIMG" ]; then
    echo "Error: Directory ${DIR_SRCIMG} not found --> EXIT."
    exit 1
fi

# Count images and calculate video duration
images=("$DIR_SRCIMG"/*.$EXT)
image_count=${#images[@]}
if [ "$image_count" -eq 0 ]; then
    echo "No images found in $DIR_SRCIMG"
    exit 1
fi

video_duration=$(( image_count / 24 ))

# Ausgabe-Dateien
timestamp=$(date +"-%Y-%m-%d--%H-%M")
OutFile720="$DIR_SRCIMG/$DIR_MP4/ffmpeg-timelapse_${timestamp}_720p.mp4"
OutFile1080="$DIR_SRCIMG/$DIR_MP4/ffmpeg-timelapse_${timestamp}_1080p.mp4"

# Funktion, um ein Verzeichnis zu überprüfen und zu erstellen
check_and_create_DIR() {
    DIR=$1
    if [ ! -d "$DIR" ]; then
        echo "Info: ${DIR} not found. Creating."
        mkdir -p "$DIR"
    fi
}

# Ausgabe-Verzeichnis erstellen
check_and_create_DIR "$DIR_SRCIMG/$DIR_MP4"

# Create a temp file for fade-out audio trimmed to video length
temp_audio=$(mktemp).mp3
trap 'rm -f "$temp_audio"' EXIT

fade_start=$(( video_duration - 3 ))
$FFMPEG -i "$FN_SOUND" -af "afade=t=out:st=${fade_start}:d=3" -t "$video_duration" -y "$temp_audio"

echo "-----------------------------------------"
echo "Source:  $DIR_SRCIMG/*.$EXT  ($image_count images, ~${video_duration}s)"
echo "Audio:   $FN_SOUND"
echo "Output:  $OutFile720  |  $OutFile1080"
echo "-----------------------------------------"

# Run ffmpeg directly with arrays to avoid eval and prevent injection via filenames
"$FFMPEG" -thread_queue_size 1024 -framerate 24 -pattern_type glob \
  -i "$DIR_SRCIMG/*.$EXT" -i "$temp_audio" \
  -c:v libx265 -pix_fmt yuv420p -flags global_header -shortest \
  -vf scale=-2:720 "$OutFile720"

"$FFMPEG" -thread_queue_size 1024 -framerate 24 -pattern_type glob \
  -i "$DIR_SRCIMG/*.$EXT" -i "$temp_audio" \
  -c:v libx265 -pix_fmt yuv420p -flags global_header -shortest \
  -vf scale=-2:1080 "$OutFile1080"

echo "Video creation completed successfully."
