#!/usr/bin/env python3
"""Reset Act_2_Level_0 back to a clean starting placeholder.

LDtk's own editor consolidated this session's separate showcase room into the
real starting room at some point (opened, auto-saved, and the two — which had
been accidentally placed at the exact same world position, a mistake in the
original showcase-room script — ended up merged under one name). This undoes
that: strips every entity except PlayerStart back out of Act_2_Level_0, and
resets its Collisions/ThoughtHazards paint to a plain flat floor (no step
block, no sludge patch — those belong to the showcase room, rebuilt fresh by a
SEPARATE run of tools/ldtk_add_act2_showcase_room.py right after this).

RUN AS A SEPARATE PROCESS FROM tools/ldtk_add_act2_showcase_room.py,
deliberately not imported — that script (like tools/ldtk_to_8px.py) runs its
whole main() unconditionally at module scope with no `__name__` guard, so
importing it here would execute its own file write using ITS OWN in-memory
copy of the project dict, racing this script's separate load/write and
silently losing whichever one wrote second. The handful of small helpers this
script needs (`_variants`, `_paint_generic`, `_rules_for`, `_auto_tiles`) are
copied in below instead, same call tools/gen_act2_cone_spikes.py's own
docstring already makes relative to gen_cone_spikes.py.

LDTK MUST BE CLOSED — see tools/ldtk_add_platforms.py for why.

Usage:  python3 tools/ldtk_reset_act2_level_0.py          # dry run
        python3 tools/ldtk_reset_act2_level_0.py --apply
"""
import json
import os
import subprocess
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
LDTK = os.path.join(ROOT, "ldtk", "hooshang_act2.ldtk")
APPLY = "--apply" in sys.argv

LEVEL_NAME = "Act_2_Level_0"
CW, CH = 40, 24
CELL = 8


def ldtk_running():
    try:
        out = subprocess.run(["ps", "ax", "-o", "command"],
                             capture_output=True, text=True).stdout
    except Exception:
        return False
    return any("LDtk.app/Contents/MacOS/LDtk" in line for line in out.splitlines())


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
    layer = next(l for l in d["defs"]["layers"] if l["identifier"] == layer_identifier)
    group = next(g for g in layer["autoRuleGroups"] if g.get("name") == group_name)
    return layer, [r for r in group["rules"] if r["active"]]


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


def main():
    if ldtk_running():
        raise SystemExit("!! LDtk is open — close it first, or it will write "
                         "the project back over this edit.")
    d = json.loads(open(LDTK).read())
    level = next((lv for lv in d["levels"] if lv["identifier"] == LEVEL_NAME), None)
    if level is None:
        raise SystemExit("!! %s not found" % LEVEL_NAME)

    entities_layer = next(ly for ly in level["layerInstances"]
                          if ly["__identifier"] == "Entities")
    before = [e["__identifier"] for e in entities_layer["entityInstances"]]
    kept = [e for e in entities_layer["entityInstances"]
           if e["__identifier"] == "PlayerStart"]
    removed = [e for e in before if e != "PlayerStart"]

    collisions_layer = next(ly for ly in level["layerInstances"]
                            if ly["__identifier"] == "Collisions")
    thought_layer = next(ly for ly in level["layerInstances"]
                         if ly["__identifier"] == "ThoughtHazards")

    floor_csv = [0] * (CW * CH)
    _rect(0, 20, CW - 1, CH - 1, floor_csv, CW, 2)
    _rect(0, 0, 0, CH - 1, floor_csv, CW, 2)
    _rect(CW - 1, 0, CW - 1, CH - 1, floor_csv, CW, 2)

    coll_layer_def, brick_rules = _rules_for(d, "Collisions", "brick")
    oob = brick_rules[0]["outOfBoundsValue"]
    coll_ts = next(t for t in d["defs"]["tilesets"]
                  if t["uid"] == coll_layer_def["tilesetDefUid"])
    floor_tiles = _auto_tiles(
        _paint_generic(brick_rules, floor_csv, CW, CH, oob, 2),
        CW, coll_ts["__cWid"])

    print("would remove %d non-PlayerStart entities from %s: %s"
          % (len(removed), LEVEL_NAME, removed))
    print("would reset Collisions to a plain floor (%d tiles) and clear "
          "ThoughtHazards" % len(floor_tiles))
    if not APPLY:
        print("\nDRY RUN — nothing written. Re-run with --apply")
        return

    entities_layer["entityInstances"] = kept
    collisions_layer["intGridCsv"] = floor_csv
    collisions_layer["autoLayerTiles"] = floor_tiles
    thought_layer["intGridCsv"] = [0] * (CW * CH)
    thought_layer["autoLayerTiles"] = []

    tmp = LDTK + ".tmp"
    with open(tmp, "w") as f:
        json.dump(d, f, indent="\t")
    os.replace(tmp, LDTK)
    print("APPLIED.")


if __name__ == "__main__":
    main()
