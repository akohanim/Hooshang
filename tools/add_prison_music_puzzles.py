#!/usr/bin/env python3
"""Install two editable ordered note puzzles; preserve unrelated rooms and artwork."""
import copy
import json
import re
import subprocess
import uuid
from pathlib import Path
from ldtk_preserve_json import update
from validate_prison_ldtk import validate

ROOT=Path(__file__).resolve().parents[1]
path=ROOT/'ldtk/hooshang_act2.ldtk'
assert 'LDtk.app/Contents/MacOS/LDtk' not in subprocess.check_output(['ps','ax','-o','comm'],text=True)
raw=path.read_text();project=json.loads(raw);before=copy.deepcopy(project)
defs={d['identifier']:d for d in project['defs']['entities']}
assert 'MusicalGate' not in defs,'Already authored; preserve later LDtk edits.'
counter=max(project['nextUid'],*map(int,re.findall(r'"uid":\s*(\d+)',raw)))
def uid():
 global counter
 counter+=1
 return counter
gate_def=copy.deepcopy(defs['CircuitGate'])
gate_def.update(identifier='MusicalGate',uid=uid(),doc='Play the five linked notes in order. Completion permanently opens this key gate.')
for f in gate_def['fieldDefs']:f['uid']=uid()
project['defs']['entities'].append(gate_def);defs['MusicalGate']=gate_def
for i in range(1,6):
 d=copy.deepcopy(defs[f'MusicNote{i}'])
 ref=copy.deepcopy(defs['CircuitNode']['fieldDefs'][0])
 ref.update(uid=uid(),allowedRefsEntityUid=gate_def['uid'],editorAlwaysShow=False,editorShowInWorld=False)
 d.update(identifier=f'PrisonNote{i}',uid=uid(),fieldDefs=[ref],showName=False,doc=f'Existing musical tile, step {i} of five. Gate progress is room-local.')
 project['defs']['entities'].append(d);defs[d['identifier']]=d
for room_name,points in [
 ('Prison_G03',[(48,128),(144,88),(232,40),(128,40),(232,128)]),
 ('Prison_Y03',[(128,136),(240,80),(296,104),(200,56),(104,48)])]:
 room=next(r for r in project['levels'] if r['identifier']==room_name)
 layer=next(l for l in room['layerInstances'] if l['__identifier']=='Entities')
 entities=layer['entityInstances']
 if room_name=='Prison_G03':
  gate=next(e for e in entities if e['__identifier']=='CircuitGate')
  entities[:]=[e for e in entities if e['__identifier']!='CircuitNode']
  circuit_id='library_archive'
 else:
  gate=next(e for e in entities if e['__identifier']=='TimedShutter' and e['px'][1]==132)
  circuit_id='gym_music'
 f=gate_def['fieldDefs'][0]
 gate.update(__identifier='MusicalGate',defUid=gate_def['uid'],fieldInstances=[dict(__identifier='CircuitId',__type='String',__value=circuit_id,__tile=None,defUid=f['uid'],realEditorValues=[dict(id='V_String',params=[circuit_id])])])
 reference=dict(entityIid=gate['iid'],layerIid=layer['iid'],levelIid=room['iid'],worldIid=project['iid'])
 for i,(x,y) in enumerate(points,1):
  d=defs[f'PrisonNote{i}'];f=d['fieldDefs'][0]
  entities.append(dict(__identifier=d['identifier'],__smartColor=d['color'],__grid=[x//8,y//8],__pivot=[.5,.5],__tags=d['tags'],__tile=d['tileRect'],__worldX=room['worldX']+x,__worldY=room['worldY']+y,defUid=d['uid'],iid=str(uuid.uuid5(uuid.NAMESPACE_URL,f'hooshang/prison/music/{room_name}/{i}')),px=[x,y],width=16,height=16,fieldInstances=[dict(__identifier='Gate',__type='EntityRef',__value=reference,__tile=None,defUid=f['uid'],realEditorValues=[dict(id='V_String',params=[gate['iid']])])]))
 for e in entities:
  if e['__identifier']=='PrisonSign':
   f=e['fieldInstances'][0];f['__value']='PLAY 1 TO 5';f['realEditorValues']=[dict(id='V_String',params=[f['__value']])]
project['nextUid']=counter+1
for old,new in zip(before['levels'],project['levels']):
 if old['identifier'] not in ['Prison_G03','Prison_Y03']:assert old==new
out=ROOT/'output/prison_precision/music_foundation';out.mkdir(parents=True,exist_ok=True)
(out/'before.ldtk').write_text(raw)
preview=out/'preview.ldtk';preview.write_text(update(raw,project));validate(preview)
path.write_text(preview.read_text())
print('Authored exactly two five-note gates: library Green and gym Gold. Routes require rendered tuning.')
