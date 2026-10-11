#!/usr/bin/env python3
"""Remove prison flags and exit-slot shelves without rebuilding authored rooms."""
import datetime,json,subprocess
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
def revise():
 if 'LDtk.app/Contents/MacOS/LDtk' in subprocess.check_output(['ps','ax','-o','comm'],text=True):
  raise SystemExit('Close LDtk before modifying its source.')
 path=ROOT/'ldtk/hooshang_act2.ldtk';original=path.read_bytes();p=json.loads(original)
 flags=0;shelves=0
 for room in p['levels']:
  if not room['identifier'].startswith('Prison_'):continue
  layers={l['__identifier']:l for l in room['layerInstances']}
  entities=layers['Entities']['entityInstances'];flags+=sum(e['__identifier']=='Checkpoint' for e in entities)
  layers['Entities']['entityInstances']=[e for e in entities if e['__identifier']!='Checkpoint']
  grid=layers['Collision']['intGridCsv'];w=layers['Collision']['__cWid'];h=layers['Collision']['__cHei'];removed=set()
  # A shelf directly above a bottom aperture obstructs the actual doorway.
  for x in range(w):
   i=(h-2)*w+x
   if grid[i]==2 and grid[(h-1)*w+x] in (0,4):grid[i]=0;removed.add((x*8,(h-2)*8));shelves+=1
  added=set()
  # Put the crossing deck ABOVE the floor, leaving the shaft's full width open.
  # A player can walk under this one-way bridge to leave, or jump onto it to
  # cross the opening without falling into the neighboring room.
  x=0
  while x<w:
   if grid[(h-1)*w+x]!=0:x+=1;continue
   start=x
   while x<w and grid[(h-1)*w+x]==0:x+=1
   if x-start<3:continue
   for xx in range(max(1,start-2),min(w-1,x+2)):
    grid[(h-7)*w+xx]=2;added.add((xx*8,(h-7)*8))
  solid=set()
  if room['identifier']=='Prison_G02' and [grid[y*w+28] for y in range(20,24)] in ([0,0,0,1],[1,1,1,1]):
   for y in range(20,24):grid[y*w+28]=1;solid.add((224,y*8))
  layers['Tiles']['autoLayerTiles']=[t for t in layers['Tiles']['autoLayerTiles'] if tuple(t['px']) not in removed|added|solid]
  rule=next(r for d in p['defs']['layers'] if d['identifier']=='Tiles' for g in d['autoRuleGroups'] for r in g['rules'] if r['pattern']==[2])
  for px,py in sorted(added,key=lambda pt:(pt[1],pt[0])):
   layers['Tiles']['autoLayerTiles'].append(dict(px=[px,py],src=[40,0],f=0,t=5,a=1,d=[rule['uid'],px//8+py//8*w]))
  for px,py in sorted(solid):
   tile=1 if grid[(py//8-1)*w+px//8]!=1 else 0
   solid_rule=next(r for d in p['defs']['layers'] if d['identifier']=='Tiles' for g in d['autoRuleGroups'] for r in g['rules'] if r['tileRectsIds']==[[tile]])
   layers['Tiles']['autoLayerTiles'].append(dict(px=[px,py],src=[tile*8,0],f=0,t=tile,a=1,d=[solid_rule['uid'],px//8+py//8*w]))
 from validate_prison_ldtk import validate
 backup=ROOT/'output/prison_build/backups'/datetime.datetime.now().strftime('%Y%m%d_%H%M%S')
 backup.mkdir(parents=True,exist_ok=True);(backup/path.name).write_bytes(original)
 path.write_text(json.dumps(p,indent='\t')+'\n');validate(path)
 print(f'Removed {flags} flags and {shelves} doorway shelf cells. Backup: {backup}')
if __name__=='__main__':revise()
