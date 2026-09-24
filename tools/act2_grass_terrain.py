"""Act 2 connected terrain: distinct rims over one shared ochre earth texture.
Keeps existing atlas slots; grass appends 195 tiles at 739. Source bitmap is
used only for palette sampling; every final pixel is drawn on the 8px grid.
"""
import copy, colorsys, json, random, re
from collections import Counter
from pathlib import Path
from PIL import Image, ImageDraw
import build_material_lab as topology
from fix_masonry_edges import matches
from ldtk_add_ceiling_tile import object_span, array_end, block, ldtk_running
ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'ldtk/art/act2_materials'
STARTS={'brick_new':26,'stone':221,'stone_grey':544,'grass':739}
VALUES={2:'brick',3:'ceiling_flor',4:'ceiling',7:'brick_new',8:'stone',9:'stone_grey',10:'grass'}
COUNT=934

def palette():
    counts=Counter(Image.open(OUT/'source/grass_earth.png').convert('RGB').getdata())
    def sample(lo,hi):
        cols=[]
        for c,n in counts.most_common():
            h,s,v=colorsys.rgb_to_hsv(*(x/255 for x in c))
            if lo<h<hi and s>.30 and .3<v<=1: cols.append(c)
        cols=sorted(cols[:32],key=lambda c:sum(a*b for a,b in zip(c,(.299,.587,.114))))
        assert len(cols)>=3
        return [cols[round((len(cols)-1)*f)] for f in (.08,.32,.62,.9)]
    green=sample(.19,.46);soil=sample(.08,.17)
    green=[tuple(round(c*.36) for c in green[0]),green[0],green[1],green[2]]
    soil=[soil[0],soil[1],soil[3],tuple(round(c*.68+255*.32) for c in soil[3])]
    return green,soil

def earth(v,soil):
    im=Image.new('RGBA',(8,8),soil[2]+(255,))
    # Quiet repeating soil, two flecks per tile. Identical for EVERY material.
    d=ImageDraw.Draw(im)
    for x,y in [((v*3+1)%7,(v*5+1)%6),((v*5+5)%7,(v*3+4)%6)]:
        d.line((x,y,x,y+1),fill=soil[3]+(255,))
        d.point((x+1,y+1),fill=soil[1]+(255,))
    return im

