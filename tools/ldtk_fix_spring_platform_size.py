#!/usr/bin/env python3
"""Lock the SpringPlatform entity to a fixed 16x8 footprint, at the user's
explicit direction: "16px x 8px when compact... this should be the only size
for this entity." A one-shot migration, not tools/ldtk_add_spring_platform.py
(which only ADDS the entity and skips if it already exists) — the entity is
already defined and placed, so this MUTATES the existing definition and every
placed instance in place.

Two things it changes:
  1. defs.entities["SpringPlatform"]: width 24 -> 16, resizableX true -> false
     (height was already 8/false). minWidth/maxWidth cleared — meaningless on
     a non-resizable entity. This is what actually removes the resize handle
     from the LDtk editor; the runtime-side guarantee (SpringPlatform ignoring
     `size` and always building FIXED_SIZE geometry regardless of what the
     entity claims) already lives in scenes/props/platforms/spring_platform.gd
     and does not depend on this script having been run.
  2. Every already-placed SpringPlatform instance: width 24 -> 16 (height was
     already 8). `px` (top-left, LDtk's own coordinate) is shifted so the
     entity's CENTRE stays where it was placed — pivotX is 0.5, so
     centre_x = px.x + width*0.5; solving for the new px.x at the new width
     keeps that centre fixed: new_px.x = old_px.x + (old_width - new_width)/2.
     Without this every placed spring would jump 4px left on next import,
     which is not what "lock its size" is supposed to do to level geometry
     that was already placed and looks right today.

LDTK MUST BE CLOSED — see tools/ldtk_add_platforms.py for why (it holds the
whole project in memory and writes it back wholesale on save/exit, which
would silently revert this edit).

Idempotent: running it again on an already-migrated file changes nothing
(width is already 16, resizableX already false — the `already_16` guard below
skips both the def and the per-instance px shift).

Usage:  python3 tools/ldtk_fix_spring_platform_size.py          # dry run
        python3 tools/ldtk_fix_spring_platform_size.py --apply
"""
import json
import os
import subprocess
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
LDTK = os.path.join(ROOT, "ldtk", "hooshang_act2.ldtk")
APPLY = "--apply" in sys.argv

NEW_WIDTH = 16
OLD_WIDTH_FALLBACK = 24  # only used to compute the px shift if a stray instance's own width disagrees with the def


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
    with open(LDTK) as f:
        d = json.load(f)

    entity_def = None
    for e in d["defs"]["entities"]:
        if e["identifier"] == "SpringPlatform":
            entity_def = e
            break
    if entity_def is None:
        raise SystemExit("!! SpringPlatform is not defined in this project — "
                         "run tools/ldtk_add_spring_platform.py first.")

    already_16 = entity_def["width"] == NEW_WIDTH and not entity_def["resizableX"]

    def_changes = []
    if entity_def["width"] != NEW_WIDTH:
        def_changes.append("width %d -> %d" % (entity_def["width"], NEW_WIDTH))
        entity_def["width"] = NEW_WIDTH
    if entity_def["resizableX"]:
        def_changes.append("resizableX true -> false")
        entity_def["resizableX"] = False
    if entity_def.get("minWidth") is not None or entity_def.get("maxWidth") is not None:
        def_changes.append("minWidth/maxWidth cleared")
        entity_def["minWidth"] = None
        entity_def["maxWidth"] = None
    entity_def["doc"] = ("A bounce pad: land on top and it launches him "
        "straight up, hard. Fixed size — 16x8 — it is not resizable; see "
        "scenes/props/platforms/spring_platform.gd's FIXED SIZE note.")

    instance_changes = []
    for lvl in d["levels"]:
        for layer in lvl.get("layerInstances") or []:
            for ent in layer.get("entityInstances", []):
                if ent["__identifier"] != "SpringPlatform":
                    continue
                old_width = ent["width"]
                if old_width == NEW_WIDTH:
                    continue
                shift = (old_width - NEW_WIDTH) // 2
                old_px = list(ent["px"])
                ent["width"] = NEW_WIDTH
                ent["px"][0] += shift
                # __worldX mirrors px[0] once the level's own worldX offset is
                # added back in; keep it in sync so the editor's own display
                # (and anything reading __worldX directly) does not disagree
                # with px.
                if "__worldX" in ent:
                    ent["__worldX"] += shift
                instance_changes.append(
                    "%s: width %d -> %d, px %s -> %s"
                    % (lvl["identifier"], old_width, NEW_WIDTH, old_px, ent["px"]))

    print("SpringPlatform entity definition:")
    for c in def_changes:
        print("  " + c)
    if not def_changes:
        print("  (already 16x8, fixed — nothing to change)" if already_16
              else "  (width already 16, but see instance changes below)")
    print("\nPlaced instances:")
    for c in instance_changes:
        print("  " + c)
    if not instance_changes:
        print("  (none needed resizing)")

    if not def_changes and not instance_changes:
        print("\nAlready migrated — nothing to do.")
        return

    if APPLY:
        tmp = LDTK + ".tmp"
        with open(tmp, "w") as f:
            json.dump(d, f, indent="\t")
        os.replace(tmp, LDTK)
        print("\nAPPLIED. Re-import in Godot:")
        print("  rm .godot/imported/hooshang_act2.ldtk-* ldtk/levels/Act_2_*.scn ldtk/levels/Act2_*.scn")
        print("  Godot --headless --path . --import")
    else:
        print("\nDRY RUN — nothing written. Re-run with --apply")


main()
