#!/usr/bin/env python3
"""Add the DarkThought entity — and the ThoughtMotion enum it reads — to LDtk.

One entity definition, one 16px tileset over the sprite sheet (so LDtk previews
the cloud rather than a coloured square), and one project enum.

ONE ENTITY WITH FIELDS, NOT ONE PER DIRECTION. This is the opposite call from
ldtk_add_cone_spikes.py, and the reason is worth stating because the two sit
next to each other. The spike strips split per surface because direction there is
a binary you can forget to set and the failure is SILENT — spikes growing out of
a ceiling upside down, correct-looking in the editor, wrong only in play. A dark
thought's motion is NUMBERS: how far, how fast, how far into the cycle. Tuning
belongs on the instance (the same call _build_slide_zone documents), because two
thoughts in one room can legitimately want different paths — which is exactly
the case an entity-per-variant cannot serve. And a thought whose Motion nobody
set still visibly drifts, so there is nothing silent to protect against.

WHY `Clockwise` IS A FLOAT AND NOT A CHECKBOX. LDtk has still only ever written
two field types into this project, String and Float, so those are the only two
whose shape can be copied from something LDtk itself produced. A Bool and a
Color built from a guessed shape crashed the editor outright the first time the
ceiling-light fields existed (`createFieldInput`, reading `.substr` of null), and
the FlickerAmount precedent — a number where 0 means "off" — costs nothing here:
0 is anticlockwise, anything above it is clockwise.

`Motion` IS a real enum, and that is not the same gamble. It is written from
LDtk's own serializer rather than from a guess: data.FieldDef.toJson writes every
key for every type (verified — the String and Float fieldDefs already in this
project have identical key sets), `__type` is `"LocalEnum." + enum identifier`,
`type` is writeEnumAsString, i.e. `F_Enum(<enum uid>)`, and an enum's default is
a `V_String` wrapper holding the value's id. So the record below is a String
fieldDef with three keys changed to what LDtk would have put there, not a shape
invented from the outside.

An LDtk enum arrives on the Godot side as a STRING, and a QUALIFIED one. Read
`__parse_enum` in the addon's src/util/field-util.gd: the regex there pulls the
enum's NAME out of the `LocalEnum.ThoughtMotion` type string, and what it hands
back is `"ThoughtMotion.Circle"` — never the bare `"Circle"`. So the import hook
reads Motion with `_field_enum`, which strips that prefix, and NOT `_field_str`.
This is written down because getting it wrong is silent: matching the bare name
misses every value and falls through to the default, and every thought in the
world drifted vertically whatever LDtk said. `dark_thought_test` pins it now.

WRITTEN AS TEXT, not as parsed JSON re-dumped — same as ldtk_add_cone_spikes.py
and for the same reason. ldtk_add_platforms.py, which both are modelled on, does
`json.dump(indent="\\t")` over the whole project; the project is a 1MB file in
LDtk's own format with arrays like `"px": [172,12]` on one line, so a dump round
trip explodes every one of those and rewrites all 20k lines, burying a one-entity
change in an unreviewable diff. The result is parsed back and compared to prove
exactly what moved.

Note the two house styles inside the one file: LDtk writes entity and tileset
definitions across many lines and enum definitions on ONE. Both are matched
below, so the diff reads like something LDtk wrote.

LDTK MUST BE CLOSED. It holds the whole project in memory and writes it back
wholesale, so a scripted edit made under a running LDtk is silently reverted —
CLAUDE.md records that happening to an entity rename already. This refuses to
run rather than let that happen.

Idempotent: running it twice adds nothing the second time.

Usage:  python3 tools/ldtk_add_dark_thought.py          # dry run
        python3 tools/ldtk_add_dark_thought.py --apply
"""
import copy
import json
import os
import re
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from ldtk_add_ceiling_tile import block, ldtk_running

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
LDTK = os.path.join(ROOT, "ldtk", "hooshang_claude.ldtk")
APPLY = "--apply" in sys.argv

