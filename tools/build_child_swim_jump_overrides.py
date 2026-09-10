#!/usr/bin/env python3
"""Replace child jump/swim clips with stable, proportionate generated strips."""
from pathlib import Path
import shutil
from typing import Optional
import numpy as np
from PIL import Image
from scipy.ndimage import label, find_objects

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "assets/characters/hooshang_child/act2/packed"
SOURCES = {
    "jump": ROOT / ".codex_missing",  # replaced below by the generated source path
}


def pack(source_path: Path, action: str, target_height: int, target_width: Optional[int] = None) -> None:
    source = np.array(Image.open(source_path).convert("RGBA"))
    labels, _ = label(source[:, :, 3] >= 200)
    bodies = []
    for ident, bounds in enumerate(find_objects(labels), 1):
        if bounds is not None and np.count_nonzero(labels[bounds] == ident) > 1200:
            bodies.append((bounds, ident))
    bodies.sort(key=lambda b: b[0][1].start)
    assert len(bodies) == 7, (action, len(bodies))
    folder = OUT / action
    folder.mkdir(parents=True, exist_ok=True)
    for frame, (bounds, ident) in enumerate(bodies):
        crop = source[bounds].copy()
        crop[:, :, 3] = np.where(labels[bounds] == ident, 255, 0)
        image = Image.fromarray(crop)
        factor = target_height / image.height
        size = (round(image.width * factor), target_height)
        image = image.resize(size, Image.Resampling.NEAREST)
        canvas = Image.new("RGBA", (88, 88))
        if target_width is not None:
            image = image.resize((target_width, round(image.height * target_width / image.width)), Image.Resampling.NEAREST)
        # Fixed center and baseline eliminate per-frame skating in the renderer.
        x = round((88 - image.width) / 2)
        y = 66 - image.height if action == "jump" else round((88 - image.height) / 2)
        canvas.alpha_composite(image, (x, y))
        canvas.save(folder / f"frame_{frame:03d}.png")


if __name__ == "__main__":
    import sys
    pack(Path(sys.argv[1]), "jump", 40)
    pack(Path(sys.argv[2]), "swim", 22)
    # Swim_idle uses the same stable horizontal source until its dedicated strip is generated.
    for i in range(7):
        shutil.copy2(OUT / "swim" / f"frame_{i:03d}.png", OUT / "swim_idle" / f"frame_{i:03d}.png")
