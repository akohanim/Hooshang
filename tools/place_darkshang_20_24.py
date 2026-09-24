#!/usr/bin/env python3
"""Add editable escape-room encounters; preserve terrain and unrelated entities."""
import copy
import json
import re
import sys
import uuid
from place_darkshang_15_18 import ROOT, instance
from ldtk_add_ceiling_tile import array_end, ldtk_running


def charge(key, pos, size, warning, speed, distance):
    return ('DarkshangChargeTrigger', pos, size, dict(EncounterID=key, AimAtPlayer=1,
            UseLaunchOffset=0, WarningTime=warning, Speed=speed, Distance=distance,
            RecoveryTime=1.0, RepeatDelay=0))


def wave(key, pos, size, surfaces, warning=1.0, interval=.7):
    return [('ShadowEruptionTrigger', pos, size, dict(EncounterID=key,
             SequenceDelay=interval, RepeatDelay=0))] + [
        ('ShadowEruption', (x, top-4), (width, 8), dict(EncounterID=key,
         Sequence=sequence, WarningTime=warning, ActiveTime=.65))
        for x, top, width, sequence in surfaces]


PLACEMENTS = {
    'Level_20': [charge('L20_EntryCharge',(624,128),(24,224),1.05,200,160),
                 charge('L20_MiddleCharge',(304,176),(24,112),1.0,210,144)]
        + wave('L20_FirstLanding',(548,132),(40,96),[(528,160,16,0)],1.15)
        + wave('L20_LastLanding',(140,120),(32,112),[(100,152,16,0)],1.05),
    'Level_21': [charge('L21_EntryCharge',(480,128),(24,176),1.0,210,152),
                 charge('L21_MiddleCharge',(248,124),(24,120),.95,215,144)]
        + wave('L21_FirstBelt',(416,160),(24,96),[(408,192,16,0),(376,192,16,1)],1.1,.45)
        + wave('L21_LastBelt',(224,148),(24,96),[(208,176,16,0),(176,176,16,1)],1.0,.45),
    'Level_22': [charge('L22_LowerCharge',(400,296),(24,96),1.05,210,136),
                 charge('L22_UpperCharge',(280,184),(24,80),1.0,215,128)]
        + wave('L22_LowerLanding',(324,260),(32,64),[(312,288,16,0)],1.1)
        + wave('L22_UpperLandings',(208,128),(24,64),[(192,168,16,0),(92,128,16,2)],1.0,1.0),
    'Level_23': [charge('L23_EntryCharge',(720,208),(24,160),1.05,210,144),
                 charge('L23_MiddleCharge',(332,176),(24,112),1.0,220,136)]
        + wave('L23_CheckpointLanding',(500,196),(32,64),[(496,216,16,0)],1.0)
        + wave('L23_UpperLanding',(308,64),(32,64),[(296,80,16,0)],.95),
    'Level_24': [charge('L24_EntryCharge',(400,152),(24,128),.95,220,152),
                 charge('L24_FinalCharge',(212,108),(24,112),.9,225,144)]
        + wave('L24_FirstSteps',(348,128),(32,72),[(336,152,16,0),(256,120,16,1)],1.0,.8)
        + wave('L24_LastStep',(128,108),(32,64),[(104,120,16,0)],.95),
}


def placement_id(p):
    return str(uuid.uuid5(uuid.NAMESPACE_URL, "hooshang/"+p[3]["EncounterID"]+"/"+p[0]+"/"+str(p[3].get("Sequence",0))))


def main(apply=False):
    path = ROOT/'ldtk/hooshang_act1.ldtk'
    raw = path.read_text()
    before = json.loads(raw)
    after = copy.deepcopy(before)
    definitions = {e['identifier']: e for e in after['defs']['entities']}
    replacements = []
    for room in after['levels']:
        if room['identifier'] not in PLACEMENTS:
            continue
        layer = next(l for l in room['layerInstances'] if l['__identifier']=='Entities')
        planned = PLACEMENTS[room['identifier']]
        keys = {p[3]['EncounterID'] for p in planned}
        def owned(e):
            return e['iid'] in {placement_id(p) for p in planned} or e['__identifier'] in ('ShadowEruptionTrigger','ShadowEruption') and any(
                f['__identifier']=='EncounterID' and f['__value'] in keys for f in e['fieldInstances'])
        additions = [instance(definitions[name], room, pos, size, fields,
                    placement_id(planned[i]))
                    for i, (name,pos,size,fields) in enumerate(planned)]
        layer['entityInstances'] = [e for e in layer['entityInstances'] if not owned(e)] + additions
        match = re.search(r'"iid"\s*:\s*"'+re.escape(layer['iid'])+'"',raw)
        start = raw.index('[',raw.index('"entityInstances"',match.end()))
        replacements.append((start,array_end(raw,start)+1,json.dumps(layer['entityInstances'],indent='\t')))
    # Strip just our explicitly named encounters before comparing the whole world.
    def unrelated(doc):
        doc = copy.deepcopy(doc)
        for room in doc['levels']:
            if room['identifier'] not in PLACEMENTS: continue
            keys = {p[3]['EncounterID'] for p in PLACEMENTS[room['identifier']]}
            for layer in room['layerInstances']:
                layer['entityInstances'] = [e for e in layer.get('entityInstances',[]) if not (
                    e['iid'] in {placement_id(p) for p in PLACEMENTS[room['identifier']]} or e['__identifier'] in ('ShadowEruptionTrigger','ShadowEruption')
                    and any(f['__identifier']=='EncounterID' and f['__value'] in keys for f in e['fieldInstances']))]
        return doc
    assert unrelated(before)==unrelated(after), 'Unexpected change outside named encounters'
    for start,end,text in sorted(replacements,reverse=True): raw=raw[:start]+text+raw[end:]
    assert json.loads(raw)==after
    if apply:
        assert not ldtk_running(), 'Close LDtk first'
        path.write_text(raw)
    print('Verified: Levels 20–24 encounters only; terrain and unrelated entities preserved.')

if __name__=='__main__': main('--apply' in sys.argv)
