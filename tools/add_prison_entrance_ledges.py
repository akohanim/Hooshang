#!/usr/bin/env python3
"""Partial catch ledges above dry vertical seams; preserve a 24px descent gap."""
import copy,json,subprocess
from pathlib import Path
from ldtk_preserve_json import update
from validate_prison_ldtk import validate
ROOT=Path(__file__).resolve().parents[1]
path=ROOT/'ldtk/hooshang_act2.ldtk'
assert 'LDtk.app/Contents/MacOS/LDtk' not in subprocess.check_output(['ps','ax','-o','comm'],text=True)
raw=path.read_text();p=json.loads(raw);before=copy.deepcopy(p)
rule=next(a for d in p['defs']['layers'] if d['identifier']=='Tiles' for g in d['autoRuleGroups'] for a in g['rules'] if a['pattern']==[2])
tile=rule['tileRectsIds'][0][0]
placements=[('Prison_Hub',80),('Prison_Hub',400),('Prison_R02',72),('Prison_G01',80),('Prison_G02',232),('Prison_G03',232),('Prison_G04',80),('Prison_B04',80),('Prison_Y02',232)]
report=[]
for name,x in placements:
 room=next(r for r in p['levels'] if r['identifier']==name)
 layers={l['__identifier']:l for l in room['layerInstances']}
 grid=layers['Collision']['intGridCsv'];w=room['pxWid']//8;y=room['pxHei']//8-2
 assert all(grid[y*w+x//8+i]==0 for i in range(5)), 'Entrance changed; inspect before modifying '+name
 for dx in range(2):
  xx=x//8+dx;index=y*w+xx;grid[index]=2
  layers['Tiles']['autoLayerTiles'].append(dict(px=[xx*8,y*8],src=[tile%16*8,tile//16*8],t=tile,f=0,a=1,d=[rule['uid'],index]))
 report.append(dict(room=name,ledge=[x,y*8,16,8],descent_gap=[x+16,y*8,24,8]))
out=ROOT/'output/prison_precision/entrance_ledges';out.mkdir(parents=True,exist_ok=True)
assert not (out/'before.ldtk').exists(),'Already authored; preserve later edits'
(out/'before.ldtk').write_text(raw)
preview=out/'preview.ldtk';preview.write_text(update(raw,p));validate(preview)
path.write_text(preview.read_text())
(out/'placements.json').write_text(json.dumps(report,indent=2))
print('Nine dry vertical seams: 16px wooden catch ledges, 24px open descent gaps. Flooded swim seam unchanged.')
