#!/usr/bin/env python3
"""One-time Y02 solid launch bank; preserve the actual one-way entrance catch."""
import copy,json,subprocess,uuid
from pathlib import Path
from ldtk_preserve_json import update
from validate_prison_ldtk import validate
ROOT=Path(__file__).resolve().parents[1];path=ROOT/'ldtk/hooshang_act2.ldtk'
assert 'LDtk.app/Contents/MacOS/LDtk' not in subprocess.check_output(['ps','ax','-o','comm'],text=True)
raw=path.read_text();p=json.loads(raw);before=copy.deepcopy(p)
r=next(r for r in p['levels'] if r['identifier']=='Prison_Y02');ls={l['__identifier']:l for l in r['layerInstances']};es=ls['Entities']['entityInstances']
assert all(ls['Collision']['intGridCsv'][20*40+x]==2 for x in range(8,14)), 'Launch bank already solid'
grid=ls['Collision']['intGridCsv'];old=grid[:]
def box(x,y,w,h,v):
 for yy in range(y//8,(y+h)//8):
  for xx in range(x//8,(x+w)//8):grid[yy*40+xx]=v
box(64,160,48,24,1)
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
assert grid[23*40:]==old[23*40:]
for a,b in zip(before['levels'],p['levels']):
 if a['identifier']!='Prison_Y02':assert a==b
out=ROOT/'output/prison_precision/gym_balcony';out.mkdir(parents=True,exist_ok=True)
assert not (out/'before_solid_launch.ldtk').exists()
(out/'before_solid_launch.ldtk').write_text(raw);preview=out/'solid_launch.ldtk';preview.write_text(update(raw,p));validate(preview);path.write_text(preview.read_text())
print('Y02 launch bank solid; actual entrance catch remains one-way.')
