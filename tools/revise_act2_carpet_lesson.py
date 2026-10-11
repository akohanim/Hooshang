#!/usr/bin/env python3
"""Replace the audited trapping draft with a recoverable first carpet lesson.
Preserve subsequent rooms' LOCAL geometry; shift their map positions to keep
this shorter room adjacent to the garden chain. Re-run only with --replace.
"""
import argparse,copy,json,uuid,subprocess
from pathlib import Path
from ldtk_preserve_json import update
from act2_grass_terrain import rebake_layer
from validate_prison_ldtk import validate
ROOT=Path(__file__).resolve().parents[1];PATH=ROOT/'ldtk/hooshang_act2.ldtk'
def main(replace):
 if 'LDtk.app/Contents/MacOS/LDtk' in subprocess.check_output(['ps','ax','-o','comm'],text=True):raise SystemExit('Close LDtk before editing its source.')
 raw=PATH.read_text();p=json.loads(raw);r=next(r for r in p['levels'] if r['identifier']=='Level_2')
 if r['pxWid']==960 and not replace:raise SystemExit('Lesson exists; edit in LDtk or pass --replace.')
 out=ROOT/'output/act2_polish/carpet_lesson';out.mkdir(parents=True,exist_ok=True)
 backup=out/'before.ldtk'
 if not backup.exists():backup.write_text(raw)
 previous=copy.deepcopy(p);shift=r['pxWid']-960
 defs={d['identifier']:d for d in p['defs']['entities']}
 r.update(pxWid=960,pxHei=320,worldY=488,__neighbours=[])
 for a in r['layerInstances']:
  a.update(__cWid=120,__cHei=40,entityInstances=[],gridTiles=[],autoLayerTiles=[])
  a['intGridCsv']=[0]*4800 if a['__type']=='IntGrid' else []
 layers={a['__identifier']:a for a in r['layerInstances']}
 grid=layers['Collisions']['intGridCsv']
 def rect(x,y,w,h,v=10):
  for yy in range(y//8,(y+h)//8):
   for xx in range(x//8,(x+w)//8):grid[yy*120+xx]=v
 for x,y,w in [(0,272,208),(208,248,64),(272,272,24),(296,312,344),(640,272,24),(664,264,72),(736,248,64),(800,232,64),(864,216,96)]:rect(x,y,w,320-y)
 # A visibly supported low arch, traversed below by either rug or swimmer.
 rect(432,0,80,232)
 # Upper route is an optional lemon detour, separate from required progress.
 rect(568,192,48,8)
 water=layers['Water'];g=water['intGridCsv']
 for y in range(272//8,312//8):
  for x in range(296//8,640//8):g[y*120+x]=1
 def wet(x,y):return 0<=x<120 and 0<=y<40 and g[y*120+x]==1
 for i,v in enumerate(g):
  if not v:continue
  x,y=i%120,i//120;top,bottom,left,right=not wet(x,y-1),not wet(x,y+1),not wet(x-1,y),not wet(x+1,y)
  t=3 if (top or bottom) and (left or right) else 1 if top or bottom else 2 if left or right else 0
  water['autoLayerTiles'].append(dict(px=[x*8,y*8],src=[t*8,0],t=t,f=(1 if right and not left else 0)+(2 if bottom and not top else 0),a=1,d=[{3:236,1:237,2:238,0:239}[t],i]))
 def entity(name,x,y,w=None,h=None,**values):
  d=defs[name];fields=[]
  for f in d['fieldDefs']:
   v=values.get(f['identifier'],f.get('defaultOverride',{}).get('params',[None])[0] if f.get('defaultOverride') else None)
   kind='V_Float' if f['__type']=='Float' else 'V_Int' if f['__type']=='Int' else 'V_String'
   fields.append(dict(__identifier=f['identifier'],__type=f['__type'],__value=v,__tile=None,defUid=f['uid'],realEditorValues=[] if v is None else [dict(id=kind,params=[v])]))
  layers['Entities']['entityInstances'].append(dict(__identifier=name,__grid=[x//8,y//8],__pivot=[d['pivotX'],d['pivotY']],__tags=d['tags'],__tile=d['tileRect'],__smartColor=d['color'],iid=str(uuid.uuid5(uuid.NAMESPACE_URL,'act2-carpet-lesson-'+name+str(x))),width=w or d['width'],height=h or d['height'],defUid=d['uid'],px=[x,y],fieldInstances=fields,__worldX=r['worldX']+x,__worldY=r['worldY']+y))
 entity('PlayerStart',32,266)
 entity('SpringPlatform',112,268,Facing='Up')
 entity('MagicCarpet',304,224,w=64,h=8,CarpetPattern='Ride',Speed=32.0,CarpetColor='Crimson')
 entity('Lemon',592,168)
 entity('Lemon',472,296)
 entity('Exit',936,184,NextRoom='Act_2_Level_3')
 ld=next(d for d in p['defs']['layers'] if d['identifier']=='Collisions')
 rules=[rule for group in ld['autoRuleGroups'] if group['active'] for rule in group['rules'] if rule['active']]
 groups={v['value']:v['groupUid'] for v in ld['intGridValues']}
 rebake_layer(layers['Collisions'],rules,groups)
 for room in p['levels']:
  name=room['identifier']
  if name.startswith('Act_2_Level_') and 3<=int(name.rsplit('_',1)[1])<=15:
   room['worldX']-=shift
   for layer in room['layerInstances']:
    for e in layer['entityInstances']:e['__worldX']=room['worldX']+e['px'][0]
 # Ensure only the selected room's geometry changed.
 for old in previous['levels']:
  if old['identifier']=='Level_2':continue
  new=next(x for x in p['levels'] if x['identifier']==old['identifier'])
  a,b=copy.deepcopy(old),copy.deepcopy(new)
  a['worldX']=b['worldX']
  for la,lb in zip(a['layerInstances'],b['layerInstances']):
   for ea,eb in zip(la['entityInstances'],lb['entityInstances']):ea['__worldX']=eb['__worldX']
  assert a==b,old['identifier']
 preview=out/'preview.ldtk';preview.write_text(update(raw,p));validate(preview);PATH.write_text(preview.read_text())
 print('Installed 960×320 carpet lesson; later room geometry preserved.')
if __name__=='__main__':
 parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('--replace',action='store_true');args=parser.parse_args();main(args.replace)
