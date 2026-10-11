#!/usr/bin/env python3
"""Remove the copied second opening spawn without rebuilding either room.

The duplicate occupied the same point as the original and reused the pond
room's entity IID. Keep the original opening spawn and all hand-authored data.
Run with --apply and LDtk closed; otherwise only validate a preview.
"""
import argparse
import copy
import json
import subprocess
from pathlib import Path

from ldtk_preserve_json import update
from validate_prison_ldtk import validate

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / 'ldtk/hooshang_act2.ldtk'
ORIGINAL = '0c492cb9-5cde-4bcb-8dd4-778aa67aa831'
COPIED = 'cc6df0b0-96d0-11f1-9a93-0d947fe948fa'


def main(apply):
    raw = SOURCE.read_text()
    project = json.loads(raw)
    before = copy.deepcopy(project)
    room = next(r for r in project['levels'] if r['identifier'] == 'Act_2_Level_0')
    layer = next(l for l in room['layerInstances'] if l['__identifier'] == 'Entities')
    spawns = [e for e in layer['entityInstances'] if e['__identifier'] == 'PlayerStart']
    assert {e['iid'] for e in spawns} in ({ORIGINAL, COPIED}, {ORIGINAL}), 'Spawn layout changed; inspect first.'
    assert all(e['px'] == [24, 312] for e in spawns), 'Spawn moved; inspect first.'
    layer['entityInstances'] = [e for e in layer['entityInstances'] if e['iid'] != COPIED]
    for old, new in zip(before['levels'], project['levels']):
        if new['identifier'] != room['identifier']:
            assert old == new
    out = ROOT / 'output/act2_polish/opening'
    out.mkdir(parents=True, exist_ok=True)
    preview = out / 'spawn_preview.ldtk'
    preview.write_text(update(raw, project))
    validate(preview)
    if apply and project != before:
        assert 'LDtk.app/Contents/MacOS/LDtk' not in subprocess.check_output(['ps', 'ax', '-o', 'comm'], text=True), 'Close LDtk first.'
        backup = out / 'before_spawn_cleanup.ldtk'
        assert not backup.exists(), 'Backup already exists; inspect before applying.'
        backup.write_text(raw)
        SOURCE.write_text(preview.read_text())
    print('Opening has one original spawn; pond and other rooms preserved.')


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--apply', action='store_true')
    main(parser.parse_args().apply)
