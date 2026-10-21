#!/usr/bin/env python3
"""Export the saved officer Aseprite source and preserve its animation timing.

This never redraws source art. Run after ordinary hand edits in Aseprite.
"""
import json
import os
from pathlib import Path
import subprocess

ROOT = Path(__file__).resolve().parents[1]
BASE = ROOT / 'assets/characters/officer'


def main():
    art = BASE / 'sprites'
    art.mkdir(parents=True, exist_ok=True)
    source = BASE / 'aseprite/officer_movement.aseprite'
    binary = os.environ.get('ASEPRITE', str(Path.home() / 'Applications/Aseprite.app/Contents/MacOS/aseprite'))
    subprocess.run([binary, '-b', str(source), '--sheet-type', 'horizontal',
                    '--sheet', str(art / 'movement.png'), '--format', 'json-array',
                    '--data', str(art / 'movement.json'), '--list-tags'], check=True)
    data = json.loads((art / 'movement.json').read_text())
    resources = []
    for i, frame in enumerate(data['frames']):
        box = frame['frame']
        assert (box['w'], box['h']) == (32, 48)
        resources.append(f'[sub_resource type="AtlasTexture" id="f{i}"]\n'
                         f'atlas = ExtResource("sheet")\nregion = Rect2({box["x"]}, {box["y"]}, 32, 48)\nfilter_clip = true')
    clips = []
    for tag in data['meta']['frameTags']:
        assert tag['direction'] == 'forward'
        entries = ['{"duration": %.6f, "texture": SubResource("f%d")}' %
                   (data['frames'][i]['duration'] / 1000, i)
                   for i in range(tag['from'], tag['to'] + 1)]
        clips.append('{"frames": [%s], "loop": true, "name": &"%s", "speed": 1.0}' %
                     (', '.join(entries), tag['name']))
    assert {tag['name'] for tag in data['meta']['frameTags']} == {'idle', 'walk', 'talk'}
    text = f'[gd_resource type="SpriteFrames" load_steps={len(resources) + 2} format=3]\n\n'
    text += '[ext_resource type="Texture2D" path="res://assets/characters/officer/sprites/movement.png" id="sheet"]\n\n'
    text += '\n\n'.join(resources) + '\n\n[resource]\n'
    text += 'metadata/aseprite_source = "res://assets/characters/officer/aseprite/officer_movement.aseprite"\n'
    text += 'animations = [' + ',\n'.join(clips) + ']\n'
    (BASE / 'officer_frames.tres').write_text(text)
    print(f'Exported {len(data["frames"])} officer frames and {len(clips)} clips from saved Aseprite art')


if __name__ == '__main__':
    main()
