"""Strip prison rooms down to an outer shell and Jamshid's cage.

Only the Prison_Hub and Prison_* levels are changed. Seal outer apertures so
PrisonWorld's adjacency scanner creates no portals. Keep only the border wall,
Jamshid, and Cage; runtime falls back to a central spawn until one is authored.
Run with LDtk closed.
"""
import copy
import json
import re
from pathlib import Path

from fix_masonry_edges import matches
from ldtk_add_ceiling_tile import array_end, ldtk_running, object_span

ROOT = Path(__file__).resolve().parents[1]
PATH = ROOT / 'ldtk/hooshang_act2.ldtk'
KEEP_ENTITIES = {'Cage', 'Jamshid'}


def array_span(text, layer_iid, key):
    start, end = object_span(text, text.index('"iid": "' + layer_iid + '"'))
    opening = text.index('[', text.index('"' + key + '":', start, end))
    return opening, array_end(text, opening) + 1


def formatted(items):
    if not items: return '[]'
    return '[\n' + ',\n'.join('\t' * 6 + json.dumps(item, separators=(',', ':')) for item in items) + '\n' + '\t' * 5 + ']'


def main():
    assert not ldtk_running(), 'Close LDtk before changing the prison levels'
    text = PATH.read_text()
    project = json.loads(text)
    masonry = next(layer for layer in project['defs']['layers'] if layer['identifier'] == 'PrisonMasonry')
    rules = [rule for group in masonry['autoRuleGroups'] if group['active'] for rule in group['rules'] if rule['active']]
    replacements = []
    totals = {'hazards': 0, 'water': 0, 'interior_solids': 0, 'entrance_cells': 0, 'entities': 0}
    rooms = 0
    for level in project['levels']:
        if level['identifier'] != 'Prison_Hub' and not level['identifier'].startswith('Prison_'): continue
        rooms += 1
        layers = {layer['__identifier']: layer for layer in level['layerInstances']}
        collision = layers['Collision']
        cells = collision['intGridCsv']
        width, height = collision['__cWid'], collision['__cHei']
        old = cells.copy()
        hazards = {i for i, value in enumerate(cells) if value == 3}
        water = {i for i, value in enumerate(cells) if value == 4}
        interior_solids = {y * width + x for y in range(1, height - 1) for x in range(1, width - 1)
                           if cells[y * width + x] == 1}
        cleared = hazards | water | interior_solids
        for index in cleared: cells[index] = 0
        sealed = set()
        for y in range(height):
            for x in range(width):
                if x not in (0, width - 1) and y not in (0, height - 1): continue
                index = y * width + x
                if cells[index] == 0:
                    cells[index] = 1
                    sealed.add(index)
        assert all(old[i] == cells[i] for i in range(len(cells)) if i not in cleared | sealed)
        totals['hazards'] += len(hazards)
        totals['water'] += len(water)
        totals['interior_solids'] += len(interior_solids)
        totals['entrance_cells'] += len(sealed)

        visual = layers['Tiles']
        before_visual = visual['autoLayerTiles']
        visual['autoLayerTiles'] = [tile for tile in before_visual
                                    if tile['px'][1] // 8 * width + tile['px'][0] // 8 not in cleared]
        assert len(before_visual) - len(visual['autoLayerTiles']) == len(hazards | water)

        masonry_layer = layers['PrisonMasonry']
        masonry_layer['autoLayerTiles'] = [tile for tile in masonry_layer['autoLayerTiles']
                                           if cells[tile['px'][1] // 8 * width + tile['px'][0] // 8] == 1]
        for index in sorted(sealed):
            x, y = index % width, index // width
            rule = next(rule for rule in rules if matches(rule, cells, width, height, x, y, {}))
            tile_id = rule['tileRectsIds'][0][0]
            masonry_layer['autoLayerTiles'].append({
                'px': [x * 8, y * 8], 'src': [tile_id % 76 * 8, tile_id // 76 * 8],
                'f': 0, 't': tile_id, 'd': [rule['uid'], index], 'a': 1,
            })
        masonry_layer['autoLayerTiles'].sort(key=lambda tile: (tile['px'][1], tile['px'][0]))
        assert len(masonry_layer['autoLayerTiles']) == sum(value == 1 for value in cells)

        entities = layers['Entities']
        before_entities = entities['entityInstances']
        entities['entityInstances'] = [entity for entity in before_entities if entity['__identifier'] in KEEP_ENTITIES]
        totals['entities'] += len(before_entities) - len(entities['entityInstances'])

        # Keep LDtk's existing per-row IntGrid formatting rather than rewriting
        # the whole 90k-line project with json.dump.
        start, end = array_span(text, collision['iid'], 'intGridCsv')
        cursor = iter(cells)
        new_array = re.sub(r'(?<!\d)\d+(?!\d)', lambda _match: str(next(cursor)), text[start:end])
        assert [int(value) for value in re.findall(r'(?<!\d)\d+(?!\d)', new_array)] == cells
        replacements.append((start, end, new_array))
        for layer, key in ((visual, 'autoLayerTiles'), (masonry_layer, 'autoLayerTiles'), (entities, 'entityInstances')):
            start, end = array_span(text, layer['iid'], key)
            replacements.append((start, end, formatted(layer[key])))
    for start, end, value in sorted(replacements, reverse=True):
        text = text[:start] + value + text[end:]
    assert json.loads(text) == project
    PATH.write_text(text)
    print('Reset', rooms, 'prison rooms:', totals)


if __name__ == '__main__': main()
