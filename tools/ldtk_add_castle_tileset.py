#!/usr/bin/env python3
"""Add the supplied castle sheets and paintable layers to Act 2.

Preserves source pixels, existing terrain and room layouts. Uses 8px cells;
select rectangles in LDtk to stamp the sheets' larger architectural pieces.
Run with --apply while LDtk and Godot are closed.
"""
import argparse
import copy
import json
from pathlib import Path
import struct
import subprocess
import uuid
import zipfile
from ldtk_preserve_json import update

ROOT = Path(__file__).resolve().parents[1]
PROJECT = ROOT / 'ldtk/hooshang_act2.ldtk'


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--archive', type=Path, default=Path.home() / 'Downloads/castle_tileset.zip')
    parser.add_argument('--apply', action='store_true')
    args = parser.parse_args()
    processes = subprocess.check_output(['ps', 'ax', '-o', 'command'], text=True)
    if args.apply and any(line.strip().split()[0].endswith('/LDtk') or (line.strip().split()[0].endswith('/Godot') and '--editor' in line) for line in processes.splitlines() if line.strip()):
        raise SystemExit('Close LDtk and the Godot editor before applying.')
    raw = PROJECT.read_text()
    project = json.loads(raw)
    definitions = project['defs']
    used = []
    def scan(value):
        if isinstance(value, dict):
            if isinstance(value.get('uid'), int): used.append(value['uid'])
            for child in value.values(): scan(child)
        elif isinstance(value, list):
            for child in value: scan(child)
    scan(project)
    next_uid = max(used + [project.get('nextUid', 1) - 1]) + 1
    initial_uid = next_uid
    def uid():
        nonlocal next_uid
        result = next_uid
        next_uid += 1
        return result
    sheets = {}
    with zipfile.ZipFile(args.archive) as archive:
        for identifier, filename in [('Act2CastleDecor', 'castle-01.png'), ('Act2CastleMasonry', 'castle-02.png')]:
            data = archive.read(filename)
            if data[:8] != b'\x89PNG\r\n\x1a\n': raise ValueError('Expected PNG: ' + filename)
            width, height = struct.unpack('>II', data[16:24])
            assert width % 8 == height % 8 == 0
            relative = 'art/castle/' + filename
            tileset = next((t for t in definitions['tilesets'] if t['identifier'] == identifier), None)
            if tileset is None:
                tileset = dict(identifier=identifier, uid=uid(), relPath=relative, embedAtlas=None,
                               pxWid=width, pxHei=height, tileGridSize=8, spacing=0, padding=0,
                               tags=[], tagsSourceEnumUid=None, enumTags=[], customData=[],
                               cachedPixelData=None, savedSelections=[], __cWid=width // 8, __cHei=height // 8)
                definitions['tilesets'].append(tileset)
            sheets[identifier] = tileset
            if args.apply:
                target = ROOT / 'ldtk' / relative
                target.parent.mkdir(parents=True, exist_ok=True)
                target.write_bytes(data)
    template = next(layer for layer in definitions['layers'] if layer['identifier'] == 'Background')
    for name, sheet, doc in [
        ('CastleTerrain', 'Act2CastleMasonry', 'Solid castle masonry. Each painted 8px cell collides; use CastleBackground for scenery.'),
        ('CastleBackground', 'Act2CastleMasonry', 'Pass-through castle walls behind the player.'),
        ('CastleDecor', 'Act2CastleDecor', 'Pass-through banners, windows and trim behind the player.'),
    ]:
        tileset = sheets[sheet]
        layer = next((l for l in definitions['layers'] if l['identifier'] == name), None)
        if layer is None:
            layer = copy.deepcopy(template)
            layer.update(identifier=name, uid=uid(), doc=doc, tilesetDefUid=tileset['uid'], gridSize=8,
                         guideGridWid=32, guideGridHei=32)
            definitions['layers'].append(layer)
        for level in project['levels']:
            if any(l['layerDefUid'] == layer['uid'] for l in level['layerInstances']): continue
            instance = dict(__identifier=name, __type='Tiles', __cWid=level['pxWid'] // 8,
                            __cHei=level['pxHei'] // 8, __gridSize=8, __opacity=1,
                            __pxTotalOffsetX=0, __pxTotalOffsetY=0,
                            __tilesetDefUid=tileset['uid'], __tilesetRelPath=tileset['relPath'],
                            iid=str(uuid.uuid4()), levelId=level['uid'], layerDefUid=layer['uid'],
                            pxOffsetX=0, pxOffsetY=0, visible=True, optionalRules=[], intGridCsv=[],
                            autoLayerTiles=[], seed=1, overrideTilesetUid=None, gridTiles=[], entityInstances=[])
            level['layerInstances'].append(instance)
    if 'nextUid' in project and next_uid != initial_uid:
        project['nextUid'] = next_uid
    if args.apply: PROJECT.write_text(update(raw, project))
    print(('Applied' if args.apply else 'Prepared') + ': two castle sheets; CastleTerrain, CastleBackground, CastleDecor in every Act 2 room.')


if __name__ == '__main__':
    main()
