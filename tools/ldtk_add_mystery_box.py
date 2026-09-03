#!/usr/bin/env python3
"""Add the MysteryBox entity — and the MushroomType enum it reads — to LDtk.

One entity definition, one 16px tileset over the two-frame sheet (so LDtk
previews the "?" face rather than a coloured square), and one project enum.
Modelled directly on ldtk_add_dark_thought.py — read that file's docstring for
the reasoning behind the shapes below; this only restates what differs.

ONE FIELD, MushroomType, AND IT IS AN ENUM FOR THE SAME REASON DarkThought's
Motion IS ONE: it is written from LDtk's own serializer shape (see
ldtk_add_dark_thought.py's note on `__type`/`type`/the ValueWrapper), not a
guessed one, and it crosses the boundary QUALIFIED — the importer hands the
hook "MushroomType.BlackWhite", never the bare "BlackWhite" — which is exactly
why the post-import hook reads it with `_field_enum`, not `_field_str`. Only
one value exists today (BlackWhite); a second colour is a second entry in
MUSHROOM_TYPES here, in Mushroom.MushroomType (scenes/props/mushroom.gd), and
in the PALETTES dict in tools/gen_mushroom.py — three places, not a fourth,
because the LDtk field, the enum and the art are the whole of what a new
colour needs.

WRITTEN AS TEXT, not as parsed JSON re-dumped — same as ldtk_add_dark_thought.py
and for the same reason: the project is a 1MB file in LDtk's own formatting and
a dump round trip would rewrite all 20k lines for a one-entity change. The
result is parsed back and compared to prove exactly what moved.

LDTK MUST BE CLOSED — it holds the whole project in memory and writes it back
wholesale, so a scripted edit made under a running LDtk is silently reverted.

Idempotent: running it twice adds nothing the second time.

Usage:  python3 tools/ldtk_add_mystery_box.py          # dry run
        python3 tools/ldtk_add_mystery_box.py --apply
"""
import copy
import json
import os
import re
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from ldtk_add_ceiling_tile import block, ldtk_running
from ldtk_add_dark_thought import field_def, inline

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
LDTK = os.path.join(ROOT, "ldtk", "hooshang_act1.ldtk")
APPLY = "--apply" in sys.argv

ART = "art/mystery_box.png"
## Two 16px frames in a row: idle ("?") and spent. The entity is TWO cells of
## the 8px grid across and down, same reasoning as DarkThought's own CELL note
## — the smallest a block can be and still hold a mushroom.
CELL = 16
FRAMES = 2

ENTITY = "MysteryBox"
ENUM = "MushroomType"
## In the order Mushroom.MushroomType declares its values — kept in step so a
## reader can put the two side by side, the same rule ldtk_add_dark_thought.py
## states for its own MOTIONS list.
MUSHROOM_TYPES = ["BlackWhite"]
ENUM_COLOR = 16777215

COLOR = "#D6A332"
DOC = ("A Mario-style \"?\" block. Bump it from underneath — jumping or "
       "dashing into its underside — and a mushroom rises out and walks off. "
       "MushroomType picks which power it hands out. Not resizable: it is "
       "16x16.")


def enum_def(uid):
    return {
        "identifier": ENUM, "uid": uid,
        "values": [{"id": v, "tileRect": None, "color": ENUM_COLOR}
                   for v in MUSHROOM_TYPES],
        "iconTilesetUid": None, "externalRelPath": None,
        "externalFileChecksum": None, "tags": [],
    }


def tileset_def(uid):
    w, h = CELL * FRAMES, CELL
    return {
        "__cWid": w // CELL, "__cHei": h // CELL,
        "identifier": ENTITY + "Sheet", "uid": uid,
        "relPath": ART, "embedAtlas": None,
        "pxWid": w, "pxHei": h, "tileGridSize": CELL,
        "spacing": 0, "padding": 0, "tags": [],
        "tagsSourceEnumUid": None, "enumTags": [], "customData": [],
        "cachedPixelData": None, "savedSelections": [],
    }


