"""Author Level_V9: The Night Shift atrium. Run with LDtk and Godot closed.
Only this existing room is replaced. Geometry is editable IntGrid data; the
baked cells use the project's existing masonry rules, never a second tileset.
Without --install writes a review candidate to output/level_v9/.
"""
from pathlib import Path
import argparse, copy, json, random, uuid
from fix_masonry_edges import matches
from ldtk_add_ceiling_tile import object_span, block
ROOT = Path(__file__).resolve().parents[1]
NAME = 'Level_V9'
# x, top, width, depth: permanent landings, large enough to stop and plan.
LANDINGS = [(0,320,96,32),(120,296,32,16),(184,272,32,24),
 (248,248,56,24),(440,192,72,24),(392,160,32,16),
 (344,128,32,16),(280,96,40,16),(368,64,40,16),
 (448,64,32,16),(520,64,40,16),(592,64,48,32),
 (536,160,32,16),(224,72,24,16)]
CRUMBLES = [(328,224,24),(384,208,24)]

def build(project):
 p = copy.deepcopy(project)
 level = next(l for l in p['levels'] if l['identifier']==NAME)
 assert (level['pxWid'], level['pxHei']) == (640,352)
 layers = {l['__identifier']:l for l in level['layerInstances']}
 for l in layers.values():
  l['entityInstances']=[];l['autoLayerTiles']=[];l['gridTiles']=[]
  l['intGridCsv']=[0]*(l['__cWid']*l['__cHei']) if l['__type']=='IntGrid' else []
 terrain=layers['Collisions']; cells=terrain['intGridCsv']; w=80; h=44
 def rect(x,y,ww,hh,material=7):
  assert all(v%8==0 for v in (x,y,ww,hh))
  for yy in range(y//8,(y+hh)//8):
   for xx in range(x//8,(x+ww)//8): cells[yy*w+xx]=material
 for i,r in enumerate(LANDINGS):rect(*r,material=8 if i in (3,4,7,11) else 7)
 # A visible roof and pit lip frame the atrium without blocking its entrance.
 rect(0,0,640,8,8);rect(0,8,8,280,8);rect(632,96,8,256,8)
 rect(96,344,536,8,8)
 definitions={d['identifier']:d for d in p['defs']['entities']}
 entities=layers['Entities']['entityInstances']
 def entity(name,x,y,width=None,height=None,**values):
  d=definitions[name]; key=f'{NAME}/{name}/{x}/{y}'
  e={'__identifier':name,'__grid':[int(x//8),int(y//8)],
   '__pivot':[d['pivotX'],d['pivotY']],'__tags':d['tags'],
   '__tile':d['tileRect'],'__smartColor':d['color'],
   'iid':str(uuid.uuid5(uuid.NAMESPACE_URL,key)),
   'width':width or d['width'],'height':height or d['height'],
   'defUid':d['uid'],'px':[x,y],'fieldInstances':[],
   '__worldX':level['worldX']+x,'__worldY':level['worldY']+y}
  for f in d['fieldDefs']:
   value=values.get(f['identifier'])
   e['fieldInstances'].append({'__identifier':f['identifier'],'__type':f['__type'],
    '__value':value,'__tile':None,'defUid':f['uid'],'realEditorValues':[]})
  entities.append(e)
 entity('PlayerStart',24,312,SpawnID='v9_entrance')
 entity('Exit',616,32)
 entity('Checkpoint',272,240,CheckpointID='v9_lower_landing')
 entity('Checkpoint',472,184,CheckpointID='v9_turnaround')
 for x,y,ww in CRUMBLES:entity('CrumblingPlatform',x+ww//2,y+4,width=ww)
 entity('ConeSpikes',364,340,width=536)
 # The patrol crosses the bridge's AIRSPACE; both staging ledges stay safe.
 entity('DarkThought',366,182,Motion='Vertical',Amplitude=18.0,Speed=0.22,Phase=0.0,Clockwise=1.0,Glow=1.0,Angle=0.0)
 # One upper timing gate. Its patrol never sweeps a resting surface.
 entity('DarkThought',500,36,Motion='Vertical',Amplitude=14.0,Speed=0.18,Phase=0.5,Clockwise=1.0,Glow=1.0,Angle=0.0)
 for x,y in [(200,232),(552,136),(236,48)]:entity('Lemon',x,y)
 ld=next(d for d in p['defs']['layers'] if d['identifier']=='Collisions')
 rules=[r for g in ld['autoRuleGroups'] if g['active'] and g['name'].startswith(('brick_new /','stone /')) for r in g['rules'] if r['active']]
 groups={v['value']:v['groupUid'] for v in ld['intGridValues']}
 for i,v in enumerate(cells):
  if not v:continue
  x,y=i%w,i//w
  rule=next(r for r in rules if matches(r,cells,w,h,x,y,groups))
  assert not rule['flipX'] and not rule['flipY']
  tile=random.Random(f"{terrain['seed']}:{rule['uid']}:{x}:{y}").choice(rule['tileRectsIds'])[0]
  terrain['autoLayerTiles'].append(dict(px=[x*8,y*8],src=[tile*8,0],f=0,t=tile,a=1,d=[rule['uid'],x,y]))
 return p,level

def main():
 ap=argparse.ArgumentParser();ap.add_argument('--install',action='store_true');args=ap.parse_args()
 path=ROOT/'ldtk/hooshang_act1.ldtk';text=path.read_text();original=json.loads(text)
 result,level=build(original)
 for before,after in zip(original['levels'],result['levels']):
  if before['identifier']!=NAME:assert before==after
 # Replace only the target object, preserving everyone else's formatting.
 start,end=object_span(text,text.index('"identifier": "'+NAME+'"'))
 indent=len(text[text.rfind('\n',0,start)+1:start])
 rendered=text[:start]+block(level,indent).lstrip('\t')+text[end:]
 assert json.loads(rendered)==result
 out=path if args.install else ROOT/'output/level_v9/hooshang_act1.candidate.ldtk'
 out.parent.mkdir(parents=True,exist_ok=True);out.write_text(rendered)
 print(out)
 print('Landings:',len(LANDINGS),'entities:',len(next(l for l in level['layerInstances'] if l['__identifier']=='Entities')['entityInstances']))
if __name__=='__main__':main()
