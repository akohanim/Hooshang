#!/usr/bin/env python3
"""Export saved finale Aseprite edits; never rebuild or resample the artwork."""
import json
from pathlib import Path
import subprocess

ROOT = Path(__file__).resolve().parents[1]
ASEPRITE = '/Users/ari/Applications/Aseprite.app/Contents/MacOS/aseprite'


def export(folder, name):
    art = ROOT / folder
    subprocess.run([
        ASEPRITE, '--batch', str(art / f'{name}.aseprite'),
        '--sheet', str(art / f'{name}.png'), '--sheet-type', 'horizontal',
        '--data', str(art / f'{name}.json'), '--format', 'json-array', '--list-tags',
    ], check=True)
    return json.loads((art / f'{name}.json').read_text())


def main():
    export('assets/characters/tiger', 'tiger')
    data = export('assets/characters/mice', 'mice')
    resources = []
    for i, frame in enumerate(data['frames']):
        box = frame['frame']
        resources.append(
            f'[sub_resource type="AtlasTexture" id="frame_{i}"]\n'
            'atlas = ExtResource("sheet")\n'
            f'region = Rect2({box["x"]}, {box["y"]}, {box["w"]}, {box["h"]})\n'
            'filter_clip = true')
    animations = []
    for tag in data['meta']['frameTags']:
        entries = [
            '{"duration": ' + str(float(data['frames'][i]['duration']))
            + ', "texture": SubResource("frame_' + str(i) + '")}'
            for i in range(tag['from'], tag['to'] + 1)
        ]
        animations.append('{"frames": [' + ', '.join(entries)
                          + '], "loop": true, "name": &"' + tag['name']
                          + '", "speed": 1000.0}')
    text = f'[gd_resource type="SpriteFrames" load_steps={len(resources)+2} format=3]\n\n'
    text += '[ext_resource type="Texture2D" path="res://assets/characters/mice/mice.png" id="sheet"]\n\n'
    text += '\n\n'.join(resources) + '\n\n[resource]\nanimations = [' + ',\n'.join(animations) + ']\n'
    (ROOT / 'assets/characters/mice/mice_frames.tres').write_text(text)
    print('Exported tiger and mice; mouse SpriteFrames built from saved tags/timing')


if __name__ == '__main__':
    main()
