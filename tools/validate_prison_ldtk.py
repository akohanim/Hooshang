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
    iids = [r['iid'] for r in rooms] + [l['iid'] for r in rooms for l in r['layerInstances']] + [e['iid'] for e in entities]
    assert len(iids) == len(set(iids)), 'Duplicate prison instance IID'
    keys = {e['iid']:e for e in entities if e['__identifier']=='Key'}
    assert len(keys) == 4
    assert {next(f['__value'] for f in e['fieldInstances'] if f['__identifier']=='KeyId') for e in keys.values()} == {'Red','Green','Blue','Gold'}
    assert not any(e['__identifier'] in ['Ladder','Switch','Lever','PressurePlate','LockedDoor'] for e in entities)
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
    print('PASS official LDtk 1.5.3 schema; 17 rooms; unique UIDs; 4 keys; 8 valid references; typed editor values; no climb/switch entities.')
if __name__ == '__main__':
    import sys
    validate(sys.argv[1] if len(sys.argv)>1 else ROOT/'ldtk/hooshang_act2.ldtk')
