#!/usr/bin/env python3
"""Move the dash tutorial out of its siding and into the run, as room 2.

  Level_24 (the standalone dash-tutorial room)  ->  Level_2
  Level_2 .. Level_23                           ->  Level_3 .. Level_24
  Level_0, Level_1                              unchanged

ONE SIMULTANEOUS MAPPING, never a sequence of renames. Done step by step,
Level_2 -> Level_3 overwrites the real Level_3 before it has moved.

Level identifiers ARE the play order in this project (CLAUDE.md), so the rename
is what actually puts the lesson second. But a rename ALONE leaves the room
sitting where it was authored — 1248px below the world, in its own siding — and
room transitions are a camera PAN across the gap between two rooms
(`_slide_to_room`), not a cut. Walking out of room 1 would fly the view down and
across the map. So this also moves pixels:

  - the tutorial room itself, from (8, 1408) to (640, 160): into the top row,
    hard against Level_1's right edge, where its 880px width now lives
  - the rest of the top row (new Level_3..Level_13) right by that 880px, which
    is what opens the slot. The escape row along the bottom does not move.
  - EVERY hand-placed light, window and prop that stands over those rooms.
    Act1World.tscn positions them in WORLD space, so a room that moves without
    them is a room lit by the lamps of whatever used to be there — including
    the tutorial's own three moon glows, which travel with it.

Rooms are matched to their decorations by POSITION, not by name: the light node
names carry a `RoomN` suffix that is an old INDEX and has been stale since the
last insert (`CeilingRoom1a` stands over Level_2, `MoonGlowRoom1` over Level_3).
Nothing reads those names, and this does not try to fix them.

The tutorial room also has no Exit — nothing led out of it, because nothing led
into it — so this adds one, on the ledge he dashes up to.

And it takes the Rumi trigger OUT of the room that used to grant the dash. That
beat has moved into the tutorial (scripts/dash_tutorial.gd hands the ability over
at the catch), so nothing claims that trigger any more — and an unclaimed
LdtkRumiTrigger is not inert: it locks the player, fades Rumi in and plays its own
one-line version, which here is an EMPTY dialogue banner.

LDtk MUST BE CLOSED. It holds the project in memory and writes it back whole, so
a scripted edit under a running LDtk is reverted silently. This refuses to run.

Usage:  python3 tools/ldtk_move_tutorial_into_run.py            # dry run
        python3 tools/ldtk_move_tutorial_into_run.py --apply
"""
import json
import os
import re
import subprocess
import sys
import uuid

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
LDTK = os.path.join(ROOT, "ldtk/hooshang_claude.ldtk")
WORLD_SCENE = os.path.join(ROOT, "ldtk/Act1World.tscn")
APPLY = "--apply" in sys.argv

TUTORIAL_OLD = 24
TUTORIAL_NEW = 2

MAP = {TUTORIAL_OLD: TUTORIAL_NEW}
for n in range(TUTORIAL_NEW, TUTORIAL_OLD):
    MAP[n] = n + 1

## Where the lesson lands, and what it displaces. Level_1 ends at x=640 and the
## top row is contiguous from there, so the whole row after it moves by the
## tutorial's own width.
TUTORIAL_TO = (640, 160)
ROW_SHIFT = 880

## Which decorations belong to which row. The top row sits at y=160..352 and the
## escape row at y=800..992; the tutorial was parked at y=1408. Generous bands,
## because a lamp hangs above its room and a floor prop stands below it.
TOP_ROW_MAX_Y = 600
SIDING_MIN_Y = 1300
## Only the part of the top row that the tutorial pushes: everything from the
## left edge of the old Level_2 rightwards.
ROW_SHIFT_MIN_X = 640

## The Exit the tutorial never had, on the ledge the dash lands him on. Bottom
## centre, one cell in from the room's right edge — the same placement every
## other room uses, read off Level_1's [312, 176] in a 320-wide room.
EXIT_PX = (872, 88)
EXIT_DEF_UID = 39
EXIT_FIELD_DEF_UID = 40

## The room the dash gift used to live in, by its name AFTER the rename, and the
## entity in it that no longer has an owner.
STALE_TRIGGER_ROOM = "Level_3"
STALE_TRIGGER = "RumiTrigger"

SKIP_DIRS = {".git", ".godot", "builds", "addons", "backups", "node_modules"}
SUFFIXES = (".gd", ".tscn", ".tres", ".md", ".ldtk", ".py", ".cfg", ".json")

## Files whose Level_N text is a RECORD of an older mapping rather than a
## reference to a room. Rewriting them turns the only written account of what a
## migration did into a plausible lie. This script is one of them; so is the
## insert that came before it.
KEEP_VERBATIM = {
    os.path.abspath(__file__),
    os.path.join(ROOT, "tools/ldtk_renumber_rooms.py"),
}

