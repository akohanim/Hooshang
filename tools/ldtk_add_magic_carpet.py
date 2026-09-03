#!/usr/bin/env python3
"""Add the MagicCarpet entity — and the CarpetPattern enum it reads — to Act 2's
LDtk project.

ONE ENTITY WITH FIELDS, not four, for the same reason tools/ldtk_add_dark_thought.py
gives for DarkThought's Motion: which pattern a carpet flies is a thing two
placed carpets can legitimately disagree about, and a carpet whose Pattern
nobody set still visibly does something (RIDE, the default) rather than being a
silently-unused fourth entity type.

The enum/field JSON shapes below are copied from ldtk_add_dark_thought.py's own
field_def()/enum_def() helpers — verified there against LDtk's own serializer
(data.FieldDef.toJson, every key present even when null) — rather than
reinvented, so a form built from this still parses the way LDtk itself would
have written it.

hooshang_act2.ldtk is a small (~140KB) file, unlike the 2MB hooshang_act1.ldtk
ldtk_add_dark_thought.py has to avoid reformatting wholesale — so this uses the
plain json.load/dump round trip tools/ldtk_add_platforms.py already uses, not
that script's text-insertion trick.

LDTK MUST BE CLOSED — see tools/ldtk_add_platforms.py for why.

Idempotent: running it twice adds nothing the second time.

Usage:  python3 tools/ldtk_add_magic_carpet.py          # dry run
        python3 tools/ldtk_add_magic_carpet.py --apply
"""
import json
import os
import re
import subprocess
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
LDTK = os.path.join(ROOT, "ldtk", "hooshang_act2.ldtk")
APPLY = "--apply" in sys.argv

ENTITY = "MagicCarpet"
ENUM = "CarpetPattern"
# Order matches magic_carpet.gd's CarpetPattern enum — the NAMES are what cross
# the boundary (an LDtk enum arrives as a qualified string, see _field_enum),
# not the order, but keeping them in step lets a reader put the two side by
# side, same reasoning ldtk_add_dark_thought.py gives.
PATTERNS = ["Ride", "Bob", "Sweep", "Bounce"]
ENUM_COLOR = 16777215

TILE_H = 8.0  # matches magic_carpet.gd's TILE.y — one cell tall, always


def ldtk_running():
    try:
        out = subprocess.run(["ps", "ax", "-o", "command"],
                             capture_output=True, text=True).stdout
    except Exception:
        return False
    return any("LDtk.app/Contents/MacOS/LDtk" in line for line in out.splitlines())


def enum_def(uid):
    return {
        "identifier": ENUM, "uid": uid,
        "values": [{"id": v, "tileRect": None, "color": ENUM_COLOR}
                   for v in PATTERNS],
        "iconTilesetUid": None, "externalRelPath": None,
        "externalFileChecksum": None, "tags": [],
    }


def field_def(identifier, doc, uid, kind, default):
    return {
        "identifier": identifier, "doc": doc,
        "__type": kind[0], "uid": uid, "type": kind[1],
        "isArray": False, "canBeNull": False,
        "arrayMinLength": None, "arrayMaxLength": None,
        "editorDisplayMode": "NameAndValue", "editorDisplayScale": 1,
        "editorDisplayPos": "Above", "editorLinkStyle": "ArrowsLine",
        "editorDisplayColor": None, "editorAlwaysShow": False,
        "editorShowInWorld": True, "editorCutLongValues": True,
        "editorTextSuffix": None, "editorTextPrefix": None,
        "useForSmartColor": False, "exportToToc": False, "searchable": False,
        "min": None, "max": None, "regex": None, "acceptFileTypes": None,
        "defaultOverride": default,
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
    if ENUM in {e["identifier"] for e in d["defs"].get("enums", [])}:
        raise SystemExit("!! the %s enum exists but the %s entity does not — "
                         "half-applied, fix by hand" % (ENUM, ENTITY))

    uid = max(int(u) for u in re.findall(r'"uid":\s*(\d+)', raw))

    uid += 1
    enum = enum_def(uid)
    d["defs"].setdefault("enums", []).append(enum)

    fields = []
    uid += 1
    fields.append(field_def(
        "CarpetPattern",
        "Which path it flies. Ride (default) drifts right and a rider steers "
        "it up/down; Bob/Sweep orbit the placed point on their own; Bounce "
        "drifts right while pulsing in a springy vertical hop.",
        uid, ("LocalEnum." + ENUM, "F_Enum(%d)" % enum["uid"]),
        {"id": "V_String", "params": [PATTERNS[0]]}))
    for name, default, docstr in [
        ("Speed", 40.0, "Ride/Bounce: how fast it drifts right, px/s. "
                        "Bob/Sweep: 0 by default (stationary); set above 0 "
                        "to also drift while oscillating."),
        ("Amplitude", 20.0, "Bob/Sweep/Bounce: how far the oscillation "
                            "swings, in px."),
        ("SteerRange", 20.0, "Ride only: how far a rider may steer it, in "
                             "px, above or below its placed y."),
    ]:
        uid += 1
        fields.append(field_def(name, docstr, uid, ("Float", "F_Float"),
                                {"id": "V_Float", "params": [default]}))

    have_ts = {t["identifier"] for t in d["defs"]["tilesets"]}
    ts_name = ENTITY + "Icon"
    uid += 1
    ts_uid = uid
    if ts_name not in have_ts:
        d["defs"]["tilesets"].append({
            "__cWid": 1, "__cHei": 1,
            "identifier": ts_name, "uid": ts_uid,
            "relPath": "art/magic_carpet.png", "embedAtlas": None,
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
        "doc": ("A rideable flying carpet. Which way it moves depends on "
                "CarpetPattern — see that field's doc. Stretch it SIDEWAYS; "
                "it is always one cell tall."),
        "width": 32, "height": int(TILE_H),
        "resizableX": True, "resizableY": False,
        "minWidth": 16, "maxWidth": None, "minHeight": None, "maxHeight": None,
        "keepAspectRatio": False,
        "tileOpacity": 1, "fillOpacity": 0.5, "lineOpacity": 1,
        "hollow": False, "color": "#C63C38",
        "renderMode": "Tile", "showName": True,
        "tilesetId": ts_uid, "tileRenderMode": "Repeat",
        "tileRect": rect, "uiTileRect": dict(rect),
        "nineSliceBorders": [], "maxCount": 0,
        "limitScope": "PerLayer", "limitBehavior": "MoveLastOne",
        "pivotX": 0.5, "pivotY": 0.5, "fieldDefs": fields,
    })

    print("\nwould add: enum %s, entity %s (fields: %s)"
          % (ENUM, ENTITY, ", ".join(f["identifier"] for f in fields)))
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
