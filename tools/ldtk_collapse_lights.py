#!/usr/bin/env python3
"""Tune the ceiling panels of the ESCAPE rooms (14-17) for a building coming down.

The outbound office is lit by fixtures that work. These four rooms are the same
building after the encounter, with the lights failing — so the panels here are
retuned as a set rather than one at a time, and the set is the point: a corridor
where every fixture flickers the same way reads as one effect switched on, not
as a building losing power.

FIVE PERSONALITIES, laid along the room in PLAY ORDER (these rooms are authored
right to left, so that is descending x — checked from PlayerStart vs Exit, not
assumed). BOTH ENDS ARE ANCHORS and the failures live in between:

    anchor   steady. The light he can trust. The first panel he meets and the
             last one before the exit are always this, which is what keeps the
             room navigable no matter how bad the middle of it looks.

             The last one is not decoration. Cycling the roles straight through
             put `failing` (pool 0.55) at the exit end of Level_15, and measured,
             that stretch fell from mean 39.2 to 21.6 — dimmer than it was on the
             way IN, at the one place he is looking for a door.
    sputter  deep, slow dropouts — the one that keeps nearly dying.
    buzz     shallow, fast. A tube that is going, but not yet gone.
    motion   dark until he comes near. Emergency lighting waking as he passes.
    failing  nearly gone: dim, slow, deep. Scenery, not a light to move by.

WHY THE SPEEDS ARE ALL DIFFERENT. LampFixture starts every fixture's flicker
clock at _t = 0, so two panels given the same FlickerSpeed pulse in EXACTLY the
same phase for the whole room — a synchronised strobe, which reads as one effect
rather than as a dozen separate failures. Distinct, non-harmonic speeds are the
only phase control the prop has (there is no phase field), so they drift apart
within a second of the room loading.

POOLDROP IS DERIVED, BUT ONLY WHERE NOBODY HAS SET IT. It is geometry — how far
below the ceiling a room's pool has to fall to land where he walks — so an
authored value is left alone. An UNTOUCHED one is a different thing: the entity
default is 50, and in a room whose floor is 172px below the panels that leaves
the pool 122px in the air, lighting the ceiling and nothing else. So a panel
still sitting on the default gets 58% of its own room's panel-to-floor distance,
which is not a number picked to taste — it reproduces the 100 the author tuned
Level_14 to by hand, in a room with exactly that geometry.

PanelOffset is never touched: which cell of the run is the lit one is a
composition choice, and it has no wrong default.

LDTK MUST BE CLOSED.

Usage:  python3 tools/ldtk_collapse_lights.py            # dry run
        python3 tools/ldtk_collapse_lights.py --apply
"""
import copy
import json
import os
import re
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from ldtk_add_ceiling_tile import array_end, ldtk_running

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
LDTK = os.path.join(ROOT, "ldtk", "hooshang_act1.ldtk")
APPLY = "--apply" in sys.argv

ROOMS = ["Level_14", "Level_15", "Level_16", "Level_17"]
ENTITY = "CeilingPanel"

## Fields this pass owns. Anything not named here is left exactly as authored.
OWNED = ["PanelEnergy", "PoolEnergy", "PoolScale",
         "FlickerAmount", "FlickerSpeed", "MotionRange", "MotionFade"]

## PanelEnergy, PoolEnergy, PoolScale, FlickerAmount, FlickerSpeed,
## MotionRange, MotionFade.
##
## The energies are deliberately a little above the old flat 1.4: flicker eats
## brightness on average (a fixture at FlickerAmount a averages 1 - a/2 of its
## nominal pool), so leaving them alone would have made the whole row dimmer
## rather than more alive.
ROLES = [
    ("anchor",  dict(PanelEnergy=1.40, PoolEnergy=1.25, PoolScale=2.0,
                     FlickerAmount=0.0,  FlickerSpeed=14.0,
                     MotionRange=0.0, MotionFade=0.25)),
    ("sputter", dict(PanelEnergy=1.50, PoolEnergy=1.35, PoolScale=1.9,
                     FlickerAmount=0.92, FlickerSpeed=6.5,
                     MotionRange=0.0, MotionFade=0.25)),
    ("failing", dict(PanelEnergy=0.70, PoolEnergy=0.55, PoolScale=1.6,
                     FlickerAmount=0.97, FlickerSpeed=4.5,
                     MotionRange=0.0, MotionFade=0.25)),
    ("motion",  dict(PanelEnergy=1.60, PoolEnergy=1.50, PoolScale=2.1,
                     FlickerAmount=0.35, FlickerSpeed=13.0,
                     MotionRange=110.0, MotionFade=0.30)),
    ("buzz",    dict(PanelEnergy=1.35, PoolEnergy=1.20, PoolScale=1.9,
                     FlickerAmount=0.45, FlickerSpeed=18.0,
                     MotionRange=0.0, MotionFade=0.25)),
]
## ORDER MATTERS, and not for tidiness. Both ends are anchors, so a five-panel
## room only ever shows THREE failures — whichever three come first in this list.
## sputter, failing, motion is deliberately that three: a light that keeps nearly
## dying, one that has, and one that wakes as he passes. Putting buzz third
## instead traded the dead fixture for a shallower version of the first one.

