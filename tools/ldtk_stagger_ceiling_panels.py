#!/usr/bin/env python3
"""Stagger the ceiling panels: each row's panels sit one column off the row above.

The `ceiling_flor` value laid a panel every third column on EVERY row, so a
two-row ceiling came out with its panels stacked in the same columns — a grid of
vertical pairs rather than a ceiling. This replaces its one panel rule with two,
split on row parity:

    even rows   panel where (col - 1) % 3 == 0
    odd rows    panel where (col - 2) % 3 == 0     — one column to the right

plus the plain cell everywhere neither claims. Order matters and is preserved:
the two panel rules come first and break on match, so the plain rule only ever
sees the cells they did not take.

THE MODULO SEMANTICS ARE MEASURED, NOT ASSUMED. LDtk applies a rule where
`(coord - offset) % modulo == 0`, which was read back off the panels LDtk itself
had already generated in rooms 0 and 1: every one of them sits at `col % 3 == 1`
against the existing rule's `xOffset` of 1. Guessing this wrong puts the panels
in the wrong columns, which is the kind of thing that looks like a taste
decision rather than a bug.

IT ALSO REPAINTS WHAT IS ALREADY PAINTED. LDtk stores its auto-layer OUTPUT in
the project file and only re-evaluates when you edit a layer, so a rule changed
from outside the app leaves every existing room drawn the old way until someone
touches it. This recomputes the ceiling tiles for every level from the same
formula. Brick tiles are left exactly as they are — only entries drawn from the
ceiling tiles are replaced.

LDTK MUST BE CLOSED. It holds the whole project in memory and writes it back
wholesale, so a scripted edit made under a running LDtk is silently reverted.

Idempotent: running it twice changes nothing the second time.

Usage:  python3 tools/ldtk_stagger_ceiling_panels.py          # dry run
        python3 tools/ldtk_stagger_ceiling_panels.py --apply
"""
import copy
import json
import os
import subprocess
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
LDTK = os.path.join(ROOT, "ldtk", "hooshang_claude.ldtk")
APPLY = "--apply" in sys.argv

LAYER = "Collisions"
GROUP = "ceiling_flor"
VALUE = 3
TILE_PLAIN, TILE_PANEL = 4, 5
## Tiles across the sheet, for turning a tile id into its pixel source.
SHEET_CWID = 6
CELL = 8

## A panel every Nth column, and the phase each row parity uses. The two differ
## by one, which is the whole point.
EVERY = 3
PHASE_EVEN_ROWS = 1
PHASE_ODD_ROWS = 2


def ldtk_running():
    """Matched on the executable path, not the full command line: a
    full-command-line scan matches the shell running this very script, because
    the script's own source contains the string it is looking for."""
    out = subprocess.run(["ps", "ax", "-o", "comm="],
                         capture_output=True, text=True).stdout
    return any(l.strip().endswith("/LDtk") or l.strip() == "LDtk"
               for l in out.splitlines())


def rule(uid, tile, x_modulo, x_offset, y_modulo, y_offset):
    """One auto-layer rule. Every field the format carries is written out rather
    than left to a default, because LDtk reads this back and a missing key there
    is not a default — it is a crash or a quietly different rule."""
    return {
        "uid": uid, "active": True, "size": 1,
        "tileRectsIds": [[tile]],
        "alpha": 1, "chance": 1, "breakOnMatch": True,
        "pattern": [VALUE],
        "flipX": False, "flipY": False,
        "xModulo": x_modulo, "yModulo": y_modulo,
        "xOffset": x_offset, "yOffset": y_offset,
        "tileXOffset": 0, "tileYOffset": 0,
        "tileRandomXMin": 0, "tileRandomXMax": 0,
        "tileRandomYMin": 0, "tileRandomYMax": 0,
        "checker": "None", "tileMode": "Single",
        "pivotX": 0, "pivotY": 0,
        # These patterns are one cell, so there is no neighbour to be out of
        # bounds — unlike the brick rules, whose 3x3 patterns set this to 2.
        "outOfBoundsValue": None,
        "invalidated": False,
        "perlinActive": False, "perlinSeed": 4367591,
        "perlinScale": 0.2, "perlinOctaves": 2,
    }


def tile_for(cx, cy):
    """Which ceiling tile a painted cell gets — the rules, in Python."""
    if cy % 2 == 0 and (cx - PHASE_EVEN_ROWS) % EVERY == 0:
        return TILE_PANEL
    if cy % 2 == 1 and (cx - PHASE_ODD_ROWS) % EVERY == 0:
        return TILE_PANEL
    return TILE_PLAIN


