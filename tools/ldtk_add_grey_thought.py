#!/usr/bin/env python3
"""Add the GreyThought entity to LDtk: the neutral tone beside dark and light.

One entity definition and one 16px tileset over the grey sprite sheet. NO new
enum and no new fields — it reuses ThoughtMotion and carries the same fields as
the DarkThought, because it is the same hazard in a different colour. Since it
is built from the DarkThought definition (which now carries the Angle field),
grey gets Angle for free.

WHY IT IS A SEPARATE ENTITY, when the tones are one prop, one script and one set
of fields on the Godot side. A `Tone` field would work and would be one less
thing here. It is a separate entity for the one reason the tones exist: LDtk
draws an entity as its icon, so a distinct entity means you can SEE which one you
placed while laying out a room. This is the same rationale as the dark/light
split — see ldtk_add_light_thought.py.

BUILT FROM ldtk_add_dark_thought.py, NOT FROM A COPY OF IT. The fieldDef and
entityDef shapes in that file are the part that was difficult. This imports them
and passes the handful of values that differ, then checks the result KEY BY KEY
against the DarkThought definition already in the project — which LDtk itself
has opened, saved and round-tripped — allowing only the keys that name this
entity to differ. See `mirrors`.

LDTK MUST BE CLOSED. It holds the whole project in memory and writes it back
wholesale, so a scripted edit made under a running LDtk is silently reverted.
This refuses to run rather than let that happen.

Idempotent: running it twice adds nothing the second time.

Usage:  python3 tools/ldtk_add_grey_thought.py          # dry run
        python3 tools/ldtk_add_grey_thought.py --apply
"""
import copy
import json
import os
import re
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from ldtk_add_ceiling_tile import block, ldtk_running
import ldtk_add_dark_thought as dt

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
LDTK = os.path.join(ROOT, "ldtk", "hooshang_act1.ldtk")
APPLY = "--apply" in sys.argv

ENTITY = "GreyThought"
TWIN = dt.ENTITY                 # DarkThought — the shape this is checked against
ART = "art/grey_thought.png"
## Neutral grey, so the three are told apart in the entity list at a glance the
## same way they are told apart in the room.
COLOR = "#8C8A96"
DOC = ("A grey thought: the same drifting cloud as a DarkThought, neutral grey "
       "instead of black, with the same red rim. The third feeling-tone beside "
       "unpleasant and pleasant. Identical in every other way — same path, same "
       "speed, same kill. The point you place is the CENTRE of the path. Not "
       "resizable: it is 16x16.")

## Keys of the entity definition that are ALLOWED to differ from the twin's.
## Everything else must match exactly — that is the whole check.
MAY_DIFFER = {"identifier", "uid", "doc", "color", "tilesetId",
              "tileRect", "uiTileRect", "fieldDefs"}


def mirrors(built, twin):
    """Prove the new entity is the existing one with only its identity changed.

    Stronger than checking the file still parses: the DarkThought definition has
    been opened and saved by LDtk itself, so matching it key for key is evidence
    from the application rather than from this script's own idea of the format.
    """
    if set(built) != set(twin):
        raise SystemExit("!! key sets differ: %s"
                         % (set(built) ^ set(twin)))
    for key in built:
        if key in MAY_DIFFER:
            continue
        if built[key] != twin[key]:
            raise SystemExit("!! %r differs from %s (%r vs %r)"
                             % (key, TWIN, built[key], twin[key]))
    # The fields are excused above only because their uids differ. Everything
    # else about them has to match, or the grey thought reads a different set of
    # numbers from the black one and stops being a recolour.
    if len(built["fieldDefs"]) != len(twin["fieldDefs"]):
        raise SystemExit("!! field count differs from %s" % TWIN)
    for a, b in zip(built["fieldDefs"], twin["fieldDefs"]):
        sa, sb = dict(a), dict(b)
        sa["uid"] = sb["uid"] = None
        if sa != sb:
            raise SystemExit("!! field %r differs from %s's"
                             % (a["identifier"], TWIN))


