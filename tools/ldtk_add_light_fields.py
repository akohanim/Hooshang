#!/usr/bin/env python3
"""Give CeilingPanel and CeilingLight per-instance lighting fields in LDtk.

Placed entities all came out with the scene's tuning — room 2's — and no way to
change one without changing every other. These are the knobs, on the entity
itself, so a run over a desk can burn brighter than the one down the corridor
and a failing tube can be one instance rather than a second prefab.

  PanelEnergy    how bright the FITTING looks
  PoolEnergy     how bright the pool it throws is
  PoolScale      the pool's radius, at 64px per 1.0 (LIGHTING.md's one number)
  PoolDrop       how far below the fixture that pool is centred
  Tint           colour of both
  Flicker        fluorescent sputter, with Amount and Speed under it

EVERY FIELD IS OPTIONAL, and that is the design rather than laziness. An LDtk
field nobody has typed into arrives as null, and `scripts/
ldtk_entities_post_import.gd` falls back to what the PROP already has — so an
untouched instance is still exactly the fixture in room 2, and only the fields
you fill in move. A Float that defaulted to 0 instead would be a light that is
off while looking configured.

The two ENERGIES are two jobs, which is why there are two: the panel is how
bright the thing looks and the pool is how far its light carries. Turning the
pool down without the panel leaves a dim room lit by a fitting that still looks
brand new.

Painted `ceiling` panels have no entity to carry fields — they are lit from the
constants at the top of scripts/ldtk_level_post_import.gd, which are the one
global for the whole world. Drop a CeilingLight on a cell to overrule one.

EDITED AS TEXT, not as parsed JSON re-dumped, and PROVEN afterwards by parsing
both versions and comparing them key by key.

LDTK MUST BE CLOSED. It holds the whole project in memory and writes it back
wholesale, so a scripted edit made under a running LDtk is silently reverted.

Idempotent: running it twice adds nothing the second time.

Usage:  python3 tools/ldtk_add_light_fields.py          # dry run
        python3 tools/ldtk_add_light_fields.py --apply
"""
import copy
import json
import os
import re
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from ldtk_add_ceiling_tile import array_end, block, ldtk_running, object_span

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
LDTK = os.path.join(ROOT, "ldtk", "hooshang_claude.ldtk")
APPLY = "--apply" in sys.argv

ENTITIES = ["CeilingPanel", "CeilingLight"]

## (identifier, LDtk type, doc). Order is the order they appear in the panel.
FIELDS = [
    ("PanelEnergy", "Float",
     "How bright the FITTING itself looks. Blank = the prop's own (1.6)."),
    ("PoolEnergy", "Float",
     "How bright the pool it throws is. Blank = the prop's own."),
    ("PoolScale", "Float",
     "Radius of that pool: 64px per 1.0. Blank = the prop's own. "
     "Mind the seam rule — a light does not stop at a room's edge."),
    ("PoolDrop", "Float",
     "How far BELOW the fixture the pool is centred, in px. Blank = the "
     "prop's own."),
    ("Tint", "Color", "Colour of the panel and its pool. Blank = cold white."),
    ("Flicker", "Bool", "Fluorescent sputter — a tube on its way out."),
    ("FlickerAmount", "Float",
     "How deep the sputter dips, 0..1. Only read when Flicker is on."),
    ("FlickerSpeed", "Float",
     "How fast it sputters. Only read when Flicker is on."),
]


def field_def(identifier, kind, doc, uid):
    """One fieldDef, written the way LDtk writes them — every key the format
    carries, because a missing one is not a default when LDtk reads this back."""
    return {
        "identifier": identifier,
        "doc": doc,
        "__type": kind,
        "uid": uid,
        "type": "F_" + kind,
        "isArray": False,
        # Optional on purpose: unset means "leave the prop alone". A Bool cannot
        # be null in LDtk, and does not need to be — the prop's default is off.
        "canBeNull": kind != "Bool",
        "arrayMinLength": None, "arrayMaxLength": None,
        "editorDisplayMode": "NameAndValue",
        "editorDisplayScale": 1,
        "editorDisplayPos": "Above",
        "editorLinkStyle": "StraightArrow",
        "editorDisplayColor": None,
        "editorAlwaysShow": False,
        "editorShowInWorld": False,
        "editorCutLongValues": True,
        "editorTextSuffix": None, "editorTextPrefix": None,
        "useForSmartColor": False,
        "exportToToc": False,
        "searchable": False,
        "min": 0 if kind == "Float" else None,
        "max": None,
        "regex": None,
        "acceptFileTypes": None,
        "defaultOverride": None,
        "textLanguageMode": None,
        "symmetricalRef": False,
        "autoChainRef": True,
        "allowOutOfLevelRef": True,
        "allowedRefs": "OnlySame",
        "allowedRefsEntityUid": None,
        "allowedRefTags": [],
        "tilesetUid": None,
    }


def check(before, after, added):
    """Prove only the two entities' fieldDefs changed."""
    a, b = json.loads(before), json.loads(after)
    for name in ENTITIES:
        ea = [e for e in a["defs"]["entities"] if e["identifier"] == name][0]
        eb = [e for e in b["defs"]["entities"] if e["identifier"] == name][0]
        if eb["fieldDefs"] != ea["fieldDefs"] + added[name]:
            raise SystemExit("!! %s's fields are not what was intended" % name)
    sa, sb = copy.deepcopy(a), copy.deepcopy(b)
    for doc in (sa, sb):
        for e in doc["defs"]["entities"]:
            if e["identifier"] in ENTITIES:
                e["fieldDefs"] = None
    if sa != sb:
        raise SystemExit("!! something outside those fieldDefs moved")


def main():
    if ldtk_running():
        raise SystemExit("!! LDtk is open — close it first, or it will write "
                         "the project back over this edit.")
    raw = open(LDTK).read()
    out = raw
    uid = max(int(u) for u in re.findall(r'"uid":\s*(\d+)', raw))
    added = {}

    for name in ENTITIES:
        b, e = object_span(out, out.index('"identifier": "%s"' % name))
        entity = out[b:e]
        if '"identifier": "%s"' % FIELDS[0][0] in entity:
            print("  %s already has its fields — skipping" % name)
            added[name] = []
            continue
        defs = []
        for ident, kind, doc in FIELDS:
            uid += 1
            defs.append(field_def(ident, kind, doc, uid))
        added[name] = defs
        i = array_end(entity, entity.index('"fieldDefs"'))
        # fieldDefs is an EMPTY array on both of these, so there is no comma to
        # write before the first entry — one for every entry after it.
        body = ",\n".join(block(d, 4) for d in defs)
        entity = entity[:i] + "\n" + body + "\n\t\t\t" + entity[i:]
        out = out[:b] + entity + out[e:]
        print("  %s  + %d fields" % (name, len(defs)))

    if not any(added.values()):
        return
    check(raw, out, added)
    for ident, kind, _doc in FIELDS:
        print("      %-14s %s" % (ident, kind))
    if not APPLY:
        print("\nDRY RUN — nothing written. Re-run with --apply")
        return
    tmp = LDTK + ".tmp"
    open(tmp, "w").write(out)
    os.replace(tmp, LDTK)
    print("\nAPPLIED. Re-import in Godot:")
    print("  rm .godot/imported/hooshang_claude.ldtk-* ldtk/levels/Level_*.scn")
    print("  Godot --headless --path . --import")


if __name__ == "__main__":
    main()