## One fieldInstance, which LDtk writes as exactly one line. Matched to the END
## OF THE LINE rather than by describing realEditorValues, because that value
## nests: `[{ "id": "V_Float", "params": [100] }]`. A non-greedy `\[.*?\]` stops
## at the INNER bracket, so an already-overridden field matched only half its own
## line and the replacement left `] }` stranded behind it — a file that no longer
## parsed, from a regex that looked right.
FIELD_LINE = re.compile(
    r'^(?P<indent>\t*)\{ "__identifier": "(?P<name>\w+)", "__type": "Float", '
    r'"__value": (?P<value>[^,]+), "__tile": null, "defUid": (?P<uid>\d+), '
    r'"realEditorValues": (?P<rev>.*?) \}(?P<comma>,?)$', re.M)


def num(v):
    """LDtk writes 100 rather than 100.0, and 1.6 as 1.6."""
    return int(v) if float(v).is_integer() else round(float(v), 4)


## How far down the pool sits, as a fraction of panel-to-floor. Reproduces the
## 100 Level_14 was hand-tuned to over its own 172px drop.
DROP_SHARE = 0.58


def _floor_y(level, below_y):
    """Top of the lowest thing he can stand on, in room px.

    BELOW_Y matters: the search is bottom-up for the lowest mostly-solid row,
    and without it a room whose only full-width rows are its CEILING answers with
    the ceiling — Level_17 did exactly that, reporting a floor 4px above the
    panels and a negative drop.

    Falls back to the lowest row with ANY solid in it, which is what a shaft room
    like Level_17 needs: it has no floor, just platforms scattered down it, and
    the lowest of those is the thing the light should still be reaching."""
    for layer in level["layerInstances"]:
        if layer["__identifier"] != "Collisions":
            continue
        w, h, cs = layer["__cWid"], layer["__cHei"], layer["intGridCsv"]
        for test in (lambda r: sum(1 for v in r if v) > w * 0.5, any):
            for y in range(h - 1, -1, -1):
                if y * 8 > below_y and test(cs[y * w:(y + 1) * w]):
                    return y * 8
    return None


def _drop_for(entity, level, default_drop):
    """A PoolDrop for a panel that has none of its own, or None to leave it."""
    current = None
    for fi in entity["fieldInstances"]:
        if fi["__identifier"] == "PoolDrop":
            current = fi["__value"]
    # Authored: somebody chose this, and it is not ours to second-guess.
    if current is None or float(current) != float(default_drop):
        return None
    floor_y = _floor_y(level, entity["px"][1])
    if floor_y is None:
        return None
    gap = floor_y - entity["px"][1]
    if gap <= 0:
        return None
    return float(round(gap * DROP_SHARE / 5.0) * 5)


def _role_for(i, total):
    """Which personality the i-th panel in play order gets.

    Ends are anchors; everything between them cycles the four failures. A room
    with one or two panels is all anchor, which is the right answer — there is
    nothing to alternate against."""
    if i == 0 or i == total - 1:
        return ROLES[0]
    return ROLES[1 + (i - 1) % (len(ROLES) - 1)]


def play_order(level):
    """Panels in the order he meets them. These rooms are authored right to
    left, but that is READ off the level rather than assumed — an author who
    flips a room should not silently get the pattern backwards."""
    start = end = None
    panels = []
    for layer in level["layerInstances"]:
        if layer["__type"] != "Entities":
            continue
        for e in layer["entityInstances"]:
            if e["__identifier"] == "PlayerStart":
                start = e["px"][0]
            elif e["__identifier"] == "Exit":
                end = e["px"][0]
            elif e["__identifier"] == ENTITY:
                panels.append(e)
    backwards = start is not None and end is not None and start > end
    panels.sort(key=lambda e: e["px"][0], reverse=backwards)
    return panels, ("right-to-left" if backwards else "left-to-right")


