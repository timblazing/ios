#!/usr/bin/env bash
# Renders art/ into Resources/: the app icon, the title-bar icon, and @2x PNGs of every art/icons/*.svg.
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p Resources/Icons
rsvg-convert -w 152 -h 152 art/app-icon.svg > Resources/Icon-76@2x.png
rsvg-convert -w 76 -h 76 art/app-icon.svg > Resources/Icon-76.png
rsvg-convert -w 1024 -h 1024 art/app-icon.svg > art/icon-1024.png
sips -z 44 44 art/paint-palette.png --out Resources/Icons/app-palette@2x.png >/dev/null
for svg in art/icons/*.svg; do
  name=$(basename "$svg" .svg)
  out="Resources/Icons/$name@2x.png"
  [[ "$out" -nt "$svg" ]] || rsvg-convert -z 2 "$svg" > "$out"
done
