#!/usr/bin/env python3
"""Add `ceiling_flor` to the Collisions layer, so the ceiling can be PAINTED.

Not an entity: an IntGrid value on the same layer the brickwork is painted on,
with auto-layer rules behind it. Pick it in LDtk, brush a run of cells, and you
get a length of suspended office ceiling that is solid to stand on — the same
way the walls are made.

WHAT THIS TOUCHES, all of it on the `Collisions` layer (uid 23):

  the tileset   `bricks_8px.png` grows from four tiles to six. An LDtk auto-layer
                has exactly ONE tileset, so the ceiling tiles have to live on the
                brick sheet — tools/gen_bricks_8px.py draws them, from the
                ceiling props' own palette so the two cannot drift.
  the value     3, `ceiling_flor`, alongside 2 `brick`.
  two rules     one lays the plain cell everywhere the value is painted; the
                other lays the panel cell every third column, so a run comes out
                as a grid with a light panel set into it rather than as an
                unbroken board.

Collision comes for free: `scripts/ldtk_tileset_post_import.gd` gives every tile
in every source a full square on every import, which is also why this needed no
new physics work.

THE PANELS DO NOT GLOW, and cannot. `CanvasModulate` is 0.05 in Act I and
multiplies every CanvasItem, so a painted luminous panel arrives at 5% of what
was drawn — the trap SunShaft, WallPattern and CeilingPanel all document. Paint
gives you the architecture; drop a `CeilingPanel` (scenes/props/lighting) on a
cell to light it.

EDITED AS TEXT, not as parsed JSON re-dumped. The project is a 1MB tab-indented
file with LDtk's own inline compaction, and a round trip through json.dump comes
back 2.4x the size with every line changed: valid, and impossible to review. It
then PROVES the edit by parsing both versions and comparing them key by key.

LDTK MUST BE CLOSED. It holds the whole project in memory and writes it back
wholesale, so a scripted edit made under a running LDtk is silently reverted —
CLAUDE.md records that happening to an entity rename already.

Idempotent: running it twice adds nothing the second time.

Usage:  python3 tools/ldtk_add_ceiling_tile.py          # dry run
        python3 tools/ldtk_add_ceiling_tile.py --apply
"""
import copy
import json
import os
import re
import subprocess
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
LDTK = os.path.join(ROOT, "ldtk", "hooshang_act1.ldtk")
APPLY = "--apply" in sys.argv

## The IntGrid value, named exactly as asked. LDtk's `identifierStyle` is
## Capitalize, which forces a leading capital on ENTITY and layer identifiers —
## but not on IntGrid value names, where the existing one is `brick`.
VALUE = 3
NAME = "ceiling_flor"
COLOR = "#B8C6D2"

LAYER = "Collisions"
TILESET = "Bricks8px"
## Tile ids on the sheet, set by tools/gen_bricks_8px.py's order.
TILE_PLAIN = 4
TILE_PANEL = 5
## Sheet size after those two are added.
NEW_CWID, NEW_PXWID = 6, 48
OLD_CWID, OLD_PXWID = 4, 32
## A panel every Nth column, offset so it lands in the middle of each group
## rather than on the first cell of a painted run.
PANEL_EVERY, PANEL_PHASE = 3, 1


def ldtk_running():
    """Matched on the executable path, not the full command line: a
    full-command-line scan matches the shell running this very script, because
    the script's own source contains the string it is looking for."""
    out = subprocess.run(["ps", "ax", "-o", "comm="],
                         capture_output=True, text=True).stdout
    return any(l.strip().endswith("/LDtk") or l.strip() == "LDtk"
               for l in out.splitlines())


def object_span(text, start):
    """(begin, end) of the JSON object containing `start`, by bracket matching
    from the `{` before it. String-aware, so a brace inside a value cannot throw
    the count off."""
    begin = text.rindex("{", 0, start)
    depth, i, in_str, esc = 0, begin, False, False
    while i < len(text):
        c = text[i]
        if in_str:
            if esc:
                esc = False
            elif c == "\\":
                esc = True
            elif c == '"':
                in_str = False
        elif c == '"':
            in_str = True
        elif c == "{":
            depth += 1
        elif c == "}":
            depth -= 1
            if depth == 0:
                return begin, i + 1
        i += 1
    raise SystemExit("!! unbalanced braces looking for an object")


def array_end(text, start):
    """Index of the `]` closing the array whose `[` is at/after `start`."""
    begin = text.index("[", start)
    depth, i, in_str, esc = 0, begin, False, False
    while i < len(text):
        c = text[i]
        if in_str:
            if esc:
                esc = False
            elif c == "\\":
                esc = True
            elif c == '"':
                in_str = False
        elif c == '"':
            in_str = True
        elif c == "[":
            depth += 1
        elif c == "]":
            depth -= 1
            if depth == 0:
                return i
        i += 1
    raise SystemExit("!! unbalanced brackets looking for an array")


def block(obj, depth):
    """One JSON object as LDtk writes them: tab-indented, at `depth` tabs."""
    body = json.dumps(obj, indent="\t")
    pad = "\t" * depth
    return "\n".join(pad + line for line in body.splitlines())


