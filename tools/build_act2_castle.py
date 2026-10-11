#!/usr/bin/env python3
"""Bootstrap the two castle threshold rooms; preserve all existing room geometry.

LDtk remains authoritative after creation. --replace-castle explicitly rebuilds
only these two rooms. Every installation saves the previous project first.
"""
import argparse
import copy
import datetime
import json
import re
import subprocess
import uuid
from pathlib import Path
from ldtk_preserve_json import update
from validate_prison_ldtk import validate

ROOT = Path(__file__).resolve().parents[1]
PATH = ROOT / 'ldtk/hooshang_act2.ldtk'
NAMES = ['Act_2_Level_14', 'Act_2_Level_15']
NS = uuid.UUID('f7fb5bbc-9dca-4775-b3e4-4cb2ba57107f')


def build(apply=False, replace=False):
    if apply and 'LDtk.app/Contents/MacOS/LDtk' in subprocess.check_output(['ps', 'ax', '-o', 'comm'], text=True):
        raise SystemExit('Close LDtk before modifying its source.')
    raw = PATH.read_text()
    project = json.loads(raw)
    original = copy.deepcopy(project)
    previous = {r['identifier']: r for r in project['levels'] if r['identifier'] in NAMES}
    if previous and not replace:
        raise SystemExit('Castle rooms already exist. Edit LDtk, or explicitly use --replace-castle.')
    counter = max([project['nextUid']] + [int(n) for n in re.findall(r'"uid":\s*(\d+)', raw)]) + 1
    entity_defs = {d['identifier']: d for d in project['defs']['entities']}
    sheets = {d['uid']: d for d in project['defs']['tilesets']}
    if 'CastlePassage' not in entity_defs:
        destination = copy.deepcopy(entity_defs['Exit']['fieldDefs'][0])
        destination.update(identifier='Destination', uid=counter, defaultOverride=None)
        counter += 1
        definition = copy.deepcopy(entity_defs['PrisonSign'])
        definition.update(identifier='CastlePassage', uid=counter, width=32, height=48,
                          pivotX=0.5, pivotY=1.0, fieldDefs=[destination],
                          doc='Always-open courtyard door. Press Up to return outside.')
        counter += 1
        project['defs']['entities'].append(definition)
        entity_defs['CastlePassage'] = definition

    def iid(name):
        return str(uuid.uuid5(NS, name))

    def field(definition, value):
        kind = {'Bool': 'V_Bool', 'Float': 'V_Float', 'Int': 'V_Int'}.get(definition['__type'], 'V_String')
        return dict(__identifier=definition['identifier'], __type=definition['__type'],
                    __value=value, __tile=None, defUid=definition['uid'],
                    realEditorValues=[] if value is None else [dict(id=kind, params=[value])])

    def entity(room, name, x, y, **values):
        d = entity_defs[name]
        layer = next(a for a in room['layerInstances'] if a['__identifier'] == 'Entities')
        fields = [field(f, values.get(f['identifier'], f.get('defaultOverride', {}).get('params', [None])[0]
                  if f.get('defaultOverride') else None)) for f in d['fieldDefs']]
        layer['entityInstances'].append(dict(__identifier=name, __grid=[x//8, y//8],
            __pivot=[d['pivotX'], d['pivotY']], __tags=d['tags'], __tile=d['tileRect'],
            __smartColor=d['color'], iid=iid(room['identifier']+name+str(len(layer['entityInstances']))),
            width=d['width'], height=d['height'], defUid=d['uid'], px=[x, y], fieldInstances=fields,
            __worldX=room['worldX']+x, __worldY=room['worldY']+y))

    last_garden = next(r for r in project['levels'] if r['identifier']=='Act_2_Level_13')
    approach_x = last_garden['worldX'] + last_garden['pxWid']
    rooms = []
    for number, width, world_x, wing in [(14, 640, approach_x, 'CastleApproach'), (15, 480, approach_x+640, 'CastleGatehouse')]:
        name = f'Act_2_Level_{number}'
        room = copy.deepcopy(project['levels'][0])
        room_uid = previous[name]['uid'] if name in previous else counter
        counter += 1
        room.update(identifier=name, iid=iid(name), uid=room_uid, worldX=world_x,
                    worldY=488, pxWid=width, pxHei=240, __neighbours=[], bgRelPath=None,
                    __bgPos=None, fieldInstances=[field(d, wing if d['identifier']=='wing' else False)
                    for d in project['defs']['levelFields']])
        layers = {}
        for layer in room['layerInstances']:
            layer.update(iid=iid(name+layer['__identifier']), levelId=room_uid,
                         __cWid=width//8, __cHei=30, entityInstances=[], gridTiles=[],
                         autoLayerTiles=[], seed=number, __opacity=1)
            layer['intGridCsv'] = [0]*(width//8*30) if layer['__type']=='IntGrid' else []
            layers[layer['__identifier']] = layer

        def tile(layer_name, x, y, sx, sy, alpha=1):
            layer = layers[layer_name]
            sheet = sheets[layer['__tilesetDefUid']]
            layer['gridTiles'].append(dict(px=[x,y],src=[sx,sy],f=0,
                t=sx//8+(sy//8)*(sheet['pxWid']//8),a=alpha,d=[x//8+(y//8)*layer['__cWid']]))

        terrain = set()
        def solid(x, y, w, h):
            terrain.update((xx, yy) for yy in range(y, y+h, 8) for xx in range(x, x+w, 8))

        def stamp(layer, x, y, w, h, sx, sy, sw, sh, alpha=1):
            for yy in range(0,h,8):
                for xx in range(0,w,8): tile(layer,x+xx,y+yy,sx+xx%sw,sy+yy%sh,alpha)

        if number == 14:
            # Reversible, forgiving stair. Water is an alternate recovery route.
            for x,y,w in [(0,200,112),(112,184,64),(176,168,64),(240,184,48),
                          (288,200,64),(352,232,128),(480,200,160)]: solid(x,y,w,240-y)
            solid(352,176,48,8)
            solid(448,176,48,8)
            water=layers['Water'];cw=water['__cWid']
            for y in range(200//8,232//8):
                for x in range(352//8,480//8):water['intGridCsv'][y*cw+x]=1
            stamp('CastleBackground',448,48,192,152,224,224,64,64)
            stamp('CastleBackground',416,24,32,176,160,32,32,64)
            stamp('CastleBackground',608,16,32,184,160,32,32,64)
            for x in [472,544]: stamp('CastleDecor',x,88,32,40,72,104,32,40)
            entity(room,'Lemon',208,136)
            entity(room,'Lemon',416,216)
        else:
            for x,y,w in [(0,200,80),(80,216,128),(208,200,272)]: solid(x,y,w,240-y)
            solid(128,184,48,8)
            solid(280,168,48,8)
            solid(352,144,48,8)
            stamp('CastleBackground',0,0,480,240,224,224,64,64)
            for x in [32,200,400]: stamp('CastleDecor',x,64,32,40,72,104,32,40)
            stamp('CastleDecor',0,24,480,8,64,64,96,8)
            entity(room,'Lemon',376,120)
        # Distinct cream top edges, red masonry beneath. All shapes are exact
        # 8px cells; ornaments stay in the non-colliding scenery layers.
        for x,y in sorted(terrain, key=lambda p:(p[1],p[0])):
            sx,sy=(48,32) if (x,y-8) not in terrain else (48+(x//8%2)*8,48+(y//8%2)*8)
            tile('CastleTerrain',x,y,sx,sy)
        water=layers['Water'];cw=water['__cWid'];ch=water['__cHei'];g=water['intGridCsv']
        def wet(x,y):return 0<=x<cw and 0<=y<ch and g[y*cw+x]==1
        for i,value in enumerate(g):
            if not value:continue
            x,y=i%cw,i//cw
            top,bottom,left,right=not wet(x,y-1),not wet(x,y+1),not wet(x-1,y),not wet(x+1,y)
            v=top or bottom;h=left or right
            t=3 if v and h else 1 if v else 2 if h else 0
            rule={3:236,1:237,2:238,0:239}[t]
            water['autoLayerTiles'].append(dict(px=[x*8,y*8],src=[t*8,0],t=t,
                f=(1 if right and not left else 0)+(2 if bottom and not top else 0),a=1,d=[rule,i]))
        entity(room,'PlayerStart',32,184)
        entity(room,'Exit',width-24,168,NextRoom='Act_2_Level_15' if number==14 else 'Prison_Hub')
        rooms.append(room)

    project['levels']=[rooms[NAMES.index(r['identifier'])] if r['identifier'] in NAMES else r for r in project['levels']]
    project['levels'].extend(r for r in rooms if r['identifier'] not in previous)
    final=next(r for r in project['levels'] if r['identifier']=='Act_2_Level_13')
    for layer in final['layerInstances']:
        for e in layer['entityInstances']:
            if e['__identifier']=='Exit':
                f=next(f for f in e['fieldInstances'] if f['__identifier']=='NextRoom')
                f.update(__value=NAMES[0],realEditorValues=[dict(id='V_String',params=[NAMES[0]])])
    hub=next(r for r in project['levels'] if r['identifier']=='Prison_Hub')
    if not any(e['__identifier']=='CastlePassage' for a in hub['layerInstances'] for e in a['entityInstances']):
        entity(hub,'CastlePassage',64,352,Destination=NAMES[1])
    project['nextUid']=counter
    for old in original['levels']:
        if old['identifier'] not in NAMES+['Act_2_Level_13','Prison_Hub']:
            assert old==next(r for r in project['levels'] if r['identifier']==old['identifier'])
    output=ROOT/'output/act2_polish/milestone1'
    output.mkdir(parents=True,exist_ok=True)
    preview=output/'castle_preview.ldtk'
    preview.write_text(update(raw,project))
    validate(preview)
    if apply:
        backup=output/('before_castle_'+datetime.datetime.now().strftime('%Y%m%d_%H%M%S')+'.ldtk')
        backup.write_text(raw)
        PATH.write_text(preview.read_text())
    print('Installed' if apply else 'Previewed',NAMES,'; existing room geometry preserved.')


if __name__=='__main__':
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--apply',action='store_true')
    parser.add_argument('--replace-castle',action='store_true')
    args=parser.parse_args()
    build(args.apply,args.replace_castle)
