#!/usr/bin/env python3
"""Export the approved 18px Aseprite pack and build Godot SpriteFrames.

Run after saving Aseprite edits. No image resampling or palette modification.
"""
import argparse
import json
from pathlib import Path
import subprocess

ROOT = Path(__file__).resolve().parents[1]
ART = ROOT / 'assets/characters/hooshang/sprites/native18'
SOURCE = ROOT / 'assets/characters/hooshang/aseprite/hooshang_18px_movement.aseprite'
# Gameplay cadence tuning; source Aseprite frame durations remain editable.
PLAYBACK_MULTIPLIERS = {'run': 1.6}
LOOPS = {'idle', 'run', 'climb', 'climb_down', 'climb_idle', 'fall', 'wall_slide', 'swim', 'swim_idle'}


def build(export=True):
    ART.mkdir(parents=True, exist_ok=True)
    if export:
        subprocess.run([
            '/Users/ari/Applications/Aseprite.app/Contents/MacOS/aseprite',
            '--batch', str(SOURCE), '--sheet', str(ART / 'movement.png'),
            '--sheet-type', 'horizontal', '--data', str(ART / 'movement.json'),
            '--format', 'json-array', '--list-tags'], check=True)
    data = json.loads((ART / 'movement.json').read_text())
    frames = data['frames']
    resources, animations = [], []
    for i, frame in enumerate(frames):
        box = frame['frame']
        assert box['w'] == box['h'] == 18, box
        resources.append(f'[sub_resource type="AtlasTexture" id="frame_{i}"]\natlas = ExtResource("sheet")\nregion = Rect2({box["x"]}, {box["y"]}, 18, 18)\nfilter_clip = true')
    for tag in data['meta']['frameTags']:
        name = tag['name']
        entries = []
        for i in range(tag['from'], tag['to'] + 1):
            # 1000fps makes each relative duration equal to its actual ms.
            entries.append('{"duration": ' + str(float(frames[i]['duration'])) + ', "texture": SubResource("frame_' + str(i) + '")}')
        speed = 1000.0 * PLAYBACK_MULTIPLIERS.get(name, 1.0)
        animations.append('{"frames": [' + ', '.join(entries) + '], "loop": ' + str(name in LOOPS).lower() + ', "name": &"' + name + '", "speed": ' + str(speed) + '}')
    # Gameplay phases reuse approved poses; source tags remain the editing contract.
    tags = {tag['name']: tag for tag in data['meta']['frameTags']}
    jump = tags['jump']['from']
    phases = {
        'takeoff': [(jump, 30), (jump + 1, 30)],
        'rise': [(jump + i, 60) for i in range(2, 6)],
        'apex': [(tags['jump']['to'], 100)],
        'land': [(tags['crouch']['from'], 55)],
        'recover': [(tags['idle']['from'], 65)],
    }
    for name, poses in phases.items():
        entries = ['{"duration": ' + str(float(ms)) + ', "texture": SubResource("frame_' + str(i) + '")}' for i, ms in poses]
        animations.append('{"frames": [' + ', '.join(entries) + '], "loop": false, "name": &"' + name + '", "speed": 1000.0}')
    text = f'[gd_resource type="SpriteFrames" load_steps={len(resources)+2} format=3]\n\n'
    text += '[ext_resource type="Texture2D" path="res://assets/characters/hooshang/sprites/native18/movement.png" id="sheet"]\n\n'
    text += '\n\n'.join(resources) + '\n\n[resource]\nanimations = [' + ',\n'.join(animations) + ']\n'
    # Standing opaque pixels end at row 18: 18 - 9 - 3 = collider feet (+6).
    text += 'metadata/visual_scale = 1.0\nmetadata/visual_offset = Vector2(0, -3)\nmetadata/native_pixel_size = 18\n'
    (ROOT / 'assets/characters/hooshang/hooshang_frames.tres').write_text(text)
    print(f'Imported {len(frames)} frames in {len(animations)} clips from Aseprite')


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--use-export', action='store_true', help='Use the existing Aseprite PNG/JSON export')
    build(export=not parser.parse_args().use_export)
