#!/usr/bin/env python3
"""Add the SpringPlatform entity to Act 2's LDtk project.

Same shape as tools/ldtk_add_platforms.py's two entries: resizableX, NOT
resizableY (scenes/props/platforms/spring_platform.gd's Platform base forces
one cell), pivot 0.5/0.5.

LDTK MUST BE CLOSED — see tools/ldtk_add_platforms.py for why.

Idempotent: running it twice adds nothing the second time.

Usage:  python3 tools/ldtk_add_spring_platform.py          # dry run
        python3 tools/ldtk_add_spring_platform.py --apply
"""
import json
import os
import re
import subprocess
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
LDTK = os.path.join(ROOT, "ldtk", "hooshang_act2.ldtk")
APPLY = "--apply" in sys.argv

SPEC = {
    "identifier": "SpringPlatform",
    "icon": "art/spring_platform.png",
    "color": "#E0A330",
    "doc": ("A bounce pad: land on top and it launches him straight up, hard. "
            "Stretch it SIDEWAYS; it is always one cell tall and the height "
            "you drag it to is ignored on import."),
}


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
    uid = max(int(u) for u in re.findall(r'"uid":\s*(\d+)', raw))

    have_en = {e["identifier"] for e in d["defs"]["entities"]}
    if SPEC["identifier"] in have_en:
        print("  %s already defined — skipping" % SPEC["identifier"])
        return

    have_ts = {t["identifier"] for t in d["defs"]["tilesets"]}
    ts_name = SPEC["identifier"] + "Icon"
    uid += 1
    ts_uid = uid
    if ts_name not in have_ts:
        d["defs"]["tilesets"].append({
            "__cWid": 1, "__cHei": 1,
            "identifier": ts_name, "uid": ts_uid,
            "relPath": SPEC["icon"], "embedAtlas": None,
            "pxWid": 16, "pxHei": 16, "tileGridSize": 16,
            "spacing": 0, "padding": 0, "tags": [],
            "tagsSourceEnumUid": None, "enumTags": [], "customData": [],
            "cachedPixelData": None, "savedSelections": [],
        })
    uid += 1
    rect = {"tilesetUid": ts_uid, "x": 0, "y": 0, "w": 16, "h": 16}
    d["defs"]["entities"].append({
        "identifier": SPEC["identifier"], "uid": uid, "tags": [],
        "exportToToc": False, "allowOutOfBounds": False,
        "doc": SPEC["doc"],
        "width": 24, "height": 8,
        "resizableX": True, "resizableY": False,
        "minWidth": 8, "maxWidth": None, "minHeight": None, "maxHeight": None,
        "keepAspectRatio": False,
        "tileOpacity": 1, "fillOpacity": 0.5, "lineOpacity": 1,
        "hollow": False, "color": SPEC["color"],
        "renderMode": "Tile", "showName": True,
        "tilesetId": ts_uid, "tileRenderMode": "Repeat",
        "tileRect": rect, "uiTileRect": dict(rect),
        "nineSliceBorders": [], "maxCount": 0,
        "limitScope": "PerLayer", "limitBehavior": "MoveLastOne",
        "pivotX": 0.5, "pivotY": 0.5, "fieldDefs": [],
    })

    print("\nwould add: %s" % SPEC["identifier"])
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
