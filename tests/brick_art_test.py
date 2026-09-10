"""Keep clay courses horizontal, jointed and varied on every wall orientation."""
import sys
from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parents[1] / 'tools'))
from gen_celeste_masonry import draw_brick, rules
from PIL import ImageColor
mortar = ImageColor.getcolor('#514444', 'RGBA')
for side in range(4):
    mask = rules.normalized(255 & ~(1 << side))
    variants = [draw_brick(mask, v) for v in range(4)]
    assert len({im.tobytes() for im in variants}) == 4
    if side in (1, 3):
        x = 7 if side == 1 else 0
        for im in variants:
            assert im.getpixel((x, 3)) == mortar
            assert im.getpixel((x, 7)) == mortar
            assert im.getpixel((x, 1)) != mortar
    else:
        y = 0 if side == 0 else 7
        for im in variants:
            assert 0 < sum(im.getpixel((x, y)) == mortar for x in range(8)) < 3
print('PASS: four distinct variants, horizontal mortar courses and jointed contact bands')
