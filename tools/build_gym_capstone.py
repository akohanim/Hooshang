#!/usr/bin/env python3
"""Author Y03: wall-jump relay, reverse upper crossing and a two-seal key alcove.
One-time authoring; later changes remain editable in LDtk.
"""
import copy,json,re,subprocess,uuid
from pathlib import Path
from ldtk_preserve_json import update
from validate_prison_ldtk import validate
ROOT=Path(__file__).resolve().parents[1];path=ROOT/'ldtk/hooshang_act2.ldtk'
assert 'LDtk.app/Contents/MacOS/LDtk' not in subprocess.check_output(['ps','ax','-o','comm'],text=True)
raw=path.read_text();p=json.loads(raw);before=copy.deepcopy(p)
r=next(r for r in p['levels'] if r['identifier']=='Prison_Y03');ls={l['__identifier']:l for l in r['layerInstances']};ents=ls['Entities']['entityInstances']
assert not any(e['__identifier']=='TimedGate' for e in ents),'Already authored; preserve hand edits.'
ed={e['identifier']:e for e in p['defs']['entities']};counter=max(p['nextUid'],*map(int,re.findall(r'"uid":\s*(\d+)',raw)))
def uid():
 global counter
 counter+=1;return counter
def entity(kind,label,at,size,values):
 d=ed[kind];iid=str(uuid.uuid5(uuid.NAMESPACE_URL,'hooshang/prison/gym-capstone/'+label));fields=[]
 for f in d['fieldDefs']:
  v=values.get(f['identifier'],f['defaultOverride']['params'][0] if f.get('defaultOverride') else None)
  fields.append(dict(__identifier=f['identifier'],__type=f['__type'],__value=v,__tile=None,defUid=f['uid'],realEditorValues=[dict(id={'Float':'V_Float','Bool':'V_Bool'}.get(f['__type'],'V_String'),params=[v['entityIid'] if isinstance(v,dict) else v])]))
 ents.append(dict(__identifier=kind,__smartColor=d['color'],__grid=[at[0]//8,at[1]//8],__pivot=[.5,.5],__tags=d['tags'],__tile=None,__worldX=r['worldX']+at[0],__worldY=r['worldY']+at[1],defUid=d['uid'],iid=iid,px=list(at),width=size[0],height=size[1],fieldInstances=fields));return iid
def reference(iid):return dict(entityIid=iid,layerIid=ls['Entities']['iid'],levelIid=r['iid'],worldIid=p['iid'])
first=reference(entity('TimedGate','ascent_gate',(212,108),(8,56),{'PuzzleId':'gym_ascent','Duration':7.0}))
second=reference(entity('TimedGate','reverse_gate',(156,52),(8,72),{'PuzzleId':'gym_reverse','Duration':6.0}))
entity('PressurePlate','ascent_start',(112,156),(24,8),{'Gate':first})
entity('TimedLever','ascent_return',(280,112),(16,16),{'Gate':first,'CanBank':False})
entity('TimedRelay','midpoint',(232,112),(16,16),{'Gate':first})
entity('PressurePlate','reverse_start',(256,116),(24,8),{'Gate':second})
entity('TimedLever','reverse_return',(80,56),(16,16),{'Gate':second,'CanBank':False})
entity('TimedRelay','upper_seal',(104,56),(16,16),{'Gate':second})
entity('TimedShutter','key_first_seal',(60,132),(72,8),{'Gate':first,'RequireBank':True})
entity('TimedShutter','key_second_seal',(60,140),(72,8),{'Gate':second,'RequireBank':True})
entity('DarkThought','upper_patrol',(136,40),(16,16),{'Motion':'Vertical','Amplitude':16.0,'Speed':0.7,'ChildhoodPalette':1.0})
def set_field(e,name,value):
 f=next(f for f in e['fieldInstances'] if f['__identifier']==name);f['__value']=value;f['realEditorValues']=[dict(id='V_Float' if f['__type']=='Float' else 'V_String',params=[value])]
def move(e,x,y):e.update(px=[x,y],__grid=[x//8,y//8],__worldX=r['worldX']+x,__worldY=r['worldY']+y)
for e in ents:
 if e['__identifier']=='PrisonSign':move(e,88,88);set_field(e,'Text','TWO SEALS')
 if e['__identifier']=='PlayerSpawn':move(e,112,154)
grid=ls['Collision']['intGridCsv']
def box(x,y,w,h,v):
 for yy in range(y,y+h):
  for xx in range(x,x+w):grid[yy*40+xx]=v
# Keep the right entrance ladder and original opposed wall-jump faces.
box(26,1,1,2,1) # leave upper crossing open above the ascent shutter
box(26,17,1,3,1)
box(28,15,9,1,2) # broad midpoint, x224..296, top120
box(27,11,7,1,2) # launch shelf, x216..272, top88
box(21,9,4,1,2) # upper rest, x168..200, top72
box(9,8,7,1,2) # upper seal landing, x72..128, top64
box(19,1,1,1,1)
box(19,11,1,3,1)
box(4,18,1,2,1);box(11,18,1,2,1) # sides of key pocket
# Ascending steps out of the opened key pocket and back to the upper return.
box(4,14,5,1,2)
box(7,11,5,1,2)
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
 if a['identifier']!='Prison_Y03':assert a==b
out=ROOT/'output/prison_challenge/gym_capstone';out.mkdir(parents=True,exist_ok=True);(out/'before.ldtk').write_text(raw)
preview=out/'preview.ldtk';preview.write_text(update(raw,p));validate(preview);path.write_text(preview.read_text())
print('Gym capstone: 7-second ascent, 6-second reverse crossing, and dual-sealed Gold key.')
