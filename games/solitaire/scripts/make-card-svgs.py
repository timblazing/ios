#!/usr/bin/env python3
"""Writes candidate card designs to docs/card-designs/sets/<set>/ as SVG plus 250x350 PNG.

One file per card, named like the app's art (AS, 10H, back), so a set's PNGs drop straight into
Resources/Cards/. Each set is a palette plus a court style; sets.json lists them for the design
playground. Run with set names to build only those. Re-running overwrites the generated files.

Suit shapes match the app icon. Court figures are Dmitry Fomin's CC0 English pattern
(docs/card-designs/courts/), recolored per set. Needs rsvg-convert (brew install librsvg).
"""
import base64
import json
import pathlib
import re
import subprocess
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
DESIGNS = ROOT / "docs" / "card-designs"
COURTS = DESIGNS / "courts"
OUT = DESIGNS / "sets"
W, H = 250, 350
FONT = "'Avenir Next Condensed', 'Helvetica Neue', sans-serif"
INK = "#16121f"

# Suit paths in a 24x24 box. Heart, spade, and club are the icon's Material Design shapes; the
# diamond has the icon's concave sides.
PATHS = {
    "H": "M12,21.35L10.55,20.03C5.4,15.36 2,12.27 2,8.5C2,5.41 4.42,3 7.5,3C9.24,3 10.91,3.81 12,5.08"
         "C13.09,3.81 14.76,3 16.5,3C19.58,3 22,5.41 22,8.5C22,12.27 18.6,15.36 13.45,20.03L12,21.35Z",
    "D": "M12,1.6C13.5,6.3 16.2,9.7 20,12C16.2,14.3 13.5,17.7 12,22.4C10.5,17.7 7.8,14.3 4,12"
         "C7.8,9.7 10.5,6.3 12,1.6Z",
    "C": "M12,2C14.3,2 16.3,4 16.3,6.2C16.21,8.77 14.34,9.83 14.04,10C15.04,9.5 16.5,9.5 16.5,9.5"
         "C19,9.5 21,11.3 21,13.8C21,16.3 19,18 16.5,18C16.5,18 15,18 13,17C13,17 12.7,19 15,22H9"
         "C11.3,19 11,17 11,17C9,18 7.5,18 7.5,18C5,18 3,16.3 3,13.8C3,11.3 5,9.5 7.5,9.5"
         "C7.5,9.5 8.96,9.5 9.96,10C9.66,9.83 7.79,8.77 7.7,6.2C7.7,4 9.7,2 12,2Z",
    "S": "M12,2C9,7 4,9 4,14C4,16 6,18 8,18C9,18 10,18 11,17C11,17 11.32,19 9,22H15C13,19 13,17 13,17"
         "C14,18 15,18 16,18C18,18 20,16 20,14C20,9 15,7 12,2Z",
}
RED = {"H", "D"}
RANKS = ["A", "2", "3", "4", "5", "6", "7", "8", "9", "10", "J", "Q", "K"]

# Court art uses five flat colors; each set maps them. "red" is also the set's red-suit ink.
SETS = {
    "lavender": dict(label="Icon lavender", red="#9976ff", blue="#3b2170", yellow="#ddd2ff", courts="figures",
                     field="#1f1240", glow="#6a44c9", glowSuit="#b9a2ff"),
    "violet-gold": dict(label="Violet + gold", red="#7445e6", blue="#2c1a52", yellow="#efc965", courts="figures",
                        field="#1a0f31", glow="#5b33b8", glowSuit="#a88bff"),
    "classic": dict(label="Classic red", red="#c8213a", blue="#3b2a78", yellow="#f1cf5b", courts="figures",
                    field="#1b1236", glow="#4b2f9a", glowSuit="#ef5a6e"),
    "minimal": dict(label="Minimal courts", red="#7445e6", blue="#2c1a52", yellow="#ddd2ff", courts="letters",
                    field="#1a0f31", glow="#5b33b8", glowSuit="#a88bff"),
    # True red and black faces, the cat on a purple back, and the icon on the board's green felt.
    "traditional": dict(label="Traditional + cat", red="#d0101e", blue="#1f3c8f", yellow="#f3c22c", courts="figures",
                        ink="#111111", field="#b3101c", line="#ffffff", glow="#e8434d", glowSuit="#ffffff",
                        felt=("#3a9d55", "#1a6a33", "#0a3a1a"), back="cat"),
}
SOURCE = {"red": (0xff, 0x55, 0x55), "blue": (0x55, 0x55, 0xaa), "yellow": (0xff, 0xff, 0x55),
          "black": (0, 0, 0), "white": (0xff, 0xff, 0xff)}

