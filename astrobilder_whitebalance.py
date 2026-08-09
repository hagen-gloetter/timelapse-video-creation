#!/usr/bin/env python3
"""
astrobilder_whitebalance.py

Gray-World-Weißabgleich für Astro-Zeitraffer-Bilder.

Ablauf:
  1. Alle JPEG/PNG-Bilder im angegebenen Ordner einlesen (sortiert nach Name)
  2. 3 Bilder aus der Mitte als Referenz wählen (Mitte der Nacht = ohne Dämmerung)
  3. Gray-World-Weißabgleich je Referenzbild berechnen → Ergebnisse mitteln
  4. Korrekturfaktoren auf alle Bilder anwenden
  5. Korrigierte Bilder  →  <ordner>/02_Whitebalance/
  6. Originalbilder      →  <ordner>/01_vonKamera/    (verschoben, nicht kopiert)

Verwendung:
  python astrobilder_whitebalance.py <bildordner>
"""

import sys
import shutil
from pathlib import Path
from typing import List, Optional, Tuple

import numpy as np
from PIL import Image
from tqdm import tqdm

# ---------------------------------------------------------------------------
# Konfiguration
# ---------------------------------------------------------------------------
IMAGE_EXTENSIONS = {".jpg", ".jpeg", ".png"}   # case-insensitive geprüft
DIR_ORIGINAL     = "01_vonKamera"
DIR_OUTPUT       = "02_Whitebalance"
N_REFERENCE      = 3       # Anzahl der Referenzbilder aus der Mitte

JPEG_QUALITY     = 95      # Ausgabe-Qualität für JPEG (1–95)

# Helligkeitsbereich (0.0–1.0) der für den Gray-World-Mittelwert verwendet wird.
# Nur den dunklen Himmelshintergrund als Referenz verwenden: Sterne und Milchstraße
# sind von Natur aus warm/orange (echte Sternfarben) und dürfen den Referenzwert
# nicht beeinflussen — sonst entsteht ein Braun-/Warmstich im Ergebnis.
# Für Nicht-Astro-Bilder: TRIM_HIGH auf 0.90 erhöhen.
TRIM_LOW  = 0.05
TRIM_HIGH = 0.25


# ---------------------------------------------------------------------------
# Hilfsfunktionen
# ---------------------------------------------------------------------------

def find_images(folder: Path) -> List[Path]:
    """Alle Bilder im Ordner einlesen, nach Dateiname sortiert."""
    return sorted(
        f for f in folder.iterdir()
        if f.is_file() and f.suffix.lower() in IMAGE_EXTENSIONS
    )


def compute_gray_world_gains(arr: np.ndarray) -> Tuple[float, float, float]:
    """
    Berechnet RGB-Korrekturfaktoren nach dem Gray-World-Verfahren.

    Gray World: Der Durchschnitt aller Pixel eines neutral beleuchteten Bildes
    sollte in allen drei Farbkanälen gleich sein. Weicht er ab, liegt ein
    Farbstich vor; die Korrekturfaktoren gleichen ihn aus.

    Für Astro-Bilder werden nur Pixel im Helligkeitsbereich [TRIM_LOW, TRIM_HIGH]
    verwendet, da überbelichtete Sterne und rein schwarzer Himmel das Ergebnis
    verzerren würden.
    """
    low  = TRIM_LOW  * 255.0
    high = TRIM_HIGH * 255.0

    lum  = arr.mean(axis=2)                         # mittlere Helligkeit pro Pixel
    mask = (lum >= low) & (lum <= high)

    # Fallback: wenn zu wenige Pixel die Maske passieren (z.B. sehr helles Bild)
    if mask.sum() < 1000:
        mask = np.ones(lum.shape, dtype=bool)

    mean_r = float(arr[:, :, 0][mask].mean())
    mean_g = float(arr[:, :, 1][mask].mean())
    mean_b = float(arr[:, :, 2][mask].mean())

    mean_all = (mean_r + mean_g + mean_b) / 3.0

    return mean_all / mean_r, mean_all / mean_g, mean_all / mean_b


def apply_gains(
    arr: np.ndarray, gain_r: float, gain_g: float, gain_b: float
) -> np.ndarray:
    """Korrekturfaktoren kanalweise anwenden; Werte auf [0, 255] begrenzen."""
    out = arr.astype(np.float64)
    out[:, :, 0] *= gain_r
    out[:, :, 1] *= gain_g
    out[:, :, 2] *= gain_b
    return np.clip(out, 0, 255).astype(np.uint8)


