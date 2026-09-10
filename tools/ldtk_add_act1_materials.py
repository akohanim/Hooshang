#!/usr/bin/env python3
"""Add `scaffolding` and `concrete` to the Collisions layer, so they can be
PAINTED as new wall materials alongside `brick`.

Not new layers: two more IntGrid values on the SAME `Collisions` layer (uid 23)
brick already lives on, each with the exact same four-rule shape brick uses
(fill / top edge / left edge / top-left corner, with flipX/flipY covering the
other three edges and corners for free) -- see tools/gen_bricks_8px.py's module
doc for why an LDtk auto-layer can only ever have one tileset, which is why
these tiles have to live on the brick sheet rather than a dedicated one.

WHAT THIS TOUCHES, all of it on the `Collisions` layer:

  the tileset   `bricks_8px.png` grows from 14 tiles to 22 -- 4 each for
                scaffolding and concrete, drawn by tools/gen_bricks_8px.py
                straight from tools/build_material_lab.py's own tile_art(),
                the procedural generator (and PALETTES) that already produced
                ldtk/material_lab/art/{scaffolding,concrete}.png. Run that
                script first if the sheet is not already 22 tiles wide.
  two values    5 `scaffolding`, 6 `concrete`, alongside 2 `brick`.
  two groups    four rules each, structurally identical to the `brick` group
                (uid 26) -- corner (flipX+flipY), top (flipY), left (flipX),
                fill -- just re-pointed at the new value and tile ids.

Collision comes for free, the same way it does for every other tile on this
sheet: scripts/ldtk_tileset_post_import.gd gives every tile in every source a
full square on every import.

ALSO CLEARS `cachedPixelData` on the Bricks8px tileset def. LDtk caches a
per-tile opacity/colour thumbnail there, sized to the tile count it last saw
-- growing __cWid/pxWid alone leaves it sized for the OLD count, and LDtk's
OWN editor then renders every tile past that as blank/hollow in both the
value palette and the level view, even though the JSON is structurally
correct and the art is really on disk. This shipped once: the first run of
this script left the cache at 14 tiles, and scaffolding/concrete's swatches
came back empty in LDtk despite `check()` passing clean. Null it out, same as
build_material_lab.py already does for a brand-new tileset, so LDtk
recomputes it fresh next time the project opens.

EDITED AS TEXT, not as parsed JSON re-dumped -- hooshang_act1.ldtk is a 2MB
tab-indented file; a json.dump round trip reformats every line and buries this
change in an unreviewable diff. Same technique as ldtk_add_ceiling_tile.py,
whose object_span/array_end/block/ldtk_running helpers this reuses directly.

LDTK MUST BE CLOSED. It holds the whole project in memory and writes it back
wholesale, so a scripted edit made under a running LDtk is silently reverted.

Idempotent: running it twice adds nothing the second time.

Usage:  python3 tools/ldtk_add_act1_materials.py          # dry run
        python3 tools/ldtk_add_act1_materials.py --apply
"""
import copy
import json
import os
import re
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from ldtk_add_ceiling_tile import array_end, block, ldtk_running, object_span

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
LDTK = os.path.join(ROOT, "ldtk", "hooshang_act1.ldtk")
APPLY = "--apply" in sys.argv

LAYER = "Collisions"
TILESET = "Bricks8px"
## Sheet size before/after tools/gen_bricks_8px.py appends this run's four-tile
## groups. Read straight off the sheet on disk (asserted in main()) rather
## than trusted blindly, since this constant is tied to exactly which
## MATERIALS entries are already applied -- update BOTH together.
OLD_CWID, OLD_PXWID = 22, 176
NEW_CWID, NEW_PXWID = 26, 208

## (IntGrid value, identifier, editor swatch color, base tile id). Base tile id
## is where this material's own fill/top/left/corner four start on the sheet --
## see tools/gen_bricks_8px.py's module doc for the exact column layout. Color
## is that material's own PALETTES[...][3] from build_material_lab.py (the
## same index scaffolding/concrete already used), so the editor swatch matches
## the actual generated art rather than a hand-picked approximation.
MATERIALS = [
    (5, "scaffolding", "#8097A5", 14),
    (6, "concrete", "#969F9B", 18),
    # material_lab's own generated Brick material -- a second, richer `brick`
    # option. Named `brick_new`, not `brick`: the existing value 2 `brick` is
    # this project's original hand-drawn masonry (tiles 0-3) and stays exactly
    # as it is, per the "keep existing materials as-is, only add new ones"
    # scope this whole script was written under.
    (7, "brick_new", "#A67A70", 22),
]


