#!/usr/bin/env python3
"""Add the JamshidCage entity to Act 2's LDtk project.

Fixed size, like MysteryBox — the art is a fixed 16x24 barred door
(tools/gen_jamshid_cage.py), so a dragged handle could only ever promise a
bigger cage than the one that is actually solid. No fields: whether it is
open is entirely derived from Act2Quest.all_keys_collected() at runtime (see
jamshid_cage.gd) — there is nothing for a level author to configure per
instance.

LDTK MUST BE CLOSED — see tools/ldtk_add_platforms.py for why.

Idempotent: running it twice adds nothing the second time.

Usage:  python3 tools/ldtk_add_jamshid_cage.py          # dry run
        python3 tools/ldtk_add_jamshid_cage.py --apply
"""
import json
import os
import re
import subprocess
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
LDTK = os.path.join(ROOT, "ldtk", "hooshang_act2.ldtk")
APPLY = "--apply" in sys.argv

ENTITY = "JamshidCage"


def ldtk_running():
    try:
        out = subprocess.run(["ps", "ax", "-o", "command"],
                             capture_output=True, text=True).stdout
    except Exception:
        return False
    return any("LDtk.app/Contents/MacOS/LDtk" in line for line in out.splitlines())


def main():
    if ldtk_running():
        raise SystemExit("!! LDtk is open — close it first, or it will write "
                         "the project back over this edit.")
    raw = open(LDTK).read()
    d = json.loads(raw)

    have_en = {e["identifier"] for e in d["defs"]["entities"]}
    if ENTITY in have_en:
        print("  %s already defined — skipping" % ENTITY)
        return

    uid = max(int(u) for u in re.findall(r'"uid":\s*(\d+)', raw))

    have_ts = {t["identifier"] for t in d["defs"]["tilesets"]}
    ts_name = ENTITY + "Icon"
    uid += 1
    ts_uid = uid
    if ts_name not in have_ts:
        d["defs"]["tilesets"].append({
            "__cWid": 1, "__cHei": 1,
            "identifier": ts_name, "uid": ts_uid,
            "relPath": "art/jamshid_cage_closed.png", "embedAtlas": None,
            "pxWid": 16, "pxHei": 24, "tileGridSize": 8,
            "spacing": 0, "padding": 0, "tags": [],
            "tagsSourceEnumUid": None, "enumTags": [], "customData": [],
            "cachedPixelData": None, "savedSelections": [],
        })
    uid += 1
    rect = {"tilesetUid": ts_uid, "x": 0, "y": 0, "w": 16, "h": 24}
    d["defs"]["entities"].append({
        "identifier": ENTITY, "uid": uid, "tags": [],
        "exportToToc": False, "allowOutOfBounds": False,
        "doc": ("The locked cage blocking the way to Jamshid. Solid until all "
                "four Act 2 keys are held, then opens for good. Not "
                "resizable: the art is fixed."),
        "width": 16, "height": 24,
        "resizableX": False, "resizableY": False,
        "minWidth": None, "maxWidth": None, "minHeight": None, "maxHeight": None,
        "keepAspectRatio": False,
        "tileOpacity": 1, "fillOpacity": 0.4, "lineOpacity": 1,
        "hollow": False, "color": "#8C6B3C",
        "renderMode": "Tile", "showName": True,
        "tilesetId": ts_uid, "tileRenderMode": "FitInside",
        "tileRect": rect, "uiTileRect": dict(rect),
        "nineSliceBorders": [], "maxCount": 0,
        "limitScope": "PerLayer", "limitBehavior": "MoveLastOne",
        "pivotX": 0.5, "pivotY": 0.5, "fieldDefs": [],
    })

    print("\nwould add: %s" % ENTITY)
    if APPLY:
        tmp = LDTK + ".tmp"
        with open(tmp, "w") as f:
            json.dump(d, f, indent="\t")
        os.replace(tmp, LDTK)
        print("APPLIED. Re-import in Godot:")
        print("  rm .godot/imported/hooshang_act2.ldtk-* ldtk/levels/Act2_*.scn")
        print("  Godot --headless --path . --import")
    else:
        print("DRY RUN — nothing written. Re-run with --apply")


main()
