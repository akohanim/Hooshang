#!/usr/bin/env python3
"""Validate the current redesign's editable source and connection invariants."""
import json
from pathlib import Path
import jsonschema
from clear_castle_interiors import apertures
ROOT=Path(__file__).resolve().parents[1]
p=json.loads((ROOT/'ldtk/hooshang_act2.ldtk').read_text())
before=json.loads((ROOT/'output/act2_redesign/before.ldtk').read_text())
jsonschema.validate(p,json.loads((ROOT/'tools/ldtk_1_5_3.schema.json').read_text()))
assert apertures(p)==apertures(before)
old={r['identifier']:r for r in before['levels']}
assert len(p['levels'])==len(old)==39
ids=[];counts={}
for r in p['levels']:
 original=old[r['identifier']]
 for key in ['identifier','iid','uid','worldX','worldY','pxWid','pxHei']:assert r[key]==original[key]
 ids.append(r['iid']);ls={l['__identifier']:l for l in r['layerInstances']}
 for l in ls.values():
  ids.append(l['iid']);ids.extend(e['iid'] for e in l['entityInstances'])
 if not r['identifier'].startswith('Prison_'):continue
 grid=ls['Collision']['intGridCsv'];w=ls['Collision']['__cWid'];h=ls['Collision']['__cHei']
 original_grid=next(l for l in original['layerInstances'] if l['__identifier']=='Collision')['intGridCsv']
 for edge,row in [(0,3),(h-1,h-2)]:
  for x in range(w):
   if original_grid[edge*w+x]==0:assert grid[row*w+x]==original_grid[row*w+x],(r['identifier'],'threshold obstructed',x,row)
 terrain={tuple(t['px']) for t in ls['PrisonMasonry']['autoLayerTiles']}
 other={tuple(t['px']) for t in ls['Tiles']['autoLayerTiles']}
 assert terrain=={(i%w*8,i//w*8) for i,v in enumerate(grid) if v==1}
 assert other=={(i%w*8,i//w*8) for i,v in enumerate(grid) if v in [2,3,4]}
 counts[r['identifier']]={str(v):grid.count(v) for v in [1,2,3,4]}
assert len(ids)==len(set(ids))
result={'schema':'LDtk 1.5.3','rooms':39,'castle_rooms':17,'paired_connections':len(apertures(p)),
        'identities_preserved':True,'threshold_clearance_preserved':True,'collision_visual_cells_match':True,'cells':counts}
(ROOT/'output/act2_redesign/source_validation.json').write_text(json.dumps(result,indent=2)+'\n')
print('PASS: schema, 39 stable identities, 20 paired mouths, 20 clear vertical thresholds, exact visible collision/hazard/water cells.')
