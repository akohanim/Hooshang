#!/usr/bin/env python3
"""Add manual boss-power definitions only; preserve every authored room. --apply to write."""
import copy
import json
import re
import sys
from pathlib import Path
from ldtk_add_ceiling_tile import block, ldtk_running
from ldtk_add_dark_thought import field_def

FIELDS = {
    'DarkshangChargeTrigger': [('AimAtPlayer',1),('Angle',180),('UseLaunchOffset',0),('LaunchOffsetX',0),('LaunchOffsetY',0),('WarningTime',.8),('Speed',240),('Distance',240),('RecoveryTime',.7),('RepeatDelay',0)],
    'ShadowEruptionTrigger': [('EncounterID','A'),('SequenceDelay',.35),('RepeatDelay',0)],
    'ShadowEruption': [('EncounterID','A'),('Sequence',0),('WarningTime',.8),('ActiveTime',.55)],
}
DOCS = {
    'DarkshangChargeTrigger': "Cross to charge from Darkshang's live position toward the player's current position and height. Aim locks during the warning. After recovery he returns behind the current player position. Angle and launch-offset fields are legacy and ignored. RepeatDelay 0 = once per life; otherwise leave and re-enter after cooldown.",
    'ShadowEruptionTrigger': 'Cross to fire same-room ShadowEruption strips with matching EncounterID. SequenceDelay is seconds per sequence step. RepeatDelay 0 = once per life.',
    'ShadowEruption': 'Place ABOVE a platform with bottom flush to its surface. Rectangle is the lethal volume. Same EncounterID links to a trigger; Sequence 0 fires first. WarningTime and ActiveTime in seconds.',
}

def install(path, apply=False):
    raw = path.read_text()
    before = json.loads(raw)
    uid = max(map(int,re.findall(r'"uid":\s*(\d+)',raw)))
    additions=[]
    for name, fields in FIELDS.items():
        if any(e['identifier']==name for e in before['defs']['entities']): continue
        entity=copy.deepcopy(next(e for e in before['defs']['entities'] if e['identifier']=='SurgePoint'))
        uid+=1
        entity.update(identifier=name,uid=uid,doc=DOCS[name],width=32 if name=='ShadowEruption' else 16,height=8 if name=='ShadowEruption' else 48,resizableX=True,resizableY=True,minWidth=8,minHeight=8,renderMode='Rectangle',color='#C479A4',tilesetId=None,tileRect=None,uiTileRect=None,fieldDefs=[])
        entity['pivotX']=entity['pivotY']=.5
        for key,value in fields:
            uid+=1
            string=isinstance(value,str)
            entity['fieldDefs'].append(field_def(key,DOCS[name],uid,('String','F_String') if string else ('Float','F_Float'),{'id':'V_String' if string else 'V_Float','params':[value]}))
        additions.append(entity)
    if not additions:
        print('Already installed');return
    i=raw.index('\n\t], "tilesets": [')
    out=raw[:i]+''.join(',\n'+block(e,2) for e in additions)+raw[i:]
    after=json.loads(out)
    expected=copy.deepcopy(before);expected['defs']['entities']+=additions
    assert after==expected, 'Unexpected content change'
    if apply:
        if ldtk_running(): raise SystemExit('Close LDtk before applying.')
        path.write_text(out)
    print(('Installed' if apply else 'Validated')+' three boss-power definitions; rooms unchanged.')

if __name__=='__main__':
    install(Path(__file__).resolve().parents[1]/'ldtk/hooshang_act1.ldtk','--apply' in sys.argv)
