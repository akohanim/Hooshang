#!/usr/bin/env python3
"""Put the dash tutorial into the run as room 2.

  Level_24 (the dash-tutorial room)  ->  Level_2
  Level_2 .. Level_23                ->  Level_3 .. Level_24
  Level_0, Level_1                   unchanged

ONE SIMULTANEOUS MAPPING, never a sequence of renames. Done step by step,
Level_2 -> Level_3 overwrites the real Level_3 before it has moved.

THE LAYOUT IS ALREADY DONE, BY HAND, and this does not touch it. The room was
authored off in a siding below the world and has been dragged into the top row
in LDtk — rooms 0 and 1 moved 880px left to open the slot, and the tutorial now
sits between room 1 and the rest of the row. That matters because a room
transition is a camera PAN across the gap between two rooms (`_slide_to_room`),
not a cut, so a room that plays second has to BE second in the world. This
script only checks the layout still holds and does the parts a mouse cannot:

  - the rename, which is what actually sets the play order. Level identifiers
    ARE the order in this project (CLAUDE.md) and `LdtkWorld.rooms` is sorted by
    them, so the room can sit anywhere on the grid and still play last.
  - the Exit the tutorial has never had, on the ledge the dash lands him on.
    Nothing led out of the room because nothing led into it.
  - taking the Rumi trigger OUT of the room that used to grant the dash. That
    beat has moved into the tutorial (scripts/dash_tutorial.gd hands the ability
    over at the catch), so nothing claims that trigger any more — and an
    unclaimed LdtkRumiTrigger is not inert: it locks the player, fades Rumi in,
    and plays its own one-line version, which here is an EMPTY banner.
  - the exports that name rooms by NUMBER, which a Level_N rewrite cannot see.

The hand-placed lights, windows and props that stand over the rooms that moved
were shifted with them in a separate pass — Act1World.tscn positions those in
WORLD space and nothing links them to a room, so they do not follow it.

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
APPLY = "--apply" in sys.argv

TUTORIAL_OLD = 24
TUTORIAL_NEW = 2

MAP = {TUTORIAL_OLD: TUTORIAL_NEW}
for n in range(TUTORIAL_NEW, TUTORIAL_OLD):
    MAP[n] = n + 1

## The Exit the tutorial never had, in room-local pixels, on the ledge the dash
## lands him on. Bottom centre, one cell in from the room's right edge — the
## same placement every other room uses, read off Level_1's [312, 176] in a
## 320-wide room.
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
# bury the handful of things this actually changes.


def level_spans(text):
    """(identifier, start, end) for each level object in the file."""
    hits = [(m.group(1), m.start()) for m in
            re.finditer(r'\t\t\t"identifier": "(Level_\d+)",\n\t\t\t"iid"', text)]
    out = []
    for i, (name, start) in enumerate(hits):
        end = hits[i + 1][1] if i + 1 < len(hits) else len(text)
        out.append((name, start, end))
    return out


def origin_of(block):
    m = re.search(r'\t\t\t"worldX": (-?\d+),\n\t\t\t"worldY": (-?\d+)', block)
    return int(m.group(1)), int(m.group(2))


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


def add_exit(block, px):
    """Append an Exit to this level's Entities layer."""
    origin = origin_of(block)
    i = block.index('"__identifier": "Entities"')
    j = block.index('"entityInstances": [', i) + len('"entityInstances": [')
    ent = exit_entity(px, (px[0] // 8, px[1] // 8),
                      (origin[0] + px[0], origin[1] + px[1]))
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
        return block[:i] + block[j + 1:].lstrip("\n")
    # last in the list: take the comma that led into it as well
    return block[:block.rfind(",", 0, i)] + block[j:]


def rewrite_ldtk(text):
    """Rename, and give the tutorial a way out. Text in, text out."""
    text = remap(text)
    spans = level_spans(text)
    tut = "Level_%d" % TUTORIAL_NEW
    if tut not in [n for n, _, _ in spans]:
        raise SystemExit("!! no %s after the rename" % tut)

    out = []
    for name, start, end in spans:
        block = text[start:end]
        if name == tut:
            block = add_exit(block, EXIT_PX)
        if name == STALE_TRIGGER_ROOM:
            block = remove_entity(block, STALE_TRIGGER)
        out.append(block)
    return text[:spans[0][1]] + "".join(out)


def check_ldtk(text):
    """Parse it back, and prove the world the mouse laid out still holds."""
    d = json.loads(text)
    rects = [(lv["identifier"], lv["worldX"], lv["worldY"], lv["pxWid"], lv["pxHei"])
             for lv in d["levels"]]
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
    for want in ("Exit", "PlayerStart"):
        if want not in entities(tut):
            raise SystemExit("!! %s has no %s" % (tut, want))
    if STALE_TRIGGER in entities(STALE_TRIGGER_ROOM):
        raise SystemExit("!! %s still holds the unclaimed %s"
                         % (STALE_TRIGGER_ROOM, STALE_TRIGGER))

    # The rooms that play one after the other should also SIT one after the
    # other, or their transition is a flight across the map. Reported rather
    # than enforced: the escape row deliberately runs right to left.
    order = sorted(rects, key=lambda r: int(r[0].split("_")[1]))
    gaps = []
    for a, b in zip(order, order[1:]):
        if a[2] == b[2] and a[1] + a[3] != b[1]:
            gaps.append("%s -> %s" % (a[0], b[0]))
    return order, gaps


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

    print("\n== the .ldtk ==")
    ldtk_out = rewrite_ldtk(open(LDTK).read())
    order, gaps = check_ldtk(ldtk_out)
    for name, x, y, w, h in order:
        print("  %-10s x=%6d y=%6d  %dx%d" % (name, x, y, w, h))
    for g in gaps:
        print("  !! not side by side: %s" % g)
    edits[LDTK] = ldtk_out

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