def rule(uid, tile, pattern, flip_x, flip_y, out_of_bounds, seed):
    """One auto-layer rule, fields written out in full -- LDtk reads this file
    back and a missing key is not a default there, it is a crash or a silently
    different rule. Shape copied verbatim from the `brick` group's own rules."""
    return {
        "uid": uid, "active": True, "size": 3 if len(pattern) == 9 else 1,
        "tileRectsIds": [[tile]],
        "alpha": 1, "chance": 1, "breakOnMatch": True,
        "pattern": pattern,
        "flipX": flip_x, "flipY": flip_y,
        "xModulo": 1, "yModulo": 1, "xOffset": 0, "yOffset": 0,
        "tileXOffset": 0, "tileYOffset": 0,
        "tileRandomXMin": 0, "tileRandomXMax": 0,
        "tileRandomYMin": 0, "tileRandomYMax": 0,
        "checker": "None", "tileMode": "Single",
        "pivotX": 0, "pivotY": 0,
        "outOfBoundsValue": out_of_bounds,
        "invalidated": False,
        "perlinActive": False, "perlinSeed": seed,
        "perlinScale": 0.2, "perlinOctaves": 2,
    }


def make_group(uid, name, value, base_tile, rule_uids):
    """Four rules, same shape as the `brick` group (uid 26): corner/top/left
    each flip to cover their opposite edges/corners for free, fill catches
    whatever is left. `value` is also this material's own outOfBoundsValue --
    matching brick's own convention that past a room's edge counts AS the
    material, so an edge cell never draws a "top" tile facing the void."""
    fill, top, left, corner = base_tile, base_tile + 1, base_tile + 2, base_tile + 3
    v = value
    rules = [
        rule(rule_uids[0], corner, [0, -v, 0, -v, v, 0, 0, 0, 0], True, True, v, 7000000 + uid),
        rule(rule_uids[1], top, [0, -v, 0, 0, v, 0, 0, 0, 0], False, True, v, 7000001 + uid),
        rule(rule_uids[2], left, [0, 0, 0, -v, v, 0, 0, 0, 0], True, False, v, 7000002 + uid),
        rule(rule_uids[3], fill, [v], False, False, v, 7000003 + uid),
    ]
    return {
        "uid": uid, "name": name, "color": None, "icon": None,
        "active": True, "isOptional": False,
        "rules": rules,
        "usesWizard": True,
        "requiredBiomeValues": [], "biomeRequirementMode": 0,
    }


def check(before, after, values, groups):
    """Prove the edit added exactly these values/groups and moved nothing else."""
    a, b = json.loads(before), json.loads(after)

    def layer(doc):
        return next(l for l in doc["defs"]["layers"] if l["identifier"] == LAYER)

    def tileset(doc):
        return next(t for t in doc["defs"]["tilesets"] if t["identifier"] == TILESET)

    if layer(b)["intGridValues"] != layer(a)["intGridValues"] + values:
        raise SystemExit("!! the IntGrid values are not what was intended")
    if layer(b)["autoRuleGroups"] != layer(a)["autoRuleGroups"] + groups:
        raise SystemExit("!! the rule groups are not what was intended")
    if (tileset(b)["__cWid"], tileset(b)["pxWid"]) != (NEW_CWID, NEW_PXWID):
        raise SystemExit("!! the tileset did not grow to %d tiles" % NEW_CWID)
    if tileset(b)["cachedPixelData"] is not None:
        raise SystemExit("!! cachedPixelData was not cleared — LDtk will keep "
                         "showing the new tiles as blank")

    sa, sb = copy.deepcopy(a), copy.deepcopy(b)
    for doc in (sa, sb):
        lv = next(l for l in doc["defs"]["layers"] if l["identifier"] == LAYER)
        lv["intGridValues"] = lv["autoRuleGroups"] = None
        ts = next(t for t in doc["defs"]["tilesets"] if t["identifier"] == TILESET)
        ts["__cWid"] = ts["pxWid"] = ts["cachedPixelData"] = None
    if sa != sb:
        raise SystemExit("!! something outside the layer and its tileset moved")


