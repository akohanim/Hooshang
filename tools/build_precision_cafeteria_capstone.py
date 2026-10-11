#!/usr/bin/env python3
"""One-time LDtk R03 two-phrase precision capstone. Preserve all other room data and hand edits."""
import copy,json,subprocess,uuid
from pathlib import Path
from ldtk_preserve_json import update
from validate_prison_ldtk import validate
ROOT=Path(__file__).resolve().parents[1];path=ROOT/'ldtk/hooshang_act2.ldtk'
assert 'LDtk.app/Contents/MacOS/LDtk' not in subprocess.check_output(['ps','ax','-o','comm'],text=True)
raw=path.read_text();p=json.loads(raw);before=copy.deepcopy(p)
r=next(r for r in p['levels'] if r['identifier']=='Prison_R03');ls={l['__identifier']:l for l in r['layerInstances']};ents=ls['Entities']['entityInstances']
assert sum(e['__identifier']=='CrumblingShelf' for e in ents)==1,'Already authored: preserve LDtk edits'
template=next(e for room in p['levels'] for layer in room['layerInstances'] for e in layer['entityInstances'] if e['__identifier']=='CrumblingShelf')
gates=[e for e in ents if e['__identifier']=='TimedGate']
def field(e,name,value):
 f=next(f for f in e['fieldInstances'] if f['__identifier']==name);f['__value']=value;f['realEditorValues']=[dict(id='V_Float' if f['__type']=='Float' else 'V_String',params=[value])]
def move(e,x,y):e.update(px=[x,y],__grid=[x//8,y//8],__worldX=r['worldX']+x,__worldY=r['worldY']+y)
first=next(e for e in gates if e['px'][0]==156);second=next(e for e in gates if e['px'][0]==236)
field(first,'Duration',9.0);move(first,156,72);first['height']=64
field(second,'Duration',8.0);move(second,268,40);second['height']=48
ents[:]=[e for e in ents if e['__identifier']!='CrumblingShelf']
for e in ents:
 if e['__identifier']=='TimedLever' and e['px'][0]==176:move(e,176,112)
 if e['__identifier']=='TimedLever' and e['px'][0]==200:move(e,200,112)
 if e['__identifier']=='TimedRelay' and e['px'][0]==168:move(e,168,112)
 if e['__identifier']=='TimedRelay' and e['px'][0]==280:move(e,232,24)
 if e['__identifier']=='DarkThought':move(e,288,80);field(e,'Amplitude',16.0)
 if e['__identifier']=='PrisonSign':move(e,184,24)
for phase,(gate,points) in enumerate([(first,[(56,136),(104,112),(64,88),(112,64)]),(second,[(232,72),(280,48),(232,32)])]):
 ref=dict(entityIid=gate['iid'],layerIid=ls['Entities']['iid'],levelIid=r['iid'],worldIid=p['iid'])
 for i,(x,top) in enumerate(points):
  e=copy.deepcopy(template);e.update(iid=str(uuid.uuid5(uuid.NAMESPACE_URL,'hooshang/precision/r03/shelf/'+str(phase)+'/'+str(i))),width=24,height=8);move(e,x,top+4)
  f=e['fieldInstances'][0];f['__value']=ref;f['realEditorValues']=[dict(id='V_String',params=[gate['iid']])];ents.append(e)
# Banked upper seal opens a low return grate; no extra switch or progression item.
return_grate=copy.deepcopy(next(e for e in ents if e['__identifier']=='TimedShutter' and e['px'][1]==140))
return_grate.update(iid=str(uuid.uuid5(uuid.NAMESPACE_URL,'hooshang/precision/r03/return_grate')),width=8,height=48)
move(return_grate,268,88);ents.append(return_grate)
grid=ls['Collision']['intGridCsv']
def box(x,y,w,h,v):
 for yy in range(y,y+h):
  for xx in range(x,x+w):grid[yy*40+xx]=v
# Keep all outer aperture cells intact; rebuild only the interior.
box(1,1,38,22,0)
box(1,20,5,3,1);box(20,15,7,8,1);box(33,20,6,3,1)
box(19,1,1,4,1);box(19,13,1,10,1)
box(33,1,1,1,1);box(33,14,1,6,1)
box(30,14,7,1,2)
box(37,18,2,1,2)
box(32,16,1,4,1)
box(9,3,5,1,2)
box(6,22,13,1,3);box(27,22,5,1,3)
ld={d['identifier']:d for d in p['defs']['layers']};rules=[a for g in ld['PrisonMasonry']['autoRuleGroups'] for a in g['rules']];cols=next(t['__cWid'] for t in p['defs']['tilesets'] if t['identifier']=='Act2CastleMasonry')
ls['PrisonMasonry']['autoLayerTiles']=[];ls['Tiles']['autoLayerTiles']=[]
for i,v in enumerate(grid):
 x,y=i%40,i//40
 if v==1:
  rule=next(a for a in rules if a['size']==3) if y==0 or grid[i-40]!=1 else next(a for a in rules if a['size']==1 and a['xOffset']==x%8 and a['yOffset']==y%8);target=ls['PrisonMasonry'];c=cols
 elif v in [2,3]:
  rule=next(a for g in ld['Tiles']['autoRuleGroups'] for a in g['rules'] if a['pattern']==[v]);target=ls['Tiles'];c=16
 else:continue
 t=rule['tileRectsIds'][0][0];target['autoLayerTiles'].append(dict(px=[x*8,y*8],src=[t%c*8,t//c*8],t=t,f=0,a=1,d=[rule['uid'],i]))
for a,b in zip(before['levels'],p['levels']):
 if a['identifier']!='Prison_R03':assert a==b
out=ROOT/'output/prison_precision/cafeteria_precision_capstone';out.mkdir(parents=True,exist_ok=True)
assert not (out/'before.ldtk').exists()
(out/'before.ldtk').write_text(raw);preview=out/'preview.ldtk';preview.write_text(update(raw,p));validate(preview);path.write_text(preview.read_text())
print('R03: two precision phrases, seven existing-art crumble stones, banked midpoint')
