#!/usr/bin/env python3
"""Idempotently add paintable algae/fish/outlets; close LDtk before --apply."""
import copy,json,uuid,sys,subprocess,re
from pathlib import Path
root=Path(__file__).resolve().parents[1]
path=root/'ldtk/hooshang_act2.ldtk'
raw=path.read_text()
p=json.loads(raw)
if any(l['identifier']=='WaterLife' for l in p['defs']['layers']):
    print('WaterLife already installed');sys.exit()
uid=p['nextUid']
ts=copy.deepcopy(next(t for t in p['defs']['tilesets'] if t['identifier']=='Act2WaterTilesSheet'))
ts.update(uid=uid,identifier='Act2WaterLife',relPath='art/act2_water_life.png',pxWid=40,pxHei=64,__cWid=5,__cHei=8,cachedPixelData=None,savedSelections=[{'id':name,'ids':[i],'mode':'Stamp'} for i,name in enumerate(['Algae','Fish','WaterfallOutlet'])])
p['defs']['tilesets'].append(ts)
l=copy.deepcopy(next(l for l in p['defs']['layers'] if l['identifier']=='Foreground'))
l.update(uid=uid+1,identifier='WaterLife',tilesetDefUid=uid,doc='Paint first-row Algae on submerged floors, Fish in water, WaterfallOutlet at an unsupported bottom water cell. Water also dresses itself automatically.',autoRuleGroups=[])
p['defs']['layers'].insert(0,l)
for level in p['levels']:
    template=copy.deepcopy(next(x for x in level['layerInstances'] if x['__identifier']=='Foreground'))
    template.update(__identifier='WaterLife',__tilesetDefUid=uid,__tilesetRelPath=ts['relPath'],layerDefUid=uid+1,iid=str(uuid.uuid4()),gridTiles=[],autoLayerTiles=[],intGridCsv=[],entityInstances=[])
    level['layerInstances'].insert(0,template)
p['nextUid']=uid+2
if '--apply' in sys.argv:
    processes=subprocess.check_output(['ps','ax','-o','command'],text=True)
    if any(line.strip().split(' ')[0].endswith('/LDtk.app/Contents/MacOS/LDtk') for line in processes.splitlines()):raise SystemExit('Close LDtk first')
    # Preserve LDtk's compact formatting of tile arrays.
    raw=re.sub(r'("nextUid":\s*)\d+',lambda m:m[1]+str(p['nextUid']),raw,count=1)
    raw=re.sub(r'("layers":\s*\[)',lambda m:m[1]+'\n'+json.dumps(l,separators=(',',':'))+',',raw,count=1)
    raw=re.sub(r'("tilesets":\s*\[)',lambda m:m[1]+'\n'+json.dumps(ts,separators=(',',':'))+',',raw,count=1)
    instances=iter(level['layerInstances'][0] for level in p['levels'])
    raw=re.sub(r'("layerInstances":\s*\[)',lambda m:m[1]+'\n'+json.dumps(next(instances),separators=(',',':'))+',',raw)
    json.loads(raw)
    path.write_text(raw)
    print('Installed WaterLife in',len(p['levels']),'rooms')
else:print('Dry run; use --apply')
