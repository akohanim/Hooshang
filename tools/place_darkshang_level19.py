#!/usr/bin/env python3
"""Link the four hand-placed Level_20 strips to its ladder-bottom trigger."""
import copy
import json
import re
import sys
from pathlib import Path
from ldtk_add_ceiling_tile import array_end, ldtk_running
from place_darkshang_15_18 import instance
ROOT=Path(__file__).resolve().parents[1]
KEY='L19_LadderBottom'

def main(apply=False):
 path=ROOT/'ldtk/hooshang_act1.ldtk'
 raw=path.read_text();before=json.loads(raw);after=copy.deepcopy(before)
 room=next(r for r in after['levels'] if r['identifier']=='Level_20')
 layer=next(l for l in room['layerInstances'] if l['__identifier']=='Entities')
 strips=sorted((e for e in layer['entityInstances'] if e['__identifier']=='ShadowEruption'),key=lambda e:-e['px'][0])
 assert [e['px'] for e in strips]==[[604,332],[532,356],[460,324],[116,324]],'Review changed manual placements before applying'
 for strip,sequence in zip(strips,[0,1,2,7]):
  values={'EncounterID':KEY,'Sequence':sequence,'WarningTime':1.5,'ActiveTime':.8}
  for f in strip['fieldInstances']:
   if f['__identifier'] in values:
    v=values[f['__identifier']];f['__value']=v
    f['realEditorValues']=[{'id':'V_String' if isinstance(v,str) else 'V_Float','params':[v]}]
 definition=next(e for e in after['defs']['entities'] if e['identifier']=='ShadowEruptionTrigger')
 existing=next((e for e in layer['entityInstances'] if e['__identifier']=='ShadowEruptionTrigger' and any(f['__identifier']=='EncounterID' and f['__value']==KEY for f in e['fieldInstances'])),None)
 ladder=next(e for e in layer['entityInstances'] if e['__identifier']=='Ladder')
 bottom=(ladder['px'][0],int(ladder['px'][1]+ladder['height']/2))
 trigger=instance(definition,room,bottom,(32,16),{'EncounterID':KEY,'SequenceDelay':1.0,'RepeatDelay':0},existing['iid'] if existing else None)
 if existing:layer['entityInstances'][layer['entityInstances'].index(existing)]=trigger
 else:layer['entityInstances'].append(trigger)
 # Prove that geometry, entity positions and everything outside these fields
 # plus the one new trigger remain exactly the user's current source.
 a=copy.deepcopy(before);b=copy.deepcopy(after)
 for doc in [a,b]:
  r=next(r for r in doc['levels'] if r['identifier']=='Level_20')
  ent=next(l for l in r['layerInstances'] if l['__identifier']=='Entities')
  ent['entityInstances']=[e for e in ent['entityInstances'] if not(e['__identifier']=='ShadowEruptionTrigger' and any(f['__identifier']=='EncounterID' and f['__value']==KEY for f in e['fieldInstances']))]
  for e in ent['entityInstances']:
   if e['__identifier']=='ShadowEruption':e['fieldInstances']=[]
 assert a==b,'Unexpected edit outside power configuration'
 match=re.search(r'"iid"\s*:\s*"'+re.escape(layer['iid'])+'"',raw)
 start=raw.index('[',raw.index('"entityInstances"',match.end()));end=array_end(raw,start)+1
 out=raw[:start]+json.dumps(layer['entityInstances'],indent='\t')+raw[end:]
 assert json.loads(out)==after
 if apply:
  assert not ldtk_running(),'Close LDtk before applying'
  path.write_text(out)
 print('Verified: four existing strips configured; one ladder-bottom trigger; all geometry and existing entity positions unchanged.')
 print('Trigger:',bottom,'Eruption starts: 1.5, 2.5, 3.5, 8.5 seconds. Each lasts .8 seconds.')

if __name__=='__main__':main('--apply' in sys.argv)
