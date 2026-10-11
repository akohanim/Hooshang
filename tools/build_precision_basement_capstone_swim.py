#!/usr/bin/env python3
"""One-time B03 deep-seal swim sequence; preserve all other rooms and entrance ledges."""
import copy,json,subprocess,uuid
from pathlib import Path
from ldtk_preserve_json import update
from validate_prison_ldtk import validate
ROOT=Path(__file__).resolve().parents[1];path=ROOT/'ldtk/hooshang_act2.ldtk'
assert 'LDtk.app/Contents/MacOS/LDtk' not in subprocess.check_output(['ps','ax','-o','comm'],text=True)
raw=path.read_text();p=json.loads(raw);before=copy.deepcopy(p)
r=next(r for r in p['levels'] if r['identifier']=='Prison_B03');ls={l['__identifier']:l for l in r['layerInstances']};es=ls['Entities']['entityInstances']
assert any(e['__identifier']=='CircuitNode' and e['px']==[104,160] for e in es),'Already authored; preserve later edits'
grid=ls['Collision']['intGridCsv'];old=grid[:]
def box(x,y,w,h,v):
 for yy in range(y//8,(y+h)//8):
  for xx in range(x//8,(x+w)//8):grid[yy*40+xx]=v
box(88,144,8,40,1)
box(128,96,8,48,1)
def move(e,x,y):
 e.update(px=[x,y],__grid=[x//8,y//8],__worldX=r['worldX']+x,__worldY=r['worldY']+y)
es[:]=[e for e in es if e['__identifier']!='DarkThought']
for e in es:
 kind=e['__identifier']
 if kind=='CircuitNode' and e['px']==[104,160]:move(e,72,128)

e=copy.deepcopy(next(e for rr in p['levels'] if rr['identifier'].startswith('Prison_') for l in rr['layerInstances'] for e in l['entityInstances'] if e['__identifier']=='DarkThought'))
e.update(iid=str(uuid.uuid5(uuid.NAMESPACE_URL,'hooshang/precision/b03/deep-patrol')),px=[112,128],__grid=[14,16],__worldX=r['worldX']+112,__worldY=r['worldY']+128)
for f in e['fieldInstances']:
 if f['__identifier'] in ['Motion','Amplitude','Speed','Phase']:
  v={'Motion':'Vertical','Amplitude':12.0,'Speed':0.35,'Phase':0.0}[f['__identifier']]
  f['__value']=v;f['realEditorValues']=[dict(id='V_String' if isinstance(v,str) else 'V_Float',params=[v])]
es.append(e)
ld={d['identifier']:d for d in p['defs']['layers']};rules=[a for g in ld['PrisonMasonry']['autoRuleGroups'] for a in g['rules']];cols=next(t['__cWid'] for t in p['defs']['tilesets'] if t['identifier']=='Act2CastleMasonry')
ls['PrisonMasonry']['autoLayerTiles']=[];ls['Tiles']['autoLayerTiles']=[]
for i,v in enumerate(grid):
 x,y=i%40,i//40
 if v==1:
  rule=next(a for a in rules if a['size']==3) if y==0 or grid[i-40]!=1 else next(a for a in rules if a['size']==1 and a['xOffset']==x%8 and a['yOffset']==y%8);target=ls['PrisonMasonry'];c=cols
 elif v in [2,3,4]:
  rule=next(a for g in ld['Tiles']['autoRuleGroups'] for a in g['rules'] if a['pattern']==[v]);target=ls['Tiles'];c=16
 else:continue
 t=rule['tileRectsIds'][0][0];target['autoLayerTiles'].append(dict(px=[x*8,y*8],src=[t%c*8,t//c*8],t=t,f=0,a=1,d=[rule['uid'],i]))
assert grid[23*40:24*40]==old[23*40:24*40]
for a,b in zip(before['levels'],p['levels']):
 if a['identifier']!='Prison_B03':assert a==b
out=ROOT/'output/prison_precision/basement_capstone';out.mkdir(parents=True,exist_ok=True)
assert not (out/'before.ldtk').exists()
(out/'before.ldtk').write_text(raw);preview=out/'preview.ldtk';preview.write_text(update(raw,p));validate(preview);path.write_text(preview.read_text())
print('B03: underwater turning sequence and one patrol; upper challenge remains to rebuild.')
