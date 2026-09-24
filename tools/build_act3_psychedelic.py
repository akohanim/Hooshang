#!/usr/bin/env python3
"""Native-pixel Act 3 assets and LDtk palette. Run with LDtk closed.

Following AGENTS.md's production pipeline, geometry is authored at native
resolution, never reduced from the generated source concept atlas.
The requested palette is strictly black/white, with binary alpha for props.
"""
import copy
import json
import subprocess
from pathlib import Path
from PIL import Image, ImageDraw
from ldtk_preserve_json import update
import act3_connected_terrain as connected

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'assets/act3'
W, B, CLEAR = (255,255,255,255), (0,0,0,255), (0,0,0,0)
RED = (255,61,41,255)  # same hot-red danger cue as DarkThought.light_color


def terrain(material, edge):
    im = Image.new('RGBA', (8,8), B)
    d = ImageDraw.Draw(im)
    if material == 0:  # sparse outlined masonry
        d.line((0,3,7,3), fill=W)
        d.line((3,0,3,2), fill=W)
        d.line((7,4,7,7), fill=W)
        d.point((1,6), fill=W)
    elif material == 1:  # grass / root bed, tile-safe silhouette
        d.line((0,1,7,1), fill=W)
        for x in (1,4,6): d.point((x,0), fill=W)
        d.line([(0,4),(2,6),(4,4),(6,6),(7,5)], fill=W)
    elif material == 2:  # structural scaffold, open bays
        d.line((0,0,7,0), fill=W)
        d.line((0,7,7,7), fill=W)
        d.line((0,0,0,7), fill=W)
        d.line((7,0,7,7), fill=W)
        d.line((1,1,6,6), fill=W)
    elif material == 3:
        d.line([(0,2),(2,0),(6,4),(7,3)], fill=W)
        d.line([(0,6),(2,4),(5,7)], fill=W)
    elif material == 4:
        d.polygon([(0,4),(3,1),(7,4),(3,7)], outline=W)
        d.rectangle((3,3,4,5), fill=W)
    elif material == 5:
        d.rectangle((0,0,7,7), outline=W)
        d.line([(2,7),(2,2),(5,2),(5,5),(4,5)], fill=W)
    elif material == 6:
        for y in range(8):
            for x in range(8):
                if (x//2+y//2)%2 == 0: d.point((x,y),fill=W)
    else:
        d.line((0,3,7,3),fill=W)
        for x in (1,5): d.rectangle((x,0,x+1,1),fill=W)
        d.line([(1,5),(3,7),(5,5),(7,7)],fill=W)
    if edge in (1,3):
        d.line((0,0,7,0),fill=W)
        if material != 2: d.line((0,1,7,1),fill=B)
    if edge in (2,3):
        d.line((0,0,0,7),fill=W)
        if material != 2: d.line((1,1,1,7),fill=B)
    return im


def thought(light=False, grey=False):
    sheet = Image.new('RGBA',(64,16),CLEAR)
    for frame in range(4):
        im=Image.new('RGBA',(16,16),CLEAR); d=ImageDraw.Draw(im)
        body=W if light else B; ink=B if light else W
        d.polygon([(0,7),(2,5),(2,3),(5,3),(6,2),(10,2),(11,4),
                   (13,4),(13,6),(15,7),(15,10),(13,12),(10,12),
                   (8,13),(5,12),(2,12),(0,10)],fill=body,outline=RED)
        # Rotating square spiral: four 16px frames, unchanged cloud silhouette.
        eye=Image.new('RGBA',(7,7),body); e=ImageDraw.Draw(eye)
        e.line([(0,3),(0,0),(6,0),(6,6),(2,6),(2,2),(4,2),(4,4)],fill=ink)
        eye=eye.rotate(frame*90)
        im.paste(eye,(5,5))
        if grey:
            for x,y in ((2,7),(3,9),(11,4),(13,9)): d.point((x,y),fill=W)
        sheet.paste(im,(frame*16,0))
    return sheet


def main():
    processes=subprocess.check_output(['ps','ax','-o','command'],text=True)
    if any('LDtk.app/Contents/MacOS/LDtk' in s for s in processes.splitlines()):
        raise SystemExit('Close LDtk before rebuilding its Act 3 project.')
    OUT.mkdir(parents=True,exist_ok=True)
    sheet=Image.new('RGBA',(64,32),B)
    for material in range(8):
        for edge in range(4):
            tid=material*4+edge
            sheet.paste(terrain(material,edge),((tid%8)*8,(tid//8)*8))
    sheet=connected.append_atlas(sheet, terrain)
    sheet.save(OUT/'terrain.png')
    for name,light,grey in [('dark_thought',False,False),('light_thought',True,False),('grey_thought',False,True)]:
        thought(light,grey).save(OUT/f'{name}.png')
    ladder=Image.new('RGBA',(8,8),CLEAR); d=ImageDraw.Draw(ladder)
    d.line((0,0,0,7),fill=W); d.line((7,0,7,7),fill=W)
    d.line([(1,0),(2,1),(5,2),(6,3),(5,4),(2,5),(1,6),(2,7)],fill=W)
    ladder.save(OUT/'ladder.png')
    # Same five-module strips and lethal depths as the existing spike prefabs.
    for prefix,cell,depth in [('cone_spikes',8,5),('glass_spikes',16,12)]:
        modules=[]
        for variant in range(5):
            tile=Image.new('RGBA',(cell,cell),CLEAR); ink=ImageDraw.Draw(tile)
            ink.rectangle((0,depth,cell-1,cell-1),fill=B)
            ink.line((0,cell-1,cell-1,cell-1),fill=W)
            ink.polygon([(0,depth-1),(cell//2,0),(cell-1,depth-1)],fill=W,outline=RED)
            if cell==16:
                ink.line([(4,9),(8,5),(10,9),(7,9)],fill=B)
            else: ink.point((4,3),fill=B)
            modules.append(tile)
        for suffix,turn in [('',0),('_down',180),('_right',270),('_left',90)]:
            vertical=turn in (90,270)
            strip=Image.new('RGBA',(cell,cell*5) if vertical else (cell*5,cell),CLEAR)
            for i,tile in enumerate(modules): strip.paste(tile.rotate(turn),(0,i*cell) if vertical else (i*cell,0))
            strip.save(OUT/f'{prefix}{suffix}.png')
    hazards=Image.new('RGBA',(32,48),CLEAR)
    for frame in range(6):
        for edge in range(4):
            tile=terrain(5,edge).rotate((frame%4)*90)
            ink=ImageDraw.Draw(tile)
            if edge in (1,3): ink.line((0,0,7,0),fill=RED)
            if edge in (2,3): ink.line((0,0,0,7),fill=RED)
            hazards.paste(tile,(edge*8,frame*8))
    hazards.save(OUT/'thought_tiles.png')
    # Reuse the existing rule schema and UID of the collision tileset.
    path=ROOT/'ldtk/hooshang_act3.ldtk'; raw=path.read_text(); p=json.loads(raw)
    ts=next(t for t in p['defs']['tilesets'] if t['uid']==32)
    ts.update(identifier='Act3Psychedelic',relPath='../assets/act3/terrain.png',
              pxWid=64,pxHei=32,__cWid=8,__cHei=4,cachedPixelData=None)
    ts['savedSelections']=[]
    coll=next(l for l in p['defs']['layers'] if l['identifier']=='Collisions')
    def uid():
        p['nextUid']+=1
        return p['nextUid']-1
    # Preserve legacy values 3/4 and their rules. New materials get new values.
    names=['Grass','Scaffolding']
    for material,name in enumerate(names,1):
        value=material+4
        if not any(v['identifier']==name for v in coll['intGridValues']):
            coll['intGridValues'].append({'value':value,'identifier':name,'color':'#FFFFFF','tile':None,'groupUid':0})
    for layer in p['defs']['layers']:
        if layer['identifier'] in ('Foreground','Background'): layer['tilesetDefUid']=32
    for level in p['levels']:
        level['bgColor']='#000000'; level['__bgColor']='#000000'
        for layer in level['layerInstances']:
            if layer['__identifier'] in ('Collisions','Foreground','Background'):
                layer['__tilesetDefUid']=32; layer['__tilesetRelPath']=ts['relPath']
    field_template=copy.deepcopy(next(e for e in p['defs']['entities'] if e['identifier']=='DarkThought')['fieldDefs'][1])
    for entity in p['defs']['entities']:
        name=entity['identifier']
        if name not in ('DarkThought','LightThought','GreyThought','Ladder') and not name.startswith(('ConeSpikes','GlassSpikes')): continue
        if not any(f['identifier']=='PsychedelicPalette' for f in entity['fieldDefs']):
            field=copy.deepcopy(field_template)
            field.update(identifier='PsychedelicPalette',uid=uid(),doc='Act 3 monochrome spiral art: 1 on, 0 off.',defaultOverride={'id':'V_Float','params':[1]})
            entity['fieldDefs'].append(field)
        entity['color']='#FFFFFF'
        if name.startswith(('ConeSpikes','GlassSpikes')):
            texture=next(t for t in p['defs']['tilesets'] if t['uid']==entity['tilesetId'])
            suffix='_down' if name.endswith('Ceiling') else '_right' if name.endswith('LeftWall') else '_left' if name.endswith('RightWall') else ''
            prefix='cone_spikes' if name.startswith('Cone') else 'glass_spikes'
            texture['relPath']=f'../assets/act3/{prefix}{suffix}.png'
            texture['cachedPixelData']=None
        elif name!='Ladder':
            texture=next(t for t in p['defs']['tilesets'] if t['uid']==entity['tilesetId'])
            texture['relPath']='../assets/act3/'+{'DarkThought':'dark_thought','LightThought':'light_thought','GreyThought':'grey_thought'}[name]+'.png'
            texture['cachedPixelData']=None
        else:
            texture=next((t for t in p['defs']['tilesets'] if t['identifier']=='Act3Ladder'),None)
            if texture is None:
                texture=copy.deepcopy(ts)
                texture.update(identifier='Act3Ladder',uid=uid(),relPath='../assets/act3/ladder.png',pxWid=8,pxHei=8,__cWid=1,__cHei=1)
                p['defs']['tilesets'].append(texture)
            rect={'tilesetUid':texture['uid'],'x':0,'y':0,'w':8,'h':8}
            entity.update(tilesetId=texture['uid'],tileRect=rect,uiTileRect=rect,
                          renderMode='Tile',tileRenderMode='Repeat')
        # Existing placements also need serialized fields: the importer does
        # not fill missing fieldInstances from definition defaults.
        field=next(f for f in entity['fieldDefs'] if f['identifier']=='PsychedelicPalette')
        for level in p['levels']:
            for layer in level['layerInstances']:
                for instance in layer['entityInstances']:
                    if instance['__identifier']==name and not any(f['__identifier']=='PsychedelicPalette' for f in instance['fieldInstances']):
                        instance['fieldInstances'].append({'__identifier':'PsychedelicPalette','__type':'Float','__value':1,'__tile':None,'defUid':field['uid'],'realEditorValues':[{'id':'V_Float','params':[1]}]})
    p['bgColor']='#000000'
    p['defaultLevelBgColor']='#000000'
    next(t for t in p['defs']['tilesets'] if t['identifier']=='ThoughtTilesSheet').update(relPath='../assets/act3/thought_tiles.png',cachedPixelData=None)
    for level in p['levels']:
        for layer in level['layerInstances']:
            if layer['__identifier']=='ThoughtHazards': layer['__tilesetRelPath']='../assets/act3/thought_tiles.png'
    connected.install(p)
    connected.preview(p, sheet, OUT/'connected_preview.png')
    path.write_text(update(raw,p))
    # Art review at game resolution, then an integer nearest upscale.
    preview=Image.new('RGBA',(320,220),B); pen=ImageDraw.Draw(preview)
    paint_preview=Image.open(OUT/'connected_preview.png').resize((288,112),Image.Resampling.NEAREST)
    preview.paste(paint_preview,(16,0))
    for index,name in enumerate(['dark_thought','light_thought','grey_thought']):
        sprite=Image.open(OUT/f'{name}.png')
        preview.alpha_composite(sprite,(8+index*88,142))
    for row in range(5): preview.alpha_composite(ladder,(298,132+row*8))
    pen.text((8,166),'THOUGHTS / RED = DANGER',fill=W)
    preview.alpha_composite(Image.open(OUT/'cone_spikes.png'),(8,195))
    preview.alpha_composite(Image.open(OUT/'glass_spikes.png'),(64,187))
    preview.alpha_composite(Image.open(OUT/'thought_tiles.png').crop((0,0,32,8)),(164,195))
    pen.text((210,192),'HAZARDS',fill=W)
    preview.resize((1280,880),Image.Resampling.NEAREST).save(OUT/'preview.png')
    print(f'Built three connected terrain brushes ({connected.COUNT} compatible atlas slots), thoughts, ladder and hazards; updated Act 3 LDtk.')


if __name__=='__main__': main()
