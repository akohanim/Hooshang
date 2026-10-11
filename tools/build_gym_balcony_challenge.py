#!/usr/bin/env python3
"""Author Y02: two balcony crossings sharing a release timer and final seal.
One-time authoring; later changes remain editable in LDtk.
"""
import copy,json,re,subprocess,uuid
from pathlib import Path
from ldtk_preserve_json import update
from validate_prison_ldtk import validate
ROOT=Path(__file__).resolve().parents[1];path=ROOT/'ldtk/hooshang_act2.ldtk'
assert 'LDtk.app/Contents/MacOS/LDtk' not in subprocess.check_output(['ps','ax','-o','comm'],text=True)
raw=path.read_text();p=json.loads(raw);before=copy.deepcopy(p)
r=next(r for r in p['levels'] if r['identifier']=='Prison_Y02');ls={l['__identifier']:l for l in r['layerInstances']};ents=ls['Entities']['entityInstances']
assert not any(e['__identifier']=='TimedGate' for e in ents),'Already authored; preserve hand edits.'
ed={e['identifier']:e for e in p['defs']['entities']};counter=max(p['nextUid'],*map(int,re.findall(r'"uid":\s*(\d+)',raw)))
def uid():
 global counter
 counter+=1;return counter
if 'PressurePlate' not in ed:
 d=copy.deepcopy(ed['TimedRelay']);d.update(identifier='PressurePlate',uid=uid(),width=24,height=8,doc='Standing on this plate holds its linked shutter open. Leaving starts the gate Duration countdown. No Up press needed.')
 for f in d['fieldDefs']:f['uid']=uid()
 p['defs']['entities'].append(d);ed['PressurePlate']=d
def entity(kind,label,at,size,values):
 d=ed[kind];iid=str(uuid.uuid5(uuid.NAMESPACE_URL,'hooshang/prison/gym-balcony/'+label));fields=[]
 for f in d['fieldDefs']:
  v=values.get(f['identifier'],f['defaultOverride']['params'][0] if f.get('defaultOverride') else None)
  fields.append(dict(__identifier=f['identifier'],__type=f['__type'],__value=v,__tile=None,defUid=f['uid'],realEditorValues=[dict(id={'Float':'V_Float','Bool':'V_Bool'}.get(f['__type'],'V_String'),params=[v['entityIid'] if isinstance(v,dict) else v])]))
 ents.append(dict(__identifier=kind,__smartColor=d['color'],__grid=[at[0]//8,at[1]//8],__pivot=[.5,.5],__tags=d['tags'],__tile=None,__worldX=r['worldX']+at[0],__worldY=r['worldY']+at[1],defUid=d['uid'],iid=iid,px=list(at),width=size[0],height=size[1],fieldInstances=fields));return iid
gate=entity('TimedGate','shutter',(180,132),(8,56),{'PuzzleId':'gym_balcony','Duration':8.5})
ref=dict(entityIid=gate,layerIid=ls['Entities']['iid'],levelIid=r['iid'],worldIid=p['iid'])
entity('PressurePlate','start',(48,156),(24,8),{'Gate':ref})
entity('TimedShutter','second-crossing',(276,132),(8,56),{'Gate':ref,'RequireBank':False})
entity('TimedShutter','exit',(252,180),(40,8),{'Gate':ref,'RequireBank':True})
entity('TimedLever','middle-return',(208,152),(16,16),{'Gate':ref,'CanBank':False})
entity('TimedLever','far-return',(304,152),(16,16),{'Gate':ref,'CanBank':False})
entity('TimedRelay','seal',(288,152),(16,16),{'Gate':ref})
for e in ents:
 if e['__identifier']=='PrisonSign':
  e.update(px=[88,80],__grid=[11,10],__worldX=r['worldX']+88,__worldY=r['worldY']+80)
  f=next(f for f in e['fieldInstances'] if f['__identifier']=='Text');f.update(__value='TWO GAPS / ONE SEAL',realEditorValues=[dict(id='V_String',params=['TWO GAPS / ONE SEAL'])])
grid=ls['Collision']['intGridCsv']
for y in range(1,13):
 for x in [22,34]:grid[y*40+x]=1
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
 if a['identifier']!='Prison_Y02':assert a==b
out=ROOT/'output/prison_challenge/gym_balcony';out.mkdir(parents=True,exist_ok=True);(out/'before.ldtk').write_text(raw)
preview=out/'preview.ldtk';preview.write_text(update(raw,p));validate(preview);path.write_text(preview.read_text())
print('Gym balcony: two gaps, 8.5-second grace, banked exit and return levers.')
