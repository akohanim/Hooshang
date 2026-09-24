#!/usr/bin/env python3
"""Explicitly seed Act3_Level_0 as a connected-terrain showcase; LDtk closed.
Run with --apply. Ordinary art rebuilds never reset the authored room.
"""
import argparse
import copy
import json
import subprocess
import uuid
from pathlib import Path
from act3_connected_terrain import rebake
from ldtk_preserve_json import update

ROOT = Path(__file__).resolve().parents[1]


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--apply',action='store_true')
    args=parser.parse_args()
    if not args.apply:
        print('Use --apply to replace the Act 3 starter room with the showcase.')
        return
    processes=subprocess.check_output(['ps','ax','-o','command'],text=True)
    if any('LDtk.app/Contents/MacOS/LDtk' in line for line in processes.splitlines()):
        raise SystemExit('Close LDtk before applying; it holds project data in memory.')
    path=ROOT/'ldtk/hooshang_act3.ldtk'
    raw=path.read_text(); p=json.loads(raw)
    room=next(r for r in p['levels'] if r['identifier']=='Act3_Level_0')
    assert (room['pxWid'],room['pxHei'])==(320,192)
    layers={l['__identifier']:l for l in room['layerInstances']}
    collision=layers['Collisions']; cells=[0]*(40*24)

    def rect(x,y,w,h,value):
        for yy in range(y,y+h):
            for xx in range(x,x+w): cells[yy*40+xx]=value

    # A safe continuous floor; adjacent brush changes demonstrate shared fill.
    for x,value in [(0,2),(8,5),(16,6),(24,2),(32,2)]: rect(x,20,8,4,value)
    rect(0,0,1,24,2); rect(39,0,1,24,2)
    # Ascending practice ledges and a ladder up the side of the scaffold shelf.
    rect(7,17,5,2,5)
    rect(12,13,5,2,6)
    rect(20,9,6,2,2)
    rect(29,13,7,2,6)
    # Suspended brick frame, with a real internal cutout.
    rect(4,3,9,5,2); rect(7,5,3,2,0)
    rect(10,3,3,5,2)
    # Mixed grass/brick island near the ceiling.
    rect(21,3,6,2,5); rect(27,3,5,2,2)
    collision['intGridCsv']=cells
    definition=next(l for l in p['defs']['layers'] if l['identifier']=='Collisions')
    rebake(collision,definition)
    entities=[]

    def entity(name,x,y,width=None,height=None,**overrides):
        definition=next(e for e in p['defs']['entities'] if e['identifier']==name)
        fields=[]
        for field in definition['fieldDefs']:
            default=field['defaultOverride']
            value=overrides.get(field['identifier'],default['params'][0] if default else None)
            editor=[] if value is None else [{'id':'V_Float' if field['__type']=='Float' else 'V_String','params':[value]}]
            fields.append({'__identifier':field['identifier'],'__type':field['__type'],
                           '__value':value,'__tile':None,'defUid':field['uid'],'realEditorValues':editor})
        entities.append({'__identifier':name,'__grid':[x//8,y//8],
                         '__pivot':[definition['pivotX'],definition['pivotY']],
                         '__tags':definition['tags'],'__tile':copy.deepcopy(definition['tileRect']),
                         '__smartColor':definition['color'],
                         'iid':str(uuid.uuid5(uuid.NAMESPACE_URL,f'hooshang/act3/showcase/{name}/{x}/{y}')),
                         'width':width or definition['width'],'height':height or definition['height'],
                         'defUid':definition['uid'],'px':[x,y],'fieldInstances':fields,
                         '__worldX':room['worldX']+x,'__worldY':room['worldY']+y})

    entity('PlayerStart',24,144,SpawnID='start')
    entity('Ladder',140,132,height=56)
    entity('DarkThought',176,116,Amplitude=8,Speed=0.15)
    entity('LightThought',264,80,Amplitude=8,Speed=0.15,Phase=0.5)
    entity('ConeSpikes',244,156,width=24)
    layers['Entities']['entityInstances']=entities
    room['__neighbours']=[]  # The copied donor referenced a room in another Act.
    room['bgColor']=room['__bgColor']='#000000'
    for layer in room['layerInstances']: layer['visible']=True
    path.write_text(update(raw,p))
    print('Initialized Act3_Level_0: three terrain brushes, safe spawn, ladder, two thoughts and spikes.')


if __name__=='__main__': main()
