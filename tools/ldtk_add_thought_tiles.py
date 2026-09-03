#!/usr/bin/env python3
"""Add the paintable ThoughtHazards IntGrid layer to the LDtk project.

Adds THREE things:

  1. A tileset definition for the `thought_tiles.png` sheet drawn by
     tools/gen_thought_tiles.py (4 tiles at 8px: fill, top edge, left edge,
     top-left corner).

  2. A layer definition — an IntGrid layer called `ThoughtHazards`, with one
     IntGrid value (`thought`, value 1) and four auto-layer rules that give
     every painted cell the right tile: corner + flipXY, top + flipY,
     left + flipX, fill.

  3. An empty layer instance in every existing level, so the file is complete
     and can be imported without opening LDtk first.

The painted cells are pass-through (not walls): scripts/ldtk_level_post_import.gd
disables collision on the ThoughtHazards TileMapLayer, and scripts/ldtk_world.gd
checks tile overlap each frame to kill the player.

EDITED AS TEXT, following ldtk_add_ceiling_tile.py's precedent.

LDTK MUST BE CLOSED. It holds the whole project in memory and writes it back
wholesale — CLAUDE.md records that happening already.

Idempotent: running it twice adds nothing the second time.

Usage:  python3 tools/ldtk_add_thought_tiles.py          # dry run
        python3 tools/ldtk_add_thought_tiles.py --apply
"""
import json
import os
import re
import sys
import uuid

from PIL import Image

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from ldtk_add_ceiling_tile import array_end, block, ldtk_running, object_span

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
LDTK = os.path.join(ROOT, "ldtk", "hooshang_act1.ldtk")
APPLY = "--apply" in sys.argv

LAYER_ID = "ThoughtHazards"
VALUE_ID = "thought"
VALUE_NUM = 1
VALUE_COLOR = "#D42020"
TILESET_ID = "ThoughtTilesSheet"
ART_REL = "art/thought_tiles.png"
ART_ABS = os.path.join(ROOT, "ldtk", ART_REL)
CELL = 8
TILES = 4  # fill, top, left, corner


def make_tileset(uid):
    img = Image.open(ART_ABS)
    return {
        "identifier": TILESET_ID,
        "uid": uid,
        "relPath": ART_REL,
        "pxWid": img.width,
        "pxHei": img.height,
        "__cWid": img.width // CELL,
        "__cHei": img.height // CELL,
        "tileGridSize": CELL,
        "spacing": 0,
        "padding": 0,
        "tags": [],
        "tagsSourceEnumUid": None,
        "enumTags": [],
        "customData": [],
        "savedSelections": [],
        "cachedPixelData": None,
        "embedAtlas": None,
    }


def make_rule(uid, tile_id, pattern, flip_x, flip_y):
    return {
        "uid": uid,
        "active": True,
        "size": 3 if len(pattern) == 9 else 1,
        "tileRectsIds": [[tile_id]],
        "alpha": 1,
        "chance": 1,
        "breakOnMatch": True,
        "pattern": pattern,
        "flipX": flip_x,
        "flipY": flip_y,
        "xModulo": 1,
        "yModulo": 1,
        "xOffset": 0,
        "yOffset": 0,
        "tileXOffset": 0,
        "tileYOffset": 0,
        "tileRandomXMin": 0,
        "tileRandomXMax": 0,
        "tileRandomYMin": 0,
        "tileRandomYMax": 0,
        "checker": "None",
        "tileMode": "Single",
        "pivotX": 0,
        "pivotY": 0,
        "outOfBoundsValue": 0,
        "invalidated": False,
        "perlinActive": False,
        "perlinSeed": 1234567,
        "perlinScale": 0.2,
        "perlinOctaves": 2,
    }


