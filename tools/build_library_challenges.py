#!/usr/bin/env python3
"""Author the library development and archive capstone once, preserving other rooms.
After authoring, edit LDtk normally; this script refuses to overwrite its own rooms.
"""
import copy, json, subprocess, uuid
from pathlib import Path
from ldtk_preserve_json import update
from validate_prison_ldtk import validate
ROOT=Path(__file__).resolve().parents[1]
PATH=ROOT/'ldtk/hooshang_act2.ldtk'
assert 'LDtk.app/Contents/MacOS/LDtk' not in subprocess.check_output(['ps','ax','-o','comm'],text=True)
raw=PATH.read_text(); p=json.loads(raw); before=copy.deepcopy(p)
ed={d['identifier']:d for d in p['defs']['entities']}
ld={d['identifier']:d for d in p['defs']['layers']}
rules=[r for g in ld['PrisonMasonry']['autoRuleGroups'] for r in g['rules']]
cols=next(t['__cWid'] for t in p['defs']['tilesets'] if t['identifier']=='Act2CastleMasonry')
ns=uuid.UUID('f640d0e1-f8c1-42ec-825e-1d26c87b64cb')
for name in ['Prison_G02','Prison_G03']:
 room=next(r for r in p['levels'] if r['identifier']==name)
 layers={l['__identifier']:l for l in room['layerInstances']}; entities=layers['Entities']['entityInstances']
 assert not any(e['__identifier']=='CircuitGate' for e in entities), 'Already authored: edit LDtk; do not overwrite.'
 grid=layers['Collision']['intGridCsv']
 # Preserve every boundary aperture and bottom landing; replace only interior scaffolds.
 for y in range(1,20):
  for x in range(1,39):grid[y*40+x]=0
 def box(x,y,w,h,v):
  for yy in range(y,y+h):
   for xx in range(x,x+w):grid[yy*40+xx]=v
 def entity(kind,label,point,size,values):
  d=ed[kind]; ident=str(uuid.uuid5(ns,name+'/'+label)); fs=[]
  for f in d['fieldDefs']:
   default=f.get('defaultOverride');v=values.get(f['identifier'],default['params'][0] if default else None)
   if v is not None and f['__type']=='Float':v=float(v)
   fs.append(dict(__identifier=f['identifier'],__type=f['__type'],__value=v,__tile=None,defUid=f['uid'],realEditorValues=[] if v is None else [dict(id='V_Float' if f['__type']=='Float' else 'V_String',params=[v.get('entityIid') if isinstance(v,dict) else v])]))
  entities.append(dict(__identifier=kind,__smartColor=d['color'],__grid=[point[0]//8,point[1]//8],__pivot=[.5,.5],__tags=d['tags'],__tile=d['tileRect'],__worldX=room['worldX']+point[0],__worldY=room['worldY']+point[1],defUid=d['uid'],iid=ident,px=list(point),width=size[0],height=size[1],fieldInstances=fs))
  return ident
 if name=='Prison_G02':
  shelves=[(7,17,6),(11,14,6),(7,11,6),(11,8,6),(17,17,6),(27,17,9),(19,14,7),(27,11,7),(27,8,7),(34,8,5)]
  for x,y,w in shelves:box(x,y,w,1,2)
  # Low central landing provides a return objective; the high traverse clears the hazard band.
  box(18,10,5,1,3)
  gate=entity('CircuitGate','stacks_exit',(316,48),(8,32),{'CircuitId':'library_stacks'})
  nodes=[('high_left',(104,56)),('high_right',(240,56)),('return_low',(152,176))]
 else:
  shelves=[(1,8,8),(3,11,7),(3,17,7),(15,12,6),(23,15,6),(27,12,3),(23,9,6),(27,6,6),(14,6,7),(27,17,6)]
  for x,y,w in shelves:box(x,y,w,1,2)
  # Central wall gives wall-jump purchase and a permanent observation ledge.
  box(9,14,3,6,1)
  box(14,12,1,8,1)
  # Archive key alcove: roof and right perimeter meet the controlled doorway.
  box(33,13,6,1,1)
  box(21,10,4,1,3)
  gate=entity('CircuitGate','archive_key',(268,136),(8,48),{'CircuitId':'library_archive'})
  nodes=[('low_left',(48,128)),('refuge',(144,88)),('high_right',(232,40)),('high_return',(128,40))]
  entity('DarkThought','archive_patrol',(184,104),(16,16),{'Motion':'Vertical','Amplitude':16,'Speed':.7,'Phase':0,'Clockwise':1,'Glow':1,'Angle':0,'ChildhoodPalette':1})
 ref=dict(entityIid=gate,layerIid=layers['Entities']['iid'],levelIid=room['iid'],worldIid=p['iid'])
 for label,point in nodes:entity('CircuitNode',label,point,(16,16),{'Gate':ref})
 for sign in entities:
  if sign['__identifier']=='PrisonSign':
   sign.update(px=[160,24],__grid=[20,3],__worldX=room['worldX']+160,__worldY=room['worldY']+24)
   for field in sign['fieldInstances']:
    if field['__identifier']=='Text':
     value='BOOK STACKS / THREE SEALS' if name=='Prison_G02' else 'ARCHIVE / FOUR SEALS'
     field['__value']=value;field['realEditorValues']=[dict(id='V_String',params=[value])]
 # Bake current auto-layers while retaining editable Collision-driven rules.
 layers['Tiles']['autoLayerTiles']=[];layers['PrisonMasonry']['autoLayerTiles']=[]
 for i,v in enumerate(grid):
  x,y=i%40,i//40
  if v==1:
   r=next(r for r in rules if r['size']==3) if y==0 or grid[i-40]!=1 else next(r for r in rules if r['size']==1 and r['xOffset']==x%8 and r['yOffset']==y%8)
   t=r['tileRectsIds'][0][0];target=layers['PrisonMasonry'];c=cols
  elif v in [2,3]:
   r=next(r for g in ld['Tiles']['autoRuleGroups'] for r in g['rules'] if r['pattern']==[v]);t=r['tileRectsIds'][0][0];target=layers['Tiles'];c=16
  else:continue
  target['autoLayerTiles'].append(dict(px=[x*8,y*8],src=[t%c*8,t//c*8],t=t,f=0,a=1,d=[r['uid'],i]))
for old,new in zip(before['levels'],p['levels']):
 if old['identifier'] not in ['Prison_G02','Prison_G03']:assert old==new
out=ROOT/'output/prison_challenge/library_wing';out.mkdir(parents=True,exist_ok=True)
(out/'before.ldtk').write_text(raw);preview=out/'preview.ldtk';preview.write_text(update(raw,p));validate(preview)
PATH.write_text(preview.read_text())
print('Authored Book Stacks three-node loop and Archive four-node key alcove.')