def rule(uid, tile, modulo, phase):
    """One auto-layer rule: where the value is painted, lay `tile`.

    Every field the format carries is written out rather than left to a default,
    because LDtk reads this file back and a missing key is not a default there —
    it is a crash or a silently different rule.
    """
    return {
        "uid": uid, "active": True, "size": 1,
        "tileRectsIds": [[tile]],
        "alpha": 1, "chance": 1, "breakOnMatch": True,
        "pattern": [VALUE],
        "flipX": False, "flipY": False,
        "xModulo": modulo, "yModulo": 1,
        "xOffset": phase, "yOffset": 0,
        "tileXOffset": 0, "tileYOffset": 0,
        "tileRandomXMin": 0, "tileRandomXMax": 0,
        "tileRandomYMin": 0, "tileRandomYMax": 0,
        "checker": "None", "tileMode": "Single",
        "pivotX": 0, "pivotY": 0,
        # The brick rules set this to 2 so past a room's edge counts AS brick,
        # which matters to their 3x3 patterns. These patterns are one cell, so
        # there is no neighbour to be out of bounds.
        "outOfBoundsValue": None,
        "invalidated": False,
        "perlinActive": False, "perlinSeed": 4367591,
        "perlinScale": 0.2, "perlinOctaves": 2,
    }


def check(before, after, group, value):
    """Prove the edit did what it said and nothing else."""
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

    sa, sb = copy.deepcopy(a), copy.deepcopy(b)
    for doc in (sa, sb):
        lv = [l for l in doc["defs"]["layers"] if l["identifier"] == LAYER][0]
        lv["intGridValues"] = lv["autoRuleGroups"] = None
        ts = [t for t in doc["defs"]["tilesets"] if t["identifier"] == TILESET][0]
        ts["__cWid"] = ts["pxWid"] = None
    if sa != sb:
        raise SystemExit("!! something outside the layer and its tileset moved")


def main():
    if ldtk_running():
        raise SystemExit("!! LDtk is open — close it first, or it will write "
                         "the project back over this edit.")
    raw = open(LDTK).read()
    if '"identifier": "%s"' % NAME in raw:
        print("  %s is already defined — nothing to do" % NAME)
        return

    sheet = os.path.join(ROOT, "ldtk", "art", "bricks_8px.png")
    from PIL import Image
    if Image.open(sheet).size[0] != NEW_PXWID:
        raise SystemExit("!! ldtk/art/bricks_8px.png is not %dpx wide — run "
                         "tools/gen_bricks_8px.py first" % NEW_PXWID)

    uid = max(int(u) for u in re.findall(r'"uid":\s*(\d+)', raw))
    group = {
        "uid": uid + 1, "name": NAME, "color": None, "icon": None,
        "active": True, "isOptional": False,
        # The panel rule comes FIRST and breaks on match, so the plain rule
        # below it only ever sees the cells the panel did not claim.
        "rules": [rule(uid + 2, TILE_PANEL, PANEL_EVERY, PANEL_PHASE),
                  rule(uid + 3, TILE_PLAIN, 1, 0)],
        "usesWizard": False,
        "requiredBiomeValues": [], "biomeRequirementMode": 0,
    }
    value = {"value": VALUE, "identifier": NAME, "color": COLOR,
             "tile": None, "groupUid": 0}

    out = raw
    # --- the tileset grows by two tiles ------------------------------------
    b, e = object_span(out, out.index('"identifier": "%s"' % TILESET))
    ts = out[b:e]
    for key, old, new in (("__cWid", OLD_CWID, NEW_CWID),
                          ("pxWid", OLD_PXWID, NEW_PXWID)):
        needle = '"%s": %d' % (key, old)
        if ts.count(needle) != 1:
            raise SystemExit("!! expected one %s in %s, found %d"
                             % (needle, TILESET, ts.count(needle)))
        ts = ts.replace(needle, '"%s": %d' % (key, new))
    out = out[:b] + ts + out[e:]

    # --- the value, and the rules behind it --------------------------------
    lb, le = object_span(out, out.index('"identifier": "%s"' % LAYER))
    layer = out[lb:le]
    i = array_end(layer, layer.index('"intGridValues"'))
    layer = layer[:i] + ",\n" + block(value, 4).rstrip() + "\n\t\t\t" + layer[i:]
    j = array_end(layer, layer.index('"autoRuleGroups"'))
    layer = layer[:j] + ",\n" + block(group, 4) + "\n\t\t\t" + layer[j:]
    out = out[:lb] + layer + out[le:]

    check(raw, out, group, value)
    print("  IntGrid value %d  %-14s on the %s layer" % (VALUE, NAME, LAYER))
    print("  tileset %s  %d -> %d tiles" % (TILESET, OLD_CWID, NEW_CWID))
    print("  rules: tile %d every %d columns (phase %d), tile %d elsewhere"
          % (TILE_PANEL, PANEL_EVERY, PANEL_PHASE, TILE_PLAIN))
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
