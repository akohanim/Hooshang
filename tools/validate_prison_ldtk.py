#!/usr/bin/env python3
"""Validate the editable source, references and progression without importing Godot."""
import json
from pathlib import Path
import jsonschema
ROOT = Path(__file__).resolve().parents[1]
def validate(path):
    p = json.loads(Path(path).read_text())
    jsonschema.validate(p, json.loads((ROOT/'tools/ldtk_1_5_3.schema.json').read_text()))
    rooms = [r for r in p['levels'] if r['identifier'].startswith('Prison_')]
    assert len(rooms) == 17
    definitions = p['defs']
    uids = [r['uid'] for r in p['levels']]
    for category in ['entities','layers','tilesets','enums','levelFields']:
        uids.extend(d['uid'] for d in definitions[category])
    uids.extend(f['uid'] for d in definitions['entities'] for f in d['fieldDefs'])
    assert len(uids) == len(set(uids)), 'Duplicate definition/level UID'
    entities = [e for r in rooms for l in r['layerInstances'] for e in l['entityInstances']]
    all_rooms = p['levels']
    iids = [r['iid'] for r in all_rooms] + [l['iid'] for r in all_rooms for l in r['layerInstances']] + [e['iid'] for r in all_rooms for l in r['layerInstances'] for e in l['entityInstances']]
    assert len(iids) == len(set(iids)), 'Duplicate project instance IID'
    keys = {e['iid']:e for e in entities if e['__identifier']=='Key'}
    assert len(keys) == 4
    assert {next(f['__value'] for f in e['fieldInstances'] if f['__identifier']=='KeyId') for e in keys.values()} == {'Red','Green','Blue','Gold'}
    assert not any(e['__identifier'] in ['Ladder','Checkpoint'] for e in entities)
    gates = {e['iid']:e for e in entities if e['__identifier'] in ['CircuitGate','FloodGate','MusicalGate']}
    circuits = [next(f['__value'] for f in e['fieldInstances'] if f['__identifier']=='CircuitId') for e in gates.values()]
    assert all(isinstance(c,str) and c.strip() for c in circuits)
    assert len(circuits)==len(set(circuits)), 'Duplicate circuit save identity'
    members = {iid:[] for iid in gates}
    for room in rooms:
        local = {e['iid'] for l in room['layerInstances'] for e in l['entityInstances']}
        for l in room['layerInstances']:
            for e in l['entityInstances']:
                if e['__identifier'] not in ['CircuitNode','FloodValve'] and not e['__identifier'].startswith('PrisonNote'): continue
                ref = next(f['__value'] for f in e['fieldInstances'] if f['__identifier']=='Gate')
                assert ref['entityIid'] in gates and ref['entityIid'] in local, 'Circuit gate must be in the same room'
                assert ref['levelIid']==room['iid']
                expected_gate = 'MusicalGate' if e['__identifier'].startswith('PrisonNote') else 'FloodGate' if e['__identifier']=='FloodValve' else 'CircuitGate'
                assert gates[ref['entityIid']]['__identifier']==expected_gate, 'Control must match its LDtk reference type'
                if e['__identifier']=='FloodValve':
                    settings = {f['__identifier']:f['__value'] for f in e['fieldInstances']}
                    assert isinstance(settings['Touch'],bool) and isinstance(settings['RequireDry'],bool)
                members[ref['entityIid']].append(e['iid'])
    for iid,nodes in members.items():
        kind=gates[iid]['__identifier']
        if kind=='MusicalGate':
            assert sorted(e['__identifier'] for e in entities if e['iid'] in nodes)==[f'PrisonNote{i}' for i in range(1,6)], 'Musical gate requires exactly notes 1–5'
        else:
            assert len(nodes)==1 if kind=='FloodGate' else 2 <= len(nodes) <= 4, 'Flood gate requires one valve; circuits require 2–4 nodes'
    if any(d['identifier']=='MusicalGate' for d in definitions['entities']):
        assert sum(e['__identifier']=='MusicalGate' for e in entities)==2, 'Exactly two prison musical puzzles'
    timed = {e['iid']:e for e in entities if e['__identifier']=='TimedGate'}
    def fields(e): return {f['__identifier']:f['__value'] for f in e['fieldInstances']}
    puzzle_ids = [fields(g)['PuzzleId'] for g in timed.values()]
    assert all(isinstance(i,str) and i.strip() for i in puzzle_ids)
    assert len(puzzle_ids)==len(set(puzzle_ids)), 'Duplicate timed puzzle identity'
    assert all(0 < fields(g)['Duration'] <= 60 for g in timed.values()), 'Invalid countdown duration'
    controls = {iid:[] for iid in timed}
    for room in rooms:
        local = {e['iid'] for l in room['layerInstances'] for e in l['entityInstances']}
        for layer in room['layerInstances']:
            for e in layer['entityInstances']:
                if e['__identifier'] not in ['TimedLever','TimedRelay','TimedShutter','CrumblingShelf','PressurePlate']: continue
                if e['__identifier']=='TimedShutter': assert isinstance(fields(e)['RequireBank'],bool), 'RequireBank must be boolean'
                ref = fields(e)['Gate']
                assert ref['entityIid'] in timed and ref['entityIid'] in local and ref['levelIid']==room['iid'], 'Timed controls must reference their own room gate'
                controls[ref['entityIid']].append(e)
    for control in controls.values():
        assert sum(e['__identifier']=='TimedRelay' for e in control)==1, 'One completion relay per timed gate'
        levers = [e for e in control if e['__identifier']=='TimedLever']
        assert any(fields(e)['CanBank'] is True for e in levers) or any(e['__identifier']=='PressurePlate' for e in control), 'Missing start lever or pressure plate'
        assert any(fields(e)['CanBank'] is False for e in levers), 'Missing safe return lever'
    doors = [e for e in entities if e['__identifier']=='ShortcutDoor']
    assert len(doors) == 8
    for door in doors:
        ref = next(f for f in door['fieldInstances'] if f['__identifier']=='Key')
        assert ref['__value']['entityIid'] in keys
        assert ref['realEditorValues'][0] == {'id':'V_String','params':[ref['__value']['entityIid']]}
    for room in rooms:
        grid = next(l for l in room['layerInstances'] if l['__identifier']=='Collision')
        assert len(grid['intGridCsv']) == room['pxWid']//8 * (room['pxHei']//8)
        assert set(grid['intGridCsv']) <= {0,1,2,3,4}
        assert room['worldX'] % 320 == 0 and room['worldY'] % 192 == 0
        for layer in room['layerInstances']:
            for tile in layer['gridTiles']:
                assert tile['d'][0] == tile['px'][0]//8 + tile['px'][1]//8 * layer['__cWid']
            for tile in layer['autoLayerTiles']:
                if layer['__identifier']=='Tiles':
                    rules = next(d['autoRuleGroups'][0]['rules'] for d in definitions['layers'] if d['identifier']=='Tiles')
                    assert tile['d'][0] in {r['uid'] for r in rules}
            for entity in layer['entityInstances']:
                for field in entity['fieldInstances']:
                    if field['__value'] is None: continue
                    expected = {'Float':'V_Float','Int':'V_Int','Bool':'V_Bool'}.get(field['__type'],'V_String')
                    assert field['realEditorValues'][0]['id'] == expected, (room['identifier'],field)
    print('PASS official LDtk 1.5.3 schema; 17 rooms; unique UIDs; 4 keys; 8 valid references; typed editor values; valid local circuits; no climb/checkpoint-flag entities.')
if __name__ == '__main__':
    import sys
    validate(sys.argv[1] if len(sys.argv)>1 else ROOT/'ldtk/hooshang_act2.ldtk')
