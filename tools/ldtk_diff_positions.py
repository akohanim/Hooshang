#!/usr/bin/env python3
"""A readable diff of every LDtk entity's position, against git HEAD (or any
ref) — the tool this project needed the day a PlayerStart drifted 8px inside
an editing session and nobody noticed.

WHY THIS EXISTS. `git diff` on hooshang_act1.ldtk is close to useless for
catching an accidental nudge: LDtk reformats large stretches of the file on
every save (key ordering, float precision, list rewraps), so even a real
2-pixel drift on one entity shows up buried inside an 800+ line diff of a 1MB
file — which is exactly how a PlayerStart ended up moved by a full grid cell
and sat there unnoticed through a commit. This tool ignores everything except
entity `px`/`__grid`, and prints ONLY what actually moved, was added, or was
removed — a two-line report instead of a haystack.

THE MOST LIKELY CAUSE of an accidental single-cell drift is LDtk's own arrow
key nudge: a selected entity moves one grid cell per keypress, and it is easy
to hit while panning/placing something else nearby with an entity still
selected. This tool does not prevent that keystroke — nothing running outside
LDtk can — it just makes the result impossible to miss before it gets
committed.

Usage:
    python3 tools/ldtk_diff_positions.py                 # working tree vs HEAD
    python3 tools/ldtk_diff_positions.py --against HEAD~3 # vs any git ref
    python3 tools/ldtk_diff_positions.py --check          # same, exit 1 if
                                                            # anything moved
                                                            # or was removed
                                                            # (for a hook)
"""
import argparse
import json
import subprocess
import sys
import os

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
LDTK_REL = "ldtk/hooshang_act1.ldtk"
LDTK = os.path.join(ROOT, LDTK_REL)


def load_ref(ref):
    """The .ldtk as it existed at a git ref."""
    raw = subprocess.check_output(["git", "show", "%s:%s" % (ref, LDTK_REL)],
                                   cwd=ROOT)
    return json.loads(raw)


def load_working_tree():
    return json.load(open(LDTK))


def entities(doc):
    """iid -> (level identifier, entity identifier, px tuple)."""
    out = {}
    for lvl in doc["levels"]:
        for layer in lvl.get("layerInstances") or []:
            if layer["__identifier"] != "Entities":
                continue
            for e in layer["entityInstances"]:
                out[e["iid"]] = (lvl["identifier"], e["__identifier"],
                                  tuple(e["px"]))
    return out


def levels(doc):
    """level iid -> (identifier, (worldX, worldY)).

    THIS IS A DIFFERENT KIND OF MOVE than an entity drifting, and worth
    tracking separately: entity `px` is level-RELATIVE, so dragging a whole
    room in LDtk's World view (or an intentional world-layout change) never
    shows up as an entity move at all — every entity inside still reads the
    same px it always did. Only the level's own worldX/worldY catches it.
    """
    return {lvl["iid"]: (lvl["identifier"], (lvl["worldX"], lvl["worldY"]))
            for lvl in doc["levels"]}


def main():
    ap = argparse.ArgumentParser(description=__doc__,
        formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--against", default="HEAD",
        help="git ref to compare the working tree against (default: HEAD)")
    ap.add_argument("--check", action="store_true",
        help="exit 1 if anything moved or was removed (for a hook/CI use)")
    args = ap.parse_args()

    old_doc, new_doc = load_ref(args.against), load_working_tree()

    old_lvl, new_lvl = levels(old_doc), levels(new_doc)
    levels_moved = []
    for iid, (ident, pos) in new_lvl.items():
        if iid in old_lvl and old_lvl[iid][1] != pos:
            old_pos = old_lvl[iid][1]
            levels_moved.append((ident, old_pos, pos,
                (pos[0] - old_pos[0], pos[1] - old_pos[1])))
    if levels_moved:
        print("LEVELS MOVED (%d) — worldX/worldY, not an entity nudge:"
              % len(levels_moved))
        for ident, old_pos, pos, delta in sorted(levels_moved):
            print("  %-16s %s -> %s   (%+d, %+d)"
                  % (ident, old_pos, pos, delta[0], delta[1]))
        print()

    old = entities(old_doc)
    new = entities(new_doc)

    moved, added, removed = [], [], []
    for iid, (lvl, ident, px) in new.items():
        if iid not in old:
            added.append((lvl, ident, px))
            continue
        _, _, old_px = old[iid]
        if old_px != px:
            moved.append((lvl, ident, old_px, px))
    for iid, (lvl, ident, px) in old.items():
        if iid not in new:
            removed.append((lvl, ident, px))

    if not (levels_moved or moved or added or removed):
        print("no level or entity position changes vs %s" % args.against)
        return

    if moved:
        print("MOVED (%d):" % len(moved))
        for lvl, ident, old_px, px in sorted(moved):
            dx, dy = px[0] - old_px[0], px[1] - old_px[1]
            print("  %-16s %-14s %s -> %s   (%+d, %+d)"
                  % (lvl, ident, old_px, px, dx, dy))
    if removed:
        print("REMOVED (%d):" % len(removed))
        for lvl, ident, px in sorted(removed):
            print("  %-16s %-14s was at %s" % (lvl, ident, px))
    if added:
        print("added (%d, informational — new placements are expected):"
              % len(added))
        for lvl, ident, px in sorted(added):
            print("  %-16s %-14s at %s" % (lvl, ident, px))

    if args.check and (levels_moved or moved or removed):
        sys.exit(1)


if __name__ == "__main__":
    main()
