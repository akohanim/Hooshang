#!/usr/bin/env python3
"""One-time LDtk R02 commitment chain. Preserve all other room data and hand edits."""
import copy,json,subprocess,uuid
from pathlib import Path
from ldtk_preserve_json import update
from validate_prison_ldtk import validate
ROOT=Path(__file__).resolve().parents[1];path=ROOT/'ldtk/hooshang_act2.ldtk'
assert 'LDtk.app/Contents/MacOS/LDtk' not in subprocess.check_output(['ps','ax','-o','comm'],text=True)
raw=path.read_text();p=json.loads(raw);before=copy.deepcopy(p)
r=next(r for r in p['levels'] if r['identifier']=='Prison_R02');ls={l['__identifier']:l for l in r['layerInstances']};ents=ls['Entities']['entityInstances']
assert not any(e['__identifier']=='CrumblingShelf' for e in ents),'Already authored: preserve LDtk edits'
template=next(e for room in p['levels'] for layer in room['layerInstances'] for e in layer['entityInstances'] if e['__identifier']=='CrumblingShelf')
gate=next(x for x in ents if x['__identifier']=='TimedGate')
f=next(f for f in gate['fieldInstances'] if f['__identifier']=='Duration');f['__value']=8.5;f['realEditorValues']=[dict(id='V_Float',params=[8.5])]
ref=dict(entityIid=gate['iid'],layerIid=ls['Entities']['iid'],levelIid=r['iid'],worldIid=p['iid'])
def move(e,x,y):e.update(px=[x,y],__grid=[x//8,y//8],__worldX=r['worldX']+x,__worldY=r['worldY']+y)
ents[:]=[e for e in ents if e['__identifier']!='DarkThought' and not (e['__identifier']=='TimedLever' and e['px'][0]==208)]
for e in ents:
 if e['__identifier']=='TimedShutter' and e['px'][0]==124:move(e,124,76);e['height']=72
 if e['__identifier']=='TimedRelay':move(e,64,80)
 if e['__identifier']=='TimedLever' and e['px'][0]==40:move(e,96,80)
 if e['__identifier']=='PrisonSign':
  move(e,176,24);f=e['fieldInstances'][0];f['__value']='KEEP MOVING';f['realEditorValues']=[dict(id='V_String',params=[f['__value']])]
for i,(x,top) in enumerate([(216,144),(176,120),(216,88),(168,64)]):
 e=copy.deepcopy(template);e.update(iid=str(uuid.uuid5(uuid.NAMESPACE_URL,'hooshang/precision/r02/shelf/'+str(i))),width=24,height=8);move(e,x,top+4)
 f=e['fieldInstances'][0];f['__value']=ref;f['realEditorValues']=[dict(id='V_String',params=[gate['iid']])];ents.append(e)
grid=ls['Collision']['intGridCsv']
def box(x,y,w,h,v):
 for yy in range(y,y+h):
  for xx in range(x,x+w):grid[yy*40+xx]=v
# Keep all outer aperture cells intact; rebuild only the interior.
box(1,1,38,22,0)
box(1,20,8,3,1);box(14,20,2,3,1);box(29,20,10,3,1)
box(30,1,1,15,1)
box(15,1,1,4,1);box(15,14,1,9,1)
box(7,11,7,1,2);box(3,14,5,1,2);box(7,17,7,1,2)
box(16,22,13,1,3)
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
for a,b in zip(before['levels'],p['levels']):
 if a['identifier']!='Prison_R02':assert a==b
out=ROOT/'output/prison_precision/cafeteria_development';out.mkdir(parents=True,exist_ok=True)
assert not (out/'before.ldtk').exists()
(out/'before.ldtk').write_text(raw);preview=out/'preview.ldtk';preview.write_text(update(raw,p));validate(preview);path.write_text(preview.read_text())
print('R02: four 24px collapsing shelves, five-action zigzag, permanent seal bank')