def save_image(
    img: Image.Image, path: Path, exif: Optional[bytes] = None
) -> None:
    """Bild speichern; EXIF-Bytes aus dem Original übernehmen wenn vorhanden."""
    ext = path.suffix.lower()
    kwargs: dict = {}

    if ext in (".jpg", ".jpeg"):
        kwargs["quality"]     = JPEG_QUALITY
        kwargs["subsampling"] = 0           # 4:4:4 — keine Farb-Unterabtastung
        if exif:
            kwargs["exif"] = exif

    elif ext == ".png":
        kwargs["compress_level"] = 1        # schnell, verlustfrei
        if exif:
            kwargs["exif"] = exif

    img.save(path, **kwargs)


# ---------------------------------------------------------------------------
# Hauptprogramm
# ---------------------------------------------------------------------------

def main() -> None:
    if len(sys.argv) < 2:
        print("Verwendung: python astrobilder_whitebalance.py <bildordner>")
        sys.exit(1)

    folder = Path(sys.argv[1]).resolve()
    if not folder.is_dir():
        print(f"Fehler: Ordner nicht gefunden: {folder}")
        sys.exit(1)

    # --- 1. Bilder einlesen ---
    images = find_images(folder)
    n = len(images)
    if n == 0:
        print(f"Keine Bilder ({', '.join(IMAGE_EXTENSIONS)}) in {folder} gefunden.")
        sys.exit(1)
    print(f"Gefunden: {n} Bilder in {folder}")

    # --- 2. Referenzbilder aus der Mitte wählen ---
    mid     = n // 2
    offsets = list(range(-(N_REFERENCE // 2), N_REFERENCE // 2 + 1))[:N_REFERENCE]
    # set() entfernt Duplikate bei sehr kleinen Bildmengen
    ref_indices = sorted({max(0, min(mid + o, n - 1)) for o in offsets})
    ref_paths   = [images[i] for i in ref_indices]

    print(f"\nReferenzbilder aus der Mitte (Indizes {ref_indices} von {n}):")

    # --- 3. Korrekturfaktoren je Referenzbild berechnen ---
    gains_list: List[Tuple[float, float, float]] = []
    for path in ref_paths:
        img  = Image.open(path).convert("RGB")
        arr  = np.array(img, dtype=np.float64)
        gain = compute_gray_world_gains(arr)
        gains_list.append(gain)
        print(f"  {path.name:<50}  R={gain[0]:.4f}  G={gain[1]:.4f}  B={gain[2]:.4f}")

    # Gemittelte Gains über alle Referenzbilder
    gain_r, gain_g, gain_b = np.mean(gains_list, axis=0).tolist()
    print(f"\nGemittelte Korrekturfaktoren:  R={gain_r:.4f}  G={gain_g:.4f}  B={gain_b:.4f}")

    # --- 4. Ausgabeordner anlegen ---
    dir_out  = folder / DIR_OUTPUT
    dir_orig = folder / DIR_ORIGINAL
    dir_out.mkdir(exist_ok=True)
    dir_orig.mkdir(exist_ok=True)

    # --- 5. Alle Bilder verarbeiten ---
    print()
    errors: List[Tuple[str, str]] = []

    for img_path in tqdm(images, desc="Weißabgleich", unit="Bild"):
        try:
            src  = Image.open(img_path)
            exif = src.info.get("exif")                 # EXIF-Bytes für Output sichern
            arr  = np.array(src.convert("RGB"), dtype=np.float64)

            out_arr = apply_gains(arr, gain_r, gain_g, gain_b)
            out_img = Image.fromarray(out_arr.astype(np.uint8), "RGB")

            save_image(out_img, dir_out / img_path.name, exif=exif)

            # Original erst nach erfolgreichem Speichern verschieben
            shutil.move(str(img_path), dir_orig / img_path.name)

        except Exception as exc:  # noqa: BLE001
            errors.append((img_path.name, str(exc)))

    # --- 6. Zusammenfassung ---
    ok = n - len(errors)
    print(f"\nFertig: {ok}/{n} Bilder erfolgreich verarbeitet.")
    print(f"  Korrigierte Bilder : {dir_out}")
    print(f"  Originale          : {dir_orig}")

    if errors:
        print(f"\nFehler bei {len(errors)} Bild(ern):")
        for name, msg in errors:
            print(f"  {name}: {msg}")
        sys.exit(1)


if __name__ == "__main__":
    main()
