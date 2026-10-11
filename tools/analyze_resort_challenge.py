#!/usr/bin/env python3
"""Static research on a user-owned Resort binary; no game assets are exported.
Apertures are geometric candidates, never a claim of playable connectivity.
"""
import argparse, collections, hashlib, json
from pathlib import Path
from analyze_celeste_ch3 import Reader

COLORS = ('Red', 'Green', 'Yellow')
RELEVANT = {'key','lockBlock','colorSwitch','clutterDoor','touchSwitch','switchGate',
 'exitBlock','invisibleBarrier','player','checkpoint','spinner','trackSpinner',
 'rotateSpinner','jumpThru','sinkingPlatform','crumbleBlock','movingPlatform',
 'refill','spring','redBlocks','greenBlocks','yellowBlocks','water'}

def analyze(path):
    name, root = Reader(path).parse()
    levels = next(n['children'] for n in root['children'] if n['name']=='levels')
    records=[]
    for level in levels:
        a=level['attrs']; groups={n['name']:n for n in level['children']}
        entities=groups.get('entities',{}).get('children',[])
        rows=groups['solids']['attrs'].get('innerText','').splitlines()
        occupancy={color:set() for color in COLORS}
        for e in entities:
            color=next((c for c in COLORS if e['name']==c.lower()+'Blocks'),None)
            if not color:continue
            p=e['attrs']
            # Entity bounds, not sprite coverage or collision-code verification.
            for y in range(p['y']//8,(p['y']+p.get('height',8)+7)//8):
                for x in range(p['x']//8,(p['x']+p.get('width',8)+7)//8):occupancy[color].add((x,y))
        variants=[]
        for mask in range(8):
            removed=[c for i,c in enumerate(COLORS) if mask&(1<<i)]
            remaining=set().union(*(occupancy[c] for c in COLORS if c not in removed))
            variants.append({'removed_colors':removed,'remaining_clutter_cells':len(remaining),
                'clutter_cells_over_empty_solids':sum(0<=y<len(rows) and 0<=x<len(rows[y]) and rows[y][x]=='0' for x,y in remaining)})
        records.append({'room':a['name'][4:],'origin':[a['x'],a['y']],
            'size_tiles':[a['width']//8,a['height']//8],
            'counts':dict(collections.Counter(e['name'] for e in entities)),
            'entities':[{'type':e['name'],**e['attrs'],'nodes':[n['attrs'] for n in e['children'] if n['name']=='node']} for e in entities if e['name'] in RELEVANT or e['name'].startswith(('spikes','triggerSpikes'))],
            'clutter_occupancy_variants':variants})
    return {'source':str(path),'sha256':hashlib.sha256(path.read_bytes()).hexdigest(),
       'method':'decoded map records; colored rectangles unioned on 8px grid',
       'limits':['No runtime or player simulation','Removal masks are hypothetical; legal cleanup ordering is not proved','Entity defaults and behaviors require runtime-code evidence','No-grab feasibility is not proved'],
       'rooms':records}

if __name__=='__main__':
    ap=argparse.ArgumentParser(description=__doc__);ap.add_argument('map',type=Path);ap.add_argument('--output',type=Path,required=True)
    args=ap.parse_args();result=analyze(args.map);args.output.parent.mkdir(parents=True,exist_ok=True)
    args.output.write_text(json.dumps(result,indent=2)+'\n')
    print('Recorded',len(result['rooms']),'rooms and all eight clutter-removal masks.')
