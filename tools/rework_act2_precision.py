#!/usr/bin/env python3
"""Act 2 precision redesign. Explicit room geometry, never a random generator.
Apply only with both editors closed. A separate immutable snapshot preserves the
user's starting source. Subsequent iterations use that snapshot, so do not rerun
this recipe after manual LDtk edits without merging them first.
"""
import copy,hashlib,json,subprocess,uuid
from pathlib import Path
from ldtk_preserve_json import update
from clear_castle_interiors import apertures
ROOT=Path(__file__).resolve().parents[1]
PATH=ROOT/'ldtk/hooshang_act2.ldtk'
OUT=ROOT/'output/act2_redesign'
NS=uuid.UUID('bc788501-e6ee-4a18-93bb-e511c546347d')

def main():
 stamp=OUT/'recipe_source.sha256'
 if stamp.exists():
  assert hashlib.sha256(PATH.read_bytes()).hexdigest()==stamp.read_text().strip(),'LDtk changed since this recipe last ran. Merge hand edits before rebuilding.'
 processes=subprocess.check_output(['ps','ax','-o','command'],text=True)
 assert not any(line.split() and line.split()[0].endswith('/MacOS/Godot') and '--editor' in line for line in processes.splitlines()),'Close Godot editor normally first'
 assert 'LDtk.app/Contents/MacOS/LDtk' not in processes,'Close LDtk first'
 raw=(OUT/'before.ldtk').read_text();project=json.loads(raw);before=copy.deepcopy(project)
 rooms={r['identifier']:r for r in project['levels']};defs={d['identifier']:d for d in project['defs']['layers']}
 edefs={d['identifier']:d for d in project['defs']['entities']}
 recipes=[]
 def entity(r,kind,x,y,w=None,h=None,**fields):
  d=edefs[kind];es=next(l for l in r['layerInstances'] if l['__identifier']=='Entities')['entityInstances'];fi=[]
  for f in d['fieldDefs']:
   v=fields.get(f['identifier']);default=f.get('defaultOverride')
   if v is None and default:v=default['params'][0]
   typ={'Float':'V_Float','Int':'V_Int','Bool':'V_Bool'}.get(f['__type'],'V_String')
   fi.append(dict(__identifier=f['identifier'],__type=f['__type'],__value=v,__tile=None,defUid=f['uid'],realEditorValues=[] if v is None else [dict(id=typ,params=[v])]))
  es.append(dict(__identifier=kind,__grid=[x//8,y//8],__pivot=[d['pivotX'],d['pivotY']],__tags=d['tags'],__tile=d['tileRect'],__smartColor=d['color'],iid=str(uuid.uuid5(NS,r['identifier']+kind+str(x)+','+str(y))),width=w or d['width'],height=h or d['height'],defUid=d['uid'],px=[x,y],fieldInstances=fi,__worldX=r['worldX']+x,__worldY=r['worldY']+y))
 def castle(name,title,idea):
  r=rooms[name];ls={l['__identifier']:l for l in r['layerInstances']};grid=ls['Collision']['intGridCsv'];w=ls['Collision']['__cWid'];h=ls['Collision']['__cHei']
  recipe=dict(name=name,title=title,idea=idea,paths=[],water_paths=[])
  recipes.append(recipe)
  def box(x,y,bw,bh,v=1):
   assert all(n%8==0 for n in [x,y,bw,bh]),(name,x,y,bw,bh)
   for yy in range(y//8,(y+bh)//8):
    for xx in range(x//8,(x+bw)//8):
     assert 0<xx<w-1 and 0<yy<h-1,(name,xx,yy)
     grid[yy*w+xx]=v
  def pad(x,y,bw=32):
   # Keep the open half of paired vertical thresholds clear, even when a new
   # route platform would overlap it. The original 16px catch remains intact.
   old=next(z for z in before['levels'] if z['identifier']==name)
   cells=next(z for z in old['layerInstances'] if z['__identifier']=='Collision')['intGridCsv']
   for xx in range(x//8,(x+bw)//8):
    edge=0 if y==24 else h-1 if y==(h-2)*8 else -1
    if edge>=0 and cells[edge*w+xx]==0 and cells[(y//8)*w+xx]!=2:continue
    box(xx*8,y,8,8,2)
  def hazard(x,y,bw,bh=8):
   old=next(z for z in before['levels'] if z['identifier']==name)
   cells=next(z for z in old['layerInstances'] if z['__identifier']=='Collision')['intGridCsv']
   for yy in range(y//8,(y+bh)//8):
    for xx in range(x//8,(x+bw)//8):
     edge=0 if yy==3 else h-1 if yy==h-2 else -1
     if edge>=0 and cells[edge*w+xx]==0:continue
     box(xx*8,yy*8,8,8,3)
  def path(points):
   for point in points:
    if point[1]==(h-2)*8:
     old=next(z for z in before['levels'] if z['identifier']==name)
     cells=next(z for z in old['layerInstances'] if z['__identifier']=='Collision')['intGridCsv']
     catches=[xx*8+8 for xx in range(w-1) if cells[(h-2)*w+xx]==2 and cells[(h-2)*w+xx+1]==2]
     if catches:point[0]=min(catches,key=lambda xx:abs(xx-point[0]))
   recipe['paths'].append(points)
   for x,y in points:pad(x-16,y,32)
  def move(kind,x,y):
   for e in ls['Entities']['entityInstances']:
    if e['__identifier']==kind:
     e.update(px=[x,y],__grid=[x//8,y//8],__worldX=r['worldX']+x,__worldY=r['worldY']+y)
  def spawn(x,y):
   if recipe['paths'] and recipe['paths'][0][0][1]==y:x=recipe['paths'][0][0][0]
   move('PlayerSpawn',x,y-6)
  def key(x,y):move('Key',x,y-12)
  return r,recipe,box,pad,hazard,path,spawn,key
 # Hub is a quiet navigation landmark. Broad terraces give access to all eight
 # mouths; the cage and courtyard floor remain untouched.
 r,q,b,p,h,path,spawn,key=castle('Prison_Hub','The Four Courtyards','Choose a wing; broad terraces reconnect the school around Jamshid.')
 p(8,160,288);p(344,160,288)
 p(296,208,48);p(248,256,48);p(296,304,48)
 p(8,352,64);p(136,352,160);p(456,352,176);p(280,328,112)
 for e in next(l for l in r['layerInstances'] if l['__identifier']=='Entities')['entityInstances']:
  if e['__identifier']=='CastlePassage':e.update(px=[64,352],__grid=[8,44],__worldY=r['worldY']+352)
 for base in [88,408]:
  for i,y in enumerate(range(328,160,-24)):p(base+(48 if i%2 else 0)-24,y,48)
  for i,y in enumerate(range(136,24,-24)):p(base+(48 if i%2==0 else 0)-24,y,48)
  p(base-24,40,48)
 # Red: short wall-sided rises, low jumps, a directional descent and return.
 r,q,b,p,h,path,spawn,key=castle('Prison_R01','Terracotta Switchback','Dash onto a raised shelf, countersteer, then transfer down through the open arch.')
 h(48,176,224);path([[296,160],[224,128],[152,104],[80,136],[24,160]])
 b(176,144,16,32);b(112,144,16,32);spawn(296,160)
 r,q,b,p,h,path,spawn,key=castle('Prison_R02','The Broken Stair','Alternate leftward rise and controlled descent into the lower classroom.')
 h(136,176,144);path([[296,160],[232,128],[160,96],[88,128],[48,160],[104,176]])
 b(184,144,16,32);spawn(296,160)
 r,q,b,p,h,path,spawn,key=castle('Prison_R03','Red Seal','Brake on descending shelves, collect the seal, then dash back into daylight.')
 h(8,176,264);path([[80,24],[128,56],[88,104],[168,136],[248,112],[296,160]])
 key(248,112);spawn(80,24)
 r,q,b,p,h,path,spawn,key=castle('Prison_R04','Lintel Run','A short low-ceiling jump rhythm after the long descent.')
 h(48,176,224);path([[24,160],[88,144],[152,160],[216,152],[296,160]])
 b(104,72,96,24);spawn(24,160)
 # Green: readable one-screen zigzags. Landings vary horizontal direction rather
 # than imposing a repeated staircase or allowing a perimeter wall climb.
 r,q,b,p,h,path,spawn,key=castle('Prison_G01','Windcatcher','Cross the shaft in three ascending diagonal transfers.')
 h(8,176,56);h(136,176,176);path([[96,176],[160,136],[224,96],[184,56],[240,24]])
 h(8,40,8,104);h(304,40,8,104);spawn(96,176)
 r,q,b,p,h,path,spawn,key=castle('Prison_G02','Windward Walls','Alternate wall jumps up the windcatcher, then transfer onto the upper arch.')
 h(8,176,200);b(216,32,16,112);b(272,72,16,88);p(280,64,32)
 q['wall_path']=[[240,176],[280,72],[296,64]];spawn(240,176)
 r,q,b,p,h,path,spawn,key=castle('Prison_G03','Green Seal','A descending aerial key line with a safe landing before the return shaft.')
 h(48,176,168);path([[24,64],[88,88],[160,120],[224,144],[256,176]])
 key(160,120);spawn(24,64)
 r,q,b,p,h,path,spawn,key=castle('Prison_G04','Falling Leaves','Steer between staggered shelves; the same route supports a retreat upward.')
 h(8,176,56);h(136,176,176);path([[240,24],[176,80],[112,112],[160,144],[96,176]])
 p(152,80,48);spawn(240,24)
 # Blue: pools have a low roof, so their dry roof is not a hold-right bypass.
 # Baffles have 32px turning pockets, wider than the full 9x12 body.
 r,q,b,p,h,path,spawn,key=castle('Prison_B01','Qanat Descent','Drop into water, swim under the first baffle and over the second, then land dry.')
 b(48,48,224,120,4);b(48,40,224,8);b(120,48,16,72);b(176,104,8,64)
 p(216,168,56);p(184,176,32);b(48,168,136,8);b(224,168,48,8);h(112,32,120)
 q['water_paths']=[[[88,24],[104,56],[96,140],[152,140],[152,80],[216,80],[216,152],[192,176]]];spawn(88,24)
 q['water_paths'].append([[192,176],[216,152],[216,80],[152,80],[152,140],[96,140],[104,56],[56,40]])
 path([[56,40],[88,24]])
 # Leave visible wells at both ends of the pool roof.
 b(72,40,40,8,0);b(232,40,32,8,0)
 r,q,b,p,h,path,spawn,key=castle('Prison_B02','Two Breaths','A dry landing separates two submerged direction changes.')
 b(40,64,240,104,4);b(40,56,240,8);b(104,64,16,64);b(168,112,16,56);b(232,64,16,64)
 b(184,56,40,8,0);b(40,56,32,8,0);b(40,168,240,8);h(72,48,112);p(8,160,40)
 q['water_paths']=[[[192,24],[208,72],[208,88],[144,88],[144,144],[80,144],[56,120],[24,160]],[[24,160],[56,120],[80,144],[144,144],[144,88],[208,88],[208,72],[240,56]]];path([[240,56],[192,24]]);spawn(192,24)
 r,q,b,p,h,path,spawn,key=castle('Prison_B03','Blue Seal','Climb out of the last pool, then use a dry diagonal dash to reach the key.')
 b(120,112,160,56,4);b(192,112,16,24);b(248,112,32,24,0);b(248,136,32,48);b(280,160,32,24);path([[296,160],[264,136],[232,104],[160,80],[88,56],[88,24]])
 key(88,56);spawn(296,160)
 r,q,b,p,h,path,spawn,key=castle('Prison_B04','The Dry Well','A compact rising countersteer sequence returns to the courtyard.')
 h(136,176,176);path([[96,176],[152,136],[216,96],[152,64],[88,56],[88,24]])
 h(304,48,8,104);spawn(96,176)
 # Gold: commitment and release. Crumbling landings carry the same authored
 # watercolor texture as outdoor ruins, with wide resting ends for retries.
 for number,points,title,idea in [
  (1,[[24,160],[96,136],[176,96],[248,136],[296,160]],'Gilded Rhythm','Three committed landings join two broad safe ends.'),
  (2,[[24,160],[96,128],[144,96],[192,136],[264,176]],'The High Note','Ascend away from the exit, then deliberately drop back to it.'),
  (3,[[240,24],[184,80],[120,112],[168,144],[96,160],[24,160]],'Gold Seal','Catch a descending crumble chain and brake on the seal terrace.'),
  (4,[[296,160],[232,128],[160,144],[88,112],[24,160]],'Last Bell','Alternate high and low catches before the safe hub.')]:
  r,q,b,p,h,path,spawn,key=castle(f'Prison_Y{number:02}',title,idea)
  h(56,176,216);path(points)
  for x,y in points[1:-1]:
   b(x-16,y,32,8,0);entity(r,'CrumblingPlatform',x,y+4,32,8)
  if number==3:key(96,160);p(80,160,40)
  spawn(*points[0])
 # Outdoor revision: keep the story, carpets and established advanced ideas,
 # but replace the repeated entry rhythm and strengthen directional decisions.
 from act2_grass_terrain import rebake_layer
 garden=json.loads((OUT/'before_expansion.json').read_text())
 collision_def=defs['Collisions']
 rules=[a for g in collision_def['autoRuleGroups'] if g['active'] for a in g['rules'] if a['active']]
 groups={v['value']:v['groupUid'] for v in collision_def['intGridValues']}
 for q in garden:
  number=int(q['name'].split('_')[-1]);r=rooms[q['name']]
  ls={l['__identifier']:l for l in r['layerInstances']};layer=ls['Collisions'];es=ls['Entities']['entityInstances']
  def terrain(x,y,w,h,v=10):
   for yy in range(y//8,(y+h)//8):
    for xx in range(x//8,(x+w)//8):layer['intGridCsv'][yy*layer['__cWid']+xx]=v
  def move_entity(e,x,y):e.update(px=[x,y],__grid=[x//8,y//8],__worldX=r['worldX']+x,__worldY=r['worldY']+y)
  if number==3:
   for x,y,w in q['ledges']:terrain(x,y,w,16,0)
   q['title']='Saffron Switchbacks'
   q['ledges']=[[128,264,40],[208,232,40],[304,264,64],[392,232,40],[464,200,40],[552,216,40],[592,192,48]]
   for x,y,w in q['ledges']:terrain(x,y,w,16)
   points=[[88,288],[144,264],[224,232],[328,264],[408,232],[480,200],[568,216],[608,192]]
   q['routes']=[dict(kind='jump' if i==0 else 'dash',start=a,target=b,jump_hold=60,dash_up=b[1]<a[1]-20) for i,(a,b) in enumerate(zip(points,points[1:]))]
   for e in es:
    if e['__identifier']=='Checkpoint' and e['px'][0]==328:move_entity(e,328,256)
  if number==4:
   terrain(264,144,80,16,0)
   # Spring launch, higher catch, then a deliberately descending dash.
   replacements={(112,240):(104,232),(184,192):(176,184),(264,144):(256,136)}
   for ledge in q['ledges']:
    key2=(ledge[0],ledge[1])
    if key2 in replacements:
     terrain(*ledge,16,0);ledge[0],ledge[1]=replacements[key2];terrain(*ledge,16)
   for spring in q['springs']:
    if spring[0]==152:spring[1]=232
    if spring[0]==240:spring[1]=184
   for e in es:
    if e['__identifier']=='SpringPlatform' and e['px'][0] in [152,240]:move_entity(e,e['px'][0],228 if e['px'][0]==152 else 180)
    if e['__identifier']=='Checkpoint' and e['px'][0]==208:move_entity(e,208,176)
   q['routes'][0]['target']=[128,232]
   q['routes'][1].update(start=[152,232],target=[200,184])
   q['routes'][2].update(start=[240,184],target=[280,136])
   q['routes'][3]['start']=[328,136]
   q['title']='Courtyard Arcs'
  if number==5:
   # Wider gaps and shorter crumble windows make the lower route a commitment;
   # the high optional spring detour still rejoins the same safe terrace.
   for e in es:
    if e['__identifier']=='CrumblingPlatform':
     e['width']=40;move_entity(e,e['px'][0]-8,e['px'][1])
   q['crumbles']=[[x-4,y,40] for x,y,w in q['crumbles']]
   q['title']='Orchard of Commitments'
  if number==7:
   # Start on foot with an up-forward dash, after several spring-led rooms.
   es[:]=[e for e in es if not(e['__identifier']=='SpringPlatform' and e['px'][0]==80)]
   q['springs']=[a for a in q['springs'] if a[0]!=80]
   for ledge in q['ledges']:
    if ledge[:2]==[112,240]:
     terrain(*ledge,16,0);ledge[1]=248;terrain(*ledge,16)
   q['routes'][0]=dict(kind='dash',start=[80,288],target=[136,248],dash_up=True,dash_frame=16)
   q['routes'][1].update(start=[152,248],dash_up=True)
   q['title']='The Garden Threshold'
  if number in [3,4,5,7]:rebake_layer(layer,rules,groups)
 (ROOT/'resources/levels/act2_expansion.json').write_text(json.dumps(garden,indent=2)+'\n')
 # Final playable stretch: three connected exams before the painted-wall story.
 from act2_ink_hazards import replace_spikes
 final_trials=[]
 for number,rectangles,guides in [
  (16,[(0,200,128,40),(176,176,40,64),(272,144,48,96),(368,176,40,64),(464,144,48,96),(576,200,64,40)],[(96,200),(192,176),(288,144),(480,144),(600,200)]),
  (17,[(0,200,128,40),(232,160,40,80),(320,184,64,56),(464,128,40,112),(576,200,64,40)],[(96,200),(248,160),(352,184),(600,200)]),
  (18,[(0,184,112,56),(112,224,176,16),(288,184,56,56),(344,224,168,16),(512,184,128,56),(128,160,144,16),(168,184,8,16),(224,208,8,16),(360,160,136,16),(392,208,16,16),(448,184,16,16)],[(80,184),(312,184),(560,184)])]:
  r=rooms[f'Act_2_Level_{number}'];ls={l['__identifier']:l for l in r['layerInstances']};es=ls['Entities']['entityInstances']
  occupied={(xx,yy) for x,y,w,h in rectangles for xx in range(x,x+w,8) for yy in range(y,y+h,8)}
  tiles=ls['CastleTerrain'];tiles['gridTiles']=[]
  sheet=next(t for t in project['defs']['tilesets'] if t['uid']==tiles['__tilesetDefUid'])
  for x,y in sorted(occupied):
   sx,sy=(48,32) if (x,y-8) not in occupied else (48+x//8%2*8,48+y//8%2*8)
   tiles['gridTiles'].append(dict(px=[x,y],src=[sx,sy],f=0,t=sx//8+sy//8*(sheet['pxWid']//8),a=1,d=[x//8+y//8*tiles['__cWid']]))
  actors=sorted([e for e in es if e['__identifier']=='ChaseGuide'],key=lambda e:e['px'][0])
  for e,(x,y) in zip(actors,guides):move_entity(e,x,y)
  if number==16:
   points=[[112,200],[192,176],[288,144],[384,176],[480,144],[592,200]]
   route=[dict(kind='dash',start=a.copy(),target=b.copy(),dash_up=b[1]<a[1]-20,dash_frame=18 if b[1]<a[1] else 14) for a,b in zip(points,points[1:])]
   # Depart near each roof's forward edge, preserving a clear braking zone.
   for step in route[1:]:step['start'][0]+=16
   entity(r,'Checkpoint',384,168,CheckpointID='precision_roofs_rest')
   title='The Rooftop Answer'
  elif number==17:
   entity(r,'CrumblingPlatform',176,196,32,8);entity(r,'CrumblingPlatform',416,156,40,8)
   points=[[112,200],[176,192],[248,160],[344,184],[416,152],[480,128],[592,200]]
   route=[dict(kind='dash',start=a.copy(),target=b.copy(),dash_up=b[1]<a[1]-20,dash_frame=18 if b[1]<a[1]-20 else 14) for a,b in zip(points,points[1:])]
   route[3]['start']=[368,184];route[-1]['start']=[488,128]
   entity(r,'Checkpoint',344,176,CheckpointID='precision_alley_rest')
   title='The Last Loose Tiles'
  else:
   ink=ls['InkThoughtHazards'];cw=ink['__cWid']
   for x,w in [(128,144),(360,136)]:
    for xx in range(x//8,(x+w)//8):ink['intGridCsv'][19*cw+xx]=1
   replace_spikes(r,defs['InkThoughtHazards'])
   route=[]
   entity(r,'Checkpoint',312,176,CheckpointID='precision_qanat_bank')
   title='Two Qanats'
   fruit=sorted([e for e in es if e['__identifier']=='Lemon'],key=lambda e:e['px'][0])
   for e,(x,y) in zip(fruit,[(248,216),(368,216)]):move_entity(e,x,y)
  final_trials.append(dict(name=r['identifier'],title=title,routes=route,
    water_paths=[[[104,184],[144,200],[152,216],[200,216],[200,196],[264,196],[312,184]],[[328,184],[368,196],[424,196],[424,216],[488,216],[496,196],[544,184]]] if number==18 else []))
 (ROOT/'resources/levels/act2_final_trials.json').write_text(json.dumps(final_trials,indent=2)+'\n')
 # Bake the semantic cells into existing watercolor masonry/water/thought art.
 masonry=[a for g in defs['PrisonMasonry']['autoRuleGroups'] for a in g['rules']]
 cols=next(t['__cWid'] for t in project['defs']['tilesets'] if t['identifier']=='Act2CastleMasonry')
 for r in project['levels']:
  if not r['identifier'].startswith('Prison_'):continue
  ls={l['__identifier']:l for l in r['layerInstances']};grid=ls['Collision']['intGridCsv'];w=ls['Collision']['__cWid']
  ls['PrisonMasonry']['autoLayerTiles']=[];ls['Tiles']['autoLayerTiles']=[]
  for i,v in enumerate(grid):
   if not v:continue
   x,y=i%w,i//w
   if v==1:
    rule=next(a for a in masonry if a['size']==3) if y==0 or grid[i-w]!=1 else next(a for a in masonry if a['size']==1 and a['xOffset']==x%8 and a['yOffset']==y%8);target=ls['PrisonMasonry'];c=cols
   else:
    rule=next(a for g in defs['Tiles']['autoRuleGroups'] for a in g['rules'] if a['pattern']==[v]);target=ls['Tiles'];c=16
   t=rule['tileRectsIds'][0][0];target['autoLayerTiles'].append(dict(px=[x*8,y*8],src=[t%c*8,t//c*8],t=t,f=0,a=1,d=[rule['uid'],i]))
 assert apertures(before)==apertures(project),'Paired room mouths must remain unchanged'
 import jsonschema
 jsonschema.validate(project,json.loads((ROOT/'tools/ldtk_1_5_3.schema.json').read_text()))
 PATH.write_text(update(raw,project))
 stamp.write_text(hashlib.sha256(PATH.read_bytes()).hexdigest()+'\n')
 (ROOT/'resources/levels/act2_precision.json').write_text(json.dumps(recipes,indent=2)+'\n')
 print('Authored 24 rooms (17 castle, 4 garden, 3 finale); preserved identities and apertures.')
if __name__=='__main__':main()
