#!/usr/bin/env python3
"""Add the four ConeSpikes entities to the LDtk project.

Four entity definitions and four 8px tilesets (the sheets drawn by
tools/gen_cone_spikes.py), so an 8x8 spike strip can be dragged onto any of the
four surfaces by hand.

FOUR ENTITIES, NOT ONE WITH A DIRECTION FIELD. Same reason the glass spikes are
four and the note tiles are five: a field you forget to set is a silent wrong
answer, and spikes growing out of a ceiling upside down is exactly the kind of
thing nobody notices until they are playing that room. Picking the right entity
is a choice you cannot forget to make.

Floor and ceiling stretch SIDEWAYS (resizableX); walls stretch UP AND DOWN
(resizableY). The other axis is not draggable and is forced to one cell on
import anyway (scripts/ldtk_entities_post_import.gd), so a diagonal drag still
yields a strip. Pivot stays 0.5/0.5, the convention every sized entity here uses
and what the prop centres its box and art against.

EIGHT, NOT SIXTEEN. width/height are 8 and every tileset is tileGridSize 8 —
these are single-cell hazards, and the entity grid is already 8 everywhere in
this project, so nothing about the layer setup has to change. Bricks8px is the
existing 8px tileset this copies the shape of.

WRITTEN AS TEXT, not as parsed JSON re-dumped. ldtk_add_platforms.py, which this
is otherwise modelled on, does `json.dump(indent="\\t")` over the whole project —
and the project is a 1MB file in LDtk's own format, with arrays like
`"px": [172,12]` on one line. A dump round trip explodes every one of those and
rewrites all 20k lines, which buries a four-entity change in an unreviewable
diff. Inserting the objects as text leaves the rest of the file untouched, and
the result is parsed back and compared to prove exactly that.

LDTK MUST BE CLOSED. It holds the whole project in memory and writes it back
wholesale, so a scripted edit made under a running LDtk is silently reverted —
CLAUDE.md records that happening to an entity rename already. This refuses to
run rather than let that happen.

Idempotent: running it twice adds nothing the second time.

Usage:  python3 tools/ldtk_add_cone_spikes.py          # dry run
        python3 tools/ldtk_add_cone_spikes.py --apply
"""
import copy
import json
import os
import re
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from ldtk_add_ceiling_tile import block, ldtk_running

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
LDTK = os.path.join(ROOT, "ldtk", "hooshang_act1.ldtk")
APPLY = "--apply" in sys.argv

CELL = 8
TILES = 5
## Which tile of the sheet stands in as the editor icon: MIDDLE_A, so the icon
## shows the repeating body rather than a capped end that only ever appears once
## in a run.
ICON_TILE = 2

## identifier, art sheet, is the strip vertical, colour, doc.
ENTITIES = [
    ("ConeSpikes", "art/cone_spikes.png", False, "#F0E6D2",
     "A row of small conical spikes on the FLOOR, points up. One cell tall — "
     "stretch it SIDEWAYS; the height you drag it to is ignored on import."),
    ("ConeSpikesCeiling", "art/cone_spikes_down.png", False, "#D8CEBC",
     "The same spikes on a CEILING, points down. Stretch it SIDEWAYS; one cell "
     "tall. It falls when the room collapses, and lands as a floor strip."),
    ("ConeSpikesLeftWall", "art/cone_spikes_right.png", True, "#CFC4B2",
     "Spikes bolted to the wall on the LEFT, points aiming RIGHT into the room. "
     "Stretch it UP AND DOWN; one cell wide. Anchored — a wall strip does not "
     "come down when the room does."),
    ("ConeSpikesRightWall", "art/cone_spikes_left.png", True, "#C6BBA8",
     "Spikes bolted to the wall on the RIGHT, points aiming LEFT into the room. "
     "Stretch it UP AND DOWN; one cell wide. Anchored — a wall strip does not "
     "come down when the room does."),
]


def tileset_def(name, rel_path, vertical, uid):
    """An 8px tileset over one spike sheet, shaped like Bricks8px."""
    w, h = (CELL, CELL * TILES) if vertical else (CELL * TILES, CELL)
    return {
        "__cWid": w // CELL, "__cHei": h // CELL,
        "identifier": name + "Sheet", "uid": uid,
        "relPath": rel_path, "embedAtlas": None,
        "pxWid": w, "pxHei": h, "tileGridSize": CELL,
        "spacing": 0, "padding": 0, "tags": [],
        "tagsSourceEnumUid": None, "enumTags": [], "customData": [],
        "cachedPixelData": None, "savedSelections": [],
    }