## Exports that name rooms by NUMBER. A rename pass over "Level_N" cannot see
## these, and every one silently points at the wrong room if left behind.
NUMERIC = [
    ("scripts/act1_beats.gd", "@export var collapse_first_room := 14",
                              "@export var collapse_first_room := 15"),
    ("scripts/act1_beats.gd", "@export var collapse_last_room := 23",
                              "@export var collapse_last_room := 24"),
    ("scripts/act1_beats.gd", "@export var glow_rooms: Array[int] = [13, 17, 18, 19]",
                              "@export var glow_rooms: Array[int] = [14, 18, 19, 20]"),
    ("scripts/act1_beats.gd", "@export var ambience_first_room := 13",
                              "@export var ambience_first_room := 14"),
    ("scripts/act1_beats.gd", "@export var ambience_last_room := 22",
                              "@export var ambience_last_room := 23"),
    ("scripts/act1_beats.gd", "@export var brick_first_room := 14",
                              "@export var brick_first_room := 15"),
    # room_number is the index PLUS ONE, and the room the save test walks to has
    # gained one more room ahead of it.
    ("tests/save_test.gd", 'int(card.get("room_number", 0)) == 9',
                           'int(card.get("room_number", 0)) == 10'),
]

PATTERN = re.compile(r"\bLevel_(\d+)\b")


def ldtk_running():
    """Is the LDtk app up?

    Matched on `comm` — the executable path alone — and NOT on the full command
    line. A full-command-line scan matches the shell running this very script,
    because the script's own source contains the string it is looking for, and
    it then refuses to run on a machine where LDtk is closed.
    """
    out = subprocess.run(["ps", "ax", "-o", "comm="],
                         capture_output=True, text=True).stdout
    return any(l.strip().endswith("/LDtk") or l.strip() == "LDtk"
               for l in out.splitlines())


def files():
    for base, dirs, names in os.walk(ROOT):
        dirs[:] = [d for d in dirs if d not in SKIP_DIRS]
        for n in names:
            if n.endswith(SUFFIXES):
                path = os.path.join(base, n)
                if os.path.abspath(path) not in KEEP_VERBATIM:
                    yield path


def remap(text):
    return PATTERN.sub(
        lambda m: "Level_%d" % MAP.get(int(m.group(1)), int(m.group(1))), text)


# ----------------------------------------------------------------- the .ldtk --
#
# Edited as TEXT, not as parsed JSON re-dumped. The project is a 1MB tab-indented
# file with LDtk's own inline compaction (`"defs": { "layers": [`, `"__grid":
# [3,21]`), and a round trip through json.dump comes back 2.4x the size with
# every line changed — functionally fine, unreviewable in a diff, and it would
# bury the handful of numbers this actually changes.


def level_spans(text):
    """(identifier, start, end) for each level object in the file."""
    hits = [(m.group(1), m.start()) for m in
            re.finditer(r'\t\t\t"identifier": "(Level_\d+)",\n\t\t\t"iid"', text)]
    out = []
    for i, (name, start) in enumerate(hits):
        end = hits[i + 1][1] if i + 1 < len(hits) else len(text)
        out.append((name, start, end))
    return out


def move_level(block, dx, dy):
    """Shift one level object: its own worldX/worldY, and the cached world
    position LDtk stores on every entity instance inside it."""
    def bump(m):
        return "%s%d%s%d" % (m.group(1), int(m.group(2)) + dx,
                             m.group(3), int(m.group(4)) + dy)
    block, n = re.subn(
        r'(\t\t\t"worldX": )(-?\d+)(,\n\t\t\t"worldY": )(-?\d+)', bump, block)
    if n != 1:
        raise SystemExit("!! expected one worldX/worldY pair, found %d" % n)
    block = re.sub(r'("__worldX": )(-?\d+)',
                   lambda m: "%s%d" % (m.group(1), int(m.group(2)) + dx), block)
    block = re.sub(r'("__worldY": )(-?\d+)',
                   lambda m: "%s%d" % (m.group(1), int(m.group(2)) + dy), block)
    return block


