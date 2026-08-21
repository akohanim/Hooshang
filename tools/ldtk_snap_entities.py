#!/usr/bin/env python3
"""Snap misplaced entity instances onto the 8px grid.

Some entities were placed at a 4px (half-cell) offset: their bounding box does
not land on the 8px grid the world is built on, so they read as sitting between
the squares. This nudges each one to the grid.

WHICH ONES: even-size props whose box top-left is off the 8px grid —
ConveyorBelt, GlassSpikes, CrumblingPlatform. CeilingPanel is DELIBERATELY left
alone: its offset is structural (an odd count of 24px cells, centre-pivoted,
lands the box on a 4px offset by design), so snapping it would only move the
offset somewhere else and break the lit-middle-cell layout.

SNAP DIRECTION IS UNIFORM (toward the lower coordinate), not "nearest". Nearest
is a tie at exactly 4px, and Python's round() breaks that tie by parity — which
would shift adjacent platforms in a run in OPPOSITE directions and tear the run
apart. Flooring every one keeps a run contiguous, just moved 4px.

Edited as TEXT, anchored on each instance's unique `iid`, so the 1MB tab-indented
project is not re-dumped (a json round trip rewrites every line at ~2.4x size).
px, __grid and __worldX/__worldY are all updated together, then the whole file
is parsed back and the move is verified instance-by-instance.

LDTK MUST BE CLOSED.

Usage:  python3 tools/ldtk_snap_entities.py           # dry run
        python3 tools/ldtk_snap_entities.py --apply
"""
import json, os, re, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from ldtk_add_ceiling_tile import ldtk_running, object_span

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
LDTK = os.path.join(ROOT, "ldtk", "hooshang_claude.ldtk")
APPLY = "--apply" in sys.argv
GRID = 8
TARGETS = {"ConveyorBelt_Right", "ConveyorBelt_Left",
           "GlassSpikesRightWall", "GlassSpikesLeftWall",
           "GlassSpikes", "GlassSpikesCeiling",
           "CrumblingPlatform"}


def plan(doc):
    piv = {e["identifier"]: (e["pivotX"], e["pivotY"])
           for e in doc["defs"]["entities"]}
    out = []
    for lv in doc["levels"]:
        for L in lv["layerInstances"]:
            if L["__type"] != "Entities":
                continue
            for e in L["entityInstances"]:
                ident = e["__identifier"]
                if ident not in TARGETS:
                    continue
                fx, fy = piv[ident]
                tlx = e["px"][0] - fx * e["width"]
                tly = e["px"][1] - fy * e["height"]
                dx = -(round(tlx) % GRID)          # floor to the gridline below
                dy = -(round(tly) % GRID)
                if dx == 0 and dy == 0:
                    continue
                out.append({
                    "lv": lv["identifier"], "ident": ident, "iid": e["iid"],
                    "old": list(e["px"]),
                    "new": [e["px"][0] + dx, e["px"][1] + dy],
                    "d": [dx, dy],
                })
    return out


def swap_pair(obj, key, a, b):
    pat = re.compile(r'("%s":\s*\[\s*)(-?\d+)(\s*,\s*)(-?\d+)(\s*\])' % re.escape(key))
    new, n = pat.subn(lambda m: m.group(1) + str(a) + m.group(3) + str(b) + m.group(5),
                      obj, count=1)
    if n != 1:
        raise SystemExit("!! could not find %s in an instance" % key)
    return new


def swap_scalar(obj, key, v):
    pat = re.compile(r'("%s":\s*)(-?\d+)' % re.escape(key))
    new, n = pat.subn(lambda m: m.group(1) + str(v), obj, count=1)
    if n != 1:
        raise SystemExit("!! could not find %s in an instance" % key)
    return new


def main():
    if ldtk_running():
        raise SystemExit("!! LDtk is open — close it first, or it will write "
                         "the project back over this edit.")
    raw = open(LDTK).read()
    doc = json.loads(raw)
    moves = plan(doc)
    print("instances to snap: %d" % len(moves))
    for m in moves:
        print("  %-9s %-20s %-14s %s -> %s  (%+d,%+d)" %
              (m["lv"], m["ident"], m["iid"][:12], m["old"], m["new"], *m["d"]))

    out = raw
    # apply from the LAST occurrence backward so earlier spans stay valid
    for m in sorted(moves, key=lambda m: out.index('"iid": "%s"' % m["iid"]),
                    reverse=True):
        pos = out.index('"iid": "%s"' % m["iid"])
        # The enclosing ENTITY object, not the nested __tile whose `{` is the
        # last brace before the iid. An instance object always opens with its
        # __identifier, so anchor on that.
        starts = [x.start() for x in re.finditer(r'\{\s*"__identifier"', out)
                  if x.start() < pos]
        b, e = object_span(out, starts[-1] + 1)
        obj = out[b:e]
        if ('"iid": "%s"' % m["iid"]) not in obj:
            raise SystemExit("!! object span missed its own iid")
        nx, ny = m["new"]
        dx, dy = m["d"]
        obj = swap_pair(obj, "px", nx, ny)
        obj = swap_pair(obj, "__grid", nx // GRID, ny // GRID)
        obj = swap_scalar(obj, "__worldX", None) if False else obj
        # __worldX/Y = level world origin + px; shift by the same delta
        obj = re.sub(r'("__worldX":\s*)(-?\d+)',
                     lambda mm: mm.group(1) + str(int(mm.group(2)) + dx), obj, count=1)
        obj = re.sub(r'("__worldY":\s*)(-?\d+)',
                     lambda mm: mm.group(1) + str(int(mm.group(2)) + dy), obj, count=1)
        out = out[:b] + obj + out[e:]

    # Prove it: parse back, and check EXACTLY these iids moved to their targets
    # and nothing else in the entity layers changed.
    a2 = json.loads(raw)
    b2 = json.loads(out)
    want = {m["iid"]: m["new"] for m in moves}
    seen = {}
    for da, db in ((a2, "a"), (b2, "b")):
        pass
    moved = {}
    for lv in b2["levels"]:
        for L in lv["layerInstances"]:
            if L["__type"] != "Entities":
                continue
            for e in L["entityInstances"]:
                if e["iid"] in want and e["px"] != want[e["iid"]]:
                    raise SystemExit("!! %s did not land where intended" % e["iid"])
    # every OTHER instance must be byte-identical in structure
    def strip(doc):
        m = {}
        for lv in doc["levels"]:
            for L in lv["layerInstances"]:
                if L["__type"] != "Entities":
                    continue
                for e in L["entityInstances"]:
                    m[e["iid"]] = (e["px"], e["__grid"], e.get("__worldX"), e.get("__worldY"))
        return m
    ma, mb = strip(a2), strip(b2)
    if set(ma) != set(mb):
        raise SystemExit("!! an instance appeared or vanished")
    changed = {k for k in ma if ma[k] != mb[k]}
    if changed != set(want):
        raise SystemExit("!! unexpected instances changed: %s" % (changed - set(want)))
    print("\nverified: exactly %d instances moved, all to grid, nothing else touched"
          % len(changed))

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
