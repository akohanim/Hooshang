#!/usr/bin/env python3
"""Add CeilingPanel to LDtk: the FULL-SIZE ceiling run, as something to place.

This is the thing standing in room 2 as `CeilingRoom2a` / `CeilingRoom2b` — the
24px suspended-ceiling cell with a flat luminous panel set into it, and the pool
it drops. Not the 8px `ceiling` tiles, which are that same ceiling cut down to
the paint grid: those are for brushing a long roof in, this is the fixture.

DRAG IT TO A WIDTH. `scripts/ldtk_entities_post_import.gd` turns the width into
`run_tiles`, so a 120px box is the five-cell run room 2 uses. The prop rounds
that to an ODD number of cells, because the panel is the middle one and an even
run has no middle — a box dragged to four cells comes back as five.

It is the same scene the props in room 2 are, so anything tuned there — panel
brightness, pool size, the flicker — is tuned here too, and a dead panel is
still `light_energy = 0`.

WHAT THIS TOUCHES: one entity definition and the icon tileset behind it. No
tiles, no IntGrid values, no rules — the paintable ceiling is a separate thing
and this leaves it alone.

EDITED AS TEXT, not as parsed JSON re-dumped — the project is a 1MB tab-indented
file and a json.dump round trip comes back 2.4x the size with every line
changed. It then PROVES the edit by parsing both versions and comparing them.

LDTK MUST BE CLOSED. It holds the whole project in memory and writes it back
wholesale, so a scripted edit made under a running LDtk is silently reverted.

Idempotent: running it twice adds nothing the second time.

Usage:  python3 tools/ldtk_add_ceiling_panel_entity.py          # dry run
        python3 tools/ldtk_add_ceiling_panel_entity.py --apply
"""
import copy
import json
import os
import re
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from ldtk_add_ceiling_tile import block, ldtk_running

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
LDTK = os.path.join(ROOT, "ldtk", "hooshang_act1.ldtk")
APPLY = "--apply" in sys.argv

ENTITY = "CeilingPanel"
ICON = "art/ceiling_panel.png"
COLOR = "#C4D4E2"
DOC = ("A run of suspended office ceiling with a light panel in the middle of "
       "it — the full-size fixture, not the 8px paint tiles. Stretch it "
       "SIDEWAYS; the width becomes the number of 24px cells and is rounded to "
       "an ODD count, because the panel is the middle one. One cell tall.")

## The prop's repeating unit, matching scenes/props/lighting/ceiling_panel.gd.
TILE_W, TILE_H = 24, 8
## Five cells: the run room 2 uses, so a freshly dragged one already looks like
## the thing it is a copy of.
DEFAULT_W = TILE_W * 5


def entity_def(uid, ts_uid):
    rect = {"tilesetUid": ts_uid, "x": 0, "y": 0, "w": 16, "h": 16}
    return {
        "identifier": ENTITY, "uid": uid, "tags": [],
        "exportToToc": False, "allowOutOfBounds": False,
        "doc": DOC,
        "width": DEFAULT_W, "height": TILE_H,
        "resizableX": True, "resizableY": False,
        "minWidth": TILE_W, "maxWidth": None,
        "minHeight": None, "maxHeight": None,
        "keepAspectRatio": False,
        "tileOpacity": 1, "fillOpacity": 0.4, "lineOpacity": 1,
        "hollow": False, "color": COLOR,
        "renderMode": "Tile", "showName": True,
        "tilesetId": ts_uid, "tileRenderMode": "Repeat",
        "tileRect": rect, "uiTileRect": dict(rect),
        "nineSliceBorders": [], "maxCount": 0,
        "limitScope": "PerLayer", "limitBehavior": "MoveLastOne",
        "pivotX": 0.5, "pivotY": 0.5, "fieldDefs": [],
    }


def tileset_def(uid):
    return {
        "__cWid": 1, "__cHei": 1,
        "identifier": ENTITY + "Icon", "uid": uid,
        "relPath": ICON, "embedAtlas": None,
        "pxWid": 16, "pxHei": 16, "tileGridSize": 16,
        "spacing": 0, "padding": 0, "tags": [],
        "tagsSourceEnumUid": None, "enumTags": [], "customData": [],
        "cachedPixelData": None, "savedSelections": [],
    }


def check(before, after, ent, ts):
    """Prove the insert added exactly these two objects and moved nothing else."""
    a, b = json.loads(before), json.loads(after)
    if b["defs"]["entities"] != a["defs"]["entities"] + [ent]:
        raise SystemExit("!! the entity list is not what was intended")
    if b["defs"]["tilesets"] != a["defs"]["tilesets"] + [ts]:
        raise SystemExit("!! the tileset list is not what was intended")
    sa, sb = copy.deepcopy(a), copy.deepcopy(b)
    for doc in (sa, sb):
        doc["defs"]["entities"] = doc["defs"]["tilesets"] = None
    if sa != sb:
        raise SystemExit("!! something outside the entity and tileset lists moved")


def main():
    if ldtk_running():
        raise SystemExit("!! LDtk is open — close it first, or it will write "
                         "the project back over this edit.")
    raw = open(LDTK).read()
    if '"identifier": "%s"' % ENTITY in raw:
        print("  %s is already defined — nothing to do" % ENTITY)
        return
    if not os.path.exists(os.path.join(ROOT, "ldtk", ICON)):
        raise SystemExit("!! no icon at ldtk/%s — run tools/gen_ceiling_panel.py"
                         % ICON)

    uid = max(int(u) for u in re.findall(r'"uid":\s*(\d+)', raw))
    ts, ent = tileset_def(uid + 1), entity_def(uid + 2, uid + 1)

    i = raw.index('\n\t], "tilesets": [')
    out = raw[:i] + ",\n" + block(ent, 2) + raw[i:]
    j = out.index('\n\t], "enums": [')
    out = out[:j] + ",\n" + block(ts, 2) + out[j:]

    check(raw, out, ent, ts)
    print("  entity %s  uid %d, icon tileset %d" % (ENTITY, ent["uid"], ts["uid"]))
    print("  default %dx%d — %d cells of %dpx, resizable across only"
          % (DEFAULT_W, TILE_H, DEFAULT_W // TILE_W, TILE_W))
    if not APPLY:
        print("\nDRY RUN — nothing written. Re-run with --apply")
        return
    tmp = LDTK + ".tmp"
    open(tmp, "w").write(out)
    os.replace(tmp, LDTK)
    print("\nAPPLIED. Re-import in Godot:")
    print("  rm .godot/imported/hooshang_act1.ldtk-* ldtk/levels/Level_*.scn")
    print("  Godot --headless --path . --import")


if __name__ == "__main__":
    main()
