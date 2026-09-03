#!/usr/bin/env python3
"""Insert the new room at position 1 by renumbering every level after it.

  Level_23 (the room inserted between the opening and room 1)  ->  Level_1
  Level_1 .. Level_22                                          ->  Level_2 .. Level_23
  Level_0, Level_24                                            unchanged

Level_0 is the opening room. Level_24 is the standalone dash-tutorial room and
is not in the run at all (scripts/dash_tutorial.gd), so it keeps its number —
which is also why the map is written as one simultaneous rewrite rather than the
"increment 1-23, then rename 24" it was first described as: that route needs a
Level_24 to pass through, and there is a real one now.

ONE SIMULTANEOUS MAPPING, never a sequence of renames. Done step by step,
Level_1 -> Level_2 overwrites the real Level_2 before it has moved.

Level identifiers ARE the play order in this project (CLAUDE.md), so this is
what actually puts the new room second in the run. Everything that names a room
by string or by number has to move with it, which is why this touches code,
tests and docs as well as the .ldtk.

TWO THINGS IT MUST NOT REWRITE, both of which look exactly like a level:
  - `Level_1_Office`, an LDtk enum value. The \\b in the pattern is what keeps it
    out; there is a guard below that aborts if it is ever touched.
  - addons/ldtk-importer, which is third-party and mentions Level_0 -> Level_1 in
    a comment. Excluded by path.

LDtk MUST BE CLOSED. It holds the project in memory and writes it back whole, so
a scripted edit under a running LDtk is reverted silently. This refuses to run.

Usage:  python3 tools/ldtk_renumber_rooms.py            # dry run
        python3 tools/ldtk_renumber_rooms.py --apply
"""
import os
import re
import subprocess
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
APPLY = "--apply" in sys.argv

MAP = {23: 1}
for n in range(1, 23):
    MAP[n] = n + 1

SKIP_DIRS = {".git", ".godot", "builds", "addons", "backups", "node_modules"}
SUFFIXES = (".gd", ".tscn", ".tres", ".md", ".ldtk", ".py", ".cfg", ".json")

## Exports that name rooms by NUMBER. A rename pass over "Level_N" cannot see
## these, and every one silently points at the wrong room if left behind.
NUMERIC = [
    ("scripts/act1_beats.gd", "@export var collapse_first_room := 13",
                              "@export var collapse_first_room := 14"),
    ("scripts/act1_beats.gd", "@export var collapse_last_room := 22",
                              "@export var collapse_last_room := 23"),
    ("scripts/act1_beats.gd", "@export var glow_rooms: Array[int] = [12, 16, 17, 18]",
                              "@export var glow_rooms: Array[int] = [13, 17, 18, 19]"),
    ("scripts/act1_beats.gd", "@export var ambience_first_room := 12",
                              "@export var ambience_first_room := 13"),
    ("scripts/act1_beats.gd", "@export var ambience_last_room := 21",
                              "@export var ambience_last_room := 22"),
    ("scripts/act1_beats.gd", "@export var brick_first_room := 13",
                              "@export var brick_first_room := 14"),
]

PATTERN = re.compile(r"\bLevel_(\d+)\b")


def ldtk_running():
    """Is the LDtk app up?

    Matched on `comm` — the executable path alone — and NOT on the full command
    line. A full-command-line scan matches the shell that is running this very
    script, because the script's own source contains the string it is looking
    for, and it then refuses to run on a machine where LDtk is closed.
    """
    out = subprocess.run(["ps", "ax", "-o", "comm="],
                         capture_output=True, text=True).stdout
    return any(l.strip().endswith("/LDtk") or l.strip() == "LDtk"
               for l in out.splitlines())


def files():
    """Every file that could name a room — except this one.

    This script's own docstring spells the mapping out in Level_N terms, so a
    repo-wide rewrite renumbers the record of what the rewrite did: the file
    ends up claiming it maps Level_24 -> Level_2 and 2..23 -> 3..24, which is
    both wrong and the only written account of the change.
    """
    me = os.path.abspath(__file__)
    for base, dirs, names in os.walk(ROOT):
        dirs[:] = [d for d in dirs if d not in SKIP_DIRS]
        for n in names:
            if n.endswith(SUFFIXES):
                path = os.path.join(base, n)
                if os.path.abspath(path) != me:
                    yield path


def remap(text):
    return PATTERN.sub(lambda m: "Level_%d" % MAP.get(int(m.group(1)), int(m.group(1))),
                       text)


def main():
    if ldtk_running():
        raise SystemExit("!! LDtk is open — close it first.")
    total = 0
    touched = 0
    for path in sorted(files()):
        try:
            src = open(path).read()
        except (UnicodeDecodeError, OSError):
            continue
        out = remap(src)
        if out == src:
            continue
        if "Level_1_Office" in src and "Level_1_Office" not in out:
            raise SystemExit("!! renamed the Level_1_Office enum in %s — aborting" % path)
        hits = len(PATTERN.findall(src))
        total += hits
        touched += 1
        print("  %-46s %d refs" % (os.path.relpath(path, ROOT), hits))
        if APPLY:
            open(path, "w").write(out)

    print("\nnumeric room references:")
    for rel, old, new in NUMERIC:
        p = os.path.join(ROOT, rel)
        src = open(p).read()
        if old not in src:
            print("  !! NOT FOUND in %s: %s" % (rel, old.strip()))
            continue
        print("  %s\n      -> %s" % (old.strip(), new.strip()))
        if APPLY:
            open(p, "w").write(src.replace(old, new, 1))

    print("\n%d level-name references across %d files" % (total, touched))
    if APPLY:
        print("APPLIED. Now:")
        print("  rm .godot/imported/hooshang_act1.ldtk-* ldtk/levels/Level_*.scn")
        print("  Godot --headless --path . --import")
    else:
        print("DRY RUN — nothing written. Re-run with --apply")


main()
