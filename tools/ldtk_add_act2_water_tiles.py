#!/usr/bin/env python3
"""Add the paintable `Water` IntGrid layer to Act 2's LDtk project — the
tile-based counterpart to the resizable `Pond` entity (tools/ldtk_add_pond.py),
kept side by side with it rather than replacing it: `Pond` for a simple
rectangular body dragged and resized, this layer for an irregular shape
painted cell by cell with a real edge where it meets a bank.

Rule/field JSON shapes are copied VERBATIM (values renamed only) from Act 2's
own already-working `ThoughtHazards` layer definition (hooshang_act2.ldtk,
layer uid 182 / tileset uid 207) — read directly out of the live project
rather than re-derived from tools/ldtk_add_thought_tiles.py's Act-1-flavoured
version, which targets a different file with a different edit technique. This
is the SAME four-rule pattern (corner+flipXY, top+flipY, left+flipX, fill)
that layer proves already imports and auto-tiles correctly in this exact
project, just pointed at a 5-column tileset instead of 4 — see
tools/gen_act2_water_tiles.py's header for what the extra `fill_deep` column
is for and why it carries no rule of its own (nothing ever places it directly;
ldtk_water_layer.gd retargets a cell there at runtime once it measures it as
deep enough).

hooshang_act2.ldtk is small (~140KB), so — like ldtk_add_magic_carpet.py and
ldtk_add_pond.py — this uses a plain json.load/dump round trip rather than
hooshang_act1.ldtk's text-insertion trick (that one exists only to avoid
reformatting a much larger file wholesale).

LDTK MUST BE CLOSED — it holds the whole project in memory and writes it back
wholesale, so a scripted edit made under a running LDtk is silently reverted.

Idempotent: running it twice adds nothing the second time.

Usage:  python3 tools/ldtk_add_act2_water_tiles.py          # dry run
        python3 tools/ldtk_add_act2_water_tiles.py --apply
"""
import json
import os
import re
import subprocess
import sys
import uuid

from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
LDTK = os.path.join(ROOT, "ldtk", "hooshang_act2.ldtk")
ART_REL = "art/act2_water_tiles.png"
ART_ABS = os.path.join(ROOT, "ldtk", ART_REL)
APPLY = "--apply" in sys.argv

LAYER_ID = "Water"
VALUE_ID = "water"
VALUE_NUM = 1
VALUE_COLOR = "#3FB6C9"
TILESET_ID = "Act2WaterTilesSheet"
CELL = 8
# fill, top, left, corner are LDtk-placed; fill_deep (id 4) is runtime-only —
# see this script's own header and gen_act2_water_tiles.py's.
TILE_COUNT = 5


def ldtk_running():
    try:
        out = subprocess.run(["ps", "ax", "-o", "command"],
                             capture_output=True, text=True).stdout
    except Exception:
        return False
    return any("LDtk.app/Contents/MacOS/LDtk" in line for line in out.splitlines())


def make_tileset(uid, img):
    return {
        "__cWid": img.width // CELL, "__cHei": img.height // CELL,
        "identifier": TILESET_ID, "uid": uid,
        "relPath": ART_REL, "embedAtlas": None,
        "pxWid": img.width, "pxHei": img.height, "tileGridSize": CELL,
        "spacing": 0, "padding": 0, "tags": [],
        "tagsSourceEnumUid": None, "enumTags": [], "customData": [],
        "savedSelections": [], "cachedPixelData": None,
    }


def make_rule(uid, tile_id, pattern, flip_x, flip_y):
    return {
        "uid": uid, "active": True, "size": 3 if len(pattern) == 9 else 1,
        "tileRectsIds": [[tile_id]], "alpha": 1, "chance": 1,
        "breakOnMatch": True, "pattern": pattern,
        "flipX": flip_x, "flipY": flip_y,
        "xModulo": 1, "yModulo": 1, "xOffset": 0, "yOffset": 0,
        "tileXOffset": 0, "tileYOffset": 0,
        "tileRandomXMin": 0, "tileRandomXMax": 0,
        "tileRandomYMin": 0, "tileRandomYMax": 0,
        "checker": "None", "tileMode": "Single", "pivotX": 0, "pivotY": 0,
        "outOfBoundsValue": 0, "invalidated": False,
        "perlinActive": False, "perlinSeed": 1234567,
        "perlinScale": 0.2, "perlinOctaves": 2,
    }