def make_layer(uid, tileset_uid, rule_uids):
    V = VALUE_NUM
    rules = [
        # Corner: not-thought above AND left → tile 3, flip both axes → all 4 corners
        make_rule(rule_uids[0], 3, [0, -V, 0, -V, V, 0, 0, 0, 0], True, True),
        # Top edge: not-thought above → tile 1, flip Y → top and bottom
        make_rule(rule_uids[1], 1, [0, -V, 0, 0, V, 0, 0, 0, 0], False, True),
        # Left edge: not-thought left → tile 2, flip X → left and right
        make_rule(rule_uids[2], 2, [0, 0, 0, -V, V, 0, 0, 0, 0], True, False),
        # Fill: any painted cell → tile 0
        make_rule(rule_uids[3], 0, [V], False, False),
    ]
    return {
        "__type": "IntGrid",
        "identifier": LAYER_ID,
        "type": "IntGrid",
        "uid": uid,
        "doc": None,
        "uiColor": None,
        "gridSize": CELL,
        "guideGridWid": 0,
        "guideGridHei": 0,
        "displayOpacity": 1,
        "inactiveOpacity": 1,
        "hideInList": False,
        "hideFieldsWhenInactive": False,
        "canSelectWhenInactive": True,
        "renderInWorldView": True,
        "pxOffsetX": 0,
        "pxOffsetY": 0,
        "parallaxFactorX": 0,
        "parallaxFactorY": 0,
        "parallaxScaling": True,
        "requiredTags": [],
        "excludedTags": [],
        "uiFilterTags": [],
        "useAsyncRender": False,
        "tilePivotX": 0,
        "tilePivotY": 0,
        "biomeFieldUid": None,
        "autoSourceLayerDefUid": None,
        "autoTilesKilledByOtherLayerUid": None,
        "tilesetDefUid": tileset_uid,
        "intGridValues": [
            {"value": VALUE_NUM, "identifier": VALUE_ID,
             "color": VALUE_COLOR, "tile": None, "groupUid": 0},
        ],
        "intGridValuesGroups": [],
        "autoRuleGroups": [
            {
                "uid": rule_uids[4],
                "name": VALUE_ID,
                "color": None,
                "icon": None,
                "active": True,
                "isOptional": False,
                "rules": rules,
                "usesWizard": False,
                "requiredBiomeValues": [],
                "biomeRequirementMode": 0,
            }
        ],
    }


def make_layer_instance(layer_uid, tileset_uid, level):
    """An empty layer instance for one level."""
    cw = level["pxWid"] // CELL
    ch = level["pxHei"] // CELL
    return {
        "__identifier": LAYER_ID,
        "__type": "IntGrid",
        "__cWid": cw,
        "__cHei": ch,
        "__gridSize": CELL,
        "__opacity": 1,
        "__pxTotalOffsetX": 0,
        "__pxTotalOffsetY": 0,
        "__tilesetDefUid": tileset_uid,
        "__tilesetRelPath": ART_REL,
        "iid": str(uuid.uuid4()),
        "layerDefUid": layer_uid,
        "levelId": level["uid"],
        "overrideTilesetUid": None,
        "pxOffsetX": 0,
        "pxOffsetY": 0,
        "visible": True,
        "optionalRules": [],
        "intGridCsv": [0] * (cw * ch),
        "autoLayerTiles": [],
        "seed": 0,
        "gridTiles": [],
        "entityInstances": [],
    }


