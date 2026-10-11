#!/usr/bin/env python3
"""Author R03: two banked phrases, a restoring crumble shelf and a two-seal key alcove.
One-time authoring; later changes remain editable in LDtk.
"""
import copy,json,re,subprocess,uuid
from pathlib import Path
from ldtk_preserve_json import update
from validate_prison_ldtk import validate
ROOT=Path(__file__).resolve().parents[1];path=ROOT/'ldtk/hooshang_act2.ldtk'
assert 'LDtk.app/Contents/MacOS/LDtk' not in subprocess.check_output(['ps','ax','-o','comm'],text=True)
raw=path.read_text();p=json.loads(raw);before=copy.deepcopy(p)
r=next(r for r in p['levels'] if r['identifier']=='Prison_R03');ls={l['__identifier']:l for l in r['layerInstances']};ents=ls['Entities']['entityInstances']
assert not any(e['__identifier']=='TimedGate' for e in ents),'Already authored; preserve hand edits.'
ed={e['identifier']:e for e in p['defs']['entities']};counter=max(p['nextUid'],*map(int,re.findall(r'"uid":\s*(\d+)',raw)))
def uid():
 global counter
 counter+=1;return counter
if 'CrumblingShelf' not in ed:
 d=copy.deepcopy(ed['CrumblingPlatform']);ref=copy.deepcopy(ed['TimedRelay']['fieldDefs'][0]);ref['uid']=uid()
 d.update(identifier='CrumblingShelf',uid=uid(),fieldDefs=[ref],doc='Existing crumbling stones. Its linked lever restores it for another attempt; death and room re-entry also reset it.')
 p['defs']['entities'].append(d);ed['CrumblingShelf']=d
