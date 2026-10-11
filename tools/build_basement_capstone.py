#!/usr/bin/env python3
"""Author B03: persistent dry valve, submerged seal and high dry seal guarding the Blue key.
One-time authoring; later changes remain editable in LDtk.
"""
import copy,json,re,subprocess,uuid
from pathlib import Path
from ldtk_preserve_json import update
from validate_prison_ldtk import validate
ROOT=Path(__file__).resolve().parents[1];path=ROOT/'ldtk/hooshang_act2.ldtk'
assert 'LDtk.app/Contents/MacOS/LDtk' not in subprocess.check_output(['ps','ax','-o','comm'],text=True)
raw=path.read_text();p=json.loads(raw);before=copy.deepcopy(p)
r=next(r for r in p['levels'] if r['identifier']=='Prison_B03');ls={l['__identifier']:l for l in r['layerInstances']};ents=ls['Entities']['entityInstances']
assert not any(e['__identifier']=='FloodGate' for e in ents),'Already authored; preserve hand edits.'
ed={e['identifier']:e for e in p['defs']['entities']};counter=max(p['nextUid'],*map(int,re.findall(r'"uid":\s*(\d+)',raw)))
def uid():
 global counter
 counter+=1;return counter
if 'FloodGate' not in ed:
 d=copy.deepcopy(ed['CircuitGate']);d.update(identifier='FloodGate',uid=uid(),doc='Permanent sluice, opened by one linked FloodValve.')
 for f in d['fieldDefs']:f['uid']=uid()
 p['defs']['entities'].append(d);ed['FloodGate']=d
 d=copy.deepcopy(ed['CircuitNode']);d.update(identifier='FloodValve',uid=uid(),doc='Touch seal or Up-operated valve. Opens its linked sluice permanently.')
 for f in d['fieldDefs']:f.update(uid=uid(),allowedRefsEntityUid=ed['FloodGate']['uid'])
 for name,doc in [('Touch','Activate on contact rather than a fresh Up press.'),('RequireDry','Require solid footing outside water.')]:
  f=copy.deepcopy(ed['TimedLever']['fieldDefs'][1]);f.update(identifier=name,uid=uid(),doc=doc,defaultOverride={'id':'V_Bool','params':[False]});d['fieldDefs'].append(f)
 p['defs']['entities'].append(d);ed['FloodValve']=d
def entity(kind,label,at,size,values):
 d=ed[kind];iid=str(uuid.uuid5(uuid.NAMESPACE_URL,'hooshang/prison/flood-pump/'+label));fields=[]
 for f in d['fieldDefs']:
  v=values.get(f['identifier'],f['defaultOverride']['params'][0] if f.get('defaultOverride') else None)
  fields.append(dict(__identifier=f['identifier'],__type=f['__type'],__value=v,__tile=None,defUid=f['uid'],realEditorValues=[dict(id={'Float':'V_Float','Bool':'V_Bool'}.get(f['__type'],'V_String'),params=[v['entityIid'] if isinstance(v,dict) else v])]))
 ents.append(dict(__identifier=kind,__smartColor=d['color'],__grid=[at[0]//8,at[1]//8],__pivot=[.5,.5],__tags=d['tags'],__tile=None,__worldX=r['worldX']+at[0],__worldY=r['worldY']+at[1],defUid=d['uid'],iid=iid,px=list(at),width=size[0],height=size[1],fieldInstances=fields));return iid
def reference(iid):return dict(entityIid=iid,layerIid=ls['Entities']['iid'],levelIid=r['iid'],worldIid=p['iid'])
ref=reference(entity('FloodGate','pump_sluice',(156,160),(8,48),{'CircuitId':'basement_pump_valve'}))
entity('FloodValve','dry_start',(256,88),(16,16),{'Gate':ref,'Touch':False,'RequireDry':True})
ref=reference(entity('CircuitGate','key_gate',(276,80),(8,32),{'CircuitId':'basement_pump_key'}))
entity('CircuitNode','deep_seal',(104,160),(16,16),{'Gate':ref})
entity('CircuitNode','high_seal',(184,32),(16,16),{'Gate':ref})
def set_field(e,name,value):
 f=next(f for f in e['fieldInstances'] if f['__identifier']==name);f['__value']=value;f['realEditorValues']=[dict(id='V_String',params=[value])]
def move(e,x,y):e.update(px=[x,y],__grid=[x//8,y//8],__worldX=r['worldX']+x,__worldY=r['worldY']+y)
for e in ents:
 if e['__identifier']=='PrisonSign':move(e,176,24);set_field(e,'Text','BOTH SEALS OPEN KEY')
 if e['__identifier']=='PlayerSpawn':move(e,256,90)
grid=ls['Collision']['intGridCsv']
def box(x,y,w,h,v):
 for yy in range(y,y+h):
  for xx in range(x,x+w):grid[yy*40+xx]=v
box(8,12,11,11,4) # open water behind the sluice; remove the old baffle
box(7,11,13,1,1) # roof prevents entering the deep seal chamber from above
box(7,12,1,11,1) # left side of submerged chamber
box(19,12,1,5,1) # above the sluice; remaining y=136..184 is the gate
box(19,17,1,6,4)
box(30,12,4,4,1) # dry valve bank, preserving the water entrance below y=128
box(34,7,5,1,1) # key alcove roof meets the existing right boundary
box(27,11,4,1,2) # dry approach scaffold, y=88
box(27,8,4,1,2) # launch platform, y=64
box(21,5,4,1,2) # high seal landing, y=40: deliberate jump/dash gap
box(10,22,3,1,3) # visible floor hazard below the deep seal, leaving a safe swim lane
ld={d['identifier']:d for d in p['defs']['layers']};rules=[rr for g in ld['PrisonMasonry']['autoRuleGroups'] for rr in g['rules']];cols=next(t['__cWid'] for t in p['defs']['tilesets'] if t['identifier']=='Act2CastleMasonry')
ls['PrisonMasonry']['autoLayerTiles']=[];ls['Tiles']['autoLayerTiles']=[]
for i,v in enumerate(grid):
 x,y=i%40,i//40
 if v==1:
  rule=next(a for a in rules if a['size']==3) if y==0 or grid[i-40]!=1 else next(a for a in rules if a['size']==1 and a['xOffset']==x%8 and a['yOffset']==y%8)
  tile=rule['tileRectsIds'][0][0];target=ls['PrisonMasonry'];c=cols
 elif v in [2,3,4]:
  rule=next(a for g in ld['Tiles']['autoRuleGroups'] for a in g['rules'] if a['pattern']==[v]);tile=rule['tileRectsIds'][0][0];target=ls['Tiles'];c=16
 else:continue
 target['autoLayerTiles'].append(dict(px=[x*8,y*8],src=[tile%c*8,tile//c*8],t=tile,f=0,a=1,d=[rule['uid'],i]))
p['nextUid']=counter+1
for a,b in zip(before['levels'],p['levels']):
 if a['identifier']!='Prison_B03':assert a==b
out=ROOT/'output/prison_challenge/basement_capstone';out.mkdir(parents=True,exist_ok=True);(out/'before.ldtk').write_text(raw)
preview=out/'preview.ldtk';preview.write_text(update(raw,p));validate(preview);path.write_text(preview.read_text())
print('Pump room: dry valve, underwater seal, high dash seal and enclosed Blue key.')
