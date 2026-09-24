#!/usr/bin/env python3
"""Create or migrate Act 2 carpets to Ride with independent color choices.
Run with --apply while LDtk is closed. Existing placements retain their colors.
"""
import json
import os
import re
import subprocess
import sys
from ldtk_preserve_json import update

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
LDTK = os.path.join(ROOT, "ldtk", "hooshang_act2.ldtk")
APPLY = "--apply" in sys.argv

ENTITY = "MagicCarpet"
ENUM = "CarpetPattern"
# Order matches magic_carpet.gd's CarpetPattern enum — the NAMES are what cross
# the boundary (an LDtk enum arrives as a qualified string, see _field_enum),
# not the order, but keeping them in step lets a reader put the two side by
# side, same reasoning ldtk_add_dark_thought.py gives.
PATTERNS = ["Ride"]
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


def migrate(d):
    """Keep enum/field IDs stable and update explicit instance overrides too."""
    entity = next(e for e in d["defs"]["entities"] if e["identifier"] == ENTITY)
    enums = d["defs"]["enums"]
    old = next(e for e in enums if e["identifier"] == ENUM)
    old["values"] = [{"id": "Ride", "tileRect": None, "color": ENUM_COLOR}]
    uid = max(int(u) for u in re.findall(r'"uid":\s*(\d+)', json.dumps(d))) + 1
    colors = next((e for e in enums if e["identifier"] == "CarpetColor"), None)
    if colors is None:
        colors = enum_def(uid)
        uid += 1
        colors["identifier"] = "CarpetColor"
        colors["values"] = [{"id": v, "tileRect": None, "color": ENUM_COLOR}
                            for v in ["Crimson", "Teal", "Violet", "Amber"]]
        enums.append(colors)
    entity["fieldDefs"] = [f for f in entity["fieldDefs"]
                           if f["identifier"] not in ("Amplitude", "SteerRange")]
    for field in entity["fieldDefs"]:
        if field["identifier"] == "CarpetPattern":
            field["doc"] = "Ride: forward flight with up/down steering throughout the room."
            field["defaultOverride"] = {"id": "V_String", "params": ["Ride"]}
        elif field["identifier"] == "Speed":
            field["doc"] = "Forward flight speed in pixels per second."
    color_field = next((f for f in entity["fieldDefs"] if f["identifier"] == "CarpetColor"), None)
    if color_field is None:
        color_field = field_def("CarpetColor", "Rug color and motif; all colors use Ride.",
                               uid, ("LocalEnum.CarpetColor", "F_Enum(%d)" % colors["uid"]),
                               {"id": "V_String", "params": ["Crimson"]})
        entity["fieldDefs"].append(color_field)
    entity["doc"] = "Rideable carpet. Steer up/down freely within the room and clear of obstacles. Color only changes its appearance."
    def walk(value):
        if isinstance(value, dict):
            if value.get("__identifier") == ENTITY and "fieldInstances" in value:
                fields = value["fieldInstances"]
                pattern = next((f for f in fields if f["__identifier"] == "CarpetPattern"), None)
                color = {"Bob": "Teal", "Sweep": "Violet", "Bounce": "Amber"}.get(
                    pattern["__value"] if pattern else "Ride", "Crimson")
                if not any(f["__identifier"] == "CarpetColor" for f in fields):
                    fields.append({"__identifier": "CarpetColor", "__type": "LocalEnum.CarpetColor",
                                   "__value": color, "defUid": color_field["uid"],
                                   "realEditorValues": [{"id": "V_String", "params": [color]}]})
                if pattern:
                    pattern["__value"] = "Ride"
                    pattern["realEditorValues"] = [{"id": "V_String", "params": ["Ride"]}]
                value["fieldInstances"] = [f for f in fields if f["__identifier"] not in ("Amplitude", "SteerRange")]
            for child in value.values():
                walk(child)
        elif isinstance(value, list):
            for child in value:
                walk(child)
    walk(d.get("levels", []))
    walk(d.get("worlds", []))


def main():
    if ldtk_running():
        raise SystemExit("!! LDtk is open — close it first, or it will write "
                         "the project back over this edit.")
    raw = open(LDTK).read()
    d = json.loads(raw)

    have_en = {e["identifier"] for e in d["defs"]["entities"]}
    if ENTITY in have_en:
        migrate(d)
        if APPLY:
            with open(LDTK, "w") as f:
                f.write(update(raw, d))
            print("Applied Ride-only carpet options and preserved placement colors.")
        else:
            print("Dry run: migrate carpets to Ride with Crimson/Teal/Violet/Amber colors.")
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
        "Ride: forward flight with up/down steering throughout the room.",
        uid, ("LocalEnum." + ENUM, "F_Enum(%d)" % enum["uid"]),
        {"id": "V_String", "params": [PATTERNS[0]]}))
    for name, default, docstr in [
        ("Speed", 40.0, "Forward flight speed in pixels per second."),
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
        "doc": ("A rideable flying carpet with independent color options. Stretch it SIDEWAYS; "
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

    migrate(d)
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
