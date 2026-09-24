"""Connected Act 3 paint, using Act 1/2's 47-mask VisibleTerrain rules.

The original 32 atlas slots remain valid for manual decoration. Connected
brushes append explicit orientations, avoiding reflected motifs at joins.
"""
import copy
import json
import re
from PIL import Image, ImageDraw
import build_material_lab as topology
from fix_masonry_edges import matches

NAMES = ['brick', 'Grass', 'Scaffolding', 'Waves', 'Eyes', 'Spiral', 'Checker', 'Frieze']
MATERIALS = {2: 0, 5: 1, 6: 2}
FIRST = 32
BASE_COUNT = FIRST + len(NAMES) * len(topology.MASKS)
COUNT = BASE_COUNT + 3 * 2 * len(topology.MASKS)
VISIBLE = 2000  # LDtk group UID 1, exactly as in Acts 1/2.
WHITE = (255, 255, 255, 255)
BLACK = (0, 0, 0, 255)
# (column period, row period, (column offset, row offset, variant) placements).
# Broad masonry needs far less marking than a narrow scaffold bay.
ACCENTS = {
    0: (9,7,[(1,0,1),(6,2,2),(3,4,1),(8,6,2)]),
    1: (7,3,[(2,0,1),(5,2,2)]),
    2: (5,3,[(1,0,1),(4,1,2),(2,2,1)]),
}


def tile_id(material, mask, variant=0):
    if variant:
        return BASE_COUNT + (material*2+variant-1)*len(topology.MASKS) + topology.MASKS.index(mask)
    return FIRST + material * len(topology.MASKS) + topology.MASKS.index(mask)


def tile(material, mask, motif, variant=0):
    # Solid-black negative space, with continuous architectural contours.
    # Never sprinkle a mark per cell: it becomes a distracting dotted grid.
    image = Image.new('RGBA', (8, 8), BLACK)
    draw = ImageDraw.Draw(image)
    for side in range(4):
        if mask & (1 << side):
            continue
        for along in range(8):
            for depth in range(3):
                x, y = [(along, depth), (7-depth, along),
                        (along, 7-depth), (depth, along)][side]
                # Scaffolding and frieze use a restrained second continuous
                # rail. Other brushes have one clean, one-pixel contour.
                color = WHITE if depth == 0 or (depth == 2 and material in (2, 7)) else BLACK
                # Grass gets a shallow, connected fringe along its top only;
                # every white pixel touches the contour, never floats inside.
                if material == 1 and side == 0 and depth == 1 and along in (1, 2, 5):
                    color = WHITE
                draw.point((x, y), fill=color)
    # Concave turns: both axial neighbors are filled but the diagonal is air.
    for bit, a, b, x, y in [(4,0,3,0,0), (5,0,1,7,0),
                            (6,1,2,7,7), (7,2,3,0,7)]:
        if mask & (1 << a) and mask & (1 << b) and not mask & (1 << bit):
            draw.point((x, y), fill=WHITE)
    if variant:
        # A single recognizable fragment, never speckled noise. Every stroke
        # stays inside the tile, leaving shared boundaries unbroken.
        if material == 0:
            # Partial coursing: one mortar joint and an offset vertical seam.
            if variant == 1:
                draw.line((1,4,6,4),fill=WHITE)
                draw.line((3,2,3,4),fill=WHITE)
            else:
                draw.line((1,2,4,2),fill=WHITE)
                draw.line((4,5,6,5),fill=WHITE)
        elif material == 1:
            # A tapering root fork under the turf; no isolated white dots.
            points = [(3,1),(3,4),(5,6)] if variant == 1 else [(5,1),(5,3),(3,5)]
            draw.line(points, fill=WHITE)
            draw.line([(3,3),(1,5)] if variant == 1 else [(5,3),(6,4)], fill=WHITE)
        else:
            # One diagonal brace, mirrored between widely spaced bays.
            draw.line((1,1,6,6) if variant == 1 else (1,6,6,1), fill=WHITE)
        # Keep a black channel beside exposed outlines. A mortar fragment
        # should never accidentally weld to the contour and thicken it.
        for side in range(4):
            if mask & (1<<side): continue
            for along in range(1,7):
                x,y=[(along,1),(6,along),(along,6),(1,along)][side]
                if not(material==1 and side==0): draw.point((x,y),fill=BLACK)
    return image


