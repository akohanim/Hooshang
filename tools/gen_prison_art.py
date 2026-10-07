#!/usr/bin/env python3
"""Editable 8px school tiles; procedural geometry with approved Act 2 source ramps."""
from pathlib import Path
from collections import Counter
from PIL import Image, ImageDraw
import json
ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'ldtk/art/prison'; OUT.mkdir(parents=True,exist_ok=True)
def ramp(path,n=16):
    im=Image.open(path).convert('RGBA')
    colors=[c for c,_ in Counter(p[:3] for p in im.getdata() if p[3]>100).most_common(n)]
    return sorted(colors,key=lambda p:sum(a*b for a,b in zip(p,(.299,.587,.114))))
r=ramp(ROOT/'art/source/prison/masonry_palette.png');g=ramp(ROOT/'art/source/prison/key_palette.png')
warm=[c for c in r if c[0]>c[1]>c[2]]
dark=r[0];shade=warm[1];stone=warm[-4];light=warm[-1];gold=next(c for c in reversed(g) if c[0]>c[1]>c[2])
colors=[(181,76,65),(84,143,104),(68,155,184),(222,175,74)]
im=Image.new('RGBA',(128,128));d=ImageDraw.Draw(im)
def tile(i):return ((i%16)*8,(i//16)*8)
# 0 fill, 1 top, 2 left, 3 right, 4 bottom, 5 one-way, 6 hazard, 7 water, 8 surface.
for i in range(5):
 x,y=tile(i);d.rectangle((x,y,x+7,y+7),fill=stone);d.line((x,y+7,x+7,y+7),fill=shade);d.line((x+3,y,x+3,y+3),fill=shade);d.line((x,y+3,x+7,y+3),fill=shade);d.point((x+6,y+1),fill=light);d.point((x+1,y+5),fill=light)
 if i==1:d.line((x,y,x+7,y),fill=light);d.line((x,y+1,x+7,y+1),fill=gold)
 if i==2:d.line((x,y,x,y+7),fill=light)
 if i==3:d.line((x+7,y,x+7,y+7),fill=dark)
 if i==4:d.line((x,y+7,x+7,y+7),fill=dark)
x,y=tile(5);d.rectangle((x,y,x+7,y+2),fill=shade);d.line((x,y,x+7,y),fill=gold)
x,y=tile(6)
for j in [0,3,5]:d.polygon([(x+j,y+7),(x+j+1,y+1),(x+min(j+3,7),y+7)],fill=(75,54,88));d.point((x+j+1,y+2),fill=(181,122,160))
for i in [7,8]:
 x,y=tile(i);d.rectangle((x,y,x+7,y+7),fill=(43,110,136,190));d.line((x+1,y+5,x+4,y+5),fill=(70,148,166,210))
 if i==8:d.line((x,y,x+7,y),fill=(149,206,202));d.line((x+1,y+1,x+4,y+1),fill=(210,225,208))
# Background tiles: plaster, wainscot, barred window, school floor stripe.
for i in [16,17,18,19]:
 x,y=tile(i);d.rectangle((x,y,x+7,y+7),fill=shade)
 if i==16:
  plaster=tuple(round(shade[j]*.9+stone[j]*.1) for j in range(3))
  d.point((x+2,y+3),fill=plaster);d.point((x+6,y+6),fill=plaster)
 if i==17:d.line((x,y,x+7,y),fill=gold);d.line((x+4,y+1,x+4,y+7),fill=dark)
 if i==18:
  d.rectangle((x+1,y+1,x+6,y+6),fill=(106,167,167));d.line((x+3,y,x+3,y+7),fill=dark);d.line((x,y+4,x+7,y+4),fill=dark)
 if i==19:d.line((x,y+6,x+7,y+6),fill=gold)
# Four colored key tiles and locks; silhouette marks triangle, leaf, drop, star.
for k,c in enumerate(colors):
 x,y=tile(32+k)
 shapes=[[(0,5),(2,0),(5,5)],[(0,3),(3,0),(5,0),(5,3),(2,5)],[(2,0),(5,3),(4,5),(1,5),(0,3)],[(2,0),(3,2),(5,2),(4,3),(5,5),(2,4),(0,5),(1,3),(0,2),(2,2)]]
 d.polygon([(x+a,y+b) for a,b in shapes[k]],fill=c,outline=dark);d.point((x+2,y+2),fill=light);d.line((x+4,y+4,x+7,y+7),fill=gold,width=2);d.point((x+7,y+5),fill=gold)
 x,y=tile(36+k);d.arc((x+2,y,x+6,y+5),180,360,fill=gold);d.rectangle((x+1,y+3,x+6,y+7),fill=c);d.point((x+3,y+5),fill=dark)
# Sheet blocks for decor, addressed as tile rectangles.
def prop(x,y,w,h,kind):
 d.rectangle((x,y,x+w-1,y+h-1),fill=dark)
 if kind=='locker':
  d.rectangle((x+1,y+1,x+w-2,y+h-2),fill=(69,117,121));d.line((x+w//2,y+1,x+w//2,y+h-2),fill=dark)
  for z in (3,5,7):d.line((x+3,y+z,x+w//2-3,y+z),fill=shade)
  d.point((x+w//2-2,y+h//2),fill=gold)
 elif kind=='shelf':
  for yy in range(y+2,y+h-1,7):
   for xx in range(x+2,x+w-2,4):d.rectangle((xx,yy,xx+2,yy+4),fill=colors[((xx+yy)//4)%4])
   d.line((x+1,yy+5,x+w-2,yy+5),fill=gold)
 elif kind=='board':
  d.rectangle((x+1,y+1,x+w-2,y+h-2),fill=(40,77,70))
  for yy in (4,8,12):d.line((x+4,y+yy,x+w-7,y+yy),fill=(164,183,152))
 elif kind=='desk':
  d.rectangle((x,y,x+w-1,y+3),fill=stone);d.line((x,y,x+w-1,y),fill=gold);d.rectangle((x+2,y+4,x+3,y+h-1),fill=shade);d.rectangle((x+w-4,y+4,x+w-3,y+h-1),fill=shade)
prop(0,32,16,24,'locker');prop(16,32,24,24,'shelf');prop(40,32,32,16,'board');prop(72,32,24,16,'desk')
# Cage has a generous 64x40 readable silhouette, overlays drawn by prefab.
for name,opened in [('cage_closed',False),('cage_open',True)]:
 a=Image.new('RGBA',(64,40));q=ImageDraw.Draw(a)
 q.rectangle((1,1,62,38),outline=stone,width=2);q.line((2,2,61,2),fill=gold,width=2)
 for xx in range(7,61,7):
  if opened and 24<xx<52:continue
  q.line((xx,4,xx,36),fill=(74,85,89),width=2);q.line((xx,4,xx,35),fill=(148,164,159))
 q.line((2,26,61,26),fill=shade,width=2);a.save(OUT/(name+'.png'))
for name,opened in [('door_closed',False),('door_open',True)]:
 a=Image.new('RGBA',(32,40));q=ImageDraw.Draw(a);q.rectangle((0,0,31,39),outline=stone,width=2)
 if not opened:
  for xx in range(5,30,5):q.line((xx,2,xx,37),fill=(118,139,140),width=2)
  q.rectangle((11,17,20,25),fill=gold)
 a.save(OUT/(name+'.png'))
# Temporary readability pass: reuse the project's steel scaffold vocabulary.
# Only the prison atlas changes; the shared source sheet remains untouched.
from gen_scaffolding import connected
for index,mask in [(0,15),(1,14),(2,7),(3,13),(4,11),(5,10)]:
 im.paste(connected(mask,0),tile(index))
# Background must sit behind gameplay, without false ledges or repeated windows.
for index in [16,17,18,19]:
 x,y=tile(index);d.rectangle((x,y,x+7,y+7),fill=(25,35,45))
# Bright spike tips distinguish danger from the neutral steel collision silhouette.
x,y=tile(6)
d.rectangle((x,y,x+7,y+7),fill=(0,0,0,0))
for j in [0,4]:d.polygon([(x+j,y+7),(x+j+2,y),(x+j+3,y+7)],fill=(235,116,126));d.point((x+j+2,y),fill=(255,222,206))
im.save(OUT/'school.png')
(OUT/'atlas.json').write_text(json.dumps({'tile_size':8,'tiles':{'fill':0,'top':1,'left':2,'right':3,'bottom':4,'one_way':5,'hazard':6,'water':7,'surface':8},'props':{'locker':[0,32,16,24],'shelf':[16,32,24,24],'board':[40,32,32,16],'desk':[72,32,24,16]}},indent=2)+'\n')
print('Generated school atlas and cage/door states')
