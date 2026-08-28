#!/usr/bin/env python3
"""Add the Linear enum value and the Angle field to the LDtk project.

Two changes to the existing definitions:
  1. Append "Linear" to the ThoughtMotion enum's values list.
  2. Append an "Angle" Float field to every thought entity definition
     (DarkThought, LightThought — GreyThought is added by its own script
     AFTER this one and copies the updated definition).

WRITTEN AS TEXT, not as a JSON round-trip — same reason as ldtk_add_dark_thought.py:
json.dump reformats every compact array in the 1MB file and the diff is
unreviewable.

LDTK MUST BE CLOSED. It holds the whole project in memory and writes it back
wholesale, so a scripted edit is silently reverted.

Idempotent: running it twice adds nothing the second time.

Usage:  python3 tools/ldtk_add_linear_motion.py          # dry run
        python3 tools/ldtk_add_linear_motion.py --apply
"""
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

NEW_VALUE = "Linear"
ANGLE_NAME = "Angle"
ANGLE_DOC = ("Linear only: the direction of travel in degrees. 0 = right "
             "(+X), 90 = down (+Y). Vertical is Linear at 90, Horizontal "
             "is Linear at 0.")
ANGLE_DEFAULT = 0.0

## Entities that get the Angle field. GreyThought is not here because it is
## added AFTER this script runs and copies from the updated DarkThought.
THOUGHT_ENTITIES = ["DarkThought", "LightThought"]


