"""Bright Act 2 materials; preserve Act 1 procedural geometry and tile IDs.
Palette comes from the saved PixelLab swatch, never resized into tile geometry.
Run with --install to add paint brushes/rules (LDtk must be closed).
Room geometry is preserved; --install rebakes art using shared-terrain rules.
"""
import copy, json, colorsys, re, sys
from collections import Counter
from pathlib import Path
from PIL import Image
import gen_celeste_masonry as masonry
from gen_scaffolding import connected
from ldtk_add_ceiling_tile import object_span, block, ldtk_running
ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'ldtk/art/act2_materials'

def lum(c): return .299*c[0]+.587*c[1]+.114*c[2]
def ramp(kind):
    source='grey_stone.png' if kind=='stone_grey' else 'materials.png'
    counts=Counter(Image.open(OUT/'source'/source).convert('RGB').getdata())
    def fits(c):
        h,s,v=colorsys.rgb_to_hsv(*(x/255 for x in c))
        if kind=='stone_grey': return s<.20 and .15<v<.98
        return s>.18 and {'brick_new': h<.065 or h>.94, 'stone': .065<=h<.19, 'scaffolding': .36<h<.59}[kind]
    colors=[c for c,n in counts.most_common() if fits(c)][:24]
    assert len(colors)>=3, (kind,colors)
    colors.sort(key=lum)
    # Lift the darkest recesses toward the swatch's body color for sunny Act 2.
    lo=colors[len(colors)//3];hi=colors[-1]
    return [tuple(round(a*(1-t)+b*t) for a,b in zip(lo,hi)) for t in [0,.18,.40,.65,1]]

def recolor(im, palette):
    colors=sorted({c[:3] for c in im.getdata() if c[3]}, key=lum)
    mapping={c:palette[round(i*4/max(1,len(colors)-1))] for i,c in enumerate(colors)}
    result=im.copy();result.putdata([mapping[c[:3]]+(c[3],) if c[3] else c for c in im.getdata()]);return result

def build():
    sheet=Image.new('RGBA',(739*8,8))
    sheet.paste(Image.open(ROOT/'ldtk/art/bricks_8px.png').crop((0,0,26*8,8)),(0,0))
    sheet.paste(Image.open(ROOT/'ldtk/art/act2_tileset_8px.png'),(0,0))
    palettes={k:ramp(k) for k in ['brick_new','stone','scaffolding','stone_grey']}
    # Shared dark accents for masonry mortar; act2_grass_terrain supplies
    # the ochre earth interiors and connected surface rims afterward.
    shared_core=tuple(round(c*.40) for c in palettes['stone_grey'][0])
    shared_infill=tuple(round(c*.52) for c in palettes['stone_grey'][0])
    for name in ('brick_new','stone','stone_grey'):
        palettes[name][0]=shared_core
        palettes[name][1]=shared_infill
    for name,start in [('brick_new',26),('stone',221),('stone_grey',544)]:
        tiles,*_=masonry.make_material('stone' if name=='stone_grey' else name)
        # One palette mapping for the whole material preserves relative shading.
        strip=Image.new('RGBA',(195*8,8))
        for i,t in enumerate(tiles):strip.paste(t,(i*8,0))
        strip=recolor(strip,palettes[name]);sheet.paste(strip,(start*8,0))
        contact=Image.new('RGBA',(128,104))
        for i in range(195):contact.paste(strip.crop((i*8,0,i*8+8,8)),(i%16*8,i//16*8))
        contact.save(OUT/f'{name}.png')
    strip=Image.new('RGBA',(128*8,8))
    for mask in range(16):
        for v in range(8):strip.paste(connected(mask,v),((mask*8+v)*8,0))
    strip=recolor(strip,palettes['scaffolding'])
    # Existing brightest clamp pixels become warm brass highlights.
    gold=palettes['stone'][-1]
    brightest=palettes['scaffolding'][-1]
    strip.putdata([gold+(c[3],) if c[:3]==brightest and c[3] else c for c in strip.getdata()])
    sheet.paste(strip,(416*8,0));sheet.save(OUT/'terrain.png')
    contact=Image.new('RGBA',(128,64))
    for i in range(128):contact.paste(strip.crop((i*8,0,i*8+8,8)),(i//8*8,i%8*8))
    contact.save(OUT/'scaffolding.png')
    from act2_grass_terrain import build as build_grass
    build_grass(palettes)
    return palettes

def install(palettes):
    assert not ldtk_running(), 'Close LDtk before installing materials'
    path=ROOT/'ldtk/hooshang_act2.ldtk';text=path.read_text();p=json.loads(text)
    a=json.loads((ROOT/'ldtk/hooshang_act1.ldtk').read_text())
    old=next(l for l in a['defs']['layers'] if l['identifier']=='Collisions')
    layer=next(l for l in p['defs']['layers'] if l['identifier']=='Collisions')
    if any(v['identifier']=='stone_grey' for v in layer['intGridValues']): return
    uid=max(p['nextUid'],max(map(int,re.findall(r'"uid":\s*(\d+)',text))))+1
    if not any(v['value']==7 for v in layer['intGridValues']):
        for value in old['intGridValues']:
            if value['value'] in (5,7,8):
                val=copy.deepcopy(value);val['color']='#%02X%02X%02X'%palettes[val['identifier']][3];layer['intGridValues'].append(val)
        layer['intGridValuesGroups']=copy.deepcopy(old['intGridValuesGroups'])
        for val in layer['intGridValues']:
            if val['value']>=2:val['groupUid']=1
        for group in old['autoRuleGroups']:
            if not group['name'].startswith(('brick_new /','stone /','scaffolding /')):continue
            group=copy.deepcopy(group);group['uid']=uid;uid+=1
            for rule in group['rules']:rule['uid']=uid;uid+=1
            layer['autoRuleGroups'].append(group)
    assert not any(v['value']==9 for v in layer['intGridValues']), 'IntGrid value 9 is already used'
    layer['intGridValues'].append(dict(value=9,identifier='stone_grey',color='#%02X%02X%02X'%palettes['stone_grey'][3],tile=None,groupUid=1))
    for group in list(layer['autoRuleGroups']):
        if not group['name'].startswith('stone /'): continue
        group=copy.deepcopy(group);group['name']=group['name'].replace('stone /','stone_grey /');group['uid']=uid;uid+=1
        for rule in group['rules']:
            rule['uid']=uid;uid+=1
            rule['pattern']=[9 if v==8 else -9 if v==-8 else v for v in rule['pattern']]
            rule['tileRectsIds']=[[tile+323 for tile in rect] for rect in rule['tileRectsIds']]
        layer['autoRuleGroups'].append(group)
    ts=next(t for t in p['defs']['tilesets'] if t['uid']==206)
    ts.update(relPath='art/act2_materials/terrain.png',pxWid=5912,__cWid=739,cachedPixelData=None)
    replacements=[]
    for identifier,obj in [('Collisions',layer),('Act2Bricks8px',ts)]:
        start,end=object_span(text,text.index('"identifier": "'+identifier+'"'));depth=len(text[text.rfind('\n',0,start)+1:start]);replacements.append((start,end,block(obj,depth).lstrip('\t')))
    # Update redundant instance paths; baked cell IDs remain valid (first 4 preserved).
    for start,end,s in sorted(replacements,reverse=True):text=text[:start]+s+text[end:]
    text=text.replace('"__tilesetRelPath": "art/act2_tileset_8px.png"','"__tilesetRelPath": "art/act2_materials/terrain.png"')
    for room in p['levels']:
        for li in room['layerInstances']:
            if li.get('__tilesetDefUid')==206:li['__tilesetRelPath']='art/act2_materials/terrain.png'
    p['nextUid']=uid;text=re.sub(r'"nextUid": \d+','"nextUid": '+str(uid),text,count=1)
    assert json.loads(text)==p
    path.write_text(text)

if __name__=='__main__':
    palettes=build()
    if '--install' in sys.argv:
        project=json.loads((ROOT/'ldtk/hooshang_act2.ldtk').read_text())
        values=next(l for l in project['defs']['layers'] if l['identifier']=='Collisions')['intGridValues']
        if {v['identifier'] for v in values}=={'grass'}:
            import runpy
            runpy.run_path(str(ROOT/'tools/replace_act2_terrain_with_grass.py'),run_name='__main__')
        else:
            install(palettes)
            from act2_grass_terrain import install as install_grass
            install_grass()
    print('Act 2 materials built:',palettes)
