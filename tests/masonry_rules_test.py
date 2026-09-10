"""Run: python3 tests/masonry_rules_test.py. Guards invisible-helper edge holes."""
import json,sys,itertools
from pathlib import Path
from PIL import Image
ROOT=Path(__file__).resolve().parents[1];sys.path.insert(0,str(ROOT/'tools'))
from fix_masonry_edges import matches
p=json.loads((ROOT/'ldtk/hooshang_act1.ldtk').read_text());ld=next(l for l in p['defs']['layers'] if l['identifier']=='Collisions')
groups={v['value']:v['groupUid'] for v in ld['intGridValues']}
assert groups[1]!=groups[7] and groups[7]==groups[8]
rules=[r for g in ld['autoRuleGroups'] if g['name'].startswith(('brick_new /','stone /')) and g['active'] for r in g['rules'] if r['active']]
atlas=Image.open(ROOT/'ldtk/art/bricks_8px.png').convert('RGBA')
positions=[(0,-1),(1,0),(0,1),(-1,0),(-1,-1),(1,-1),(1,1),(-1,1)]
checked=0
for material,empty in itertools.product((7,8),(0,1)):
 for mask in range(256):
  cells=[material]*25;cells[12]=material
  for i,(dx,dy) in enumerate(positions):cells[(2+dy)*5+2+dx]=(8 if material==7 else 7) if mask>>i&1 else empty
  r=next(r for r in rules if matches(r,cells,5,5,2,2,groups))
  for side in range(4):
   if mask>>side&1:continue
   for ids in r['tileRectsIds']:
    t=ids[0];pixels=[atlas.getpixel((t*8+x,y)) for x,y in [[(u,0) for u in range(8)],[(7,u) for u in range(8)],[(u,7) for u in range(8)],[(0,u) for u in range(8)]][side]]
    # An exposed edge needs a visible face, not shared fill or dark infill.
    assert sum(c[3]>0 and max(c[:3])>70 for c in pixels)>=5,(material,empty,mask,side,t)
  checked+=1
for level in p['levels']:
 for li in level['layerInstances']:
  if li['__identifier']!='Collisions':continue
  tiles={tuple(t['px']):t for t in li['autoLayerTiles']};w,h=li['__cWid'],li['__cHei']
  for i,v in enumerate(li['intGridCsv']):
   if v not in (7,8):continue
   x,y=i%w,i//w;r=next(r for r in rules if matches(r,li['intGridCsv'],w,h,x,y,groups))
   assert tiles[(x*8,y*8)]['t'] in [ts[0] for ts in r['tileRectsIds']],(level['identifier'],x,y)
print(f'PASS: {checked} neighbor/helper configurations, every variant on exposed sides, and all authored masonry cells')
