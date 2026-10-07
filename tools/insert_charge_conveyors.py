"""Insert the leftward conveyor course once, preserving all existing room IIDs."""
import copy, json, re
from pathlib import Path
from build_act1_expansion import Author, new_room
from ldtk_add_ceiling_tile import ldtk_running, object_span, block
from place_darkshang_15_18 import instance
ROOT=Path(__file__).resolve().parents[1]
def shift(s):
 return re.sub(r'(?<![A-Za-z0-9])Level_(19|2[0-5])(?![0-9])',lambda m:'Level_'+str(int(m[1])+1),s)
def main():
 assert not ldtk_running(), 'Close LDtk first'
 path=ROOT/'ldtk/hooshang_act1.ldtk';raw=path.read_text();p=json.loads(raw)
 assert not any(r['identifier']=='Level_26' for r in p['levels']), 'Already inserted'
 edits=[]
 for r in p['levels']:
  old=r['identifier'];new=shift(old)
  if new==old:continue
  start,end=object_span(raw,raw.index('"identifier": "'+old+'"'))
  r['identifier']=new
  # Stable entity IDs and checkpoint keys intentionally survive the rename.
  edits.append((start,end,raw[start:end].replace('"identifier": "'+old+'"','"identifier": "'+new+'"',1)))
 configs=json.loads((ROOT/'resources/levels/act1_expansion.json').read_text())
 for c in configs:c['name']=shift(c['name'])
 # 16 moving platforms, all approached from the right. Small alternating
 # heights leave room to jump the locked horizontal charge on each platform.
 route=[[1320,192,96]]
 for i in range(16):route.append([1240-i*72,[176,160,176,152][i%4],40])
 route.append([0,192,120])
 c=copy.deepcopy(next(c for c in configs if c['name']=='Level_18'))
 c.update(name='Level_19',title='Against the Current',width=1416,height=240,
  world_position=[46000,-2048],route=route,belts=list(range(1,17)),
  checkpoints=[6,12],recovery=False, note_landings={},deck_depth={},
  design='Sixteen right-running conveyor platforms in one uninterrupted leftward course. Jump between alternating heights and over telegraphed horizontal charges.',
  conveyor_direction=1,conveyor_speed=36)
 c['encounter'].update(mode='traversal',follow_delay=3.8,anchor=[1392,192],cloud_form=True)
 configs.insert(next(i for i,v in enumerate(configs) if v['name']=='Level_20'),c)
 (ROOT/'resources/levels/act1_expansion.json').write_text(json.dumps(configs,indent=2)+'\n')
 r=new_room(p,'Level_19',1416,240,99);r['uid']=p['nextUid'];p['nextUid']+=1
 r['worldX'],r['worldY']=c['world_position']
 for l in r['layerInstances']:l['levelId']=r['uid']
 a=Author(p,r)
 a.rect(0,0,1416,8,8);a.rect(0,232,1416,8,8)
 a.rect(1320,192,96,40);a.rect(0,192,120,40)
 a.entity('ConeSpikes',720,228,width=1200,height=8)
 for x,y,w in route[1:-1]:a.entity('ConveyorBelt_Right',x+w/2,y+8,width=w,height=16,speed=36.0)
 a.entity('PlayerStart',1392,184,SpawnID='charge_conveyors_entrance')
 a.entity('Exit',0,160)
 for n in c['checkpoints']:
  x,y,w=route[n];a.entity('Checkpoint',x+w/2,y-8,CheckpointID='charge_conveyors_'+str(n))
 definitions={d['identifier']:d for d in p['defs']['entities']}
 for i,x in enumerate([1256,968,680,392,176]):
  a.layers['Entities']['entityInstances'].append(instance(definitions['DarkshangChargeTrigger'],r,(x,120),(24,224),dict(AimAtPlayer=1,UseLaunchOffset=0,WarningTime=1.05,Speed=190+i*8,Distance=240,RecoveryTime=1.2)))
 a.bake()
 last=json.loads(path.read_text())['levels'][-1]
 _,end=object_span(raw,raw.index('"identifier": "'+last['identifier']+'"'))
 edits.append((end,end,',\n'+block(r,2)))
 m=re.search(r'"nextUid":\s*\d+',raw);edits.append((m.start(),m.end(),'"nextUid": '+str(p['nextUid'])))
 for start,end,s in sorted(edits,reverse=True):raw=raw[:start]+s+raw[end:]
 assert json.loads(raw)==p
 path.write_text(raw)
 # Rename room references, never the existing artwork paths or stable IDs.
 files=list((ROOT/'scripts').glob('*.gd'))+list((ROOT/'scenes').rglob('*.gd'))+list((ROOT/'tests').glob('*.gd'))+[ROOT/'ldtk/Act1World.tscn']
 for f in files:
  s=f.read_text();t=shift(s)
  if f.name=='Act1World.tscn':t=t.replace('"Level_18": ExtResource("office_Level_18"),','"Level_18": ExtResource("office_Level_18"),\n"Level_19": ExtResource("office_Level_18"),')
  if t!=s:f.write_text(t)
 print('Inserted Level_19; old 19–25 are now 20–26 with original identities and geometry.')
if __name__=='__main__':main()