# Court frame: the source art is 302x482, centered on the card at 0.6 scale.
STRIP = 62  # top of the card reserved for the index; the mirrored index takes the same at the bottom
SCALE = (H - 2 * STRIP + 4) / 482
FX, FY = (W - 302 * SCALE) / 2, (H - 482 * SCALE) / 2


def pip(letter, cx, cy, size, color, flip=False):
    """A suit shape centered on (cx, cy), size px tall, optionally upside down."""
    s = size / 24
    rotate = f"rotate(180 {cx:g} {cy:g}) " if flip else ""
    return (f'<path transform="{rotate}translate({cx - 12 * s:g} {cy - 12 * s:g}) scale({s:g})" '
            f'd="{PATHS[letter]}" fill="{color}"/>')


def text_width(text, size, spacing=0):
    try:
        from PIL import ImageFont
        font = ImageFont.truetype("/System/Library/Fonts/Avenir Next Condensed.ttc", size, index=2)
        return font.getlength(text) + spacing * (len(text) - 1)
    except (ImportError, OSError):
        return size * .5 * len(text)


def index(rank, letter, color):
    """Top-left index: rank and suit side by side in the top STRIP px, so both stay readable in a fully
    compressed tableau column. Everything else on the card starts below the strip."""
    spacing = -3 if rank == "10" else 0
    x = 14 + text_width(rank, 54, spacing)
    return (f'<text x="14" y="53" font-family="{FONT}" font-weight="600" font-size="54" '
            f'letter-spacing="{spacing}" fill="{color}">{rank}</text>' + pip(letter, x + 20, 35, 34, color))


# Pip centers for 2-10 as (column, row): columns 0-2 left to right, rows 0-1 top to bottom.
L, M, R = 0, 1, 2
LAYOUTS = {
    2: [(M, 0), (M, 1)],
    3: [(M, 0), (M, .5), (M, 1)],
    4: [(L, 0), (R, 0), (L, 1), (R, 1)],
    5: [(L, 0), (R, 0), (M, .5), (L, 1), (R, 1)],
    6: [(L, 0), (R, 0), (L, .5), (R, .5), (L, 1), (R, 1)],
    7: [(L, 0), (R, 0), (M, .25), (L, .5), (R, .5), (L, 1), (R, 1)],
    8: [(L, 0), (R, 0), (M, .25), (L, .5), (R, .5), (M, .75), (L, 1), (R, 1)],
    9: [(L, 0), (R, 0), (L, 1 / 3), (R, 1 / 3), (M, .5), (L, 2 / 3), (R, 2 / 3), (L, 1), (R, 1)],
    10: [(L, 0), (R, 0), (M, 1 / 6), (L, 1 / 3), (R, 1 / 3), (L, 2 / 3), (R, 2 / 3), (M, 5 / 6), (L, 1),
         (R, 1)],
}


def recolor(svg, palette):
    """Maps every color in the court art to the nearest of its five source colors, then to the set."""
    target = {"red": palette["red"], "blue": palette["blue"], "yellow": palette["yellow"],
              "black": palette.get("ink", INK), "white": "#ffffff"}

    def swap(m):
        rgb = tuple(int(m.group(1)[i:i + 2], 16) for i in (0, 2, 4))
        name = min(SOURCE, key=lambda k: sum((a - b) ** 2 for a, b in zip(rgb, SOURCE[k])))
        return target[name]
    return re.sub(r"#([0-9a-fA-F]{6})\b", swap, svg)


