"""Draws the CurseForge project icon (400x400 PNG): a parchment map with guildies as class-coloured
dots, on a dark rounded square. Original artwork (no game art). Run: python tools/curseforge/make_icon.py
Needs Pillow (pip install pillow)."""
import os
from PIL import Image, ImageDraw, ImageFilter

S = 1600                      # drawn big, then scaled down for smooth edges
OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "icon.png")

img = Image.new("RGBA", (S, S), (0, 0, 0, 0))
d = ImageDraw.Draw(img)

# Dark rounded square with a soft lighter middle.
d.rounded_rectangle([0, 0, S - 1, S - 1], radius=260, fill=(18, 28, 40, 255))
glow = Image.new("RGBA", (S, S), (0, 0, 0, 0))
ImageDraw.Draw(glow).ellipse([260, 220, S - 260, S - 300], fill=(60, 90, 120, 120))
glow = glow.filter(ImageFilter.GaussianBlur(160))
mask = Image.new("L", (S, S), 0)
ImageDraw.Draw(mask).rounded_rectangle([0, 0, S - 1, S - 1], radius=260, fill=255)
img.paste(Image.alpha_composite(img, glow), (0, 0), mask)
d = ImageDraw.Draw(img)

# The map: a parchment disc with a gold rim.
C, R = S // 2, 610
d.ellipse([C - R - 40, C - R - 40, C + R + 40, C + R + 40], fill=(184, 134, 43, 255))
d.ellipse([C - R, C - R, C + R, C + R], fill=(226, 205, 150, 255))
# Land shapes, a little darker.
land = (196, 170, 110, 255)
d.polygon([(C - 420, C - 260), (C - 150, C - 420), (C + 60, C - 330), (C - 20, C - 120),
           (C - 260, C - 40), (C - 460, C - 120)], fill=land)
d.polygon([(C + 120, C - 80), (C + 430, C - 200), (C + 520, C + 60), (C + 330, C + 300),
           (C + 80, C + 220)], fill=land)
d.polygon([(C - 380, C + 160), (C - 120, C + 120), (C - 60, C + 380), (C - 300, C + 470),
           (C - 470, C + 330)], fill=land)
# A dashed path between the guildies.
path = [(C - 300, C - 230), (C - 60, C + 10), (C + 260, C + 60), (C - 210, C + 290)]
for (x1, y1), (x2, y2) in zip(path, path[1:]):
    n = 9
    for i in range(0, n, 2):
        a, b = i / n, (i + 1) / n
        d.line([(x1 + (x2 - x1) * a, y1 + (y2 - y1) * a), (x1 + (x2 - x1) * b, y1 + (y2 - y1) * b)],
               fill=(120, 90, 50, 255), width=22)

# Guildies: class-coloured dots with a dark ring.
def dot(x, y, col, r=78):
    d.ellipse([x - r - 16, y - r - 16, x + r + 16, y + r + 16], fill=(25, 25, 25, 255))
    d.ellipse([x - r, y - r, x + r, y + r], fill=col)
    d.ellipse([x - r * 0.45, y - r * 0.6, x - r * 0.05, y - r * 0.2], fill=(255, 255, 255, 110))

dot(C - 300, C - 230, (63, 199, 235, 255))    # mage blue
dot(C + 260, C + 60, (170, 211, 114, 255))    # hunter green
dot(C - 210, C + 290, (255, 124, 10, 255))    # druid orange
dot(C + 300, C - 330, (135, 136, 238, 255), 62)  # warlock purple
dot(C + 70, C + 420, (244, 140, 186, 255), 62)   # paladin pink

# "You": a red map pin in the middle of the group.
px, py = C - 60, C + 10
# Circle head (centre px, py-345) and a point whose sides meet the circle smoothly.
d.ellipse([px - 175, py - 520, px + 175, py - 170], fill=(25, 25, 25, 255))
d.polygon([(px, py + 80), (px - 158, py - 270), (px + 158, py - 270)], fill=(25, 25, 25, 255))
d.ellipse([px - 150, py - 495, px + 150, py - 195], fill=(214, 48, 49, 255))
d.polygon([(px, py + 40), (px - 130, py - 270), (px + 130, py - 270)], fill=(214, 48, 49, 255))
d.ellipse([px - 62, py - 407, px + 62, py - 283], fill=(255, 240, 220, 255))

img.resize((400, 400), Image.LANCZOS).save(OUT)
print("wrote", OUT)
