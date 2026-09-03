#!/usr/bin/env python3
"""One-shot: create ldtk/hooshang_act3.ldtk, mirroring exactly how
hooshang_act2.ldtk was built (see CLAUDE.md's Act 3 note) — copy Act 1's
project wholesale (every entity/layer/tileset def becomes shared scaffolding,
Act 3 gets its own art later, the same way Act 2 did), then trim `levels`
down to a single minimal starter room.

Act1_Level_25 is the donor level: same 320x192 (40x24 @ 8px) shape every
ordinary room uses, and the FEWEST entities (3) of any Act1 room, so
stripping it down to just PlayerStart throws away the least. Its Collisions
IntGrid is then reset to a plain floor-and-side-walls shell and re-tiled with
Act 1's own "brick" auto-rule group — copied wholesale, not reinvented,
because inventing a second copy of that rule set would drift from Act 1's the
moment either one is edited. ThoughtHazards/Foreground/Background/Collision
are cleared the same way tools/ldtk_reset_act2_level_0.py clears them for
Act 2's own starter room.

The room name is Act3_Level_0 — NOT "Level_0". The LDtk importer writes every
project's rooms into the SAME shared res://ldtk/levels/ folder keyed only by
identifier, so a bare "Level_0" would silently overwrite Act 1's real
Level_0 on import (this already happened once between Act 1 and Act 2 with a
stray "Level_1" — see the Act3World section of CLAUDE.md). Every future Act 3
room must keep the Act3_ prefix for the same reason.

LDTK MUST BE CLOSED — see tools/ldtk_add_platforms.py for why.

Usage: python3 tools/create_act3_project.py          # dry run
       python3 tools/create_act3_project.py --apply
"""
import copy
import json
import os
import subprocess
import sys
import uuid

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(ROOT, "ldtk", "hooshang_act1.ldtk")
DST = os.path.join(ROOT, "ldtk", "hooshang_act3.ldtk")
APPLY = "--apply" in sys.argv

DONOR_LEVEL = "Level_25"
NEW_LEVEL = "Act3_Level_0"
CW, CH = 40, 24
CELL = 8


def ldtk_running():
    try:
        out = subprocess.run(["ps", "ax", "-o", "command"],
                              capture_output=True, text=True).stdout
    except Exception:
        return False
    return any("LDtk.app/Contents/MacOS/LDtk" in line for line in out.splitlines())


# --- same small auto-tiling helpers as ldtk_reset_act2_level_0.py ----------

def _variants(rule):
    n, p = rule["size"], rule["pattern"]
    combos = [(0, 0)]
    if rule["flipX"]:
        combos.append((1, 0))
    if rule["flipY"]:
        combos.append((0, 1))
    if rule["flipX"] and rule["flipY"]:
        combos.append((1, 1))
    out = []
    for fx, fy in combos:
        pat = []
        for y in range(n):
            for x in range(n):
                sx = n - 1 - x if fx else x
                sy = n - 1 - y if fy else y
                pat.append(p[sy * n + sx])
        out.append((fx | (fy << 1), pat))
    return out


def _paint_generic(rules, csv, w, h, oob, target):
    def val(x, y):
        return csv[y * w + x] if (0 <= x < w and 0 <= y < h) else oob

    out = {}
    for y in range(h):
        for x in range(w):
            if csv[y * w + x] != target:
                continue
            hit = None
            for rule in rules:
                n = rule["size"]
                rad = n // 2
                for flip, pat in _variants(rule):
                    ok = True
                    for py in range(n):
                        for px in range(n):
                            want = pat[py * n + px]
                            if want == 0:
                                continue
                            got = val(x + px - rad, y + py - rad)
                            if (want > 0 and got != want) or (want < 0 and got == -want):
                                ok = False
                                break
                        if not ok:
                            break
                    if ok:
                        hit = (rule["uid"], rule["tileRectsIds"][0][0], flip)
                        break
                if hit:
                    break
            if hit:
                out[y * w + x] = hit
    return out


def _rules_for(d, layer_identifier, group_name):
    """The Collisions layer carries TWO autoRuleGroups both named "brick" —
    one is an empty leftover. Match on non-empty `rules`, not name alone, or
    this silently picks the dead one (checked directly: the first "brick"
    group in hooshang_act1.ldtk has zero rules)."""
    layer = next(l for l in d["defs"]["layers"] if l["identifier"] == layer_identifier)
    for group in layer["autoRuleGroups"]:
        if group.get("name") == group_name and group["rules"]:
            return layer, [r for r in group["rules"] if r["active"]]
    raise SystemExit("!! no non-empty '%s' rule group on %s" % (group_name, layer_identifier))


