#!/usr/bin/env python3
"""Export hand-editable ending poses; never regenerate or edit the source."""
import json
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
ART = ROOT / 'assets/characters/hooshang/act2_ending'
ASEPRITE = '/Users/ari/Applications/Aseprite.app/Contents/MacOS/aseprite'
subprocess.run([ASEPRITE, '--batch', str(ART / 'source/finale.aseprite'),
                '--sheet', str(ART / 'finale.png'), '--sheet-type', 'horizontal',
                '--data', str(ART / 'finale.json'), '--format', 'json-array', '--list-tags'], check=True)
subprocess.run([ASEPRITE, '--batch', str(ART / 'source/coat.aseprite'),
                '--save-as', str(ART / 'coat.png')], check=True)
data = json.loads((ART / 'finale.json').read_text())
resources, clips = [], []
for i, frame in enumerate(data['frames']):
    box = frame['frame']
    assert box['w'] == box['h'] == 18
    resources.append(f'[sub_resource type="AtlasTexture" id="frame_{i}"]\natlas = ExtResource("sheet")\nregion = Rect2({box["x"]}, {box["y"]}, 18, 18)\nfilter_clip = true')
for tag in data['meta']['frameTags']:
    entries = ['{"duration": %s, "texture": SubResource("frame_%d")}' % (data['frames'][i]['duration'], i)
               for i in range(tag['from'], tag['to'] + 1)]
    clips.append('{"frames": [' + ', '.join(entries) + '], "loop": ' + str(tag['name'] in ('paint', 'walk_home')).lower()
                 + ', "name": &"' + tag['name'] + '", "speed": 1000.0}')
(ART / 'finale_frames.tres').write_text(
    f'[gd_resource type="SpriteFrames" load_steps={len(resources)+2} format=3]\n'
    '[ext_resource type="Texture2D" path="res://assets/characters/hooshang/act2_ending/finale.png" id="sheet"]\n'
    + '\n'.join(resources) + '\n[resource]\nanimations = [' + ',\n'.join(clips) + ']\n')
print('Exported editable finale poses and folded coat.')
