#!/usr/bin/env python3
"""Finish converting `brick` (IntGrid value 2) to the new materials on the
`Collisions` layer, across every level in Act 1 that still has plain brick.

NOT a flat swap. Levels 0-6 were hand-converted directly in LDtk already, and
inspecting them (ASCII-rendering their intGridCsv) shows the same split every
time: the room's own WALL/FLOOR/CEILING BOUNDARY became `brick_new`, while
FREESTANDING INTERIOR platforms and steps (the shapes that don't touch the
room's outer edge) became a second material instead -- `stone` in Level_1
(its interior staircase is 100% stone), a mix of stone/scaffolding/concrete
in Level_2-5. Per the user's own call: replicate the WALL/PLATFORM split, but
with a single consistent second material -- every freestanding interior
platform becomes `stone` (value 8), matching Level_1 exactly, rather than
guessing which of stone/scaffolding/concrete each individual shape "should"
be (that part of 0-6 was a hand-picked artistic choice, not a derivable
rule).

THE SPLIT RULE: flood-fill 4-connected components of brick(2) cells per
level. A component touching the room's outer edge (x=0, x=w-1, y=0, or
y=h-1) is a WALL -> brick_new (7). A component that never touches the edge
is a freestanding PLATFORM -> stone (8). Checked against Level_1 itself
before writing this: its interior staircase blob does not touch the level's
actual edge rows/columns (the near-edge row that looked border-adjacent by
eye was not literally row 0/h-1), confirming border-touching is the real
rule Level_1's hand conversion follows.

EDITED AS TEXT, preserving the ORIGINAL array's exact line-wrapping: rather
than regenerating the whole intGridCsv array, every individual number token
is found in original document order (regex over the array's own span, which
holds nothing but integers) and only the tokens whose value actually changes
are replaced in place, right to left so earlier offsets stay valid. Every
untouched token -- including brick cells in levels not touched by this pass,
and every OTHER IntGrid value already in the array -- keeps its original
bytes exactly.

VERIFIED AGAINST A PURE-JSON EXPECTATION: the expected new intGridCsv for
every level is computed directly from the flood-fill in Python (no text
involved), and the text-edited-and-reparsed document must equal that exactly
-- not just spot-checked fields.

Only the `Collisions` layer is touched. The similarly-named singular
`Collision` layer (Solid/OneWay/Hazard/UnderworldTrigger) is unrelated and
never matched.

`autoLayerTiles` (the pre-baked tile art Godot's importer reads verbatim,
addons/ldtk-importer/src/layer.gd:151) is NOT touched here -- brick_new and
stone are both full Corners/Edges/Infill/Interior rule systems now, not the
original 4-tile brick shape, and getting that hand-matched to LDtk's own
topology decisions is exactly what LDtk itself already does correctly (0-6
were converted BY HAND in LDtk, not scripted). After applying: reopen this
project in LDtk and press Save once to rebuild every repainted room's
auto-tiles, the same step every other scripted content change in this
project already relies on. Until that save, repainted rooms will still SHOW
old brick art in Godot even though the data underneath is already correct --
expected, not a bug.

LDTK MUST BE CLOSED for the edit itself.

Idempotent: running it twice changes nothing the second time (no more brick
cells left to classify).

Usage:  python3 tools/ldtk_replace_brick_with_brick_new.py          # dry run
        python3 tools/ldtk_replace_brick_with_brick_new.py --apply
"""
import json
import os
import re
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from ldtk_add_ceiling_tile import array_end, ldtk_running, object_span

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
LDTK = os.path.join(ROOT, "ldtk", "hooshang_act1.ldtk")
APPLY = "--apply" in sys.argv

LAYER = "Collisions"
BRICK, WALL_VALUE, PLATFORM_VALUE = 2, 7, 8
NUMBER_RE = re.compile(r"-?\d+")