def _auto_tiles(painted, w, tileset_cwid):
    tiles = []
    for coord, (rule_uid, tile, flip) in sorted(painted.items()):
        cx, cy = coord % w, coord // w
        tiles.append({
            "px": [cx * CELL, cy * CELL],
            "src": [(tile % tileset_cwid) * CELL, (tile // tileset_cwid) * CELL],
            "f": flip, "t": tile, "d": [rule_uid, coord], "a": 1,
        })
    return tiles


def _rect(x0, y0, x1, y1, csv, w, value):
    for y in range(y0, y1 + 1):
        for x in range(x0, x1 + 1):
            csv[y * w + x] = value


def _max_uid(node, best):
    if isinstance(node, dict):
        v = node.get("uid")
        if isinstance(v, int) and v > best[0]:
            best[0] = v
        for val in node.values():
            _max_uid(val, best)
    elif isinstance(node, list):
        for item in node:
            _max_uid(item, best)


def main():
    if ldtk_running():
        raise SystemExit("!! LDtk is open — close it first, or it will write "
                          "the project back over this file the next time it saves.")
    if os.path.exists(DST) and not APPLY:
        print("(hooshang_act3.ldtk already exists — dry run will still show "
              "what a fresh --apply would write)")

    d = json.loads(open(SRC).read())

    donor = next((lv for lv in d["levels"] if lv["identifier"] == DONOR_LEVEL), None)
    if donor is None:
        raise SystemExit("!! donor level %s not found in %s" % (DONOR_LEVEL, SRC))
    level = copy.deepcopy(donor)

    best = [0]
    _max_uid(d, best)
    new_uid = best[0] + 1

    level["identifier"] = NEW_LEVEL
    level["iid"] = str(uuid.uuid4())
    level["uid"] = new_uid
    level["worldX"] = 0
    level["worldY"] = 0
    level["worldDepth"] = 0

    layers = {ly["__identifier"]: ly for ly in level["layerInstances"]}

    # Entities: strip everything except a fresh PlayerStart, same shape LDtk
    # gives one (see any existing PlayerStart instance for the field layout).
    ents = layers["Entities"]
    old_start = next((e for e in ents["entityInstances"]
                       if e["__identifier"] == "PlayerStart"), None)
    if old_start is None:
        raise SystemExit("!! donor level has no PlayerStart to model the new one on")
    start = copy.deepcopy(old_start)
    start["iid"] = str(uuid.uuid4())
    start["px"] = [24, 128]
    start["__grid"] = [start["px"][0] // CELL, start["px"][1] // CELL]
    for fi in start.get("fieldInstances", []):
        if fi["__identifier"] == "SpawnID":
            fi["__value"] = "start"
            fi["__tile"] = None
    ents["entityInstances"] = [start]
    ents["iid"] = str(uuid.uuid4())

    # Collisions: a plain floor + side walls, same shell
    # ldtk_reset_act2_level_0.py builds for Act 2's own starter room —
    # walkable, but nothing painted in the middle for a future room to
    # design around.
    coll = layers["Collisions"]
    floor_csv = [0] * (CW * CH)
    _rect(0, 20, CW - 1, CH - 1, floor_csv, CW, 2)
    _rect(0, 0, 0, CH - 1, floor_csv, CW, 2)
    _rect(CW - 1, 0, CW - 1, CH - 1, floor_csv, CW, 2)
    _, brick_rules = _rules_for(d, "Collisions", "brick")
    oob = brick_rules[0]["outOfBoundsValue"]
    coll_ts = next(t for t in d["defs"]["tilesets"] if t["uid"] == coll["__tilesetDefUid"])
    coll["intGridCsv"] = floor_csv
    coll["autoLayerTiles"] = _auto_tiles(
        _paint_generic(brick_rules, floor_csv, CW, CH, oob, 2), CW, coll_ts["__cWid"])
    coll["iid"] = str(uuid.uuid4())

    # Everything else: cleared, same as a fresh Act 2 starter room.
    for name in ("Foreground", "Background", "Collision"):
        ly = layers[name]
        ly["autoLayerTiles"] = []
        if "intGridCsv" in ly:
            ly["intGridCsv"] = [0] * (CW * CH)
        ly["iid"] = str(uuid.uuid4())
    thought = layers["ThoughtHazards"]
    thought["intGridCsv"] = [0] * (CW * CH)
    thought["autoLayerTiles"] = []
    thought["iid"] = str(uuid.uuid4())

    for ly in level["layerInstances"]:
        ly["levelId"] = new_uid

    d["iid"] = str(uuid.uuid4())
    d["levels"] = [level]
    d["nextUid"] = new_uid + 1

    print("would write %s: 1 level (%s), %d Collisions tiles, PlayerStart at %s"
          % (os.path.basename(DST), NEW_LEVEL, len(coll["autoLayerTiles"]), start["px"]))
    if not APPLY:
        print("\nDRY RUN — nothing written. Re-run with --apply")
        return

    tmp = DST + ".tmp"
    with open(tmp, "w") as f:
        json.dump(d, f, indent="\t")
    os.replace(tmp, DST)
    print("APPLIED — wrote", DST)


if __name__ == "__main__":
    main()
