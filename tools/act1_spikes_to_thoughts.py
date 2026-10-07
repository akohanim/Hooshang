#!/usr/bin/env python3
"""Convert Act One spike entities to editable ThoughtHazards cells. LDtk must be closed.
Default is a dry run; --apply writes only affected entity/paint arrays.
"""
import copy
import json
from pathlib import Path
import sys
from ldtk_add_ceiling_tile import ldtk_running


PATH = Path(__file__).resolve().parents[1] / 'ldtk/hooshang_act1.ldtk'

def _variants(rule):
    """(flip_bits, pattern) for each mirror the rule is allowed to match in.

    Order matters and is LDtk's: unmirrored, X, Y, XY. It decides which rule
    wins where two orientations both match, and any other order disagrees with
    the stored world."""
    n, p = rule["size"], rule["pattern"]
    combos = [(0, 0)]
    if rule["flipX"]:
        combos.append((1, 0))
    if rule["flipY"]:
        combos.append((0, 1))
    if rule["flipX"] and rule["flipY"]:
        combos.append((1, 1))
    out = []
    for fx, fy in combos:
        pat = []
        for y in range(n):
            for x in range(n):
                sx = n - 1 - x if fx else x
                sy = n - 1 - y if fy else y
                pat.append(p[sy * n + sx])
        out.append((fx | (fy << 1), pat))
    return out


def convert(project):
    definition = next(l for l in project['defs']['layers'] if l['identifier'] == 'ThoughtHazards')
    rules = [r for g in definition['autoRuleGroups'] for r in g['rules'] if r['active']]
    report = []
    for room in project['levels']:
        layer = next(l for l in room['layerInstances'] if l['__identifier'] == 'ThoughtHazards')
        w, h = layer['__cWid'], layer['__cHei']
        count = 0
        for entities in room['layerInstances']:
            keep = []
            for e in entities['entityInstances']:
                if not e['__identifier'].startswith(('ConeSpikes', 'GlassSpikes')):
                    keep.append(e)
                    continue
                x = e['px'][0] - e['width'] * e['__pivot'][0] + entities['__pxTotalOffsetX'] - layer['__pxTotalOffsetX']
                y = e['px'][1] - e['height'] * e['__pivot'][1] + entities['__pxTotalOffsetY'] - layer['__pxTotalOffsetY']
                assert all(v % 8 == 0 for v in [x, y, e['width'], e['height']])
                for yy in range(int(y)//8, int(y+e['height'])//8):
                    for xx in range(int(x)//8, int(x+e['width'])//8):
                        assert 0 <= xx < w and 0 <= yy < h, (room['identifier'],xx,yy)
                        layer['intGridCsv'][yy*w+xx] = 1
                count += 1
            entities['entityInstances'] = keep
        if not count:
            continue
        csv = layer['intGridCsv']
        tiles = []
        for i, value in enumerate(csv):
            if not value:
                continue
            x, y = i % w, i // w
            hit = None
            for rule in rules:
                n = rule['size']
                for flip, pattern in _variants(rule):
                    matches = True
                    for j, want in enumerate(pattern):
                        xx, yy = x+j%n-n//2, y+j//n-n//2
                        got = csv[yy*w+xx] if 0 <= xx < w and 0 <= yy < h else 0
                        if (want > 0 and got != want) or (want < 0 and got == -want):
                            matches = False
                            break
                    if matches:
                        hit = (rule['uid'],rule['tileRectsIds'][0][0],flip)
                        break
                if hit:
                    break
            assert hit
            uid, tile, flip = hit
            tiles.append(dict(px=[x*8,y*8],src=[tile*8,0],f=flip,t=tile,a=1,d=[uid,i]))
        layer['autoLayerTiles'] = tiles
        report.append((room['identifier'],count,len(tiles)))
    return report

def main():
    assert not ldtk_running(), 'Close LDtk before converting.'
    raw = PATH.read_text()
    before = json.loads(raw)
    after = copy.deepcopy(before)
    report = convert(after)
    edits = []
    decoder = json.JSONDecoder()
    # Locate arrays by the stable layer IID, preserving all unrelated formatting/data.
    for oldroom, room in zip(before['levels'],after['levels']):
        for old, layer in zip(oldroom['layerInstances'],room['layerInstances']):
            for key in ['entityInstances','intGridCsv','autoLayerTiles']:
                if old[key] == layer[key]:
                    continue
                anchor = raw.index('"iid": "'+layer['iid']+'"')
                pos = raw.index('"'+key+'":',anchor)+len(key)+3
                while raw[pos].isspace(): pos += 1
                _, length = decoder.raw_decode(raw[pos:])
                edits.append((pos,pos+length,json.dumps(layer[key],ensure_ascii=False)))
    for start,end,value in sorted(edits,reverse=True):
        raw = raw[:start]+value+raw[end:]
    assert json.loads(raw) == after
    print(report)
    print('Total strips:',sum(r[1] for r in report))
    if '--apply' in sys.argv:
        PATH.write_text(raw)
    else:
        print('Dry run; pass --apply to save.')

if __name__ == '__main__':main()