ART = "art/dark_thought.png"
## The sprite sheet: four 16px frames in a row. The entity is TWO cells of the
## 8px grid across and down — the smallest a cloud can be and still have an
## inside — so its own grid size is 16 while every layer stays at 8.
CELL = 16
FRAMES = 4

ENTITY = "DarkThought"
ENUM = "ThoughtMotion"
## The three paths, in the order dark_thought.gd's `Motion` enum declares them.
## The NAMES are what cross the boundary (an LDtk enum arrives as a string), not
## the order — but keeping them in step means a reader can put the two side by
## side, which is the only thing that catches a value added to one and not the
## other.
MOTIONS = ["Vertical", "Horizontal", "Circle"]
## LDtk stores a value's editor colour as a plain int. White, like every value
## in the four enums already here.
ENUM_COLOR = 16777215

COLOR = "#8E2C3A"
DOC = ("A dark thought: a small black cloud that drifts a repeating path and "
       "kills on contact. The point you place is the CENTRE of that path — it "
       "swings Amplitude px either side of here, or orbits here at Amplitude "
       "radius when Motion is Circle. Not resizable: it is 16x16.")


## identifier, type, default, doc. Every one falls back to the prop's own value
## on import, so a thought placed before a field existed still drifts.
FIELDS = [
    ("Amplitude", 32.0,
     "Half the travel in px — the swing either side of the placed point, or the "
     "orbit radius when Motion is Circle."),
    ("Speed", 1.0,
     "Full cycles per second: one trip out and back, or one lap."),
    ("Phase", 0.0,
     "Where in the cycle it starts, 0..1. Set it per instance, or several "
     "thoughts in one room move in lockstep and read as one object."),
    ("Clockwise", 1.0,
     "Circle only: 1 goes clockwise on screen, 0 anticlockwise. A number and "
     "not a checkbox — see the note at the top of "
     "tools/ldtk_add_dark_thought.py."),
]



def inline(obj):
    """One JSON object the way LDtk writes an ENUM definition: all on one line,
    with a space inside every brace and inside every non-empty bracket.

    json.dumps' own compact form is a character off that in a dozen places, and
    the next save from the app would reformat the line — so the diff of that
    save would be this change all over again, which is precisely what a
    text-insertion tool exists to avoid.
    """
    if isinstance(obj, dict):
        body = ", ".join('%s: %s' % (json.dumps(k), inline(v))
                         for k, v in obj.items())
        return "{ %s }" % body
    if isinstance(obj, list):
        return "[]" if not obj else "[ %s ]" % ", ".join(inline(v) for v in obj)
    return json.dumps(obj)


def enum_def(uid):
    """The project enum, shaped like the four LDtk already wrote (LevelId,
    GrantsAbility, HazardType, Facing)."""
    return {
        "identifier": ENUM, "uid": uid,
        "values": [{"id": v, "tileRect": None, "color": ENUM_COLOR}
                   for v in MOTIONS],
        "iconTilesetUid": None, "externalRelPath": None,
        "externalFileChecksum": None, "tags": [],
    }


def field_def(identifier, doc, uid, kind, default):
    """One fieldDef, at the full width LDtk's own FieldDef.toJson emits.

    EVERY KEY IS WRITTEN, including the ones that are null for this type. A
    fieldDef built from only the keys that look relevant is what crashed the
    editor the first time these existed: LDtk reads the file back and a missing
    key there is not a default, it is a null the form builder walks into.

    `kind` is ("Float", "F_Float") or ("LocalEnum.X", "F_Enum(uid)"); `default`
    is the ValueWrapper LDtk would have stored — V_Float for a number, V_String
    for an enum value's id.
    """
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


