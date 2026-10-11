#!/usr/bin/env python3
"""One-time Y03 musical reversal; preserve all other rooms and entrance ledges."""
import copy,json,subprocess,uuid
from pathlib import Path
from ldtk_preserve_json import update
from validate_prison_ldtk import validate
ROOT=Path(__file__).resolve().parents[1];path=ROOT/'ldtk/hooshang_act2.ldtk'
assert 'LDtk.app/Contents/MacOS/LDtk' not in subprocess.check_output(['ps','ax','-o','comm'],text=True)
raw=path.read_text();p=json.loads(raw);before=copy.deepcopy(p)
r=next(r for r in p['levels'] if r['identifier']=='Prison_Y03');ls={l['__identifier']:l for l in r['layerInstances']};es=ls['Entities']['entityInstances']
assert not any(e['__identifier']=='CrumblingShelf' for e in es),'Already authored; preserve later edits'
grid=ls['Collision']['intGridCsv'];old=grid[:]
def box(x,y,w,h,v):
 for yy in range(y//8,(y+h)//8):
  for xx in range(x//8,(x+w)//8):grid[yy*40+xx]=v
# Remove redundant upper rests; retain the top entrance landing at y24.
for y in [40,64,72,88]:
 for x in range(72,288,8):
  if y==88 and x<200:continue
  if grid[(y//8)*40+x//8]==2:grid[(y//8)*40+x//8]=0
box(224,8,8,40,1)
box(160,120,24,8,0)
box(64,64,32,8,2)
es[:]=[e for e in es if e['__identifier']!='DarkThought']
for e in es:
 if e['__identifier']=='TimedGate' and any(f['__identifier']=='PuzzleId' and f['__value']=='gym_reverse' for f in e['fieldInstances']):
  f=next(f for f in e['fieldInstances'] if f['__identifier']=='Duration');f['__value']=8.0;f['realEditorValues']=[dict(id='V_Float',params=[8.0])]
d=next(d for d in p['defs']['entities'] if d['identifier']=='CrumblingShelf')
gate=next(e for e in es if e['__identifier']=='TimedGate' and any(f['__identifier']=='PuzzleId' and f['__value']=='gym_reverse' for f in e['fieldInstances']))
ref=dict(entityIid=gate['iid'],layerIid=ls['Entities']['iid'],levelIid=r['iid'],worldIid=p['iid'])
for x,y in [(248,60),(152,60)]:
 fields=[dict(__identifier=f['identifier'],__type=f['__type'],__value=ref,__tile=None,defUid=f['uid'],realEditorValues=[dict(id='V_String',params=[ref['entityIid']])]) for f in d['fieldDefs']]
 e=dict(__identifier=d['identifier'],__smartColor=d['color'],__grid=[x//8,y//8],__pivot=[.5,.5],__tags=[],__tile=d['tileRect'],__worldX=r['worldX']+x,__worldY=r['worldY']+y,defUid=d['uid'],iid=str(uuid.uuid5(uuid.NAMESPACE_URL,f'hooshang/precision/gym/music/{x}')),px=[x,y],width=24,height=8,fieldInstances=fields);es.append(e)
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
assert grid[3*40+29:3*40+34]==old[3*40+29:3*40+34]
assert grid[23*40:]==old[23*40:]
for a,b in zip(before['levels'],p['levels']):
 if a['identifier']!='Prison_Y03':assert a==b
out=ROOT/'output/prison_precision/gym_music';out.mkdir(parents=True,exist_ok=True)
assert not (out/'before.ldtk').exists()
(out/'before.ldtk').write_text(raw);preview=out/'preview.ldtk';preview.write_text(update(raw,p));validate(preview);path.write_text(preview.read_text())
print('Y03: upper music reversal, two crumble stones and under-beam transfer.')
