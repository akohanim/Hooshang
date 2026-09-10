"""Install native LDtk scaffold topology/variant rules. Close project first."""
import copy,json,random
from pathlib import Path
from PIL import Image
from gen_scaffolding import connected
from ldtk_add_ceiling_tile import object_span,array_end,block
from fix_masonry_edges import matches
ROOT=Path(__file__).resolve().parents[1]
def run():
 path=ROOT/'ldtk/hooshang_act1.ldtk';text=path.read_text();p=json.loads(text)
 layer=next(l for l in p['defs']['layers'] if l['identifier']=='Collisions')
 oldgroup=next(g for g in layer['autoRuleGroups'] if g['name'].startswith('scaffolding'))
 template=copy.deepcopy(oldgroup['rules'][0]);group=copy.deepcopy(oldgroup);group['name']='scaffolding / connected steel';group['usesWizard']=False;group['rules']=[]
 uid=p['nextUid'];base=416
 for mask in range(16):
  for reinforced in ([True,False] if mask in (5,10) else [True]):
   r=copy.deepcopy(template);r.update(uid=uid,size=3,pattern=[0]*9,flipX=False,flipY=False,outOfBoundsValue=0,chance=0.17 if mask in (5,10) and reinforced else 1)
   uid+=1;r['pattern'][4]=5
   for bit,index in enumerate([1,5,7,3]):r['pattern'][index]=5 if mask&(1<<bit) else -5
   r['tileRectsIds']=[[base+mask*8+v] for v in range(4 if reinforced else 0,8 if reinforced else 4)]
   group['rules'].append(r)
 layer['autoRuleGroups'][layer['autoRuleGroups'].index(oldgroup)]=group;p['nextUid']=uid
 sheetpath=ROOT/'ldtk/art/bricks_8px.png';old=Image.open(sheetpath).convert('RGBA');sheet=Image.new('RGBA',(544*8,8));sheet.paste(old.crop((0,0,base*8,8)),(0,0))
 for mask in range(16):
  for v in range(8):sheet.paste(connected(mask,v),((base+mask*8+v)*8,0))
 sheet.save(sheetpath)
 ts=next(t for t in p['defs']['tilesets'] if t['uid']==32);ts.update(pxWid=544*8,__cWid=544,cachedPixelData=None)
 replacements=[]
 for identifier,obj in [('Collisions',layer),('Bricks8px',ts)]:
  a,b=object_span(text,text.index('"identifier": "'+identifier+'"'));depth=len(text[text.rfind('\n',0,a)+1:a]);replacements.append((a,b,block(obj,depth).lstrip('\t')))
 count=0
 for level in p['levels']:
  for li in level['layerInstances']:
   if li['__identifier']!='Collisions':continue
   cells=li['intGridCsv'];w=li['__cWid'];h=li['__cHei'];paint={(i%w*8,i//w*8) for i,v in enumerate(cells) if v==5}
   result=[t for t in li['autoLayerTiles'] if tuple(t['px']) not in paint]
   for px,py in sorted(paint):
    x,y=px//8,py//8;rng=random.Random(f"scaffold:{li['seed']}:{x}:{y}")
    r=next(r for r in group['rules'] if matches(r,cells,w,h,x,y,{}) and rng.random()<r['chance'])
    t=rng.choice(r['tileRectsIds'])[0];result.append(dict(px=[px,py],src=[t*8,0],f=0,t=t,a=1,d=[r['uid'],x,y]));count+=1
   result.sort(key=lambda t:(t['px'][1],t['px'][0]));li['autoLayerTiles']=result
   start,end=object_span(text,text.index('"iid": "'+li['iid']+'"'));a=text.index('[',text.index('"autoLayerTiles":',start,end));b=array_end(text,a)+1
   replacements.append((a,b,json.dumps(result,separators=(',',':'))))
 for a,b,s in sorted(replacements,reverse=True):text=text[:a]+s+text[b:]
 import re
 text=re.sub(r'"nextUid": \d+', '"nextUid": '+str(uid),text,count=1)
 assert json.loads(text)==p
 path.write_text(text);print('Installed native scaffold rules and rebaked',count,'cells')
if __name__=='__main__':run()