def main():
    if ldtk_running():
        raise SystemExit("!! LDtk is open — close it first, or it will write "
                         "the project back over this edit.")
    raw = open(LDTK).read()

    doc = json.loads(raw)
    layer_def = next(l for l in doc["defs"]["layers"] if l["identifier"] == LAYER)
    existing = {v["identifier"] for v in layer_def["intGridValues"]}
    todo = [m for m in MATERIALS if m[1] not in existing]
    for _value, name, _color, _base_tile in MATERIALS:
        if name in existing:
            print("  %s already defined — skipping" % name)
    if not todo:
        print("\nnothing to add.")
        return

    sheet = os.path.join(ROOT, "ldtk", "art", "bricks_8px.png")
    from PIL import Image
    w = Image.open(sheet).size[0]
    if w != NEW_PXWID:
        raise SystemExit("!! ldtk/art/bricks_8px.png is %dpx wide, expected %d — "
                         "run tools/gen_bricks_8px.py first" % (w, NEW_PXWID))

    uid = max(int(u) for u in re.findall(r'"uid":\s*(\d+)', raw))
    values, groups = [], []
    for value, name, color, base_tile in todo:
        uid += 1
        group_uid = uid
        rule_uids = [uid + 1 + i for i in range(4)]
        uid += 4
        values.append({"value": value, "identifier": name, "color": color,
                       "tile": None, "groupUid": 0})
        groups.append(make_group(group_uid, name, value, base_tile, rule_uids))

    out = raw

    # --- the tileset grows by eight tiles -----------------------------------
    ts_b, ts_e = object_span(out, out.index('"identifier": "%s"' % TILESET))
    ts = out[ts_b:ts_e]
    for key, old, new in (("__cWid", OLD_CWID, NEW_CWID),
                          ("pxWid", OLD_PXWID, NEW_PXWID)):
        needle = '"%s": %d' % (key, old)
        if ts.count(needle) != 1:
            raise SystemExit("!! expected one %s in %s, found %d"
                             % (needle, TILESET, ts.count(needle)))
        ts = ts.replace(needle, '"%s": %d' % (key, new))
    # LDtk caches a per-tile opacity/colour thumbnail (`cachedPixelData`) sized
    # to the tile count it last saw. Growing __cWid/pxWid alone leaves that
    # cache at the OLD tile count, so LDtk's own editor renders every tile past
    # the old count as blank/hollow in the value palette and the level view --
    # even though the JSON is structurally correct and the art is really
    # there. Null it out, the same way build_material_lab.py does for a
    # brand-new tileset, so LDtk recomputes it fresh from the actual image on
    # next open. (Discovered because this is exactly what happened here.)
    cache_start = ts.index('"cachedPixelData":')
    after_colon = ts[cache_start + len('"cachedPixelData":'):].lstrip()
    if after_colon.startswith("{"):
        obj_start = ts.index('{', cache_start)
        depth, i = 0, obj_start
        while True:
            if ts[i] == '{':
                depth += 1
            elif ts[i] == '}':
                depth -= 1
                if depth == 0:
                    break
            i += 1
        ts = ts[:cache_start] + '"cachedPixelData": null' + ts[i + 1:]
    out = out[:ts_b] + ts + out[ts_e:]

    # --- the values and rule groups, both on Collisions ---------------------
    lb, le = object_span(out, out.index('"identifier": "%s"' % LAYER))
    layer = out[lb:le]
    i = array_end(layer, layer.index('"intGridValues"'))
    layer = (layer[:i] + ",\n"
             + ",\n".join(block(v, 4) for v in values) + "\n\t\t\t" + layer[i:])
    j = array_end(layer, layer.index('"autoRuleGroups"'))
    layer = (layer[:j] + ",\n"
             + ",\n".join(block(g, 4) for g in groups) + "\n\t\t\t" + layer[j:])
    out = out[:lb] + layer + out[le:]

    check(raw, out, values, groups)
    print("verified: %d IntGrid values and %d rule groups added, nothing else touched"
          % (len(values), len(groups)))
    for value, name, color, base_tile in todo:
        print("  value %d  %-12s tiles %d-%d" % (value, name, base_tile, base_tile + 3))
    print("  tileset %s  %d -> %d tiles" % (TILESET, OLD_CWID, NEW_CWID))

    if not APPLY:
        print("\nDRY RUN — nothing written. Re-run with --apply")
        return
    tmp = LDTK + ".tmp"
    open(tmp, "w").write(out)
    os.replace(tmp, LDTK)
    print("\nAPPLIED. Re-import in Godot:")
    print("  rm .godot/imported/hooshang_act1.ldtk-* ldtk/levels/Level_*.scn")
    print("  Godot --headless --path . --import")


if __name__ == "__main__":
    main()
