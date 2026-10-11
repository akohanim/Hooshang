#!/usr/bin/env python3
"""Native geometry with source-derived watercolor ramps; never reduce source art.
Source: built-in imagegen (PixelLab subscription expired), materials.png.
"""
from pathlib import Path
from collections import Counter
import random
from PIL import Image, ImageDraw
ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'assets/props/school_wall'
source=Image.open(OUT/'source/materials.png').convert('RGB')
w,h=source.size

def ramp(box,n=6):
    colors=Counter(source.crop(box).getdata()).most_common(300)
    colors=sorted([c for c,_ in colors],key=lambda c:sum(c))
    return [colors[round(i*(len(colors)-1)/(n-1))] for i in range(n)]
cream=ramp((w//8,h//8,w*3//8,h*3//8))
teal=ramp((w*5//8,h//8,w*7//8,h*3//8))
gold=ramp((w//8,h*5//8,w*3//8,h*7//8))
black=ramp((w*5//8,h*5//8,w*7//8,h*7//8))
wall=Image.new('RGBA',(288,104));d=ImageDraw.Draw(wall)
for y in range(104):d.line((0,y,287,y),fill=cream[min(5,max(0,5-y//18))]+(255,))
d.rectangle((0,0,287,3),fill=cream[5]);d.rectangle((0,99,287,103),fill=gold[0])
rng=random.Random(842)
for _ in range(140):
    x,y=rng.randrange(288),rng.randrange(5,81)
    d.point((x,y),fill=cream[min(5,max(0,5-y//18-1))])
for x,y in [(12,18),(269,37),(54,68)]:d.line([(x,y),(x+2,y+3),(x+1,y+7)],fill=cream[0])
wall.save(OUT/'plaster.png')
# Severe principal: tall hat, conspicuous moustache, brass whistle, rigid boots.
sheet=Image.new('RGBA',(24*4,32))
for frame in range(4):
    img=Image.new('RGBA',(24,32));p=ImageDraw.Draw(img);step=[0,1,0,-1][frame]
    p.rectangle((8,2,18,5),fill=black[0]);p.rectangle((8,3,18,4),fill=teal[3]);p.rectangle((5,6,19,7),fill=black[0])
    p.rectangle((7,8,16,14),fill=gold[3]);p.rectangle((7,8,12,11),fill=cream[3]);p.point((7,10),fill=black[0])
    p.rectangle((4,11,8,13),fill=gold[3]);p.line((5,13,17,13),fill=black[0],width=2);p.point((4,12),fill=black[0]);p.point((18,12),fill=black[0])
    p.polygon([(8,15),(17,15),(20,25),(6,25)],fill=teal[2]);p.line((10,15,8,24),fill=teal[5]);p.line((16,15,18,24),fill=teal[0])
    p.rectangle((5,17,7,23),fill=teal[3]);p.rectangle((4,23,7,25),fill=gold[3]);p.rectangle((9,17,12,19),fill=gold[4])
    p.line((10,15,11,17),fill=gold[1]);p.rectangle((7,24,19,25),fill=black[0]);p.point((11,24),fill=gold[4])
    for x,dy in [(8,step),(15,-step)]:
        p.rectangle((x,26,x+3,29+min(0,dy)),fill=black[1]);p.rectangle((x-2,29+min(0,dy),x+3,31+min(0,dy)),fill=black[0]);p.line((x-2,29+min(0,dy),x,29+min(0,dy)),fill=black[5])
    sheet.alpha_composite(img,(frame*24,0))
sheet.save(OUT/'principal_walk.png')
can=Image.new('RGBA',(6,8));d=ImageDraw.Draw(can);d.rectangle((1,2,4,7),fill=teal[3]);d.line((1,2,1,7),fill=teal[5]);d.rectangle((1,4,4,5),fill=cream[2]);d.rectangle((2,0,3,1),fill=black[3]);can.save(OUT/'spray_can.png')
print('Generated native plaster, principal frames and spray can.')

poster=Image.new('RGBA',(28,34));d=ImageDraw.Draw(poster)
d.rectangle((0,0,27,33),fill=gold[0]);d.rectangle((1,1,26,32),fill=cream[4])
d.ellipse((7,5,21,22),fill=gold[3]);d.rectangle((7,4,21,7),fill=black[1]);d.rectangle((11,11,12,12),fill=black[0]);d.rectangle((18,11,19,12),fill=black[0])
d.polygon([(7,16),(13,17),(19,15),(22,17),(13,20),(6,18)],fill=teal[0])
d.polygon([(5,30),(8,23),(22,23),(25,30)],fill=teal[2]);poster.save(OUT/'moustache_poster.png')
