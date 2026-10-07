#!/usr/bin/env python3
"""Read a user-owned Celeste A-side map; emit structural evidence, never game art.
Decoder adapted from the local read_celeste.py research utility.
Boundary apertures are candidates, NOT a playability or direction proof.
"""
from pathlib import Path
import struct,json,collections,statistics
class Reader:
 def __init__(self,p): self.b=p.read_bytes();self.i=0;self.lookup=[]
 def read(self,n):b=self.b[self.i:self.i+n];self.i+=n;assert len(b)==n;return b
 def unpack(self,f):return struct.unpack('<'+f,self.read(struct.calcsize('<'+f)))[0]
 def string(self):
  n=0;shift=0
  while True:
   c=self.unpack('B');n|=(c&127)<<shift;shift+=7
   if c<128:break
  return self.read(n).decode('utf-8')
 def val(self):
  t=self.unpack('B')
  if t==0:return bool(self.unpack('B'))
  if t in (1,2,3,4):return self.unpack({1:'B',2:'h',3:'i',4:'f'}[t])
  if t==5:return self.lookup[self.unpack('H')]
  if t==6:return self.string()
  if t==7:
   raw=self.read(self.unpack('h'));return ''.join(chr(raw[i+1])*raw[i] for i in range(0,len(raw),2))
  raise ValueError((t,self.i))
 def node(self):
  name=self.lookup[self.unpack('H')];attrs={}
  for _ in range(self.unpack('B')):
   key=self.lookup[self.unpack('H')];attrs[key]=self.val()
  return dict(name=name,attrs=attrs,children=[self.node() for _ in range(self.unpack('H'))])
 def parse(self):
  assert self.string()=='CELESTE MAP';name=self.string();self.lookup=[self.string() for _ in range(self.unpack('H'))];root=self.node();assert self.i==len(self.b);return name,root

if __name__ == '__main__':
 import argparse, hashlib
 parser=argparse.ArgumentParser(description=__doc__)
 parser.add_argument('map', type=Path)
 parser.add_argument('--output', type=Path, required=True)
 args=parser.parse_args()
 name,data=Reader(args.map).parse()
 levels=next(n['children'] for n in data['children'] if n['name']=='levels')
 def children(l, name): return next((n['children'] for n in l['children'] if n['name']==name), [])
 def tile(l,x,y):
  a=l['attrs']; rows=next(n['attrs'].get('innerText','') for n in l['children'] if n['name']=='solids').splitlines()
  x=(x-a['x'])//8; y=(y-a['y'])//8
  return rows[y][x] if 0<=y<len(rows) and 0<=x<len(rows[y]) else '0'
 rooms=[]; edges=[]; widths=[]
 for i,l in enumerate(levels):
  a=l['attrs']; es=children(l,'entities')
  rooms.append(dict(id=a['name'][4:],size_tiles=[a['width']//8,a['height']//8],
   entity_counts=dict(collections.Counter(e['name'] for e in es)),
   gates=[dict(entity=e['name'], **e['attrs']) for e in es if e['name'] in ['key','lockBlock','colorSwitch','clutterDoor','exitBlock','invisibleBarrier','checkpoint']],
   platforms=[dict(entity=e['name'], **e['attrs']) for e in es if e['name'] in ['jumpThru','sinkingPlatform','crumbleBlock','movingPlatform']]))
  widths.extend(e['attrs']['width']/8 for e in es if e['name'] in ['jumpThru','sinkingPlatform','crumbleBlock','movingPlatform'])
  for m in levels[i+1:]:
   b=m['attrs']; openings=[]; axis=None
   if a['x']+a['width']==b['x'] or b['x']+b['width']==a['x']:
    left,right=(l,m) if a['x']<b['x'] else (m,l); x=right['attrs']['x']; axis='vertical seam'
    openings=[y for y in range(max(a['y'],b['y']),min(a['y']+a['height'],b['y']+b['height']),8) if tile(left,x-8,y)=='0' and tile(right,x,y)=='0']
   elif a['y']+a['height']==b['y'] or b['y']+b['height']==a['y']:
    top,bot=(l,m) if a['y']<b['y'] else (m,l); y=bot['attrs']['y']; axis='horizontal seam'
    openings=[x for x in range(max(a['x'],b['x']),min(a['x']+a['width'],b['x']+b['width']),8) if tile(top,x,y-8)=='0' and tile(bot,x,y)=='0']
   if openings:
    runs=[]
    for v in openings:
     if not runs or v!=runs[-1][-1]+8:runs.append([])
     runs[-1].append(v)
    edges.append(dict(a=a['name'][4:],b=b['name'][4:],axis=axis,aperture_runs_tiles=[len(r) for r in runs]))
 out=dict(source=str(args.map),sha256=hashlib.sha256(args.map.read_bytes()).hexdigest(),room_count=len(rooms),
  median_room_tiles=[statistics.median(r['size_tiles'][i] for r in rooms) for i in [0,1]],
  platform_width_tiles=dict(count=len(widths),min=min(widths),median=statistics.median(widths),max=max(widths)),
  rooms=rooms,boundary_candidates=edges)
 args.output.parent.mkdir(parents=True,exist_ok=True)
 args.output.write_text(json.dumps(out,indent=2)+'\n')
 print(f"{len(rooms)} rooms; {len(edges)} boundary candidates; {len(widths)} platform measurements")
