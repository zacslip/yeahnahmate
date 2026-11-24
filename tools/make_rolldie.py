"""Draws YeahNahMate/Media/rolldie.tga: the clan roll winner's icon, a gold die with a small crown.

Original art, drawn here from shapes (no game files used). Run from the repo root:
    python tools/make_rolldie.py
Needs Pillow (pip install pillow). The game wants a power-of-two size: 64 x 64, 32-bit TGA.
"""
import os
from PIL import Image, ImageDraw, ImageFilter

S = 256                                  # drawn 4x, then shrunk for smooth edges
OUT = 64
GOLD = (255, 205, 60, 255)
GOLD_LIGHT = (255, 236, 150, 255)
GOLD_DARK = (170, 110, 20, 255)
PIP = (70, 35, 10, 255)
EDGE = (40, 20, 5, 255)


def main():
    img = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)

    # The die: a rounded square in the lower part, a dark edge, a lighter top-left bevel.
    box = (30, 78, 226, 248)
    d.rounded_rectangle(box, radius=34, fill=EDGE)
    inner = (40, 88, 216, 238)
    d.rounded_rectangle(inner, radius=28, fill=GOLD_DARK)
    d.rounded_rectangle((44, 90, 212, 228), radius=26, fill=GOLD)
    d.rounded_rectangle((52, 96, 160, 150), radius=22, fill=GOLD_LIGHT)
    d.rounded_rectangle((50, 100, 208, 224), radius=24, fill=GOLD)

    # Five pips.
    cx, cy = 128, 162
    r = 15
    for dx, dy in ((0, 0), (-46, -40), (46, -40), (-46, 40), (46, 40)):
        x, y = cx + dx, cy + dy
        d.ellipse((x - r, y - r, x + r, y + r), fill=PIP)
        d.ellipse((x - r + 4, y - r + 3, x - r + 11, y - r + 10), fill=(140, 90, 40, 255))

    # The crown, sitting on the die's top edge.
    crown = [(70, 92), (70, 40), (100, 66), (128, 22), (156, 66), (186, 40), (186, 92)]
    d.polygon([(x, y + 4) for x, y in crown], fill=EDGE)
    d.polygon(crown, fill=GOLD_LIGHT)
    d.rectangle((70, 78, 186, 92), fill=GOLD)
    for x, y in ((70, 40), (128, 22), (186, 40)):
        d.ellipse((x - 9, y - 9, x + 9, y + 9), fill=EDGE)
        d.ellipse((x - 7, y - 7, x + 7, y + 7), fill=(230, 60, 50, 255))

    # A soft dark glow behind it so it reads over any background.
    alpha = img.split()[3].filter(ImageFilter.GaussianBlur(6))
    glow = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    glow.putalpha(alpha.point(lambda a: int(a * 0.6)))
    out = Image.alpha_composite(glow, img).resize((OUT, OUT), Image.LANCZOS)

    path = os.path.join(os.path.dirname(__file__), "..", "YeahNahMate", "Media", "rolldie.tga")
    out.save(os.path.normpath(path), format="TGA", compression=None)
    print("wrote", os.path.normpath(path))


if __name__ == "__main__":
    main()
