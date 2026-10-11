#!/usr/bin/env python3
"""Add the author's pond/wall ending and explicit staging marks to LDtk."""
import copy,json,uuid,subprocess
from pathlib import Path
from ldtk_preserve_json import update
from act2_grass_terrain import rebake_layer
from validate_prison_ldtk import validate
ROOT=Path(__file__).resolve().parents[1];PATH=ROOT/'ldtk/hooshang_act2.ldtk'
if 'LDtk.app/Contents/MacOS/LDtk' in subprocess.check_output(['ps','ax','-o','comm'],text=True):raise SystemExit('Close LDtk first.')
raw=PATH.read_text();p=json.loads(raw);old=copy.deepcopy(p['levels']);uid=p['nextUid']+1
if any(r['identifier']=='Act_2_Level_20' for r in old):raise SystemExit('Ending already exists; edit LDtk directly.')
defs={d['identifier']:d for d in p['defs']['entities']}
d=copy.deepcopy(defs['Act2StoryScene']);d.update(identifier='FinaleMark',uid=uid,width=8,height=8,pivotX=.5,pivotY=.5,doc='Non-colliding story staging point; Role names its purpose.')
d['fieldDefs'][0].update(identifier='Role',uid=uid+1);uid+=2;defs['FinaleMark']=d;p['defs']['entities'].append(d)
def iid(s):return str(uuid.uuid5(uuid.NAMESPACE_URL,'hooshang-ending-'+s))
def entity(r,kind,x,y,**values):
 d=defs[kind];fields=[]
 for f in d['fieldDefs']:
  v=values.get(f['identifier'],f['defaultOverride']['params'][0] if f.get('defaultOverride') else None)
  fields.append(dict(__identifier=f['identifier'],__type=f['__type'],__value=v,__tile=None,defUid=f['uid'],realEditorValues=[] if v is None else [dict(id='V_String',params=[v])]))
 l=next(l for l in r['layerInstances'] if l['__identifier']=='Entities')
 l['entityInstances'].append(dict(__identifier=kind,__grid=[x//8,y//8],__pivot=[d['pivotX'],d['pivotY']],__tags=d['tags'],__tile=d['tileRect'],__smartColor=d['color'],iid=iid(r['identifier']+kind+str(x)+str(y)),width=d['width'],height=d['height'],defUid=d['uid'],px=[x,y],fieldInstances=fields,__worldX=r['worldX']+x,__worldY=r['worldY']+y))
for n,source,wing in [(20,18,'EndingPond'),(21,19,'EndingWall')]:
 r=copy.deepcopy(next(r for r in old if r['identifier']==f'Act_2_Level_{source}'))
 r.update(identifier=f'Act_2_Level_{n}',uid=uid,iid=iid(str(n)),worldX=2560 if n==20 else 3200,__neighbours=[]);uid+=1
 for f in r['fieldInstances']:
  if f['__identifier']=='wing':f.update(__value=wing,realEditorValues=[dict(id='V_String',params=[wing])])
 layers={l['__identifier']:l for l in r['layerInstances']}
 for l in layers.values():
  l.update(iid=iid(str(n)+l['__identifier']),levelId=r['uid'],entityInstances=[])
 if n==20:
  layers['CastleTerrain']['gridTiles']=[]
  c=layers['Collisions'];g=c['intGridCsv'];cw=c['__cWid']
  for y in range(30):
   for x in range(cw):g[y*cw+x]=10 if y>= (23 if x<14 or x>=64 else 28) else 0
  definition=next(d for d in p['defs']['layers'] if d['identifier']=='Collisions')
  rules=[r for group in definition['autoRuleGroups'] if group['active'] for r in group['rules'] if r['active']]
  rebake_layer(c,rules,{v['value']:v['groupUid'] for v in definition['intGridValues']})
  water=layers['Water'];wg=water['intGridCsv'];water['autoLayerTiles']=[]
  for y in range(30):
   for x in range(cw):wg[y*cw+x]=1 if 14<=x<64 and 23<=y<28 else 0
  def wet(x,y):return 0<=x<cw and 0<=y<30 and wg[y*cw+x]==1
  for i,v in enumerate(wg):
   if not v:continue
   x,y=i%cw,i//cw;top,bottom,left,right=not wet(x,y-1),not wet(x,y+1),not wet(x-1,y),not wet(x+1,y)
   t=3 if (top or bottom) and (left or right) else 1 if top or bottom else 2 if left or right else 0
   water['autoLayerTiles'].append(dict(px=[x*8,y*8],src=[t*8,0],t=t,f=(1 if right and not left else 0)+(2 if bottom and not top else 0),a=1,d=[{3:236,1:237,2:238,0:239}[t],i]))
  entity(r,'PlayerStart',560,178)
  entity(r,'Exit',616,152,NextRoom='Act_2_Level_21')
  for role,x,y in [('Immersion',320,208),('Bank',560,178),('Rumi',492,174),('Rod',96,184)]:entity(r,'FinaleMark',x,y,Role=role)
 else:
  entity(r,'PlayerStart',32,194)
  for role,x,y in [('Wall',128,200),('Painter',256,194),('Home',440,194)]:entity(r,'FinaleMark',x,y,Role=role)
 p['levels'].append(r)
r=next(r for r in p['levels'] if r['identifier']=='Act_2_Level_19');entity(r,'FinaleMark',320,196,Role='Carpet')
p['nextUid']=uid
for r in old:
 if r['identifier']!='Act_2_Level_19':assert r==next(a for a in p['levels'] if a['identifier']==r['identifier'])
out=ROOT/'output/act2_polish/ending';out.mkdir(parents=True,exist_ok=True);(out/'before_ending.ldtk').write_text(raw)
preview=out/'ending_preview.ldtk';preview.write_text(update(raw,p));validate(preview);PATH.write_text(preview.read_text())
print('Added ending rooms 20/21 and explicit staging marks.')