def check(before, after, entity, tileset):
    """Prove the insert added exactly these two objects and moved nothing else."""
    a, b = json.loads(before), json.loads(after)
    if b["defs"]["entities"] != a["defs"]["entities"] + [entity]:
        raise SystemExit("!! the entity list is not what was intended")
    if b["defs"]["tilesets"] != a["defs"]["tilesets"] + [tileset]:
        raise SystemExit("!! the tileset list is not what was intended")
    sa, sb = copy.deepcopy(a), copy.deepcopy(b)
    for doc in (sa, sb):
        doc["defs"]["entities"] = doc["defs"]["tilesets"] = None
    if sa != sb:
        raise SystemExit("!! something outside those two lists moved")


def main():
    if ldtk_running():
        raise SystemExit("!! LDtk is open — close it first, or it will write "
                         "the project back over this edit.")
    raw = open(LDTK).read()
    doc = json.loads(raw)
    ents = {e["identifier"]: e for e in doc["defs"]["entities"]}
    if ENTITY in ents:
        print("  %s already defined — nothing to add." % ENTITY)
        return
    if TWIN not in ents:
        raise SystemExit("!! %s is not defined yet — run "
                         "tools/ldtk_add_dark_thought.py first" % TWIN)
    if not os.path.exists(os.path.join(ROOT, "ldtk", ART)):
        raise SystemExit("!! no art at ldtk/%s — run tools/gen_dark_thought.py"
                         % ART)
    enums = {e["identifier"]: e for e in doc["defs"]["enums"]}
    if dt.ENUM not in enums:
        raise SystemExit("!! the %s enum is missing" % dt.ENUM)

    uid = max(int(u) for u in re.findall(r'"uid":\s*(\d+)', raw))

    # The SAME fields, in the same order, off the same builder the twin used —
    # only the uids are new. Built from the twin's own field list so any field
    # added to the twin (like Angle) is carried here automatically.
    twin_fields = ents[TWIN]["fieldDefs"]
    fields = []
    for tf in twin_fields:
        uid += 1
        f = copy.deepcopy(tf)
        f["uid"] = uid
        fields.append(f)

    uid += 1
    tileset = dt.tileset_def(uid, ENTITY, ART)
    uid += 1
    entity = dt.entity_def(uid, tileset["uid"], fields, ENTITY, DOC, COLOR)

    mirrors(entity, ents[TWIN])
    print("  tileset %-16s uid %d, %dx%d, grid %d"
          % (tileset["identifier"], tileset["uid"], tileset["pxWid"],
             tileset["pxHei"], tileset["tileGridSize"]))
    print("  entity  %-16s uid %d, %dx%d, not resizable"
          % (ENTITY, entity["uid"], dt.CELL, dt.CELL))
    for f in fields:
        print("      %-12s %-24s" % (f["identifier"], f["__type"]))
    print("  reuses the existing %s enum (uid %d)"
          % (dt.ENUM, enums[dt.ENUM]["uid"]))
    print("  mirrors %s: every key outside %s matches"
          % (TWIN, ", ".join(sorted(MAY_DIFFER))))

    out = raw
    i = out.index('\n\t], "tilesets": [')
    out = out[:i] + ",\n" + block(entity, 2) + out[i:]
    j = out.index('\n\t], "enums": [')
    out = out[:j] + ",\n" + block(tileset, 2) + out[j:]

    check(raw, out, entity, tileset)
    print("\nverified: 1 entity and 1 tileset added, nothing else touched")
    if not APPLY:
        print("\nDRY RUN — nothing written. Re-run with --apply")
        return
    tmp = LDTK + ".tmp"
    open(tmp, "w").write(out)
    os.replace(tmp, LDTK)
    print("\nAPPLIED. The hook that BUILDS this changed too, so the .ldtk needs")
    print("touching or Godot will not re-read it:")
    print("  touch ldtk/hooshang_act1.ldtk")
    print("  rm .godot/imported/hooshang_act1.ldtk-* ldtk/levels/*.scn")
    print("  Godot --headless --path . --import")


if __name__ == "__main__":
    main()
