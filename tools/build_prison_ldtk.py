#!/usr/bin/env python3
"""Bootstrap approved prison rooms into Act 2. LDtk is the source after bootstrap.
Rebuild requires --rebuild; every write makes a timestamped backup. No runtime
level JSON is maintained beside LDtk. Validate against official 1.5.3 schema.
"""
import argparse, copy, datetime, json, re, subprocess, uuid
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
PATH=ROOT/'ldtk/hooshang_act2.ldtk'
NAMESPACE=uuid.UUID('2bf49576-22c3-4a57-82b7-23f41303d3b9')
def iid(s):return str(uuid.uuid5(NAMESPACE,s))
POSITIONS={'Prison_Hub':(0,0,80,48)}
for w,pts in {'R':[(-1,0),(-2,0),(-2,1),(-1,1)],'G':[(0,-1),(0,-2),(1,-2),(1,-1)],'B':[(1,2),(1,3),(0,3),(0,2)],'Y':[(2,0),(3,0),(3,1),(2,1)]}.items():
 for i,(x,y) in enumerate(pts,1):POSITIONS[f'Prison_{w}{i:02}']=(x,y,40,24)
COLORS={'R':'Red','G':'Green','B':'Blue','Y':'Gold'}

def build(rebuild=False):
 processes=subprocess.check_output(['ps','ax','-o','command'],text=True)
 if any('LDtk.app/Contents/MacOS/LDtk' in s for s in processes.splitlines()):raise SystemExit('Close LDtk before editing its source.')
 p=json.loads(PATH.read_text());original=copy.deepcopy(p)
 existing=[r for r in p['levels'] if r['identifier'].startswith('Prison_')]
 if existing and not rebuild:raise SystemExit('Prison already exists; edit it in LDtk. Explicit --rebuild overwrites prison rooms only.')
 p['levels']=[r for r in p['levels'] if not r['identifier'].startswith('Prison_')]
 counter=max([p['nextUid']]+[int(n) for n in re.findall(r'"uid":\s*(\d+)',json.dumps(p))])+1
 def uid():
  nonlocal counter
  counter+=1;return counter
 # Repair an existing numeric level/entity UID collision without changing IIDs.
 used={d['uid'] for cat in ['entities','layers','tilesets','enums','levelFields'] for d in p['defs'][cat]}
 used.update(f['uid'] for e in p['defs']['entities'] for f in e['fieldDefs'])
 for r in p['levels']:
  if r['uid'] in used:
   r['uid']=uid()
   for l in r['layerInstances']:l['levelId']=r['uid']
  used.add(r['uid'])
 def upsert(cat,obj):
  old=next((d for d in p['defs'][cat] if d['identifier']==obj['identifier']),None)
  if old:return old
  p['defs'][cat].append(obj);return obj
 ftemplate=copy.deepcopy(p['defs']['entities'][0]['fieldDefs'][0])
 def field(name,typ,default=None):
  f=copy.deepcopy(ftemplate);f.update(identifier=name,uid=uid(),__type=typ,type={'String':'F_String','Bool':'F_Bool','EntityRef':'F_EntityRef'}.get(typ,'F_Enum(KeyId)'),isArray=False,canBeNull=default is None,defaultOverride=None,doc='Prison mission authoring field.',allowedRefs='Any',allowOutOfLevelRef=True)
  if default is not None:f['defaultOverride']={'id':{'String':'V_String','Bool':'V_Bool'}.get(typ,'V_String'),'params':[default]}
  return f
 enum=copy.deepcopy(p['defs']['enums'][0]);enum.update(identifier='KeyId',uid=uid(),values=[{'id':n,'tileRect':None,'color':c} for n,c in [('Red',0xb54c41),('Blue',0x449bb8),('Green',0x548f68),('Gold',0xdeaf4a)]]);upsert('enums',enum)
 wf=upsert('levelFields',field('wing','String',''));hf=upsert('levelFields',field('isHub','Bool',False))
 def finst(f,v):
  if f['__type']=='Float' and v is not None:v=float(v)
  if f['__type']=='Int' and v is not None:v=int(v)
  wrapped=v.get('entityIid') if isinstance(v,dict) and f['__type']=='EntityRef' else v
  kind={'Bool':'V_Bool','Float':'V_Float','Int':'V_Int','Color':'V_Int'}.get(f['__type'],'V_String')
  return {'__identifier':f['identifier'],'__type':f['__type'],'__value':v,'__tile':None,'defUid':f['uid'],'realEditorValues':[] if v is None else [{'id':kind,'params':[wrapped]}]}
 for r in p['levels']:
  for f in [wf,hf]:
   if not any(x['defUid']==f['uid'] for x in r['fieldInstances']):r['fieldInstances'].append(finst(f,'' if f==wf else False))
 ts=copy.deepcopy(p['defs']['tilesets'][0]);ts.update(identifier='PrisonSchool',uid=uid(),relPath='art/prison/school.png',pxWid=128,pxHei=128,tileGridSize=8,__cWid=16,__cHei=16,spacing=0,padding=0,enumTags=[],customData=[],savedSelections=[],cachedPixelData=None);ts=upsert('tilesets',ts)
 ld={d['identifier']:d for d in p['defs']['layers']};collision=ld['Collision']
 assert not any(4 in l['intGridCsv'] for r in p['levels'] for l in r['layerInstances'] if l['__identifier']=='Collision'), 'Legacy value 4 must be migrated first'
 collision['intGridValues'][3].update(identifier='Water',color='#449BB8')
 collision['doc']='Prison: 1 solid, 2 one-way, 3 hazard, 4 water. Existing rooms retain their own imported geometry.'
 def layerdef(name,typ):
  l=copy.deepcopy(ld['Entities']);l.update(identifier=name,uid=uid(),__type=typ,type=typ,tilesetDefUid=ts['uid'],autoSourceLayerDefUid=collision['uid'] if typ=='AutoLayer' else None)
  return upsert('layers',l)
 tiles=layerdef('Tiles','AutoLayer');decor=layerdef('Decor','Tiles')
 ruletemplate=copy.deepcopy(ld['Water']['autoRuleGroups'][0]['rules'][-1])
 rules=[]
 for value,tile in [(1,0),(2,5),(3,6),(4,7)]:
  if value in (1,4):
   r=copy.deepcopy(ruletemplate);r.update(uid=uid(),size=3,pattern=[0,-value,0,0,value,0,0,0,0],tileRectsIds=[[1 if value==1 else 8]]);rules.append(r)
  r=copy.deepcopy(ruletemplate);r.update(uid=uid(),size=1,pattern=[value],tileRectsIds=[[tile]]);rules.append(r)
 group=copy.deepcopy(ld['Water']['autoRuleGroups'][0]);group.update(uid=uid(),name='School materials',rules=rules);tiles['autoRuleGroups']=[group]
 # Keep requested relative order without reordering older render layers.
 extras=[d for d in p['defs']['layers'] if d['identifier'] not in ['Collision','Tiles','Decor','Entities']]
 p['defs']['layers']=extras+[collision,tiles,decor,ld['Entities']]
 etemplate=copy.deepcopy(next(e for e in p['defs']['entities'] if e['identifier']=='Checkpoint'))
 def entitydef(name,w,h,fields=[]):
  e=copy.deepcopy(etemplate);e.update(identifier=name,uid=uid(),width=w,height=h,fieldDefs=fields,pivotX=.5,pivotY=.5,doc='Prison mission entity',color='#DEAF4A');return upsert('entities',e)
 spawn=entitydef('PlayerSpawn',8,16)
 key=next(e for e in p['defs']['entities'] if e['identifier']=='Key')
 if not any(f['identifier']=='KeyId' for f in key['fieldDefs']):key['fieldDefs'].append(field('KeyId','LocalEnum.KeyId'))
 cage=entitydef('Cage',64,40,[field('Lock'+str(i+1),'LocalEnum.KeyId',n) for i,n in enumerate(['Red','Green','Blue','Gold'])])
 shortcut=entitydef('ShortcutDoor',32,40,[field('Key','EntityRef')]);shortcut['resizableX']=shortcut['resizableY']=True
 sf=shortcut['fieldDefs'][0];sf.update(allowedRefs='OnlySpecificEntity',allowedRefsEntityUid=key['uid'])
 sign=entitydef('PrisonSign',8,8,[field('Text','String','')])
 ents={d['identifier']:d for d in p['defs']['entities']}
 # Ensure old instances have the newly defined nullable KeyId field.
 for r in p['levels']:
  for l in r['layerInstances']:
   for e in l['entityInstances']:
    if e['__identifier']=='Key':
     f=key['fieldDefs'][-1]
     if not any(x['defUid']==f['uid'] for x in e['fieldInstances']):e['fieldInstances'].append(finst(f,None))
 origin=(13440,1152);rooms={};grids={};layers={};portals={n:[] for n in POSITIONS}
 ltemplate=copy.deepcopy(p['levels'][3]);insttemplate=copy.deepcopy(p['levels'][3]['layerInstances'][0])
 def put(n,x,y,w,h,v):
  W=POSITIONS[n][2];H=POSITIONS[n][3]
  for yy in range(max(0,y),min(H,y+h)):
   for xx in range(max(0,x),min(W,x+w)):grids[n][yy*W+xx]=v
 def entity(n,kind,x,y,values={},label=None,w=None,h=None):
  ed=ents[kind];W=w or ed['width'];H=h or ed['height'];ident=iid(n+'/'+(label or kind)+'/'+str(x)+'/'+str(y))
  e={'__smartColor':ed['color'],'__identifier':kind,'__grid':[int(x)//8,int(y)//8],'__pivot':[ed['pivotX'],ed['pivotY']],'__tags':ed['tags'],'__tile':ed['tileRect'],'__worldX':rooms[n]['worldX']+x,'__worldY':rooms[n]['worldY']+y,'defUid':ed['uid'],'iid':ident,'px':[x,y],'width':W,'height':H,'fieldInstances':[]}
  for f in ed['fieldDefs']:
   default=f.get('defaultOverride');v=values.get(f['identifier'],default['params'][0] if default else None);e['fieldInstances'].append(finst(f,v))
  layers[n]['Entities']['entityInstances'].append(e);return e
 for name,(gx,gy,W,H) in POSITIONS.items():
  r=copy.deepcopy(ltemplate);r.update(identifier=name,iid=iid(name),uid=uid(),worldX=origin[0]+gx*320,worldY=origin[1]+gy*192,pxWid=W*8,pxHei=H*8,__bgColor='#293D40',bgColor='#293D40',bgRelPath=None,__bgPos=None,__neighbours=[],fieldInstances=[finst(wf,'Hub' if name=='Prison_Hub' else COLORS[name[7]]),finst(hf,name=='Prison_Hub')],layerInstances=[])
  rooms[name]=r;layers[name]={};grids[name]=[0]*(W*H)
  for ld2 in p['defs']['layers']:
   li=copy.deepcopy(insttemplate);li.update(__identifier=ld2['identifier'],__type=ld2['type'],__cWid=W,__cHei=H,__gridSize=8,__tilesetDefUid=ld2['tilesetDefUid'],__tilesetRelPath=next((t['relPath'] for t in p['defs']['tilesets'] if t['uid']==ld2['tilesetDefUid']),None),iid=iid(name+'/'+ld2['identifier']),levelId=r['uid'],layerDefUid=ld2['uid'],intGridCsv=[0]*(W*H) if ld2['type']=='IntGrid' else [],gridTiles=[],autoLayerTiles=[],entityInstances=[],seed=1)
   r['layerInstances'].append(li);layers[name][ld2['identifier']]=li
  put(name,0,0,W,1,1);put(name,0,H-1,W,1,1);put(name,0,0,1,H,1);put(name,W-1,0,1,H,1)
  put(name,1,H-4,W-2,3,1)
 # Shared apertures: offset is along shared span; key gates on both mouth rooms.
 edges=[]
 def edge(a,b,offset,gate=''):
  ra,rb=rooms[a],rooms[b];ax,ay=ra['worldX'],ra['worldY'];bx,by=rb['worldX'],rb['worldY']
  horizontal=ax+ra['pxWid']==bx or bx+rb['pxWid']==ax
  if horizontal:
   start=max(ay,by)+offset*8
   for n,o,xx in [(a,b,POSITIONS[a][2]-1 if ax<bx else 0),(b,a,0 if ax<bx else POSITIONS[b][2]-1)]:
    yy=(start-rooms[n]['worldY'])//8;put(n,xx,yy,1,4,0);put(n,max(1,xx-4),yy+4,4,1,1);portals[n].append((o,'e' if xx else 'w',xx,yy,4,gate))
  else:
   start=max(ax,bx)+offset*8
   for n,o,yy in [(a,b,POSITIONS[a][3]-1 if ay<by else 0),(b,a,0 if ay<by else POSITIONS[b][3]-1)]:
    xx=(start-rooms[n]['worldX'])//8;put(n,xx,yy,5,1,0)
    if yy:put(n,xx,yy-3,5,3,0)
    portals[n].append((o,'s' if yy else 'n',xx,yy,5,gate))
  edges.append((a,b,gate))
 for w in COLORS:
  ns=[f'Prison_{w}{i:02}' for i in range(1,5)]
  edge('Prison_Hub',ns[0],16 if w in 'RY' else 10)
  edge(ns[0],ns[1],16 if w in 'RY' else 23 if w=='B' else 29)
  edge(ns[1],ns[2],9 if w=='R' else 29 if w=='Y' else 16)
  edge(ns[2],ns[3],16 if w in 'RY' else 10 if w=='B' else 29,COLORS[w])
  edge(ns[3],'Prison_Hub',16 if w in 'RY' else 10,COLORS[w])
 # Authored paths, one-way stairs allow jumping through supports rather than grab.
 for name in rooms:
  W,H=POSITIONS[name][2:]
  if name=='Prison_Hub':
   # Two legible stair towers connect all eight mouths. 48px decks,
   # 24px rises, no solid undersides to catch a jump. The cage has a bypass.
   for left in [10,50]:
    for j,row in enumerate(range(41,4,-3)):
     put(name,left+(6 if j%2==0 and row!=5 else 0),row,6,1,2)
    put(name,left,3,5,1,2)
   for row in [20,44]:
    put(name,1,row,9,1,2);put(name,62,row,17,1,2)
   put(name,4,41,6,1,2)
   put(name,22,41,7,1,2);put(name,29,38,22,1,2)
   put(name,25,20,25,1,2)
   spawn_xy=(288,346);entity(name,'Cage',336,332,dict(zip(['Lock1','Lock2','Lock3','Lock4'],['Red','Green','Blue','Gold'])));entity(name,'Jamshid',336,352);entity(name,'PrisonSign',320,292,{'Text':'FREE JAMSHID  /  FOUR KEYS'})
  else:
   wing=name[7];index=int(name[-2:]);spawn_xy=(48,154)
   # Every north mouth gets a complete staircase from the recovery floor.
   # The top deck is 24px down: enough headroom for a standing body and jump.
   for o,side,x,y,length,gate in portals[name]:
    if side=='n' and not (wing=='B' and index<4):
     for j,row in enumerate([17,14,11,8,5]):
      put(name,x+(0 if j%2==0 else (6 if x<20 else -6)),row,6,1,2)
     put(name,x,3,5,1,2)
   if index<4 and wing in 'RG':
    for x,gap in ([(19,3)] if index==1 else [(17,4),(28,4)] if index==2 else [(20,5 if wing=='R' else 6)]):
     put(name,x,20,gap,3,0)
     # Nonlethal recovery floor: every missed jump has a short way out.
    if wing=='R':
     for j,x in enumerate([224] if index==3 else [164] if index==1 else [144,240]):entity(name,'DarkThought',x,112,{'Motion':'Vertical','Amplitude':18.0,'Speed':1.0,'Phase':float(j)*3.14,'Glow':True})
    # Library challenge lives on the floor; keep transit stair headroom clear.
   if wing=='Y' and index<4:
    # Solid faces, 4-cell channel; two short bursts rather than a tall climb.
    put(name,18,14,2,4,1);put(name,23,13,2,7,1);put(name,20,15,3,1,2)
    put(name,25,14,3,1,2);put(name,28,17,5,1,2)
   if wing=='B' and index<4:
    # The floor supports dry entrances; below/along it lies the flooded route.
    put(name,7,12,29,11,4);put(name,7,23,29,1,1)
    # Baffles create alternating low/high swim passages.
    if index>1:put(name,18,12,2,6,1);put(name,26,19,2,4,1)
    for j in range(7):put(name,29+j,18-j,1,5+j,1)
    put(name,35,12,4,11,1)
    # Preserve seam apertures and submerged mouth pools after water painting.
    for o,side,x,y,length,gate in portals[name]:
     if side in ['w','e']:put(name,x,y,1,length,4);put(name,1 if side=='w' else 28,y,4 if side=='w' else 11,length,4)
     elif side=='s':put(name,x,y-3,length,4,4)
     else:
      # dry exit staircase to surface; no bank mantle required
      for j,row in enumerate([11,8,5]):put(name,x+(0 if j%2==0 else 6),row,6,1,2)
      put(name,x,3,5,1,2)
   if index==3:
    kx,ky=(296,90) if wing=='B' else (64,154) if wing=='Y' else (288,154)
    entity(name,'Key',kx,ky,{'KeyId':COLORS[wing]},label='key')
    entity(name,'Checkpoint',kx,ky,{'CheckpointID':'prison_'+wing+'_key'})
   entity(name,'PrisonSign',160,40,{'Text':({'R':'CAFETERIA','G':'LIBRARY','B':'FLOODED BASEMENT','Y':'GYM'}[wing] if index<4 else 'RETURN TO JAMSHID')+'  '+str(index)})
  if name=='Prison_Hub':
   for x,y,label in [(54,120,'< CAFETERIA'),(582,120,'GYM >'),(110,72,'LIBRARY ^'),(449,335,'BASEMENT v')]:entity(name,'PrisonSign',x,y,{'Text':label},label=label)
  entity(name,'PlayerSpawn',*spawn_xy);entity(name,'Checkpoint',*spawn_xy,{'CheckpointID':name+'_entry'})
 # Re-open the authored seams after challenge painting; a hazard must never seal a route.
 for n,ps in portals.items():
  for o,side,x,y,length,gate in ps:
   if side in ['w','e']:put(n,x,y,1,length,4 if n[7:8]=='B' and n[-2:] in ['01','02','03'] else 0)
   else:
    wet=side=='s' and n[7:8]=='B' and n[-2:] in ['01','02','03']
    put(n,x,y-3 if side=='s' else y,length,4 if side=='s' else 1,4 if wet else 0)
    # A locked bottom mouth is a shallow pocket, never a one-way trap.
    if side=='s' and not wet:put(n,x+1,y-1,2,1,2)
 # Shortcut EntityRefs are real cross-level refs to the authored Key instance.
 key_entities={}
 for w in COLORS:
  n=f'Prison_{w}03';key_entities[COLORS[w]]=next(e for e in layers[n]['Entities']['entityInstances'] if e['__identifier']=='Key')
 for a,b,gate in edges:
  if not gate:continue
  # One physical shutter per gated edge, in return room; two shutters per wing.
  n=a if a.endswith('04') else b
  o,side,x,y,length,_=next(v for v in portals[n] if v[0]==(b if n==a else a))
  k=key_entities[gate];ref={'entityIid':k['iid'],'layerIid':layers[next(q for q in rooms if q.endswith('03') and COLORS.get(q[7])==gate)]['Entities']['iid'],'levelIid':iid(next(q for q in rooms if q.endswith('03') and COLORS.get(q[7])==gate)),'worldIid':p['dummyWorldIid']}
  entity(n,'ShortcutDoor',x*8+(4 if side in 'we' else 20),y*8+(16 if side in 'we' else 4),{'Key':ref},w=8 if side in 'we' else 40,h=32 if side in 'we' else 8)
 def tile(i,x,y,rule_uid=None):return {'px':[x*8,y*8],'src':[(i%16)*8,(i//16)*8],'f':0,'t':i,'a':1,'d':[x+y*POSITIONS[name][2]] if rule_uid is None else [rule_uid,x+y*POSITIONS[name][2]]}
 for name,r in rooms.items():
  W,H=POSITIONS[name][2:];grid=grids[name];layers[name]['Collision']['intGridCsv']=grid
  for y in range(H):
   for x in range(W):
    v=grid[y*W+x]
    if v:
     above=grid[(y-1)*W+x] if y else 0;t={1:0,2:5,3:6,4:7}[v]
     if v in (1,4) and above!=v:t=1 if v==1 else 8
     rule=next(rule for rule in rules if rule['tileRectsIds']==[[t]])
     layers[name]['Tiles']['autoLayerTiles'].append(tile(t,x,y,rule['uid']))
    # Warm plaster backdrop, turquoise wainscot and high barred windows.
    layers[name]['Decor']['gridTiles'].append(tile(16,x,y))
  # Place readable school props from atlas selections (never collision).
  dress=[(5,H-7,0,2,3),(W-7,H-7,16,3,3),(W//2-2,6,40,4,2)]
  if name[7:8]=='R':dress=[(5,H-7,0,2,3),(W-10,H-6,72,3,2),(W//2-2,6,40,4,2)]
  if name[7:8]=='B':dress=[(5,H-7,0,2,3),(W//2-2,6,40,4,2)]
  if name[7:8]=='Y':dress=[(5,H-7,0,2,3),(W-6,H-7,0,2,3),(W//2-2,6,40,4,2)]
  for px,py,src,w,h in dress:
   for yy in range(h):
    for xx in range(w):layers[name]['Decor']['gridTiles'].append(tile((32//8+yy)*16+src//8+xx,px+xx,py+yy))
  r['__neighbours']=[{'levelIid':rooms[o]['iid'],'dir':side} for o,side,*_ in portals[name]]
  p['levels'].append(r)
 # Link existing Act 2 exit explicitly; no prison name can enter legacy sort order.
 last=next(r for r in p['levels'] if r['identifier']=='Act_2_Level_13')
 for l in last['layerInstances']:
  for e in l['entityInstances']:
   if e['__identifier']=='Exit':
    for f in e['fieldInstances']:
     if f['__identifier']=='NextRoom':f['__value']='Prison_Hub';f['realEditorValues']=[{'id':'V_String','params':['Prison_Hub']}]
 
 for e in p['defs']['entities']:
  for f in e['fieldDefs']:
   if f['__type']=='LocalEnum.KeyId':f['type']=f"F_Enum({next(v['uid'] for v in p['defs']['enums'] if v['identifier']=='KeyId')})"
 p.update(nextUid=counter+1,worldGridWidth=320,worldGridHeight=192)
 # All layers exist in older rooms too, so LDtk can open without rebuilding a missing layer.
 for r in p['levels']:
  if r['identifier'].startswith('Prison_'):continue
  for ld2 in [tiles,decor]:
   if any(l['layerDefUid']==ld2['uid'] for l in r['layerInstances']):continue
   li=copy.deepcopy(insttemplate);li.update(__identifier=ld2['identifier'],__type=ld2['type'],__cWid=r['pxWid']//8,__cHei=r['pxHei']//8,__tilesetDefUid=ts['uid'],__tilesetRelPath=ts['relPath'],iid=iid(r['iid']+'/'+ld2['identifier']),levelId=r['uid'],layerDefUid=ld2['uid'],intGridCsv=[],gridTiles=[],autoLayerTiles=[],entityInstances=[]);r['layerInstances'].append(li)
  r['layerInstances'].sort(key=lambda l:next(i for i,d in enumerate(p['defs']['layers']) if d['uid']==l['layerDefUid']))
 import jsonschema
 schema=json.loads((ROOT/'tools/ldtk_1_5_3.schema.json').read_text());jsonschema.validate(p,schema)
 backup=ROOT/'output/prison_build/backups'/datetime.datetime.now().strftime('%Y%m%d_%H%M%S');backup.mkdir(parents=True,exist_ok=True);(backup/PATH.name).write_text(json.dumps(original))
 PATH.write_text(json.dumps(p,indent='\t')+'\n')
 print(f'Wrote {len(rooms)} prison rooms, {len(edges)} adjacency edges; official schema valid. Backup: {backup}')
if __name__=='__main__':
 parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('--rebuild',action='store_true');args=parser.parse_args();build(args.rebuild)
