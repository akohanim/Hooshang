#!/usr/bin/env python3
"""8px water dressing, procedural geometry using the built-in ImageGen aquatic source.
Columns: rooted algae, fish brush, outlet brush, falling water, splash.
Eight animation rows. Existing water/fish sheet contracts stay unchanged.
"""
from pathlib import Path
from collections import Counter
from PIL import Image, ImageDraw
import math
ROOT=Path(__file__).resolve().parents[1]
def ramp(kind):
    img=Image.open(ROOT/'assets/props/water_life/source/aquatic_imagegen.png').convert('RGBA')
    width,height=img.size
    box=(0,0,width//2,height//2) if kind=='green' else ((0,height//2,width//2,height) if kind=='water' else (width//2,0,width,height//2))
    colors=Counter(p[:3] for p in img.crop(box).getdata() if p[3]>40)
    def accept(c):
        r,g,b=c
        if kind=='green':return g>r*1.1 and g>b*1.08 and g>45
        if kind=='water':return g>r*1.12 and b>r*1.1
        return r>g*1.15 and g>b*1.15
    candidates=sorted([c for c,n in colors.items() if accept(c)],key=lambda c:sum(c))
    return [candidates[int((len(candidates)-1)*i/31)] for i in range(32)]
g=ramp('green')
w=ramp('water')
k=ramp('fish')
sheet=Image.new('RGBA',(40,64))
fish=Image.new('RGBA',(36,8))
for f in range(3):
    tile=Image.new('RGBA',(12,8));d=ImageDraw.Draw(tile)
    d.polygon([(3,3),(0,1+f),(0,5+f),(3,5)],fill=k[len(k)//3]+(255,))
    d.ellipse((3,2,10,6),fill=k[-8]+(255,))
    d.line((4,5,8,5),fill=(245,234,204,255))
    d.point((9,3),fill=(30,49,46,255))
    d.point((5,2),fill=k[0]+(255,))
    fish.alpha_composite(tile,(12*f,0))
fish.save(ROOT/'assets/props/water_life/koi.png')
for f in range(8):
    tile=Image.new('RGBA',(8,8)); d=ImageDraw.Draw(tile)
    for root,height,phase in [(1,5,0),(3,8,1.5),(6,6,3)]:
        pts=[]
        for h in range(height):
            x=round(root+math.sin(f*math.tau/8+h*.4+phase)*h/6)
            pts.append((max(0,min(7,x)),7-h))
        d.line(pts,fill=g[len(g)//3]+(240,),width=2)
        d.line([(x+1,y) for x,y in pts],fill=g[-3]+(220,))
    sheet.alpha_composite(tile,(0,f*8))
    sheet.alpha_composite(fish.crop((f%3*12+2,0,f%3*12+10,8)),(8,f*8))
    for col in (2,3):
        tile=Image.new('RGBA',(8,8)); p=tile.load()
        for y in range(8):
            for x in range(8):
                ribbon=x in (1,2,5)
                glint=ribbon and (y-f*2)%8<5
                p[x,y]=((221,249,232) if glint else w[24 if ribbon else 16])+(220 if glint else 155,)
        sheet.alpha_composite(tile,(col*8,f*8))
    tile=Image.new('RGBA',(8,8));d=ImageDraw.Draw(tile)
    d.arc((-2,3-f%3,9,8),180,355,fill=w[-1]+(210,))
    for x in (1,5):d.point((x,(x-f)%4),fill=w[-1]+(180,))
    sheet.alpha_composite(tile,(32,f*8))
sheet.save(ROOT/'ldtk/art/act2_water_life.png')
print('Generated act2_water_life.png (40x64)')

# Taller fronds retain readable swaying silhouettes at game resolution.
algae=Image.new('RGBA',(8,128))
for f in range(8):
    tile=Image.new('RGBA',(8,16));d=ImageDraw.Draw(tile)
    for root,height,phase in [(1,9,0),(3,15,1.5),(6,11,3)]:
        pts=[(max(0,min(6,round(root+math.sin(f*math.tau/8+h*.25+phase)*h/8))),15-h) for h in range(height)]
        d.line(pts,fill=g[13]+(245,),width=2)
        d.line([(x+1,y) for x,y in pts],fill=g[26]+(235,))
    algae.alpha_composite(tile,(0,f*16))
algae.save(ROOT/'assets/props/water_life/algae.png')
