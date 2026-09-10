#!/usr/bin/env python3
"""Add the Pond entity to Act 2's LDtk project — a swimmable, resizable body
of water (scenes/props/zones/Pond.tscn / pond.gd).

Same shape as SlideZone: a plain coloured Rectangle in the LDtk editor (no
tileset icon — nothing here is drawn from a tile, the real water art is built
by the Godot prop at runtime from tools/gen_pond_water.py), resizable in both
axes so a level author can stretch it over whatever water a room needs.

FishCount IS A FLOAT FIELD, not an Int, even though it is conceptually a
count. This project has only ever written String and Float fields to an
LDtk project from a script — CLAUDE.md records that a guessed Bool shape
once corrupted the editor, and nothing here has tried Int either, so this
follows the field type that is actually known to round-trip cleanly rather
than guessing a new JSON shape. _build_pond() in
ldtk_entities_post_import.gd rounds it back to an int on the way in.

hooshang_act2.ldtk is small (~140KB), so this uses the plain json.load/dump
round trip tools/ldtk_add_magic_carpet.py already uses for the same file,
not hooshang_act1.ldtk's text-insertion trick (that one exists to avoid
reformatting a 2MB file wholesale).

LDTK MUST BE CLOSED — see tools/ldtk_add_magic_carpet.py for why.

Idempotent: running it twice adds nothing the second time.

Usage:  python3 tools/ldtk_add_pond.py          # dry run
        python3 tools/ldtk_add_pond.py --apply
"""
import json
import os
import re
import subprocess
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
LDTK = os.path.join(ROOT, "ldtk", "hooshang_act2.ldtk")
APPLY = "--apply" in sys.argv

ENTITY = "Pond"
CELL = 8


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
        "__type": "Float", "uid": uid, "type": "F_Float",
        "isArray": False, "canBeNull": False,
        "arrayMinLength": None, "arrayMaxLength": None,
        "editorDisplayMode": "NameAndValue", "editorDisplayScale": 1,
        "editorDisplayPos": "Above", "editorLinkStyle": "ArrowsLine",
        "editorDisplayColor": None, "editorAlwaysShow": False,
        "editorShowInWorld": True, "editorCutLongValues": True,
        "editorTextSuffix": None, "editorTextPrefix": None,
        "useForSmartColor": False, "exportToToc": False, "searchable": False,
        "min": 0, "max": None, "regex": None, "acceptFileTypes": None,
        "defaultOverride": {"id": "V_Float", "params": [default]},
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

    have = {e["identifier"] for e in d["defs"]["entities"]}
    if ENTITY in have:
        print("  %s already defined — skipping" % ENTITY)
        return

    uid = max(int(u) for u in re.findall(r'"uid":\s*(\d+)', raw))

    uid += 1
    fields = [field_def(
        "FishCount",
        "How many ambient fish drift inside it. Purely decorative — 0 for a "
        "quiet pond.",
        uid, 3.0)]

    d["defs"]["entities"].append({
        "identifier": ENTITY, "uid": uid + 1, "tags": [],
        "exportToToc": False, "allowOutOfBounds": False,
        "doc": ("A swimmable body of water — a traversal zone, not a hazard. "
                "No drowning, no timer. Stretch it over the water you want; "
                "see scenes/props/zones/pond.gd and Player's Swim export "
                "group for how it feels to move through."),
        "width": 32, "height": 16,
        "resizableX": True, "resizableY": True,
        "minWidth": CELL * 2, "maxWidth": None,
        "minHeight": CELL, "maxHeight": None,
        "keepAspectRatio": False,
        "tileOpacity": 1, "fillOpacity": 0.35, "lineOpacity": 1,
        "hollow": False, "color": "#2BB3B8",
        "renderMode": "Rectangle", "showName": True,
        "tilesetId": None, "tileRenderMode": "FitInside",
        "tileRect": None, "uiTileRect": None, "nineSliceBorders": [],
        "maxCount": 0, "limitScope": "PerLayer", "limitBehavior": "MoveLastOne",
        "pivotX": 0.5, "pivotY": 0.5, "fieldDefs": fields,
    })

    print("\nwould add: entity %s (fields: %s)"
          % (ENTITY, ", ".join(f["identifier"] for f in fields)))
    if APPLY:
        tmp = LDTK + ".tmp"
        with open(tmp, "w") as f:
            json.dump(d, f, indent="\t")
        os.replace(tmp, LDTK)
        print("APPLIED. Re-import in Godot:")
        print("  rm .godot/imported/hooshang_act2.ldtk-* ldtk/levels/Act_2_Level_*.scn")
        print("  Godot --headless --path . --import")
    else:
        print("DRY RUN — nothing written. Re-run with --apply")


main()
