#!/usr/bin/env python3
"""Bootstrap original, editable LDtk escape rooms. Existing rooms stay byte-equivalent as data."""
import copy, json, uuid, subprocess, argparse
from pathlib import Path
from ldtk_preserve_json import update
from validate_prison_ldtk import validate
ROOT=Path(__file__).resolve().parents[1]
PATH=ROOT/'ldtk/hooshang_act2.ldtk'
NAMES=[f'Act_2_Level_{n}' for n in range(16,20)]
def build(apply=False):
    if apply and 'LDtk.app/Contents/MacOS/LDtk' in subprocess.check_output(['ps','ax','-o','comm'],text=True): raise SystemExit('Close LDtk before editing.')
    raw=PATH.read_text();p=json.loads(raw);old=copy.deepcopy(p['levels'])
    if any(r['identifier'] in NAMES for r in old): raise SystemExit('Chase already exists; edit LDtk directly.')
    uid=p['nextUid']+1
    defs={d['identifier']:d for d in p['defs']['entities']}
    d=copy.deepcopy(defs['Act2StoryScene'])
    d.update(identifier='ChaseGuide',uid=uid,width=16,height=24,pivotX=.5,pivotY=1,doc='Jamshid waiting point. Order is left-to-right. No collision or unlock.')
    d['fieldDefs']=[];defs['ChaseGuide']=d;p['defs']['entities'].append(d);uid+=1
    sheets={d['uid']:d for d in p['defs']['tilesets']}
    def iid(s):return str(uuid.uuid5(uuid.NAMESPACE_URL,'hooshang-friendly-chase-'+s))
    def field(d,v):return dict(__identifier=d['identifier'],__type=d['__type'],__value=v,__tile=None,defUid=d['uid'],realEditorValues=[] if v is None else [dict(id='V_Bool' if d['__type']=='Bool' else 'V_String',params=[v])])
    template=next(r for r in old if r['identifier']=='Act_2_Level_15')
    specs=[
      (16,640,'EscapeRooftops',[(0,200,104),(104,184,64),(168,168,80),(248,224,16),(264,200,32),(296,184,80),(376,208,40),(416,168,80),(496,184,64),(560,200,80)],[(136,184),(216,168),(344,184),(456,168),(592,200)]),
      (17,640,'EscapeAlleys',[(0,200,96),(96,216,96),(192,200,80),(272,184,72),(344,208,80),(424,192,72),(496,176,64),(560,200,80)],[(144,216),(304,184),(464,192),(592,200)]),
      (18,640,'EscapePond',[(0,184,112),(112,224,176),(288,184,56),(344,224,168),(512,184,128)],[(80,184),(312,184),(560,184)]),
      (19,480,'EscapeWall',[(0,200,480)],[(304,200)])]
    for n,w,wing,rects,guides in specs:
        r=copy.deepcopy(template);name=f'Act_2_Level_{n}'
        r.update(identifier=name,iid=iid(name),uid=uid,worldX=(n-16)*640,worldY=2200,pxWid=w,pxHei=240,__neighbours=[],fieldInstances=[field(d,wing if d['identifier']=='wing' else False) for d in p['defs']['levelFields']]);uid+=1
        layers={}
        for l in r['layerInstances']:
            l.update(iid=iid(name+l['__identifier']),levelId=r['uid'],__cWid=w//8,__cHei=30,entityInstances=[],gridTiles=[],autoLayerTiles=[],seed=n)
            l['intGridCsv']=[0]*(w//8*30) if l['__type']=='IntGrid' else []
            layers[l['__identifier']]=l
        def entity(kind,x,y,**vals):
            d=defs[kind];layer=layers['Entities']
            fields=[field(f,vals.get(f['identifier'],f['defaultOverride']['params'][0] if f.get('defaultOverride') else None)) for f in d['fieldDefs']]
            layer['entityInstances'].append(dict(__identifier=kind,__grid=[x//8,y//8],__pivot=[d['pivotX'],d['pivotY']],__tags=d['tags'],__tile=d['tileRect'],__smartColor=d['color'],iid=iid(name+kind+str(len(layer['entityInstances']))),width=d['width'],height=d['height'],defUid=d['uid'],px=[x,y],fieldInstances=fields,__worldX=r['worldX']+x,__worldY=r['worldY']+y))
        def tile(layer,x,y,sx,sy):
            l=layers[layer];sheet=sheets[l['__tilesetDefUid']]
            l['gridTiles'].append(dict(px=[x,y],src=[sx,sy],f=0,t=sx//8+sy//8*(sheet['pxWid']//8),a=1,d=[x//8+y//8*l['__cWid']]))
        occupied=set()
        for x,y,width in rects:
            occupied.update((xx,yy) for yy in range(y,240,8) for xx in range(x,x+width,8))
        if n==18:
            for x,y,width in [(160,160,48),(232,144,40),(384,160,48),(456,160,32)]:
                occupied.update((xx,y) for xx in range(x,x+width,8))
        for x,y in sorted(occupied):
            sx,sy=(48,32) if (x,y-8) not in occupied else (48+x//8%2*8,48+y//8%2*8)
            tile('CastleTerrain',x,y,sx,sy)
        # Recessed facades are scenery, safely separate from cream-edged platforms.
        if n in [16,17]:
            for bx,by,bw,bh in ([(144,72,88,96),(408,64,80,104)] if n==16 else [(192,56,72,144),(424,48,72,144)]):
                for y in range(by,by+bh,8):
                    for x in range(bx,bx+bw,8):tile('CastleBackground',x,y,224+(x-bx)%64,224+(y-by)%64)
                for y in range(0,40,8):
                    for x in range(0,32,8):tile('CastleDecor',bx+16+x,by+24+y,72+x,104+y)
        water=layers['Water'];cw=w//8;g=water['intGridCsv']
        if n==18:
            for a,b in [(112,288),(344,512)]:
                for y in range(184,224,8):
                    for x in range(a,b,8):g[y//8*cw+x//8]=1
            def wet(x,y):return 0<=x<cw and 0<=y<30 and g[y*cw+x]==1
            for i,v in enumerate(g):
                if not v:continue
                x,y=i%cw,i//cw;top,bottom,left,right=not wet(x,y-1),not wet(x,y+1),not wet(x-1,y),not wet(x+1,y)
                t=3 if (top or bottom) and (left or right) else 1 if top or bottom else 2 if left or right else 0
                water['autoLayerTiles'].append(dict(px=[x*8,y*8],src=[t*8,0],t=t,f=(1 if right and not left else 0)+(2 if bottom and not top else 0),a=1,d=[{3:236,1:237,2:238,0:239}[t],i]))
        entity('PlayerStart',32,rects[0][1]-6)
        if n<19:entity('Exit',w-24,rects[-1][1]-32,NextRoom=f'Act_2_Level_{n+1}')
        for x,y in guides:entity('ChaseGuide',x,y)
        if n==16:entity('Lemon',448,136)
        if n==17:entity('Lemon',528,144)
        if n==18:entity('Lemon',256,120);entity('Lemon',432,208)
        p['levels'].append(r)
    p['nextUid']=uid
    assert p['levels'][:len(old)]==old,'Existing room changed'
    out=ROOT/'output/act2_polish/chase';out.mkdir(parents=True,exist_ok=True)
    preview=out/'chase_preview.ldtk';preview.write_text(update(raw,p));validate(preview)
    if apply:
        (out/'before_chase.ldtk').write_text(raw);PATH.write_text(preview.read_text())
    print('Installed' if apply else 'Previewed',NAMES)
if __name__=='__main__':
    a=argparse.ArgumentParser();a.add_argument('--apply',action='store_true');build(a.parse_args().apply)
