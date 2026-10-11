#!/usr/bin/env python3
"""One-time castle readability pass; preserve authored collision and entities."""
import copy,json,subprocess,datetime
from pathlib import Path
from ldtk_preserve_json import update
from validate_prison_ldtk import validate
ROOT=Path(__file__).resolve().parents[1];PATH=ROOT/'ldtk/hooshang_act2.ldtk'
assert 'LDtk.app/Contents/MacOS/LDtk' not in subprocess.check_output(['ps','ax','-o','comm'],text=True),'Close LDtk first'
raw=PATH.read_text();p=json.loads(raw);old=copy.deepcopy(p)
def layers(name):return {l['__identifier']:l for l in next(r for r in p['levels'] if r['identifier']==name)['layerInstances']}
gate=layers('Act_2_Level_15')
assert not gate['Decor']['gridTiles'],'Threshold dressing exists; preserve hand edits.'
gate['CastleBackground']['__opacity']=.56
def board(layer,x,y):
 cols=next(t['pxWid']//8 for t in p['defs']['tilesets'] if t['uid']==layer['__tilesetDefUid'])
 for dy in range(0,16,8):
  for dx in range(0,32,8):
   sx,sy=40+dx,32+dy
   layer['gridTiles'].append(dict(px=[x+dx,y+dy],src=[sx,sy],f=0,t=sy//8*cols+sx//8,a=1,d=[(x+dx)//8+(y+dy)//8*layer['__cWid']]))
board(gate['Decor'],216,120)
board(gate['Decor'],88,120)
# Bring an existing classroom cue into the hub's arrival view; it was high
# above the first screen. Keep it away from the cage, signs and scaffold edges.
hub=layers('Prison_Hub')['Decor']
for t in hub['gridTiles']:
 if 304<=t['px'][0]<336 and 48<=t['px'][1]<64 and 40<=t['src'][0]<72 and 32<=t['src'][1]<48:
  t['px'][0]-=80;t['px'][1]+=224
  t['d']=[t['px'][0]//8+t['px'][1]//8*hub['__cWid']]
for before,after in zip(old['levels'],p['levels']):
 if before['identifier'] not in ['Act_2_Level_15','Prison_Hub']:assert before==after
 for a,b in zip(before['layerInstances'],after['layerInstances']):
  if a['__identifier'] not in ['CastleBackground','Decor']:assert a==b
out=ROOT/'output/act2_polish/threshold_readability';out.mkdir(parents=True,exist_ok=True)
(out/('before_'+datetime.datetime.now().strftime('%Y%m%d_%H%M%S')+'.ldtk')).write_text(raw)
result=update(raw,p);preview=out/'preview.ldtk';preview.write_text(result);validate(preview);PATH.write_text(result)
print('Gatehouse wall contrast and three classroom-board placements updated; geometry and entities unchanged.')
