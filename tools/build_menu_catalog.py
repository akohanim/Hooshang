"""Build the chapter browser's room catalog from LDtk; the menu never loads a world.

Writes `resources/menu/rooms.json`: one list per Act, one entry per level, with
everything the Explore Chapters WORLD MAP needs to draw that Act without
instancing it — where the room sits in the world (`pos`, LDtk worldX/worldY),
how big it is, a terrain GRID, and a few markers (start, exits, keys).

`grid` is one character per 8px cell, row-major, `size[0]/8` cells wide:
  .  empty      #  solid      =  platform (one-way / scaffolding / crumbling)
  ^  hazard     ~  water
Kinds come from the IntGrid value's IDENTIFIER, not its number, because the
numbers disagree between Acts (4 is `Water` in Act 2's Collision layer and
`UnderworldTrigger` in Act 1's and Act 3's).

Re-run after moving, adding or repainting a room in any `ldtk/hooshang_act*.ldtk`,
or the map shows the old layout: `python3 tools/build_menu_catalog.py`.
"""
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
CELL = 8
# Which kind wins when two layers paint the same cell.
PRIORITY = {".": 0, "~": 1, "=": 2, "^": 3, "#": 4}
TERRAIN_LAYERS = ("Collisions", "Collision", "CastleTerrain")
MARKERS = ("PlayerStart", "PlayerSpawn", "Exit", "ExitCeiling", "Key", "Cage", "Checkpoint")
PLATFORMS = ("CrumblingPlatform", "SpringPlatform", "CrumblingShelf", "SwimCrumblingPlatform")


def kind_for(layer: str, value_name: str) -> str:
    if layer in ("ThoughtHazards", "InkThoughtHazards") or value_name == "Hazard":
        return "^"
    if layer == "Water" or value_name == "Water":
        return "~"
    if value_name in ("OneWay", "scaffolding", "Scaffolding"):
        return "="
    if value_name == "UnderworldTrigger":
        return ""
    return "#"


def build_room(level: dict, value_names: dict) -> dict:
    cols, rows = level["pxWid"] // CELL, level["pxHei"] // CELL
    grid = ["."] * (cols * rows)

    def paint(x: int, y: int, kind: str) -> None:
        cx, cy = x // CELL, y // CELL
        if 0 <= cx < cols and 0 <= cy < rows and PRIORITY[kind] > PRIORITY[grid[cy * cols + cx]]:
            grid[cy * cols + cx] = kind

    markers = []
    for layer in level["layerInstances"]:
        name = layer["__identifier"]
        size = layer["__gridSize"]
        if layer["__type"] == "IntGrid" and (name in TERRAIN_LAYERS or name in ("Water", "ThoughtHazards", "InkThoughtHazards")):
            for i, value in enumerate(layer["intGridCsv"]):
                kind = kind_for(name, value_names.get((name, value), "")) if value else ""
                if kind:
                    for dy in range(0, size, CELL):
                        for dx in range(0, size, CELL):
                            paint((i % layer["__cWid"]) * size + dx, (i // layer["__cWid"]) * size + dy, kind)
        # Painted tiles only: an IntGrid layer's auto-tiles mirror its own cells,
        # and counting them as solid would bury its scaffolding and hazards.
        if name in TERRAIN_LAYERS and layer["__type"] == "Tiles":
            for tile in layer["gridTiles"]:
                paint(tile["px"][0], tile["px"][1], "#")
        for entity in layer["entityInstances"]:
            ident = entity["__identifier"]
            left = entity["px"][0] - entity["__pivot"][0] * entity["width"]
            top = entity["px"][1] - entity["__pivot"][1] * entity["height"]
            if ident in MARKERS:
                markers.append([round(left + entity["width"] / 2), round(top + entity["height"] / 2), ident])
            elif ident in PLATFORMS:
                for y in range(int(top), int(top + entity["height"]), CELL):
                    for x in range(int(left), int(left + entity["width"]), CELL):
                        paint(x, y, "=")
    return dict(
        id=level["identifier"],
        pos=[level["worldX"], level["worldY"]],
        size=[level["pxWid"], level["pxHei"]],
        grid="".join(grid),
        markers=markers,
    )


def main() -> None:
    names = {}
    for recipe in ["act2_precision", "act2_expansion", "act2_final_trials"]:
        for r in json.loads((ROOT / f"resources/levels/{recipe}.json").read_text()):
            names[r["name"]] = r
    # Act III's titles and chapters come from the same table that draws its
    # rooms (tools/build_act3_world.py -> resources/levels/act3_rooms.json).
    chapters = {1: "I · THE INK SHORE", 2: "II · THE SHALLOWS", 3: "III · THE DROWNED OFFICE",
                4: "IV · THE REEF OF LANTERNS", 5: "V · THE FLOOR OF LIGHT", 6: "EPILOGUE"}
    act3_path = ROOT / "resources/levels/act3_rooms.json"
    if act3_path.exists():
        for room_id, meta in json.loads(act3_path.read_text()).items():
            names[room_id] = {"title": meta["title"], "idea": chapters.get(meta["chapter"], "")}
    acts = []
    for act in range(1, 4):
        project = json.loads((ROOT / f"ldtk/hooshang_act{act}.ldtk").read_text())
        value_names = {}
        for layer in project["defs"]["layers"]:
            for v in layer.get("intGridValues", []):
                value_names[(layer["identifier"], v["value"])] = v.get("identifier") or ""
        rooms = []
        for level in project["levels"]:
            if level["identifier"].startswith("Act3_Sketch_"):
                continue  # kept in the project, shelved out of the route
            room = build_room(level, value_names)
            recipe = names.get(level["identifier"], {})
            room["title"] = recipe.get("title", "")
            room["idea"] = recipe.get("idea", "")
            rooms.append(room)
        acts.append(rooms)
    (ROOT / "resources/menu/rooms.json").write_text(json.dumps(acts, separators=(",", ":")) + "\n")


if __name__ == "__main__":
    main()
