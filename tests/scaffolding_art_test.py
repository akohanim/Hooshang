"""Open steel bays must survive regeneration without moving other atlas tiles."""
from pathlib import Path
import sys
from PIL import Image
ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / 'tools'))
from gen_scaffolding import tile
atlas = Image.open(ROOT / 'ldtk/art/bricks_8px.png').convert('RGBA')
for i, mask in enumerate((255, 14, 7, 6)):
    art = tile(mask)
    assert atlas.crop(((14+i)*8, 0, (15+i)*8, 8)).tobytes() == art.tobytes()
    clear = sum(pixel[3] == 0 for pixel in art.getdata())
    assert clear >= 14, (i, clear)
    # Keep a non-empty source tile, plus uninterrupted load-bearing rails.
    assert all(art.getpixel((x, 0))[3] == 255 for x in range(8))
    assert all(art.getpixel((0, y))[3] == 255 for y in range(8))
print('PASS: scaffold atlas matches generator, transparent bays and continuous rails')
