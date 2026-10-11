#!/usr/bin/env python3
"""Replace noisy prison solid fill with installed castle masonry, keeping geometry.
LDtk AutoLayer remains driven by Collision; scaffolds, water and hazards retain
existing art. Add quiet wall texture/windows to the representative assembly hall.
"""
import argparse, copy, datetime, json, re, subprocess, uuid
from pathlib import Path
from ldtk_preserve_json import update
from validate_prison_ldtk import validate
ROOT=Path(__file__).resolve().parents[1]
PATH=ROOT/'ldtk/hooshang_act2.ldtk'
def place_header(p):
 hub=next(r for r in p['levels'] if r['identifier']=='Prison_Hub')
 for l in hub['layerInstances']:
  for e in l['entityInstances']:
   if e['__identifier']=='PrisonSign' and any(f['__value']=='FREE JAMSHID  /  FOUR KEYS' for f in e['fieldInstances']):
    assert e['px'][1] in (292,268), 'Header changed; inspect before moving.'
    e['px'][1]=268;e['__grid'][1]=33;e['__worldY']=hub['worldY']+268

def main(apply, repair_opacity=False):
 if apply: assert 'LDtk.app/Contents/MacOS/LDtk' not in subprocess.check_output(['ps','ax','-o','comm'],text=True), 'Close LDtk first.'
 raw=PATH.read_text();p=json.loads(raw);before=copy.deepcopy(p)
 if any(d['identifier']=='PrisonMasonry' for d in p['defs']['layers']):
  if not repair_opacity: raise SystemExit('Masonry already installed; preserve later hand edits in LDtk.')
  out=ROOT/'output/act2_polish/prison_materials'
  backup=json.loads(sorted(out.glob('before_*.ldtk'))[0].read_text())
  old_hub=next(r for r in backup['levels'] if r['identifier']=='Prison_Hub')
  for d in p['defs']['layers']:
   if d['identifier']=='PrisonMasonry':
    for g in d['autoRuleGroups']:
     for r in g['rules']:r['alpha']=1
  for room in p['levels']:
   for l in room['layerInstances']:
    if l['__identifier']=='PrisonMasonry':
     for t in l['autoLayerTiles']:t['a']=1
    if room['identifier']=='Prison_Hub':
     if l['__identifier']=='Decor':l['gridTiles']=copy.deepcopy(next(a for a in old_hub['layerInstances'] if a['__identifier']=='Decor')['gridTiles'])
     if l['__identifier'] in ('CastleBackground','CastleDecor'):
      l['__opacity']=.17 if l['__identifier']=='CastleBackground' else .5
      for t in l['gridTiles']:t['a']=1
  place_header(p)
  preview=out/'opacity_repair.ldtk';preview.write_text(update(raw,p));validate(preview)
  if apply: PATH.write_text(preview.read_text())
  return
 counter=max(p['nextUid'],*map(int,re.findall(r'"uid":\s*(\d+)',raw)))+1
 def uid():
  nonlocal counter
  v=counter;counter+=1;return v
 defs={d['identifier']:d for d in p['defs']['layers']}
 old=defs['Tiles'];collision=defs['Collision'];sheet=next(t for t in p['defs']['tilesets'] if t['identifier']=='Act2CastleMasonry')
 template=copy.deepcopy(old['autoRuleGroups'][0]['rules'][1]);rules=[]
 def rule(tile,pattern,size=1,x=0,y=0,mod=1,alpha=1):
  r=copy.deepcopy(template);r.update(uid=uid(),pattern=pattern,size=size,tileRectsIds=[[tile]],xModulo=mod,yModulo=mod,xOffset=x,yOffset=y,alpha=alpha);rules.append(r);return r
 cols=sheet['__cWid'];top=rule(4*cols+6,[0,-1,0,0,1,0,0,0,0],3)
 fills={}
 for y in range(8):
  for x in range(8):fills[x,y]=rule((28+y)*cols+28+x,[1],x=x,y=y,mod=8,alpha=1)
 group=copy.deepcopy(old['autoRuleGroups'][0]);group.update(uid=uid(),name='Castle masonry / semantic solid',rules=rules)
 layer=copy.deepcopy(old);layer.update(identifier='PrisonMasonry',uid=uid(),tilesetDefUid=sheet['uid'],autoSourceLayerDefUid=collision['uid'],autoRuleGroups=[group],doc='Solid prison walls. Driven by Collision value 1; scaffolds stay on Tiles.')
 p['defs']['layers'].insert(p['defs']['layers'].index(old),layer)
 for g in old['autoRuleGroups']:g['rules']=[r for r in g['rules'] if r['pattern'][len(r['pattern'])//2]!=1]
 def tile(x,y,sx,sy,cols,alpha=1,rule_id=None,cw=0):
  v=dict(px=[x*8,y*8],src=[sx,sy],f=0,t=sy//8*cols+sx//8,a=alpha,d=[x+y*cw])
  if rule_id is not None:v['d']=[rule_id,0]
  return v
 for room in p['levels']:
  layers={l['__identifier']:l for l in room['layerInstances']};source=layers['Tiles']
  new=copy.deepcopy(source);new.update(__identifier='PrisonMasonry',layerDefUid=layer['uid'],__tilesetDefUid=sheet['uid'],__tilesetRelPath=sheet['relPath'],iid=str(uuid.uuid5(uuid.NAMESPACE_URL,room['iid']+'/prison-masonry')),autoLayerTiles=[],gridTiles=[],entityInstances=[],intGridCsv=[])
  room['layerInstances'].insert(room['layerInstances'].index(source),new)
  if not room['identifier'].startswith('Prison_'):continue
  data=layers['Collision']['intGridCsv'];w=new['__cWid']
  for i,v in enumerate(data):
   if v!=1:continue
   x,y=i%w,i//w;is_top=y==0 or data[i-w]!=1
   r=top if is_top else fills[x%8,y%8];t=r['tileRectsIds'][0][0]
   new['autoLayerTiles'].append(tile(x,y,t%cols*8,t//cols*8,cols,r['alpha'],r['uid']))
  source['autoLayerTiles']=[t for t in source['autoLayerTiles'] if t['t'] not in (0,1)]
  if room['identifier']=='Prison_Hub':
   bg=layers['CastleBackground'];assert not bg['gridTiles'];bg['__opacity']=.17
   for y in range(new['__cHei']):
    for x in range(w):bg['gridTiles'].append(tile(x,y,224+x%8*8,224+y%8*8,cols,1,cw=w))
   windows=layers['CastleDecor'];assert not windows['gridTiles'];windows['__opacity']=.5
   for x0 in [176,432]:
    for dy in range(0,40,8):
     for dx in range(0,32,8):windows['gridTiles'].append(tile((x0+dx)//8,(256+dy)//8,72+dx,104+dy,28,1,cw=w))
 # Collision and all gameplay entities remain byte-for-byte equivalent as data.
 for a,b in zip(before['levels'],p['levels']):
  la={l['__identifier']:l for l in a['layerInstances']};lb={l['__identifier']:l for l in b['layerInstances']}
  assert la['Collision']==lb['Collision'] and la['Entities']==lb['Entities']
  if not a['identifier'].startswith('Prison_'):
   assert all(l==lb[l['__identifier']] for l in a['layerInstances'])
 place_header(p)
 p['nextUid']=counter
 out=ROOT/'output/act2_polish/prison_materials';out.mkdir(parents=True,exist_ok=True)
 preview=out/'preview.ldtk';preview.write_text(update(raw,p));validate(preview)
 if apply:
  assert 'LDtk.app/Contents/MacOS/LDtk' not in subprocess.check_output(['ps','ax','-o','comm'],text=True),'Close LDtk first.'
  (out/('before_'+datetime.datetime.now().strftime('%Y%m%d_%H%M%S')+'.ldtk')).write_text(raw)
  PATH.write_text(preview.read_text())
 print('Masonry installed; semantic collision, entities and non-prison visuals preserved.')
if __name__=='__main__':
 parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('--apply',action='store_true');parser.add_argument('--repair-opacity',action='store_true');args=parser.parse_args();main(args.apply,args.repair_opacity)
