#!/usr/bin/env python3
"""Develop the library climb into a reversible zigzag before the archive."""
import copy,json,datetime,subprocess
from pathlib import Path
from ldtk_preserve_json import update
from validate_prison_ldtk import validate
ROOT=Path(__file__).resolve().parents[1];path=ROOT/'ldtk/hooshang_act2.ldtk'
assert 'LDtk.app/Contents/MacOS/LDtk' not in subprocess.check_output(['ps','ax','-o','comm'],text=True),'Close LDtk first'
raw=path.read_text();p=json.loads(raw);before=copy.deepcopy(p)
defs={d['identifier']:d for d in p['defs']['layers']}
solid_rules=[r for g in defs['PrisonMasonry']['autoRuleGroups'] for r in g['rules']]
top=next(r for r in solid_rules if r['size']==3)
oneway=next(r for g in defs['Tiles']['autoRuleGroups'] for r in g['rules'] if r['pattern']==[2])
cols=next(t['__cWid'] for t in p['defs']['tilesets'] if t['identifier']=='Act2CastleMasonry')
for name in ['Prison_G02','Prison_G03']:
 room=next(r for r in p['levels'] if r['identifier']==name);ls={l['__identifier']:l for l in room['layerInstances']}
 g=ls['Collision']['intGridCsv'];w=40
 edge=39 if name=='Prison_G02' else 0
 assert all(g[y*w+edge]==0 for y in range(16,20)), 'Room already revised; preserve edits.'
 for y in range(16,20):g[y*w+edge]=1
 for y in range(4,8):g[y*w+edge]=0
 shelves=[(19,14,7),(27,11,7),(34,8,5)] if name=='Prison_G02' else [(1,8,8),(3,11,7),(10,14,7),(3,17,7)]
 for x,y,length in shelves:
  for xx in range(x,x+length):assert g[y*w+xx] in (0,2);g[y*w+xx]=2
 assert set(g)<={0,1,2}
 ls['Tiles']['autoLayerTiles']=[];ls['PrisonMasonry']['autoLayerTiles']=[]
 for i,v in enumerate(g):
  x,y=i%w,i//w
  if v==2:
   ls['Tiles']['autoLayerTiles'].append(dict(px=[x*8,y*8],src=[40,0],t=5,f=0,a=1,d=[oneway['uid'],i]))
  elif v==1:
   r=top if y==0 or g[i-w]!=1 else next(r for r in solid_rules if r['size']==1 and r['xOffset']==x%8 and r['yOffset']==y%8)
   t=r['tileRectsIds'][0][0]
   ls['PrisonMasonry']['autoLayerTiles'].append(dict(px=[x*8,y*8],src=[t%cols*8,t//cols*8],t=t,f=0,a=1,d=[r['uid'],i]))
for a,b in zip(before['levels'],p['levels']):
 if a['identifier'] not in ['Prison_G02','Prison_G03']:assert a==b
 else:
  for la,lb in zip(a['layerInstances'],b['layerInstances']):
   if la['__identifier'] not in ['Collision','Tiles','PrisonMasonry']:assert la==lb
out=ROOT/'output/act2_polish/library_stacks';out.mkdir(parents=True,exist_ok=True)
(out/('before_'+datetime.datetime.now().strftime('%Y%m%d_%H%M%S')+'.ldtk')).write_text(raw)
preview=out/'preview.ldtk';preview.write_text(update(raw,p));validate(preview);path.write_text(preview.read_text())
print('Book Stacks now folds left, right, then up to a paired archive entrance; keys and shortcuts unchanged.')
