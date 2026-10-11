#!/usr/bin/env python3
"""One-time G02 four-stone reversal; preserve all other rooms and entrance ledges."""
import copy,json,subprocess,uuid
from pathlib import Path
from ldtk_preserve_json import update
from validate_prison_ldtk import validate
ROOT=Path(__file__).resolve().parents[1];path=ROOT/'ldtk/hooshang_act2.ldtk'
assert 'LDtk.app/Contents/MacOS/LDtk' not in subprocess.check_output(['ps','ax','-o','comm'],text=True)
raw=path.read_text();p=json.loads(raw);before=copy.deepcopy(p)
r=next(r for r in p['levels'] if r['identifier']=='Prison_G02');ls={l['__identifier']:l for l in r['layerInstances']};es=ls['Entities']['entityInstances']
assert not any(e['__identifier']=='CrumblingPlatform' for e in es),'Already authored; preserve later edits'
grid=ls['Collision']['intGridCsv'];old=grid[:]
# Preserve boundary apertures; replace only interior collision.
for y in range(1,23):
 for x in range(1,39):grid[y*40+x]=0
def box(x,y,w,h,v):
 for yy in range(y//8,(y+h)//8):
  for xx in range(x//8,(x+w)//8):grid[yy*40+xx]=v
box(8,176,224,8,1)
box(272,176,40,8,1)
box(80,144,40,8,2)
box(144,40,40,8,2)
box(264,64,48,8,2)
box(192,88,32,8,3)
box(232,136,48,8,3)
box(232,176,16,8,2)
def move(e,x,y):
 e.update(px=[x,y],__grid=[x//8,y//8],__worldX=r['worldX']+x,__worldY=r['worldY']+y)
es[:]=[e for e in es if e['__identifier']!='DarkThought' and not (e['__identifier']=='CircuitNode' and e['px'][1]==176)]
for e in es:
 kind=e['__identifier']
 if kind=='CircuitNode':move(e,104,136) if e['px'][0]==104 else move(e,160,32)
 elif kind=='PlayerSpawn':move(e,48,170)
 elif kind=='PrisonSign':
  move(e,104,120);f=e['fieldInstances'][0];f['__value']='UP / BACK';f['realEditorValues']=[dict(id='V_String',params=[f['__value']])]
d=next(d for d in p['defs']['entities'] if d['identifier']=='CrumblingPlatform')
for x,y in [(160,132),(216,132),(264,100),(216,68)]:
 e=dict(__identifier=d['identifier'],__smartColor=d['color'],__grid=[x//8,y//8],__pivot=[.5,.5],__tags=[],__tile=d['tileRect'],__worldX=r['worldX']+x,__worldY=r['worldY']+y,defUid=d['uid'],iid=str(uuid.uuid5(uuid.NAMESPACE_URL,f'hooshang/precision/library/stacks/{x}/{y}')),px=[x,y],width=24,height=8,fieldInstances=[]);es.append(e)
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
assert grid[22*40+29:22*40+34]==old[22*40+29:22*40+34]
for a,b in zip(before['levels'],p['levels']):
 if a['identifier']!='Prison_G02':assert a==b
out=ROOT/'output/prison_precision/library_stacks';out.mkdir(parents=True,exist_ok=True)
assert not (out/'before.ldtk').exists()
(out/'before.ldtk').write_text(raw);preview=out/'preview.ldtk';preview.write_text(update(raw,p));validate(preview);path.write_text(preview.read_text())
print('G02: four temporary landings, rightward rise and leftward reversal, two endpoint seals.')
