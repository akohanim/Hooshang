#!/usr/bin/env python3
"""Add a `ChildhoodPalette` Float field to Act 2's own copies of the
DarkThought/LightThought/GreyThought and four ConeSpikes* entity defs.

WHY A FIELD, NOT A PER-PROJECT-FILE SWAP. Unlike the wall tileset or the
paintable "sludge" tiles (tools/ldtk_add_act2_tileset.py), these hazards are
Godot SCENES — dark_thought.gd/cone_spikes.gd hardcode their art as preload()
constants, and the one shared scene/script is instanced by BOTH Acts via the
one shared scripts/ldtk_entities_post_import.gd. So a per-Act look needs a
per-*instance* switch, and the level author sets it the same way DarkThought's
own Glow field already works: unset/0 means "old behavior" (Act 1's office
palette — palette.gd's Palette.OFFICE, the default), anything above 0 means
Act 2's childhood palette.

A NUMBER, NOT A CHECKBOX — same reasoning ldtk_add_dark_thought.py gives for
Clockwise/Glow: LDtk has only ever written String and Float fields in this
project, and a Bool built from a guessed shape crashed the editor once already.

Only hooshang_act2.ldtk is touched. hooshang_claude.ldtk (Act 1) has no field
named ChildhoodPalette and never will — its own DarkThought/ConeSpikes
placements simply have no override for a field that does not exist there,
which is exactly what leaves every existing Act 1 room unaffected.

LDTK MUST BE CLOSED — see tools/ldtk_add_platforms.py for why.

Idempotent: running it twice adds nothing the second time (checks each
entity's fieldDefs for the field by name first).

Usage:  python3 tools/ldtk_add_act2_palette_field.py          # dry run
        python3 tools/ldtk_add_act2_palette_field.py --apply
"""
import json
import os
import re
import subprocess
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
LDTK = os.path.join(ROOT, "ldtk", "hooshang_act2.ldtk")
APPLY = "--apply" in sys.argv

FIELD_NAME = "ChildhoodPalette"
FIELD_DOC = ("0 (default) = Act 1's office palette. Anything above 0 = Act "
             "2's childhood-memory palette (see dark_thought.gd/"
             "cone_spikes.gd's Palette enum). A number, not a checkbox — "
             "see tools/ldtk_add_act2_palette_field.py.")
ENTITIES = ["DarkThought", "LightThought", "GreyThought",
            "ConeSpikes", "ConeSpikesCeiling",
            "ConeSpikesLeftWall", "ConeSpikesRightWall"]


def ldtk_running():
    try:
        out = subprocess.run(["ps", "ax", "-o", "command"],
                             capture_output=True, text=True).stdout
    except Exception:
        return False
    return any("LDtk.app/Contents/MacOS/LDtk" in line for line in out.splitlines())


def field_def(uid):
    return {
        "identifier": FIELD_NAME, "doc": FIELD_DOC,
        "__type": "Float", "uid": uid, "type": "F_Float",
        "isArray": False, "canBeNull": False,
        "arrayMinLength": None, "arrayMaxLength": None,
        "editorDisplayMode": "NameAndValue", "editorDisplayScale": 1,
        "editorDisplayPos": "Above", "editorLinkStyle": "ArrowsLine",
        "editorDisplayColor": None, "editorAlwaysShow": False,
        "editorShowInWorld": True, "editorCutLongValues": True,
        "editorTextSuffix": None, "editorTextPrefix": None,
        "useForSmartColor": False, "exportToToc": False, "searchable": False,
        "min": None, "max": None, "regex": None, "acceptFileTypes": None,
        "defaultOverride": {"id": "V_Float", "params": [0.0]},
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
    uid = max(int(u) for u in re.findall(r'"uid":\s*(\d+)', raw))

    by_id = {e["identifier"]: e for e in d["defs"]["entities"]}
    missing = [name for name in ENTITIES if name not in by_id]
    if missing:
        raise SystemExit("!! entity defs not found in %s: %s" % (LDTK, missing))

    changed = []
    for name in ENTITIES:
        entity = by_id[name]
        if any(f["identifier"] == FIELD_NAME for f in entity["fieldDefs"]):
            continue
        uid += 1
        entity["fieldDefs"].append(field_def(uid))
        changed.append(name)

    print("\nwould add %s to: %s" % (FIELD_NAME, ", ".join(changed) if changed else "nothing"))
    if not changed:
        return
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
