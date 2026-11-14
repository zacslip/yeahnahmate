"""Makes the CurseForge project icon from the guild crest (tools/art/crest.png, the author's own image):
the crest, transparent edges trimmed, on the same dark rounded square as the old map icon (icon.png).
Writes icon-crest.png (400x400). Upload it by hand on the CurseForge project page (Settings >
General > Avatar); the upload API can't change it. Run: python tools/curseforge/make_crest_icon.py"""
import os
from PIL import Image, ImageDraw

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, "icon-crest.png")
S, PAD = 400, 22

crest = Image.open(os.path.join(HERE, "..", "art", "crest.png")).convert("RGBA")
crest = crest.crop(crest.getchannel("A").point(lambda a: 255 if a > 8 else 0).getbbox())
scale = (S - 2 * PAD) / max(crest.size)
crest = crest.resize((round(crest.width * scale), round(crest.height * scale)), Image.LANCZOS)

img = Image.new("RGBA", (S, S), (0, 0, 0, 0))
ImageDraw.Draw(img).rounded_rectangle([0, 0, S - 1, S - 1], radius=65, fill=(18, 28, 40, 255))
img.alpha_composite(crest, ((S - crest.width) // 2, (S - crest.height) // 2))
img.save(OUT)
print("wrote", OUT, img.size)
