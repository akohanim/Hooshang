#!/usr/bin/env python3
"""One-time authoring reset. Preserve map/IDs and connections; archive first."""
import copy,json,subprocess
from pathlib import Path
import jsonschema
from ldtk_preserve_json import update
ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'output/castle_authoring_reset';PATH=ROOT/'ldtk/hooshang_act2.ldtk'
def apertures(project):
 rooms=[r for r in project['levels'] if r['identifier'].startswith('Prison_')]; edges=[]
 def value(r,x,y):
  l=next(l for l in r['layerInstances'] if l['__identifier']=='Collision')
  return l['intGridCsv'][(y-r['worldY'])//8*l['__cWid']+(x-r['worldX'])//8]
 for a in rooms:
  for b in rooms:
   for axis in ['x','y']:
    horizontal=axis=='x'; pos='worldX' if horizontal else 'worldY';size='pxWid' if horizontal else 'pxHei';other='worldY' if horizontal else 'worldX';extent='pxHei' if horizontal else 'pxWid'
    seam=a[pos]+a[size]
    if seam!=b[pos]:continue
    start=max(a[other],b[other]);end=min(a[other]+a[extent],b[other]+b[extent]);run=None
    for c in range(start,end+8,8):
     opened=c<end and (value(a,seam-4,c+4) if horizontal else value(a,c+4,seam-4)) in [0,4] and (value(b,seam+4,c+4) if horizontal else value(b,c+4,seam+4)) in [0,4]
     if opened and run is None:run=c
     if not opened and run is not None:
      if c-run>=24:edges.append(dict(a=a['identifier'],b=b['identifier'],axis=axis,seam=seam,start=run,end=c))
      run=None
 return edges

def main():
 assert 'LDtk.app/Contents/MacOS/LDtk' not in subprocess.check_output(['ps','ax','-o','comm'],text=True),'Close LDtk before editing source'
 OUT.mkdir(parents=True,exist_ok=True);backup=OUT/'before.ldtk';assert not backup.exists(),'Already applied; do not overwrite hand edits'
 raw=PATH.read_text();p=json.loads(raw);before=copy.deepcopy(p);edges=apertures(p);backup.write_text(raw)
 rooms={r['identifier']:r for r in p['levels'] if r['identifier'].startswith('Prison_')};placements=[];removed={}
 for name,r in rooms.items():
  w,h=r['pxWid']//8,r['pxHei']//8;layers={l['__identifier']:l for l in r['layerInstances']};old=layers['Collision']['intGridCsv']
  grid=[0]*(w*h)
  # Keep the existing outer perimeter, including all non-map passage mouths.
  for y in range(h):
   for x in range(w):
    if x in [0,w-1] or y in [0,h-1]:grid[y*w+x]=1 if old[y*w+x]==1 else 0
  for l in r['layerInstances']:
   if l['__identifier']=='CastleBackground':continue # flat room backdrop
   l['gridTiles']=[t for t in l['gridTiles'] if t['t']==16] if l['__identifier']=='Decor' else [];l['autoLayerTiles']=[]
   if l['intGridCsv']:l['intGridCsv']=[0]*len(l['intGridCsv'])
  layers['Collision']['intGridCsv']=grid
  es=layers['Entities']['entityInstances'];keep={'PlayerSpawn','Cage','Jamshid','Key','CastlePassage'}
  removed[name]=[e['__identifier'] for e in es if e['__identifier'] not in keep];es[:]=[e for e in es if e['__identifier'] in keep]
  for e in es:
   if e['__identifier'] in ['PlayerSpawn','Key','Cage','Jamshid','CastlePassage']:
    e['px'][1]=r['pxHei']-8-(6 if e['__identifier']=='PlayerSpawn' else 8 if e['__identifier']=='Key' else e['height']//2 if e['__identifier']=='Cage' else 0)
    if e['__identifier']=='PlayerSpawn':e['px'][0]=48
    e['__grid']=[v//8 for v in e['px']];e['__worldX']=r['worldX']+e['px'][0];e['__worldY']=r['worldY']+e['px'][1]
 for edge in edges:
  if edge['axis']!='y':continue
  upper,lower=rooms[edge['a']],rooms[edge['b']]
  for r,y in [(upper,upper['pxHei']-16),(lower,24)]:
   x=edge['start']-r['worldX'];l=next(l for l in r['layerInstances'] if l['__identifier']=='Collision');w=r['pxWid']//8
   for xx in range(x//8,x//8+2):l['intGridCsv'][y//8*w+xx]=2
   placements.append(dict(room=r['identifier'],ledge=[x,y,16,8],descent_gap=[x+16,y,edge['end']-edge['start']-16,8],role='catch' if r==upper else 'launch'))
 defs={d['identifier']:d for d in p['defs']['layers']};rules=[a for g in defs['PrisonMasonry']['autoRuleGroups'] for a in g['rules']];cols=next(t['__cWid'] for t in p['defs']['tilesets'] if t['identifier']=='Act2CastleMasonry')
 for r in rooms.values():
  ls={l['__identifier']:l for l in r['layerInstances']};grid=ls['Collision']['intGridCsv'];w=r['pxWid']//8
  for i,v in enumerate(grid):
   if not v:continue
   x,y=i%w,i//w
   if v==1:
    rule=next(a for a in rules if a['size']==3) if y==0 or grid[i-w]!=1 else next(a for a in rules if a['size']==1 and a['xOffset']==x%8 and a['yOffset']==y%8);target=ls['PrisonMasonry'];c=cols
   else:
    rule=next(a for g in defs['Tiles']['autoRuleGroups'] for a in g['rules'] if a['pattern']==[2]);target=ls['Tiles'];c=16
   t=rule['tileRectsIds'][0][0];target['autoLayerTiles'].append(dict(px=[x*8,y*8],src=[t%c*8,t//c*8],t=t,f=0,a=1,d=[rule['uid'],i]))
 assert apertures(p)==edges,'Room connections changed'
 for a,b in zip(before['levels'],p['levels']):
  for k in ['identifier','iid','uid','worldX','worldY','pxWid','pxHei']:assert a[k]==b[k]
  if not a['identifier'].startswith('Prison_'):assert a==b
 jsonschema.validate(p,json.loads((ROOT/'tools/ldtk_1_5_3.schema.json').read_text()))
 PATH.write_text(update(raw,p));(OUT/'connections.json').write_text(json.dumps(edges,indent=2));(OUT/'ledges.json').write_text(json.dumps(placements,indent=2));(OUT/'removed.json').write_text(json.dumps(removed,indent=2))
 print(f'Cleared {len(rooms)} interiors, preserved {len(edges)} undirected connections; {len(placements)} threshold ledges. Backup: {backup}')
if __name__=='__main__':main()
