#!/usr/bin/env python3
"""Add a small showcase room to hooshang_act2.ldtk: the new tileset painted in,
and one of each new entity — SpringPlatform, MagicCarpet (RIDE + BOB), all
four Keys, JamshidCage, childhood-palette DarkThought/LightThought/GreyThought,
childhood-palette ConeSpikes, and a patch of the reskinned ThoughtHazards
paint. NOT part of real progression — clearly named Act_2_Level_Showcase, a
before-wiring-anything-real visual check, the same job tests/room_shot.tscn's
own doc describes it for.

THE AUTO-LAYER TILES ARE COMPUTED HERE, not left for LDtk to fill in later —
same reasoning tools/ldtk_to_8px.py's header gives: the Godot importer reads
`autoLayerTiles` straight out of the .ldtk (addons/ldtk-importer/src/layer.gd
reads layer_data.autoLayerTiles directly, it does not re-derive tiles from
intGridCsv + the rule defs), so a painted IntGrid with an empty
`autoLayerTiles` array would import as an EMPTY floor. `paint()` and
`_variants()` are imported from ldtk_to_8px.py rather than re-derived —
that evaluator was checked byte-identical against LDtk's own output on all
1893 tiles of the real world before it was trusted, and duplicating a rule
matcher is exactly the kind of thing that quietly drifts from what LDtk itself
does. `paint()` is written for the Collisions layer's own IntGrid value (2,
"brick") specifically; `_paint_generic()` below is the same algorithm
parameterised for the ThoughtHazards layer's "thought" value (1).

LDTK MUST BE CLOSED — see tools/ldtk_add_platforms.py for why.

Usage:  python3 tools/ldtk_add_act2_showcase_room.py          # dry run
        python3 tools/ldtk_add_act2_showcase_room.py --apply
"""
import json
import os
import re
import subprocess
import sys
import uuid

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
LDTK = os.path.join(ROOT, "ldtk", "hooshang_act2.ldtk")
APPLY = "--apply" in sys.argv

LEVEL_NAME = "Act_2_Level_Showcase"
CW, CH = 40, 24  # cells — the project's standard room size
CELL = 8


def ldtk_running():
    try:
        out = subprocess.run(["ps", "ax", "-o", "command"],
                             capture_output=True, text=True).stdout
    except Exception:
        return False
    return any("LDtk.app/Contents/MacOS/LDtk" in line for line in out.splitlines())


def _variants(rule):
    """(flip_bits, pattern) for each mirror the rule is allowed to match in —
    copied verbatim from tools/ldtk_to_8px.py's own _variants(), NOT imported:
    that file runs its whole one-shot migration at module scope on import (no
    __name__ guard) and errors when re-run against an already-migrated
    project. Duplicating this one small, already-verified pure function is
    safer than fighting that side effect."""
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
    """paint(), from ldtk_to_8px.py, parameterised for any IntGrid value —
    that file hardcodes 2 ("brick"); ThoughtHazards' own value is 1."""
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
    """Fill an inclusive cell rectangle in a flat IntGrid csv."""
    for y in range(y0, y1 + 1):
        for x in range(x0, x1 + 1):
            csv[y * w + x] = value


def _field(identifier, type_str, value, def_uid):
    return {"__identifier": identifier, "__type": type_str, "__value": value,
            "__tile": None, "defUid": def_uid, "realEditorValues": []}


