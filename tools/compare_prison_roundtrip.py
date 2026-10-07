#!/usr/bin/env python3
"""Compare a generated source with a copy actually saved by LDtk."""
import json
import sys
from pathlib import Path

def compare(before, after):
    a, b = (json.loads(Path(path).read_text()) for path in (before, after))
    count = 0
    for room in a['levels']:
        if not room['identifier'].startswith('Prison_'): continue
        saved = next(r for r in b['levels'] if r['iid']==room['iid'])
        for key in ['identifier','uid','worldX','worldY','pxWid','pxHei']:
            assert room[key] == saved[key], (room['identifier'],key)
        for layer in room['layerInstances']:
            other = next(l for l in saved['layerInstances'] if l['iid']==layer['iid'])
            assert layer['intGridCsv'] == other['intGridCsv']
            for tiles in ['gridTiles','autoLayerTiles']:
                normalize = lambda data: sorted((tuple(t['px']),t['t'],t['f']) for t in data)
                assert normalize(layer[tiles]) == normalize(other[tiles]), (room['identifier'],layer['__identifier'],tiles)
            for entity in layer['entityInstances']:
                ee = next(e for e in other['entityInstances'] if e['iid']==entity['iid'])
                for key in ['__identifier','px','width','height']:
                    assert entity[key] == ee[key]
                values = lambda e: {f['__identifier']: f['__value'] for f in e['fieldInstances']}
                assert values(entity) == values(ee), (room['identifier'],entity['__identifier'])
        count += 1
    print(f'PASS LDtk editor round-trip: {count} rooms, geometry, all tile placements, entity transforms and typed field values preserved.')
if __name__ == '__main__': compare(*sys.argv[1:3])
