#!/usr/bin/env python3
"""Native thorn-and-rose field: 16 connections × 4 variants × 6 frames.
The existing filename is retained for saved LDtk/Godot resource compatibility.
Only palette colors are sampled from the PixelLab swatch; no art is resized.
"""
from collections import Counter
from pathlib import Path
import math
from PIL import Image, ImageDraw
ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / 'ldtk/art/source/act2_rose_thorns.png'
OUT = ROOT / 'ldtk/art/act2_ink_thought_tiles.png'
VARIANTS = 4

def mix(a, b, t):
    return tuple(round(x + (y-x)*t) for x, y in zip(a, b))

def ramp(predicate):
    colors = Counter(p[:3] for p in Image.open(SOURCE).convert('RGBA').getdata()
                     if p[3] > 200 and predicate(*p[:3]))
    assert colors, 'Source swatch must contain the requested botanical colors'
    return sorted([c for c, _ in colors.most_common(12)], key=lambda c: sum(c))

reds = ramp(lambda r,g,b: r > g*1.35 and r > b*1.12)
greens = ramp(lambda r,g,b: g > r*1.08 and g > b*1.08)
ivory = ramp(lambda r,g,b: min(r,g,b) > 125 and max(r,g,b)-min(r,g,b) < 100)
wood = mix(reds[0], greens[0], .4)
leaf_dark, leaf_light = greens[0], greens[-1]
rose_dark, rose_light = reds[0], reds[-1]
thorn = ivory[-1]
sheet = Image.new('RGBA', (512, 48))
for frame in range(6):
    for variant in range(VARIANTS):
        for mask in range(16):
            tile = Image.new('RGBA', (8,8))
            d = ImageDraw.Draw(tile)
            pulse = .04 * math.sin(frame*math.tau/6 + variant)
            leaf = mix(leaf_dark, leaf_light, .52+pulse)
            petal = mix(rose_dark, rose_light, .64+pulse)
            # Intertwined woody runners meet neighboring cells at fixed ports.
            d.line([(0,5),(2,6),(4,4),(7,5)], fill=wood, width=2)
            d.line([(0,3),(2,4),(5,6),(7,3)], fill=leaf_dark)
            d.line([(0,5),(2,5),(4,3),(7,5)], fill=leaf)
            if mask & 1: d.line([(3,0),(4,2),(3,5)], fill=wood, width=2)
            if mask & 4: d.line([(3,4),(4,6),(3,7)], fill=wood, width=2)
            # Small tapered leaves, not a solid rectangular fill.
            d.polygon([(0,6),(2,6),(1,7)], fill=leaf_light)
            d.polygon([(5,5),(7,6),(6,7)], fill=leaf)
            # Exposed perimeter bears hooked ivory thorns; no colored border.
            if not mask & 1:
                tip = 1 if variant%2 == 0 else 2
                d.line([(tip,0),(tip,1),(tip+1,2),(tip+1,4)], fill=wood, width=1)
                d.line([(tip,0),(tip,1),(tip+1,2)], fill=thorn)
                d.line([(6,1),(5,3),(5,4)], fill=wood, width=2)
                d.line([(6,1),(5,2)], fill=mix(thorn,leaf_light,.2))
            if not mask & 4:
                d.line([(3,5),(2,7)], fill=wood)
                d.point((2,7), fill=thorn)
            if not mask & 8:
                d.line([(0,2),(2,3)], fill=thorn)
            if not mask & 2:
                d.line([(5,4),(7,2)], fill=thorn)
            # Alternate blossoms and brambles rather than stamping a rose in
            # every cell. Layered five-pixel corollas with dark curled centres.
            if variant in (1,3):
                cx,cy = (4,5) if variant == 1 else (3,4)
                pattern = ['.rrr.','rhhpr','rhddr','.rpr.','..r..']
                colors = {'r':rose_dark,'h':rose_light,'p':petal,'d':mix(rose_dark,wood,.45)}
                for yy,row in enumerate(pattern):
                    for xx,c in enumerate(row):
                        x,y = cx-2+xx,cy-2+yy
                        if c != '.' and 0<=x<8 and 0<=y<8:d.point((x,y),fill=colors[c])
            elif variant == 2:
                d.line([(3,5),(4,2)],fill=wood)
                d.point((4,2),fill=petal)
                d.point((5,2),fill=rose_dark)
            sheet.paste(tile, ((variant*16+mask)*8,frame*8))
sheet.save(OUT)
print(OUT, '512x48; 16 connections, four botanical variants, six stable silhouettes')