def make_layer(uid, tileset_uid, rule_uids):
    V = VALUE_NUM
    rules = [
        # Corner: not-water above AND left -> tile 3, flip both -> all 4 corners
        make_rule(rule_uids[0], 3, [0, -V, 0, -V, V, 0, 0, 0, 0], True, True),
        # Top edge (the surface): not-water above -> tile 1, flip Y -> top and bottom
        make_rule(rule_uids[1], 1, [0, -V, 0, 0, V, 0, 0, 0, 0], False, True),
        # Left edge (a bank): not-water left -> tile 2, flip X -> left and right
        make_rule(rule_uids[2], 2, [0, 0, 0, -V, V, 0, 0, 0, 0], True, False),
        # Fill: any painted cell -> tile 0 (shallow; ldtk_water_layer.gd may
        # retarget this to fill_deep at runtime — see its own header).
        make_rule(rule_uids[3], 0, [V], False, False),
    ]
    return {
        "__type": "IntGrid", "identifier": LAYER_ID, "type": "IntGrid",
        "uid": uid, "doc": None, "uiColor": None,
        "gridSize": CELL, "guideGridWid": 0, "guideGridHei": 0,
        "displayOpacity": 1, "inactiveOpacity": 1,
        "hideInList": False, "hideFieldsWhenInactive": False,
        "canSelectWhenInactive": True, "renderInWorldView": True,
        "pxOffsetX": 0, "pxOffsetY": 0,
        "parallaxFactorX": 0, "parallaxFactorY": 0, "parallaxScaling": True,
        "requiredTags": [], "excludedTags": [],
        "autoTilesKilledByOtherLayerUid": None, "uiFilterTags": [],
        "useAsyncRender": False,
        "intGridValues": [
            {"value": VALUE_NUM, "identifier": VALUE_ID,
             "color": VALUE_COLOR, "tile": None, "groupUid": 0},
        ],
        "intGridValuesGroups": [],
        "autoRuleGroups": [{
            "uid": rule_uids[4], "name": VALUE_ID, "color": None, "icon": None,
            "active": True, "isOptional": False, "rules": rules,
            "usesWizard": False, "requiredBiomeValues": [],
            "biomeRequirementMode": 0,
        }],
        "autoSourceLayerDefUid": None,
        "tilesetDefUid": tileset_uid, "tilePivotX": 0, "tilePivotY": 0,
        "biomeFieldUid": None,
    }


def make_layer_instance(layer_uid, tileset_uid, level):
    cw = level["pxWid"] // CELL
    ch = level["pxHei"] // CELL
    return {
        "__identifier": LAYER_ID, "__type": "IntGrid",
        "__cWid": cw, "__cHei": ch, "__gridSize": CELL, "__opacity": 1,
        "__pxTotalOffsetX": 0, "__pxTotalOffsetY": 0,
        "__tilesetDefUid": tileset_uid, "__tilesetRelPath": ART_REL,
        "iid": str(uuid.uuid4()), "levelId": level["uid"],
        "layerDefUid": layer_uid, "pxOffsetX": 0, "pxOffsetY": 0,
        "visible": True, "optionalRules": [],
        "intGridCsv": [0] * (cw * ch),
        "autoLayerTiles": [], "seed": 0, "overrideTilesetUid": None,
        "gridTiles": [], "entityInstances": [],
    }


def main():
    if ldtk_running():
        raise SystemExit("!! LDtk is open — close it first, or it will write "
                         "the project back over this edit.")
    if not os.path.exists(ART_ABS):
        raise SystemExit("!! %s not found — run tools/gen_act2_water_tiles.py first"
                         % ART_REL)
    img = Image.open(ART_ABS)
    if img.width // CELL != TILE_COUNT:
        raise SystemExit("!! %s is %dpx wide, expected %d tiles of %dpx"
                         % (ART_REL, img.width, TILE_COUNT, CELL))

    raw = open(LDTK).read()
    d = json.loads(raw)

    if LAYER_ID in {l["identifier"] for l in d["defs"]["layers"]}:
        print("  %s already defined — skipping" % LAYER_ID)
        return

    uid = max(int(u) for u in re.findall(r'"uid":\s*(\d+)', raw))

    uid += 1
    ts_uid = uid
    tileset = make_tileset(ts_uid, img)
    d["defs"]["tilesets"].append(tileset)

    uid += 1
    layer_uid = uid
    rule_uids = [uid + 1 + i for i in range(5)]  # 4 rules + 1 rule group
    uid += 5
    layer = make_layer(layer_uid, ts_uid, rule_uids)
    d["defs"]["layers"].append(layer)

    count = 0
    for lvl in d["levels"]:
        lvl["layerInstances"].append(make_layer_instance(layer_uid, ts_uid, lvl))
        count += 1

    print("  tileset: %s  (%s, %dx%d, %d tiles)"
          % (TILESET_ID, ART_REL, img.width, img.height, TILE_COUNT))
    print("  layer:   %s  (IntGrid, %dpx grid, value '%s')" % (LAYER_ID, CELL, VALUE_ID))
    print("  rules:   corner+flipXY, top+flipY, left+flipX, fill")
    print("  instances: %d levels, all empty" % count)

    if APPLY:
        tmp = LDTK + ".tmp"
        with open(tmp, "w") as f:
            json.dump(d, f, indent="\t")
        os.replace(tmp, LDTK)
        print("\nAPPLIED. Re-import in Godot:")
        print("  rm .godot/imported/hooshang_act2.ldtk-* ldtk/levels/Act_2_Level_*.scn")
        print("  Godot --headless --path . --import")
    else:
        print("\nDRY RUN — nothing written. Re-run with --apply")


main()
