"""Six authored spring/carpet rooms. Existing rooms retain their terrain.
Run with Act 2 closed in LDtk. Uses the project's existing source-derived art.
"""
import copy,json,uuid
from pathlib import Path
from act2_grass_terrain import rebake_layer
from ldtk_preserve_json import update
ROOT=Path(__file__).resolve().parents[1]
PATH=ROOT/'ldtk/hooshang_act2.ldtk'
NS=uuid.UUID('147c257a-86d5-4dab-a7b7-d8ab39629111')
def ident(s): return str(uuid.uuid5(NS,s))
def main():
 p=json.loads(PATH.read_text()); backup=ROOT/'output/act2_expansion/before.ldtk'
 if not backup.exists():backup.write_text(PATH.read_text())
 (backup.parent/'.gdignore').touch()
 defs={e['identifier']:e for e in p['defs']['entities']}
 if not any(f['identifier']=='Facing' for f in defs['SpringPlatform']['fieldDefs']):
  enum=copy.deepcopy(p['defs']['enums'][0]);enum.update(identifier='SpringFacing',uid=p['nextUid'],values=[dict(id=v,tileRect=None,color=None) for v in ['Up','Right','Left']]);p['nextUid']+=1;p['defs']['enums'].append(enum)
  field=copy.deepcopy(defs['MagicCarpet']['fieldDefs'][0]);field.update(identifier='Facing',uid=p['nextUid'],__type='LocalEnum.SpringFacing',type=f"F_Enum({enum['uid']})",defaultOverride={'id':'V_String','params':['Up']},doc='Up, or rotate the spring 90 degrees to launch Right/Left.');p['nextUid']+=1
  defs['SpringPlatform']['fieldDefs'].append(field)
 ld=next(l for l in p['defs']['layers'] if l['identifier']=='Collisions')
 rules=[r for g in ld['autoRuleGroups'] if g['active'] for r in g['rules'] if r['active']]
 groups={v['value']:v['groupUid'] for v in ld['intGridValues']}
 recipes=[]
 def entity(room,name,x,y,w=None,h=None,**fields):
  d=defs[name];w=w or d['width'];h=h or d['height'];pivot=[d['pivotX'],d['pivotY']]
  # x/y are physical centres, except zero-pivot markers/exits which use top-left.
  px=[round(x),round(y)]
  es=next(a for a in room['layerInstances'] if a['__identifier']=='Entities')['entityInstances']
  fi=[]
  for f in d['fieldDefs']:
   value=fields.get(f['identifier'])
   if value is None and f.get('defaultOverride'):value=f['defaultOverride']['params'][0]
   fi.append(dict(__identifier=f['identifier'],__type=f['__type'],__value=value,__tile=None,defUid=f['uid'],realEditorValues=[]))
  es.append(dict(__identifier=name,__grid=[px[0]//8,px[1]//8],__pivot=pivot,__tags=d['tags'],__tile=d['tileRect'],__smartColor=d['color'],iid=ident(room['identifier']+name+str(len(es))),width=w,height=h,defUid=d['uid'],px=px,fieldInstances=fi,__worldX=room['worldX']+px[0],__worldY=room['worldY']+px[1]))
 def rect(room,x,y,w,h):
  li=room['layerInstances'][0];cw=li['__cWid']
  for yy in range(y//8,(y+h)//8):
   for xx in range(x//8,(x+w)//8):li['intGridCsv'][yy*cw+xx]=10
 def spring(room,x,y):entity(room,'SpringPlatform',x,y-4)
 def carpet(room,x,y,kind='Ride',amp=0,width=48):entity(room,'MagicCarpet',x,y+4,width,8,CarpetPattern="Ride",CarpetColor={"Bob":"Teal","Sweep":"Violet","Bounce":"Amber"}.get(kind,"Crimson"),Speed=32.0)
 def lemon(room,x,y):entity(room,'Lemon',x,y)
 names=['Saffron Steps','The Flying Courtyard','Orchard of Detours','Silk in the Wind','The Sky Garden','Garden of Kings']
 for n in range(3,9):
  room=copy.deepcopy(p['levels'][0]);name=f'Act_2_Level_{n}'
  width=768 if n==7 else 640
  room.update(identifier=name,iid=ident(name),uid=next((r['uid'] for r in p['levels'] if r['identifier']==name),p['nextUid']+n),worldX=3160+(n-3)*640+(128 if n>=8 else 0),worldY=488,pxWid=width,pxHei=320,__neighbours=[],bgRelPath=None,__bgPos=None,fieldInstances=[])
  for a in room['layerInstances']:
   a.update(iid=ident(name+a['__identifier']),levelId=room['uid'],__cWid=width//8,__cHei=40,entityInstances=[],autoLayerTiles=[],gridTiles=[],seed=n)
   a['intGridCsv']=[0]*(width//8*40) if a['__type']=='IntGrid' else []
  entity(room,'PlayerStart',24,272)
  # A continuous catch-floor turns a missed transfer into recovery.
  rect(room,0,288,width,32)
  ledges=[];springs=[];carpets=[];side_springs=[]
  def ledge(x,y,w):rect(room,x,y,w,16);ledges.append([x,y,w])
  def sp(x,y):spring(room,x,y);springs.append([x,y])
  def side(x,y,facing):
   entity(room,'SpringPlatform',x,y,Facing=facing);side_springs.append([x,y,facing])
  def cp(x,y,k='Ride',a=104,w=48):carpet(room,x,y,k,a,w);carpets.append([x,y,k,a,w])
  routes=[];gates=[]
  def bounce(x,y,tx,ty):routes.append(dict(kind='spring',start=[x,y],target=[tx,ty]))
  def flight(x,start,waypoints,target,jump_x):
   routes.append(dict(kind='flight',carpet=x,start=start,waypoints=waypoints,target=target,jump_x=jump_x))
  def side_route(start,target):routes.append(dict(kind='side',start=start,target=target))
  def thought(x,y,amplitude=0,speed=0.25,phase=0):
   entity(room,'LightThought',x,y,Motion='Vertical',Amplitude=float(amplitude),Speed=float(speed),Phase=float(phase),ChildhoodPalette=1.0)
  def gate(x,lane,gap=40,motion=0):
   gates.append([x,lane])
   for gy in range(16,273,24):
    if abs(gy-(lane-6))>gap:thought(x,gy,motion)
  def checkpoint(x,y):entity(room,'Checkpoint',x,y-8,CheckpointID=name+'_rest')
  # All rugs retain landing activation, steady right travel and up/down steering.
  sp(80,288);ledge(112,240,48);bounce(80,288,128,240)
  if n==3:
   # The first flight is short and harmless. Two spring stairs then turn the
   # learned air steering into an upbeat finish, with a high optional lemon.
   cp(192,240,w=56)
   ledge(392,192,64);sp(440,192)
   ledge(472,144,56);sp(512,144);ledge(544,96,96)
   flight(192,[144,240],[[280,208],[336,184]],[408,192],364)
   bounce(440,192,488,144);bounce(512,144,560,96)
   lemon(room,288,164);lemon(room,536,86)
   end_y=96
  elif n==4:
   # Duck beneath the hanging garden, climb to an island, then spring onto
   # a second waiting vehicle. The island is both a rest and a checkpoint.
   cp(192,240)
   ledge(248,144,72);ledge(360,184,72);checkpoint(376,184)
   sp(416,184);cp(464,136,w=48)
   gate(536,112,40)
   ledge(584,104,56)
   flight(192,[144,240],[[280,224],[328,176]],[376,184],332)
   bounce(416,184,464,136)
   flight(464,None,[[536,112]],[600,104],556)
   lemon(room,280,206);lemon(room,512,100)
   end_y=104
  elif n==5:
   # Read the central island before committing: the roomy low tunnel and
   # the exposed high route reunite at the same landing. The upper lemon
   # balcony asks for a jump off the rug, then a controlled drop back.
   sp(152,240);ledge(184,192,72);bounce(152,240,200,192)
   cp(288,192)
   ledge(360,160,96);rect(room,360,176,96,32)
   ledge(400,80,48)
   ledge(552,224,88)
   thought(344,72,8,0.22);thought(464,264)
   flight(288,[244,192],[[336,232],[480,232]],[576,224],524)
   # An independently verified second solution, not a cosmetic dead end.
   routes.append(dict(kind='alternate',carpet=288,start=[244,192],waypoints=[[344,112],[488,112]],target=[576,224],jump_x=524))
   lemon(room,416,62);lemon(room,408,236);lemon(room,496,112)
   end_y=224
  elif n==6:
   # Spring staircase -> horizontal spring shot -> low parked carpet.
   # A gently moving gate adds timing, then a low exit gives breathing room.
   sp(152,240);ledge(184,192,120);bounce(152,240,200,192)
   side(232,180,'Right');cp(336,232,w=56)
   gate(424,176,40,10);gate(496,216,32)
   ledge(552,224,88);checkpoint(280,192)
   side_route([264,192],[336,232])
   flight(336,None,[[424,176],[496,216]],[576,224],524)
   lemon(room,360,180);lemon(room,480,206)
   end_y=224
  elif n==7:
   # Final remix: launch directly onto rug one, thread a tighter aperture,
   # rest, bounce to the upper terrace, side-launch onto rug two, and climb.
   sp(152,240);cp(200,192,w=48);bounce(152,240,200,192)
   gate(288,152,28)
   ledge(360,152,64);checkpoint(384,152);sp(408,152)
   ledge(440,104,72);side(456,92,'Right');cp(544,144,w=40)
   flight(200,None,[[288,152]],[376,152],332)
   bounce(408,152,456,104)
   side_route([488,104],[544,144])
   gate(616,120,28);ledge(680,96,88)
   flight(544,None,[[616,120]],[704,96],652)
   lemon(room,264,128);lemon(room,576,100);lemon(room,712,72)
   end_y=96
  else:
   # A calm coda after the precision finale: room to enjoy Pasargadae,
   # a short flight, and one last spring to the garden's final terrace.
   sp(152,240);ledge(184,192,72);bounce(152,240,200,192)
   cp(288,192,w=56);ledge(472,144,88);checkpoint(496,144)
   flight(288,[244,192],[[376,160],[416,136]],[488,144],444)
   sp(536,144);ledge(568,96,72);bounce(536,144,584,96)
   lemon(room,368,124);lemon(room,600,70)
   end_y=96
  exit_x=width-24
  if n>=7:entity(room,'Checkpoint',width-48,end_y-8,CheckpointID=name+'_summit')
  entity(room,'Exit',exit_x,end_y-32,NextRoom=f'Act_2_Level_{n+1}' if n<8 else '')
  # Checkpoint at the start ensures debug starts and retries are identical.
  entity(room,'Checkpoint',48,280,CheckpointID=name+'_start')
  rebake_layer(room['layerInstances'][0],rules,groups)
  p['levels']=[r for r in p['levels'] if r['identifier']!=name];p['levels'].append(room)
  recipes.append(dict(name=name,title=names[n-3],width=width,ledges=ledges,springs=springs,carpets=carpets,side_springs=side_springs,exit=[exit_x,end_y],gates=gates,routes=routes))
 # Minimal progression repair on the existing unfinished rooms, no terrain erased.
 old1=p['levels'][1];es=next(a for a in old1['layerInstances'] if a['__identifier']=='Entities')['entityInstances']
 if not any(e['__identifier']=='Exit' for e in es):entity(old1,'Exit',816,248,NextRoom='Level_2')
 old2=next(r for r in p['levels'] if r['identifier'] in ('Level_2','Act_2_Level_2'))
 es=next(a for a in old2['layerInstances'] if a['__identifier']=='Entities')['entityInstances']
 if not any(e['__identifier']=='PlayerStart' for e in es):entity(old2,'PlayerStart',24,568)
 if not any(e['__identifier']=='Exit' for e in es):
  rect(old2,288,352,80,16);entity(old2,'Exit',344,320,NextRoom='Act_2_Level_3');rebake_layer(old2['layerInstances'][0],rules,groups)
 p['nextUid']=max(p['nextUid'],max(r['uid'] for r in p['levels'])+1)
 PATH.write_text(update(PATH.read_text(),p))
 (ROOT/'resources/levels/act2_expansion.json').write_text(json.dumps(recipes,indent=2)+'\n')
 print('Built six rooms, linked from existing Act 2, using grass terrain and existing polished props.')
if __name__=='__main__':main()
