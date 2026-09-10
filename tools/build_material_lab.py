"""Build the isolated office material library and LDtk acceptance room.
Only --reset-room rewrites authored geometry. Run with LDtk closed.
Topology and palette are procedural pixel art; no reduced concept bitmap.
"""
from pathlib import Path
import copy, json, random, uuid, argparse
from PIL import Image, ImageDraw
ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT/'ldtk/material_lab'
ANY = 1000001
VARIANTS = 4
INFILL_COUNT = 10  # nine dark clusters + one plain shared fill = 10% empty detail
FILL = '#191d29'
PALETTES = {
 'Brick': [FILL, '#37303b', '#725354', '#a67a70', '#d2aaa0'],
 'Scaffolding': [FILL, '#293440', '#546574', '#8097a5', '#bfd0d4'],
 'Concrete': [FILL, '#30363f', '#626b70', '#969f9b', '#c5c9b8'],
 'Ceiling': [FILL, '#343740', '#707778', '#a5ada5', '#d4d7c4'],
 'Floor': [FILL, '#33343c', '#6a6264', '#a1978e', '#d1c1a3'],
 'Background': [FILL, '#252b39', '#353e4c', '#4b5765', '#647180'],
}
NEIGHBORS = [(0,-1),(1,0),(0,1),(-1,0),(-1,-1),(1,-1),(1,1),(-1,1)]
def normalized(mask):
 for bit,a,b in [(4,0,3),(5,0,1),(6,1,2),(7,2,3)]:
  if not(mask>>a&1 and mask>>b&1): mask &= ~(1<<bit)
 return mask
MASKS=sorted({normalized(m) for m in range(256)})
assert len(MASKS)==47
base=json.loads((ROOT/'ldtk/hooshang_act1.ldtk').read_text())
layer_template=base['defs']['layers'][0]
rule_template=layer_template['autoRuleGroups'][0]['rules'][0]
uid=1000
def newuid():
 global uid
 uid+=1
 return uid
def iid(name): return str(uuid.uuid5(uuid.NAMESPACE_URL,'hooshang/material-lab/'+name))

def tile_art(material,mask,variant):
 p=PALETTES[material]; rng=random.Random(mask*97+variant*1723)
 im=Image.new('RGBA',(8,8),p[0]); d=ImageDraw.Draw(im)
 edges=[not(mask>>i&1) for i in range(4)]
 # Ragged inward transition: variable 2–5px depth, never a straight inner seam.
 for side,on in enumerate(edges):
  if not on: continue
  for u in range(8):
   depth=rng.choice([2,3,3,4,5])
   for v in range(depth):
    x,y=[(u,v),(7-v,u),(u,7-v),(v,u)][side]
    tone=3 if v==0 else (2 if v<depth-1 else 1)
    if v==0 and (u+variant)%5==0: tone=4
    # Mortar breaks are irregular, offset across variants, not a fixed 8px lattice.
    if v>0 and u==(variant*3+side)%8: tone=1
    if material=='Scaffolding' and v==1: tone=1
    if material=='Floor' and v==2 and u%4==variant: tone=3
    d.point((x,y),fill=p[tone])
 # Concave corners carry a tiny highlight; diagonals ignored unless both sides solid.
 for bit,a,b,x,y in [(4,0,3,0,0),(5,0,1,7,0),(6,1,2,7,7),(7,2,3,0,7)]:
  if mask>>a&1 and mask>>b&1 and not mask>>bit&1:
   d.point((x,y),fill=p[3]); d.point((abs(x-1),y),fill=p[1]); d.point((x,abs(y-1)),fill=p[1])
 # One-pixel corner chips only: top and side contact bands remain readable.
 for a,b,x,y in [(0,3,0,0),(0,1,7,0),(2,1,7,7),(2,3,0,7)]:
  if edges[a] and edges[b]: d.point((x,y),fill=(0,0,0,0))
 if material=='Background':
  # Paint itself is porous, as well as the deliberately unpainted window.
  if variant in (1,3): d.rectangle((3,3,4,4),fill=(0,0,0,0))
 return im

