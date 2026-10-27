#!/usr/bin/env bash
# Renders art/app-icon.svg into Resources/Icon-76*.png. The PNGs are committed; run this only after editing the SVG.
set -euo pipefail
cd "$(dirname "$0")/.."
rsvg-convert -w 152 -h 152 art/app-icon.svg > Resources/Icon-76@2x.png
rsvg-convert -w 76 -h 76 art/app-icon.svg > Resources/Icon-76.png
