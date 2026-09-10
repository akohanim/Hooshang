"""Prepare approved generated sheets for the existing 96px / 0.5-scale rig.

Only asset preparation: threshold extraction alpha, align by turban/feet,
sample at game resolution, share a palette, and pack nearest-scaled atlases.
The approved poses are the source, not procedurally redrawn replacements.
Run from any directory with Python + Pillow + numpy.
"""
from pathlib import Path
import json
import shutil
import numpy as np
from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[1]
DEST = ROOT / 'assets/characters/rumi/sprites'
SOURCE = DEST / 'source'
PREVIEW = ROOT / 'output/imagegen/rumi-animations'
SPECS = {'idle': ('idle.png', 4, 1, 4),
         'walk': ('walk-transparent.png', 4, 2, 8),
         'give_glow': ('give_glow-transparent.png', 3, 2, 6)}


def prepare(name, filename, cols, rows):
    path = SOURCE / filename
    if not path.exists():
        shutil.copy2(PREVIEW / filename, path)
    source = np.array(Image.open(path).convert('RGBA'))
    height, width = source.shape[:2]
    frames = []
    for row in range(rows):
        for col in range(cols):
            a = source[round(row*height/rows):round((row+1)*height/rows),
                       round(col*width/cols):round((col+1)*width/cols)].copy()
            # Extraction variants have nearly-opaque interiors (252-254),
            # not 255. Drop soft halos and make the actual sprite fully opaque.
            mask = a[:, :, 3] >= 220
            r, g, b = (a[:, :, i].astype(int) for i in range(3))
            # The existing live mote supplies the light; don't bake its flight
            # into the actor as well. Yellow never occurs on Rumi himself.
            if name == 'give_glow':
                mask &= ~((r > 180) & (g > 155) & (b < g * .7))
            a[:, :, 3] = np.where(mask, 255, 0)
            ys, xs = np.where(mask)
            assert len(xs), (name, row, col)
            top, bottom = ys.min(), ys.max()+1
            # Anchor the head, not the changing width of his arm or stride.
            orange = mask & (r > 130) & (r > g*1.35) & (g > b*1.5)
            orange[top + (bottom-top)//3:] = False
            ox = np.where(orange)[1]
            head_x = (ox.min()+ox.max()+1)/2
            scale = 18/(bottom-top)  # original samurai occupied ~17 world px
            # Sample each game pixel at its centre. Constant feet/head anchor
            # avoids the lateral jitter of independently centred tight crops.
            result = np.zeros((48, 48, 4), dtype=np.uint8)
            for y in range(48):
                sy = int(bottom + (y+.5-40)/scale)
                for x in range(48):
                    sx = int(head_x + (x+.5-24)/scale)
                    if 0 <= sy < a.shape[0] and 0 <= sx < a.shape[1]:
                        result[y,x] = a[sy,sx]
            result[result[:,:,3] == 0] = 0
            frames.append(Image.fromarray(result))
    return frames


def main():
    SOURCE.mkdir(parents=True, exist_ok=True)
    clips = {name: prepare(name, f, c, r) for name, (f,c,r,_) in SPECS.items()}
    # Shared 24-colour palette removes generation noise and palette flicker.
    pixels = [np.array(im)[np.array(im)[:,:,3] > 0,:3]
              for frames in clips.values() for im in frames]
    samples = np.concatenate(pixels).reshape(1,-1,3)
    palette = Image.fromarray(samples).quantize(colors=24)
    for name, frames in clips.items():
        atlas = Image.new('RGBA', (96*len(frames),96))
        for i, im in enumerate(frames):
            alpha = im.getchannel('A')
            im = im.convert('RGB').quantize(palette=palette, dither=Image.Dither.NONE).convert('RGBA')
            im.putalpha(alpha)
            frames[i] = im
            atlas.paste(im.resize((96,96),Image.Resampling.NEAREST), (96*i,0))
        atlas.save(DEST / (name+'.png'))
    # A still used by DialogueBox's legacy default (normal dialogue supplies
    # the existing expressive portrait art instead).
    clips['idle'][0].crop((17,21,30,35)).resize((52,56),Image.Resampling.NEAREST).save(DEST/'portrait.png')
    parts = ['[gd_resource type="SpriteFrames" format=3 uid="uid://cktdl6l6c7a5v"]']
    for name in clips:
        parts.append(f'[ext_resource type="Texture2D" path="res://assets/characters/rumi/sprites/{name}.png" id="{name}"]')
    for name, frames in clips.items():
        for i in range(len(frames)):
            parts.append(f'[sub_resource type="AtlasTexture" id="{name}_{i}"]\natlas = ExtResource("{name}")\nregion = Rect2({i*96}, 0, 96, 96)')
    animations = []
    # Legacy movement names remain available to older greybox consumers,
    # but none retain any samurai textures.
    mappings = {name:(name,list(range(len(frames)))) for name,frames in clips.items()}
    mappings.update({'run':('walk',list(range(8))), 'jump':('walk',[2]),
                     'fall':('walk',[3]), 'dash':('walk',[0]), 'wall_slide':('idle',[0])})
    for name,(clip,indices) in mappings.items():
        frames = ', '.join('{"duration": 1.0, "texture": SubResource("%s_%d")}' % (clip,i) for i in indices)
        fps = SPECS[clip][3]
        animations.append('{"frames": [%s], "loop": %s, "name": &"%s", "speed": %.1f}' % (frames, 'false' if name=='give_glow' else 'true', name, fps))
    parts.append('[resource]\nanimations = [' + ',\n'.join(animations) + ']')
    (DEST.parent/'rumi_frames.tres').write_text('\n\n'.join(parts)+'\n')
    # Review at integer scale, including the genuine 18px game footprint.
    previews=[]
    for tick in range(24):
        canvas=Image.new('RGB',(720,270),(38,39,48))
        draw=ImageDraw.Draw(canvas)
        for j,(name,frames) in enumerate(clips.items()):
            i = (tick//2)%len(frames)
            im = frames[i]
            canvas.paste(im.resize((240,240),Image.Resampling.NEAREST),(j*240,0),im.resize((240,240),Image.Resampling.NEAREST))
            draw.text((j*240+12,240),name,fill='white')
            canvas.paste(im,(j*240+172,215),im)
        previews.append(canvas)
    previews[0].save(PREVIEW/'in-game-animations.gif',save_all=True,append_images=previews[1:],duration=100,loop=0)
    previews[0].save(PREVIEW/'in-game-contact.png')
    (DEST/'manifest.json').write_text(json.dumps({'frame_size':[96,96], 'render_scale':.5, 'occupied_height_world_px':18,
        'animations':{n:{'frames':len(f),'fps':SPECS[n][3],'loop':n!='give_glow'} for n,f in clips.items()}},indent=2)+'\n')


if __name__ == '__main__':
    main()
