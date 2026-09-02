#!/usr/bin/env python3
"""Add the Key entity to Act 2's LDtk project.

Fixed size, like MysteryBox/DarkThought — the art is a fixed 10x14 sprite, so a
dragged handle could only ever promise a bigger pickup than the one that
actually collects. One field, KeyID (String — the value Act2Quest.collect()
uses to track which of the four are held).

LDTK MUST BE CLOSED — see tools/ldtk_add_platforms.py for why.

Idempotent: running it twice adds nothing the second time.

Usage:  python3 tools/ldtk_add_key.py          # dry run
        python3 tools/ldtk_add_key.py --apply
"""
import json
import os
import re
import subprocess
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
LDTK = os.path.join(ROOT, "ldtk", "hooshang_act2.ldtk")
APPLY = "--apply" in sys.argv

ENTITY = "Key"


def ldtk_running():
    try:
        out = subprocess.run(["ps", "ax", "-o", "command"],
                             capture_output=True, text=True).stdout
    except Exception:
        return False
    return any("LDtk.app/Contents/MacOS/LDtk" in line for line in out.splitlines())


def field_def(identifier, doc, uid, default):
    return {
        "identifier": identifier, "doc": doc,
        "__type": "String", "uid": uid, "type": "F_String",
        "isArray": False, "canBeNull": False,
        "arrayMinLength": None, "arrayMaxLength": None,
        "editorDisplayMode": "NameAndValue", "editorDisplayScale": 1,
        "editorDisplayPos": "Above", "editorLinkStyle": "ArrowsLine",
        "editorDisplayColor": None, "editorAlwaysShow": False,
        "editorShowInWorld": True, "editorCutLongValues": True,
        "editorTextSuffix": None, "editorTextPrefix": None,
        "useForSmartColor": False, "exportToToc": False, "searchable": False,
        "min": None, "max": None, "regex": None, "acceptFileTypes": None,
        "defaultOverride": {"id": "V_String", "params": [default]},
        "textLanguageMode": None, "symmetricalRef": False,
        "autoChainRef": False, "allowOutOfLevelRef": False,
        "allowedRefs": "Any", "allowedRefsEntityUid": None,
        "allowedRefTags": [], "tilesetUid": None,
    }


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

    uid += 1
    fields = [field_def("KeyID",
        "Which of the four keys this is. Act2Quest.collect() tracks holding "
        "by this string — two keys placed with the same id count as one.",
        uid, "1")]

    have_ts = {t["identifier"] for t in d["defs"]["tilesets"]}
    ts_name = ENTITY + "Icon"
    uid += 1
    ts_uid = uid
    if ts_name not in have_ts:
        d["defs"]["tilesets"].append({
            "__cWid": 1, "__cHei": 1,
            "identifier": ts_name, "uid": ts_uid,
            "relPath": "art/key.png", "embedAtlas": None,
            "pxWid": 16, "pxHei": 16, "tileGridSize": 16,
            "spacing": 0, "padding": 0, "tags": [],
            "tagsSourceEnumUid": None, "enumTags": [], "customData": [],
            "cachedPixelData": None, "savedSelections": [],
        })
    uid += 1
    rect = {"tilesetUid": ts_uid, "x": 0, "y": 0, "w": 16, "h": 16}
    d["defs"]["entities"].append({
        "identifier": ENTITY, "uid": uid, "tags": [],
        "exportToToc": False, "allowOutOfBounds": False,
        "doc": "One of the four quest keys. Not resizable: the art is fixed.",
        "width": 10, "height": 14,
        "resizableX": False, "resizableY": False,
        "minWidth": None, "maxWidth": None, "minHeight": None, "maxHeight": None,
        "keepAspectRatio": False,
        "tileOpacity": 1, "fillOpacity": 0.4, "lineOpacity": 1,
        "hollow": False, "color": "#E0B240",
        "renderMode": "Tile", "showName": True,
        "tilesetId": ts_uid, "tileRenderMode": "FitInside",
        "tileRect": rect, "uiTileRect": dict(rect),
        "nineSliceBorders": [], "maxCount": 0,
        "limitScope": "PerLayer", "limitBehavior": "MoveLastOne",
        "pivotX": 0.5, "pivotY": 0.5, "fieldDefs": fields,
    })

    print("\nwould add: %s (field KeyID)" % ENTITY)
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
