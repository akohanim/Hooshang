"""Prepare the remaining Act I back walls at native size; never stretch furniture."""
from pathlib import Path
import json
from PIL import Image, ImageOps

ROOT = Path(__file__).resolve().parents[1]
ART = ROOT / 'assets/background/act1_office'
world = json.loads((ROOT / 'ldtk/hooshang_act1.ldtk').read_text())
rooms = {r['identifier']: r for r in world['levels']}
for row in json.loads((ART / 'remaining_rooms.json').read_text()):
    name = row['room']
    room = rooms[name]
    size = (room['pxWid'], room['pxHei'])
    source = ART / 'source' / (name.lower() + '.png')
    if not source.exists():
        continue
    original = Image.open(source).convert('RGB')
    # Fit the height, preserving pixel proportions. Very long rooms continue
    # in reflected architectural bays, with no duplicated moons in the paint.
    width = round(original.width * size[1] / original.height)
    bay = original.resize((width, size[1]), Image.Resampling.NEAREST)
    image = Image.new('RGB', size)
    for i, x in enumerate(range(0, size[0], width)):
        image.paste(bay if i % 2 == 0 else ImageOps.mirror(bay), (x, 0))
    image = image.quantize(colors=64, dither=Image.Dither.NONE).convert('RGB')
    image.save(ART / (name.lower() + '.png'))
    print(name, size)
