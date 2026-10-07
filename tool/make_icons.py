#!/usr/bin/env python3
"""Draws the Pocketwell launcher icon (a coin peeking out of a pocket).

Needs Pillow:  pip install pillow
Writes assets/icon/icon.png and assets/icon/icon_fg.png.
You only need to run this if you want to change the icon.
"""
import pathlib

from PIL import Image, ImageDraw

OUT = pathlib.Path(__file__).resolve().parent.parent / "assets" / "icon"
OUT.mkdir(parents=True, exist_ok=True)

BG = (107, 119, 214, 255)  # #6B77D6
WHITE = (255, 255, 255, 255)
GOLD = (255, 209, 102, 255)
GOLD_DARK = (240, 178, 60, 255)
SCALE = 2
SIZE = 1024 * SCALE


def s(v: float) -> int:
    return int(v * SCALE)


def glyph(draw: ImageDraw.ImageDraw) -> None:
    # coin, drawn first so the pocket covers its lower half
    cx, cy, r = 512, 410, 112
    draw.ellipse((s(cx - r), s(cy - r), s(cx + r), s(cy + r)), fill=GOLD)
    ri = 72
    draw.ellipse(
        (s(cx - ri), s(cy - ri), s(cx + ri), s(cy + ri)),
        outline=GOLD_DARK,
        width=s(12),
    )

    # pocket: rounded at the bottom, square at the top
    left, top, right, bottom = 286, 452, 738, 764
    draw.rounded_rectangle(
        (s(left), s(top), s(right), s(bottom)), radius=s(96), fill=WHITE
    )
    draw.rectangle((s(left), s(top), s(right), s(top + 110)), fill=WHITE)

    # stitching along the top edge of the pocket
    x = left + 44
    while x + 22 <= right - 44:
        draw.rounded_rectangle(
            (s(x), s(top + 40), s(x + 22), s(top + 50)), radius=s(5), fill=BG
        )
        x += 40


def save(img: Image.Image, name: str) -> None:
    img = img.resize((1024, 1024), Image.LANCZOS)
    img.save(OUT / name)
    print("wrote", OUT / name)


# full icon: solid background
full = Image.new("RGBA", (SIZE, SIZE), BG)
glyph(ImageDraw.Draw(full))
save(full, "icon.png")

# adaptive foreground: transparent, glyph kept inside the safe zone
fg = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
glyph(ImageDraw.Draw(fg))
save(fg, "icon_fg.png")
