#!/usr/bin/env python3
"""Draws the 1024px icon master and the plain launch images. Run once; outputs are committed."""
from pathlib import Path
from PIL import Image, ImageDraw

root = Path(__file__).resolve().parent.parent / "Resources"
G, Y, X = (0x6A, 0xAA, 0x64), (0xC9, 0xB4, 0x58), (0x78, 0x7C, 0x7E)
grid = [[X, Y, X], [Y, G, X], [G, G, G]]
icon = Image.new("RGB", (1024, 1024), "white")
d = ImageDraw.Draw(icon)
tile, gap = 250, 32
start = (1024 - 3 * tile - 2 * gap) // 2
for r, row in enumerate(grid):
    for c, color in enumerate(row):
        x, y = start + c * (tile + gap), start + r * (tile + gap)
        d.rectangle([x, y, x + tile - 1, y + tile - 1], fill=color)
(root / "Icon").mkdir(exist_ok=True)
icon.save(root / "Icon" / "icon-1024.png")
for name, size in [("Launch-Portrait", (768, 1024)), ("Launch-Landscape", (1024, 768))]:
    for scale, suffix in [(1, ""), (2, "@2x")]:
        Image.new("RGB", (size[0] * scale, size[1] * scale), "white").save(root / f"{name}{suffix}.png")
