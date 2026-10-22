"""Repair the erased late-Act-2 floors using their last authored cell footprints.

One-time migration, not a level generator. Keeps current entities, water,
hazards, backgrounds, prison and gardens; uses the current grass brush.
Refuses partial terrain so later hand edits cannot be replaced by this recipe.
"""
import copy
import json
import subprocess
from pathlib import Path

from act2_grass_terrain import rebake_layer
from ldtk_preserve_json import update

ROOT = Path(__file__).resolve().parents[1]
PATH = ROOT / "ldtk/hooshang_act2.ldtk"
REFERENCE = "1bc1d735"
ROOMS = {f"Act_2_Level_{n}" for n in (16, 17, 18, 19, 21)}


def main():
    processes = subprocess.check_output(["ps", "ax", "-o", "command"], text=True)
    assert "LDtk.app/Contents/MacOS/LDtk" not in processes, "Close LDtk first"
    assert not any("Godot" in s and "--editor" in s and str(ROOT) in s for s in processes.splitlines()), "Quit the Godot editor normally first"
    raw = PATH.read_text()
    project = json.loads(raw)
    before = copy.deepcopy(project)
    reference = json.loads(subprocess.check_output(["git", "show", f"{REFERENCE}:ldtk/hooshang_act2.ldtk"]))
    definition = next(d for d in project["defs"]["layers"] if d["identifier"] == "Collisions")
    rules = [r for g in definition["autoRuleGroups"] if g["active"] for r in g["rules"] if r["active"]]
    groups = {v["value"]: v["groupUid"] for v in definition["intGridValues"]}
    repaired = {}
    for room in project["levels"]:
        if room["identifier"] not in ROOMS:
            continue
        terrain = next(a for a in room["layerInstances"] if a["__identifier"] == "Collisions")
        castle = next(a for a in room["layerInstances"] if a["__identifier"] == "CastleTerrain")
        assert not castle["gridTiles"], "Room already has castle terrain"
        assert not any(terrain["intGridCsv"]), "Room has authored terrain; merge manually"
        old_room = next(r for r in reference["levels"] if r["identifier"] == room["identifier"])
        old = next(a for a in old_room["layerInstances"] if a["__identifier"] == "CastleTerrain")
        assert old["gridTiles"] and (old_room["pxWid"], old_room["pxHei"]) == (room["pxWid"], room["pxHei"])
        for tile in old["gridTiles"]:
            x, y = tile["px"]
            terrain["intGridCsv"][y // 8 * terrain["__cWid"] + x // 8] = 10
        rebake_layer(terrain, rules, groups)
        repaired[room["identifier"]] = sum(bool(v) for v in terrain["intGridCsv"])
    for old_room, room in zip(before["levels"], project["levels"]):
        for old_layer, layer in zip(old_room["layerInstances"], room["layerInstances"]):
            if room["identifier"] not in ROOMS or layer["__identifier"] != "Collisions":
                assert old_layer == layer
    backup = ROOT / "output/act2_direction_review/before_terrain_repair.ldtk"
    assert not backup.exists(), "Repair has already run"
    backup.write_text(raw)
    PATH.write_text(update(raw, project))
    print("Restored authored floor footprints using current grass brush:", repaired)


if __name__ == "__main__":
    main()
