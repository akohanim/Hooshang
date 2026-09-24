"""Bake a review-only terrain fixture using the installed LDtk auto-rules."""
import json,random
from pathlib import Path
from fix_masonry_edges import matches
ROOT=Path(__file__).resolve().parents[1]
p=json.loads((ROOT/'ldtk/hooshang_act2.ldtk').read_text());layer=next(l for l in p['defs']['layers'] if l['identifier']=='Collisions')
groups={v['value']:v['groupUid'] for v in layer['intGridValues']}
rules=[r for g in layer['autoRuleGroups'] if g['active'] and g['name'].startswith(('brick_new /','stone /','scaffolding /','stone_grey /','grass /')) for r in g['rules'] if r['active']]
result=[]
for n,value in enumerate([10,7,8,9]):
 w,h=11,14
 cells=[0]*(w*h)
 for y in range(h):
  for x in range(w):
   solid=(y>=10 or (x<2 and y>2) or (x>8 and y>5) or (3<=x<=7 and y==5) or (x==5 and 6<=y<=8))
   if value==5:solid=(y in (4,11) or x in (1,9) and y>=4 or y==8 and 4<=x<=7)
   if solid:cells[y*w+x]=value
 for i,v in enumerate(cells):
  if not v:continue
  x,y=i%w,i//w;rng=random.Random(f'{value}:{x}:{y}')
  rule=next(r for r in rules if matches(r,cells,w,h,x,y,groups) and rng.random()<r['chance'])
  tid=rng.choice(rule['tileRectsIds'])[0];result.append([2+n*13+x,5+y,tid])
# A continuous mass crosses material boundaries: the core should have no seam.
w,h=50,10
cells=[([10,7,8,9][min(x//13,3)] if y>=2+(x//10)%3 else 0) for y in range(h) for x in range(w)]
for i,v in enumerate(cells):
 if not v:continue
 x,y=i%w,i//w;rng=random.Random(f'mixed:{x}:{y}')
 rule=next(r for r in rules if matches(r,cells,w,h,x,y,groups) and rng.random()<r['chance'])
 tid=rng.choice(rule['tileRectsIds'])[0];result.append([2+x,23+y,tid])
(ROOT/'output/act2_materials/fixture.json').write_text(json.dumps(result))
print('Baked',len(result),'cells with installed LDtk rules')