def court_figure(rank, letter, palette):
    """The figure clipped to a uniform frame. The source frame is notched where its own index sat, and
    a few cards keep suit marks there inside nested groups, so both notches are painted over."""
    svg = (COURTS / f"{rank}{letter}.svg").read_text()
    body = svg[svg.index(">") + 1:svg.rindex("</svg>")]
    notch = '<rect x="0" y="0" width="94" height="108" fill="#ffffff"/>'
    art = (f'<clipPath id="frame"><rect width="302" height="482"/></clipPath>'
           f'<g clip-path="url(#frame)">{recolor(body, palette)}{notch}'
           f'<g transform="rotate(180 151 241)">{notch}</g></g>')
    return (f'<g transform="translate({FX:g} {FY:g}) scale({SCALE:g})">{art}</g>'
            f'<rect x="{FX:g}" y="{FY:g}" width="{302 * SCALE:g}" height="{482 * SCALE:g}" rx="3" fill="none" '
            f'stroke="{palette["blue"]}" stroke-width="1.5"/>')


def court_letter(rank, letter, color, palette):
    # Inset clear of both corner indexes.
    return (f'<rect x="{FX:g}" y="{FY:g}" width="{W - 2 * FX:g}" height="{H - 2 * FY:g}" rx="8" '
            f'fill="{palette["yellow"]}" fill-opacity=".35" stroke="{color}" stroke-width="2.5"/>'
            f'<text x="{W / 2:g}" y="208" text-anchor="middle" font-family="{FONT}" font-weight="600" '
            f'font-size="130" fill="{color}">{rank}</text>' + pip(letter, W / 2, 250, 40, color))


def center(rank, letter, color, palette):
    if rank == "A":
        return pip(letter, W / 2, H / 2, 128 if letter == "S" else 104, color)
    if rank in "JQK":
        if palette["courts"] == "figures":
            return court_figure(rank, letter, palette)
        return court_letter(rank, letter, color, palette)
    columns, top, bottom = (78, 125, 172), STRIP + 44, H - STRIP - 44
    return "".join(pip(letter, columns[c], top + r * (bottom - top), 40, color, flip=r > .5)
                   for c, r in LAYOUTS[int(rank)])


def face(rank, letter, palette):
    color = palette["red"] if letter in RED else palette.get("ink", INK)
    corner = index(rank, letter, color)
    return (f'<svg xmlns="http://www.w3.org/2000/svg" width="{W}" height="{H}" viewBox="0 0 {W} {H}">\n'
            f'<rect width="{W}" height="{H}" fill="#ffffff"/>\n'
            f'<g id="center">{center(rank, letter, color, palette)}</g>\n'
            f'<g id="index">{corner}</g>\n'
            f'<g id="index-flipped" transform="rotate(180 {W / 2:g} {H / 2:g})">{corner}</g>\n'
            f'</svg>\n')


def diamond(cx, cy, w, h, pinch=.14):
    """A diamond with concave sides, like the icon's; pinch pulls each side toward the center."""
    pts = [(cx, cy - h / 2), (cx + w / 2, cy), (cx, cy + h / 2), (cx - w / 2, cy)]
    d = f"M{pts[0][0]:g},{pts[0][1]:g}"
    for i in range(4):
        (ax, ay), (bx, by) = pts[i], pts[(i + 1) % 4]
        qx = cx + ((ax + bx) / 2 - cx) * pinch * 2
        qy = cy + ((ay + by) / 2 - cy) * pinch * 2
        d += f" Q{qx:g},{qy:g} {bx:g},{by:g}"
    return d + "Z"