def exit_entity(px, grid, world):
    """One Exit instance, written the way LDtk writes them (tabs, inline arrays)."""
    return (
        '\t\t\t\t\t\t{\n'
        '\t\t\t\t\t\t\t"__identifier": "Exit",\n'
        '\t\t\t\t\t\t\t"__grid": [%d,%d],\n'
        '\t\t\t\t\t\t\t"__pivot": [0.5,1],\n'
        '\t\t\t\t\t\t\t"__tags": [],\n'
        '\t\t\t\t\t\t\t"__tile": null,\n'
        '\t\t\t\t\t\t\t"__smartColor": "#3FA34D",\n'
        '\t\t\t\t\t\t\t"iid": "%s",\n'
        '\t\t\t\t\t\t\t"width": 16,\n'
        '\t\t\t\t\t\t\t"height": 32,\n'
        '\t\t\t\t\t\t\t"defUid": %d,\n'
        '\t\t\t\t\t\t\t"px": [%d,%d],\n'
        '\t\t\t\t\t\t\t"fieldInstances": [\n'
        '\t\t\t\t\t\t\t\t{\n'
        '\t\t\t\t\t\t\t\t\t"__identifier": "NextRoom",\n'
        '\t\t\t\t\t\t\t\t\t"__type": "String",\n'
        '\t\t\t\t\t\t\t\t\t"__value": null,\n'
        '\t\t\t\t\t\t\t\t\t"__tile": null,\n'
        '\t\t\t\t\t\t\t\t\t"defUid": %d,\n'
        '\t\t\t\t\t\t\t\t\t"realEditorValues": []\n'
        '\t\t\t\t\t\t\t\t}\n'
        '\t\t\t\t\t\t\t],\n'
        '\t\t\t\t\t\t\t"__worldX": %d,\n'
        '\t\t\t\t\t\t\t"__worldY": %d\n'
        '\t\t\t\t\t\t}'
        % (grid[0], grid[1], uuid.uuid4(), EXIT_DEF_UID, px[0], px[1],
           EXIT_FIELD_DEF_UID, world[0], world[1]))


