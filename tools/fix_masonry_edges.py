"""Repair visible-terrain grouping and rebake affected masonry, preserving geometry.
Close this project in LDtk before running. Safe to rerun: valid variants stay put.
"""
import json, copy, random
from pathlib import Path
from ldtk_add_ceiling_tile import object_span, array_end, block
ROOT=Path(__file__).resolve().parents[1]
VISIBLE=2000 # LDtk IntGrid group uid 1: (uid + 1) * 1000

def configure(layer):
 group=next(g for g in layer['intGridValuesGroups'] if g['uid']==1)
 group['identifier']='VisibleTerrain'
 for value in layer['intGridValues']:
  if 2<=value['value']<=8:value['groupUid']=1
 for g in layer['autoRuleGroups']:
  if not g['name'].startswith(('brick_new /','stone /')):continue
  for r in g['rules']:
   r['pattern']=[VISIBLE if v==1000001 else -VISIBLE if v==-1000001 else v for v in r['pattern']]
   r['outOfBoundsValue']=7

def matches(rule,cells,w,h,x,y,groups):
 s=rule['size'];radius=s//2
 for i,v in enumerate(rule['pattern']):
  if v==0:continue
  xx,yy=x+i%s-radius,y+i//s-radius
  actual=cells[yy*w+xx] if 0<=xx<w and 0<=yy<h else rule['outOfBoundsValue']
  if abs(v)==1000001:ok=actual!=0
  elif abs(v)>=1000:ok=groups.get(actual)==abs(v)//1000-1
  else:ok=actual==abs(v)
  if ok!=(v>0):return False
 return True

def repair():
 path=ROOT/'ldtk/hooshang_act1.ldtk';text=path.read_text();p=json.loads(text);original=copy.deepcopy(p)
 ld=next(l for l in p['defs']['layers'] if l['identifier']=='Collisions');configure(ld)
 rules=[r for g in ld['autoRuleGroups'] if g['active'] and g['name'].startswith(('brick_new /','stone /')) for r in g['rules'] if r['active']]
 groups={v['value']:v['groupUid'] for v in ld['intGridValues']}
 replacements=[];a,b=object_span(text,text.index('"identifier": "Collisions"'));depth=len(text[text.rfind('\n',0,a)+1:a]);replacements.append((a,b,block(ld,depth).lstrip('\t')))
 changed=0
 for level in p['levels']:
  for li in level['layerInstances']:
   if li['__identifier']!='Collisions':continue
   w,h=li['__cWid'],li['__cHei'];cells=li['intGridCsv'];old={tuple(t['px']):t for t in li['autoLayerTiles']};new=[]
   for i,value in enumerate(cells):
    if value not in (7,8):continue
    x,y=i%w,i//w;prior=old.pop((x*8,y*8),None)
    r=next(r for r in rules if matches(r,cells,w,h,x,y,groups));ids=[t[0] for t in r['tileRectsIds']]
    if prior and prior['t'] in ids:new.append(prior);continue
    t=random.Random(f"{li['seed']}:{r['uid']}:{x}:{y}").choice(ids)
    new.append(dict(px=[x*8,y*8],src=[t*8,0],f=0,t=t,a=1,d=[r['uid'],x,y]));changed+=1
   result=list(old.values())+new
   result.sort(key=lambda t:(t['px'][1],t['px'][0]))
   li['autoLayerTiles']=result
   pos=text.index('"iid": "'+li['iid']+'"');start,end=object_span(text,pos)
   key=text.index('"autoLayerTiles":',start,end);arr=text.index('[',key);last=array_end(text,arr)
   replacements.append((arr,last+1,'[\n'+',\n'.join('\t'*6+json.dumps(t,separators=(',',':')) for t in result)+'\n'+'\t'*5+']'))
 for a,b,s in sorted(replacements,reverse=True):text=text[:a]+s+text[b:]
 assert json.loads(text)==p
 for before,after in zip(original['levels'],p['levels']):
  for bl,al in zip(before['layerInstances'],after['layerInstances']):assert bl['intGridCsv']==al['intGridCsv']
 path.write_text(text);print('Repaired edge selections:',changed)
if __name__=='__main__':repair()
