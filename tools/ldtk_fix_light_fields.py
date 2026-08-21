#!/usr/bin/env python3
"""Rewrite CeilingPanel's and CeilingLight's fields so LDtk can open them.

The first version of these fieldDefs was written from the shape a String field
had, with the rest guessed: `canBeNull: true`, `defaultOverride: null`, `min: 0`,
and two field types — Color and Bool — that this project had never asked LDtk to
write. Clicking one of those entities crashed the editor in `createFieldInput`,
reading `.substr` of null.

This replaces them with fields that are structurally IDENTICAL to a Float field
LDtk itself wrote here (SlideZone's `angle`) — every key the same except the
identifier, the uid, the doc and the default. The tool ASSERTS that identity
rather than trusting the copy, so the next field added cannot drift back.

FLOAT ONLY. LDtk has written exactly two field types in this project, String and
Float; Color and Bool shapes would be guesses again, and a guess is what broke
the editor. So the colour knob stays where it already is — the prop's own
`light_color`, in the .tscn — and the flicker is a NUMBER: `FlickerAmount`, with
0 meaning steady. That reads as well as a checkbox and is one less invention.

NO NULLS EITHER. A field LDtk cannot leave empty always arrives with a value, so
"blank means leave the prop alone" is gone and every default written here has to
MATCH the prop's own — otherwise placing an entity silently retunes it. The tool
reads both .tscn files and the script's declared defaults and refuses to run if
any of the six disagree.

LDTK MUST BE CLOSED.

Usage:  python3 tools/ldtk_fix_light_fields.py          # dry run
        python3 tools/ldtk_fix_light_fields.py --apply
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
SCRIPT = os.path.join(ROOT, "scenes/props/lighting/ceiling_panel.gd")
SCENES = {
    "CeilingPanel": os.path.join(ROOT, "scenes/props/lighting/CeilingPanel.tscn"),
    "CeilingLight": os.path.join(ROOT, "scenes/props/lighting/CeilingLight.tscn"),
}
APPLY = "--apply" in sys.argv

## The Float field LDtk wrote in this project. Everything below is shaped to it.
REFERENCE = ("SlideZone", "angle")

## (LDtk field, the prop property it drives, doc).
FIELDS = [
    ("PanelOffset", "panel_offset",
     "WHICH cell of the run is the lit one, counted from the middle. 0 is the "
     "middle, -1 one cell left, +1 one right. Offset the lower of two stacked "
     "runs by 1 so their panels do not line up into vertical pairs."),
    ("PanelEnergy", "panel_energy",
     "How bright the FITTING itself looks — separate from the pool it throws."),
    ("PoolEnergy", "light_energy",
     "How bright the pool it throws is. This is how far the light carries; "
     "PanelEnergy is how bright the thing looks."),
    ("PoolScale", "light_scale",
     "Radius of that pool: 64px per 1.0. Mind the seam rule — a light does not "
     "stop at a room's edge (LIGHTING.md)."),
    ("PoolDrop", "pool_drop",
     "How far BELOW the fixture the pool is centred, in px."),
    ("FlickerAmount", "flicker_amount",
     "Fluorescent sputter: how deep the dip is, 0..1. 0 is a steady tube."),
    ("FlickerSpeed", "flicker_speed", "How fast that sputter runs."),
    ("MotionRange", "motion_range",
     "Motion sensor: how close he has to get before this fixture wakes up, in "
     "px. 0 keeps it simply ON, which is what every panel placed before this "
     "existed does. Measured to the POOL the fixture throws (PoolDrop below the "
     "panel), not to the panel in the ceiling — so it is a distance from the bit "
     "of floor this light lands on, not from the roof."),
    ("MotionFade", "motion_fade",
     "How long a sensored fixture takes to come up, and to go back down, in "
     "seconds. 0 snaps."),
]
## FlickerAmount does not take the prop's own default: LampFixture ships 0.18
## with `flickers` OFF, and 0.18 here would light every placed fixture with a
## stutter nobody asked for. 0 is the same thing the prop actually does.
STEADY = {"FlickerAmount": 0.0}

ENTITIES = list(SCENES)


def prop_defaults(name):
    """What the prop is actually tuned to: the scene's overrides over the
    script's declared defaults. Read rather than repeated, because a default
    written here that disagrees with the prop retunes every placed instance."""
    script = open(SCRIPT).read()
    values = {}
    for m in re.finditer(r"@export var (\w+)\s*:?=\s*([-\d.]+)", script):
        values[m.group(1)] = float(m.group(2))
    # LampFixture's, which CeilingPanel inherits.
    base = open(os.path.join(ROOT, "scenes/props/lighting/lamp_fixture.gd")).read()
    for m in re.finditer(r"@export var (\w+)\s*:?=\s*([-\d.]+)", base):
        values.setdefault(m.group(1), float(m.group(2)))
    for m in re.finditer(r"^(\w+) = ([-\d.]+)$", open(SCENES[name]).read(), re.M):
        values[m.group(1)] = float(m.group(2))
    return values


def field_def(identifier, doc, default, uid, ref):
    """A Float fieldDef, built FROM the reference so it cannot drift."""
    f = copy.deepcopy(ref)
    f["identifier"] = identifier
    f["doc"] = doc
    f["uid"] = uid
    f["defaultOverride"] = {"id": "V_Float", "params": [default]}
    return f


def assert_shaped_like(made, ref):
    """Every key but the four that are meant to differ must match the reference."""
    free = {"identifier", "doc", "uid", "defaultOverride"}
    if set(made) != set(ref):
        raise SystemExit("!! field %s has different KEYS from %s.%s"
                         % (made["identifier"], *REFERENCE))
    for k in made:
        if k in free:
            continue
        if made[k] != ref[k]:
            raise SystemExit("!! field %s differs at %r: %r vs the reference's %r"
                             % (made["identifier"], k, made[k], ref[k]))


def main():
    if ldtk_running():
        raise SystemExit("!! LDtk is open — close it first, or it will write "
                         "the project back over this edit.")
    raw = open(LDTK).read()
    doc = json.loads(raw)

    ref = None
    for e in doc["defs"]["entities"]:
        if e["identifier"] != REFERENCE[0]:
            continue
        for f in e["fieldDefs"]:
            if f["identifier"] == REFERENCE[1]:
                ref = f
    if ref is None:
        raise SystemExit("!! no %s.%s to copy the shape from" % REFERENCE)

    uid = max(int(u) for u in re.findall(r'"uid":\s*(\d+)', raw))
    out = raw
    for name in ENTITIES:
        tuned = prop_defaults(name)
        # KEEP THE UIDS OF FIELDS THAT ALREADY EXIST. Field instances point at a
        # defUid, so renumbering on every run would orphan every value anybody
        # had typed into LDtk — silently, since the field would simply come back
        # blank. Only genuinely new fields take a new number.
        existing = {f["identifier"]: f["uid"]
                    for e in doc["defs"]["entities"] if e["identifier"] == name
                    for f in e["fieldDefs"]}
        defs = []
        for ident, prop, text in FIELDS:
            if ident in STEADY:
                default = STEADY[ident]
            elif prop in tuned:
                default = tuned[prop]
            else:
                raise SystemExit("!! %s has no %s to take a default from"
                                 % (name, prop))
            if ident in existing:
                made = field_def(ident, text, default, existing[ident], ref)
            else:
                uid += 1
                made = field_def(ident, text, default, uid, ref)
            assert_shaped_like(made, ref)
            defs.append(made)
        print("  %s" % name)
        for d in defs:
            print("      %-14s default %s" % (d["identifier"],
                                              d["defaultOverride"]["params"][0]))

        b, e = object_span(out, out.index('"identifier": "%s"' % name))
        entity = out[b:e]
        i = entity.index('"fieldDefs"')
        j = array_end(entity, i)
        body = ",\n".join(block(d, 4) for d in defs)
        entity = entity[:entity.index("[", i) + 1] + "\n" + body + "\n\t\t\t" \
            + entity[j:]
        out = out[:b] + entity + out[e:]

    # Prove it: parse it back, and check nothing outside those fieldDefs moved.
    a, b = json.loads(raw), json.loads(out)
    for name in ENTITIES:
        eb = [x for x in b["defs"]["entities"] if x["identifier"] == name][0]
        if len(eb["fieldDefs"]) != len(FIELDS):
            raise SystemExit("!! %s came out with %d fields, wanted %d"
                             % (name, len(eb["fieldDefs"]), len(FIELDS)))
        for f in eb["fieldDefs"]:
            assert_shaped_like(f, ref)
    for d in (a, b):
        for e in d["defs"]["entities"]:
            if e["identifier"] in ENTITIES:
                e["fieldDefs"] = None
    if a != b:
        raise SystemExit("!! something outside those fieldDefs moved")

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