def draw(name,mask,v,ramps,green,soil):
    im=earth(v,soil);d=ImageDraw.Draw(im)
    p=ramps.get(name,soil)
    exposed=[s for s in range(4) if not(mask>>s&1)]
    for side in exposed:
        for u in range(8):
            if name=='grass' and side==0:
                depth=[3,3,4,4,3,3,4,3][u]
                for z in range(depth):
                    col=green[0] if z==0 or z==depth-1 else green[3] if z==1 else green[1]
                    d.point((u,z),fill=col+(255,))
            else:
                depth=2 if name=='grass' else 3+(u+v)%2
                for z in range(depth):
                    x,y=[(u,z),(7-z,u),(u,7-z),(z,u)][side]
                    if name=='grass': col=soil[0] if z==0 else soil[1]
                    elif name=='brick_new':
                        joint=y%4==3 or (x+(y//4)*4+v*2)%8==0
                        col=p[1] if joint else p[4] if y%4==0 else p[3] if z<2 else p[2]
                    else: col=p[4] if side==0 and z==0 else p[3] if z<2 else p[2]
                    d.point((x,y),fill=col+(255,))
    for bit,a,b,x,y in [(4,0,3,0,0),(5,0,1,7,0),(6,1,2,7,7),(7,2,3,0,7)]:
        if mask>>a&1 and mask>>b&1 and not mask>>bit&1:
            color=green[0] if name=='grass' else p[3]
            d.point((x,y),fill=color+(255,))
            d.point((x+(1 if x==0 else -1),y),fill=soil[1]+(255,))
    for a,b,x,y in [(0,3,0,0),(0,1,7,0),(2,1,7,7),(2,3,0,7)]:
        if a in exposed and b in exposed:d.point((x,y),fill=(0,0,0,0))
    return im

def build(ramps):
    path=OUT/'terrain.png';old=Image.open(path).convert('RGBA')
    sheet=Image.new('RGBA',(COUNT*8,8));sheet.paste(old,(0,0))
    green,soil=palette()
    for name,start in STARTS.items():
        tiles=[]
        for mask in topology.MASKS:
            if mask!=255:tiles += [draw(name,mask,v,ramps,green,soil) for v in range(4)]
        tiles += [earth(v,soil) for v in range(10)]+[earth(0,soil)]
        assert len(tiles)==195
        contact=Image.new('RGBA',(128,104))
        for i,tile in enumerate(tiles):
            sheet.paste(tile,((start+i)*8,0));contact.paste(tile,(i%16*8,i//16*8))
        contact.save(OUT/(name+'.png'))
    # Keep legacy art slots valid for manually placed tiles as well.
    for i,mask in [(0,255),(1,254),(2,247),(3,246)]:
        sheet.paste(draw('brick_new',mask,0,ramps,green,soil),(i*8,0))
    for i in range(4,26):sheet.paste(draw('stone_grey',254,0,ramps,green,soil),(i*8,0))
    sheet.save(path)
    return green,soil

def install():
    assert not ldtk_running(), 'Close LDtk before installing terrain rules'
    path=ROOT/'ldtk/hooshang_act2.ldtk';text=path.read_text();p=json.loads(text)
    before=copy.deepcopy(p)
    layer=next(l for l in p['defs']['layers'] if l['identifier']=='Collisions')
    topology.uid=max(p['nextUid'],max(map(int,re.findall(r'"uid":\s*(\d+)',text))))
    green,soil=palette()
    if not any(v['value']==10 for v in layer['intGridValues']):
        layer['intGridValues'].append(dict(value=10,identifier='grass',color='#%02X%02X%02X'%green[2],tile=None,groupUid=1))
    assert next(v for v in layer['intGridValues'] if v['value']==10)['identifier']=='grass'
    layer['autoRuleGroups']=[g for g in layer['autoRuleGroups'] if g['name'].startswith('scaffolding /')]
    for value,name in VALUES.items():
        material='brick_new' if value==2 else 'stone_grey' if value in (3,4) else name
        start=STARTS[material];mapping={};i=0
        for mask in topology.MASKS:
            if mask==255:continue
            mapping[mask]=list(range(start+i,start+i+4));i+=4
        gs=topology.groups(name,value,mapping,list(range(start+184,start+194)),start+194)
        for g in gs:
            for r in g['rules']:
                r['pattern']=[2000 if v==1000001 else -2000 if v==-1000001 else v for v in r['pattern']]
                r['outOfBoundsValue']=value
        layer['autoRuleGroups']+=gs
    ts=next(t for t in p['defs']['tilesets'] if t['uid']==206)
    ts.update(pxWid=COUNT*8,__cWid=COUNT,cachedPixelData=None)
    p['nextUid']=topology.uid+1
    groups={v['value']:v['groupUid'] for v in layer['intGridValues']}
    rules=[r for g in layer['autoRuleGroups'] if g['active'] for r in g['rules'] if r['active']]
    for room in p['levels']:
        # LDtk d is [rule_uid, linear_cell_id], NOT [rule_uid, x, y].
        # The editor erases cached artwork by linear_cell_id.
        # Imported level scenes share one directory across all Acts.
        if room['identifier']=='Level_2':room['identifier']='Act_2_Level_2'
        for li in room['layerInstances']:
            if li['__identifier']!='Collisions':continue
            rebake_layer(li,rules,groups)
    text=serialize_project(text,p,before)
    for old,new in zip(before['levels'],p['levels']):
        for a,b in zip(old['layerInstances'],new['layerInstances']):
            assert a['intGridCsv']==b['intGridCsv'] and a['entityInstances']==b['entityInstances']
    path.write_text(text)
    print('Installed grass brush and shared-soil terrain; geometry/entities preserved.')


def serialize_project(text,p,before):
    """Keep authored geometry and LDtk's compact per-cell formatting intact."""
    replacements=[]
    for identifier,obj in [('Collisions',next(l for l in p['defs']['layers'] if l['identifier']=='Collisions')),('Act2Bricks8px',next(t for t in p['defs']['tilesets'] if t['uid']==206))]:
        a,b=object_span(text,text.index('"identifier": "'+identifier+'"'))
        depth=len(text[text.rfind('\n',0,a)+1:a]);replacements.append((a,b,block(obj,depth).lstrip('\t')))
    for old,new in zip(before['levels'],p['levels']):
        for old_layer,new_layer in zip(old['layerInstances'],new['layerInstances']):
            if old_layer['intGridCsv']!=new_layer['intGridCsv']:
                a,b=object_span(text,text.index('"iid": "'+old_layer['iid']+'"'))
                key=text.index('"intGridCsv":',a,b);a=text.index('[',key);b=array_end(text,a)+1
                replacements.append((a,b,json.dumps(new_layer['intGridCsv'],separators=(',',':'))))
            if old_layer['autoLayerTiles']==new_layer['autoLayerTiles']:continue
            a,b=object_span(text,text.index('"iid": "'+old_layer['iid']+'"'))
            key=text.index('"autoLayerTiles":',a,b);a=text.index('[',key);b=array_end(text,a)+1
            tiles=new_layer['autoLayerTiles']
            replacements.append((a,b,'[\n'+',\n'.join('\t'*6+json.dumps(t,separators=(',',':')) for t in tiles)+'\n'+'\t'*5+']'))
    for a,b,s in sorted(replacements,reverse=True):text=text[:a]+s+text[b:]
    text=text.replace('"identifier": "Level_2"','"identifier": "Act_2_Level_2"')
    text=re.sub(r'"nextUid": \d+','"nextUid": '+str(p['nextUid']),text,count=1)
    assert json.loads(text)==p
    return text


def rebake_layer(li,rules,groups):
    cells=li['intGridCsv'];w,h=li['__cWid'],li['__cHei']
    # The IntGrid is authoritative. Never retain cached art over erased cells.
    bypos={tuple(t['px']):t for t in li['autoLayerTiles']
           if cells[t['px'][1]//8*w+t['px'][0]//8] not in (0,*VALUES)}
    for i,value in enumerate(cells):
        if value not in VALUES:continue
        x,y=i%w,i//w
        r=next(r for r in rules if matches(r,cells,w,h,x,y,groups))
        tid=random.Random(f'{li["seed"]}:{x}:{y}').choice(r['tileRectsIds'])[0]
        bypos[(x*8,y*8)]=dict(px=[x*8,y*8],src=[tid*8,0],f=0,t=tid,a=1,d=[r['uid'],x+y*w])
    li['autoLayerTiles']=sorted(bypos.values(),key=lambda t:(t['px'][1],t['px'][0]))