def back(palette):
    """Bordered like the faces: a white margin around a dark field with a fine lattice, a double rule,
    and a concave-diamond medallion holding the four suits. Symmetric under a half turn."""
    field, line, light = palette["field"], palette.get("line", palette["yellow"]), palette["glow"]
    fx, fy, fw, fh = 11, 11, W - 22, H - 22
    cx, cy = W / 2, H / 2
    lattice = (f'<pattern id="lattice" width="18" height="18" patternUnits="userSpaceOnUse" '
               f'patternTransform="translate({cx:g} {cy:g}) rotate(45)">'
               f'<path d="M0,0H18M0,0V18" stroke="{line}" stroke-opacity=".16" stroke-width="1"/>'
               f'<path d="{diamond(9, 9, 5, 5, .1)}" fill="{line}" fill-opacity=".22"/></pattern>')
    glow = (f'<radialGradient id="glow" cx="{cx:g}" cy="{cy:g}" r="{fh * .62:g}" gradientUnits="userSpaceOnUse">'
            f'<stop offset="0" stop-color="{light}" stop-opacity=".55"/>'
            f'<stop offset="1" stop-color="{light}" stop-opacity="0"/></radialGradient>')
    rule = lambda inset, width, opacity: (
        f'<rect x="{fx + inset:g}" y="{fy + inset:g}" width="{fw - 2 * inset:g}" height="{fh - 2 * inset:g}" '
        f'rx="{max(2, 10 - inset / 2):g}" fill="none" stroke="{line}" stroke-opacity="{opacity}" '
        f'stroke-width="{width}"/>')
    corners = "".join(f'<path d="{diamond(x, y, 12, 16)}" fill="{line}"/>'
                      for x in (fx + 9, fx + fw - 9) for y in (fy + 9, fy + fh - 9))
    pale = "#ffffff" if "line" in palette else "#f6f2ff"
    suit_color = {"S": pale, "C": pale, "H": palette["glowSuit"], "D": palette["glowSuit"]}
    suits = "".join(pip(k, cx + dx, cy + dy, 26, suit_color[k], flip=flip)
                    for k, dx, dy, flip in (("S", 0, -34, False), ("H", 30, 0, False),
                                            ("C", 0, 34, True), ("D", -30, 0, False)))
    medallion = (f'<path d="{diamond(cx, cy, 150, 214)}" fill="{field}" stroke="{line}" stroke-width="2"/>'
                 f'<path d="{diamond(cx, cy, 132, 190)}" fill="none" stroke="{line}" stroke-opacity=".45" '
                 f'stroke-width="1"/>'
                 f'<path d="{diamond(cx, cy - 72, 10, 14)}" fill="{line}"/>'
                 f'<path d="{diamond(cx, cy + 72, 10, 14)}" fill="{line}"/>' + suits)
    return (f'<svg xmlns="http://www.w3.org/2000/svg" width="{W}" height="{H}" viewBox="0 0 {W} {H}">\n'
            f'<defs>{lattice}{glow}</defs>\n'
            f'<rect width="{W}" height="{H}" fill="#ffffff"/>\n'
            f'<rect x="{fx}" y="{fy}" width="{fw}" height="{fh}" rx="10" fill="{field}"/>\n'
            f'<rect x="{fx}" y="{fy}" width="{fw}" height="{fh}" rx="10" fill="url(#glow)"/>\n'
            f'<rect x="{fx}" y="{fy}" width="{fw}" height="{fh}" rx="10" fill="url(#lattice)"/>\n'
            f'{rule(6, 1.6, .9)}{rule(10, .8, .5)}\n{corners}\n<g id="medallion">{medallion}</g>\n'
            f'</svg>\n')


# The cat back: a purple gradient field with the cat (docs/card-designs/cat/cat.png, background already cut
# out) gradient-mapped to the same purples, so she reads as part of the print rather than a photo on top.
CAT = DESIGNS / "cat" / "cat.png"
CAT_FIELD = ("#2a0a5e", "#5b1fb0", "#a23fd6", "#e07ae6")
CAT_TONES = ((0, (0x16, 0x03, 0x38)), (.4, (0x6a, 0x22, 0xb8)), (.8, (0xd9, 0x8c, 0xf5)), (1, (0xff, 0xec, 0xff)))


