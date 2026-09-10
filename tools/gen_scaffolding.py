"""Open galvanized scaffold bays on the existing four tile IDs (14..17).
Run directly to patch only scaffolding in the shared atlas. No LDtk edits.
Imported collision remains a full cell: the openings are visual, not passages.
"""
from pathlib import Path
from PIL import Image, ImageDraw
ROOT = Path(__file__).resolve().parents[1]

def tile(mask):
    im = Image.new('RGBA', (8, 8))
    d = ImageDraw.Draw(im)
    # Two steel diagonals with darker rear bracing, open sky between them.
    d.line((1, 1, 6, 6), fill='#47536d')
    d.line((1, 6, 6, 1), fill='#8496ae')
    # Continuous tubular rails. Cool highlights sit on the outer arris.
    d.line((0, 0, 7, 0), fill='#b3bec9')
    d.line((0, 1, 7, 1), fill='#53647c')
    d.line((0, 0, 0, 7), fill='#a0b0c3')
    d.line((1, 2, 1, 7), fill='#506078')
    d.line((7, 2, 7, 7), fill='#3e4c64')
    d.line((2, 7, 7, 7), fill='#3e4c64')
    # Clamp collars at the post/rail junction, not masonry speckles.
    d.point((0, 0), fill='#d2d7d9')
    d.point((1, 1), fill='#899aaa')
    d.point((4, 4), fill='#a5b3bf')
    if mask in (14, 6):
        d.line((2, 0, 7, 0), fill='#ccd2d3')
    if mask in (7, 6):
        d.line((0, 2, 0, 7), fill='#c0c9d0')
    return im

def connected(mask, variant):
    reinforced = variant >= 4 or mask not in (5, 10)
    variant %= 4
    # Bits N/E/S/W mean adjacent scaffolding: omit end caps at shared seams.
    im = Image.new('RGBA', (8, 8)); d = ImageDraw.Draw(im)
    for side in range(4):
        if mask & (1 << side): continue
        if side == 0: d.line((0,0,7,0), fill='#bdc9d2'); d.line((0,1,7,1), fill='#586a82')
        if side == 1: d.line((7,0,7,7), fill='#93a6bc'); d.line((6,0,6,7), fill='#465a73')
        if side == 2: d.line((0,7,7,7), fill='#8f9fb5'); d.line((0,6,7,6), fill='#45556e')
        if side == 3: d.line((0,0,0,7), fill='#bdc9d2'); d.line((1,0,1,7), fill='#586a82')
    # Braces meet at consistent connection points; surface wear varies inside.
    d.line((1,1,6,6), fill=['#63768f','#74869d','#63768f','#8292a6'][variant])
    d.line((1,6,6,1), fill=['#879bb4','#6d819b','#99aabd','#798da8'][variant])
    d.point((3,3), fill='#aebdc9')
    d.point(((2,4,5,3)[variant],(2,3,2,4)[variant]), fill='#45566d')
    if reinforced:
        # Boxed couplers at load changes; inset cheeks leave the central hole.
        d.rectangle((0,0,7,7), outline='#9aadc2')
        d.line((0,0,7,0), fill='#c0ccd5')
        d.line((0,0,0,7), fill='#bcc8d3')
        for x,y in [(1,1),(5,1),(1,5),(5,5)]:
            d.rectangle((x,y,x+1,y+1), fill='#71859f')
        for point in [(1,1),(6,1),(1,6),(6,6)]: d.point(point,fill='#cbd2d6')
    return im

def run():
    path = ROOT / 'ldtk/art/bricks_8px.png'
    sheet = Image.open(path).convert('RGBA')
    assert sheet.width >= 18 * 8
    tiles = [tile(mask) for mask in (255, 14, 7, 6)]
    for i, art in enumerate(tiles):
        sheet.paste(art, ((14+i)*8, 0))  # replace alpha too, never alpha-composite
    if sheet.width >= 544*8:
        for mask in range(16):
            for v in range(8): sheet.paste(connected(mask,v), ((416+mask*8+v)*8,0))
    sheet.save(path)
    strip = Image.new('RGBA', (32, 8))
    for i, art in enumerate(tiles): strip.paste(art, (8*i, 0))
    strip.save(ROOT / 'ldtk/art/scaffolding_8px.png')
    variants = Image.new('RGBA', (128, 64))
    for mask in range(16):
        for v in range(8): variants.paste(connected(mask, v), (mask*8, v*8))
    variants.save(ROOT / 'ldtk/art/scaffolding_connected.png')
    # A tall frame and a compact platform against a sky-colored backing.
    preview = Image.new('RGBA', (128, 80), '#18212d')
    for ox, oy, w, h in [(8, 8, 7, 8), (80, 24, 5, 4)]:
        for y in range(h):
            for x in range(w):
                if x not in (0, w-1) and y not in (0, h-1): continue
                cells = {(a,b) for a in range(w) for b in range(h) if a in (0,w-1) or b in (0,h-1)}
                mask = sum(1<<k for k,(dx,dy) in enumerate([(0,-1),(1,0),(0,1),(-1,0)]) if (x+dx,y+dy) in cells)
                art = connected(mask, (x*7+y*13+ox)%4 + (4 if mask not in (5,10) or (x if mask==10 else y)%6==3 else 0))
                preview.alpha_composite(art, (ox+x*8, oy+y*8))
    preview.resize((768, 480), Image.Resampling.NEAREST).save(ROOT / 'ldtk/art/scaffolding_preview.png')
    print('Scaffolding updated: IDs 14..17, transparent steel-braced bays.')

if __name__ == '__main__': run()
