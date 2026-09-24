"""Exercise serialized LDtk rules, mixed brush joins and paint/erase caches."""
import copy
import json
from pathlib import Path
from PIL import Image
import act3_connected_terrain as connected
from act3_connected_terrain import rule_matches as matches

ROOT = Path(__file__).resolve().parents[1]
p = json.loads((ROOT/'ldtk/hooshang_act3.ldtk').read_text())
definition = next(l for l in p['defs']['layers'] if l['identifier'] == 'Collisions')
rules = [r for g in definition['autoRuleGroups'] if g['active'] for r in g['rules'] if r['active']]
groups = {v['value']:v['groupUid'] for v in definition['intGridValues']}
atlas = Image.open(ROOT/'assets/act3/terrain.png').convert('RGBA')

# Independent topology oracle: evaluate every possible eight-neighbor occupancy
# for every brush, alternating DIFFERENT materials around its center.
for value, material in connected.MATERIALS.items():
    for bits in range(256):
        cells = [0]*9
        cells[4] = value
        for bit,(dx,dy) in enumerate(connected.topology.NEIGHBORS):
            if bits & (1<<bit): cells[(dy+1)*3+dx+1] = 5 if value != 5 else 2
        rule = next(r for r in rules if matches(r,cells,3,3,1,1,groups))
        tid = rule['tileRectsIds'][0][0]
        mask = connected.topology.normalized(bits)
        assert tid == connected.tile_id(material,mask), (value,bits,tid)
        assert not rule['flipX'] and not rule['flipY']
        image = atlas.crop((tid%8*8,tid//8*8,tid%8*8+8,tid//8*8+8))
        for side,(dx,dy) in enumerate(connected.topology.NEIGHBORS[:4]):
            x,y = [(3,0),(7,3),(3,7),(0,3)][side]
            # Connected boundaries must have NO white outline; exposed ones do.
            assert image.getpixel((x,y)) == (connected.BLACK if bits & (1<<side) else connected.WHITE)
assert {v['value'] for v in definition['intGridValues']} == {2,5,6}
print('PASS: only brick/grass/scaffolding brushes; 768 neighbor configurations; edges, inner corners, thin strips and isolated cells')

fill = None
for material in range(8):
    tid = connected.tile_id(material,255)
    pixels = atlas.crop((tid%8*8,tid//8*8,tid%8*8+8,tid//8*8+8)).tobytes()
    assert pixels == bytes(connected.BLACK)*64, 'Deep interiors must be plain black, with no repeated dot texture'
    if fill is None: fill = pixels
    assert pixels == fill
print('PASS: all brush and compatibility slots have identical plain-black interiors')

# The new accents are selected by the editor's actual rules, not a preview-only
# overlay. Exercise every modulo phase and verify sparsity and shared borders.
for value,material in connected.MATERIALS.items():
    probe=dict(__cWid=32,__cHei=12,intGridCsv=[0]*384,autoLayerTiles=[])
    for y in range(1,11):
        for x in range(1,31): probe['intGridCsv'][y*32+x]=value
    connected.rebake(probe,definition)
    accents=[t for t in probe['autoLayerTiles'] if t['t']>=connected.BASE_COUNT]
    assert 0 < len(accents) < len(probe['autoLayerTiles'])*0.2
    variants=set()
    for cell in accents:
        x,y=cell['px'][0]//8,cell['px'][1]//8
        period_x,period_y,placements=connected.ACCENTS[material]
        assert (x%period_x,y%period_y) in [(xx,yy) for xx,yy,_ in placements]
        assert x<=2 or x>=29 or y<=2 or y>=9, 'Deep interior must stay quiet'
        variant=(cell['t']-connected.BASE_COUNT)//47-material*2+1
        variants.add(variant)
        sx,sy=cell['src']
        art=atlas.crop((sx,sy,sx+8,sy+8))
        white=sum(c==connected.WHITE for c in art.getdata())
        assert white>=6, 'A structural fragment must not regress to one dot'
    assert variants=={1,2}
print('PASS: all three materials have sparse structural accents, both variants, staggered placement and plain deep fill')

instance = dict(__cWid=9,__cHei=9,intGridCsv=[2]*81,autoLayerTiles=[])
connected.rebake(instance,definition)
assert len(instance['autoLayerTiles']) == 81
assert next(t for t in instance['autoLayerTiles'] if t['d'][1] == 40)['t'] == connected.tile_id(0,255)
instance['intGridCsv'][40] = 0
connected.rebake(instance,definition)
assert len(instance['autoLayerTiles']) == 80
assert not any(t['d'][1] == 40 for t in instance['autoLayerTiles'])
assert next(t for t in instance['autoLayerTiles'] if t['d'][1] == 31)['t'] != connected.tile_id(0,255)
instance['intGridCsv'][40] = 5
connected.rebake(instance,definition)
assert len(instance['autoLayerTiles']) == 81
assert next(t for t in instance['autoLayerTiles'] if t['d'][1] == 31)['t'] == connected.tile_id(0,255)
assert next(t for t in instance['autoLayerTiles'] if t['d'][1] == 40)['t'] == connected.tile_id(1,255)
for tile in instance['autoLayerTiles']:
    assert tile['d'][1] == tile['px'][0]//8 + tile['px'][1]//8*9
    assert tile['src'] == [tile['t']%8*8,tile['t']//8*8]
print('PASS: erasing opens a hole and repairs neighboring rims; repainting with grass removes the seam; cache IDs stay erasable')

before = copy.deepcopy(p)
connected.install(p)
assert p == before, 'Rebuilding must preserve IDs, geometry, entities and painted caches'
for level in p['levels']:
    for layer in level['layerInstances']:
        if layer['__identifier']=='Collisions':
            clone=copy.deepcopy(layer)
            connected.rebake(clone,definition)
            assert clone==layer
print('PASS: existing rooms have fresh caches; installer is idempotent')
