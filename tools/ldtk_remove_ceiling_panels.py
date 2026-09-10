#!/usr/bin/env python3
"""Strip `CeilingPanel` entities out of most of Act 1's rooms, keeping them
only in the music-tile puzzle rooms and the room where Hooshang meets
Darkshang.

KEEP_IN is computed from what's actually IN THE FILE, not a hand-typed level
list: a room counts as "music tiles" if its Entities layer has any
MusicNote1..5 entity (the NoteSequence puzzle, see tools/gen_note_audio.py /
tests/music_test.tscn), and as "the Darkshang encounter" if it has a
DarkshangSpawn or DarkshangTrigger entity. At the time this was written that
resolved to Level_7/8/9/13/15/19/20/21 (music) and Level_14 (Darkshang) --
printed at runtime so a stale hardcoded list can never silently diverge from
the project.

EDITED AS TEXT, not as parsed JSON re-dumped -- hooshang_act1.ldtk is a 2MB
tab-indented file, and LDtk's own entity-instance formatting (some nested
objects compacted onto one line, e.g. "__tile") is not what a plain
json.dumps(indent="\\t") round trip would reproduce -- re-serializing even
just the touched entityInstances arrays would reformat every OTHER entity in
them too. Instead each CeilingPanel object is found by bracket-matching from
its own `{` and excised together with exactly one adjacent comma (whichever
side doesn't already have one), so every untouched entity's original text is
left byte-for-byte alone.

VERIFIED AGAINST A PURE-JSON EXPECTATION, not just structural spot checks:
the script also computes what the filtered document SHOULD look like by
filtering the parsed dict directly (list comprehension, no text surgery
involved) and asserts the text-edited-and-reparsed result equals that
byte-for-byte as data. That catches a text-surgery mistake regardless of
where it happened, not just in the fields this script happened to think to
check.

LDTK MUST BE CLOSED. It holds the whole project in memory and writes it back
wholesale, so a scripted edit made under a running LDtk is silently reverted.

Idempotent: running it twice removes nothing the second time.

Usage:  python3 tools/ldtk_remove_ceiling_panels.py          # dry run
        python3 tools/ldtk_remove_ceiling_panels.py --apply
"""
import copy
import json
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from ldtk_add_ceiling_tile import ldtk_running, object_span

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
LDTK = os.path.join(ROOT, "ldtk", "hooshang_act1.ldtk")
APPLY = "--apply" in sys.argv

ENTITY = "CeilingPanel"
MUSIC_MARKER_PREFIX = "MusicNote"
DARKSHANG_MARKERS = {"DarkshangSpawn", "DarkshangTrigger"}


def entity_names(level):
    for li in level["layerInstances"]:
        if li["__identifier"] == "Entities":
            return [e["__identifier"] for e in li["entityInstances"]]
    return []


def removal_span(text, obj_start, obj_end):
    """The exact range to delete for one entity object: itself plus whichever
    adjacent comma keeps the array valid. Prefers the comma BEFORE it (the
    common case -- this object is not first); falls back to the comma AFTER
    it only when there is nothing before (this object is first in the
    array)."""
    i = obj_start - 1
    while i >= 0 and text[i] in " \t\n":
        i -= 1
    if i >= 0 and text[i] == ",":
        return i, obj_end
    j = obj_end
    while j < len(text) and text[j] in " \t\n":
        j += 1
    if j < len(text) and text[j] == ",":
        return obj_start, j + 1
    return obj_start, obj_end  # sole element -- not expected to occur here


def main():
    if ldtk_running():
        raise SystemExit("!! LDtk is open — close it first, or it will write "
                         "the project back over this edit.")
    raw = open(LDTK).read()
    doc = json.loads(raw)

    music_levels, darkshang_levels = [], []
    for lvl in doc["levels"]:
        names = entity_names(lvl)
        if any(n.startswith(MUSIC_MARKER_PREFIX) for n in names):
            music_levels.append(lvl["identifier"])
        if DARKSHANG_MARKERS & set(names):
            darkshang_levels.append(lvl["identifier"])
    keep_in = set(music_levels) | set(darkshang_levels)

    print("keeping CeilingPanel in (music tiles):", ", ".join(sorted(music_levels)))
    print("keeping CeilingPanel in (Darkshang encounter):", ", ".join(darkshang_levels))
    print()

    removal_ranges = []   # (start, end) in `raw`, collected across all levels
    per_level_removed = {}
    expected = copy.deepcopy(doc)

    for lvl, exp_lvl in zip(doc["levels"], expected["levels"]):
        if lvl["identifier"] in keep_in:
            continue
        ent_li = next(li for li in lvl["layerInstances"] if li["__identifier"] == "Entities")
        count = sum(1 for e in ent_li["entityInstances"] if e["__identifier"] == ENTITY)
        if count == 0:
            continue
        per_level_removed[lvl["identifier"]] = count

        exp_ent_li = next(li for li in exp_lvl["layerInstances"] if li["__identifier"] == "Entities")
        exp_ent_li["entityInstances"] = [e for e in exp_ent_li["entityInstances"]
                                        if e["__identifier"] != ENTITY]

        lvl_pos = raw.index('"iid": "%s"' % lvl["iid"])
        lvl_b, lvl_e = object_span(raw, lvl_pos)
        ent_pos = raw.index('"__identifier": "Entities"', lvl_b, lvl_e)
        elb, ele = object_span(raw, ent_pos)

        search_from = elb
        while True:
            hit = raw.find('"__identifier": "%s"' % ENTITY, search_from, ele)
            if hit == -1:
                break
            ob, oe = object_span(raw, hit)
            removal_ranges.append(removal_span(raw, ob, oe))
            search_from = oe

    if not per_level_removed:
        print("nothing to remove.")
        return

    for name, count in per_level_removed.items():
        print("  %-14s remove %d CeilingPanel" % (name, count))
    print("\n  %d entities across %d levels" % (sum(per_level_removed.values()), len(per_level_removed)))

    out = raw
    for start, end in sorted(removal_ranges, key=lambda r: -r[0]):
        out = out[:start] + out[end:]

    actual = json.loads(out)
    if actual != expected:
        raise SystemExit("!! the edited document does not match the expected "
                         "filtered result — nothing written")
    print("\nverified: edited document matches the pure-JSON expected result exactly")

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