def cat_image(width, height):
    """The cat, duotoned to purples and faded out at the bottom, as a PNG data URI sized for the field."""
    import io
    from PIL import Image, ImageOps
    cat = Image.open(CAT).convert("RGBA")
    cat = cat.resize((width * 3, round(width * 3 * cat.height / cat.width)), Image.LANCZOS)
    gray = ImageOps.autocontrast(cat.convert("L"), cutoff=2)
    lut = []
    for c in range(3):
        for v in range(256):
            t = v / 255
            (t0, a), (t1, b) = next((CAT_TONES[i], CAT_TONES[i + 1]) for i in range(len(CAT_TONES) - 1)
                                    if t <= CAT_TONES[i + 1][0])
            f = (t - t0) / (t1 - t0)
            lut.append(round(a[c] + (b[c] - a[c]) * f))
    tinted = Image.merge("RGB", (gray, gray, gray)).point(lut)
    alpha = cat.getchannel("A")
    fade = Image.linear_gradient("L").resize(alpha.size)  # 0 at the top, 255 at the bottom
    fade = fade.point(lambda v: 255 if v < 150 else max(0, 255 - (v - 150) * 255 // 105))
    tinted.putalpha(Image.composite(alpha, Image.new("L", alpha.size, 0), fade))
    buf = io.BytesIO()
    tinted.save(buf, "PNG", optimize=True)
    return "data:image/png;base64," + base64.b64encode(buf.getvalue()).decode()


def cat_back(palette):
    fx, fy, fw, fh = 11, 11, W - 22, H - 22
    cx = W / 2
    stops = "".join(f'<stop offset="{i / (len(CAT_FIELD) - 1):g}" stop-color="{c}"/>' for i, c in enumerate(CAT_FIELD))
    dots = (f'<pattern id="dots" width="14" height="14" patternUnits="userSpaceOnUse" '
            f'patternTransform="rotate(45)"><circle cx="7" cy="7" r="1.1" fill="#ffffff" fill-opacity=".16"/>'
            f'</pattern>')
    glow = (f'<radialGradient id="halo" cx="{cx:g}" cy="{fy + fh * .36:g}" r="{fw * .62:g}" '
            f'gradientUnits="userSpaceOnUse"><stop offset="0" stop-color="#f6c7ff" stop-opacity=".55"/>'
            f'<stop offset="1" stop-color="#f6c7ff" stop-opacity="0"/></radialGradient>')
    cw = fw - 18
    ch = round(cw * 1021 / 675)
    rule = lambda inset, width, opacity: (
        f'<rect x="{fx + inset:g}" y="{fy + inset:g}" width="{fw - 2 * inset:g}" height="{fh - 2 * inset:g}" '
        f'rx="{max(2, 10 - inset / 2):g}" fill="none" stroke="#ffffff" stroke-opacity="{opacity}" '
        f'stroke-width="{width}"/>')
    sparkle = lambda x, y, r: (f'<path d="M{x:g},{y - r:g}Q{x:g},{y:g} {x + r:g},{y:g}Q{x:g},{y:g} {x:g},{y + r:g}'
                               f'Q{x:g},{y:g} {x - r:g},{y:g}Q{x:g},{y:g} {x:g},{y - r:g}Z" fill="#ffffff" '
                               f'fill-opacity=".85"/>')
    sparkles = "".join(sparkle(x, y, r) for x, y, r in ((40, 44, 7), (212, 62, 5), (205, 128, 8), (47, 150, 5),
                                                         (30, 96, 4), (222, 190, 4)))
    corners = "".join(f'<path d="{diamond(x, y, 12, 16)}" fill="#ffffff"/>'
                      for x in (fx + 9, fx + fw - 9) for y in (fy + 9, fy + fh - 9))
    return (f'<svg xmlns="http://www.w3.org/2000/svg" width="{W}" height="{H}" viewBox="0 0 {W} {H}">\n'
            f'<defs><linearGradient id="field" x1="0" y1="0" x2="1" y2="1">{stops}</linearGradient>{dots}{glow}'
            f'<clipPath id="inside"><rect x="{fx}" y="{fy}" width="{fw}" height="{fh}" rx="10"/></clipPath></defs>\n'
            f'<rect width="{W}" height="{H}" fill="#ffffff"/>\n'
            f'<g clip-path="url(#inside)"><rect x="{fx}" y="{fy}" width="{fw}" height="{fh}" fill="url(#field)"/>'
            f'<rect x="{fx}" y="{fy}" width="{fw}" height="{fh}" fill="url(#dots)"/>'
            f'<rect x="{fx}" y="{fy}" width="{fw}" height="{fh}" fill="url(#halo)"/>{sparkles}'
            f'<image href="{cat_image(cw, fh)}" x="{cx - cw / 2:g}" y="{fy + 26:g}" width="{cw}" height="{ch}"/></g>\n'
            f'{rule(6, 1.6, .9)}{rule(10, .8, .5)}\n{corners}\n</svg>\n')


def icon(name, palette):
    """1024px app icon: the set's back and ace of spades fanned on the board color (near-black, or felt)."""
    out = OUT / name
    cards = []
    for card in ("back", "AS"):
        png = subprocess.run(["rsvg-convert", "-w", str(W * 3), str(out / f"{card}.svg")],
                             check=True, capture_output=True).stdout
        cards.append("data:image/png;base64," + base64.b64encode(png).decode())
    cw, ch = 476, 666
    felt = palette.get("felt")

    def card(href, x, y, angle):
        return (f'<g transform="rotate({angle} {x + cw / 2:g} {y + ch / 2:g})">'
                f'<rect x="{x}" y="{y + 14}" width="{cw}" height="{ch}" rx="34" fill="#000" '
                f'fill-opacity=".55" filter="url(#shadow)"/>'
                f'<clipPath id="c{angle}"><rect x="{x}" y="{y}" width="{cw}" height="{ch}" rx="34"/></clipPath>'
                f'<image href="{href}" x="{x}" y="{y}" width="{cw}" height="{ch}" clip-path="url(#c{angle})"/></g>')
    svg = (f'<svg xmlns="http://www.w3.org/2000/svg" width="1024" height="1024" viewBox="0 0 1024 1024">'
           f'<defs><radialGradient id="bg" cx="512" cy="300" r="820" gradientUnits="userSpaceOnUse">'
           + (f'<stop offset="0" stop-color="{felt[0]}"/><stop offset=".55" stop-color="{felt[1]}"/>'
              f'<stop offset="1" stop-color="{felt[2]}"/></radialGradient>' if felt else
              f'<stop offset="0" stop-color="{palette["glow"]}" stop-opacity=".55"/>'
              f'<stop offset=".55" stop-color="#140d24"/><stop offset="1" stop-color="#07060a"/></radialGradient>')
           + f'<filter id="shadow" x="-30%" y="-30%" width="160%" height="160%">'
           f'<feGaussianBlur stdDeviation="22"/></filter></defs>'
           f'<rect width="1024" height="1024" fill="url(#bg)"/>'
           + card(cards[0], 138, 176, -12) + card(cards[1], 408, 168, 8) + '</svg>')
    (out / "icon-1024.svg").write_text(svg)
    subprocess.run(["rsvg-convert", "-w", "1024", "-h", "1024", "-b", felt[2] if felt else "#07060a", "-o",
                    str(out / "icon-1024.png"), str(out / "icon-1024.svg")], check=True)


def build(name, palette):
    out = OUT / name
    out.mkdir(parents=True, exist_ok=True)
    cards = {"back": cat_back(palette) if palette.get("back") == "cat" else back(palette)}
    for letter in "SHDC":
        for rank in RANKS:
            cards[rank + letter] = face(rank, letter, palette)
    for card, svg in cards.items():
        (out / f"{card}.svg").write_text(svg)
        subprocess.run(["rsvg-convert", "-w", str(W), "-h", str(H), "-o", str(out / f"{card}.png"),
                        str(out / f"{card}.svg")], check=True)
    icon(name, palette)
    print(f"Wrote {len(cards)} cards and an icon to {out.relative_to(ROOT)}")


def main():
    names = sys.argv[1:] or list(SETS)
    for name in names:
        build(name, SETS[name])
    (OUT / "sets.json").write_text(json.dumps(
        [{"id": k, "label": v["label"]} for k, v in SETS.items() if (OUT / k).is_dir()], indent=1) + "\n")


if __name__ == "__main__":
    main()
