#!/usr/bin/env python3
"""Match prison crumble entities to the existing crumble icon, without geometry edits."""
import copy
import json
import subprocess
from pathlib import Path
from ldtk_preserve_json import update
from validate_prison_ldtk import validate

ROOT = Path(__file__).resolve().parents[1]
path = ROOT / 'ldtk/hooshang_act2.ldtk'
assert 'LDtk.app/Contents/MacOS/LDtk' not in subprocess.check_output(['ps', 'ax', '-o', 'comm'], text=True)
raw = path.read_text()
project = json.loads(raw)
source = next(d for d in project['defs']['entities'] if d['identifier'] == 'CrumblingPlatform')
target = next(d for d in project['defs']['entities'] if d['identifier'] == 'CrumblingShelf')
for key in ('tilesetId', 'tileRect', 'uiTileRect', 'tileRenderMode'):
    target[key] = copy.deepcopy(source[key])
target['doc'] = 'Existing crumbling stones. Linked lever, death and room re-entry restore them.'
for room in project['levels']:
    for layer in room['layerInstances']:
        for entity in layer['entityInstances']:
            if entity['__identifier'] == 'CrumblingShelf':
                entity['__tile'] = copy.deepcopy(target['tileRect'])
out = ROOT / 'output/prison_precision/existing_crumble_art'
out.mkdir(parents=True, exist_ok=True)
if not (out / 'before.ldtk').exists():
    (out / 'before.ldtk').write_text(raw)
preview = out / 'preview.ldtk'
preview.write_text(update(raw, project))
validate(preview)
path.write_text(preview.read_text())
