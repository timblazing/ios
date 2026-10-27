#!/usr/bin/env bash
# Builds the bundle icon sizes from the 1024px master. Keeps the existing icons if the master is
# missing or sips (macOS) is unavailable.
set -euo pipefail
cd "$(dirname "$0")/.."
master="Resources/Icon/icon-1024.png"
if [[ ! -f "$master" ]]; then echo "make-icons: $master not found; keeping existing icons"; exit 0; fi
if ! command -v sips >/dev/null; then echo "make-icons: sips not available; keeping existing icons"; exit 0; fi
width=$(sips -g pixelWidth "$master" | awk '/pixelWidth/ {print $2}')
height=$(sips -g pixelHeight "$master" | awk '/pixelHeight/ {print $2}')
if [[ "$width" != 1024 || "$height" != 1024 ]]; then
  echo "make-icons: $master is ${width}x${height}, expected 1024x1024" >&2; exit 1
fi
for entry in Icon-76@2x:152 Icon-40@2x:80 Icon-29@2x:58 Icon-83.5@2x:167 Icon-76:76 Icon-40:40 Icon-29:29; do
  sips -z "${entry#*:}" "${entry#*:}" "$master" --out "Resources/${entry%%:*}.png" >/dev/null
done
echo "make-icons: wrote icons from $master"
