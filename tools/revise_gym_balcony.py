#!/usr/bin/env python3
"""Replace the duplicated gym wall-hop with an original readable dash crossing."""
import copy,datetime,json,subprocess
from pathlib import Path
from ldtk_preserve_json import update
from validate_prison_ldtk import validate
ROOT=Path(__file__).resolve().parents[1];path=ROOT/'ldtk/hooshang_act2.ldtk'
assert 'LDtk.app/Contents/MacOS/LDtk' not in subprocess.check_output(['ps','ax','-o','comm'],text=True),'Close LDtk first'
raw=path.read_text();p=json.loads(raw);before=copy.deepcopy(p)
room=next(r for r in p['levels'] if r['identifier']=='Prison_Y02')
ls={l['__identifier']:l for l in room['layerInstances']};g=ls['Collision']['intGridCsv'];w=40
assert g[13*w+23]==1 and g[22*w+18]==1,'Balcony already revised; preserve later hand edits'
# Keep authored boundary apertures and every entity/connection. Two solid
# banks frame an 64px crossing; the lower hazard is visible from the takeoff.
for y in range(1,23):
 for x in range(1,39):g[y*w+x]=0
for y in range(20,24):
 for x in list(range(1,14))+list(range(22,29))+list(range(34,39)):g[y*w+x]=1
for x in range(14,22):g[22*w+x]=3;g[23*w+x]=1
for y in range(20,24):
 for x in range(29,34):g[y*w+x]=0
# A broad one-way launch deck gives the takeoff its scaffold silhouette.
for x in range(8,14):g[20*w+x]=2
layers={d['identifier']:d for d in p['defs']['layers']}
solid=[r for group in layers['PrisonMasonry']['autoRuleGroups'] for r in group['rules']]
top=next(r for r in solid if r['size']==3)
semantic={r['pattern'][0]:r for group in layers['Tiles']['autoRuleGroups'] for r in group['rules'] if len(r['pattern'])==1}
cols=next(t['__cWid'] for t in p['defs']['tilesets'] if t['identifier']=='Act2CastleMasonry')
for name in ['Tiles','PrisonMasonry']:ls[name]['autoLayerTiles']=[]
for i,v in enumerate(g):
 x,y=i%w,i//w
 if v in [2,3]:
  rule=semantic[v];t=rule['tileRectsIds'][0][0]
  ls['Tiles']['autoLayerTiles'].append(dict(px=[x*8,y*8],src=[t*8,0],t=t,f=0,a=1,d=[rule['uid'],i]))
 elif v==1:
  rule=top if y==0 or g[i-w]!=1 else next(r for r in solid if r['size']==1 and r['xOffset']==x%8 and r['yOffset']==y%8)
  t=rule['tileRectsIds'][0][0]
  ls['PrisonMasonry']['autoLayerTiles'].append(dict(px=[x*8,y*8],src=[t%cols*8,t//cols*8],t=t,f=0,a=1,d=[rule['uid'],i]))
for a,b in zip(before['levels'],p['levels']):
 if a['identifier']!='Prison_Y02':assert a==b
 else:
  for la,lb in zip(a['layerInstances'],b['layerInstances']):
   if la['__identifier'] not in ['Collision','Tiles','PrisonMasonry']:assert la==lb
out=ROOT/'output/act2_polish/gym_balcony';out.mkdir(parents=True,exist_ok=True)
(out/('before_'+datetime.datetime.now().strftime('%Y%m%d_%H%M%S')+'.ldtk')).write_text(raw)
preview=out/'preview.ldtk';preview.write_text(update(raw,p));validate(preview);path.write_text(preview.read_text())
print('Balcony crossing revised; other rooms, keys, portals, entities and scenery preserved.')