def repaint(doc, rule_uids):
    """Redraw every level's ceiling from the new rules. Returns (levels, tiles)."""
    levels = tiles = 0
    for lv in doc["levels"]:
        for li in lv["layerInstances"]:
            if li["__identifier"] != LAYER:
                continue
            cw = li["__cWid"]
            painted = [i for i, v in enumerate(li["intGridCsv"]) if v == VALUE]
            if not painted:
                continue
            kept = [t for t in li["autoLayerTiles"] if t["t"] < TILE_PLAIN]
            fresh = []
            for coord in painted:
                cx, cy = coord % cw, coord // cw
                tile = tile_for(cx, cy)
                fresh.append({
                    "px": [cx * CELL, cy * CELL],
                    "src": [(tile % SHEET_CWID) * CELL, (tile // SHEET_CWID) * CELL],
                    "f": 0, "t": tile,
                    "d": [rule_uids[tile], coord], "a": 1,
                })
            li["autoLayerTiles"] = kept + fresh
            levels += 1
            tiles += len(fresh)
    return levels, tiles


def main():
    if ldtk_running():
        raise SystemExit("!! LDtk is open — close it first, or it will write "
                         "the project back over this edit.")
    raw = open(LDTK).read()
    doc = json.loads(raw)

    layer = [l for l in doc["defs"]["layers"] if l["identifier"] == LAYER][0]
    group = next((g for g in layer["autoRuleGroups"] if g["name"] == GROUP), None)
    if group is None:
        raise SystemExit("!! no %s rule group — run tools/ldtk_add_ceiling_tile.py"
                         % GROUP)
    if len(group["rules"]) == 3:
        print("  %s already has its three rules — nothing to do" % GROUP)
        return

    # Reuse the uids that are there and take one more, so a rule the user has
    # since clicked on in LDtk keeps its identity where it can.
    uids = [r["uid"] for r in group["rules"]]
    uids.append(max(int(r["uid"]) for g in layer["autoRuleGroups"]
                    for r in g["rules"]) + 1)
    group["rules"] = [
        rule(uids[0], TILE_PANEL, EVERY, PHASE_EVEN_ROWS, 2, 0),
        rule(uids[2], TILE_PANEL, EVERY, PHASE_ODD_ROWS, 2, 1),
        rule(uids[1], TILE_PLAIN, 1, 0, 1, 0),
    ]
    by_tile = {TILE_PANEL: uids[0], TILE_PLAIN: uids[1]}

    before = json.loads(raw)
    levels, tiles = repaint(doc, by_tile)

    # Report what actually moved, per row, so this is checkable by eye.
    for name in ("Level_0", "Level_1"):
        lv = next((l for l in doc["levels"] if l["identifier"] == name), None)
        if lv is None:
            continue
        li = [x for x in lv["layerInstances"] if x["__identifier"] == LAYER][0]
        rows = {}
        for t in li["autoLayerTiles"]:
            if t["t"] == TILE_PANEL:
                rows.setdefault(t["px"][1] // CELL, []).append(t["px"][0] // CELL)
        for cy in sorted(rows):
            print("  %-8s row %2d  panels at cols %s"
                  % (name, cy, sorted(rows[cy])[:8]))

    # Nothing outside the rules and the ceiling tiles may move.
    a, b = copy.deepcopy(before), copy.deepcopy(doc)
    for doc_ in (a, b):
        lay = [l for l in doc_["defs"]["layers"] if l["identifier"] == LAYER][0]
        for g in lay["autoRuleGroups"]:
            if g["name"] == GROUP:
                g["rules"] = None
        for lv in doc_["levels"]:
            for li in lv["layerInstances"]:
                if li["__identifier"] == LAYER:
                    li["autoLayerTiles"] = [t for t in li["autoLayerTiles"]
                                            if t["t"] < TILE_PLAIN]
    if a != b:
        raise SystemExit("!! something outside the ceiling rules and tiles moved")

    print("\n  repainted %d tiles across %d levels" % (tiles, levels))
    if not APPLY:
        print("DRY RUN — nothing written. Re-run with --apply")
        return
    tmp = LDTK + ".tmp"
    with open(tmp, "w") as f:
        json.dump(doc, f, indent="\t")
    os.replace(tmp, LDTK)
    print("APPLIED. Re-import in Godot:")
    print("  rm .godot/imported/hooshang_claude.ldtk-* ldtk/levels/Level_*.scn")
    print("  Godot --headless --path . --import")


if __name__ == "__main__":
    main()
