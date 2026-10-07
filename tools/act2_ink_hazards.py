"""Install a dedicated LDtk paint brush; convert authored spike boxes into cells."""
import copy, uuid
from ldtk_add_thought_tiles import make_layer, make_layer_instance, make_rule
NAME='InkThoughtHazards'
ART='art/act2_ink_thought_tiles.png'
NS=uuid.UUID('6ca411bb-9ac6-4900-83aa-2989b20fd09a')
def install(project):
 def uid():
  v=project['nextUid'];project['nextUid']+=1;return v
 ts=next((t for t in project['defs']['tilesets'] if t['identifier']=='InkThoughtTiles'),None)
 if ts is None:
  ts=copy.deepcopy(next(t for t in project['defs']['tilesets'] if t['relPath'].endswith('act2_thought_tiles.png')))
  ts.update(identifier='InkThoughtTiles',uid=uid(),relPath=ART,pxWid=128,pxHei=48,__cWid=16,__cHei=6,cachedPixelData=None,customData=[])
  project['defs']['tilesets'].append(ts)
 ts.update(pxWid=512,pxHei=48,__cWid=64,__cHei=6,cachedPixelData=None)
 ld=next((l for l in project['defs']['layers'] if l['identifier']==NAME),None)
 if ld is None:
  ld=make_layer(uid(),ts['uid'],[uid() for _ in range(5)])
  ld.update(identifier=NAME,doc='Paint lethal ink-thought ribbons. Auto-connected 8px cells; all sides supported.',uiColor='#2E888F')
  ld['intGridValues'][0].update(identifier='ink_thought',color='#2E888F')
  group=ld['autoRuleGroups'][0];group['name']='Connected ink ribbons';group['rules']=[]
  for mask in range(16):
   pattern=[0]*9;pattern[4]=1
   for bit,index in [(1,1),(2,5),(4,7),(8,3)]:pattern[index]=1 if mask&bit else -1
   group['rules'].append(make_rule(uid(),mask,pattern,False,False))
  project['defs']['layers'].append(ld)
 ld.update(doc='Paint a lethal field of roses tangled in sharp thorns. Four variants per connection.',uiColor='#9B3E58')
 ld['intGridValues'][0].update(identifier='rose_thorns',color='#9B3E58')
 group=ld['autoRuleGroups'][0];group['name']='Rose thicket connections'
 for mask,rule in enumerate(group['rules']):
  rule['tileRectsIds']=[[mask+variant*16] for variant in range(4)]
 for room in project['levels']:
  if not any(l['__identifier']==NAME for l in room['layerInstances']):
   li=make_layer_instance(ld['uid'],ts['uid'],room)
   li.update(__identifier=NAME,__tilesetRelPath=ART,iid=str(uuid.uuid5(NS,room['identifier'])))
   room['layerInstances'].append(li)
 return ld,ts

def replace_spikes(room,definition):
 layer=next(l for l in room['layerInstances'] if l['__identifier']==NAME)
 width,height=layer['__cWid'],layer['__cHei']
 cells=layer['intGridCsv'];removed=0
 for entities in room['layerInstances']:
  keep=[]
  for e in entities['entityInstances']:
   if 'Spikes' not in e['__identifier']:keep.append(e);continue
   x=e['px'][0]-e['width']*e['__pivot'][0];y=e['px'][1]-e['height']*e['__pivot'][1]
   assert all(v%8==0 for v in [x,y,e['width'],e['height']]), 'Spike boxes must align to the paint grid'
   for yy in range(int(y)//8,int(y+e['height'])//8):
    for xx in range(int(x)//8,int(x+e['width'])//8):
     assert 0<=xx<width and 0<=yy<height
     cells[yy*width+xx]=1
   removed+=1
  entities['entityInstances']=keep
 rules=definition['autoRuleGroups'][0]['rules'];tiles=[]
 for i,v in enumerate(cells):
  if not v:continue
  x,y=i%width,i//width;mask=0
  for bit,dx,dy in [(1,0,-1),(2,1,0),(4,0,1),(8,-1,0)]:
   if 0<=x+dx<width and 0<=y+dy<height and cells[(y+dy)*width+x+dx]:mask|=bit
  variant=((x*374761393+y*668265263)^((x*374761393+y*668265263)>>13))%4
  tile=mask+variant*16
  tiles.append(dict(px=[x*8,y*8],src=[tile*8,0],f=0,t=tile,a=1,d=[rules[mask]['uid'],i]))
 layer['autoLayerTiles']=tiles
 return removed