def main():
    if ldtk_running():
        raise SystemExit("!! LDtk is open — close it first.")
    raw = open(LDTK).read()
    doc = json.loads(raw)

    enums = {e["identifier"]: e for e in doc["defs"]["enums"]}
    if dt.ENUM not in enums:
        raise SystemExit("!! %s enum not found" % dt.ENUM)

    existing_values = [v["id"] for v in enums[dt.ENUM]["values"]]
    changes = []
    out = raw

    # --- 1. Add Linear to the ThoughtMotion enum -----------------------------
    if NEW_VALUE in existing_values:
        print("  %s already has %s — skipping" % (dt.ENUM, NEW_VALUE))
    else:
        # The enum's values in the file look like:
        #   { "id": "Circle", "tileRect": null, "color": 16777215 }
        # followed by the rest of the enum object. Add a comma and the new
        # value after Circle.
        old = ('{ "id": "Circle", "tileRect": null, "color": %d }\n'
               '\t\t], "iconTilesetUid"' % dt.ENUM_COLOR)
        new = ('{ "id": "Circle", "tileRect": null, "color": %d },\n'
               '\t\t\t{ "id": "Linear", "tileRect": null, "color": %d }\n'
               '\t\t], "iconTilesetUid"' % (dt.ENUM_COLOR, dt.ENUM_COLOR))
        if old not in out:
            raise SystemExit("!! could not find the Circle enum value to "
                             "insert after — has the format changed?")
        out = out.replace(old, new, 1)
        changes.append("Linear enum value")
        print("  adding Linear to %s enum" % dt.ENUM)

    # --- 2. Add Angle field to each thought entity ---------------------------
    uid = max(int(u) for u in re.findall(r'"uid":\s*(\d+)', out))
    entities = {e["identifier"]: e for e in doc["defs"]["entities"]}

    for ent_name in THOUGHT_ENTITIES:
        if ent_name not in entities:
            print("  %s not found — skipping" % ent_name)
            continue
        ent = entities[ent_name]
        existing_fields = [f["identifier"] for f in ent["fieldDefs"]]
        if ANGLE_NAME in existing_fields:
            print("  %s already has %s — skipping" % (ent_name, ANGLE_NAME))
            continue

        uid += 1
        field = dt.field_def(ANGLE_NAME, ANGLE_DOC, uid, ("Float", "F_Float"),
                             {"id": "V_Float", "params": [ANGLE_DEFAULT]})

        # Find the entity's fieldDefs closing bracket. The last field ends with
        #     "tilesetUid": null\n\t\t\t\t}\n\t\t\t]\n
        # We find the entity by its uid and then search forward for this pattern.
        ent_uid_str = '"uid": %d,' % ent["uid"]
        ent_pos = out.index(ent_uid_str)
        # Find the fieldDefs closing ] after this entity's definition.
        # It's the first occurrence of \n\t\t\t]\n after the entity's fields.
        # The last field ends with "tilesetUid": null\n\t\t\t\t}
        # then \n\t\t\t] closes the fieldDefs array.
        #
        # Search for the pattern: "tilesetUid": null followed by closing braces
        # and the fieldDefs ]
        search_from = ent_pos
        # Find '"fieldDefs": [' after the entity start
        fd_start = out.index('"fieldDefs": [', search_from)
        # Find the matching ] — it's the first \n\t\t\t]\n after the last field.
        # The nesting depth is 4 tabs for field content, 3 tabs for the ] closing
        # fieldDefs, 2 tabs for the } closing the entity.
        #
        # Find the last field's closing } before the fieldDefs ]
        # The pattern is: \n\t\t\t\t}\n\t\t\t]\n
        last_field_close = out.find('\n\t\t\t\t}\n\t\t\t]', fd_start)
        if last_field_close < 0:
            raise SystemExit("!! could not find fieldDefs end for %s" % ent_name)

        # Insert after the } that closes the last field, before the ] that
        # closes fieldDefs.
        insert_at = last_field_close + len('\n\t\t\t\t}')
        field_text = ",\n" + block(field, 4)
        out = out[:insert_at] + field_text + out[insert_at:]

        changes.append("%s.Angle" % ent_name)
        print("  adding Angle field to %s (uid %d)" % (ent_name, uid))

    if not changes:
        print("\nNothing to add.")
        return

    # Verify the result is valid JSON and only the expected parts changed
    try:
        result = json.loads(out)
    except json.JSONDecodeError as e:
        raise SystemExit("!! result is not valid JSON: %s" % e)

    # The enum gained exactly Linear; each touched entity gained exactly one
    # Angle Float field; nothing else moved.
    b_enums = {e["identifier"]: e for e in result["defs"]["enums"]}
    assert [v["id"] for v in b_enums[dt.ENUM]["values"]] == \
        existing_values + [NEW_VALUE], "enum values not as intended"
    b_ents = {e["identifier"]: e for e in result["defs"]["entities"]}
    for ent_name in THOUGHT_ENTITIES:
        if ent_name not in entities:
            continue
        a_fields = entities[ent_name]["fieldDefs"]
        b_fields = b_ents[ent_name]["fieldDefs"]
        assert len(b_fields) == len(a_fields) + 1, \
            "%s field count wrong" % ent_name
        assert b_fields[:-1] == a_fields, "%s existing fields moved" % ent_name
        added = b_fields[-1]
        assert added["identifier"] == ANGLE_NAME and added["__type"] == "Float", \
            "%s new field is not Angle:Float" % ent_name
    # Everything OUTSIDE those enum values and entity fieldDefs is byte-equal.
    a_copy, b_copy = json.loads(raw), json.loads(out)
    for e in a_copy["defs"]["enums"]:
        if e["identifier"] == dt.ENUM:
            e["values"] = None
    for e in b_copy["defs"]["enums"]:
        if e["identifier"] == dt.ENUM:
            e["values"] = None
    for e in a_copy["defs"]["entities"] + b_copy["defs"]["entities"]:
        if e["identifier"] in THOUGHT_ENTITIES:
            e["fieldDefs"] = None
    assert a_copy == b_copy, "!! something outside the intended edits moved"

    print("\nverified: only Linear + Angle added, nothing else touched")
    print("Changes: %s" % ", ".join(changes))
    if not APPLY:
        print("\nDRY RUN — nothing written. Re-run with --apply")
        return
    tmp = LDTK + ".tmp"
    with open(tmp, "w") as f:
        f.write(out)
    os.replace(tmp, LDTK)
    print("\nAPPLIED. Re-import after running ldtk_add_grey_thought.py too:")
    print("  touch ldtk/hooshang_claude.ldtk")
    print("  rm .godot/imported/hooshang_claude.ldtk-* ldtk/levels/*.scn")
    print("  Godot --headless --path . --import")


if __name__ == "__main__":
    main()
