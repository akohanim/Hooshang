#!/usr/bin/env python3
"""Add the overhead ceiling: `ceiling` to paint, and CeilingLight to place.

Two halves of the same thing, split because a tile cannot glow and an entity
should not have to carry the whole ceiling.

  ceiling       an IntGrid value on the Collisions layer, next to `brick` and
                `ceiling_flor` — the office ceiling seen from BELOW, which is
                what room 2's CeilingPanel props are made of. Paint it along the
                top of a room and it is solid, like every other tile there.
  CeilingLight  an entity, for the light itself. Drop it on a panel cell (or
                anywhere else) and the import turns it into the panel's glow and
                the pool it throws.

Painted panel cells are lit automatically as well — see
`scripts/ldtk_level_post_import.gd`. The entity is for the ones that are not on
the rhythm: a lit panel over a doorway, a single fitting in a dark room, a
ceiling whose grid you painted but whose lights you want somewhere else.

WHAT THIS TOUCHES:

  the tileset   `bricks_8px.png` grows from six tiles to eight. An LDtk
                auto-layer has exactly ONE tileset, so every paintable tile in
                the game lives on the brick sheet; tools/gen_bricks_8px.py draws
                them, from the ceiling props' own palette so the two cannot
                drift apart.
  the value     4, `ceiling`, alongside 2 `brick` and 3 `ceiling_flor`.
  three rules   the panel cell every third column, staggered a column per row so
                a two-row ceiling reads as a grid rather than as vertical pairs,
                and the plain cell everywhere neither claims.
  the entity    CeilingLight, a point (no size to drag), pivot 0.5/0.5 like
                every other entity here.

Collision comes for free: `scripts/ldtk_tileset_post_import.gd` gives every tile
in every source a full square on every import.

EDITED AS TEXT, not as parsed JSON re-dumped — the project is a 1MB tab-indented
file and a json.dump round trip comes back 2.4x the size with every line
changed. It then PROVES the edit by parsing both versions and comparing them.

LDTK MUST BE CLOSED. It holds the whole project in memory and writes it back
wholesale, so a scripted edit made under a running LDtk is silently reverted.

Idempotent: running it twice adds nothing the second time.

Usage:  python3 tools/ldtk_add_overhead_ceiling.py          # dry run
        python3 tools/ldtk_add_overhead_ceiling.py --apply
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
APPLY = "--apply" in sys.argv

LAYER = "Collisions"
TILESET = "Bricks8px"

## The IntGrid value. Lower case like `brick` and `ceiling_flor` — LDtk's
## Capitalize style applies to entity and layer identifiers, not to these.
VALUE, NAME, COLOR = 4, "ceiling", "#9AA8B6"
## Tile ids on the sheet, fixed by tools/gen_bricks_8px.py's order.
TILE_PLAIN, TILE_PANEL = 6, 7
OLD_CWID, OLD_PXWID = 6, 48
NEW_CWID, NEW_PXWID = 8, 64
## A panel every Nth column, one column further along on odd rows. Same rhythm
## `ceiling_flor` uses, and for the same reason.
EVERY, PHASE_EVEN, PHASE_ODD = 3, 1, 2

## The light, as something to place by hand.
ENTITY = "CeilingLight"
ENTITY_ICON = "art/ceiling_light.png"
ENTITY_COLOR = "#DDE8F2"
ENTITY_DOC = ("The light of a ceiling panel: the panel's own glow, and the pool "
              "it drops into the room. Painted `ceiling` panels are lit "
              "automatically — place this for the ones that are not on the "
              "rhythm, or to light a plain cell.")


def rule(uid, tile, x_modulo, x_offset, y_modulo, y_offset):
    """One auto-layer rule. Every field the format carries is written out,
    because LDtk reads this back and a missing key there is not a default."""
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
        "outOfBoundsValue": None,
        "invalidated": False,
        "perlinActive": False, "perlinSeed": 4367592,
        "perlinScale": 0.2, "perlinOctaves": 2,
    }


def tileset_def(uid):
    return {
        "__cWid": 1, "__cHei": 1,
        "identifier": ENTITY + "Icon", "uid": uid,
        "relPath": ENTITY_ICON, "embedAtlas": None,
        "pxWid": 16, "pxHei": 16, "tileGridSize": 16,
        "spacing": 0, "padding": 0, "tags": [],
        "tagsSourceEnumUid": None, "enumTags": [], "customData": [],
        "cachedPixelData": None, "savedSelections": [],
    }


def entity_def(uid, ts_uid):
    rect = {"tilesetUid": ts_uid, "x": 0, "y": 0, "w": 16, "h": 16}
    return {
        "identifier": ENTITY, "uid": uid, "tags": [],
        "exportToToc": False, "allowOutOfBounds": False,
        "doc": ENTITY_DOC,
        # One cell. A light is a point — there is nothing to drag.
        "width": 8, "height": 8,
        "resizableX": False, "resizableY": False,
        "minWidth": None, "maxWidth": None,
        "minHeight": None, "maxHeight": None,
        "keepAspectRatio": False,
        "tileOpacity": 1, "fillOpacity": 0.4, "lineOpacity": 1,
        "hollow": False, "color": ENTITY_COLOR,
        "renderMode": "Tile", "showName": False,
        "tilesetId": ts_uid, "tileRenderMode": "FitInside",
        "tileRect": rect, "uiTileRect": dict(rect),
        "nineSliceBorders": [], "maxCount": 0,
        "limitScope": "PerLayer", "limitBehavior": "MoveLastOne",
        "pivotX": 0.5, "pivotY": 0.5, "fieldDefs": [],
    }


def check(before, after, group, value, ent, ts):
    a, b = json.loads(before), json.loads(after)

    def layer(doc):
        return [l for l in doc["defs"]["layers"] if l["identifier"] == LAYER][0]

    def tileset(doc):
        return [t for t in doc["defs"]["tilesets"] if t["identifier"] == TILESET][0]

    if layer(b)["intGridValues"] != layer(a)["intGridValues"] + [value]:
        raise SystemExit("!! the IntGrid values are not what was intended")
    if layer(b)["autoRuleGroups"] != layer(a)["autoRuleGroups"] + [group]:
        raise SystemExit("!! the rule groups are not what was intended")
    if (tileset(b)["__cWid"], tileset(b)["pxWid"]) != (NEW_CWID, NEW_PXWID):
        raise SystemExit("!! the tileset did not grow to %d tiles" % NEW_CWID)
    if b["defs"]["entities"] != a["defs"]["entities"] + [ent]:
        raise SystemExit("!! the entity list is not what was intended")
    # The sheet's own entry is edited in place as well as one being appended, so
    # the expectation has to carry that edit rather than compare against the
    # untouched list — which is what this caught the first time it ran.
    expected = copy.deepcopy(a["defs"]["tilesets"])
    for t in expected:
        if t["identifier"] == TILESET:
            t["__cWid"], t["pxWid"] = NEW_CWID, NEW_PXWID
    if b["defs"]["tilesets"] != expected + [ts]:
        raise SystemExit("!! the tileset list is not what was intended")

    sa, sb = copy.deepcopy(a), copy.deepcopy(b)
    for doc in (sa, sb):
        lv = [l for l in doc["defs"]["layers"] if l["identifier"] == LAYER][0]
        lv["intGridValues"] = lv["autoRuleGroups"] = None
        doc["defs"]["entities"] = doc["defs"]["tilesets"] = None
    if sa != sb:
        raise SystemExit("!! something outside the layer, its tileset and the "
                         "entity list moved")


def main():
    if ldtk_running():
        raise SystemExit("!! LDtk is open — close it first, or it will write "
                         "the project back over this edit.")
    raw = open(LDTK).read()
    if '"identifier": "%s"' % ENTITY in raw:
        print("  %s is already defined — nothing to do" % ENTITY)
        return

    from PIL import Image
    sheet = os.path.join(ROOT, "ldtk", "art", "bricks_8px.png")
    if Image.open(sheet).size[0] != NEW_PXWID:
        raise SystemExit("!! ldtk/art/bricks_8px.png is not %dpx wide — run "
                         "tools/gen_bricks_8px.py first" % NEW_PXWID)
    if not os.path.exists(os.path.join(ROOT, "ldtk", ENTITY_ICON)):
        raise SystemExit("!! no icon at ldtk/%s — run tools/gen_ceiling_panel.py"
                         % ENTITY_ICON)

    uid = max(int(u) for u in re.findall(r'"uid":\s*(\d+)', raw))
    group = {
        "uid": uid + 1, "name": NAME, "color": None, "icon": None,
        "active": True, "isOptional": False,
        # Panels first and breaking on match, so the plain rule below only ever
        # sees the cells they did not take.
        "rules": [rule(uid + 2, TILE_PANEL, EVERY, PHASE_EVEN, 2, 0),
                  rule(uid + 3, TILE_PANEL, EVERY, PHASE_ODD, 2, 1),
                  rule(uid + 4, TILE_PLAIN, 1, 0, 1, 0)],
        "usesWizard": False,
        "requiredBiomeValues": [], "biomeRequirementMode": 0,
    }
    value = {"value": VALUE, "identifier": NAME, "color": COLOR,
             "tile": None, "groupUid": 0}
    ts = tileset_def(uid + 5)
    ent = entity_def(uid + 6, uid + 5)

    out = raw
    # --- the sheet grows by two tiles --------------------------------------
    b, e = object_span(out, out.index('"identifier": "%s"' % TILESET))
    block_ts = out[b:e]
    for key, old, new in (("__cWid", OLD_CWID, NEW_CWID),
                          ("pxWid", OLD_PXWID, NEW_PXWID)):
        needle = '"%s": %d' % (key, old)
        if block_ts.count(needle) != 1:
            raise SystemExit("!! expected one %s in %s, found %d"
                             % (needle, TILESET, block_ts.count(needle)))
        block_ts = block_ts.replace(needle, '"%s": %d' % (key, new))
    out = out[:b] + block_ts + out[e:]

    # --- the value and its rules -------------------------------------------
    lb, le = object_span(out, out.index('"identifier": "%s"' % LAYER))
    layer = out[lb:le]
    i = array_end(layer, layer.index('"intGridValues"'))
    layer = layer[:i] + ",\n" + block(value, 4).rstrip() + "\n\t\t\t" + layer[i:]
    j = array_end(layer, layer.index('"autoRuleGroups"'))
    layer = layer[:j] + ",\n" + block(group, 4) + "\n\t\t\t" + layer[j:]
    out = out[:lb] + layer + out[le:]

    # --- the entity, and the icon tileset behind it ------------------------
    i = out.index('\n\t], "tilesets": [')
    out = out[:i] + ",\n" + block(ent, 2) + out[i:]
    j = out.index('\n\t], "enums": [')
    out = out[:j] + ",\n" + block(ts, 2) + out[j:]

    check(raw, out, group, value, ent, ts)
    print("  IntGrid value %d  %-12s  tiles %d/%d, panel every %d, staggered"
          % (VALUE, NAME, TILE_PLAIN, TILE_PANEL, EVERY))
    print("  tileset %s  %d -> %d tiles" % (TILESET, OLD_CWID, NEW_CWID))
    print("  entity  %s  uid %d, icon tileset %d" % (ENTITY, ent["uid"], ts["uid"]))
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