def _entity(identifier, def_uid, center_px, size, fields=None, pivot=(0.5, 0.5)):
    px = [int(center_px[0] - size[0] * pivot[0]), int(center_px[1] - size[1] * pivot[1])]
    return {
        "__identifier": identifier, "__grid": [px[0] // CELL, px[1] // CELL],
        "__pivot": list(pivot), "__tags": [], "__tile": None,
        "__smartColor": "#FFFFFF", "iid": str(uuid.uuid4()),
        "width": size[0], "height": size[1], "defUid": def_uid, "px": px,
        "fieldInstances": fields or [], "__worldX": px[0], "__worldY": px[1],
    }


def main():
    if ldtk_running():
        raise SystemExit("!! LDtk is open — close it first, or it will write "
                         "the project back over this edit.")
    d = json.loads(open(LDTK).read())

    if any(lv["identifier"] == LEVEL_NAME for lv in d["levels"]):
        print("  %s already exists — skipping" % LEVEL_NAME)
        return

    raw = json.dumps(d)
    uid = max(int(u) for u in re.findall(r'"uid":\s*(\d+)', raw))

    entity_defs = {e["identifier"]: e for e in d["defs"]["entities"]}
    field_defs = {e["identifier"]: {f["identifier"]: f["uid"] for f in e["fieldDefs"]}
                 for e in d["defs"]["entities"]}

    # ---- paint the floor + a step block, in Act 2's own new tileset --------
    collisions_csv = [0] * (CW * CH)
    _rect(0, 20, CW - 1, CH - 1, collisions_csv, CW, 2)   # floor, rows 20-23
    _rect(0, 0, 0, CH - 1, collisions_csv, CW, 2)          # left wall
    _rect(CW - 1, 0, CW - 1, CH - 1, collisions_csv, CW, 2)  # right wall
    _rect(30, 17, 33, 19, collisions_csv, CW, 2)           # a standalone step block
    # Leave a gap in the floor under the step block's row so ConeSpikes (row
    # 20 near x 25-27) sits on bare floor rather than under the raised block.
    # And leave a gap where the ThoughtHazards patch goes (cols 8-10, row 20)
    # — painted brick there would sit ON TOP of the sludge tiles in the same
    # cells and hide them completely, which is exactly what a first capture
    # of this room showed happening.
    _rect(8, 20, 10, 20, collisions_csv, CW, 0)

    coll_layer_def, brick_rules = _rules_for(d, "Collisions", "brick")
    oob = brick_rules[0]["outOfBoundsValue"]
    coll_ts = next(t for t in d["defs"]["tilesets"] if t["uid"] == coll_layer_def["tilesetDefUid"])
    coll_tiles = _auto_tiles(_paint_generic(brick_rules, collisions_csv, CW, CH, oob, 2),
                             CW, coll_ts["__cWid"])

    # ---- a patch of the reskinned "sludge" paint ---------------------------
    thought_csv = [0] * (CW * CH)
    _rect(8, 20, 10, 20, thought_csv, CW, 1)
    thought_layer_def, thought_rules = _rules_for(d, "ThoughtHazards", "thought")
    thought_oob = thought_rules[0]["outOfBoundsValue"]
    thought_ts = next(t for t in d["defs"]["tilesets"] if t["uid"] == thought_layer_def["tilesetDefUid"])
    thought_tiles = _auto_tiles(
        _paint_generic(thought_rules, thought_csv, CW, CH, thought_oob, 1),
        CW, thought_ts["__cWid"])

    # ---- entities -----------------------------------------------------------
    entities = []

    def f(entity_name, field_name, type_str, value):
        return _field(field_name, type_str, value, field_defs[entity_name][field_name])

    entities.append(_entity("PlayerStart", entity_defs["PlayerStart"]["uid"],
        (24, 128), (16, 16), pivot=(0, 0)))

    entities.append(_entity("SpringPlatform", entity_defs["SpringPlatform"]["uid"],
        (64, 144), (24, 8)))

    entities.append(_entity("MagicCarpet", entity_defs["MagicCarpet"]["uid"],
        (120, 128), (32, 8), fields=[
            f("MagicCarpet", "CarpetPattern", "LocalEnum.CarpetPattern", "Ride"),
            f("MagicCarpet", "Speed", "Float", 30.0),
            f("MagicCarpet", "Amplitude", "Float", 20.0),
            f("MagicCarpet", "SteerRange", "Float", 20.0),
        ]))
    entities.append(_entity("MagicCarpet", entity_defs["MagicCarpet"]["uid"],
        (200, 104), (24, 8), fields=[
            f("MagicCarpet", "CarpetPattern", "LocalEnum.CarpetPattern", "Bob"),
            f("MagicCarpet", "Speed", "Float", 0.0),
            f("MagicCarpet", "Amplitude", "Float", 16.0),
            f("MagicCarpet", "SteerRange", "Float", 20.0),
        ]))

    for i, cx in enumerate([40, 96, 152, 208]):
        entities.append(_entity("Key", entity_defs["Key"]["uid"],
            (cx, 80 - i * 10), (10, 14), fields=[
                f("Key", "KeyID", "String", str(i + 1)),
            ]))

    entities.append(_entity("JamshidCage", entity_defs["JamshidCage"]["uid"],
        (280, 148), (16, 24)))

    for name, cx, cy in [("DarkThought", 50, 60), ("LightThought", 150, 50),
                         ("GreyThought", 250, 60)]:
        entities.append(_entity(name, entity_defs[name]["uid"], (cx, cy), (16, 16), fields=[
            f(name, "Motion", "LocalEnum.ThoughtMotion", "Vertical"),
            f(name, "Amplitude", "Float", 10.0),
            f(name, "Speed", "Float", 0.4),
            f(name, "Phase", "Float", 0.0),
            f(name, "Clockwise", "Float", 1.0),
            f(name, "Glow", "Float", 1.0),
            f(name, "Angle", "Float", 0.0),
            f(name, "ChildhoodPalette", "Float", 1.0),
        ]))

    entities.append(_entity("ConeSpikes", entity_defs["ConeSpikes"]["uid"],
        (212, 164), (24, 8), fields=[
            f("ConeSpikes", "ChildhoodPalette", "Float", 1.0),
        ]))

    # ---- assemble the level --------------------------------------------------
    def layer_instance(identifier, is_intgrid, csv=None, auto_tiles=None):
        # A real LDtk save gives EVERY layer instance the full uniform key
        # set below regardless of type — confirmed by reading Act2_Level_0's
        # own layers, all six of which carry entityInstances/gridTiles/
        # overrideTilesetUid/autoLayerTiles/intGridCsv, just empty where not
        # applicable. Godot's importer reads several of these unconditionally
        # (tileset.gd reads layer.overrideTilesetUid off every layer, not
        # just Entities ones), so a layer instance built with only the keys
        # that looked relevant is missing ones the importer still expects.
        base = next(l for l in d["defs"]["layers"] if l["identifier"] == identifier)
        inst = {
            "__identifier": identifier, "__type": base["type"],
            "__cWid": CW, "__cHei": CH, "__gridSize": CELL, "__opacity": 1,
            "__pxTotalOffsetX": 0, "__pxTotalOffsetY": 0,
            "__tilesetDefUid": base.get("tilesetDefUid"),
            "__tilesetRelPath": None, "iid": str(uuid.uuid4()),
            "levelId": 0, "layerDefUid": base["uid"],
            "pxOffsetX": 0, "pxOffsetY": 0, "visible": True,
            "optionalRules": [], "intGridCsv": csv or [], "seed": 1,
            "overrideTilesetUid": None, "gridTiles": [],
            "autoLayerTiles": auto_tiles or [],
            "entityInstances": entities if identifier == "Entities" else [],
        }
        if base.get("tilesetDefUid") is not None:
            ts = next(t for t in d["defs"]["tilesets"] if t["uid"] == base["tilesetDefUid"])
            inst["__tilesetRelPath"] = ts["relPath"]
        return inst

    uid += 1
    level_uid = uid
    level = {
        "identifier": LEVEL_NAME, "iid": str(uuid.uuid4()), "uid": level_uid,
        # worldY 1000, clearly clear of Act_2_Level_0's own y:400-592 span —
        # the ORIGINAL version of this script placed the showcase room at the
        # exact same world position as the real starting room, which is how
        # LDtk's editor ended up merging the two into one room under one name
        # the first time this ran. Never repeat that mistake.
        "worldX": 0, "worldY": 1000, "worldDepth": 0,
        "pxWid": CW * CELL, "pxHei": CH * CELL,
        "__bgColor": "#202030", "bgColor": None, "useAutoIdentifier": True,
        "bgRelPath": None, "bgPos": None, "bgPivotX": 0.5, "bgPivotY": 0.5,
        "__smartColor": "#FFFFFF", "__bgPos": None, "externalRelPath": None,
        "fieldInstances": [],
        "layerInstances": [
            layer_instance("Collisions", True, collisions_csv, coll_tiles),
            layer_instance("Foreground", False),
            layer_instance("Entities", False),
            layer_instance("Collision", True, [0] * (CW * CH)),
            layer_instance("Background", False),
            layer_instance("ThoughtHazards", True, thought_csv, thought_tiles),
        ],
        "__neighbours": [],
    }
    for li in level["layerInstances"]:
        li["levelId"] = level_uid

    d["levels"].append(level)

    print("\nwould add level %s (uid %d): %d floor/wall tiles, %d sludge tiles, "
          "%d entities" % (LEVEL_NAME, level_uid, len(coll_tiles), len(thought_tiles),
                           len(entities)))
    if APPLY:
        tmp = LDTK + ".tmp"
        with open(tmp, "w") as fh:
            json.dump(d, fh, indent="\t")
        os.replace(tmp, LDTK)
        print("APPLIED. Re-import in Godot:")
        print("  rm .godot/imported/hooshang_act2.ldtk-* ldtk/levels/Act2_*.scn")
        print("  Godot --headless --path . --import")
    else:
        print("DRY RUN — nothing written. Re-run with --apply")


main()
