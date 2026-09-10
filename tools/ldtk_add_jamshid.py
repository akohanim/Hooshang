#!/usr/bin/env python3
"""Add the `Jamshid` entity to Act 2's LDtk project, and stand him on the right
bank of Act_2_Level_0's water.

Two things in one script because they are one change: the entity definition is
useless without a first placement, and the placement cannot exist without the
definition. Both halves are independently idempotent, so re-running after
hand-moving him in LDtk adds nothing and moves nothing.

NOT the same entity as `JamshidCage` (Act_2_Level_2's locked barrier). That one
is a prop with no character in it; this is the cousin himself —
scenes/characters/jamshid/JamshidNpc.tscn, built by
scripts/ldtk_entities_post_import.gd's `_build_jamshid_npc`.

PIVOT IS BOTTOM-CENTRE (0.5, 1.0), unlike almost everything else here. Jamshid's
own origin is his FEET (assets/characters/jamshid/README.md), so a bottom pivot makes the
box LDtk draws stand on the same floor the sprite will, and makes the `px` this
writes the exact point his feet land on with no correction at either end.

FaceLeft is a 1/0 FLOAT, not a Bool, for the reason tools/ldtk_add_pond.py
records: this project has only ever written String and Float fields to an LDtk
project from a script, and CLAUDE.md records that a guessed Bool shape once
corrupted the editor.

WHERE HE STANDS is measured off the room's own Collisions/Water layers rather
than typed in, and asserted before anything is written — the bank is the run of
solid cells immediately RIGHT of the water's right edge, and his feet go on top
of the first row of it. A hardcoded pixel would silently point at open air the
first time that room is re-dug.

WRITTEN AS TEXT, not as parsed JSON re-dumped — the same trick
tools/ldtk_add_cone_spikes.py uses on Act 1's project, and needed here for the
same reason even though this file is a tenth the size. LDtk writes its own
format: `"px": [668,280]` on one line, `intGridCsv` wrapped a room-row at a
time. A `json.dump(indent="\t")` round trip explodes every one of those —
measured on this file, 9,097 lines became 69,325 — which buries a one-entity
change in an unreviewable diff and reformats every room in the Act. Inserting
the two objects as text leaves the rest byte-identical, and `check()` parses the
result back and compares it to the same edit made on the PARSED document, which
is what proves it.

LDTK MUST BE CLOSED — it holds the whole project in memory and writes it back
wholesale, so it will revert this edit. See tools/ldtk_add_magic_carpet.py.

Usage:  python3 tools/ldtk_add_jamshid.py           # dry run
        python3 tools/ldtk_add_jamshid.py --apply
"""
import copy
import json
import os
import re
import sys
import uuid

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from ldtk_add_ceiling_tile import block, ldtk_running

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
LDTK = os.path.join(ROOT, "ldtk", "hooshang_act2.ldtk")
APPLY = "--apply" in sys.argv

ENTITY = "Jamshid"
LEVEL = "Act_2_Level_0"
CELL = 8

# How far right of the water's edge he stands, in CELLS. Two: one clear of the
# waterline so he is not drawn standing in it, and no further, so he is still
# plainly "at the water" rather than off in the brick.
BANK_INSET = 3

GREETING = "(excited) Hooshang! Cousin joon!"
# The greeting's reach, in px. Measured origin to origin — see JamshidNpc's own
# `trigger_radius` doc.
TRIGGER_RADIUS = 50.0


