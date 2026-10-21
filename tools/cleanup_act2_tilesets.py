"""Remove unreferenced legacy Act 2 LDtk tileset definitions.

Keep image files: other worlds and reproducible generators may still use them.
The Water IntGrid and WaterLife dressing tileset serve different live roles.
"""
import json
from pathlib import Path

from ldtk_add_ceiling_tile import ldtk_running, object_span

ROOT = Path(__file__).resolve().parents[1]
PATH = ROOT / 'ldtk/hooshang_act2.ldtk'
LEGACY = {'Bricks': 24, 'Bricks8px': 32, 'ThoughtTilesSheet': 181}


def references(node, uid, location=''):
    found = []
    if isinstance(node, dict):
        for key, value in node.items():
            here = f'{location}/{key}'
            if key in ('tilesetId', 'tilesetUid', 'tilesetDefUid', '__tilesetDefUid') and value == uid:
                found.append(here)
            found.extend(references(value, uid, here))
    elif isinstance(node, list):
        for index, value in enumerate(node):
            found.extend(references(value, uid, f'{location}/{index}'))
    return found


def main():
    assert not ldtk_running(), 'Close LDtk before editing its project'
    text = PATH.read_text()
    project = json.loads(text)
    for name, uid in LEGACY.items():
        definition = next(x for x in project['defs']['tilesets'] if x['identifier'] == name)
        assert definition['uid'] == uid
        assert not references(project, uid), f'{name} still has live references'
        start, end = object_span(text, text.index('"identifier": "' + name + '"'))
        # Remove the object and its following comma, preserving LDtk formatting.
        after = end
        while text[after] in ' \t\r\n': after += 1
        assert text[after] == ','
        text = text[:start] + text[after + 1:]
        project['defs']['tilesets'].remove(definition)

    descriptions = {
        'Water': 'Paint swimmable water here. Act2WaterTilesSheet is the live base-water atlas; WaterLife adds optional dressing.',
        'WaterLife': 'Optional algae, fish, and waterfall outlet markers. This is decoration over the separate swimmable Water layer.',
    }
    for name, description in descriptions.items():
        definition = next(x for x in project['defs']['layers'] if x['identifier'] == name)
        start, end = object_span(text, text.index('"identifier": "' + name + '"'))
        chunk = text[start:end]
        old = json.dumps(definition['doc'])
        assert '"doc": ' + old in chunk
        chunk = chunk.replace('"doc": ' + old, '"doc": ' + json.dumps(description), 1)
        text = text[:start] + chunk + text[end:]
        definition['doc'] = description
    assert json.loads(text) == project
    PATH.write_text(text)
    print('Removed 3 unused Act 2 tileset definitions; documented both active water layers')


if __name__ == '__main__':
    main()