def main():
    if ldtk_running():
        raise SystemExit("!! LDtk is open — close it first, or it will write "
                         "the project back over this edit.")
    raw = open(LDTK).read()
    doc = json.loads(raw)

    default_drop = None
    for e in doc["defs"]["entities"]:
        if e["identifier"] != ENTITY:
            continue
        for f in e["fieldDefs"]:
            if f["identifier"] == "PoolDrop":
                default_drop = f["defaultOverride"]["params"][0]
    if default_drop is None:
        raise SystemExit("!! %s has no PoolDrop default to compare against" % ENTITY)

    plan = {}          # iid -> (room, role, values)
    for level in doc["levels"]:
        if level["identifier"] not in ROOMS:
            continue
        panels, direction = play_order(level)
        print("  %-9s %d panels, %s" % (level["identifier"], len(panels), direction))
        if not panels:
            print("             (none placed — nothing to tune here)")
            continue
        for i, e in enumerate(panels):
            role, shared = _role_for(i, len(panels))
            values = dict(shared)          # copied: PoolDrop differs per room
            drop = _drop_for(e, level, default_drop)
            if drop is not None:
                values["PoolDrop"] = drop
            plan[e["iid"]] = (level["identifier"], role, values)
            print("             x=%-4d %-8s pool %.2f  flicker %.2f @ %.1f%s%s"
                  % (e["px"][0], role, values["PoolEnergy"],
                     values["FlickerAmount"], values["FlickerSpeed"],
                     "  motion %.0fpx" % values["MotionRange"]
                     if values["MotionRange"] else "",
                     "  drop %.0f (was default)" % values["PoolDrop"]
                     if "PoolDrop" in values else ""))
    if not plan:
        raise SystemExit("!! no %s found in %s — nothing to do." % (ENTITY, ROOMS))

    out = raw
    for iid in sorted(plan, key=lambda i: out.index('"iid": "%s"' % i), reverse=True):
        _room, _role, values = plan[iid]
        pos = out.index('"iid": "%s"' % iid)
        # The entity's own fieldInstances array, found by MATCHING BRACKETS
        # rather than by looking for a closing "]" at a guessed indentation —
        # the indent varies with nesting and the guess sliced through the middle
        # of the array, which produced a file that no longer parsed.
        head = out.index('"fieldInstances": [', pos)
        tail = array_end(out, head)
        span = out[head:tail]

        def rewrite(m):
            name = m.group("name")
            if name not in values:
                return m.group(0)
            v = num(values[name])
            return ('%s{ "__identifier": "%s", "__type": "Float", "__value": %s, '
                    '"__tile": null, "defUid": %s, "realEditorValues": '
                    '[{ "id": "V_Float", "params": [%s] }] }%s'
                    % (m.group("indent"), name, v, m.group("uid"), v,
                       m.group("comma")))

        out = out[:head] + FIELD_LINE.sub(rewrite, span) + out[tail:]

    # Prove it: parse both, and check that exactly the intended instances moved,
    # that only OWNED fields on them changed, and that the editor's own copy of
    # each value agrees with the value — a mismatch there shows in LDtk as the
    # field reading "Default" while the game uses the number.
    before, after = json.loads(raw), json.loads(out)

    def fields(d):
        m = {}
        for lv in d["levels"]:
            for L in lv["layerInstances"]:
                if L["__type"] != "Entities":
                    continue
                for e in L["entityInstances"]:
                    m[e["iid"]] = {f["__identifier"]: (f["__value"], f["realEditorValues"])
                                   for f in e["fieldInstances"]}
        return m

    fa, fb = fields(before), fields(after)
    if set(fa) != set(fb):
        raise SystemExit("!! an entity appeared or vanished")
    changed = {i for i in fa if fa[i] != fb[i]}
    # SUBSET, not equality. Demanding that every planned panel CHANGED is wrong
    # the second time this is run: a panel that already holds the role it is
    # being given is correct, not a failure, and the equality version aborted the
    # whole pass over it — silently, because the error went to a filtered grep
    # and the run before it stayed live in the game.
    stray = changed - set(plan)
    if stray:
        raise SystemExit("!! instances changed that were not planned: %s" % stray)
    # What matters is where they ENDED, so check the plan and not the diff.
    for iid in plan:
        wanted = plan[iid][2]
        for name, (val, rev) in fb[iid].items():
            # Keyed off what this INSTANCE was planned to get, not a fixed list:
            # PoolDrop is set on some panels and deliberately left on others, and
            # a global list cannot tell those two apart.
            if name not in wanted:
                if fa[iid][name] != (val, rev):
                    raise SystemExit("!! %s changed on %s, and it is not ours"
                                     % (name, iid))
                continue
            want = num(wanted[name])
            if val != want:
                raise SystemExit("!! %s came out %s, wanted %s" % (name, val, want))
            if not rev or rev[0].get("params", [None])[0] != want:
                raise SystemExit("!! %s's editor value disagrees with its value"
                                 % name)
    # And nothing outside those levels' entity layers moved at all.
    sa, sb = copy.deepcopy(before), copy.deepcopy(after)
    for d in (sa, sb):
        for lv in d["levels"]:
            for L in lv["layerInstances"]:
                if L["__type"] == "Entities":
                    L["entityInstances"] = None
    if sa != sb:
        raise SystemExit("!! something outside the entity layers moved")
    print("\nverified: %d panels retuned, nothing else touched" % len(changed))

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