def entity_def(name, vertical, color, doc, uid, ts_uid):
    # The icon tile, one axis apart depending on which way the sheet runs.
    rect = {"tilesetUid": ts_uid,
            "x": 0 if vertical else ICON_TILE * CELL,
            "y": ICON_TILE * CELL if vertical else 0,
            "w": CELL, "h": CELL}
    return {
        "identifier": name, "uid": uid, "tags": [],
        "exportToToc": False, "allowOutOfBounds": False,
        "doc": doc,
        "width": CELL, "height": CELL,
        # A wall strip stretches only down, a floor strip only across. The other
        # axis is forced to one cell on import regardless, so this just stops
        # the handle offering a drag that cannot mean anything.
        "resizableX": not vertical, "resizableY": vertical,
        "minWidth": None if vertical else CELL,
        "maxWidth": None,
        "minHeight": CELL if vertical else None,
        "maxHeight": None,
        "keepAspectRatio": False,
        "tileOpacity": 1, "fillOpacity": 0.4, "lineOpacity": 1,
        "hollow": False, "color": color,
        "renderMode": "Tile", "showName": True,
        "tilesetId": ts_uid, "tileRenderMode": "Repeat",
        "tileRect": rect, "uiTileRect": dict(rect),
        "nineSliceBorders": [], "maxCount": 0,
        "limitScope": "PerLayer", "limitBehavior": "MoveLastOne",
        "pivotX": 0.5, "pivotY": 0.5, "fieldDefs": [],
    }


def check(before, after, ents, tss):
    """Prove the insert added exactly these objects and moved nothing else."""
    a, b = json.loads(before), json.loads(after)
    if b["defs"]["entities"] != a["defs"]["entities"] + ents:
        raise SystemExit("!! the entity list is not what was intended")
    if b["defs"]["tilesets"] != a["defs"]["tilesets"] + tss:
        raise SystemExit("!! the tileset list is not what was intended")
    sa, sb = copy.deepcopy(a), copy.deepcopy(b)
    for doc in (sa, sb):
        doc["defs"]["entities"] = doc["defs"]["tilesets"] = None
    if sa != sb:
        raise SystemExit("!! something outside the entity and tileset lists moved")


def main():
    if ldtk_running():
        raise SystemExit("!! LDtk is open — close it first, or it will write "
                         "the project back over this edit.")
    raw = open(LDTK).read()
    doc = json.loads(raw)
    have = {e["identifier"] for e in doc["defs"]["entities"]}

    todo = [spec for spec in ENTITIES if spec[0] not in have]
    for spec in ENTITIES:
        if spec[0] in have:
            print("  %s already defined — skipping" % spec[0])
    if not todo:
        print("\nnothing to add.")
        return

    for _name, rel, _v, _c, _d in todo:
        if not os.path.exists(os.path.join(ROOT, "ldtk", rel)):
            raise SystemExit("!! no art at ldtk/%s — run tools/gen_cone_spikes.py"
                             % rel)

    uid = max(int(u) for u in re.findall(r'"uid":\s*(\d+)', raw))
    ents, tss = [], []
    for name, rel, vertical, color, docstr in todo:
        uid += 1
        ts = tileset_def(name, rel, vertical, uid)
        uid += 1
        ents.append(entity_def(name, vertical, color, docstr, uid, ts["uid"]))
        tss.append(ts)
        print("  %-22s entity %d, tileset %d (%dx%d, grid %d), %s"
              % (name, uid, ts["uid"], ts["pxWid"], ts["pxHei"], ts["tileGridSize"],
                 "stretches down" if vertical else "stretches across"))

    out = raw
    i = out.index('\n\t], "tilesets": [')
    out = out[:i] + ",\n" + ",\n".join(block(e, 2) for e in ents) + out[i:]
    j = out.index('\n\t], "enums": [')
    out = out[:j] + ",\n" + ",\n".join(block(t, 2) for t in tss) + out[j:]

    check(raw, out, ents, tss)
    print("\nverified: %d entities and %d tilesets added, nothing else touched"
          % (len(ents), len(tss)))
    if not APPLY:
        print("\nDRY RUN — nothing written. Re-run with --apply")
        return
    tmp = LDTK + ".tmp"
    open(tmp, "w").write(out)
    os.replace(tmp, LDTK)
    print("\nAPPLIED. Re-import in Godot — and the hook that BUILDS these has")
    print("changed too, so the .ldtk needs touching or Godot will not re-read it:")
    print("  touch ldtk/hooshang_act1.ldtk")
    print("  rm .godot/imported/hooshang_act1.ldtk-* ldtk/levels/Level_*.scn")
    print("  Godot --headless --path . --import")


if __name__ == "__main__":
    main()
