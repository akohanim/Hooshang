#!/usr/bin/env python3
"""Add the Ladder entity to the LDtk project.

A climbable rail. Stretch it vertically in LDtk to set how tall it is; width
is fixed at one cell (8px), both here (resizableX off, minWidth == maxWidth)
and in the prop itself (scenes/props/zones/ladder.gd's CELL) — nothing about
a ladder should read as wider than the rail it is.

NO TILESET. Renders as a plain coloured Rectangle in the LDtk editor, the same
way SlideZone does — the real rung art is drawn by the Godot prop at runtime
(tools/gen_ladder.py), tiled to whatever height the entity is stretched to.

CENTRE PIVOT (0.5/0.5), the convention every other sized/resizable entity in
this project uses (see ldtk_entities_post_import.gd's own header comment) —
so `data.position` is already the box's centre and _build_ladder needs no
pivot offsetting, same reason SlideZone and ConeSpikes are simple.

WRITTEN AS TEXT, not as parsed JSON re-dumped — see tools/ldtk_add_cone_spikes.py
for why (a round trip through json.dump touches all 20k lines of this 1MB
file). Inserting the object as text leaves the rest of the file untouched, and
the result is parsed back and compared to prove exactly that.

LDTK MUST BE CLOSED. It holds the whole project in memory and writes it back
wholesale, so a scripted edit made under a running LDtk is silently reverted.

Idempotent: running it twice adds nothing the second time.

Usage:  python3 tools/ldtk_add_ladder.py          # dry run
        python3 tools/ldtk_add_ladder.py --apply
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

NAME = "Ladder"
CELL = 8
DOC = ("A climbable rail. Stretch it vertically to set how tall it is; width "
       "is fixed at one cell. Standing in it and pressing up/down grips it — "
       "see scenes/props/zones/ladder.gd.")


def entity_def(uid):
    return {
        "identifier": NAME, "uid": uid, "tags": [],
        "exportToToc": False, "allowOutOfBounds": False, "doc": DOC,
        "width": CELL, "height": CELL * 2,
        "resizableX": False, "resizableY": True,
        "minWidth": CELL, "maxWidth": CELL, "minHeight": CELL, "maxHeight": None,
        "keepAspectRatio": False,
        "tileOpacity": 1, "fillOpacity": 0.5, "lineOpacity": 1, "hollow": False,
        "color": "#A8845C", "renderMode": "Rectangle", "showName": True,
        "tilesetId": None, "tileRenderMode": "FitInside",
        "tileRect": None, "uiTileRect": None, "nineSliceBorders": [],
        "maxCount": 0, "limitScope": "PerLayer", "limitBehavior": "MoveLastOne",
        "pivotX": 0.5, "pivotY": 0.5,
        "fieldDefs": [],
    }


def check(before, after, ent):
    """Prove the insert added exactly this object and moved nothing else."""
    a, b = json.loads(before), json.loads(after)
    if b["defs"]["entities"] != a["defs"]["entities"] + [ent]:
        raise SystemExit("!! the entity list is not what was intended")
    sa, sb = copy.deepcopy(a), copy.deepcopy(b)
    for doc in (sa, sb):
        doc["defs"]["entities"] = None
    if sa != sb:
        raise SystemExit("!! something outside the entity list moved")


def main():
    if ldtk_running():
        raise SystemExit("!! LDtk is open — close it first, or it will write "
                         "the project back over this edit.")
    raw = open(LDTK).read()
    doc = json.loads(raw)
    have = {e["identifier"] for e in doc["defs"]["entities"]}
    if NAME in have:
        print("  %s already defined — nothing to add." % NAME)
        return

    uid = max(int(u) for u in re.findall(r'"uid":\s*(\d+)', raw)) + 1
    ent = entity_def(uid)
    print("  %-8s entity %d (%dx%d, stretches down)" % (NAME, uid, CELL, CELL * 2))

    out = raw
    i = out.index('\n\t], "tilesets": [')
    out = out[:i] + ",\n" + block(ent, 2) + out[i:]

    check(raw, out, ent)
    print("\nverified: 1 entity added, nothing else touched")
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
