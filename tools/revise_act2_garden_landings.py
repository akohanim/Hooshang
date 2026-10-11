#!/usr/bin/env python3
"""Widen the two observed tight spring catches in Apex Relay, preserving all else.

Run --apply with LDtk closed. This is a guarded one-time migration, not a room
rebuild: later hand edits remain authoritative. Existing entity IIDs are kept.
"""
import argparse
import copy
import datetime
import json
import subprocess
from pathlib import Path
from ldtk_preserve_json import update
from validate_prison_ldtk import validate
from act2_grass_terrain import rebake_layer
ROOT = Path(__file__).resolve().parents[1]
PATH = ROOT / 'ldtk/hooshang_act2.ldtk'

def main(apply, spring_catches=False, carpet_clearance=False):
    raw = PATH.read_text()
    project = json.loads(raw)
    original = copy.deepcopy(project)
    room = next(r for r in project['levels'] if r['identifier'] == 'Act_2_Level_9')
    entities = next(l for l in room['layerInstances'] if l['__identifier'] == 'Entities')['entityInstances']
    for old_x, y, old_width in [(164, 220, 40), (528, 132, 48)]:
        candidates = [e for e in entities if e['__identifier'] == 'CrumblingPlatform'
                      and e['px'][1] == y and e['px'][0] in (old_x, old_x - 8)]
        assert len(candidates) == 1, 'Landing changed; inspect before applying.'
        e = candidates[0]
        if e['px'][0] == old_x - 8 and e['width'] == old_width + 16:
            continue
        assert e['px'][0] == old_x and e['width'] == old_width
        assert e['__pivot'] == [0.5, 0.5]
        e['px'][0] -= 8
        e['width'] += 16
        e['__grid'][0] = e['px'][0] // 8
        e['__worldX'] = room['worldX'] + e['px'][0]
    changed_rooms = {room['identifier']}
    if spring_catches:
        definition = next(d for d in project['defs']['layers'] if d['identifier'] == 'Collisions')
        rules = [r for g in definition['autoRuleGroups'] if g['active'] for r in g['rules'] if r['active']]
        groups = {v['value']: v['groupUid'] for v in definition['intGridValues']}
        # Keep the landing height and far edge; extend the catch by two grid cells.
        for number, left, top in [(4, 35, 18), (7, 47, 21)]:
            catch_room = next(r for r in project['levels'] if r['identifier'] == f'Act_2_Level_{number}')
            layer = next(l for l in catch_room['layerInstances'] if l['__identifier'] == 'Collisions')
            width = layer['__cWid']
            cells = layer['intGridCsv']
            for y in (top, top + 1):
                assert cells[y * width + left] == 10, 'Landing moved; inspect before applying.'
                for x in (left - 2, left - 1):
                    assert cells[y * width + x] in (0, 10)
                    cells[y * width + x] = 10
            rebake_layer(layer, rules, groups)
            changed_rooms.add(catch_room['identifier'])
    if carpet_clearance:
        flight = next(r for r in project['levels'] if r['identifier'] == 'Act_2_Level_6')
        items = next(l for l in flight['layerInstances'] if l['__identifier'] == 'Entities')['entityInstances']
        clouds = [e for e in items if e['__identifier'] == 'LightThought' and e['px'][0] in (504, 536)]
        assert len(clouds) == 9, 'Thought column changed; inspect before applying.'
        for e in clouds:
            e['px'][0] = 504
            e['__grid'][0] = 63
            e['__worldX'] = flight['worldX'] + 504
        fruit = [e for e in items if e['__identifier'] == 'Lemon' and e['px'][0] in (480, 512) and e['px'][1] == 92]
        assert len(fruit) == 1
        fruit[0]['px'][0] = 480
        fruit[0]['__grid'][0] = 60
        fruit[0]['__worldX'] = flight['worldX'] + 480
        changed_rooms.add(flight['identifier'])
    for old, new in zip(original['levels'], project['levels']):
        if old['identifier'] not in changed_rooms: assert old == new
    out = ROOT / 'output/act2_polish/garden_audit'
    out.mkdir(parents=True, exist_ok=True)
    preview = out / 'landing_preview.ldtk'
    preview.write_text(update(raw, project))
    validate(preview)
    if apply and project != original:
        assert 'LDtk.app/Contents/MacOS/LDtk' not in subprocess.check_output(['ps','ax','-o','comm'], text=True), 'Close LDtk first.'
        stamp = datetime.datetime.now().strftime('%Y%m%d_%H%M%S')
        (out / f'before_landings_{stamp}.ldtk').write_text(raw)
        PATH.write_text(preview.read_text())
    print('Landing migration validated; far edges and unrelated rooms preserved.')

if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--apply', action='store_true')
    parser.add_argument('--spring-catches', action='store_true', help='Also widen the audited Level 4/7 solid spring catches.')
    parser.add_argument('--carpet-clearance', action='store_true', help='Move the last Level 6 cloud column 32px earlier for dismount clearance.')
    args = parser.parse_args()
    main(args.apply, args.spring_catches, args.carpet_clearance)