def tileset_def(uid, entity=None, art=None):
    """A 16px tileset over the four-frame sheet, shaped like the ones
    ldtk_add_cone_spikes.py adds.

    `entity` and `art` default to the DarkThought's. They are arguments so the
    pale variant can be built by ldtk_add_light_thought.py from THIS definition
    rather than from a copy of it — the fieldDef and entityDef shapes are the
    part of this file that was hard to get right, and a second transcription of
    them is a second chance to get one key wrong.
    """
    entity = entity or ENTITY
    art = art or ART
    w, h = CELL * FRAMES, CELL
    return {
        "__cWid": w // CELL, "__cHei": h // CELL,
        "identifier": entity + "Sheet", "uid": uid,
        "relPath": art, "embedAtlas": None,
        "pxWid": w, "pxHei": h, "tileGridSize": CELL,
        "spacing": 0, "padding": 0, "tags": [],
        "tagsSourceEnumUid": None, "enumTags": [], "customData": [],
        "cachedPixelData": None, "savedSelections": [],
    }


def entity_def(uid, ts_uid, fields, entity=None, doc=None, color=None):
    entity = entity or ENTITY
    doc = doc or DOC
    color = color or COLOR
    # Frame 0 as the icon: the rest are the same cloud breathing, so any of them
    # would do, and picking the first means the editor shows what the prop shows
    # the instant it spawns.
    rect = {"tilesetUid": ts_uid, "x": 0, "y": 0, "w": CELL, "h": CELL}
    return {
        "identifier": entity, "uid": uid, "tags": [],
        "exportToToc": False, "allowOutOfBounds": False,
        "doc": doc,
        "width": CELL, "height": CELL,
        # NOT RESIZABLE. The art is a fixed 16px cloud and the kill box is
        # derived from it in dark_thought.gd, so a dragged handle could only ever
        # promise a bigger hazard than the one that kills.
        "resizableX": False, "resizableY": False,
        "minWidth": None, "maxWidth": None,
        "minHeight": None, "maxHeight": None,
        "keepAspectRatio": False,
        "tileOpacity": 1, "fillOpacity": 0.4, "lineOpacity": 1,
        "hollow": False, "color": color,
        "renderMode": "Tile", "showName": True,
        "tilesetId": ts_uid, "tileRenderMode": "FitInside",
        "tileRect": rect, "uiTileRect": dict(rect),
        "nineSliceBorders": [], "maxCount": 0,
        "limitScope": "PerLayer", "limitBehavior": "MoveLastOne",
        # The convention every sized entity here uses, and what the prop centres
        # its box and art against.
        "pivotX": 0.5, "pivotY": 0.5,
        "fieldDefs": fields,
    }


def check(before, after, entity, tileset, enum):
    """Prove the insert added exactly these objects and moved nothing else."""
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
        raise SystemExit("!! no art at ldtk/%s — run tools/gen_dark_thought.py"
                         % ART)

    uid = max(int(u) for u in re.findall(r'"uid":\s*(\d+)', raw))

    uid += 1
    enum = enum_def(uid)
    fields = [field_def("Motion",
                        "Which path it walks. Vertical and Horizontal swing "
                        "either side of the placed point; Circle orbits it.",
                        uid + 1,
                        ("LocalEnum." + ENUM, "F_Enum(%d)" % enum["uid"]),
                        {"id": "V_String", "params": [MOTIONS[0]]})]
    uid += 1
    for name, default, docstr in FIELDS:
        uid += 1
        fields.append(field_def(name, docstr, uid, ("Float", "F_Float"),
                                {"id": "V_Float", "params": [default]}))
    uid += 1
    tileset = tileset_def(uid)
    uid += 1
    entity = entity_def(uid, tileset["uid"], fields)

    print("  enum    %-16s uid %d, values %s"
          % (ENUM, enum["uid"], ", ".join(MOTIONS)))
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
    # Enums are written ONE PER LINE by LDtk, unlike the two lists above. Match
    # it, or the next save from the app reformats this line and the diff of that
    # save is this change all over again.
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
    print("  touch ldtk/hooshang_claude.ldtk")
    print("  rm .godot/imported/hooshang_claude.ldtk-* ldtk/levels/Level_*.scn")
    print("  Godot --headless --path . --import")


if __name__ == "__main__":
    main()
