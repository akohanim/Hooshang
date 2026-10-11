#!/usr/bin/env python3
"""Research-only schematic from the local binary. Not Celeste game artwork."""
from pathlib import Path
import argparse,sys
from PIL import Image,ImageDraw
from analyze_celeste_ch3 import Reader
p=argparse.ArgumentParser();p.add_argument('map',type=Path);p.add_argument('--out',type=Path,required=True);args=p.parse_args()
_,data=Reader(args.map).parse();levels=next(n['children'] for n in data['children'] if n['name']=='levels');args.out.mkdir(parents=True,exist_ok=True)
for l in levels:
 a=l['attrs'];name=a['name'][4:]
 if name not in ['02-b','09-b','11-c','12-d','10-z','08-d','11-x']:continue
 im=Image.new('RGB',(a['width'],a['height']),(20,25,34));d=ImageDraw.Draw(im)
 rows=next(n['attrs'].get('innerText','') for n in l['children'] if n['name']=='solids').splitlines()
 for y,row in enumerate(rows):
  for x,v in enumerate(row):
   if v!='0':d.rectangle((x*8,y*8,x*8+7,y*8+7),fill=(95,103,116))
 es=next(n['children'] for n in l['children'] if n['name']=='entities')
 colors={'redBlocks':'#8b4646','greenBlocks':'#42724f','yellowBlocks':'#8c793c'}
 for e in es:
  t=e['name'];p=e['attrs'];x=p.get('x',0);y=p.get('y',0);w=p.get('width',8);h=p.get('height',8)
  if t in colors:d.rectangle((x,y,x+w-1,y+h-1),fill=colors[t])
 for e in es:
  t=e['name'];p=e['attrs'];x=p.get('x',0);y=p.get('y',0);w=p.get('width',8);h=p.get('height',8)
  nodes=[n['attrs'] for n in e['children'] if n['name']=='node']
  if 'Spinner' in t or t=='spinner':
   for n in nodes:d.line((x,y,n['x'],n['y']),fill='#ed8b90')
   d.ellipse((x-4,y-4,x+4,y+4),fill='#ff586d')
  elif t in ['jumpThru','sinkingPlatform','crumbleBlock']:d.rectangle((x,y,x+w,y+3),fill='#e4d3ac')
  elif t in ['switchGate','lockBlock','clutterDoor']:
   d.rectangle((x,y,x+w-1,y+h-1),outline='#fbc94f',width=2)
   for n in nodes:d.line((x,y,n['x'],n['y']),fill='#fbc94f')
  elif t in ['key','touchSwitch','colorSwitch']:d.ellipse((x-4,y-4,x+4,y+4),fill='#ffe46c')
  elif t=='refill':d.polygon([(x,y-4),(x+4,y),(x,y+4),(x-4,y)],fill='#80efc7')
  elif t=='player':d.rectangle((x-2,y-8,x+2,y),fill='#f4f4f4')
  elif t.startswith(('spikes','triggerSpikes')):d.rectangle((x,y,x+w-1,y+h-1),outline='#ec759d')
 im.resize((im.width*3,im.height*3),Image.Resampling.NEAREST).save(args.out/(name+'.png'))
print('Saved seven binary structure schematics; colors identify entity families, not game art.')
