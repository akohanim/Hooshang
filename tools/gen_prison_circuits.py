#!/usr/bin/env python3
"""Crisp mechanism geometry, palette sampled from the existing Act2 key swatch."""
from pathlib import Path
from collections import Counter
from PIL import Image,ImageDraw
root=Path(__file__).resolve().parents[1]
source=root/'assets/props/prison_circuits/source/material.png'
colors=[c for c,_ in Counter(p[:3] for p in Image.open(source).convert('RGBA').getdata() if p[3]>40).most_common(20)]
colors=[c for c in colors if c[0]>c[1]>c[2]] # Brass hues; exclude the swatch's magenta ornament.
colors.sort(key=lambda c: .299*c[0]+.587*c[1]+.114*c[2])
dark,mid,light=colors[0],colors[len(colors)//2],colors[-1]
im=Image.new('RGBA',(40,16));d=ImageDraw.Draw(im)
for x,lit in [(0,False),(16,True)]:
 # Small inset brass seal; restrained highlights distinguish it from hazards.
 d.rectangle((x+3,3,x+12,12),fill=dark)
 d.rectangle((x+4,4,x+11,11),fill=mid)
 d.line((x+4,4,x+11,4),fill=light)
 d.rectangle((x+5,5,x+10,10),fill=dark)
 if lit:d.line([(x+5,8),(x+7,10),(x+10,6)],fill=light)
 else:d.rectangle((x+7,7,x+8,8),fill=mid)
for bx in [33,37]:
 d.rectangle((bx,0,bx+1,7),fill=dark)
 d.line((bx,0,bx,7),fill=mid)
d.line((32,1,39,1),fill=mid)
d.point((33,1),fill=light);d.point((37,1),fill=light)
im.save(root/'assets/props/prison_circuits/circuit.png')

# Lever positions and relay badge use the same sampled material ramp.
im=Image.new('RGBA',(64,16));d=ImageDraw.Draw(im)
for x,on in [(0,False),(16,True)]:
 d.rectangle((x+3,11,x+12,14),fill=dark)
 d.line((x+4,11,x+11,11),fill=mid)
 end=(x+11 if on else x+4,5)
 d.line([(x+8,11),end],fill=mid,width=2)
 d.rectangle((end[0]-1,3,end[0]+1,5),fill=light)
for x,on in [(32,False),(48,True)]:
 d.rectangle((x+3,3,x+12,12),fill=dark)
 d.rectangle((x+4,4,x+11,11),outline=mid,width=1)
 if on:d.line([(x+5,8),(x+7,10),(x+10,6)],fill=light)
 else:d.rectangle((x+7,7,x+8,8),fill=light)
im.save(root/'assets/props/prison_circuits/timed.png')
