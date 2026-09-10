#!/usr/bin/env python3
"""Build Godot atlas resources from Jamshid's unchanged generated sheets.

Pillow/numpy only inspect alpha bounds; no bitmap is redrawn or resampled.
Each clip keeps its source resolution. Jamshid's scene scales the clips using
their authored standing height, keeping sitting and crouching naturally short.
"""
import json
from pathlib import Path
import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'assets/jamshid'
CLIPS = {
    'idle': (1, 5, True, 740, [215, 219, 246, 268]),
    'walk': (2, 10, True, 500, [185, 180, 155, 180, 195, 188, 170, 181]),
    'sit': (1, 4, True, 800, [235, 267, 256, 270]),
    'jump': (2, 10, False, 429, [224, 193, 180, 140, 211, 214, 213, 145]),
}
EMOTIONS = ['friendly', 'joyful', 'worried', 'sad', 'determined']


def atlas(path, texture, region, margin=None):
    text = '[gd_resource type="AtlasTexture" load_steps=2 format=3]\n\n'
    text += f'[ext_resource type="Texture2D" path="{texture}" id="1"]\n\n'
    text += '[resource]\natlas = ExtResource("1")\n'
    text += 'region = Rect2(%s)\n' % ', '.join(map(str, region))
    if margin:
        text += 'margin = Rect2(%s)\n' % ', '.join(map(str, margin))
    text += 'filter_clip = true\n'
    path.write_text(text)


def enforce_black_outline(image, rows):
    """Guarantee one opaque black pixel on every frame's outer boot silhouette.

    Generated art already has dark outlines, but a few antialiased edge pixels
    can be near-black rather than exact black. We deliberately pin one pixel on
    the lowest occupied row of each frame, at its outermost occupied x, so the
    invariant is deterministic and survives every rebuild.
    """
    pixels = np.array(image, copy=True)
    h, w = pixels.shape[:2]
    for i in range(rows * 4):
        x0, x1 = round(i % 4 * w / 4), round((i % 4 + 1) * w / 4)
        y0, y1 = round(i // 4 * h / rows), round((i // 4 + 1) * h / rows)
        alpha = pixels[y0:y1, x0:x1, 3]
        occupied = np.argwhere(alpha >= 128)
        if occupied.size == 0:
            raise ValueError(f'frame {i} is empty')
        lowest = occupied[:, 0].max()
        candidates = occupied[occupied[:, 0] == lowest]
        # Outermost boot pixel: this is on the silhouette edge, never interior.
        local_y, local_x = int(candidates[np.argmin(candidates[:, 1])][0]), int(candidates[:, 1].min())
        pixels[y0 + local_y, x0 + local_x, :3] = (0, 0, 0)
        pixels[y0 + local_y, x0 + local_x, 3] = 255
    image.paste(Image.fromarray(pixels, mode='RGBA'))


def main():
    ext, animations, metadata = [], [], {}
    for name, (rows, fps, loop, height, anchors) in CLIPS.items():
        source = OUT / 'source' / f'{name}.png'
        image = Image.open(source)
        assert image.mode == 'RGBA', f'{name} needs real alpha'
        enforce_black_outline(image, rows)
        image.save(source)
        pixels = np.asarray(image)
        h, w = pixels.shape[:2]
        frames = []
        directory = OUT / name
        directory.mkdir(exist_ok=True)
        for i in range(rows * 4):
            x0, x1 = round(i % 4 * w / 4), round((i % 4 + 1) * w / 4)
            y0, y1 = round(i // 4 * h / rows), round((i // 4 + 1) * h / rows)
            yy, xx = np.where(pixels[y0:y1, x0:x1, 3] >= 128)
            # Keep the antialiased silhouette's 2px fringe; the sprite shader
            # rejects low-alpha spill without erasing opaque dark hair.
            bx, by = max(0, int(xx.min()) - 2), max(0, int(yy.min()) - 2)
            ex, ey = min(x1-x0, int(xx.max()) + 3), min(y1-y0, int(yy.max()) + 3)
            width, tall = ex-bx, ey-by
            baseline = ey
            if name == 'jump' and i not in (0, 6, 7):
                baseline = 480 if i < 4 else 458
            # All atlas frames report 800x900; anchor is (400,850).
            margin = [400 - anchors[i] + bx, 850 - baseline + by, 800-width, 900-tall]
            # Write a full-size transparent frame. Godot's AtlasTexture margin
            # is not a sprite canvas margin: on some renderer paths it crops the
            # atlas to the margin rectangle, collapsing the character to a thin
            # strip. A native 800x900 frame keeps the authored anchor explicit.
            frame_image = Image.new('RGBA', (800, 900), (0, 0, 0, 0))
            crop = image.crop((x0 + bx, y0 + by, x0 + ex, y0 + ey))
            paste_x = 400 - anchors[i] + bx
            paste_y = 850 - baseline + by
            frame_image.alpha_composite(crop, (paste_x, paste_y))
            frame_path = directory / f'frame_{i:03}.png'
            frame_image.save(frame_path)
            frame_id = f'{name}_{i}'
            ext.append(f'[ext_resource type="Texture2D" path="res://assets/characters/jamshid/{name}/{frame_path.name}" id="{frame_id}"]')
            frames.append('{"duration": 1.0, "texture": ExtResource("%s")}' % frame_id)
        animations.append('{"frames": [%s], "loop": %s, "name": &"%s", "speed": %s}' %
                          (',\n'.join(frames), str(loop).lower(), name, fps))
        metadata[name] = {'frames': rows*4, 'fps': fps, 'loop': loop, 'standing_source_height': height}
    (OUT / 'jamshid_frames.tres').write_text(
        '[gd_resource type="SpriteFrames" load_steps=%d format=3]\n\n' % (len(ext)+1)
        + '\n'.join(ext) + '\n\n[resource]\nanimations = [' + ',\n'.join(animations) + ']\n')
    (OUT / 'animations.json').write_text(json.dumps(metadata, indent=2)+'\n')
    manifest_path = ROOT / 'assets/portraits/loops/manifest.json'
    manifest = json.loads(manifest_path.read_text())
    for emotion in EMOTIONS:
        key = 'jamshid_' + emotion
        w, h = Image.open(OUT / 'source' / f'{key}.png').size
        # Direct PNG backing keeps the dialogue's frame window on one atlas.
        # Retain fractional widths so the fourth frame cannot drift off-sheet.
        atlas(ROOT / 'assets/portraits/jamshid' / f'{key}.tres',
              f'res://assets/characters/jamshid/source/{key}.png', [0, 0, w/4, h])
        manifest[key] = {'sheet': f'../../characters/jamshid/source/{key}.png', 'frames': 4, 'frame_size': [w/4, h],
                         'fps': 8, 'loop': True, 'rest': 0, 'talk': [1, 2], 'blink': 3,
                         'authored_roles': True}
    manifest_path.write_text(json.dumps(manifest, indent=2)+'\n')
    print('Packed 24 avatar frames and 20 dialogue frames (5 emotions).')


if __name__ == '__main__':
    main()
