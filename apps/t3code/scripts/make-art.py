#!/usr/bin/env python3
"""Generate the original speech-bubble icon with Python's standard library."""
import struct
import zlib
from pathlib import Path
root = Path(__file__).resolve().parent.parent

def chunk(name, data):
    return struct.pack('!I', len(data)) + name + data + struct.pack('!I', zlib.crc32(name + data))

def color(x, y):
    if 170 < x < 854 and 220 < y < 804:
        if 250 < x < 774 and 310 < y < 670:
            if 310 < x < 700 and (365 < y < 395 or 465 < y < 495 or 565 < y < 595):
                return (149, 118, 158)
            return (250, 247, 251)
        if 650 < x < 735 and 650 < y < x + 60:
            return (250, 247, 251)
        return (72, 44, 80)
    return (238, 232, 241)

for name, size in [('Icon-76.png', 76), ('Icon-76@2x.png', 152), ('Icon-83.5@2x.png', 167)]:
    rows = bytearray()
    for y in range(size):
        rows.append(0)
        for x in range(size):
            colors = [color((x + dx / 3) * 1024 / size, (y + dy / 3) * 1024 / size) for dy in range(3) for dx in range(3)]
            rows.extend(sum(c[i] for c in colors) // 9 for i in range(3))
    png = b'\x89PNG\r\n\x1a\n' + chunk(b'IHDR', struct.pack('!IIBBBBB', size, size, 8, 2, 0, 0, 0)) + chunk(b'IDAT', zlib.compress(bytes(rows), 9)) + chunk(b'IEND', b'')
    (root / 'Resources' / name).write_bytes(png)