def append_atlas(legacy, motif):
    atlas = Image.new('RGBA', (64, ((COUNT + 7)//8)*8), BLACK)
    # Keep existing atlas coordinates valid, but expose only the three chosen
    # looks. Legacy decorative/material slots become compatible brick aliases.
    for tid in range(FIRST):
        material = tid//4 if tid//4 < 3 else 0
        mask = [255,254,247,246][tid%4]
        atlas.paste(tile(material, mask, motif), ((tid%8)*8, (tid//8)*8))
    for material in range(len(NAMES)):
        for mask in topology.MASKS:
            tid = tile_id(material, mask)
            atlas.paste(tile(material if material < 3 else 0, mask, motif), ((tid % 8)*8, (tid//8)*8))
    for material in range(3):
        for variant in (1,2):
            for mask in topology.MASKS:
                tid=tile_id(material,mask,variant)
                atlas.paste(tile(material,mask,motif,variant),((tid%8)*8,(tid//8)*8))
    return atlas


def install(project):
    layer = next(l for l in project['defs']['layers'] if l['identifier'] == 'Collisions')
    layer['intGridValues'] = [v for v in layer['intGridValues'] if v['value'] in MATERIALS]
    layer['intGridValuesGroups'] = [{'uid': 1, 'identifier': 'VisibleTerrain', 'color': None}]
    for value in layer['intGridValues']:
        if value['value'] in MATERIALS:
            value['groupUid'] = 1
    # Reuse rule/group IDs on rebuild so this installer is idempotent.
    old_groups = {g['name']: g['uid'] for g in layer['autoRuleGroups']}
    old_rules = {(g['name'], tuple(r['pattern']),r['xModulo'],r['yModulo'],r['xOffset'],r['yOffset']): r['uid']
                 for g in layer['autoRuleGroups'] for r in g['rules']}
    next_uid = max(project['nextUid'], max(map(int, re.findall(r'"uid":\s*(\d+)', json.dumps(project)))) + 1)
    topology.uid = next_uid

    def stable_uid(old):
        nonlocal next_uid
        if old is not None:
            return old
        value = next_uid
        next_uid += 1
        return value

    groups = []
    for value, material in MATERIALS.items():
        name = next(v['identifier'] for v in layer['intGridValues'] if v['value'] == value)
        mapping = {mask: [tile_id(material, mask)] for mask in topology.MASKS if mask != 255}
        fill = tile_id(material, 255)
        generated = topology.groups(name, value, mapping, [fill], fill)
        # Sparse, staggered placement at a material-specific density.
        detail=copy.deepcopy(generated[0])
        detail.update(name=name+' / 0 Sparse structure',rules=[])
        for mask in topology.MASKS:
            candidates=[]
            if mask != 255:
                base=next(r for g in generated[:2] for r in g['rules'] if r['tileRectsIds']==[[tile_id(material,mask)]])
                candidates=[base]
            else:
                # Fully enclosed cells receive a mark only within two cells
                # of open space; deep interiors stay common black across brushes.
                for px,py in [(0,-2),(2,0),(0,2),(-2,0)]:
                    base=copy.deepcopy(generated[3]['rules'][0])
                    pattern=[0]*25;pattern[12]=value
                    for dx,dy in topology.NEIGHBORS: pattern[(dy+2)*5+dx+2]=topology.ANY
                    pattern[(py+2)*5+px+2]=-topology.ANY
                    base.update(size=5,pattern=pattern)
                    candidates.append(base)
            for base in candidates:
                x_period,y_period,placements=ACCENTS[material]
                for offset,phase,variant in placements:
                    rule=copy.deepcopy(base)
                    rule.update(xModulo=x_period,yModulo=y_period,xOffset=offset,yOffset=phase,
                                tileRectsIds=[[tile_id(material,mask,variant)]])
                    detail['rules'].append(rule)
        for group in [detail]+generated[:2] + generated[3:]:
            group['uid'] = stable_uid(old_groups.get(group['name']))
            group.update(active=True, isOptional=False)
            for rule in group['rules']:
                rule['pattern'] = [VISIBLE if v == topology.ANY else -VISIBLE if v == -topology.ANY else v for v in rule['pattern']]
                rule['uid'] = stable_uid(old_rules.get((group['name'], tuple(rule['pattern']),rule['xModulo'],rule['yModulo'],rule['xOffset'],rule['yOffset'])))
                rule.update(active=True, chance=1, breakOnMatch=True,
                            outOfBoundsValue=value, perlinActive=False)
            groups.append(group)
    layer['autoRuleGroups'] = groups
    project['nextUid'] = next_uid
    ts = next(t for t in project['defs']['tilesets'] if t['uid'] == 32)
    ts.update(pxWid=64, pxHei=((COUNT+7)//8)*8, __cWid=8, __cHei=(COUNT+7)//8, cachedPixelData=None)
    for level in project['levels']:
        for instance in level['layerInstances']:
            if instance['__identifier'] == 'Collisions':
                # Keep the user's authored shape; retired brushes become brick.
                instance['intGridCsv'] = [v if v == 0 or v in MATERIALS else 2 for v in instance['intGridCsv']]
                rebake(instance, layer)


def rule_matches(rule,cells,width,height,x,y,groups):
    # LDtk's measured semantics: (coordinate - offset) % modulo == 0.
    return ((x-rule['xOffset'])%rule['xModulo']==0
            and (y-rule['yOffset'])%rule['yModulo']==0
            and matches(rule,cells,width,height,x,y,groups))


def rebake(instance, definition):
    rules = [r for g in definition['autoRuleGroups'] if g['active'] for r in g['rules'] if r['active']]
    groups = {v['value']: v['groupUid'] for v in definition['intGridValues']}
    width, height = instance['__cWid'], instance['__cHei']
    cells = instance['intGridCsv']
    tiles = []
    for index, value in enumerate(cells):
        if value not in MATERIALS:
            continue
        x, y = index % width, index // width
        rule = next(r for r in rules if rule_matches(r, cells, width, height, x, y, groups))
        tid = rule['tileRectsIds'][0][0]
        tiles.append(dict(px=[x*8, y*8], src=[tid%8*8, tid//8*8], f=0,
                          t=tid, a=1, d=[rule['uid'], index]))
    instance['autoLayerTiles'] = tiles


def preview(project, atlas, destination):
    definition = next(l for l in project['defs']['layers'] if l['identifier'] == 'Collisions')
    image = Image.new('RGBA', (288, 112), BLACK)
    draw = ImageDraw.Draw(image)
    # Each swatch has a concave cutout, a one-cell branch and a mixed brush seam.
    shape = ['1111111110', '1111111110', '1110001111', '1110001110',
             '1111111110', '0001110000']
    for material, name in enumerate(NAMES[:3]):
        value = 2 if material == 0 else material+4
        cells = [0]*96
        for y, row in enumerate(shape, 1):
            for x, filled in enumerate(row):
                if filled == '1': cells[y*12+x+1] = value
        # Touching materials connect through the same VisibleTerrain group.
        for y in (1, 2, 5):
            for x in (6, 7, 8): cells[y*12+x+1] = 5 if value != 5 else 2
        instance = dict(__cWid=12, __cHei=8, intGridCsv=cells, autoLayerTiles=[])
        rebake(instance, definition)
        ox, oy = (material%4)*96, (material//4)*100
        draw.text((ox+2, oy+2), name.upper(), fill=WHITE)
        for cell in instance['autoLayerTiles']:
            sx, sy = cell['src']
            image.paste(atlas.crop((sx,sy,sx+8,sy+8)), (ox+cell['px'][0],oy+16+cell['px'][1]))
    draw.text((4,96), 'BRICK / GRASS / SCAFFOLDING', fill=WHITE)
    image.resize((1152,448), Image.Resampling.NEAREST).save(destination)
