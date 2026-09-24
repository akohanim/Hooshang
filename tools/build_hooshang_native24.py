#!/usr/bin/env python3
"""Pack the approved Hooshang / PixelLab animations into native 24px atlases.

Source frame 0 is PixelLab's unchanged input, not part of a run/dash cycle.
Keep the generated pixel coordinates: never fit each pose to its own bounds,
which would stretch knees and cancel the authored breathing/stride motion.
Only normalize alpha/palette and the exterior one-pixel black contour.
Rebuild locally without calling a generation service:
    python3 tools/build_hooshang_native24.py
"""
from pathlib import Path
import json

import numpy as np
from PIL import Image, ImageDraw
from scipy import ndimage

ROOT = Path(__file__).resolve().parents[1]
ART = ROOT / "assets/characters/hooshang/sprites/native24"
REVIEW = ROOT / "output/hooshang_native24"
SIZE = 24
PALETTE = np.array([
    (0, 0, 0), (45, 40, 47), (136, 137, 137),
    (255, 165, 99), (222, 136, 76), (112, 55, 28), (78, 35, 17),
    (145, 216, 245), (91, 176, 218), (102, 21, 49), (68, 15, 33),
    (77, 37, 17), (214, 155, 78),
], dtype=np.int32)
CLIPS = {
    "idle": (6, True), "run": (12, True), "dash": (24, False),
    "jump": (16, False), "wall_slide": (6, True), "climb": (12, True),
    "swim": (8, True), "exit_water": (12, False),
}


def normalize(image):
    assert image.size == (SIZE, SIZE), image.size
    pixels = np.array(image.convert("RGBA"))
    opaque = pixels[:, :, 3] >= 128
    distances = ((pixels[:, :, None, :3].astype(np.int32)
                  - PALETTE[None, None, :, :]) ** 2).sum(axis=3)
    pixels[:, :, :3] = PALETTE[distances.argmin(axis=2)]
    boundary = opaque & ~ndimage.binary_erosion(opaque)
    pixels[boundary, :3] = 0
    pixels[:, :, 3] = opaque * 255
    pixels[~opaque] = 0
    return Image.fromarray(pixels)


def preserve_head(image):
    """Register the approved head on the generated neck, preventing AI eyes.

    Track the largest upper skin component, rather than the whole silhouette:
    swinging hands/feet must not shift the head. The head ends directly above
    the first blue shirt row. All replacements use integer translations only.
    """
    pixels = np.array(image)
    rgb = pixels[:, :, :3]
    skin = (rgb[:, :, 0] > 180) & (rgb[:, :, 1] > 100) & (rgb[:, :, 2] < 140)
    skin[13:] = False
    labels, count = ndimage.label(skin)
    if not count:
        return image
    sizes = ndimage.sum(skin, labels, range(1, count + 1))
    ys, xs = np.where(labels == (int(np.argmax(sizes)) + 1))
    blue = (rgb[:, :, 2] > 180) & (rgb[:, :, 0] < 170)
    by, bx = np.where(blue & (np.indices(blue.shape)[0] >= ys.min()))
    neck_y = int(by.min()) if len(by) else int(ys.max()) + 1
    dx = int(np.clip(xs.max() - 15, -5, 5))
    dy = int(np.clip(neck_y - 9, 0, 5))
    # Remove only the old head box, leaving lifted arms outside it intact.
    left, right = max(0, int(xs.min()) - 3), min(24, int(xs.max()) + 3)
    pixels[:neck_y, left:right] = 0
    result = Image.fromarray(pixels)
    approved = Image.open(ART / "base.png").convert("RGBA").crop((7, 1, 17, 9))
    result.alpha_composite(approved, (7 + dx, 1 + dy))
    return normalize(result)


