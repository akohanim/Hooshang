#!/usr/bin/env python3
"""Add the LightThought entity to LDtk: the pale twin of the DarkThought.

One entity definition and one 16px tileset over the pale sprite sheet. NO new
enum and no new fields — it reuses ThoughtMotion and carries the same five
fields, because it is the same hazard in a different colour.

WHY IT IS A SECOND ENTITY AT ALL, when the two tones are one prop, one script
and one set of fields on the Godot side. A `Tone` field would work and would be
one less thing here. It is two entities for the one reason the tones exist:
LDtk draws an entity as its icon, so two entities means you can SEE which one
you placed while laying out a room. A tone field would leave the level view
showing the same black cloud for both and the difference readable only by
clicking each one — which for a thing whose entire purpose is being visually
distinct is exactly backwards. Compare the note tiles and the spike strips,
split for the harder version of the same reason (there the mistake is silent).

BUILT FROM ldtk_add_dark_thought.py, NOT FROM A COPY OF IT. The fieldDef and
entityDef shapes in that file are the part that was difficult — every key
written including the ones that are null for the type, because LDtk reads the
file back and a missing key there is not a default but a null its form builder
walks into (that crashed the editor once already). Transcribing them again here
is a second chance to get one key wrong, so this imports them and passes the
handful of values that differ.

And then it checks that claim rather than trusting it: the entity this builds is
compared KEY BY KEY against the DarkThought definition already in the project —
which LDtk itself has opened, saved and round-tripped — and the only keys
allowed to differ are the ones naming this entity. See `mirrors`.

LDTK MUST BE CLOSED. It holds the whole project in memory and writes it back
wholesale, so a scripted edit made under a running LDtk is silently reverted.
This refuses to run rather than let that happen.

Idempotent: running it twice adds nothing the second time.

Usage:  python3 tools/ldtk_add_light_thought.py          # dry run
        python3 tools/ldtk_add_light_thought.py --apply
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
LDTK = os.path.join(ROOT, "ldtk", "hooshang_claude.ldtk")
APPLY = "--apply" in sys.argv

ENTITY = "LightThought"
TWIN = dt.ENTITY                 # DarkThought — the shape this is checked against
ART = "art/light_thought.png"
## Pale, so the two are told apart in the entity list at a glance the same way
## they are told apart in the room.
COLOR = "#E4E1F0"
DOC = ("A light thought: the same drifting cloud as a DarkThought, pale instead "
       "of black, with the same red rim. Identical in every other way — same "
       "path, same speed, same kill. The point you place is the CENTRE of the "
       "path. Not resizable: it is 16x16.")

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
    # else about them has to match, or the pale thought reads a different set of
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

    # The same five fields, in the same order, off the same builder the twin
    # used — only the uids are new.
    uid += 1
    fields = [dt.field_def("Motion",
                           "Which path it walks. Vertical and Horizontal swing "
                           "either side of the placed point; Circle orbits it.",
                           uid,
                           ("LocalEnum." + dt.ENUM,
                            "F_Enum(%d)" % enums[dt.ENUM]["uid"]),
                           {"id": "V_String", "params": [dt.MOTIONS[0]]})]
    for name, default, docstr in dt.FIELDS:
        uid += 1
        fields.append(dt.field_def(name, docstr, uid, ("Float", "F_Float"),
                                   {"id": "V_Float", "params": [default]}))
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
        print("      %-12s %-24s default %s"
              % (f["identifier"], f["__type"], f["defaultOverride"]["params"][0]))
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
    print("  touch ldtk/hooshang_claude.ldtk")
    print("  rm .godot/imported/hooshang_claude.ldtk-* ldtk/levels/*.scn")
    print("  Godot --headless --path . --import")


if __name__ == "__main__":
    main()
