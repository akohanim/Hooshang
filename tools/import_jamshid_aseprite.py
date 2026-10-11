#!/usr/bin/env python3
"""Export saved Jamshid child art through Aseprite; write matching Godot clips."""
import json
import os
from pathlib import Path
import subprocess

ROOT = Path(__file__).resolve().parents[1]
BASE = ROOT / 'assets/characters/jamshid'
LOOPS = {'idle', 'run', 'sprint', 'skid', 'climb', 'climb_down', 'swim', 'swim_idle', 'sit', 'wall_slide'}

def main():
    art = BASE / 'sprites/child'
    art.mkdir(parents=True, exist_ok=True)
    binary = os.environ.get('ASEPRITE', str(Path.home() / 'Applications/Aseprite.app/Contents/MacOS/aseprite'))
    subprocess.run([binary, '-b', '--script-param', f'root={ROOT}', '--script', str(ROOT / 'tools/export_jamshid_movement.lua')], check=True)
    data = json.loads((art / 'movement.json').read_text())
    socks = json.loads((art / 'socks.json').read_text())
    resources, clips, sock_clips = [], [], []
    for i, frame in enumerate(data['frames']):
        box = frame['frame']
        assert box['w'] == box['h'] == 88
        resources.append(f'[sub_resource type="AtlasTexture" id="f{i}"]\natlas = ExtResource("sheet")\nregion = Rect2({box["x"]}, {box["y"]}, 88, 88)\nfilter_clip = true')
    tags = data['meta']['frameTags']
    tags = tags + [dict(next(t for t in tags if t['name'] == 'run'), name='walk')]
    for tag in tags:
        name = tag['name']
        order = list(range(tag['from'], tag['to'] + 1))
        if tag['direction'] == 'pingpong':
            order += order[-2:0:-1]
        elif tag['direction'] == 'reverse':
            order.reverse()
        else:
            assert tag['direction'] == 'forward', tag
        entries = ['{"duration": %.6f, "texture": SubResource("f%d")}' % (data['frames'][i]['duration']/1000, i) for i in order]
        clips.append('{"frames": [%s], "loop": %s, "name": &"%s", "speed": 1.0}' % (', '.join(entries), str(name in LOOPS or name == 'walk').lower(), name))
        points = ['PackedVector2Array(' + ', '.join(str(v) for p in socks[i] for v in p) + ')' for i in order]
        sock_clips.append('"%s": [%s]' % (name, ', '.join(points)))
    text = '[gd_resource type="SpriteFrames" format=3]\n\n[ext_resource type="Texture2D" path="res://assets/characters/jamshid/sprites/child/movement.png" id="sheet"]\n\n'
    text += '\n\n'.join(resources) + '\n\n[resource]\nmetadata/visual_scale = 0.375\nmetadata/visual_offset = Vector2(0, -3)\n'
    text += 'metadata/aseprite_source = "res://assets/characters/jamshid/aseprite/jamshid_child_movement.aseprite"\n'
    text += 'metadata/sock_pixels = {' + ',\n'.join(sock_clips) + '}\nanimations = [' + ',\n'.join(clips) + ']\n'
    (BASE / 'jamshid_frames.tres').write_text(text)
    print(f'Exported {len(data["frames"])} frames; {len(clips)} clips including walk alias')

if __name__ == '__main__':
    main()
