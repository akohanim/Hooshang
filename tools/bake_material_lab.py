"""Bake this library's non-flipped Single rules for reproducible bootstrap/CI.
LDtk remains the normal authoring/baking path. Deliberately rejects unsupported rules.
"""
from pathlib import Path
import json, random
P=Path(__file__).resolve().parents[1]/'ldtk/material_lab/office_materials.ldtk'
def bake():
 p=json.loads(P.read_text()); defs={d['uid']:d for d in p['defs']['layers']}
 for level in p['levels']:
  layers={l['layerDefUid']:l for l in level['layerInstances']}
  for li in layers.values():
   ld=defs[li['layerDefUid']]
   if ld['type']!='AutoLayer': continue
   source=layers[ld['autoSourceLayerDefUid']]; w,h=source['__cWid'],source['__cHei']; cells=source['intGridCsv']; result=[]
   rules=[r for g in ld['autoRuleGroups'] if g['active'] for r in g['rules'] if r['active']]
   for y in range(h):
    for x in range(w):
     if not cells[y*w+x]: continue
     for r in rules:
      assert not r['flipX'] and not r['flipY'] and r['chance']==1 and r['tileMode']=='Single'
      size=r['size']; radius=size//2
      match=True
      for i,v in enumerate(r['pattern']):
       if not v: continue
       xx,yy=x+i%size-radius,y+i//size-radius
       a=cells[yy*w+xx] if 0<=xx<w and 0<=yy<h else r['outOfBoundsValue']
       ok=(a!=0 if v>0 else a==0) if abs(v)==1000001 else (a==v if v>0 else a!=-v)
       if not ok: match=False; break
      if match:
       # Bootstrap seed; LDtk uses its own coordinate hash when the author saves.
       t=random.Random(f"{li['seed']}:{r['uid']}:{x}:{y}").choice(r['tileRectsIds'])[0]
       result.append(dict(px=[x*8,y*8],src=[t%16*8,t//16*8],f=0,t=t,a=1,d=[r['uid'],x,y]))
       if r['breakOnMatch']: break
   li['autoLayerTiles']=result
 P.write_text(json.dumps(p,indent=2)+'\n')
 print('Baked',sum(len(l['autoLayerTiles']) for r in p['levels'] for l in r['layerInstances']),'tiles')
if __name__=='__main__': bake()
