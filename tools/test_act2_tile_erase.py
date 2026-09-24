"""Regression: cached art must remain addressable by LDtk's linear cell ID."""
import copy,json
from pathlib import Path
from act2_grass_terrain import rebake_layer
p=json.loads(Path('ldtk/hooshang_act2.ldtk').read_text())
definition=next(l for l in p['defs']['layers'] if l['identifier']=='Collisions')
rules=[r for g in definition['autoRuleGroups'] if g['active'] for r in g['rules'] if r['active']]
groups={v['value']:v['groupUid'] for v in definition['intGridValues']}
for room in p['levels']:
    layer=copy.deepcopy(next(l for l in room['layerInstances'] if l['__identifier']=='Collisions'))
    rebake_layer(layer,rules,groups)
    seen=set()
    for tile in layer['autoLayerTiles']:
        coord=tile['px'][0]//8+(tile['px'][1]//8)*layer['__cWid']
        assert len(tile['d'])==2 and tile['d'][1]==coord
        assert layer['intGridCsv'][coord]!=0 and coord not in seen
        seen.add(coord)
    assert seen
    # Erase a real lower-row cell (x alone must not be mistaken for its ID).
    coord=max(seen);layer['intGridCsv'][coord]=0
    # This is how the editor addresses cached art before rebuilding neighbors.
    remaining=[t for t in layer['autoLayerTiles'] if t['d'][1]!=coord]
    assert len(remaining)==len(layer['autoLayerTiles'])-1
    rebake_layer(layer,rules,groups)
    assert not any(t['d'][1]==coord for t in layer['autoLayerTiles'])
    print('PASS',room['identifier'],'erase removes art; no ghosts or duplicate cells')
