#!/usr/bin/env python3
"""Subtle original-material variations, preserving every seam and tile ID.
Run after gen_bricks_8px.py. Only legacy brick/concrete faces change; edge pixels,
mortar, transparency, newer masonry, scaffolding and luminous panels stay exact.
"""
from pathlib import Path
from PIL import Image
ROOT = Path(__file__).resolve().parents[1]
COLUMNS = [0, 1, 2, 3, 18, 19, 20, 21, 22, 23, 24, 25]

def build():
    source = Image.open(ROOT / 'ldtk/art/bricks_8px.png').convert('RGBA')
    for variant in range(1, 4):
        result = source.copy()
        for col in COLUMNS:
            for y in range(1, 7):
                for x in range(1, 7):
                    # Keep the three-pixel lip and running-bond mortar untouched.
                    topology = col % 4 if col < 4 else (col - (18 if col < 22 else 22))
                    if topology in (1, 3) and y < 3 or topology in (2, 3) and x < 3:
                        continue
                    if col not in range(18, 22) and (y % 4 == 3 or (x - (y // 4) * 4) % 8 == 0):
                        continue
                    r, g, b, a = source.getpixel((col * 8 + x, y))
                    if not a:
                        continue
                    # Coherent small mineral patches, not independent noisy pixels.
                    grain = ((x // 2) * 13 + (y // 2) * 7 + variant * 11 + col * 3) % 7
                    shift = (-5, 0, 4)[(grain + variant) % 3]
                    result.putpixel((col * 8 + x, y), (max(0,min(255,r+shift)), max(0,min(255,g+shift)), max(0,min(255,b+shift)), a))
        result.save(ROOT / f'ldtk/art/terrain_variant_{variant}.png')

if __name__ == '__main__':
    build()
