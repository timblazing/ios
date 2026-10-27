#!/usr/bin/env python3
"""Resize the official T3 Code app icon (art/icon-1024.png) to the iPad sizes iOS 10 needs."""
import subprocess
from pathlib import Path
root = Path(__file__).resolve().parent.parent
source = root / 'art' / 'icon-1024.png'
for name, size in [('Icon-76.png', 76), ('Icon-76@2x.png', 152), ('Icon-83.5@2x.png', 167)]:
    target = root / 'Resources' / name
    if not target.exists() or target.stat().st_mtime < source.stat().st_mtime:
        subprocess.run(['sips', '-s', 'format', 'png', '-z', str(size), str(size), str(source), '--out', str(target)],
                       check=True, stdout=subprocess.DEVNULL)