def atlas(material):
 tiles=[]; mapping={}
 for mask in MASKS:
  if mask==255: continue
  mapping[mask]=list(range(len(tiles),len(tiles)+VARIANTS))
  tiles.extend(tile_art(material,mask,v) for v in range(VARIANTS))
 infill=[]
 for v in range(INFILL_COUNT):
  im=Image.new('RGBA',(8,8),FILL); d=ImageDraw.Draw(im)
  if v:
   rng=random.Random(82+v)
   for n in range(2):
    x,y=rng.randrange(6),rng.randrange(6)
    d.ellipse((x,y,min(7,x+rng.randrange(2,5)),min(7,y+rng.randrange(2,4))),fill=PALETTES[material][1])
  if material=='Background': d.rectangle((2,2,4,4),fill=(0,0,0,0))
  infill.append(len(tiles)); tiles.append(im)
 fill=len(tiles); tiles.append(Image.new('RGBA',(8,8),FILL))
 sheet=Image.new('RGBA',(128,((len(tiles)+15)//16)*8))
 for n,t in enumerate(tiles): sheet.paste(t,(n%16*8,n//16*8))
 sheet.save(OUT/'art'/f'{material.lower()}.png')
 return mapping,infill,fill,sheet.size

def rule(pattern,size,ids):
 r=copy.deepcopy(rule_template)
 r.update(uid=newuid(),size=size,pattern=pattern,tileRectsIds=[[i] for i in ids],flipX=False,flipY=False,outOfBoundsValue=1,perlinSeed=73241)
 return r

def group(name,rules):
 g=copy.deepcopy(layer_template['autoRuleGroups'][0]); g.update(uid=newuid(),name=name,rules=rules,usesWizard=False)
 return g

def groups(material,value,mapping,infill,fill):
 corners=[]; edges=[]
 for mask,ids in mapping.items():
  p=[0]*9; p[4]=value
  for bit,(x,y) in enumerate(NEIGHBORS):
   if bit>=4:
    a,b=[(0,3),(0,1),(1,2),(2,3)][bit-4]
    if not(mask>>a&1 and mask>>b&1): continue
   p[(y+1)*3+x+1]=ANY if mask>>bit&1 else -ANY
  r=rule(p,3,ids)
  (edges if mask in [normalized(255 ^ (1 << i)) for i in range(4)] else corners).append(r)
 # A cell up to two cells from any empty neighbor gets random dark clusters.
 infills=[]
 for y in range(-2,3):
  for x in range(-2,3):
   if max(abs(x),abs(y))!=2: continue
   p=[0]*25; p[12]=value; p[(y+2)*5+x+2]=-ANY
   infills.append(rule(p,5,infill))
 return [group(material+' / 1 Corners',corners),group(material+' / 2 Edges',edges),group(material+' / 3 Infill (5x5)',infills),group(material+' / 4 Interior',[rule([value],1,[fill])])]

def build(reset=False):
 p=copy.deepcopy(base); p.update(iid=iid('project'),worldLayout='Free',worldGridWidth=192,worldGridHeight=96,defaultLevelWidth=192,defaultLevelHeight=96,defaultGridSize=8,defaultEntityWidth=8,defaultEntityHeight=8,toc=[],worlds=[],dummyWorldIid=iid('world'),backupOnSave=True)
 p['defs']=dict(layers=[],entities=[],tilesets=[],enums=[],externalEnums=[],levelFields=[])
 solid=copy.deepcopy(layer_template); solid.update(identifier='Solids',uid=100,tilesetDefUid=None,autoRuleGroups=[],autoTilesKilledByOtherLayerUid=None,intGridValuesGroups=[],intGridValues=[dict(value=i+1,identifier=n,color=PALETTES[n][2],tile=None,groupUid=0) for i,n in enumerate(list(PALETTES)[:5])])
 bg=copy.deepcopy(solid); bg.update(identifier='BackgroundGeometry',uid=101,intGridValues=[dict(value=1,identifier='Wall',color='#353e4c',tile=None,groupUid=0)])
 visual=[]
 for i,material in enumerate(PALETTES):
  mapping,inf,fill,size=atlas(material); tid=200+i
  ts=copy.deepcopy(base['defs']['tilesets'][0]); ts.update(identifier=material,uid=tid,relPath='art/'+material.lower()+'.png',pxWid=size[0],pxHei=size[1],tileGridSize=8,__cWid=size[0]//8,__cHei=size[1]//8,cachedPixelData=None)
  p['defs']['tilesets'].append(ts)
  l=copy.deepcopy(solid); l.update(identifier=material+'Art',uid=300+i,type='AutoLayer',__type='AutoLayer',intGridValues=[],autoSourceLayerDefUid=101 if i==5 else 100,tilesetDefUid=tid,autoRuleGroups=groups(material,1 if i==5 else i+1,mapping,inf,fill))
  visual.append(l)
 ent=copy.deepcopy(base['defs']['layers'][2]); ent.update(identifier='Props',uid=102,gridSize=8,autoTilesKilledByOtherLayerUid=None)
 p['defs']['layers']=[ent]+visual[:5]+[solid,visual[5],bg]
 ed=copy.deepcopy(base['defs']['entities'][0]); ed.update(uid=400,identifier='PlayerStart',width=8,height=8,fieldDefs=[])
 p['defs']['entities'].append(ed)
 variants=['Paper','Rubble','Pipe','Sign','Plant']
 p['defs']['enums']=[dict(uid=500,identifier='OfficeProp',externalRelPath=None,iconTilesetUid=None,values=[dict(id=n,tileRect=None,color=7368816) for n in variants])]
 for k,name in enumerate(['ForegroundProp','BackgroundProp']):
  e=copy.deepcopy(ed); e.update(uid=401+k,identifier=name,color='#8896A0')
  f=copy.deepcopy(base['defs']['entities'][0]['fieldDefs'][0]); f.update(uid=510+k,identifier='Variants',__type='Array<LocalEnum.OfficeProp>',type='F_Enum(500)',isArray=True,canBeNull=False,defaultOverride=None)
  e['fieldDefs']=[f]; p['defs']['entities'].append(e)
 level=copy.deepcopy(base['levels'][0]); level.update(identifier='OfficeMaterialLab',iid=iid('room'),uid=600,worldX=0,worldY=0,pxWid=192,pxHei=96,__bgColor='#191d29',layerInstances=[],__neighbours=[])
 W,H=24,12
 cells=[0]*(W*H); backs=[0]*(W*H)
 for y in range(H):
  for x in range(W):
   if y>=9: cells[y*W+x]=1 if x<14 else 3
   if x in (0,23): cells[y*W+x]=1
   if y==0: cells[y*W+x]=4
   if 3<=x<=6 and y==6: cells[y*W+x]=2
   if 15<=x<=19 and y==5: cells[y*W+x]=5
   if 3<=x<=21 and 2<=y<=8 and not (10<=x<=13 and 3<=y<=5): backs[y*W+x]=1
 for ld in p['defs']['layers']:
  li=copy.deepcopy(base['levels'][0]['layerInstances'][0]); li.update(__identifier=ld['identifier'],__type=ld['type'],__cWid=W,__cHei=H,__tilesetDefUid=ld['tilesetDefUid'],__tilesetRelPath=None if ld['tilesetDefUid'] is None else p['defs']['tilesets'][ld['tilesetDefUid']-200]['relPath'],iid=iid(ld['identifier']),levelId=600,layerDefUid=ld['uid'],intGridCsv=cells if ld['uid']==100 else backs if ld['uid']==101 else [],autoLayerTiles=[],gridTiles=[],entityInstances=[],seed=8711)
  level['layerInstances'].append(li)
 eli=level['layerInstances'][0]
 for n,(kind,x,y,choices) in enumerate([('PlayerStart',80,64,[]),('ForegroundProp',48,72,['Paper','Rubble']),('ForegroundProp',104,72,['Paper','Rubble']),('ForegroundProp',160,40,['Plant']),('ForegroundProp',136,72,['Rubble']),('BackgroundProp',32,32,['Pipe']),('BackgroundProp',144,24,['Sign']),('BackgroundProp',152,64,['Pipe'])]):
  definition=next(e for e in p['defs']['entities'] if e['identifier']==kind)
  ei=dict(__identifier=kind,__grid=[x//8,y//8],__pivot=[0,0],__tags=[],__tile=None,__smartColor=definition['color'],iid=iid('prop'+str(n)),defUid=definition['uid'],px=[x,y],width=8,height=8,fieldInstances=[])
  if choices: ei['fieldInstances']=[dict(__identifier='Variants',__type='Array<LocalEnum.OfficeProp>',__value=choices,__tile=None,defUid=definition['fieldDefs'][0]['uid'],realEditorValues=[dict(id='V_String',params=[c]) for c in choices])]
  eli['entityInstances'].append(ei)
 p['levels']=[level]; p['nextUid']=uid+1
 target=OUT/'office_materials.ldtk'
 if target.exists() and not reset:
  old=json.loads(target.read_text()); p['levels']=old['levels']
 target.write_text(json.dumps(p,indent=2)+'\n')
 print(target)
if __name__=='__main__':
 ap=argparse.ArgumentParser(); ap.add_argument('--reset-room',action='store_true'); build(ap.parse_args().reset_room)
