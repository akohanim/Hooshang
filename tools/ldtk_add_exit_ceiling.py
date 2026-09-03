#!/usr/bin/env python3
"""Add the ExitCeiling entity to the LDtk project.

A ceiling-mounted twin of the existing Exit entity: touching it advances to
the next room exactly the same way (scripts/ldtk_entities_post_import.gd's
_build_exit_ceiling reuses Exit's own trigger/group/NextRoom-meta setup), it
is just an 8x16 sign hanging from the ceiling instead of a 16x32 doorway.

CENTRE PIVOT (0.5/0.5), NOT Exit's OWN (0/0). Exit predates the convention
every other sized entity in this project uses — this project's own header
comment in ldtk_entities_post_import.gd says "All entities here use a centre
pivot" — so the new entity follows that instead of copying Exit's legacy
corner pivot. That is what keeps _build_exit_ceiling simple: data.position IS
the box's centre, nothing needs offsetting.

NO TILESET. Like SlideZone, this renders as a plain coloured Rectangle in the
LDtk editor — the real art is the ExitSignCeiling.tscn prefab the Godot side
instances, not something the .ldtk needs to carry.

WRITTEN AS TEXT, not as parsed JSON re-dumped — see tools/ldtk_add_cone_spikes.py
for why (a round trip through json.dump touches all 20k lines of this 1MB
file). Inserting the object as text leaves the rest of the file untouched, and
the result is parsed back and compared to prove exactly that.

LDTK MUST BE CLOSED. It holds the whole project in memory and writes it back
wholesale, so a scripted edit made under a running LDtk is silently reverted.

Idempotent: running it twice adds nothing the second time.

Usage:  python3 tools/ldtk_add_exit_ceiling.py          # dry run
        python3 tools/ldtk_add_exit_ceiling.py --apply
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

NAME = "ExitCeiling"
DOC = ("Ceiling-mounted room exit — behaves exactly like Exit (touching it "
       "advances to the next room); an 8x16 sign hanging from the ceiling "
       "instead of a floor doorway. Leave NextRoom blank to use the next room "
       "by world position.")


def field_next_room(uid):
    """Same shape as Exit's own NextRoom field (uid 40) in the live project."""
    return {
        "identifier": "NextRoom",
        "doc": "Optional: room identifier to jump to. Blank = next room by world position.",
        "__type": "String", "uid": uid, "type": "F_String",
        "isArray": False, "canBeNull": True,
        "arrayMinLength": None, "arrayMaxLength": None,
        "editorDisplayMode": "NameAndValue", "editorDisplayScale": 1,
        "editorDisplayPos": "Above", "editorLinkStyle": "StraightArrow",
        "editorDisplayColor": None, "editorAlwaysShow": False,
        "editorShowInWorld": True, "editorCutLongValues": True,
        "editorTextSuffix": None, "editorTextPrefix": None,
        "useForSmartColor": False, "exportToToc": False, "searchable": False,
        "min": None, "max": None, "regex": None, "acceptFileTypes": None,
        "defaultOverride": None, "textLanguageMode": None,
        "symmetricalRef": False, "autoChainRef": True,
        "allowOutOfLevelRef": True, "allowedRefs": "OnlySame",
        "allowedRefsEntityUid": None, "allowedRefTags": [],
        "tilesetUid": None,
    }


def entity_def(uid, field_uid):
    return {
        "identifier": NAME, "uid": uid, "tags": [],
        "exportToToc": False, "allowOutOfBounds": False, "doc": DOC,
        "width": 8, "height": 16,
        "resizableX": False, "resizableY": False,
        "minWidth": None, "maxWidth": None, "minHeight": None, "maxHeight": None,
        "keepAspectRatio": False,
        "tileOpacity": 1, "fillOpacity": 0.7, "lineOpacity": 1, "hollow": False,
        "color": "#3FA34D", "renderMode": "Rectangle", "showName": True,
        "tilesetId": None, "tileRenderMode": "FitInside",
        "tileRect": None, "uiTileRect": None, "nineSliceBorders": [],
        "maxCount": 0, "limitScope": "PerLevel", "limitBehavior": "PreventAdding",
        "pivotX": 0.5, "pivotY": 0.5,
        "fieldDefs": [field_next_room(field_uid)],
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

    uid = max(int(u) for u in re.findall(r'"uid":\s*(\d+)', raw))
    ent = entity_def(uid + 2, uid + 1)
    print("  %-14s entity %d, field %d" % (NAME, uid + 2, uid + 1))

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
