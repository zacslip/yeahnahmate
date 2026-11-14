"""Turns the guild crest (tools/art/crest.png, the author's own image) into the game textures the addon uses.
WoW needs power-of-two sizes and reads TGA, so: crest.tga (128) for the window header and welcome box,
crest32.tga (32) for the pop-ups, and crestmini.tga (64): the owl cut in close, for the minimap button
and the AddOns list icon, where the whole crest is too small to make out.
Run: python tools/art/make_crest.py   (needs Pillow)"""
import os
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, "..", "..", "YeahNahMate", "Media")
src = Image.open(os.path.join(HERE, "crest.png")).convert("RGBA")
for name, size in (("crest.tga", 128), ("crest32.tga", 32)):
    src.resize((size, size), Image.LANCZOS).save(os.path.join(OUT, name))
    print("wrote", name, size)
src.crop((76, 72, 174, 170)).resize((64, 64), Image.LANCZOS).save(os.path.join(OUT, "crestmini.tga"))
print("wrote crestmini.tga 64")
