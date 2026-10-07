#!/usr/bin/env python3
"""Export young Hooshang's approved Aseprite source and SpriteFrames timing.

Pixels are edited/exported only by Aseprite. This Python wrapper writes Godot
resource text; it never loads or transforms an image. Set ASEPRITE if necessary.
"""
import json
import os
from pathlib import Path
import shutil
import subprocess

ROOT = Path(__file__).resolve().parents[1]
BASE = ROOT / 'assets/characters/hooshang_child'

def main():
    (ROOT / 'output/child_animation_fix').mkdir(parents=True, exist_ok=True)
    binary = os.environ.get('ASEPRITE') or shutil.which('aseprite')
    if not binary:
        binary = str(Path.home() / 'Applications/Aseprite.app/Contents/MacOS/aseprite')
    subprocess.run([binary, '-b', '--script-param', f'root={ROOT}', '--script',
                    str(ROOT / 'tools/export_child_movement.lua')], check=True)
    tags = json.loads((BASE / 'aseprite/movement_export.json').read_text())
    resources, clips, sock_clips = [], [], []
    for tag in tags:
        name = tag['name']
        frames = []
        sock_frames = []
        for i, frame in enumerate(tag['frames']):
            ident = f'{name}_{i}'
            path = f'res://assets/characters/hooshang_child/act2/packed/{name}/frame_{i:03d}.png'
            resources.append(f'[ext_resource type="Texture2D" path="{path}" id="{ident}"]')
            frames.append('{"duration": %.6f, "texture": ExtResource("%s")}' % (frame['duration'], ident))
            points = frame['socks']
            assert len(points) == 2, (name, i)
            sock_frames.append('PackedVector2Array(' + ', '.join(str(v) for point in points for v in point) + ')')
        loop = name in ('idle', 'run', 'sprint', 'skid', 'climb', 'climb_down',
                        'swim', 'swim_idle', 'sit', 'wall_slide')
        clips.append('{"frames": [%s], "loop": %s, "name": &"%s", "speed": 1.0}' %
                     (', '.join(frames), str(loop).lower(), name))
        sock_clips.append('"%s": [%s]' % (name, ', '.join(sock_frames)))
    (BASE / 'act2_frames.tres').write_text('[gd_resource type="SpriteFrames" format=3]\n\n' +
        '\n'.join(resources) + '\n\n[resource]\nmetadata/child_hooshang = true\n' +
        'metadata/visual_scale = 0.375\nmetadata/visual_offset = Vector2(0, -3)\n' +
        'metadata/aseprite_source = "res://assets/characters/hooshang_child/aseprite/young_hooshang_movement.aseprite"\n' +
        'metadata/sock_pixels = {' + ',\n'.join(sock_clips) + '}\n' +
        'animations = [' + ',\n'.join(clips) + ']\n')
    print(f'Exported {sum(len(t["frames"]) for t in tags)} Aseprite frames and {len(clips)} Godot animations.')

if __name__ == '__main__':
    main()
