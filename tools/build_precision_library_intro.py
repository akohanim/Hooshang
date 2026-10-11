#!/usr/bin/env python3
"""One-time G01 two-stone lesson; preserve all other rooms and entrance ledges."""
import copy,json,subprocess,uuid
from pathlib import Path
from ldtk_preserve_json import update
from validate_prison_ldtk import validate
ROOT=Path(__file__).resolve().parents[1];path=ROOT/'ldtk/hooshang_act2.ldtk'
assert 'LDtk.app/Contents/MacOS/LDtk' not in subprocess.check_output(['ps','ax','-o','comm'],text=True)
raw=path.read_text();p=json.loads(raw);before=copy.deepcopy(p)
r=next(r for r in p['levels'] if r['identifier']=='Prison_G01');ls={l['__identifier']:l for l in r['layerInstances']};es=ls['Entities']['entityInstances']
assert not any(e['__identifier']=='CrumblingPlatform' for e in es),'Already authored; preserve later edits'
grid=ls['Collision']['intGridCsv'];old=grid[:]
# Preserve boundary apertures; replace only interior collision.
for y in range(1,23):
 for x in range(1,39):grid[y*40+x]=0
def box(x,y,w,h,v):
 for yy in range(y//8,(y+h)//8):
  for xx in range(x//8,(x+w)//8):grid[yy*40+xx]=v
box(8,160,72,24,1)
box(48,136,72,8,2)
box(232,64,56,8,2)
box(232,24,40,8,2)
box(120,176,192,8,3)
box(80,176,16,8,2)
def move(e,x,y):
 e.update(px=[x,y],__grid=[x//8,y//8],__worldX=r['worldX']+x,__worldY=r['worldY']+y)
es[:]=[e for e in es if e['__identifier']!='DarkThought']
for e in es:
 kind=e['__identifier']
 if kind=='CircuitNode' and e['px'][0]==200:move(e,248,56)
 elif kind=='PrisonSign':
  move(e,96,112);f=e['fieldInstances'][0];f['__value']='KEEP MOVING';f['realEditorValues']=[dict(id='V_String',params=[f['__value']])]
d=next(d for d in p['defs']['entities'] if d['identifier']=='CrumblingPlatform')
for x,y in [(160,116),(208,92)]:
 e=dict(__identifier=d['identifier'],__smartColor=d['color'],__grid=[x//8,y//8],__pivot=[.5,.5],__tags=[],__tile=d['tileRect'],__worldX=r['worldX']+x,__worldY=r['worldY']+y,defUid=d['uid'],iid=str(uuid.uuid5(uuid.NAMESPACE_URL,f'hooshang/precision/library/intro/{x}')),px=[x,y],width=24,height=8,fieldInstances=[]);es.append(e)
ld={d['identifier']:d for d in p['defs']['layers']};rules=[a for g in ld['PrisonMasonry']['autoRuleGroups'] for a in g['rules']];cols=next(t['__cWid'] for t in p['defs']['tilesets'] if t['identifier']=='Act2CastleMasonry')
ls['PrisonMasonry']['autoLayerTiles']=[];ls['Tiles']['autoLayerTiles']=[]
for i,v in enumerate(grid):
 x,y=i%40,i//40
 if v==1:
  rule=next(a for a in rules if a['size']==3) if y==0 or grid[i-40]!=1 else next(a for a in rules if a['size']==1 and a['xOffset']==x%8 and a['yOffset']==y%8);target=ls['PrisonMasonry'];c=cols
 elif v in [2,3]:
  rule=next(a for g in ld['Tiles']['autoRuleGroups'] for a in g['rules'] if a['pattern']==[v]);target=ls['Tiles'];c=16
 else:continue
 t=rule['tileRectsIds'][0][0];target['autoLayerTiles'].append(dict(px=[x*8,y*8],src=[t%c*8,t//c*8],t=t,f=0,a=1,d=[rule['uid'],i]))
assert grid[22*40+10:22*40+15]==old[22*40+10:22*40+15]
for a,b in zip(before['levels'],p['levels']):
 if a['identifier']!='Prison_G01':assert a==b
out=ROOT/'output/prison_precision/library_intro';out.mkdir(parents=True,exist_ok=True)
assert not (out/'before.ldtk').exists()
(out/'before.ldtk').write_text(raw);preview=out/'preview.ldtk';preview.write_text(update(raw,p));validate(preview);path.write_text(preview.read_text())
print('G01: two crumble landings between permanent seal banks; both vertical connections retained.')