def _common(identifier, doc, uid, type_name, type_code, default):
    return {
        "identifier": identifier, "doc": doc,
        "__type": type_name, "uid": uid, "type": type_code,
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


def string_field(identifier, doc, uid, default):
    f = _common(identifier, doc, uid, "String", "F_String",
                {"id": "V_String", "params": [default]})
    f["canBeNull"] = True
    return f


def float_field(identifier, doc, uid, default, minimum=None):
    f = _common(identifier, doc, uid, "Float", "F_Float",
                {"id": "V_Float", "params": [default]})
    f["min"] = minimum
    return f


def find_bank(level):
    """(feet_px_x, feet_px_y) on the solid bank just right of the water."""
    layers = {li["__identifier"]: li for li in level["layerInstances"]}
    water, solid = layers["Water"], layers["Collisions"]
    w, h = water["__cWid"], water["__cHei"]
    wc, cc = water["intGridCsv"], solid["intGridCsv"]

    wet = [(x, y) for y in range(h) for x in range(w) if wc[y * w + x]]
    if not wet:
        raise SystemExit("!! %s has no painted Water — nothing to stand beside." % LEVEL)
    right = max(x for x, _ in wet)
    top = min(y for _, y in wet)

    x = right + BANK_INSET
    if x >= w:
        raise SystemExit("!! the water reaches the room's right edge — no bank to stand on.")
    # The surface: the first solid row at or below the waterline, with nothing
    # solid immediately above it (so he stands in the open, not inside brick).
    for y in range(top, h):
        if cc[y * w + x] and not cc[(y - 1) * w + x]:
            return x * CELL + CELL // 2, y * CELL
    raise SystemExit("!! no standable surface at cell x=%d in %s." % (x, LEVEL))


def array_end(text, start):
    """Index of the `]` closing the JSON array that opens at/after `start`.

    String-aware, so a bracket inside a value (an iid, a doc line) cannot throw
    the count off — the same reason ldtk_add_ceiling_tile.object_span walks the
    text rather than trusting a regex.
    """
    i = text.index("[", start)
    depth, in_str, esc = 0, False, False
    while i < len(text):
        c = text[i]
        if in_str:
            if esc:
                esc = False
            elif c == "\\":
                esc = True
            elif c == '"':
                in_str = False
        elif c == '"':
            in_str = True
        elif c in "[{":
            depth += 1
        elif c in "]}":
            depth -= 1
            if depth == 0:
                return i
        i += 1
    raise SystemExit("!! unbalanced array while scanning the project file.")


def instances_span(text):
    """(open, close) of Act_2_Level_0's Entities layer `entityInstances` array.

    Found by walking FORWARD from the level's own identifier: a level object
    writes its identifier before its layerInstances, and no other layer in this
    project is called Entities, so the first one after it is the right one.
    """
    at = text.index('"identifier": "%s"' % LEVEL)
    at = text.index('"__identifier": "Entities"', at)
    at = text.index('"entityInstances":', at)
    return text.index("[", at), array_end(text, at)


def check(raw, out, want):
    """Prove the text insert produced exactly the edit made on the parsed
    document, and moved nothing else."""
    if json.loads(out) != want:
        raise SystemExit("!! the text insert did not match the parsed edit — "
                         "nothing written.")


def main():
    if ldtk_running():
        raise SystemExit("!! LDtk is open — close it first, or it will write "
                         "the project back over this edit.")
    raw = open(LDTK).read()
    doc = json.loads(raw)
    want = copy.deepcopy(doc)
    out = raw

    defs = {e["identifier"]: e for e in doc["defs"]["entities"]}
    if ENTITY in defs:
        print("  entity %s already defined — leaving it alone" % ENTITY)
        ent = defs[ENTITY]
    else:
        uid = max(int(u) for u in re.findall(r'"uid":\s*(\d+)', raw))
        fields = [
            string_field("DialogueLine",
                         "What he says: one spoken line per line of text. A line "
                         "may open with a portrait state in parentheses — "
                         "(excited), (worried) — which is read and stripped, "
                         "never printed.",
                         uid + 1, GREETING),
            float_field("TriggerRadius",
                        "How close, in px, Hooshang has to come before the line "
                        "starts. Measured origin to origin.",
                        uid + 2, TRIGGER_RADIUS, minimum=0),
            float_field("FaceLeft",
                        "1 = mirrored to face left, 0 = facing right. Every "
                        "source frame faces right.",
                        uid + 3, 1.0, minimum=0),
        ]
        ent = {
            "identifier": ENTITY, "uid": uid + 4, "tags": [],
            "exportToToc": False, "allowOutOfBounds": False,
            "doc": ("Hooshang\'s cousin, standing in a room with something to "
                    "say. Walking within TriggerRadius plays DialogueLine once. "
                    "See scenes/characters/jamshid/jamshid_npc.gd."),
            "width": 12, "height": 16,
            "resizableX": False, "resizableY": False,
            "minWidth": None, "maxWidth": None,
            "minHeight": None, "maxHeight": None,
            "keepAspectRatio": False,
            "tileOpacity": 1, "fillOpacity": 0.4, "lineOpacity": 1,
            "hollow": False, "color": "#E08A3C",
            "renderMode": "Rectangle", "showName": True,
            "tilesetId": None, "tileRenderMode": "FitInside",
            "tileRect": None, "uiTileRect": None, "nineSliceBorders": [],
            "maxCount": 0, "limitScope": "PerLevel", "limitBehavior": "MoveLastOne",
            # Bottom-centre: his origin is his feet — see the module docstring.
            "pivotX": 0.5, "pivotY": 1.0, "fieldDefs": fields,
        }
        want["defs"]["entities"].append(copy.deepcopy(ent))
        # End of defs.entities — the same marker ldtk_add_cone_spikes.py inserts
        # entity definitions at, and the only occurrence in the file.
        i = out.index('\n\t], "tilesets": [')
        out = out[:i] + ",\n" + block(ent, 2) + out[i:]
        print("would add: entity %s (fields: %s)"
              % (ENTITY, ", ".join(f["identifier"] for f in fields)))

    field_uid = {f["identifier"]: f["uid"] for f in ent["fieldDefs"]}
    level = next(lv for lv in doc["levels"] if lv["identifier"] == LEVEL)
    placed = next(li for li in level["layerInstances"]
                  if li["__identifier"] == "Entities")["entityInstances"]
    if any(e["__identifier"] == ENTITY for e in placed):
        print("  %s already placed in %s — leaving it alone" % (ENTITY, LEVEL))
    else:
        fx, fy = find_bank(level)
        inst = {
            "__identifier": ENTITY, "__grid": [fx // CELL, fy // CELL],
            "__pivot": [ent["pivotX"], ent["pivotY"]], "__tags": [],
            "__tile": None, "__smartColor": ent["color"],
            "iid": str(uuid.uuid4()),
            "width": ent["width"], "height": ent["height"],
            "defUid": ent["uid"], "px": [fx, fy],
            "fieldInstances": [
                {"__identifier": "DialogueLine", "__type": "String",
                 "__value": GREETING, "__tile": None,
                 "defUid": field_uid["DialogueLine"], "realEditorValues": []},
                {"__identifier": "TriggerRadius", "__type": "Float",
                 "__value": TRIGGER_RADIUS, "__tile": None,
                 "defUid": field_uid["TriggerRadius"], "realEditorValues": []},
                {"__identifier": "FaceLeft", "__type": "Float",
                 "__value": 1.0, "__tile": None,
                 "defUid": field_uid["FaceLeft"], "realEditorValues": []},
            ],
            "__worldX": level["worldX"] + fx, "__worldY": level["worldY"] + fy,
        }
        want_level = next(lv for lv in want["levels"] if lv["identifier"] == LEVEL)
        next(li for li in want_level["layerInstances"]
             if li["__identifier"] == "Entities")["entityInstances"] \
            .append(copy.deepcopy(inst))
        open_at, close_at = instances_span(out)
        empty = out[open_at + 1:close_at].strip() == ""
        text = block(inst, 6)
        out = out[:close_at] + ("" if empty else ",\n") + text + "\n\t\t\t\t\t" \
            + out[close_at:]
        print("would place: %s in %s, feet at px (%d, %d) — cell (%d, %d)"
              % (ENTITY, LEVEL, fx, fy, fx // CELL, fy // CELL))
        print("             saying %r within %gpx" % (GREETING, TRIGGER_RADIUS))

    if out == raw:
        print("\nnothing to add.")
        return
    check(raw, out, want)
    print("\nverified: the text insert matches the parsed edit exactly — "
          "nothing else in the file moved")
    if not APPLY:
        print("\nDRY RUN — nothing written. Re-run with --apply")
        return
    tmp = LDTK + ".tmp"
    open(tmp, "w").write(out)
    os.replace(tmp, LDTK)
    print("\nAPPLIED. The hook that BUILDS this entity changed too, so the .ldtk")
    print("needs touching or Godot will not re-read it (CLAUDE.md). Editor CLOSED:")
    print("  touch ldtk/hooshang_act2.ldtk")
    print("  rm .godot/imported/hooshang_act2.ldtk-* ldtk/levels/Act_2_Level_*.scn")
    print("  Godot --headless --path . --import")


main()
