#!/bin/bash

# Hagen@gloetter.de 2020
# Erstellt ein H.264-Timelapse-Video aus einem Ordner mit JPEG-Einzelbildern.
# Optional kann eine Audiodatei eingemischt werden.
#
# Verwendung: ./make_mp4.sh <Bildordner> [Audiodatei]
#
# Referenzen:
#   https://trac.ffmpeg.org/wiki/Slideshow
#   http://hamelot.io/visualization/using-ffmpeg-to-convert-a-set-of-images-into-a-video/

# Skript bricht bei Fehlern (-e), undeklarierten Variablen (-u) und fehlgeschlagenen Pipes (-o pipefail) ab.
set -euo pipefail

# nullglob: Glob-Muster, die auf keine Datei passen, werden zu einem leeren Array statt als
# Literal-String weitergegeben. Verhindert, dass ffmpeg einen Dateinamen wie "*.jpg" bekommt.
shopt -s nullglob

_self="${0##*/}"
echo "$_self is called"

# --- Argumente prüfen ---
if [[ $# -lt 1 ]]; then
    echo "Usage: $(basename "$0") <foldername> [soundfile]"
    exit 1
fi

# --- Konfiguration ---
DIR_SRCIMG="$1"   # Ordner mit den Quellbildern
DIR_MP4="h264"    # Unterordner für die fertigen Videos
EXT="jpg"         # Dateiendung der Quellbilder
FN_SOUND=""       # Audiodatei (optional)
FRAMERATE=24      # Bilder pro Sekunde; bestimmt die Abspielgeschwindigkeit
CRF=23            # H.264-Qualität: niedriger = besser / größer (Bereich 0–51, Standard 23)

if [[ $# -ge 2 ]]; then
    FN_SOUND="$2"
    echo "Soundfile used: $FN_SOUND"
fi

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

# Bilder in ein Array einlesen; bei nullglob bleibt das Array leer wenn nichts passt.
images=("$DIR_SRCIMG"/*.$EXT)
if [ ${#images[@]} -eq 0 ]; then
    echo "Error: No .$EXT images found in $DIR_SRCIMG --> EXIT."
    exit 1
fi

if [[ -n "$FN_SOUND" && ! -f "$FN_SOUND" ]]; then
    echo "Error: Sound file not found: $FN_SOUND --> EXIT."
    exit 1
fi

# --- Ausgabepfade zusammenbauen ---
# Zeitstempel im Dateinamen verhindert versehentliches Überschreiben.
timestamp=$(date +"-%Y-%m-%d--%H-%M")
OutFile720="$DIR_SRCIMG/$DIR_MP4/ffmpeg-timelapse${timestamp}_720p.mp4"
OutFile1080="$DIR_SRCIMG/$DIR_MP4/ffmpeg-timelapse${timestamp}_1080p.mp4"

# --- Hilfsfunktion: Ausgabeordner anlegen ---
check_and_create_DIR() {
    local DIR="$1"
    if [ ! -d "$DIR" ]; then
        mkdir -p "$DIR"
        echo "Info: ${DIR} not found. Creating."
    else
        echo "${DIR} exists -> OK"
    fi
    # Zweite Prüfung fängt den Fall ab, dass mkdir trotzdem fehlschlägt (z.B. Berechtigungen).
    if [ ! -d "$DIR" ]; then
        echo "Error: ${DIR} CANNOT BE CREATED --> EXIT."
        exit 1
    fi
}

check_and_create_DIR "$DIR_SRCIMG/$DIR_MP4"

echo "-----------------------------------------"
echo "Processing Dir: $DIR_SRCIMG"
echo "Images:   ${#images[@]} x .$EXT"
echo "OutFile720=$OutFile720"
echo "OutFile1080=$OutFile1080"
echo "Sound=${FN_SOUND:-<none>}"
echo "-----------------------------------------"

# --- Video rendern (Single-Pass) ---
# split=2 teilt den dekodierten Video-Stream auf zwei Zweige auf; jedes Bild wird
# nur einmal gelesen und dekodiert statt zweimal (einmal pro Auflösung).
# scale=-2:<h>: Skaliert auf Zielhöhe; Breite automatisch berechnet, auf gerades Vielfaches gerundet.
filter_complex="[0:v]split=2[v720][v1080];[v720]scale=-2:720[out720];[v1080]scale=-2:1080[out1080]"

# Optionale Audio-Argumente als Arrays; Argumente zwischen zwei Ausgabepfaden gelten nur für den jeweiligen Output.
audio_input=()
audio_map=()
audio_codec=()
shortest=()
if [[ -n "$FN_SOUND" ]]; then
    audio_input=(-i "$FN_SOUND")
    audio_map=(-map "1:a")
    # -c:a aac: Audio in AAC re-encodieren — MP3 direkt in MP4 ist nicht überall abspielbar.
    audio_codec=(-c:a aac)
    # -shortest: Encoding endet, wenn der kürzere Stream (Video oder Audio) fertig ist.
    shortest=(-shortest)
fi

# -thread_queue_size: Puffergröße für Eingabe-Threads; verhindert "Thread queue is blocking".
# -framerate $FRAMERATE: Bilder pro Sekunde; bestimmt die Abspielgeschwindigkeit des Timelapses.
# -pattern_type glob:    ffmpeg expandiert das *.jpg-Muster selbst — Shell darf es NICHT vorher expandieren.
# -c:v libx264:          H.264-Encoder — breite Kompatibilität mit Geräten und Browsern.
# -crf $CRF:             Qualitätsstufe (Constant Rate Factor); niedrigerer Wert = besser / größer.
# -pix_fmt yuv420p:      Pixel-Format für maximale Kompatibilität (QuickTime, ältere Geräte).
# -flags global_header:  Header im Container ablegen (nötig für einige Player).
"$FFMPEG" -thread_queue_size 1024 -framerate "$FRAMERATE" -pattern_type glob \
  -i "$DIR_SRCIMG/*.$EXT" "${audio_input[@]}" \
  -filter_complex "$filter_complex" \
  -map "[out720]"  "${audio_map[@]}" -c:v libx264 "${audio_codec[@]}" -crf "$CRF" -pix_fmt yuv420p -flags global_header "${shortest[@]}" "$OutFile720" \
  -map "[out1080]" "${audio_map[@]}" -c:v libx264 "${audio_codec[@]}" -crf "$CRF" -pix_fmt yuv420p -flags global_header "${shortest[@]}" "$OutFile1080"

echo "Video creation completed successfully."

