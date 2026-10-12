"""Build lightweight room previews from LDtk; no world scenes loaded by the menu."""
import json
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
acts=[]
names={}
for recipe in ["act2_precision", "act2_expansion", "act2_final_trials"]:
 for r in json.loads((ROOT/f"resources/levels/{recipe}.json").read_text()): names[r["name"]]=r
for act in range(1,4):
 p=json.loads((ROOT/f'ldtk/hooshang_act{act}.ldtk').read_text())
 rooms=[]
 for r in p['levels']:
  cells=[]
  markers=[]
  for l in r['layerInstances']:
   if l['__identifier'] in ('Collisions','Collision','CastleTerrain'):
    for i,v in enumerate(l['intGridCsv']):
     if v: cells.append([(i%l['__cWid'])*l['__gridSize'],(i//l['__cWid'])*l['__gridSize'],l['__gridSize'],v])
    for t in l['gridTiles']+l['autoLayerTiles']:
     cells.append([*t['px'],l['__gridSize'],1])
   for e in l['entityInstances']:
    if e['__identifier'] in ['PlayerStart','PlayerSpawn','Exit','Key','Cage','Checkpoint']: markers.append([*e['px'],e['__identifier']])
  rooms.append(dict(id=r['identifier'],title=names.get(r['identifier'],{}).get('title',''),idea=names.get(r['identifier'],{}).get('idea',''),size=[r['pxWid'],r['pxHei']],cells=cells,markers=markers))
 acts.append(rooms)
(ROOT/'resources/menu/rooms.json').write_text(json.dumps(acts,separators=(',',':'))+'\n')
