"""Original 8px masonry inspired by Aran Ink's edge / infill method.
Rebuild art without changing any pre-existing tile IDs. --install updates LDtk
rules only; close the Act 1 project in LDtk first. Old tiles 0..25 stay intact.
"""
from pathlib import Path
import json, copy, argparse, random
from PIL import Image, ImageDraw, ImageColor
import build_material_lab as rules
ROOT=Path(__file__).resolve().parents[1]
FILL='#151c27'
RAMPS={'brick_new':[FILL,'#34313c','#795153','#ad7970','#d3a08b'],
       'stone':[FILL,'#293642','#526b77','#81979e','#b1bbb0']}
BASE=26
COUNT=195

def draw_brick(mask, v):
 """Running-bond fired clay. Courses stay horizontal even on vertical walls.
 Four variants change firing marks and joints, never rotate the brickwork.
 """
 im=Image.new('RGBA',(8,8),FILL)
 # Desaturated NYC red/brown clay with warm worn arrises and recessed mortar.
 clay=['#875448','#925c4d','#805047','#9a6251']
 mortar='#514444'; shadow='#583d38'; highlight='#b17b60'
 exposed=[side for side in range(4) if not mask>>side&1]
 for y in range(8):
  for x in range(8):
   distances=[y,7-x,7-y,x]
   depth=min([distances[k] for k in exposed],default=99)
   # Uneven broken back of the face; broad clay masses rather than plus signs.
   limit=[6,7,6,5,6,7,7,6][(x+v*2)%8]
   if depth>=limit: continue
   course=y//4
   joint=(v*2+course*4)%8
   seam=x==joint
   if y%4==3:
    color=mortar
   elif seam:
    color=mortar
   elif y%4==0:
    color=highlight if depth<3 else clay[(v+course)%4]
   elif y%4==2:
    color=clay[(v+course+2)%4]
   else:
    color=clay[(v+course)%4]
   # Short firing variations stay inside the brick, never become random noise.
   if y%4==1 and (x+v)%7 in (2,3): color=clay[(v+2)%4]
   if depth>=4:
    color=shadow if color!=mortar else '#373039'
   im.putpixel((x,y),ImageColor.getcolor(color,'RGBA'))
 # Continuous readable contact bands, but with recessed joints and worn tones.
 for side in exposed:
  for u in range(8):
   x,y=[(u,0),(7,u),(u,7),(0,u)][side]
   joint=(v*2+(y//4)*4)%8
   color=mortar if (y%4==3 if side in (1,3) else x==joint) else (
    highlight if side==0 else clay[(v+(u//3))%4])
   im.putpixel((x,y),ImageColor.getcolor(color,'RGBA'))
 for bit,a,b,x,y in [(4,0,3,0,0),(5,0,1,7,0),(6,1,2,7,7),(7,2,3,0,7)]:
  if mask>>a&1 and mask>>b&1 and not mask>>bit&1:
   d=ImageDraw.Draw(im)
   d.point((x,y),fill=highlight)
   d.point((x+(1 if x==0 else -1),y),fill=clay[v])
   d.point((x,y+(1 if y==0 else -1)),fill=shadow)
 for a,b,x,y in [(0,3,0,0),(0,1,7,0),(2,1,7,7),(2,3,0,7)]:
  if not mask>>a&1 and not mask>>b&1: im.putpixel((x,y),(0,0,0,0))
 return im

def draw_tile(name,mask,v):
 if name=='brick_new': return draw_brick(mask,v)
 p=RAMPS[name]; im=Image.new('RGBA',(8,8),p[0]); d=ImageDraw.Draw(im)
 # Coherent 3–6px clusters, with sparse joints. No uncorrelated pixel noise.
 profiles=[[6,7,7,6,6,5,5,6],[5,5,6,7,7,6,6,5],[7,7,6,6,5,6,7,7],[6,5,5,6,7,7,6,6]]
 for side in range(4):
  if mask>>side&1: continue
  depth=profiles[(v+side)%4]
  seam=(2+v*2+side)%8
  for u in range(8):
   for z in range(depth[u]):
    x,y=[(u,z),(7-z,u),(u,7-z),(z,u)][side]
    # Shade downwards. Bottom edges remain readable without a white outline.
    tone=3 if z==0 else 2 if z<depth[u]-1 else 1
    if side==2 and tone==3: tone=2
    if name=='brick_new':
     if u==seam and z>0: tone=1
     if z==3: tone=1
     if z>=4 and u==(seam+4)%8: tone=1
     if z==1 and u not in (seam,(seam+1)%8) and side==0: tone=3
    else:
     # Rounded shoulders and shaded stone cheeks, not square masonry joints.
     if u in (seam,(seam+1)%8) and z>=2: tone=1
     if side==0 and z==1 and u in ((seam+3)%8,(seam+4)%8): tone=3
    d.point((x,y),fill=p[tone])
  if side==0:
   start=(v*2+1)%6
   for u in range(start,start+2): d.point((u,0),fill=p[4])
 # Concave corners get a short bevel which fades inward.
 for bit,a,b,x,y in [(4,0,3,0,0),(5,0,1,7,0),(6,1,2,7,7),(7,2,3,0,7)]:
  if mask>>a&1 and mask>>b&1 and not mask>>bit&1:
   for dx,dy,t in [(0,0,3),(1,0,2),(0,1,2),(1,1,1)]:
    d.point((x+dx*(1 if x==0 else -1),y+dy*(1 if y==0 else -1)),fill=p[t])
 # Restore each exposed contact band after drawing all sides. On narrow or
 # isolated tiles, a later side's inward shading must not erase another edge.
 for side in range(4):
  if mask>>side&1:continue
  for u in range(8):
   x,y=[(u,0),(7,u),(u,7),(0,u)][side]
   d.point((x,y),fill=p[3 if side==0 else 2])
 # Tiny convex corner recesses; large readable contact bands remain on-grid.
 for a,b,x,y in [(0,3,0,0),(0,1,7,0),(2,1,7,7),(2,3,0,7)]:
  if not mask>>a&1 and not mask>>b&1: d.point((x,y),fill=(0,0,0,0))
 return im

def make_material(name):
 tiles=[]; mapping={}
 for mask in rules.MASKS:
  if mask==255: continue
  mapping[mask]=list(range(len(tiles),len(tiles)+4))
  tiles += [draw_tile(name,mask,v) for v in range(4)]
 infill=[]
 # Nine abstract shapes touch different tile sides; one quiet tile = 10%.
 shapes=[[],[(0,1,4,3),(5,5,8,7)],[(3,-1,6,3)],[(0,5,5,8)],[(5,2,9,5)],[(0,0,2,4),(4,5,7,8)],[(1,2,6,4)],[(4,-1,8,2),(0,6,3,8)],[(0,2,3,5)],[(2,5,6,8)]]
 for boxes in shapes:
  im=Image.new('RGBA',(8,8),FILL); d=ImageDraw.Draw(im)
  for box in boxes:
   if name=='stone': d.ellipse(box,fill=RAMPS[name][1])
   else: d.rounded_rectangle(box,radius=1,fill=RAMPS[name][1])
  infill.append(len(tiles));tiles.append(im)
 fill=len(tiles);tiles.append(Image.new('RGBA',(8,8),FILL))
 assert len(tiles)==COUNT
 return tiles,mapping,infill,fill

def run(install):
 pth=ROOT/'ldtk/hooshang_act1.ldtk'; original=pth.read_text(); p=json.loads(original); ld=next(l for l in p['defs']['layers'] if l['identifier']=='Collisions')
 sheet_path=ROOT/'ldtk/art/bricks_8px.png'; old=Image.open(sheet_path).convert('RGBA')
 if not install and old.width<BASE*8: raise RuntimeError('Original 26-tile atlas required')
 sheet=Image.new('RGBA',(max(old.width,(BASE+COUNT*2)*8),8));sheet.paste(old,(0,0));sheet.paste(old.crop((0,0,BASE*8,8)),(0,0))
 materials={}
 for n,name in enumerate(RAMPS):
  tiles,mapping,inf,fill=make_material(name);start=BASE+n*COUNT
  for i,t in enumerate(tiles): sheet.paste(t,((start+i)*8,0))
  materials[name]=(tiles,mapping,inf,fill,start)
  contact=Image.new('RGBA',(128,104))
  for i,t in enumerate(tiles):contact.paste(t,(i%16*8,i//16*8))
  contact.save(ROOT/f'ldtk/art/{name}_celeste.png')
 sheet.save(sheet_path)
 if install:
  existing=[u for g in ld['autoRuleGroups'] if g['name'].startswith(('brick_new /','stone /')) for u in [g['uid']]+[r['uid'] for r in g['rules']]]
  rules.uid=min(existing)-1 if existing else max(p['nextUid'],10000)
  ld['autoRuleGroups']=[g for g in ld['autoRuleGroups'] if not g['name'].startswith(('brick_new','stone'))]
  values={v['value']:v for v in ld['intGridValues']}
  for value,name in [(7,'brick_new'),(8,'stone')]:
   if value not in values: ld['intGridValues'].append(dict(value=value,identifier=name,color=RAMPS[name][3],tile=None,groupUid=0))
   else: values[value]['color']=RAMPS[name][3]
   tiles,mp,inf,fill,start=materials[name]
   ld['autoRuleGroups'] += rules.groups(name,value,{k:[start+i for i in v] for k,v in mp.items()},[start+i for i in inf],start+fill)
  from fix_masonry_edges import configure
  configure(ld)
  ts=next(t for t in p['defs']['tilesets'] if t['uid']==32); ts.update(pxWid=sheet.width,pxHei=8,__cWid=sheet.width//8,__cHei=1,cachedPixelData=None)
  p['nextUid']=max(p['nextUid'],rules.uid+1)
  # Existing rooms currently contain neither value 7 nor 8. No geometry changes.
  affected=sum(v in (7,8) for r in p['levels'] for l in r['layerInstances'] if l['__identifier']=='Collisions' for v in l['intGridCsv'])
  if affected: raise RuntimeError('Save in LDtk to rebake placed new materials before installing updated rules')
  from ldtk_add_ceiling_tile import object_span, block
  replacements=[]
  for identifier,obj in [('Collisions',ld),('Bricks8px',ts)]:
   a,b=object_span(original,original.index('"identifier": "'+identifier+'"'))
   depth=len(original[original.rfind('\n',0,a)+1:a])
   replacements.append((a,b,block(obj,depth).lstrip('\t')))
  for a,b,text in sorted(replacements,reverse=True):original=original[:a]+text+original[b:]
  import re
  original=re.sub(r'"nextUid": \d+', '"nextUid": '+str(p['nextUid']), original,count=1)
  assert json.loads(original)==p
  pth.write_text(original)
 # Native-scale study: two materials in matching shapes, 26-cell uninterrupted runs.
 preview=Image.new('RGBA',(256,192),'#242e40')
 for n,name in enumerate(RAMPS):
  tiles,mp,inf,fill,_=materials[name];w,h=28,9
  solid={(x,y) for y in range(h) for x in range(w) if y>=4 or x<3 or x>=25}
  solid-={(x,y) for x in range(9,13) for y in range(4,6)}
  for x,y in solid:
   mask=rules.normalized(sum((1<<i) for i,(dx,dy) in enumerate(rules.NEIGHBORS) if (x+dx,y+dy) in solid))
   rng=random.Random(x*7651+y*831+n*18)
   if mask!=255:t=tiles[rng.choice(mp[mask])]
   elif any((x+dx,y+dy) not in solid for dx in range(-2,3) for dy in range(-2,3)):t=tiles[rng.choice(inf)]
   else:t=tiles[fill]
   preview.alpha_composite(t,(16+x*8,8+n*96+y*8))
 preview.save(ROOT/'ldtk/art/celeste_masonry_preview.png')
 preview.resize((1024,768),Image.Resampling.NEAREST).save(ROOT/'ldtk/art/celeste_masonry_preview_4x.png')
 print('Created brick and stone: four variants per boundary topology, 10 infill tiles, common interior.')
if __name__=='__main__':
 ap=argparse.ArgumentParser();ap.add_argument('--install',action='store_true');run(ap.parse_args().install)
