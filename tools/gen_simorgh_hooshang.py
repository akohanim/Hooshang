"""Hooshang for SUPER SIMORGH's third-person opening: a 32x48-cell sheet cut
from the PixelLab pack (the same character the rig comes from), laid out like
Darkshang's own sheet so the two stand side by side in the corridor.

    row 0  facing the camera (south), breathing idle, 4 frames
    row 1  side on (east), breathing idle, 4 frames — mirrored for west
    row 2  his back (north), the rotation still

Writes assets/minigame/simorgh/hooshang_sheet.png (128x144).

    python3 tools/gen_simorgh_hooshang.py
"""
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
SRC = ROOT / 'assets/characters/hooshang/sprites'
OUT = ROOT / 'assets/minigame/simorgh/hooshang_sheet.png'
# The 88px canvas puts him at x 32-56, y 22-66; a 32x48 box round that.
BOX = (28, 20, 60, 68)


def frames(path, n):
    files = sorted(path.glob('frame_*.png'))
    step = max(1, len(files) // n)
    return [Image.open(f).convert('RGBA').crop(BOX) for f in files[::step][:n]]


def main():
    sheet = Image.new('RGBA', (128, 144), (0, 0, 0, 0))
    rows = [frames(SRC / 'animations/Breathing_Idle/south', 4),
            frames(SRC / 'animations/Breathing_Idle/east', 4),
            [Image.open(SRC / 'rotations/north.png').convert('RGBA').crop(BOX)]]
    for r, row in enumerate(rows):
        for c, im in enumerate(row):
            sheet.alpha_composite(im, (c * 32, r * 48))
    OUT.parent.mkdir(parents=True, exist_ok=True)
    sheet.save(OUT)
    print('wrote', OUT.relative_to(ROOT))


if __name__ == '__main__':
    main()