def main():
    if ldtk_running():
        raise SystemExit("!! LDtk is open — close it first, or it will write "
                         "the project back over this edit.")

    if not os.path.exists(ART_ABS):
        raise SystemExit("!! %s not found — run tools/gen_thought_tiles.py first"
                         % ART_REL)

    img = Image.open(ART_ABS)
    if img.size != (CELL * TILES, CELL):
        raise SystemExit("!! %s is %dx%d, expected %dx%d"
                         % (ART_REL, img.width, img.height, CELL * TILES, CELL))

    raw = open(LDTK).read()
    if '"%s"' % LAYER_ID in raw:
        print("  %s is already defined — nothing to do" % LAYER_ID)
        return

    # Allocate UIDs: tileset, layer, 4 rules, 1 rule group = 7
    base_uid = max(int(u) for u in re.findall(r'"uid":\s*(\d+)', raw)) + 1
    ts_uid = base_uid
    layer_uid = base_uid + 1
    rule_uids = [base_uid + 2 + i for i in range(5)]  # 4 rules + 1 group

    tileset = make_tileset(ts_uid)
    layer = make_layer(layer_uid, ts_uid, rule_uids)

    out = raw

    # --- 1. Add the tileset definition ------------------------------------
    # Find the tilesets array and append before the closing ]
    ts_array_start = out.index('"tilesets"')
    ts_end = array_end(out, ts_array_start)
    ts_block = block(tileset, 3)
    out = out[:ts_end] + ",\n" + ts_block + "\n\t\t" + out[ts_end:]

    # --- 2. Add the layer definition --------------------------------------
    # Append to the layers array
    layer_array_start = out.index('"layers"')
    layer_end = array_end(out, layer_array_start)
    layer_block = block(layer, 3)
    out = out[:layer_end] + ",\n" + layer_block + "\n\t\t" + out[layer_end:]

    # --- 3. Add empty layer instances to every level ----------------------
    parsed = json.loads(raw)
    count = 0
    # Work backwards so earlier insertions don't shift later positions
    # Find every "layerInstances" in levels
    positions = []
    search_from = 0
    for lvl in parsed["levels"]:
        pos = out.index('"identifier": "%s"' % lvl["identifier"], search_from)
        li_pos = out.index('"layerInstances"', pos)
        li_end = array_end(out, li_pos)
        positions.append((li_end, lvl))
        search_from = li_end

    for li_end, lvl in reversed(positions):
        inst = make_layer_instance(layer_uid, ts_uid, lvl)
        inst_block = block(inst, 5)
        out = out[:li_end] + ",\n" + inst_block + "\n\t\t\t\t" + out[li_end:]
        count += 1

    # --- Verify -----------------------------------------------------------
    before = json.loads(raw)
    after = json.loads(out)

    # Tileset added
    ts_ids = [t["identifier"] for t in after["defs"]["tilesets"]]
    if TILESET_ID not in ts_ids:
        raise SystemExit("!! tileset %s not found after edit" % TILESET_ID)

    # Layer added
    lyr_ids = [l["identifier"] for l in after["defs"]["layers"]]
    if LAYER_ID not in lyr_ids:
        raise SystemExit("!! layer %s not found after edit" % LAYER_ID)

    # Every level has the instance
    for lvl in after["levels"]:
        li_ids = [li["__identifier"] for li in lvl["layerInstances"]]
        if LAYER_ID not in li_ids:
            raise SystemExit("!! level %s missing %s instance" %
                             (lvl["identifier"], LAYER_ID))

    # Nothing else in defs changed (except the additions)
    a_defs, b_defs = before["defs"], after["defs"]
    if (len(b_defs["tilesets"]) != len(a_defs["tilesets"]) + 1):
        raise SystemExit("!! tileset count wrong")
    if (len(b_defs["layers"]) != len(a_defs["layers"]) + 1):
        raise SystemExit("!! layer count wrong")

    print("  tileset: %s  (%s, %dx%d, %d tiles)"
          % (TILESET_ID, ART_REL, img.width, img.height, TILES))
    print("  layer:   %s  (IntGrid, %dpx grid, value '%s')"
          % (LAYER_ID, CELL, VALUE_ID))
    print("  rules:   corner+flipXY, top+flipY, left+flipX, fill")
    print("  instances: %d levels, all empty" % count)

    if not APPLY:
        print("\nDRY RUN — nothing written. Re-run with --apply")
        return

    tmp = LDTK + ".tmp"
    with open(tmp, "w") as f:
        f.write(out)
    os.replace(tmp, LDTK)
    print("\nAPPLIED. Re-import in Godot:")
    print("  rm .godot/imported/hooshang_act1.ldtk-* ldtk/levels/Level_*.scn")
    print("  Godot --headless --path . --import")


if __name__ == "__main__":
    main()