def build():
    REVIEW.mkdir(parents=True, exist_ok=True)
    frames = {}
    for name in CLIPS:
        paths = sorted((ART / "source" / name).glob("frame_*.png"))
        assert len(paths) >= 5, f"Missing generated frames for {name}"
        # Idle starts in the approved pose. Actions start in motion.
        frames[name] = [preserve_head(normalize(Image.open(p)))
                        for p in paths[(0 if name == "idle" else 1):]]

    # Existing controller names remain available without ever switching back
    # to the old character. The airborne hold and wall kick share jump poses;
    # seated cutscenes use the low braced stance, and floating uses a slow stroke.
    frames["fall"] = frames["jump"][-2:]
    frames["wall_jump"] = frames["jump"]
    frames["wall_land"] = frames["wall_slide"][:1]
    frames["swim_idle"] = frames["swim"]
    settings = dict(CLIPS, fall=(5, True), wall_jump=(16, False),
                    wall_land=(6, False), swim_idle=(3, True))
    ext, sub, animations = [], [], []
    manifest = {"frame_size": [24, 24], "visual_scale": 1.0,
                "visual_offset": [0, -5], "clips": {}}
    review = Image.new("RGB", (24 * 8 * 5, len(frames) * 150), (61, 59, 106))
    draw = ImageDraw.Draw(review)
    for row, (name, images) in enumerate(frames.items()):
        atlas = Image.new("RGBA", (SIZE * len(images), SIZE))
        for i, im in enumerate(images):
            atlas.alpha_composite(im, (SIZE * i, 0))
        atlas.save(ART / f"{name}.png")
        ext.append(f'[ext_resource type="Texture2D" path="res://assets/characters/hooshang/sprites/native24/{name}.png" id="{name}"]')
        entries = []
        for i in range(len(images)):
            ident = f"{name}_{i}"
            sub.append(f'[sub_resource type="AtlasTexture" id="{ident}"]\natlas = ExtResource("{name}")\nregion = Rect2({i * SIZE}, 0, 24, 24)\nfilter_clip = true')
            entries.append('{"duration": 1.0, "texture": SubResource("' + ident + '")}')
        speed, loop = settings[name]
        animations.append('{"frames": [' + ', '.join(entries) + '],\n"loop": ' + str(loop).lower() + ', "name": &"' + name + '", "speed": ' + str(float(speed)) + '}')
        manifest["clips"][name] = {"frames": len(images), "fps": speed, "loop": loop}
        draw.text((4, row * 150 + 3), f"{name} | {len(images)} frames | {speed} fps", fill="white")
        review.paste(atlas.resize((atlas.width * 5, SIZE * 5), Image.Resampling.NEAREST),
                     (0, row * 150 + 22), atlas.resize((atlas.width * 5, SIZE * 5), Image.Resampling.NEAREST))
        previews = []
        for im in images:
            bg = Image.new("RGBA", im.size, (61, 59, 106, 255))
            bg.alpha_composite(im)
            previews.append(bg.convert("RGB").resize((240, 240), Image.Resampling.NEAREST))
        previews[0].save(REVIEW / f"{name}.gif", save_all=True, append_images=previews[1:],
                         duration=round(1000 / speed), loop=0, disposal=2)
    resource = '[gd_resource type="SpriteFrames" load_steps=' + str(1 + len(ext) + len(sub)) + ' format=3]\n\n'
    resource += '\n'.join(ext) + '\n\n' + '\n\n'.join(sub)
    resource += '\n\n[resource]\nanimations = [' + ',\n'.join(animations) + ']\n'
    resource += 'metadata/visual_scale = 1.0\nmetadata/visual_offset = Vector2(0, -5)\nmetadata/native_pixel_size = 24\n'
    (ROOT / "assets/characters/hooshang/hooshang_frames.tres").write_text(resource)
    (ART / "manifest.json").write_text(json.dumps(manifest, indent=2) + "\n")
    review.save(REVIEW / "all_sheets.png")
    print(json.dumps(manifest, indent=2))


if __name__ == "__main__":
    build()
