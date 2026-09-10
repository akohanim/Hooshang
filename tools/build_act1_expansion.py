"""Build the five-room descent and ten-room escape from the authored route data.
Use --install with editors closed. Existing unrelated rooms and all story text
are preserved. New rooms have stable IDs so re-running never changes saves.
"""
from pathlib import Path
import copy,json,random,uuid,argparse
from fix_masonry_edges import matches
from ldtk_add_ceiling_tile import object_span,block
ROOT=Path(__file__).resolve().parents[1]
P=ROOT/'ldtk/hooshang_act1.ldtk'
CONFIG=ROOT/'resources/levels/act1_expansion.json'
def iid(key):return str(uuid.uuid5(uuid.NAMESPACE_URL,'hooshang/act1-expansion/'+key))

class Author:
 def __init__(self,p,level):
  self.p=p;self.level=level;self.layers={a['__identifier']:a for a in level['layerInstances']}
  self.w=level['pxWid']//8;self.h=level['pxHei']//8
  for a in self.layers.values():
   a['__cWid']=self.w;a['__cHei']=self.h
   a['entityInstances']=[];a['gridTiles']=[];a['autoLayerTiles']=[]
   a['intGridCsv']=[0]*(self.w*self.h) if a['__type']=='IntGrid' else []
 def rect(self,x,y,w,h,value=7):
  assert all(n%8==0 for n in [x,y,w,h]),(x,y,w,h)
  assert 0<=x<x+w<=self.w*8 and 0<=y<y+h<=self.h*8
  for yy in range(y//8,(y+h)//8):
   for xx in range(x//8,(x+w)//8):self.layers['Collisions']['intGridCsv'][yy*self.w+xx]=value
 def entity(self,name,x,y,width=None,height=None,**values):
  d=next(d for d in self.p['defs']['entities'] if d['identifier']==name)
  e={'__identifier':name,'__grid':[int(x//8),int(y//8)],'__pivot':[d['pivotX'],d['pivotY']],
   '__tags':d['tags'],'__tile':d['tileRect'],'__smartColor':d['color'],
   'iid':iid(f"{self.level['identifier']}/{name}/{x}/{y}"),'width':width or d['width'],
   'height':height or d['height'],'defUid':d['uid'],'px':[x,y],'fieldInstances':[],
   '__worldX':self.level['worldX']+x,'__worldY':self.level['worldY']+y}
  for f in d['fieldDefs']:
   e['fieldInstances'].append({'__identifier':f['identifier'],'__type':f['__type'],
    '__value':values.get(f['identifier']),'__tile':None,'defUid':f['uid'],'realEditorValues':[]})
  self.layers['Entities']['entityInstances'].append(e)
 def bake(self):
  ld=next(d for d in self.p['defs']['layers'] if d['identifier']=='Collisions')
  rules=[r for g in ld['autoRuleGroups'] if g['active'] and g['name'].startswith(('brick_new /','stone /')) for r in g['rules'] if r['active']]
  groups={v['value']:v['groupUid'] for v in ld['intGridValues']};a=self.layers['Collisions']
  for i,v in enumerate(a['intGridCsv']):
   if not v:continue
   x,y=i%self.w,i//self.w;r=next(r for r in rules if matches(r,a['intGridCsv'],self.w,self.h,x,y,groups))
   t=random.Random(f"{a['seed']}:{r['uid']}:{x}:{y}").choice(r['tileRectsIds'])[0]
   a['autoLayerTiles'].append(dict(px=[x*8,y*8],src=[t*8,0],f=0,t=t,a=1,d=[r['uid'],x,y]))

def new_room(p,name,w,h,index):
 template=next(l for l in p['levels'] if l['identifier']=='Level_V9')
 level=copy.deepcopy(template);level.update(identifier=name,iid=iid(name),uid=11000+index,
  worldX=6624+index*672,worldY=-488,pxWid=w,pxHei=h,__neighbours=[],bgRelPath=None,bgPos=None,__bgPos=None)
 for a in level['layerInstances']:a.update(iid=iid(name+'/'+a['__identifier']),levelId=level['uid'])
 p['levels'].append(level);p['nextUid']=max(p['nextUid'],level['uid']+1)
 return level

def build(p):
 configs=json.loads(CONFIG.read_text());changed=[]
 for i,c in enumerate(configs):
  level=next((l for l in p['levels'] if l['identifier']==c['name']),None)
  if level is None:level=new_room(p,c['name'],c['width'],c['height'],i)
  assert (level['pxWid'],level['pxHei'])==(c['width'],c['height'])
  a=Author(p,level);route=c['route'];crumble=c.get('crumbles',[])
  for n,(x,y,w) in enumerate(route):
   if n in crumble:a.entity('CrumblingPlatform',x+w/2,y+4,width=w)
   else:a.rect(x,y,w,16 if n not in (0,len(route)-1) and n not in c.get('belts',[]) else c['height']-y,8 if n in c.get('checkpoints',[]) else 7)
  a.rect(0,0,c['width'],8,8);a.rect(0,c['height']-8,c['width'],8,8)
  a.entity('ConeSpikes',c['width']/2,c['height']-12,width=c['width'])
  for r in c.get('ceilings',[]):a.rect(*r,8)
  direction=c['direction'];sx,sy,sw=route[0];ex,ey,ew=route[-1]
  a.entity('PlayerStart',sx+24 if direction>0 else sx+sw-24,sy-8,SpawnID=c['name']+'_entrance')
  a.entity('Exit',c['width']-24 if direction>0 else 0,ey-32)
  for n in c.get('checkpoints',[]):
   x,y,w=route[n];a.entity('Checkpoint',x+w/2,y-8,CheckpointID=c['name']+'_landing_'+str(n))
  for x,y in c.get('lemons',[]):a.entity('Lemon',x,y)
  for n in c.get('belts',[]):
   x,y,w=route[n]
   # The solid belt fits exactly over a recessed stretch of this landing.
   # It is supported, so RoomCollapse leaves it in place on the escape.
   for yy in range(y//8,min(a.h,y//8+2)):
    for xx in range(x//8,(x+w)//8):a.layers['Collisions']['intGridCsv'][yy*a.w+xx]=0
   a.entity('ConveyorBelt_Right' if direction>0 else 'ConveyorBelt_Left',x+w/2,y+8,width=w,height=16,speed=28.0 if direction>0 else 36.0)
  for x,y,amp,speed in c.get('thoughts',[]):
   a.entity('DarkThought',x,y,Motion='Vertical',Amplitude=amp,Speed=speed,Phase=0.0,Glow=1.0)
  # Only five fixtures in a long room; pools never exhaust the 16-light cap.
  for x in range(56,c['width'],128):
   nearest=min(route,key=lambda r:abs(r[0]+r[2]/2-x))
   y=max(24,nearest[1]-56)
   a.entity('CeilingLight',x,y,PoolEnergy=1.0,PoolScale=1.7,PoolDrop=32.0,PanelEnergy=0.75,FlickerAmount=0.04 if direction<0 else 0.0,MotionRange=0.0)
  a.bake();changed.append(level['identifier'])
 # Darkshang: deliberate approach, uninterrupted reveal dais, then a return
 # sprint through two short gaps. No checkpoint can respawn past the reveal.
 level=next(l for l in p['levels'] if l['identifier']=='Level_14')
 preserved=[copy.deepcopy(e) for l in level['layerInstances'] for e in l['entityInstances'] if e['__identifier'] in ['DarkshangTrigger','DarkshangSpawn']]
 a=Author(p,level)
 for r in [(0,168,160,24),(192,160,104,32),(328,168,336,24)]:a.rect(*r)
 a.rect(0,0,664,8,8);a.rect(0,184,664,8,8)
 for x,w in [(160,32),(296,32)]:a.entity('ConeSpikes',x+w/2,180,width=w)
 a.entity('PlayerStart',24,160)
 a.layers['Entities']['entityInstances'].extend(preserved)
 # A single clearly telegraphed surge on broad floor AFTER the first escape jump.
 a.entity('SurgePoint',104,128,width=48,height=96,surge_duration=0.7,surge_intensity=0.35)
 for x in [80,240,384,528]:a.entity('CeilingLight',x,32,PoolEnergy=0.8,PoolScale=1.8,PoolDrop=100.0,PanelEnergy=0.5,FlickerAmount=0.15,MotionRange=0.0)
 a.bake();changed.append('Level_14')
 # Home is the ORIGINAL cubicle's geometry and background, with only a return
 # spawn. No opening Rumi trigger or exit can interrupt the existing finale.
 original=next(l for l in p['levels'] if l['identifier']=='Level_0')
 home=next(l for l in p['levels'] if l['identifier']=='Level_25')
 a=Author(p,home)
 for name in ['Collisions','Foreground','Collision','Background','ThoughtHazards']:
  src=next(l for l in original['layerInstances'] if l['__identifier']==name)
  for key in ['intGridCsv','autoLayerTiles','gridTiles','__tilesetDefUid','__tilesetRelPath','overrideTilesetUid']:
   a.layers[name][key]=copy.deepcopy(src[key])
 a.entity('PlayerStart',248,88,SpawnID='homecoming')
 changed.append('Level_25')
 return changed

def main():
 ap=argparse.ArgumentParser();ap.add_argument('--install',action='store_true');args=ap.parse_args()
 text=P.read_text();p=json.loads(text);before=copy.deepcopy(p);changed=build(p)
 # Preserve non-target objects byte-for-byte. Appended new rooms land immediately
 # before the levels array's closing bracket, without reformatting the project.
 edits=[]
 for old in before['levels']:
  if old['identifier'] not in changed:continue
  level=next(l for l in p['levels'] if l['identifier']==old['identifier'])
  start,end=object_span(text,text.index('"identifier": "'+old['identifier']+'"'))
  indent=len(text[text.rfind('\n',0,start)+1:start]);edits.append((start,end,block(level,indent).lstrip('\t')))
 new=[l for l in p['levels'] if l['identifier'] not in {b['identifier'] for b in before['levels']}]
 if new:
  last=before['levels'][-1];start,end=object_span(text,text.index('"identifier": "'+last['identifier']+'"'))
  edits.append((end,end,',\n'+',\n'.join(block(l,2) for l in new)))
 import re
 m=re.search(r'"nextUid":\s*\d+',text);edits.append((m.start(),m.end(),'"nextUid": '+str(p['nextUid'])))
 for start,end,replacement in sorted(edits,reverse=True):text=text[:start]+replacement+text[end:]
 assert json.loads(text)==p
 for old in before['levels']:
  if old['identifier'] not in changed:assert old==next(l for l in p['levels'] if l['identifier']==old['identifier'])
 dest=P if args.install else ROOT/'output/act1_expansion/candidate.ldtk';dest.write_text(text)
 print('Built',', '.join(changed));print(dest)
if __name__=='__main__':main()
