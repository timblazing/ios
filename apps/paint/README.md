# Paint

Windows XP-style Paint for the iPad mini 2 (iOS 10.3.3). Objective-C and UIKit, fully offline.

## Features

- All 16 XP tools: Free-Form Select, Select, Eraser, Fill With Color, Pick Color, Magnifier, Pencil, Brush, Airbrush, Text, Line, Curve, Rectangle, Polygon, Ellipse, Rounded Rectangle.
- The tool options box under the toolbox changes per tool: brush shapes and sizes, eraser and airbrush sizes, line widths, fill styles, fill tolerance, magnification, font, size, bold, and opaque or transparent text and selections.
- Selections float like XP: drag to move, drag the blue corner to resize, flip, rotate, invert, cut, copy, and paste (through the system clipboard, so images from other apps paste too).
- Menus: File (New, Open from Photos, Save to Photos, Send), Edit, View (toolbars, zoom), Image (flip, rotate, invert, attributes, clear, draw opaque), Colors (Edit Colors dialog, swap, reset palette), and Help.
- Undo and redo of every change, including canvas resizes and rotations, within a 72 MB budget.
- The picture is autosaved when the app goes to the background and restored at launch.

## Touch controls

- One finger draws. Pinch to zoom (up to 16×, shown pixel-sharp), two fingers to scroll.
- Two-finger tap undoes, three-finger tap redoes. The title bar has save, undo, and redo buttons.
- Tap a palette color for color 1; touch and hold for color 2. Tap the color well to swap them.
- Curve: drag the line, then drag twice to bend it. Polygon: tap each corner, then tap the first corner (or the last one again) to finish.
- Title bar buttons: minimize hides the toolbars, maximize fits the picture to the window, close starts a new picture.

**Release:** [Paint-2.0.0.ipa](dist/Paint-2.0.0.ipa), Debian packages in `packages/`, and [checksums](dist/SHA256SUMS). This project now lives in `apps/paint/`.

## Build

```sh
export THEOS=~/theos
make package FINALPACKAGE=1 -j4   # .deb in packages/
scripts/package-ipa.sh            # .ipa in dist/
scripts/test-rules.sh             # pixel and undo model tests
```

`make` runs `scripts/make-art.sh`, which renders `art/` into `Resources/`: the app icon (`art/app-icon.svg`, the classic Paint cup over an XP Bliss-style sky), the title bar icon, and the toolbox, window, and dialog icons (`art/icons/*.svg`). Edit the SVGs, not the PNGs.

## Code

- `Application/Model/`: Foundation-only pixel operations (flood fill, flips, rotation, inversion) and the undo history. Tested by `scripts/test-rules.sh`.
- `PaintCanvasView`: the bitmap canvas and every tool. Pixels live in one RGBA buffer at screen scale (1760 × 1120 by default); each operation records only the rect it changed.
- `PaintViewController`: the window, menus, toolbox, options, and commands.
- `XPChrome`: Luna styling, bevels, buttons, windows, message boxes, and menus.
- `PaintColorBox`, `PaintColorDialog`, `PaintOptionsView`: the color box, Edit Colors dialog, and tool options box.

Checks that need the iPad are in `Tests/DEVICE_CHECKLIST.md`.
