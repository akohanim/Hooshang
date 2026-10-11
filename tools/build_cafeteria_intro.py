#!/usr/bin/env python3
"""Install timed puzzle entities and author the cafeteria's first lever encounter.
Run once; later room edits belong in LDtk. No other room geometry is changed.
"""
import copy,json,re,subprocess,uuid
from pathlib import Path
from ldtk_preserve_json import update
from validate_prison_ldtk import validate
ROOT=Path(__file__).resolve().parents[1];path=ROOT/'ldtk/hooshang_act2.ldtk'
assert 'LDtk.app/Contents/MacOS/LDtk' not in subprocess.check_output(['ps','ax','-o','comm'],text=True)
raw=path.read_text();p=json.loads(raw);before=copy.deepcopy(p)
room=next(r for r in p['levels'] if r['identifier']=='Prison_R01');ls={l['__identifier']:l for l in room['layerInstances']};entities=ls['Entities']['entityInstances']
assert not any(e['__identifier']=='TimedGate' for e in entities),'Already authored; preserve later LDtk edits.'
count=max(p['nextUid'],*map(int,re.findall(r'"uid":\s*(\d+)',raw)))
def uid():
 global count
 count+=1;return count
ed={e['identifier']:e for e in p['defs']['entities']}
def field(name,typ,value=None):
 f=copy.deepcopy(ed['CircuitGate']['fieldDefs'][0]);f.update(identifier=name,uid=uid(),__type=typ,type={'String':'F_String','Float':'F_Float','Bool':'F_Bool','EntityRef':'F_EntityRef'}[typ],canBeNull=False,defaultOverride=None,allowedRefs='Any',allowedRefsEntityUid=None,allowOutOfLevelRef=False)
 f['doc']={'PuzzleId': 'Unique stable save identity for this timed challenge.', 'Duration': 'Seconds from main-lever activation to touching the completion seal.', 'Gate': 'TimedGate in this room controlled by this entity.', 'CanBank': 'True: main start lever. False: opens a return path but cannot complete the challenge.'}[name]
 if value is not None:f['defaultOverride']={'id':{'Float':'V_Float','Bool':'V_Bool'}.get(typ,'V_String'),'params':[value]}
 return f
def definition(name,size,fields):
 if name in ed:return ed[name]
 d=copy.deepcopy(ed['CircuitGate']);d.update(identifier=name,uid=uid(),width=size[0],height=size[1],fieldDefs=fields,resizableX=name=='TimedGate',resizableY=name=='TimedGate',doc='Timed lever and far relay. Return levers reopen passage but cannot bank completion.')
 p['defs']['entities'].append(d);ed[name]=d;return d
gate_def=definition('TimedGate',(8,32),[field('PuzzleId','String'),field('Duration','Float',8.0)])
for kind in ['TimedLever','TimedRelay']:
 ref=field('Gate','EntityRef');ref.update(allowedRefs='OnlySpecificEntity',allowedRefsEntityUid=gate_def['uid'])
 definition(kind,(16,16),[ref,field('CanBank','Bool',True)] if kind=='TimedLever' else [ref])
def entity(kind,label,x,y,values):
 d=ed[kind];ident=str(uuid.uuid5(uuid.NAMESPACE_URL,'hooshang/prison/cafeteria/'+label));fs=[]
 for f in d['fieldDefs']:
  default=f.get('defaultOverride');v=values.get(f['identifier'],default['params'][0] if default else None)
  fs.append(dict(__identifier=f['identifier'],__type=f['__type'],__value=v,__tile=None,defUid=f['uid'],realEditorValues=[dict(id={'Float':'V_Float','Bool':'V_Bool'}.get(f['__type'],'V_String'),params=[v['entityIid'] if isinstance(v,dict) else v])]))
 entities.append(dict(__identifier=kind,__smartColor=d['color'],__grid=[x//8,y//8],__pivot=[.5,.5],__tags=d['tags'],__tile=None,__worldX=room['worldX']+x,__worldY=room['worldY']+y,defUid=d['uid'],iid=ident,px=[x,y],width=d['width'],height=d['height'],fieldInstances=fs));return ident
gate=entity('TimedGate','intro_gate',84,144,{'PuzzleId':'cafeteria_intro','Duration':9.0})
ref=dict(entityIid=gate,layerIid=ls['Entities']['iid'],levelIid=room['iid'],worldIid=p['iid'])
entity('TimedLever','intro_start',264,152,{'Gate':ref,'CanBank':True})
entity('TimedLever','intro_return',40,152,{'Gate':ref,'CanBank':False})
entity('TimedRelay','intro_relay',64,152,{'Gate':ref})
for e in entities:
 if e['__identifier']=='PlayerSpawn':e.update(px=[288,154],__grid=[36,19],__worldX=room['worldX']+288,__worldY=room['worldY']+154)
 if e['__identifier']=='PrisonSign':
  e.update(px=[192,40],__grid=[24,5],__worldX=room['worldX']+192,__worldY=room['worldY']+40)
  f=e['fieldInstances'][0];f['__value']='UP: LEVER / TOUCH THE SEAL';f['realEditorValues']=[dict(id='V_String',params=[f['__value']])]
grid=ls['Collision']['intGridCsv']
for y in range(1,16):grid[y*40+10]=1
ld={d['identifier']:d for d in p['defs']['layers']};rules=[r for g in ld['PrisonMasonry']['autoRuleGroups'] for r in g['rules']];cols=next(t['__cWid'] for t in p['defs']['tilesets'] if t['identifier']=='Act2CastleMasonry')
ls['PrisonMasonry']['autoLayerTiles']=[]
for i,v in enumerate(grid):
 if v!=1:continue
 x,y=i%40,i//40
 r=next(r for r in rules if r['size']==3) if y==0 or grid[i-40]!=1 else next(r for r in rules if r['size']==1 and r['xOffset']==x%8 and r['yOffset']==y%8)
 t=r['tileRectsIds'][0][0];ls['PrisonMasonry']['autoLayerTiles'].append(dict(px=[x*8,y*8],src=[t%cols*8,t//cols*8],t=t,f=0,a=1,d=[r['uid'],i]))
p['nextUid']=count+1
for a,b in zip(before['levels'],p['levels']):
 if a['identifier']!='Prison_R01':assert a==b
out=ROOT/'output/prison_challenge/cafeteria_intro';out.mkdir(parents=True,exist_ok=True)
(out/'before.ldtk').write_text(raw);preview=out/'preview.ldtk';preview.write_text(update(raw,p));validate(preview);path.write_text(preview.read_text())
print('Cafeteria introduction: nine-second lever, sealed passage, relay and return-only lever.')
