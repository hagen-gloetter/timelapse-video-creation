#!/bin/bash
# setup_venv.sh
# Erzeugt ein Python-venv und installiert alle Pakete für astrobilder_whitebalance.py.
# Funktioniert unter Linux, macOS und Windows (Git Bash).

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VENV_DIR="$SCRIPT_DIR/venv"

# --- Python-Interpreter finden (muss tatsächlich ausführbar sein) ---
PYTHON=""
for candidate in python3.13 python3.12 python3.11 python3.10 python3 python; do
    if command -v "$candidate" &>/dev/null && "$candidate" --version &>/dev/null 2>&1; then
        PYTHON=$(command -v "$candidate")
        break
    fi
done

if [ -z "$PYTHON" ]; then
    echo "Fehler: Kein funktionierendes Python gefunden."
    echo "WSL/Ubuntu:  sudo apt install python3 python3-venv"
    echo "macOS:       brew install python"
    echo "Windows:     https://www.python.org/downloads/"
    exit 1
fi
echo "Python: $PYTHON  ($("$PYTHON" --version))"

# --- venv anlegen (oder neu anlegen wenn activate-Script fehlt) ---
# Aktivierungsskript: Windows (Git Bash) = Scripts/, Linux/macOS = bin/
ACTIVATE="$VENV_DIR/Scripts/activate"
[ -f "$ACTIVATE" ] || ACTIVATE="$VENV_DIR/bin/activate"

if [ ! -f "$ACTIVATE" ]; then
    # Verzeichnis ggf. von fehlgeschlagenem Vorlauf bereinigen
    [ -d "$VENV_DIR" ] && rm -rf "$VENV_DIR"
    echo "Erzeuge venv in $VENV_DIR ..."
    "$PYTHON" -m venv "$VENV_DIR"
    # Pfad nach Neuanlage neu bestimmen
    ACTIVATE="$VENV_DIR/Scripts/activate"
    [ -f "$ACTIVATE" ] || ACTIVATE="$VENV_DIR/bin/activate"
else
    echo "venv existiert bereits -> Pakete werden aktualisiert."
fi

# shellcheck source=/dev/null
source "$ACTIVATE"

# --- Pakete installieren ---
echo "Installiere Pakete ..."
pip install --upgrade pip
pip install \
    Pillow \
    numpy \
    tqdm

echo ""
echo "Installation abgeschlossen."
echo ""
echo "Script aufrufen mit:"
echo "  Windows (Git Bash): venv/Scripts/python astrobilder_whitebalance.py <bildordner>"
echo "  Linux / macOS:      venv/bin/python     astrobilder_whitebalance.py <bildordner>"
echo ""
echo "Beispiel:"
echo '  venv/Scripts/python astrobilder_whitebalance.py "C:\Seestar\2026_Zeitraffer\2026-08-07-WehrlewegMilchstrasse"'
