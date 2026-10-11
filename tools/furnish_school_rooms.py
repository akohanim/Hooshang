#!/usr/bin/env python3
"""Furnish two named school spaces with existing, editable background atlas tiles.

Collision, auto-tiles, entities, portals and all other rooms are preserved.
Refuses to overwrite props already occupying the intended cells.
"""
import copy
import datetime
import json
import subprocess
from pathlib import Path

from ldtk_preserve_json import update
from validate_prison_ldtk import validate

ROOT = Path(__file__).resolve().parents[1]
PATH = ROOT / "ldtk/hooshang_act2.ldtk"
assert "LDtk.app/Contents/MacOS/LDtk" not in subprocess.check_output(
    ["ps", "ax", "-o", "comm"], text=True
), "Close LDtk before scripted authoring."
raw = PATH.read_text()
project = json.loads(raw)
before = copy.deepcopy(project)
placements = {
    "Prison_G02": [(176, 136, 16, 32, 24, 24), (200, 136, 16, 32, 24, 24)],
    "Prison_Y04": [(136, 136, 0, 32, 16, 24), (160, 136, 0, 32, 16, 24),
                    (184, 136, 0, 32, 16, 24)],
}
for room in project["levels"]:
    if room["identifier"] not in placements:
        continue
    layers = {layer["__identifier"]: layer for layer in room["layerInstances"]}
    decor = layers["Decor"]
    collision = layers["Collision"]
    width = collision["__cWid"]
    for x, y, sx, sy, w, h in placements[room["identifier"]]:
        # Grounded furniture, well away from the room's portal apertures.
        assert all(collision["intGridCsv"][(y + h) // 8 * width + xx] == 1
                   for xx in range(x // 8, (x + w) // 8))
        cells = {(x + dx, y + dy) for dy in range(0, h, 8) for dx in range(0, w, 8)}
        assert all(tile["t"] in (16, 17, 18, 19) for tile in decor["gridTiles"]
                   if tuple(tile["px"]) in cells), "Existing prop: preserve hand edits."
        decor["gridTiles"] = [tile for tile in decor["gridTiles"] if tuple(tile["px"]) not in cells]
        for dy in range(0, h, 8):
            for dx in range(0, w, 8):
                decor["gridTiles"].append(dict(
                    px=[x + dx, y + dy], src=[sx + dx, sy + dy], f=0,
                    t=(sy + dy) // 8 * 16 + (sx + dx) // 8, a=1,
                    d=[(x + dx) // 8 + (y + dy) // 8 * width]))
for old, new in zip(before["levels"], project["levels"]):
    if old["identifier"] not in placements:
        assert old == new
    else:
        for a, b in zip(old["layerInstances"], new["layerInstances"]):
            if a["__identifier"] != "Decor":
                assert a == b
out = ROOT / "output/act2_polish/school_furnishing"
out.mkdir(parents=True, exist_ok=True)
(out / ("before_" + datetime.datetime.now().strftime("%Y%m%d_%H%M%S") + ".ldtk")).write_text(raw)
preview = out / "preview.ldtk"
preview.write_text(update(raw, project))
validate(preview)
PATH.write_text(preview.read_text())
print("Added two bookcases and three lockers; only the two Decor layers changed.")
