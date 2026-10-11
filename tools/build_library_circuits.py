#!/usr/bin/env python3
"""Install editable library circuit definitions and the introductory room.
Only missing definitions/entities are added; reruns preserve LDtk hand edits.
"""
import copy
import json
import re
import subprocess
import uuid
from pathlib import Path
from ldtk_preserve_json import update
from validate_prison_ldtk import validate

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / 'ldtk/hooshang_act2.ldtk'
NAMESPACE = uuid.UUID('f640d0e1-f8c1-42ec-825e-1d26c87b64cb')

def build():
    assert 'LDtk.app/Contents/MacOS/LDtk' not in subprocess.check_output(['ps','ax','-o','comm'], text=True), 'Close LDtk before modifying source'
    raw = SOURCE.read_text()
    project = json.loads(raw)
    before = copy.deepcopy(project)
    counter = max(project['nextUid'], *[int(v) for v in re.findall(r'"uid":\s*(\d+)', raw)])
    def uid():
        nonlocal counter
        counter += 1
        return counter
    definitions = {d['identifier']: d for d in project['defs']['entities']}
    def definition(name, size, field_name, field_type):
        if name in definitions: return definitions[name]
        entity = copy.deepcopy(definitions['ShortcutDoor'])
        field = copy.deepcopy(entity['fieldDefs'][0])
        field.update(identifier=field_name, uid=uid(), __type=field_type,
                     type='F_EntityRef' if field_type=='EntityRef' else 'F_String',
                     canBeNull=False, defaultOverride=None, allowOutOfLevelRef=False,
                     allowedRefs='OnlySpecificEntity' if field_type=='EntityRef' else 'Any',
                     allowedRefsEntityUid=None, doc='Gate controlled by this touch node.' if field_type=='EntityRef' else 'Stable save identity; unique across this act.')
        entity.update(identifier=name, uid=uid(), width=size[0], height=size[1],
                      fieldDefs=[field], resizableX=name=='CircuitGate', resizableY=name=='CircuitGate',
                      tileRect=None, color='#B4C393', doc='Touch every linked node to open the gate permanently. Partial attempts reset on death or room exit.')
        project['defs']['entities'].append(entity)
        definitions[name] = entity
        return entity
    gate_def = definition('CircuitGate', (8,32), 'CircuitId', 'String')
    node_def = definition('CircuitNode', (16,16), 'Gate', 'EntityRef')
    node_def['fieldDefs'][0]['allowedRefsEntityUid'] = gate_def['uid']
    room = next(r for r in project['levels'] if r['identifier']=='Prison_G01')
    layer = next(l for l in room['layerInstances'] if l['__identifier']=='Entities')
    def entity(kind, label, point, size, value):
        ident = str(uuid.uuid5(NAMESPACE, room['identifier']+'/'+label))
        if any(e['iid']==ident for e in layer['entityInstances']): return ident
        definition = definitions[kind]
        field = definition['fieldDefs'][0]
        field_value = {'__identifier':field['identifier'], '__type':field['__type'], '__value':value,
                       '__tile':None, 'defUid':field['uid'], 'realEditorValues':[{'id':'V_String', 'params':[value['entityIid'] if isinstance(value,dict) else value]}]}
        layer['entityInstances'].append({'__identifier':kind, '__smartColor':definition['color'],
            '__grid':[point[0]//8,point[1]//8], '__pivot':[.5,.5], '__tags':definition['tags'], '__tile':None,
            '__worldX':room['worldX']+point[0], '__worldY':room['worldY']+point[1],
            'defUid':definition['uid'], 'iid':ident, 'px':list(point), 'width':size[0], 'height':size[1],
            'fieldInstances':[field_value]})
        return ident
    gate = entity('CircuitGate', 'reading_exit', (252,12), (40,24), 'library_reading')
    # Upgrade only the first prototype's cropped gate; retain later hand edits.
    placed = next(e for e in layer['entityInstances'] if e['iid']==gate)
    if placed['px']==[252,4] and placed['height']==8:
        placed.update(px=[252,12], __grid=[31,1], __worldY=room['worldY']+12, height=24)
    reference = {'entityIid':gate, 'layerIid':layer['iid'], 'levelIid':room['iid'], 'worldIid':project['iid']}
    entity('CircuitNode', 'reading_low', (104,128), (16,16), reference)
    entity('CircuitNode', 'reading_high', (200,104), (16,16), reference)
    project['nextUid'] = max(project['nextUid'], counter+1)
    for old,new in zip(before['levels'], project['levels']):
        if old['identifier']!='Prison_G01': assert old==new
    preview = ROOT/'output/prison_challenge/library_intro/preview.ldtk'
    preview.parent.mkdir(parents=True, exist_ok=True)
    preview.write_text(update(raw,project))
    validate(preview)
    if raw != preview.read_text():
        backup = preview.parent/'before.ldtk'
        if not backup.exists(): backup.write_text(raw)
        SOURCE.write_text(preview.read_text())
    print('Library introduction: two touch nodes and the sealed upper exit; geometry and other rooms preserved.')

if __name__=='__main__': build()