def entity_def(uid, ts_uid, fields):
    # Frame 0 (the idle "?" face) as the icon — frame 1 is what it looks like
    # after being spent, which is not what you are placing.
    rect = {"tilesetUid": ts_uid, "x": 0, "y": 0, "w": CELL, "h": CELL}
    return {
        "identifier": ENTITY, "uid": uid, "tags": [],
        "exportToToc": False, "allowOutOfBounds": False,
        "doc": DOC,
        "width": CELL, "height": CELL,
        "resizableX": False, "resizableY": False,
        "minWidth": None, "maxWidth": None,
        "minHeight": None, "maxHeight": None,
        "keepAspectRatio": False,
        "tileOpacity": 1, "fillOpacity": 0.4, "lineOpacity": 1,
        "hollow": False, "color": COLOR,
        "renderMode": "Tile", "showName": True,
        "tilesetId": ts_uid, "tileRenderMode": "FitInside",
        "tileRect": rect, "uiTileRect": dict(rect),
        "nineSliceBorders": [], "maxCount": 0,
        "limitScope": "PerLayer", "limitBehavior": "MoveLastOne",
        "pivotX": 0.5, "pivotY": 0.5,
        "fieldDefs": fields,
    }


def check(before, after, entity, tileset, enum):
    a, b = json.loads(before), json.loads(after)
    if b["defs"]["entities"] != a["defs"]["entities"] + [entity]:
        raise SystemExit("!! the entity list is not what was intended")
    if b["defs"]["tilesets"] != a["defs"]["tilesets"] + [tileset]:
        raise SystemExit("!! the tileset list is not what was intended")
    if b["defs"]["enums"] != a["defs"]["enums"] + [enum]:
        raise SystemExit("!! the enum list is not what was intended")
    sa, sb = copy.deepcopy(a), copy.deepcopy(b)
    for doc in (sa, sb):
        doc["defs"]["entities"] = None
        doc["defs"]["tilesets"] = None
        doc["defs"]["enums"] = None
    if sa != sb:
        raise SystemExit("!! something outside those three lists moved")


def main():
    if ldtk_running():
        raise SystemExit("!! LDtk is open — close it first, or it will write "
                         "the project back over this edit.")
    raw = open(LDTK).read()
    doc = json.loads(raw)
    if ENTITY in {e["identifier"] for e in doc["defs"]["entities"]}:
        print("  %s already defined — nothing to add." % ENTITY)
        return
    if ENUM in {e["identifier"] for e in doc["defs"]["enums"]}:
        raise SystemExit("!! the %s enum exists but the %s entity does not — "
                         "half-applied, fix by hand" % (ENUM, ENTITY))
    if not os.path.exists(os.path.join(ROOT, "ldtk", ART)):
        raise SystemExit("!! no art at ldtk/%s — run tools/gen_mystery_box.py"
                         % ART)

    uid = max(int(u) for u in re.findall(r'"uid":\s*(\d+)', raw))

    uid += 1
    enum = enum_def(uid)
    fields = [field_def("MushroomType",
                        "Which mushroom a bump gives up.",
                        uid + 1,
                        ("LocalEnum." + ENUM, "F_Enum(%d)" % enum["uid"]),
                        {"id": "V_String", "params": [MUSHROOM_TYPES[0]]})]
    uid += 2
    tileset = tileset_def(uid)
    uid += 1
    entity = entity_def(uid, tileset["uid"], fields)

    print("  enum    %-16s uid %d, values %s"
          % (ENUM, enum["uid"], ", ".join(MUSHROOM_TYPES)))
    print("  tileset %-16s uid %d, %dx%d, grid %d"
          % (tileset["identifier"], tileset["uid"], tileset["pxWid"],
             tileset["pxHei"], tileset["tileGridSize"]))
    print("  entity  %-16s uid %d, %dx%d, not resizable"
          % (ENTITY, entity["uid"], CELL, CELL))
    for f in fields:
        print("      %-12s %-24s default %s"
              % (f["identifier"], f["__type"], f["defaultOverride"]["params"][0]))

    out = raw
    i = out.index('\n\t], "tilesets": [')
    out = out[:i] + ",\n" + block(entity, 2) + out[i:]
    j = out.index('\n\t], "enums": [')
    out = out[:j] + ",\n" + block(tileset, 2) + out[j:]
    k = out.index('\n\t], "externalEnums": [')
    out = out[:k] + ",\n\t\t" + inline(enum) + out[k:]

    check(raw, out, entity, tileset, enum)
    print("\nverified: 1 entity, 1 tileset and 1 enum added, nothing else touched")
    if not APPLY:
        print("\nDRY RUN — nothing written. Re-run with --apply")
        return
    tmp = LDTK + ".tmp"
    open(tmp, "w").write(out)
    os.replace(tmp, LDTK)
    print("\nAPPLIED. Re-import in Godot — and the hook that BUILDS this has")
    print("changed too, so the .ldtk needs touching or Godot will not re-read it:")
    print("  touch ldtk/hooshang_act1.ldtk")
    print("  rm .godot/imported/hooshang_act1.ldtk-* ldtk/levels/Level_*.scn")
    print("  Godot --headless --path . --import")


if __name__ == "__main__":
    main()
