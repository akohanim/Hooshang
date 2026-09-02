#!/usr/bin/env python3
"""Point Act 2's Collisions and ThoughtHazards layers at Act 2's own tilesets.

hooshang_act2.ldtk currently borrows Act 1's tilesets wholesale (Bricks8px /
ThoughtTilesSheet, copied along with the rest of the placeholder room). This
adds two new tileset defs (art/act2_tileset_8px.png, art/act2_thought_tiles.png
— see tools/gen_act2_tileset_8px.py and tools/gen_act2_thought_tiles.py) and
repoints the Collisions and ThoughtHazards layer definitions' tilesetDefUid at
them.

The existing auto-rules on both layers are left completely untouched: they
reference tiles by POSITION (tileRectsIds), and both new sheets keep the exact
same tile order as the ones they replace (fill/top/left/corner for the wall;
the same 6-frame x 4-tile-type layout for the sludge), confirmed by reading
hooshang_act2.ldtk's own rule data before writing this script. hooshang_claude.ldtk
(Act 1) is a completely separate file and is never opened here.

LDTK MUST BE CLOSED — same reasoning as tools/ldtk_add_platforms.py.

Idempotent: running it twice does nothing the second time (checks the layers
already point at the Act 2 tilesets).

Usage:  python3 tools/ldtk_add_act2_tileset.py          # dry run
        python3 tools/ldtk_add_act2_tileset.py --apply
"""
import json
import os
import re
import subprocess
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
LDTK = os.path.join(ROOT, "ldtk", "hooshang_act2.ldtk")
APPLY = "--apply" in sys.argv

# identifier -> (relPath, pxWid, pxHei, tileGridSize, layer to repoint)
TILESETS = [
    {
        "identifier": "Act2Bricks8px",
        "relPath": "art/act2_tileset_8px.png",
        "pxWid": 32, "pxHei": 8, "tileGridSize": 8,
        "layer": "Collisions",
    },
    {
        "identifier": "Act2ThoughtTilesSheet",
        "relPath": "art/act2_thought_tiles.png",
        "pxWid": 32, "pxHei": 48, "tileGridSize": 8,
        "layer": "ThoughtHazards",
    },
]


def ldtk_running():
    try:
        out = subprocess.run(["ps", "ax", "-o", "command"],
                             capture_output=True, text=True).stdout
    except Exception:
        return False
    return any("LDtk.app/Contents/MacOS/LDtk" in line for line in out.splitlines())


def main():
    if ldtk_running():
        raise SystemExit("!! LDtk is open — close it first, or it will write "
                         "the project back over this edit.")
    raw = open(LDTK).read()
    d = json.loads(raw)
    uid = max(int(u) for u in re.findall(r'"uid":\s*(\d+)', raw))

    have_ts = {t["identifier"]: t for t in d["defs"]["tilesets"]}
    layers_by_id = {l["identifier"]: l for l in d["defs"]["layers"]}

    changed = []
    for spec in TILESETS:
        ts = have_ts.get(spec["identifier"])
        if ts is None:
            uid += 1
            ts = {
                "__cWid": spec["pxWid"] // spec["tileGridSize"],
                "__cHei": spec["pxHei"] // spec["tileGridSize"],
                "identifier": spec["identifier"], "uid": uid,
                "relPath": spec["relPath"], "embedAtlas": None,
                "pxWid": spec["pxWid"], "pxHei": spec["pxHei"],
                "tileGridSize": spec["tileGridSize"],
                "spacing": 0, "padding": 0, "tags": [],
                "tagsSourceEnumUid": None, "enumTags": [], "customData": [],
                "cachedPixelData": None, "savedSelections": [],
            }
            d["defs"]["tilesets"].append(ts)
            have_ts[spec["identifier"]] = ts
            changed.append("added tileset %s" % spec["identifier"])

        layer = layers_by_id.get(spec["layer"])
        if layer is None:
            raise SystemExit("!! layer %r not found in %s" % (spec["layer"], LDTK))
        if layer.get("tilesetDefUid") != ts["uid"]:
            layer["tilesetDefUid"] = ts["uid"]
            changed.append("repointed layer %s -> %s"
                           % (spec["layer"], spec["identifier"]))

    print("\nwould change: %s" % ("; ".join(changed) if changed else "nothing"))
    if not changed:
        return
    if APPLY:
        tmp = LDTK + ".tmp"
        with open(tmp, "w") as f:
            json.dump(d, f, indent="\t")
        os.replace(tmp, LDTK)
        print("APPLIED. Re-import in Godot:")
        print("  rm .godot/imported/hooshang_act2.ldtk-* ldtk/levels/Act2_*.scn")
        print("  Godot --headless --path . --import")
    else:
        print("DRY RUN — nothing written. Re-run with --apply")


main()
