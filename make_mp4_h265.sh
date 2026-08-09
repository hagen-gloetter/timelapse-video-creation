#!/bin/bash

# Hagen@gloetter.de 2020
# Erstellt ein H.265/HEVC-Timelapse-Video aus einem Ordner mit JPEG-Einzelbildern.
# Der Audio-Track wird automatisch auf die Videolänge gekürzt und mit Fade-Out versehen.
# Im Vergleich zu H.264 (make_mp4.sh) erzeugt H.265 bei gleicher Qualität kleinere Dateien,
# benötigt aber mehr Rechenzeit beim Encoding und ggf. Hardware-Unterstützung bei der Wiedergabe.
#
# Verwendung: ./make_mp4_h265.sh <Bildordner> <Audiodatei>

# Skript bricht bei Fehlern (-e), undeklarierten Variablen (-u) und fehlgeschlagenen Pipes (-o pipefail) ab.
set -euo pipefail

# nullglob: Glob-Muster, die auf keine Datei passen, werden zu einem leeren Array statt als
# Literal-String weitergegeben. Verhindert, dass ffmpeg einen Dateinamen wie "*.jpg" bekommt.
shopt -s nullglob

_self="${0##*/}"
echo "$_self is called"

# --- Argumente prüfen ---
# Beide Argumente sind Pflicht; Sound ist erforderlich für den Fade-Out-Trimmer.
if [[ $# -lt 2 ]]; then
    echo "Usage: $(basename "$0") <foldername> <soundfile>"
    exit 1
fi

# --- Konfiguration ---
DIR_SRCIMG="$1"   # Ordner mit den Quellbildern
FN_SOUND="$2"     # Audiodatei
DIR_MP4="h265"    # Unterordner für die fertigen Videos
EXT="jpg"         # Dateiendung der Quellbilder
FRAMERATE=24      # Bilder pro Sekunde; bestimmt die Abspielgeschwindigkeit
CRF=28            # H.265-Qualität: niedriger = besser / größer (Bereich 0–51, Standard 28)

# --- Abhängigkeiten prüfen ---
# `command -v` ist portabler als `which` und schlägt sauber fehl wenn ffmpeg fehlt.
if ! command -v ffmpeg &>/dev/null; then
    echo "ffmpeg NOT found"
    exit 1
fi
FFMPEG=$(command -v ffmpeg)

# --- Eingaben validieren ---
if [ ! -d "$DIR_SRCIMG" ]; then
    echo "Error: Directory ${DIR_SRCIMG} not found --> EXIT."
    exit 1
fi

if [ ! -f "$FN_SOUND" ]; then
    echo "Error: Sound file not found: $FN_SOUND --> EXIT."
    exit 1
fi

# Bilder in ein Array einlesen; bei nullglob bleibt das Array leer wenn nichts passt.
images=("$DIR_SRCIMG"/*.$EXT)
image_count=${#images[@]}
if [ "$image_count" -eq 0 ]; then
    echo "Error: No .$EXT images found in $DIR_SRCIMG --> EXIT."
    exit 1
fi

# Videolänge in Sekunden (Ganzzahl-Division reicht für den Audio-Trimmer).
video_duration=$(( image_count / FRAMERATE ))
if [ "$video_duration" -eq 0 ]; then
    echo "Error: Too few images (${image_count}) for a 1-second video at ${FRAMERATE} fps --> EXIT."
    exit 1
fi

# --- Ausgabepfade zusammenbauen ---
# Zeitstempel im Dateinamen verhindert versehentliches Überschreiben.
timestamp=$(date +"-%Y-%m-%d--%H-%M")
OutFile720="$DIR_SRCIMG/$DIR_MP4/ffmpeg-timelapse_${timestamp}_720p.mp4"
OutFile1080="$DIR_SRCIMG/$DIR_MP4/ffmpeg-timelapse_${timestamp}_1080p.mp4"

# --- Hilfsfunktion: Ausgabeordner anlegen ---
check_and_create_DIR() {
    local DIR="$1"
    if [ ! -d "$DIR" ]; then
        echo "Info: ${DIR} not found. Creating."
        mkdir -p "$DIR"
    fi
}

check_and_create_DIR "$DIR_SRCIMG/$DIR_MP4"

# --- Audio vorbereiten ---
# mktemp erzeugt eine eindeutige temporäre Datei; die .mp3-Endung ist für ffmpeg erforderlich.
# trap stellt sicher, dass die Temp-Datei auch bei Fehlern oder Abbruch gelöscht wird.
temp_audio=$(mktemp).mp3
trap 'rm -f "$temp_audio"' EXIT

# Fade-Out beginnt 3 Sekunden vor Ende; bei sehr kurzen Videos (< 3 s) direkt am Anfang.
fade_start=$(( video_duration > 3 ? video_duration - 3 : 0 ))

# Audio kürzen und Fade-Out einbauen:
#   afade=t=out       : Fade-Richtung Ausblenden
#   st=<sekunde>      : Fade-Start in Sekunden ab Beginn
#   d=3               : Fade-Dauer 3 Sekunden
#   -t $video_duration: Audio hart auf Videolänge schneiden
#   -y                : Ausgabedatei ohne Rückfrage überschreiben
"$FFMPEG" -i "$FN_SOUND" -af "afade=t=out:st=${fade_start}:d=3" -t "$video_duration" -y "$temp_audio"

echo "-----------------------------------------"
echo "Source:   $DIR_SRCIMG/*.$EXT  ($image_count images, ~${video_duration}s @ ${FRAMERATE}fps)"
echo "Audio:    $FN_SOUND  (trimmed + fade-out -> $temp_audio)"
echo "Output:   $OutFile720"
echo "          $OutFile1080"
echo "-----------------------------------------"

# --- Video rendern (Single-Pass) ---
# ffmpeg wird direkt mit Argumenten aufgerufen — kein eval, kein String-Interpolieren.
# Das verhindert Command-Injection durch Sonderzeichen in Datei- oder Ordnernamen.
#
# split=2 teilt den dekodierten Video-Stream auf zwei Zweige auf; jedes Bild wird
# nur einmal gelesen und dekodiert statt zweimal (einmal pro Auflösung).
# scale=-2:<h>: Skaliert auf Zielhöhe; Breite automatisch berechnet, auf gerades Vielfaches gerundet.
filter_complex="[0:v]split=2[v720][v1080];[v720]scale=-2:720[out720];[v1080]scale=-2:1080[out1080]"

# -thread_queue_size 1024: Eingabe-Puffer; verhindert "Thread queue is blocking" bei vielen Bildern.
# -framerate $FRAMERATE:   Bilder pro Sekunde; bestimmt die Abspielgeschwindigkeit des Timelapses.
# -pattern_type glob:      ffmpeg expandiert das *.jpg-Muster selbst — die Shell darf es NICHT
#                          vorher expandieren, deshalb steht der Pfad in Anführungszeichen.
# -c:v libx265:            H.265/HEVC-Encoder — kleinere Dateien als H.264 bei gleicher Qualität.
# -c:a aac:                Audio in AAC re-encodieren — MP3 direkt in MP4 ist nicht überall abspielbar.
# -crf $CRF:               Qualitätsstufe (Constant Rate Factor); niedrigerer Wert = besser / größer.
# -pix_fmt yuv420p:        Pixel-Format für maximale Kompatibilität (z.B. Apple-Geräte, ältere Player).
# -flags global_header:    Header-Informationen im Container ablegen (nötig für einige Player).
# -shortest:               Encoding endet, wenn der kürzere Stream (Video oder Audio) fertig ist.
"$FFMPEG" -thread_queue_size 1024 -framerate "$FRAMERATE" -pattern_type glob \
  -i "$DIR_SRCIMG/*.$EXT" -i "$temp_audio" \
  -filter_complex "$filter_complex" \
  -map "[out720]"  -map "1:a" -c:v libx265 -c:a aac -crf "$CRF" -pix_fmt yuv420p -flags global_header -shortest "$OutFile720" \
  -map "[out1080]" -map "1:a" -c:v libx265 -c:a aac -crf "$CRF" -pix_fmt yuv420p -flags global_header -shortest "$OutFile1080"

echo "Video creation completed successfully."
