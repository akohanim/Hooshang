#!/usr/bin/env python3
"""One-time LDtk R01 precision lesson. Preserve all other room data and hand edits."""
import copy,json,subprocess,uuid
from pathlib import Path
from ldtk_preserve_json import update
from validate_prison_ldtk import validate
ROOT=Path(__file__).resolve().parents[1];path=ROOT/'ldtk/hooshang_act2.ldtk'
assert 'LDtk.app/Contents/MacOS/LDtk' not in subprocess.check_output(['ps','ax','-o','comm'],text=True)
raw=path.read_text();p=json.loads(raw);before=copy.deepcopy(p)
r=next(r for r in p['levels'] if r['identifier']=='Prison_R01');ls={l['__identifier']:l for l in r['layerInstances']};ents=ls['Entities']['entityInstances']
assert not any(e['__identifier']=='CrumblingShelf' for e in ents),'Already authored: preserve LDtk edits'
template=next(e for room in p['levels'] for layer in room['layerInstances'] for e in layer['entityInstances'] if e['__identifier']=='CrumblingShelf')
e=copy.deepcopy(template);e.update(iid=str(uuid.uuid5(uuid.NAMESPACE_URL,'hooshang/precision/r01/shelf')),px=[192,148],__grid=[24,18],__worldX=r['worldX']+192,__worldY=r['worldY']+148,width=24,height=8)
gate=next(x for x in ents if x['__identifier']=='TimedGate')
f=e['fieldInstances'][0];ref=dict(entityIid=gate['iid'],layerIid=ls['Entities']['iid'],levelIid=r['iid'],worldIid=p['iid']);f['__value']=ref;f['realEditorValues']=[dict(id='V_String',params=[gate['iid']])]
ents[:]=[x for x in ents if x['__identifier']!='DarkThought'];ents.append(e)
for e in ents:
 if e['__identifier']=='PrisonSign':
  f=e['fieldInstances'][0];f['__value']='LAND / JUMP AGAIN';f['realEditorValues']=[dict(id='V_String',params=[f['__value']])]
grid=ls['Collision']['intGridCsv']
for y in range(20,23):
 for x in range(17,30):grid[y*40+x]=0
for x in range(17,30):grid[22*40+x]=3
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
 if a['identifier']!='Prison_R01':assert a==b
out=ROOT/'output/prison_precision/cafeteria_intro';out.mkdir(parents=True,exist_ok=True)
assert not (out/'before.ldtk').exists()
(out/'before.ldtk').write_text(raw);preview=out/'preview.ldtk';preview.write_text(update(raw,p));validate(preview);path.write_text(preview.read_text())
print('R01: 104px gap, 24px solid collapsing shelf, existing lever and room entrances retained')
