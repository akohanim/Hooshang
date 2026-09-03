#!/usr/bin/env python3
"""Add the `Glow` field to both thought entities.

One Float field on DarkThought and LightThought: 1 the halo is drawn, 0 it is
not. It exists because a room can only carry so much glow before the thoughts
in it stop reading as separate objects — and, when the halo was still a
PointLight2D, because this renderer drops any light past the sixteenth on an
item and the ones it drops are silent. The halo is paint now (see
scenes/props/hazards/dark_thought.gd) so it can no longer be culled, but being
able to turn it off is worth having on its own.

A FLOAT, NOT A CHECKBOX, the same call `Clockwise` makes and for the same
reason: LDtk has still only ever written String and Float fieldDefs into this
project, so those are the only two whose shape can be copied from something the
app itself produced. A Bool built from a guessed shape crashed the editor once.
1 is on, 0 is off, and anything above 0 counts as on.

UNSET MEANS ON. Every thought already placed predates this field and will have
no value for it until LDtk next saves the level. The import reads it with a
fallback of 1, so those keep their halo rather than quietly going dark — which
is the same rule every other field here follows.

THIS ONE EDITS EXISTING DEFINITIONS rather than appending new ones, which is
what makes it different from ldtk_add_dark_thought.py and ldtk_add_light_thought
.py. It finds each entity's `fieldDefs` array, bracket-matches to its end and
inserts there; it does NOT slice on guessed indentation. Then it parses both
versions and proves each of the two entities gained exactly this one field and
that nothing else in the project moved at all.

LDTK MUST BE CLOSED. It holds the whole project in memory and writes it back
wholesale, so a scripted edit made under a running LDtk is silently reverted.

Idempotent: running it twice adds nothing the second time.

Usage:  python3 tools/ldtk_add_thought_glow.py          # dry run
        python3 tools/ldtk_add_thought_glow.py --apply
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

ENTITIES = ["DarkThought", "LightThought"]
FIELD = "Glow"
DEFAULT = 1.0
DOC = ("1 draws the red halo around it, 0 leaves it bare. Off is for a thought "
       "meant to be found rather than seen coming, or for a cluster where "
       "several halos would merge into one red smear. Unset counts as on.")

## fieldDef objects sit four tabs in — `block` pads every line by that many.
DEPTH = 4


def inline_default(text):
    """Put `defaultOverride` back on one line, the way LDtk writes it.

    json.dumps expands every nested object, and LDtk keeps this one inline
    (`"defaultOverride": { "id": "V_Float", "params": [1] }`). Matching it means
    the next save from the app does not reformat this block — and a save whose
    diff is your own change all over again is exactly what a text-insertion tool
    exists to avoid.
    """
    return re.sub(
        r'"defaultOverride": \{\s*\n\s*"id": "(\w+)",\s*\n\s*"params": \[\s*\n'
        r'\s*([^\n]*?)\s*\n\s*\]\s*\n\s*\}',
        lambda m: '"defaultOverride": { "id": "%s", "params": [ %s ] }'
                  % (m.group(1), m.group(2)),
        text)


def array_end(text, start):
    """Index of the `]` closing the array whose `[` is at or after `start`."""
    i = text.index("[", start)
    depth = 0
    while i < len(text):
        if text[i] == "[":
            depth += 1
        elif text[i] == "]":
            depth -= 1
            if depth == 0:
                return i
        elif text[i] == '"':          # skip strings: docs contain brackets
            i += 1
            while text[i] != '"':
                i += 2 if text[i] == "\\" else 1
        i += 1
    raise SystemExit("!! unbalanced fieldDefs array")


def check(before, after, built):
    a, b = json.loads(before), json.loads(after)
    ea = {e["identifier"]: e for e in a["defs"]["entities"]}
    eb = {e["identifier"]: e for e in b["defs"]["entities"]}
    if set(ea) != set(eb):
        raise SystemExit("!! the set of entities changed")
    for name in ea:
        if name in ENTITIES:
            want = ea[name]["fieldDefs"] + [built[name]]
            if eb[name]["fieldDefs"] != want:
                raise SystemExit("!! %s's fields are not what was intended" % name)
            stripped_a = dict(ea[name]); stripped_b = dict(eb[name])
            stripped_a["fieldDefs"] = stripped_b["fieldDefs"] = None
            if stripped_a != stripped_b:
                raise SystemExit("!! something else about %s moved" % name)
        elif ea[name] != eb[name]:
            raise SystemExit("!! %s changed and should not have" % name)
    sa, sb = copy.deepcopy(a), copy.deepcopy(b)
    sa["defs"]["entities"] = sb["defs"]["entities"] = None
    if sa != sb:
        raise SystemExit("!! something outside the entity list moved")


def main():
    if ldtk_running():
        raise SystemExit("!! LDtk is open — close it first, or it will write "
                         "the project back over this edit.")
    raw = open(LDTK).read()
    doc = json.loads(raw)
    ents = {e["identifier"]: e for e in doc["defs"]["entities"]}

    todo = []
    for name in ENTITIES:
        if name not in ents:
            raise SystemExit("!! %s is not defined — run its add tool first" % name)
        if any(f["identifier"] == FIELD for f in ents[name]["fieldDefs"]):
            print("  %s already has %s — skipping" % (name, FIELD))
        else:
            todo.append(name)
    if not todo:
        print("\nnothing to add.")
        return

    uid = max(int(u) for u in re.findall(r'"uid":\s*(\d+)', raw))
    built = {}
    for name in todo:
        uid += 1
        built[name] = dt.field_def(FIELD, DOC, uid, ("Float", "F_Float"),
                                   {"id": "V_Float", "params": [DEFAULT]})
        print("  %-14s + %s  (Float, uid %d, default %g)"
              % (name, FIELD, uid, DEFAULT))

    # Back to front, so an earlier insert cannot move a later offset.
    out = raw
    for name in reversed(todo):
        marker = '"identifier": "%s",' % name
        at = out.index(marker)
        end = array_end(out, out.index('"fieldDefs": [', at))
        last = end - 1
        while out[last] in " \t\n":
            last -= 1
        if out[last] != "}":
            raise SystemExit("!! %s's fieldDefs does not end in an object" % name)
        text = inline_default(block(built[name], DEPTH))
        out = out[:last + 1] + ",\n" + text + out[last + 1:]

    check(raw, out, built)
    print("\nverified: %d field(s) added, and nothing else in the project moved"
          % len(todo))
    if not APPLY:
        print("\nDRY RUN — nothing written. Re-run with --apply")
        return
    tmp = LDTK + ".tmp"
    open(tmp, "w").write(out)
    os.replace(tmp, LDTK)
    print("\nAPPLIED. Re-import — the hook that READS this changed too, so the")
    print(".ldtk needs touching or Godot will not re-read it:")
    print("  touch ldtk/hooshang_act1.ldtk")
    print("  rm .godot/imported/hooshang_act1.ldtk-* ldtk/levels/*.scn")
    print("  Godot --headless --path . --import")


if __name__ == "__main__":
    main()
