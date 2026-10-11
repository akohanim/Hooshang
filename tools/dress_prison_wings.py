#!/usr/bin/env python3
"""Add subdued, editable castle wall dressing to the school wings; preserve play.
Existing installed sheets only. No new bitmap art or collision is generated.
"""
import argparse,copy,datetime,json,subprocess
from pathlib import Path
from ldtk_preserve_json import update
from validate_prison_ldtk import validate
ROOT=Path(__file__).resolve().parents[1];PATH=ROOT/'ldtk/hooshang_act2.ldtk'
NAMES={'R':['LUNCH HALL','KITCHEN PASS','PANTRY','SERVICE HALL'],
'G':['READING ROOM','BOOK STACKS','ARCHIVE','STAFF STAIRS'],
'B':['LOWER LANDING','FLOODED STORES','PUMP ROOM','DRAINAGE PASS'],
'Y':['TRAINING HALL','BALCONY RUN','EQUIPMENT STORE','LOCKER PASS']}
def main(apply):
 if apply:assert 'LDtk.app/Contents/MacOS/LDtk' not in subprocess.check_output(['ps','ax','-o','comm'],text=True),'Close LDtk first.'
 raw=PATH.read_text();p=json.loads(raw);before=copy.deepcopy(p)
 def paint(layer,x,y,sx,sy,cols):
  layer['gridTiles'].append(dict(px=[x,y],src=[sx,sy],f=0,t=sy//8*cols+sx//8,a=1,d=[x//8+y//8*layer['__cWid']]))
 def stamp(layer,x,y,sx,sy,w,h):
  for dy in range(0,h,8):
   for dx in range(0,w,8):paint(layer,x+dx,y+dy,sx+dx,sy+dy,28)
 for room in p['levels']:
  name=room['identifier']
  if not name.startswith('Prison_') or name=='Prison_Hub':continue
  wing=name[7];number=int(name[-2:]);layers={l['__identifier']:l for l in room['layerInstances']}
  bg=layers['CastleBackground'];decor=layers['CastleDecor']
  assert not bg['gridTiles'] and not decor['gridTiles'], 'Wing dressing exists; preserve hand edits.'
  bg['__opacity']=.10 if wing in ('R','G') else .07
  decor['__opacity']=.28
  for y in range(0,room['pxHei'],8):
   for x in range(0,room['pxWid'],8):paint(bg,x,y,224+x%64,224+y%64,76)
  if wing=='R':
   for x in ([72,216] if number%2 else [136]):stamp(decor,x,64,72,104,32,40)
  elif wing=='G':stamp(decor,136,72,136,104,32,40)
  elif wing=='B':stamp(decor,224,32,72,104,32,40)
  else:
   for x in [48,240]:stamp(decor,x,32,32,32,32,96)
  for e in layers['Entities']['entityInstances']:
   if e['__identifier']!='PrisonSign':continue
   for f in e['fieldInstances']:
    if f['__identifier']=='Text' and str(f['__value']).endswith(' '+str(number)):
     f['__value']=NAMES[wing][number-1];f['realEditorValues']=[dict(id='V_String',params=[f['__value']])]
 # No collision, pickups, doors, patrols, spawn points or layout changes.
 for old,new in zip(before['levels'],p['levels']):
  a={l['__identifier']:l for l in old['layerInstances']};b={l['__identifier']:l for l in new['layerInstances']}
  assert a['Collision']==b['Collision']
  for ea,eb in zip(a['Entities']['entityInstances'],b['Entities']['entityInstances']):
   if ea['__identifier']!='PrisonSign':assert ea==eb
 out=ROOT/'output/act2_polish/prison_wings';out.mkdir(parents=True,exist_ok=True)
 preview=out/'preview.ldtk';preview.write_text(update(raw,p));validate(preview)
 if apply:
  (out/('before_'+datetime.datetime.now().strftime('%Y%m%d_%H%M%S')+'.ldtk')).write_text(raw);PATH.write_text(preview.read_text())
 print('Sixteen named school spaces dressed; all movement geometry and gameplay entities preserved.')
if __name__=='__main__':
 p=argparse.ArgumentParser(description=__doc__);p.add_argument('--apply',action='store_true');main(p.parse_args().apply)
