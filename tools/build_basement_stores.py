#!/usr/bin/env python3
"""Author B02: submerged approach to a dry valve pocket and a permanent exit sluice.
One-time authoring; later changes remain editable in LDtk.
"""
import copy,json,re,subprocess,uuid
from pathlib import Path
from ldtk_preserve_json import update
from validate_prison_ldtk import validate
ROOT=Path(__file__).resolve().parents[1];path=ROOT/'ldtk/hooshang_act2.ldtk'
assert 'LDtk.app/Contents/MacOS/LDtk' not in subprocess.check_output(['ps','ax','-o','comm'],text=True)
raw=path.read_text();p=json.loads(raw);before=copy.deepcopy(p)
r=next(r for r in p['levels'] if r['identifier']=='Prison_B02');ls={l['__identifier']:l for l in r['layerInstances']};ents=ls['Entities']['entityInstances']
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
 d=ed[kind];iid=str(uuid.uuid5(uuid.NAMESPACE_URL,'hooshang/prison/flood-stores/'+label));fields=[]
 for f in d['fieldDefs']:
  v=values.get(f['identifier'],f['defaultOverride']['params'][0] if f.get('defaultOverride') else None)
  fields.append(dict(__identifier=f['identifier'],__type=f['__type'],__value=v,__tile=None,defUid=f['uid'],realEditorValues=[dict(id={'Float':'V_Float','Bool':'V_Bool'}.get(f['__type'],'V_String'),params=[v['entityIid'] if isinstance(v,dict) else v])]))
 ents.append(dict(__identifier=kind,__smartColor=d['color'],__grid=[at[0]//8,at[1]//8],__pivot=[.5,.5],__tags=d['tags'],__tile=None,__worldX=r['worldX']+at[0],__worldY=r['worldY']+at[1],defUid=d['uid'],iid=iid,px=list(at),width=size[0],height=size[1],fieldInstances=fields));return iid
gate=entity('FloodGate','sluice',(4,144),(8,32),{'CircuitId':'basement_stores'})
ref=dict(entityIid=gate,layerIid=ls['Entities']['iid'],levelIid=r['iid'],worldIid=p['iid'])
entity('FloodValve','dry_valve',(104,120),(16,16),{'Gate':ref,'Touch':False,'RequireDry':True})
def set_field(e,name,value):
 f=next(f for f in e['fieldInstances'] if f['__identifier']==name);f['__value']=value;f['realEditorValues']=[dict(id='V_String',params=[value])]
def move(e,x,y):e.update(px=[x,y],__grid=[x//8,y//8],__worldX=r['worldX']+x,__worldY=r['worldY']+y)
for e in ents:
 if e['__identifier']=='PrisonSign':move(e,96,56);set_field(e,'Text','DRY VALVE / UP')
 if e['__identifier']=='PlayerSpawn':move(e,204,18)
grid=ls['Collision']['intGridCsv']
def box(x,y,w,h,v):
 for yy in range(y,y+h):
  for xx in range(x,x+w):grid[yy*40+xx]=v
box(18,12,2,6,4) # remove the old narrow baffle
box(20,12,2,6,1) # new dive baffle, with a 32px-wide ascent shaft behind it
box(10,11,12,1,1) # continuous roof prevents dropping straight onto the valve
box(9,11,1,9,1) # left wall, ending at y=160 for the lower swim return
box(10,12,6,4,0) # dry pocket with 32px of headroom
box(10,16,6,4,1) # permanent valve footing
box(22,22,3,1,3) # visible deep-water floor hazard, away from the observation pocket
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
 if a['identifier']!='Prison_B02':assert a==b
out=ROOT/'output/prison_challenge/basement_stores';out.mkdir(parents=True,exist_ok=True);(out/'before.ldtk').write_text(raw)
preview=out/'preview.ldtk';preview.write_text(update(raw,p));validate(preview);path.write_text(preview.read_text())
print('Flooded stores: submerged approach, dry valve pocket and permanent left exit.')
