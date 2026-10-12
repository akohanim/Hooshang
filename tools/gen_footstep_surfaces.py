#!/usr/bin/env python3
"""Which floor tiles are SCAFFOLDING, for Sfx.surface_cue's footsteps.

At runtime the Collisions TileMapLayer only carries the auto-tiled art: the
importer keeps no IntGrid value layer for it (it has a tileset), and a cell's
atlas x is simply its LDtk tile id. So this collects every tile id LDtk paints
on an IntGrid "scaffolding" (5) cell across Act 1, asserts none of them is ever
painted on any other value, and writes the set for systems/sfx.gd to load.
Re-run after changing Act 1's Collisions auto-rules.

  python3 tools/gen_footstep_surfaces.py
"""
import json
from collections import defaultdict
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SCAFFOLD = 5
by_value = defaultdict(set)
project = json.loads((ROOT / 'ldtk/hooshang_act1.ldtk').read_text())
for level in project['levels']:
    for layer in level['layerInstances']:
        if layer['__identifier'] != 'Collisions':
            continue
        w, csv = layer['__cWid'], layer['intGridCsv']
        for tile in layer['autoLayerTiles']:
            i = (tile['px'][1] // 8) * w + tile['px'][0] // 8
            by_value[csv[i]].add(tile['t'])
scaffold = by_value[SCAFFOLD]
other = set().union(*(v for k, v in by_value.items() if k != SCAFFOLD))
assert scaffold and not (scaffold & other), sorted(scaffold & other)
out = ROOT / 'assets/audio/elevenlabs_v2/surfaces.json'
out.write_text(json.dumps({'scaffold_tiles': sorted(scaffold)}) + '\n')
print(f'{len(scaffold)} scaffold tile ids -> {out.relative_to(ROOT)}')