def entity(kind,label,at,size,values):
 d=ed[kind];iid=str(uuid.uuid5(uuid.NAMESPACE_URL,'hooshang/prison/pantry/'+label));fields=[]
 for f in d['fieldDefs']:
  v=values.get(f['identifier'],f['defaultOverride']['params'][0] if f.get('defaultOverride') else None)
  fields.append(dict(__identifier=f['identifier'],__type=f['__type'],__value=v,__tile=None,defUid=f['uid'],realEditorValues=[dict(id={'Float':'V_Float','Bool':'V_Bool'}.get(f['__type'],'V_String'),params=[v['entityIid'] if isinstance(v,dict) else v])]))
 ents.append(dict(__identifier=kind,__smartColor=d['color'],__grid=[at[0]//8,at[1]//8],__pivot=[.5,.5],__tags=d['tags'],__tile=None,__worldX=r['worldX']+at[0],__worldY=r['worldY']+at[1],defUid=d['uid'],iid=iid,px=list(at),width=size[0],height=size[1],fieldInstances=fields));return iid
def reference(iid):return dict(entityIid=iid,layerIid=ls['Entities']['iid'],levelIid=r['iid'],worldIid=p['iid'])
first=reference(entity('TimedGate','shelf_gate',(156,124),(8,72),{'PuzzleId':'cafeteria_pantry_shelf','Duration':6.0}))
second=reference(entity('TimedGate','upper_gate',(236,80),(8,64),{'PuzzleId':'cafeteria_pantry_upper','Duration':4.5}))
entity('TimedLever','shelf_start',(40,152),(16,16),{'Gate':first,'CanBank':True})
entity('TimedLever','shelf_return',(176,112),(16,16),{'Gate':first,'CanBank':False})
entity('TimedRelay','midpoint',(168,112),(16,16),{'Gate':first})
entity('CrumblingShelf','service_shelf',(108,140),(40,8),{'Gate':first})
entity('TimedLever','upper_start',(200,112),(16,16),{'Gate':second,'CanBank':True})
entity('TimedLever','upper_return',(288,104),(16,16),{'Gate':second,'CanBank':False})
entity('TimedRelay','upper_seal',(280,104),(16,16),{'Gate':second})
entity('TimedShutter','key_first_seal',(292,132),(56,8),{'Gate':first,'RequireBank':True})
entity('TimedShutter','key_second_seal',(292,140),(56,8),{'Gate':second,'RequireBank':True})
def set_field(e,name,value):
 f=next(f for f in e['fieldInstances'] if f['__identifier']==name);f['__value']=value;f['realEditorValues']=[dict(id='V_Float' if f['__type']=='Float' else 'V_String',params=[value])]
def move(e,x,y):e.update(px=[x,y],__grid=[x//8,y//8],__worldX=r['worldX']+x,__worldY=r['worldY']+y)
for e in ents:
 if e['__identifier']=='DarkThought':
  move(e,260,80);set_field(e,'Amplitude',16.0)
 if e['__identifier']=='PrisonSign':move(e,184,32);set_field(e,'Text','TWO SEALS')
 if e['__identifier']=='PlayerSpawn':move(e,40,154)
grid=ls['Collision']['intGridCsv']
def box(x,y,w,h,v):
 for yy in range(y,y+h):
  for xx in range(x,x+w):grid[yy*40+xx]=v
# Preserve exterior aperture cells, replacing only the interior route.
box(1,1,38,19,0)
box(1,20,38,3,1)
box(10,20,8,3,0) # recoverable shelf pit, original bottom floor remains
box(19,1,1,10,1) # first wall, passage at y=88..160
box(20,15,7,5,1) # permanent midpoint at y=120
box(24,12,3,1,2) # one-way launch shelf at y=96
box(29,1,1,5,1);box(29,14,1,6,1) # upper passage y=48..112
box(30,14,7,1,2) # far-side seal landing clear of the patrol
box(37,18,2,1,2) # key-alcove return step after both seals open
box(32,16,1,4,1) # left side of key alcove, roof is the two banked shutters
# Keep the existing upper entrance ladder of scaffolds on the left.
box(9,3,5,1,2);box(9,6,5,1,2);box(6,9,5,1,2);box(3,13,5,1,2);box(4,17,4,1,2)
ld={d['identifier']:d for d in p['defs']['layers']};rules=[rr for g in ld['PrisonMasonry']['autoRuleGroups'] for rr in g['rules']];cols=next(t['__cWid'] for t in p['defs']['tilesets'] if t['identifier']=='Act2CastleMasonry')
ls['PrisonMasonry']['autoLayerTiles']=[];ls['Tiles']['autoLayerTiles']=[]
for i,v in enumerate(grid):
 x,y=i%40,i//40
 if v==1:
  rule=next(a for a in rules if a['size']==3) if y==0 or grid[i-40]!=1 else next(a for a in rules if a['size']==1 and a['xOffset']==x%8 and a['yOffset']==y%8)
  tile=rule['tileRectsIds'][0][0];target=ls['PrisonMasonry'];c=cols
 elif v in [2,3]:
  rule=next(a for g in ld['Tiles']['autoRuleGroups'] for a in g['rules'] if a['pattern']==[v]);tile=rule['tileRectsIds'][0][0];target=ls['Tiles'];c=16
 else:continue
 target['autoLayerTiles'].append(dict(px=[x*8,y*8],src=[tile%c*8,tile//c*8],t=tile,f=0,a=1,d=[rule['uid'],i]))
p['nextUid']=counter+1
for a,b in zip(before['levels'],p['levels']):
 if a['identifier']!='Prison_R03':assert a==b
out=ROOT/'output/prison_challenge/cafeteria_capstone';out.mkdir(parents=True,exist_ok=True);(out/'before.ldtk').write_text(raw)
preview=out/'preview.ldtk';preview.write_text(update(raw,p));validate(preview);path.write_text(preview.read_text())
print('Pantry: independently banked 6- and 4.5-second phrases, restoring shelf and dual-sealed key.')