def split_brick(w, h, csv):
    """New intGridCsv: every brick(2) cell becomes WALL_VALUE if its 4-connected
    component touches the room's outer edge, else PLATFORM_VALUE."""
    new_csv = list(csv)
    seen = [False] * (w * h)
    for sy in range(h):
        for sx in range(w):
            i0 = sy * w + sx
            if csv[i0] != BRICK or seen[i0]:
                continue
            stack = [(sx, sy)]
            seen[i0] = True
            cells = [(sx, sy)]
            touches_edge = sx == 0 or sy == 0 or sx == w - 1 or sy == h - 1
            while stack:
                x, y = stack.pop()
                for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                    nx, ny = x + dx, y + dy
                    if 0 <= nx < w and 0 <= ny < h:
                        j = ny * w + nx
                        if csv[j] == BRICK and not seen[j]:
                            seen[j] = True
                            cells.append((nx, ny))
                            stack.append((nx, ny))
                            if nx == 0 or ny == 0 or nx == w - 1 or ny == h - 1:
                                touches_edge = True
            value = WALL_VALUE if touches_edge else PLATFORM_VALUE
            for x, y in cells:
                new_csv[y * w + x] = value
    return new_csv


def main():
    if ldtk_running():
        raise SystemExit("!! LDtk is open — close it first, or it will write "
                         "the project back over this edit.")
    raw = open(LDTK).read()
    doc = json.loads(raw)

    out = raw
    per_level = {}
    for lvl in doc["levels"]:
        coll = next(li for li in lvl["layerInstances"] if li["__identifier"] == LAYER)
        old_csv = coll["intGridCsv"]
        if BRICK not in old_csv:
            continue
        w, h = coll["__cWid"], coll["__cHei"]
        new_csv = split_brick(w, h, old_csv)
        walls = sum(1 for a, b in zip(old_csv, new_csv) if a == BRICK and b == WALL_VALUE)
        platforms = sum(1 for a, b in zip(old_csv, new_csv) if a == BRICK and b == PLATFORM_VALUE)
        per_level[lvl["identifier"]] = (walls, platforms)

        lvl_pos = out.index('"iid": "%s"' % lvl["iid"])
        lvl_b, lvl_e = object_span(out, lvl_pos)
        coll_pos = out.index('"__identifier": "%s"' % LAYER, lvl_b, lvl_e)
        clb, cle = object_span(out, coll_pos)

        csv_key = out.index('"intGridCsv"', clb, cle)
        arr_start = out.index("[", csv_key)
        arr_end = array_end(out, csv_key)
        segment = out[arr_start:arr_end + 1]

        matches = list(NUMBER_RE.finditer(segment))
        if len(matches) != len(old_csv):
            raise SystemExit("!! %s: found %d numbers in intGridCsv text, "
                             "expected %d" % (lvl["identifier"], len(matches), len(old_csv)))
        new_segment = segment
        for i in range(len(matches) - 1, -1, -1):
            if new_csv[i] == old_csv[i]:
                continue
            m = matches[i]
            new_segment = new_segment[:m.start()] + str(new_csv[i]) + new_segment[m.end():]
        out = out[:arr_start] + new_segment + out[arr_end + 1:]

    if not per_level:
        print("nothing to convert.")
        return

    for name, (walls, platforms) in per_level.items():
        print("  %-14s wall/floor -> brick_new: %-5d  platform -> stone: %-5d"
              % (name, walls, platforms))
    total_walls = sum(w for w, _ in per_level.values())
    total_platforms = sum(p for _, p in per_level.values())
    print("\n  %d levels, %d cells -> brick_new, %d cells -> stone"
          % (len(per_level), total_walls, total_platforms))

    expected = json.loads(raw)
    for lvl in expected["levels"]:
        coll = next(li for li in lvl["layerInstances"] if li["__identifier"] == LAYER)
        if BRICK in coll["intGridCsv"]:
            coll["intGridCsv"] = split_brick(coll["__cWid"], coll["__cHei"], coll["intGridCsv"])

    actual = json.loads(out)
    if actual != expected:
        raise SystemExit("!! the edited document does not match the expected "
                         "pure-JSON result — nothing written")
    print("\nverified: edited document matches the pure-JSON expected result exactly")

    if not APPLY:
        print("\nDRY RUN — nothing written. Re-run with --apply")
        return
    tmp = LDTK + ".tmp"
    open(tmp, "w").write(out)
    os.replace(tmp, LDTK)
    print("\nAPPLIED.")
    print("Next: open hooshang_act1.ldtk in LDtk and press Save once, so LDtk")
    print("rebuilds every repainted room's auto-tiles from its own rule engine")
    print("(the same step that already produced Level_0-6's brick_new/stone art).")
    print("Then, with LDtk closed again:")
    print("  rm .godot/imported/hooshang_act1.ldtk-* ldtk/levels/hooshang_act1/Level_*.scn")
    print("  Godot --headless --path . --import")


if __name__ == "__main__":
    main()