def add_exit(block, px, origin):
    """Append an Exit to this level's Entities layer."""
    i = block.index('"__identifier": "Entities"')
    j = block.index('"entityInstances": [', i) + len('"entityInstances": [')
    grid = (px[0] // 8, px[1] // 8)
    ent = exit_entity(px, grid, (origin[0] + px[0], origin[1] + px[1]))
    # The layer already holds instances, so the new one is a continuation.
    return block[:j] + "\n" + ent + "," + block[j:]


def remove_entity(block, ident):
    """Drop one entity instance from a level.

    Found by its opening brace at six tabs and closed at the first brace back at
    that same indent — LDtk indents an entity's own fields deeper, so the first
    six-tab `}` after the start is this entity's and not a field's."""
    head = '\t\t\t\t\t\t{\n\t\t\t\t\t\t\t"__identifier": "%s",' % ident
    i = block.find(head)
    if i < 0:
        raise SystemExit("!! no %s to remove" % ident)
    close = "\n\t\t\t\t\t\t}"
    j = block.index(close, i) + len(close)
    if block[j:j + 1] == ",":
        j += 1                      # it had a sibling after it
        return block[:i] + block[j:].lstrip("\n")
    # last in the list: take the newline and comma that led into it
    k = block.rfind(",", 0, i)
    return block[:k] + block[j:]


def rewrite_ldtk(text):
    """Rename, move, and give the tutorial a way out. Text in, text out."""
    text = remap(text)
    spans = level_spans(text)
    names = [n for n, _, _ in spans]
    tut = "Level_%d" % TUTORIAL_NEW
    if tut not in names:
        raise SystemExit("!! no %s after the rename — nothing to move" % tut)

    out = []
    moves = []
    for name, start, end in spans:
        block = text[start:end]
        n = int(name.split("_")[1])
        origin = None
        if name == tut:
            m = re.search(r'\t\t\t"worldX": (-?\d+),\n\t\t\t"worldY": (-?\d+)', block)
            was = (int(m.group(1)), int(m.group(2)))
            dx, dy = TUTORIAL_TO[0] - was[0], TUTORIAL_TO[1] - was[1]
            origin = TUTORIAL_TO
        elif TUTORIAL_NEW < n <= MAP[12]:      # the rest of the old top row
            dx, dy = ROW_SHIFT, 0
        else:
            dx, dy = 0, 0
        if (dx, dy) != (0, 0):
            block = move_level(block, dx, dy)
            moves.append((name, dx, dy))
        if origin is not None:
            block = add_exit(block, EXIT_PX, origin)
        if name == STALE_TRIGGER_ROOM:
            block = remove_entity(block, STALE_TRIGGER)
        out.append(block)

    head = text[:spans[0][1]]
    return head + "".join(out), moves


def check_ldtk(text):
    """Parse it back and prove the rooms do not overlap."""
    d = json.loads(text)
    rects = []
    for lv in d["levels"]:
        rects.append((lv["identifier"], lv["worldX"], lv["worldY"],
                      lv["pxWid"], lv["pxHei"]))
    for i in range(len(rects)):
        for j in range(i + 1, len(rects)):
            a, b = rects[i], rects[j]
            if (a[1] < b[1] + b[3] and b[1] < a[1] + a[3]
                    and a[2] < b[2] + b[4] and b[2] < a[2] + a[4]):
                raise SystemExit("!! %s overlaps %s" % (a[0], b[0]))
    def entities(name):
        lv = [l for l in d["levels"] if l["identifier"] == name][0]
        return [e["__identifier"] for l in lv["layerInstances"]
                for e in l.get("entityInstances", [])]
    tut = "Level_%d" % TUTORIAL_NEW
    if "Exit" not in entities(tut):
        raise SystemExit("!! %s still has no Exit" % tut)
    if "PlayerStart" not in entities(tut):
        raise SystemExit("!! %s lost its PlayerStart" % tut)
    if STALE_TRIGGER in entities(STALE_TRIGGER_ROOM):
        raise SystemExit("!! %s still holds the unclaimed %s"
                         % (STALE_TRIGGER_ROOM, STALE_TRIGGER))
    return sorted(rects, key=lambda r: int(r[0].split("_")[1]))


# ------------------------------------------------------ the world's furniture --


def shift_world_scene(text):
    """Move every hand-placed light, window and prop that stands over a room
    that moved. Act1World.tscn positions them in world space and nothing links
    them to a room, so this matches them by where they are."""
    moved = []

    def one(m):
        x, y = float(m.group(1)), float(m.group(2))
        if y >= SIDING_MIN_Y:                       # travels with the tutorial
            dx, dy = TUTORIAL_TO[0] - 8, TUTORIAL_TO[1] - 1408
        elif y < TOP_ROW_MAX_Y and x >= ROW_SHIFT_MIN_X:
            dx, dy = ROW_SHIFT, 0
        else:
            return m.group(0)
        moved.append((x, y, x + dx, y + dy))
        return "position = Vector2(%s, %s)" % (_num(x + dx), _num(y + dy))

    return re.sub(r'position = Vector2\(([-\d.]+), ([-\d.]+)\)', one, text), moved


def _num(v):
    return str(int(v)) if float(v).is_integer() else str(v)


def main():
    if ldtk_running():
        raise SystemExit("!! LDtk is open — close it first. It holds the project"
                         " in memory and writes it back whole, so this would be"
                         " reverted silently.")

    print("== rename ==")
    total = touched = 0
    edits = {}
    for path in sorted(files()):
        try:
            src = open(path).read()
        except (UnicodeDecodeError, OSError):
            continue
        out = remap(src)
        if out == src:
            continue
        if "Level_1_Office" in src and "Level_1_Office" not in out:
            raise SystemExit("!! renamed the Level_1_Office enum in %s" % path)
        hits = len(PATTERN.findall(src))
        total += hits
        touched += 1
        print("  %-46s %d refs" % (os.path.relpath(path, ROOT), hits))
        if os.path.abspath(path) != os.path.abspath(LDTK):
            edits[path] = out

    print("\n== the world grid ==")
    ldtk_out, moves = rewrite_ldtk(open(LDTK).read())
    for name, dx, dy in moves:
        print("  %-10s %+d, %+d" % (name, dx, dy))
    for name, x, y, w, h in check_ldtk(ldtk_out):
        print("  %-10s x=%6d y=%6d  %dx%d" % (name, x, y, w, h))
    edits[LDTK] = ldtk_out

    print("\n== lights, windows and props ==")
    scene_out, moved = shift_world_scene(
        edits.get(WORLD_SCENE) or open(WORLD_SCENE).read())
    print("  %d nodes moved with their rooms" % len(moved))
    edits[WORLD_SCENE] = scene_out

    print("\n== rooms named by number ==")
    for rel, old, new in NUMERIC:
        p = os.path.join(ROOT, rel)
        # From the rename pass's output where there is one — reading the file
        # again here would hand back the pre-rename text and undo it.
        src = edits.get(p) or open(p).read()
        if old not in src:
            print("  !! NOT FOUND in %s: %s" % (rel, old.strip()))
            continue
        print("  %-16s %s\n%s-> %s" % (rel, old.strip(), " " * 19, new.strip()))
        edits[p] = src.replace(old, new, 1)

    print("\n%d level-name references across %d files" % (total, touched))
    if not APPLY:
        print("DRY RUN — nothing written. Re-run with --apply")
        return
    for path, out in sorted(edits.items()):
        open(path, "w").write(out)
    print("APPLIED. Now:")
    print("  rm .godot/imported/hooshang_claude.ldtk-* ldtk/levels/Level_*.scn")
    print("  Godot --headless --path . --import")


if __name__ == "__main__":
    main()
