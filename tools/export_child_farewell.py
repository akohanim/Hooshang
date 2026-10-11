#!/usr/bin/env python3
"""Export the editable farewell source without altering shared character art."""
import json
import subprocess
from pathlib import Path
ROOT = Path(__file__).resolve().parents[1]
ART = ROOT / 'assets/characters/hooshang_child/act2_ending'
subprocess.run(['/Users/ari/Applications/Aseprite.app/Contents/MacOS/aseprite', '--batch',
                str(ART/'source/farewell.aseprite'), '--sheet', str(ART/'farewell.png'),
                '--data', str(ART/'farewell.json'), '--format', 'json-array', '--list-tags'], check=True)
data = json.loads((ART/'farewell.json').read_text())
resources, clips = [], []
for i, frame in enumerate(data['frames']):
    r = frame['frame']
    resources.append(f'[sub_resource type="AtlasTexture" id="f{i}"]\natlas = ExtResource("sheet")\nregion = Rect2({r["x"]},{r["y"]},{r["w"]},{r["h"]})\nfilter_clip = true')
for tag in data['meta']['frameTags']:
    frames = [f'{{"duration": {data["frames"][i]["duration"]}, "texture": SubResource("f{i}")}}'
              for i in range(tag['from'],tag['to']+1)]
    clips.append('{"name": &"'+tag['name']+'", "loop": false, "speed": 1000.0, "frames": ['+', '.join(frames)+']}')
(ART/'farewell_frames.tres').write_text(
    f'[gd_resource type="SpriteFrames" load_steps={len(resources)+2} format=3]\n'
    '[ext_resource type="Texture2D" path="res://assets/characters/hooshang_child/act2_ending/farewell.png" id="sheet"]\n'
    +'\n'.join(resources)+'\n[resource]\nanimations = ['+',\n'.join(clips)+']\n')
