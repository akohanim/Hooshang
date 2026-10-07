"""Eleven original precision-puzzle rooms after World 2 Level 2. Earlier rooms are preserved.
Run with Act 2 closed in LDtk. Uses the project's existing source-derived art.
"""
import copy,json,uuid
from pathlib import Path
from act2_grass_terrain import rebake_layer
from ldtk_preserve_json import update
from act2_ink_hazards import install as install_ink, replace_spikes
ROOT=Path(__file__).resolve().parents[1]
PATH=ROOT/'ldtk/hooshang_act2.ldtk'
NS=uuid.UUID('147c257a-86d5-4dab-a7b7-d8ab39629111')
def ident(s): return str(uuid.uuid5(NS,s))
def main():
 p=json.loads(PATH.read_text()); ink_definition,_=install_ink(p); earlier=copy.deepcopy(p['levels'][:3]); backup=ROOT/'output/act2_expansion/before.ldtk'
 backup.parent.mkdir(parents=True,exist_ok=True)
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
 def carpet(room,x,y,kind='Ride',amp=0,width=48,speed=32):entity(room,'MagicCarpet',x,y+4,width,8,CarpetPattern="Ride",CarpetColor={"Bob":"Teal","Sweep":"Violet","Bounce":"Amber"}.get(kind,"Crimson"),Speed=float(speed))
 def lemon(room,x,y):entity(room,'Lemon',x,y)
 names=['Saffron Steps','The Spring Courtyard','Orchard of Choices','Silk in the Wind','The Sky Garden','Garden of Kings','Apex Relay','Needlewind Passage','The Turning Stair','Under the Thorns','Crown of the Wind']
 world_x=3160
 for n in range(3,14):
  room=copy.deepcopy(p['levels'][0]);name=f'Act_2_Level_{n}'
  width={7:768,9:880,10:1120,11:800,12:928,13:1448}.get(n,640)
  room.update(identifier=name,iid=ident(name),uid=next((r['uid'] for r in p['levels'] if r['identifier']==name),p['nextUid']+n),worldX=world_x,worldY=488,pxWid=width,pxHei=320,__neighbours=[],bgRelPath=None,__bgPos=None,fieldInstances=[])
  for a in room['layerInstances']:
   a.update(iid=ident(name+a['__identifier']),levelId=room['uid'],__cWid=width//8,__cHei=40,entityInstances=[],autoLayerTiles=[],gridTiles=[],seed=n)
   a['intGridCsv']=[0]*(width//8*40) if a['__type']=='IntGrid' else []
  entity(room,'PlayerStart',24,272)
  ledges=[];springs=[];carpets=[];side_springs=[]
  def ledge(x,y,w):rect(room,x,y,w,16);ledges.append([x,y,w])
  def sp(x,y):spring(room,x,y);springs.append([x,y])
  def side(x,y,facing):
   entity(room,'SpringPlatform',x,y,Facing=facing);side_springs.append([x,y,facing])
  def cp(x,y,k='Ride',a=104,w=48,speed=32):carpet(room,x,y,k,a,w,speed);carpets.append([x,y,k,a,w])
  routes=[];gates=[]
  def bounce(x,y,tx,ty):routes.append(dict(kind='spring',start=[x,y],target=[tx,ty]))
  def flight(x,start,waypoints,target,jump_x):
   routes.append(dict(kind='flight',carpet=x,start=start,waypoints=waypoints,target=target,jump_x=jump_x))
  def spring_dash(x,y,tx,ty):routes.append(dict(kind='spring_dash',start=[x,y],target=[tx,ty],dash_frame=18))
  def side_route(start,target):routes.append(dict(kind='side',start=start,target=target))
  def thought(x,y,amplitude=0,speed=0.25,phase=0):
   entity(room,'LightThought',x,y,Motion='Vertical',Amplitude=float(amplitude),Speed=float(speed),Phase=float(phase),ChildhoodPalette=1.0)
  def gate(x,lane,gap=40,motion=0):
   gates.append([x,lane])
   for gy in range(16,273,24):
    if abs(gy-(lane-6))>gap:thought(x,gy,motion)
  def checkpoint(x,y):entity(room,'Checkpoint',x,y-8,CheckpointID=name+'_rest')
  def weave(x,start,islands,target,jump_x,speed):
   # 16px upper passage admits the 12px player, but not rider + 8px rug.
   # The lower passage admits the empty rug; its spike floor excludes a rider.
   for bx,w,lane in islands:
    left=bx-64;right=bx+w+64
    rect(room,left,0,right-left,lane-40)
    rect(room,bx,lane-24,w,24);ledges.append([bx,lane-24,w])
    rect(room,left,lane+16,right-left,312-(lane+16))
    thorns(left,lane+8,right-left)
   routes.append(dict(kind='weave',carpet=x,start=start,islands=islands,target=target,jump_x=jump_x,speed=speed))
  # Each room has one readable movement idea, a rest before its harder remix,
  # and an optional lemon line. Targets are real safe landing surfaces.
  def jump(start,target,dash=False):
   routes.append(dict(kind='dash' if dash else 'jump',start=start,target=target))
  def crumble(x,y,w=40):
   entity(room,'CrumblingPlatform',x+w/2,y+4,w,8)
   crumbles.append([x,y,w])
  def thorns(x,y,w):entity(room,'ConeSpikes',x+w/2,y+4,w,8,ChildhoodPalette=1.0)
  crumbles=[];optional=[]
  # Later failures reset at the last resting island, not at a long catch-floor.
  rect(room,0,288,176 if n==3 else 104,32)
  if n!=8:
   rect(room,176 if n==3 else 104,312,width-(176 if n==3 else 104),8)
   thorns(176 if n==3 else 104,304,width-(176 if n==3 else 104)-80)
  else:rect(room,0,288,width,32)
  if n==3:
   # See the landing, jump; then repeat across a gap that asks for a dash.
   ledge(128,264,48);ledge(216,248,48);ledge(304,248,56)
   ledge(408,216,48);ledge(504,216,48);ledge(592,192,48)
   jump([88,288],[144,264]);routes[-1]["jump_hold"]=60;jump([160,264],[232,248],True)
   jump([248,248],[320,248],True);checkpoint(328,248)
   jump([344,248],[424,216],True);jump([440,216],[520,216],True)
   jump([536,216],[608,192],True)
   lemon(room,264,208);lemon(room,472,176)
   end_y=192
  elif n==4:
   # Springs teach steering toward a visible ledge before a mixed landing chain.
   sp(80,288);ledge(112,240,56);sp(152,240)
   ledge(184,192,80);checkpoint(208,192);sp(240,192)
   ledge(280,144,64);crumble(392,152,56)
   ledge(480,128,48);ledge(568,176,72)
   bounce(80,288,128,240);bounce(152,240,200,192);bounce(240,192,296,144)
   jump([328,144],[416,152],True);jump([432,152],[496,128],True)
   jump([512,128],[592,176],True)
   lemon(room,176,164);lemon(room,448,96)
   end_y=176
  elif n==5:
   # Low route: commit across crumbling stones. High route: a spring detour
   # with a bonus lemon; both converge at the checkpoint terrace.
   sp(80,288);ledge(112,240,56);sp(152,240)
   crumble(200,264,48);crumble(280,248,48);crumble(360,248,48)
   ledge(424,224,56);ledge(520,200,48);ledge(584,200,56)
   ledge(184,192,64);ledge(280,176,48);ledge(360,192,48)
   bounce(80,288,128,240)
   jump([128,240],[216,264],True);jump([216,264],[296,248],True)
   jump([296,248],[376,248],True);jump([376,248],[440,224],True)
   checkpoint(448,224);jump([464,224],[536,200],True);jump([552,200],[600,200])
   optional=[dict(kind='spring',start=[152,240],target=[200,192]),
    dict(kind='dash',start=[232,192],target=[296,176]),
    dict(kind='dash',start=[312,176],target=[376,192]),
    dict(kind='jump',start=[392,192],target=[448,224])]
   lemon(room,296,158);lemon(room,340,210)
   end_y=200
  elif n==6:
   # Two short carpet puzzles with a checkpoint between them. Changing lane
   # is the problem; the rug always travels right at its familiar steady speed.
   sp(80,288);ledge(112,240,48);cp(192,240,w=48)
   ledge(248,144,72);ledge(360,184,72);checkpoint(376,184)
   sp(416,184);cp(464,136,w=48)
   gate(280,224,32);gate(536,112,28)
   ledge(584,104,56)
   bounce(80,288,128,240)
   flight(192,[144,240],[[280,224],[328,176]],[376,184],332)
   bounce(416,184,464,136)
   flight(464,None,[[536,112]],[600,104],556)
   lemon(room,280,206);lemon(room,512,92)
   end_y=104
  elif n==7:
   # Exam: launch, precise dash, crumbling departure, rest; then flight and
   # two final landings. Each rest gives the next screen its own retry point.
   sp(80,288);ledge(112,240,56);crumble(208,216,48)
   ledge(288,216,72);checkpoint(304,216);sp(336,216)
   ledge(376,168,64);cp(480,168,w=40);gate(552,136,28)
   ledge(616,144,48);checkpoint(632,144)
   crumble(680,128,32);ledge(712,104,56)
   bounce(80,288,128,240)
   jump([152,240],[224,216],True);jump([240,216],[304,216],True)
   bounce(336,216,392,168)
   flight(480,[424,168],[[552,136]],[632,144],588)
   jump([648,144],[696,128],True);jump([696,128],[752,104],True)
   lemon(room,272,184);lemon(room,568,108);lemon(room,720,88)
   end_y=104
  elif n==8:
   # Release after the exam: forgiving spring flight and a final garden stroll.
   sp(80,288);ledge(112,240,56);cp(208,240,w=56)
   ledge(352,160,104);checkpoint(400,160)
   ledge(472,168,80);ledge(568,168,72)
   bounce(80,288,128,240)
   flight(208,[152,240],[[288,176],[336,184]],[376,160],332)
   jump([448,160],[488,168]);jump([528,168],[592,168],True)
   lemon(room,304,132);lemon(room,600,142)
   end_y=168
  elif n==9:
   # Spring apex becomes the launch point for a dash: no safe pad in between.
   sp(80,288);crumble(144,216,40);crumble(224,200,40);crumble(304,216,40)
   ledge(392,192,64);checkpoint(416,192);sp(440,192)
   spring_dash(80,288,160,216)
   jump([160,216],[240,200],True);jump([240,200],[320,216],True)
   jump([320,216],[408,192],True);routes[-1]["dash_up"]=True
   crumble(504,128,48);crumble(592,144,40);ledge(672,128,40)
   ledge(760,160,40);ledge(832,160,48)
   spring_dash(440,192,520,128)
   jump([520,128],[608,144],True);jump([608,144],[688,128],True)
   jump([696,128],[776,160],True);jump([784,160],[856,160],True)
   lemon(room,264,160);lemon(room,632,100);end_y=160
  elif n==10:
   # Three mandatory departures and catches of one faster, narrow carpet.
   sp(80,288);ledge(112,240,56);cp(200,217,w=24,speed=48)
   bounce(80,288,128,240)
   weave(200,[152,240],[[272,40,216],[456,56,216],[672,40,216]],[840,192],792,48)
   ledge(824,192,64);checkpoint(848,192);sp(872,192)
   spring_dash(872,192,952,120);ledge(936,120,40)
   crumble(1024,136,32);ledge(1056,120,64)
   jump([952,120],[1040,136],True);jump([1040,136],[1096,120],True)
   lemon(room,384,184);lemon(room,608,184);end_y=120
  elif n==11:
   # Reversing ascent, then a descending chain; all tops reached in flight.
   sp(80,288);ledge(144,216,48);ledge(72,160,32)
   ledge(152,112,80);checkpoint(200,112)
   spring_dash(80,288,160,216);jump([160,216],[88,160],True);routes[-1]["dash_frame"]=18
   jump([88,160],[168,112],True);routes[-1]["dash_frame"]=18
   crumble(280,136,40);crumble(360,160,40);ledge(440,184,64)
   jump([216,112],[296,136],True);jump([296,136],[376,160],True)
   jump([376,160],[456,184],True);checkpoint(472,184);sp(488,184)
   crumble(552,112,40);crumble(632,136,40);ledge(720,112,80)
   spring_dash(488,184,568,112);jump([568,112],[648,136],True)
   jump([648,136],[736,112],True);routes[-1]["dash_up"]=True
   lemon(room,88,124);lemon(room,336,96);end_y=112
  elif n==12:
   # The ceiling forbids a high bailout. Commit to low, timed departures.
   sp(80,288);ledge(112,240,56)
   crumble(208,240,40);crumble(288,224,40);crumble(368,240,40)
   rect(room,184,160,240,16)
   entity(room,'ConeSpikesCeiling',304,180,240,8,ChildhoodPalette=1.0)
   thorns(184,152,240)  # Prevent bypassing the constrained route over its roof.
   ledge(448,216,72);checkpoint(472,216);sp(504,216)
   bounce(80,288,128,240)
   jump([152,240],[224,240],True);jump([224,240],[304,224],True)
   jump([304,224],[384,240],True);routes[-1]["jump_hold"]=6
   jump([384,240],[464,216],True)
   ledge(568,144,40);crumble(664,160,40);ledge(744,144,40)
   crumble(816,160,32);ledge(864,176,64)
   spring_dash(504,216,584,144)
   jump([584,144],[680,160],True);jump([680,160],[760,144],True)
   jump([760,144],[832,160],True);jump([832,160],[904,176],True)
   lemon(room,264,208);lemon(room,720,104);end_y=176
  elif n==13:
   # Repeated separation at changing heights, then a committed crumble finish.
   sp(80,288);crumble(144,216,40);crumble(224,200,40)
   ledge(304,216,72);checkpoint(336,216)
   spring_dash(80,288,160,216)
   jump([160,216],[240,200],True);jump([240,200],[320,216],True)
   cp(408,217,w=24,speed=56)
   weave(408,[360,216],[[480,40,216],[680,56,192],[904,40,216]],[1072,192],1024,56)
   ledge(1056,192,72);checkpoint(1080,192);sp(1112,192)
   spring_dash(1112,192,1192,120);crumble(1176,120,40)
   crumble(1256,136,40);crumble(1336,120,40);ledge(1400,144,48)
   jump([1192,120],[1272,136],True);jump([1272,136],[1352,120],True)
   jump([1352,120],[1424,144],True)
   lemon(room,200,160);lemon(room,616,168);lemon(room,840,192);end_y=144
  world_x+=width
  exit_x=width-24
  if n>=7:entity(room,'Checkpoint',width-32,end_y-8,CheckpointID=name+'_summit')
  entity(room,'Exit',exit_x,end_y-32,NextRoom=f'Act_2_Level_{n+1}' if n<13 else '')
  # Checkpoint at the start ensures debug starts and retries are identical.
  entity(room,'Checkpoint',48,280,CheckpointID=name+'_start')
  replace_spikes(room,ink_definition)
  rebake_layer(room['layerInstances'][0],rules,groups)
  p['levels']=[r for r in p['levels'] if r['identifier']!=name];p['levels'].append(room)
  recipes.append(dict(name=name,title=names[n-3],width=width,ledges=ledges,springs=springs,carpets=carpets,side_springs=side_springs,exit=[exit_x,end_y],gates=gates,routes=routes,crumbles=crumbles,optional_routes=optional,final=n==13,advanced=n>=9))
 assert p['levels'][:3]==earlier, 'World 2 levels 0-2 must remain untouched'
 p['nextUid']=max(p['nextUid'],max(r['uid'] for r in p['levels'])+1)
 PATH.write_text(update(PATH.read_text(),p))
 (ROOT/'resources/levels/act2_expansion.json').write_text(json.dumps(recipes,indent=2)+'\n')
 print('Built World 2 levels 3-13, including five advanced challenge rooms.')
if __name__=='__main__':main()
