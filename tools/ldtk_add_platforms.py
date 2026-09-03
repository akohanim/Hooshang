#!/usr/bin/env python3
"""Add the Platform and CrumblingPlatform entities to the LDtk project.

Two tilesets (the entity icons drawn by tools/gen_platforms.py) and two entity
definitions, so both can be dragged into rooms by hand.

Both are resizableX and NOT resizableY, copying GlassSpikes: a platform is a
LEDGE, and the height you drag it to is ignored on import
(scripts/ldtk_entities_post_import.gd forces one cell). Pivot stays 0.5/0.5,
which is the convention every sized entity here uses and what the props centre
their box and art against.

LDTK MUST BE CLOSED. It holds the whole project in memory and writes it back
wholesale, so a scripted edit made under a running LDtk is silently reverted —
CLAUDE.md records that happening to an entity rename already. This refuses to
run rather than let that happen.

Idempotent: running it twice adds nothing the second time.

Usage:  python3 tools/ldtk_add_platforms.py          # dry run
        python3 tools/ldtk_add_platforms.py --apply
"""
import json
import os
import re
import subprocess
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
LDTK = os.path.join(ROOT, "ldtk", "hooshang_act1.ldtk")
APPLY = "--apply" in sys.argv

ENTITIES = [
    {
        "identifier": "Platform",
        "icon": "art/platform.png",
        "color": "#9FB6C6",
        "doc": ("A suspended ceiling panel you can stand on. Stretch it "
                "SIDEWAYS; it is always one cell tall and the height you drag "
                "it to is ignored on import."),
    },
    {
        "identifier": "CrumblingPlatform",
        "icon": "art/platform_crumbling.png",
        "color": "#C8A88C",
        "doc": ("A ceiling panel that gives way about half a second after he "
                "stands on it, and comes back when he respawns or re-enters "
                "the room. Stretch it SIDEWAYS; always one cell tall."),
    },
]


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

    have_ts = {t["identifier"] for t in d["defs"]["tilesets"]}
    have_en = {e["identifier"] for e in d["defs"]["entities"]}
    added = []

    for spec in ENTITIES:
        if spec["identifier"] in have_en:
            print("  %s already defined — skipping" % spec["identifier"])
            continue
        ts_name = spec["identifier"] + "Icon"
        uid += 1
        ts_uid = uid
        if ts_name not in have_ts:
            d["defs"]["tilesets"].append({
                "__cWid": 1, "__cHei": 1,
                "identifier": ts_name, "uid": ts_uid,
                "relPath": spec["icon"], "embedAtlas": None,
                "pxWid": 16, "pxHei": 16, "tileGridSize": 16,
                "spacing": 0, "padding": 0, "tags": [],
                "tagsSourceEnumUid": None, "enumTags": [], "customData": [],
                "cachedPixelData": None, "savedSelections": [],
            })
        uid += 1
        rect = {"tilesetUid": ts_uid, "x": 0, "y": 0, "w": 16, "h": 16}
        d["defs"]["entities"].append({
            "identifier": spec["identifier"], "uid": uid, "tags": [],
            "exportToToc": False, "allowOutOfBounds": False,
            "doc": spec["doc"],
            # 24 wide is one art tile, so a freshly dragged one already shows
            # the repeat rather than a single sliver.
            "width": 24, "height": 8,
            "resizableX": True, "resizableY": False,
            "minWidth": 8, "maxWidth": None, "minHeight": None, "maxHeight": None,
            "keepAspectRatio": False,
            "tileOpacity": 1, "fillOpacity": 0.5, "lineOpacity": 1,
            "hollow": False, "color": spec["color"],
            "renderMode": "Tile", "showName": True,
            "tilesetId": ts_uid, "tileRenderMode": "Repeat",
            "tileRect": rect, "uiTileRect": dict(rect),
            "nineSliceBorders": [], "maxCount": 0,
            "limitScope": "PerLayer", "limitBehavior": "MoveLastOne",
            "pivotX": 0.5, "pivotY": 0.5, "fieldDefs": [],
        })
        added.append(spec["identifier"])

    print("\nwould add: %s" % (", ".join(added) if added else "nothing"))
    if not added:
        return
    if APPLY:
        tmp = LDTK + ".tmp"
        with open(tmp, "w") as f:
            json.dump(d, f, indent="\t")
        os.replace(tmp, LDTK)
        print("APPLIED. Re-import in Godot:")
        print("  rm .godot/imported/hooshang_act1.ldtk-* ldtk/levels/Level_*.scn")
        print("  Godot --headless --path . --import")
    else:
        print("DRY RUN — nothing written. Re-run with --apply")


main()
