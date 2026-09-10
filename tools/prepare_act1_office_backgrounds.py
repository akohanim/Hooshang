"""Build room-sized nearest-sampled game textures from retained ImageGen sources."""
from pathlib import Path
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
ART = ROOT / 'assets/background/act1_office'
SIZES = [(320, 192)] * 10
SIZES[2] = (880, 192)
SIZES[6] = (200, 408)

for i, size in enumerate(SIZES):
    source = ART / 'source' / f'level_{i}.png'
    image = Image.open(source).convert('RGB')
    if i == 2:
        # ImageGen's wide source is shorter than this 4.6:1 room. Two mirrored
        # architectural runs keep the moons round instead of stretching them.
        from PIL import ImageOps
        width = size[0] // 2
        height = round(image.height * width / image.width)
        bay = image.resize((width, height), Image.Resampling.NEAREST)
        top = (height - size[1]) // 2
        bay = bay.crop((0, top, width, top + size[1]))
        image = Image.new('RGB', size)
        image.paste(bay, (0, 0))
        image.paste(ImageOps.mirror(bay), (width, 0))
    else:
        image = image.resize(size, Image.Resampling.NEAREST)
    # Bound the palette to preserve readable pixel clusters at native scale.
    image = image.quantize(colors=64, dither=Image.Dither.NONE).convert('RGB')
    image.save(ART / f'level_{i}.png')
    print(f'Level_{i}: {size}')
