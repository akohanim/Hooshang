"""Restore Act 2 brick, stone, and scaffolding LDtk brushes without repainting rooms.

The shared 934-tile Act 2 atlas already contains these materials. This only
restores their IntGrid values and auto-rules beside the existing grass brush.
Run with LDtk closed; reimport the project after closing the Godot editor.
"""
import copy
import json
from pathlib import Path

from ldtk_add_ceiling_tile import block, ldtk_running, object_span

ROOT = Path(__file__).resolve().parents[1]
PATH = ROOT / 'ldtk/hooshang_act2.ldtk'
MATERIALS = {'scaffolding': 5, 'brick_new': 7, 'stone': 8}


def main():
    assert not ldtk_running(), 'Close LDtk before editing its project'
    text = PATH.read_text()
    project = json.loads(text)
    source = json.loads((ROOT / 'ldtk/hooshang_act1.ldtk').read_text())
    layer = next(x for x in project['defs']['layers'] if x['identifier'] == 'Collisions')
    source_layer = next(x for x in source['defs']['layers'] if x['identifier'] == 'Collisions')
    atlas = next(x for x in project['defs']['tilesets'] if x['uid'] == layer['tilesetDefUid'])
    assert atlas['relPath'] == 'art/act2_materials/terrain.png' and atlas['__cWid'] >= 934
    existing = {x['identifier'] for x in layer['intGridValues']}
    next_uid = project['nextUid']
    for name, value in MATERIALS.items():
        if name not in existing:
            brush = copy.deepcopy(next(x for x in source_layer['intGridValues'] if x['value'] == value))
            brush['groupUid'] = 1  # VisibleTerrain: grass and masonry join at seams.
            layer['intGridValues'].append(brush)
        for source_group in source_layer['autoRuleGroups']:
            if not source_group['name'].startswith(name + ' /'): continue
            if any(x['name'] == source_group['name'] for x in layer['autoRuleGroups']): continue
            group = copy.deepcopy(source_group)
            group['uid'] = next_uid
            next_uid += 1
            for rule in group['rules']:
                rule['uid'] = next_uid
                next_uid += 1
            layer['autoRuleGroups'].append(group)
    project['nextUid'] = next_uid
    start, end = object_span(text, text.index('"identifier": "Collisions"'))
    depth = len(text[text.rfind('\n', 0, start) + 1:start])
    text = text[:start] + block(layer, depth).lstrip('\t') + text[end:]
    import re
    text = re.sub(r'"nextUid": \d+', '"nextUid": ' + str(next_uid), text, count=1)
    assert json.loads(text) == project
    PATH.write_text(text)
    print('Restored Act 2 LDtk brushes:', ', '.join(MATERIALS))


if __name__ == '__main__':
    main()
