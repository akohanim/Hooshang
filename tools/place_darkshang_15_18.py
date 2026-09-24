#!/usr/bin/env python3
"""Place boss powers without changing any terrain or non-power entities. --apply to write."""
import copy
import json
import re
import uuid
from pathlib import Path
from ldtk_add_ceiling_tile import ldtk_running, array_end
ROOT = Path(__file__).resolve().parents[1]
POWER_NAMES = {'DarkshangChargeTrigger', 'ShadowEruptionTrigger', 'ShadowEruption'}
# Centres, sizes and LDtk fields. All strips bottom-align to existing solid tops.
PLACEMENTS = {
 'Level_15': [
  ('ShadowEruptionTrigger',(276,64),(16,64),dict(EncounterID='L15_Intro',SequenceDelay=0)),
  ('ShadowEruption',(220,92),(24,8),dict(EncounterID='L15_Intro',Sequence=0,WarningTime=1.1,ActiveTime=.55)),
 ],
 'Level_16': [
  ('ShadowEruptionTrigger',(292,328),(16,96),dict(EncounterID='L16_Landing',SequenceDelay=0)),
  ('ShadowEruption',(232,356),(16,8),dict(EncounterID='L16_Landing',Sequence=0,WarningTime=1.05,ActiveTime=.65)),
  ('ShadowEruptionTrigger',(148,212),(112,16),dict(EncounterID='L16_Climb',SequenceDelay=.45)),
  ('ShadowEruption',(152,164),(16,8),dict(EncounterID='L16_Climb',Sequence=0,WarningTime=.95,ActiveTime=.65)),
  ('ShadowEruption',(184,164),(16,8),dict(EncounterID='L16_Climb',Sequence=1,WarningTime=.95,ActiveTime=.65)),
 ],
 'Level_17': [
  ('ShadowEruptionTrigger',(412,40),(16,48),dict(EncounterID='L17_Roof',SequenceDelay=.35)),
  ('ShadowEruption',(392,60),(16,8),dict(EncounterID='L17_Roof',Sequence=0,WarningTime=.75,ActiveTime=.8)),
  ('ShadowEruption',(360,60),(16,8),dict(EncounterID='L17_Roof',Sequence=1,WarningTime=.75,ActiveTime=.8)),
  ('ShadowEruption',(328,60),(16,8),dict(EncounterID='L17_Roof',Sequence=2,WarningTime=.75,ActiveTime=.8)),
  ('ShadowEruptionTrigger',(184,184),(64,16),dict(EncounterID='L17_Drop',SequenceDelay=0)),
  ('ShadowEruption',(196,212),(24,8),dict(EncounterID='L17_Drop',Sequence=0,WarningTime=.7,ActiveTime=.8)),
 ],
 'Level_18': [
  ('DarkshangChargeTrigger',(1256,120),(16,224),dict(AimAtPlayer=1,UseLaunchOffset=0,WarningTime=1,Speed=190,Distance=160,RecoveryTime=1.1)),
  ('DarkshangChargeTrigger',(840,120),(16,224),dict(AimAtPlayer=1,UseLaunchOffset=0,WarningTime=.9,Speed=210,Distance=152,RecoveryTime=1)),
  ('DarkshangChargeTrigger',(480,120),(16,224),dict(AimAtPlayer=1,UseLaunchOffset=0,WarningTime=.85,Speed=225,Distance=224,RecoveryTime=.95)),
 ],
}

def instance(definition, room, pos, size, fields, iid=None):
 values=[]
 for f in definition['fieldDefs']:
  value=fields.get(f['identifier'], f['defaultOverride']['params'][0])
  values.append({'__identifier':f['identifier'],'__type':f['__type'],'__value':value,'__tile':None,'defUid':f['uid'],'realEditorValues':[{'id':'V_String' if isinstance(value,str) else 'V_Float','params':[value]}]})
 return {'__identifier':definition['identifier'],'__grid':[pos[0]//8,pos[1]//8],'__pivot':[.5,.5],'__tags':[], '__tile':None,'__smartColor':definition['color'],'iid':iid or str(uuid.uuid4()),'width':size[0],'height':size[1],'defUid':definition['uid'],'px':list(pos),'fieldInstances':values,'__worldX':room['worldX']+pos[0],'__worldY':room['worldY']+pos[1]}

def main(apply=False):
 path=ROOT/'ldtk/hooshang_act1.ldtk';raw=path.read_text();before=json.loads(raw);after=copy.deepcopy(before)
 defs={e['identifier']:e for e in before['defs']['entities']}
 for room in after['levels']:
  if room['identifier'] not in PLACEMENTS:continue
  layer=next(l for l in room['layerInstances'] if l['__identifier']=='Entities')
  existing=[e for e in layer['entityInstances'] if e['__identifier'] in POWER_NAMES]
  keep=[e for e in layer['entityInstances'] if e['__identifier'] not in POWER_NAMES]
  additions=[instance(defs[name],room,pos,size,fields,existing[i]['iid'] if i<len(existing) else None) for i,(name,pos,size,fields) in enumerate(PLACEMENTS[room['identifier']])]
  layer['entityInstances']=keep+additions
 # Check all non-power data remains byte-equivalent after parsing, including other rooms.
 a=copy.deepcopy(before);b=copy.deepcopy(after)
 for doc in (a,b):
  for room in doc['levels']:
   if room['identifier'] in PLACEMENTS:
    for layer in room['layerInstances']:
     layer['entityInstances']=[e for e in layer.get('entityInstances',[]) if e['__identifier'] not in POWER_NAMES]
 assert a==b
 # Replace only each relevant entityInstances array in the original text.
 replacements=[]
 for room in after['levels']:
  if room['identifier'] not in PLACEMENTS:continue
  layer=next(l for l in room['layerInstances'] if l['__identifier']=='Entities')
  match=re.search(r'"iid"\s*:\s*"'+re.escape(layer['iid'])+'"',raw)
  start=raw.index('"entityInstances"',match.end())
  start=raw.index('[',start);end=array_end(raw,start)+1
  replacements.append((start,end,json.dumps(layer['entityInstances'],indent='\t')))
 for start,end,text in sorted(replacements,reverse=True):raw=raw[:start]+text+raw[end:]
 assert json.loads(raw)==after
 if apply:
  assert not ldtk_running(),'Close LDtk first'
  path.write_text(raw)
 print('Verified: only power entities changed in Levels 15–18; all geometry and other entities preserved.')

if __name__=='__main__':
 import sys
 main('--apply' in sys.argv)
