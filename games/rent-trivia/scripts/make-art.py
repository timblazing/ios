#!/usr/bin/env python3
"""Renders art/source into Resources/: stills, cast headshots, logo, and the app icon."""
import os

root = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
src = os.path.join(root, "art", "source")
media = os.path.join(root, "Resources", "Media")
if not os.path.isdir(os.path.join(src, "stills")):
    print("make-art: art/source/ not found (film art isn't in the repo); skipping.")
    raise SystemExit(0)
from PIL import Image, ImageDraw, ImageFilter

os.makedirs(media, exist_ok=True)

def newer(out, *ins):
    return os.path.exists(out) and all(os.path.getmtime(out) >= os.path.getmtime(i) for i in ins)

# Stills fill a 2048x1536 retina screen when aspect-filled; 1920 wide is the sweet spot for size vs. sharpness.
for name in sorted(os.listdir(os.path.join(src, "stills"))):
    if not name.endswith(".jpg"):
        continue
    i, o = os.path.join(src, "stills", name), os.path.join(media, "still-" + name)
    if newer(o, i):
        continue
    im = Image.open(i).convert("RGB")
    if im.width > 1920:
        im = im.resize((1920, round(im.height * 1920 / im.width)), Image.LANCZOS)
    im.save(o, quality=78, optimize=True, progressive=False)

for name in sorted(os.listdir(os.path.join(src, "cast"))):
    i, o = os.path.join(src, "cast", name), os.path.join(media, "cast-" + name)
    if not newer(o, i):
        Image.open(i).convert("RGB").resize((300, 450), Image.LANCZOS).save(o, quality=85)

logo_i = os.path.join(src, "logo.png")
logo = Image.open(logo_i).convert("RGBA")
logo = logo.crop(logo.getbbox())
logo_o = os.path.join(media, "logo.png")
if not newer(logo_o, logo_i):
    logo.resize((1400, round(logo.height * 1400 / logo.width)), Image.LANCZOS).save(logo_o, optimize=True)

# Icon: the poster's four colour bands with the white stencil logo across them.
icon_o = os.path.join(root, "art", "icon-1024.png")
if not newer(icon_o, logo_i, __file__):
    S = 1024
    icon = Image.new("RGB", (S, S), (12, 10, 10))
    d = ImageDraw.Draw(icon)
    bands = [(232, 115, 28), (30, 127, 196), (62, 154, 58), (212, 42, 42)]
    w = S // 4
    for k, c in enumerate(bands):
        d.rectangle([k * w, 0, (k + 1) * w - 1, S], fill=c)
    grain = Image.effect_noise((S, S), 40).convert("L").filter(ImageFilter.GaussianBlur(1))
    icon = Image.composite(icon, Image.new("RGB", (S, S), (0, 0, 0)), grain.point(lambda v: 205 + v // 5))
    lw = 920
    lg = logo.resize((lw, round(logo.height * lw / logo.width)), Image.LANCZOS)
    shadow = Image.new("RGBA", lg.size, (0, 0, 0, 0))
    shadow.putalpha(lg.getchannel("A").point(lambda a: a * 0.7))
    shadow = shadow.filter(ImageFilter.GaussianBlur(10))
    x, y = (S - lw) // 2, (S - lg.height) // 2
    icon.paste(shadow, (x + 8, y + 12), shadow)
    icon.paste(lg, (x, y), lg)
    icon.save(icon_o)

icon = Image.open(icon_o)
for px, name in [(76, "Icon-76.png"), (152, "Icon-76@2x.png")]:
    icon.resize((px, px), Image.LANCZOS).save(os.path.join(root, "Resources", name))
