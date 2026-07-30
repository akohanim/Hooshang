#!/usr/bin/env python3
"""Ensures the entity definitions Godot's import hooks expect exist in the
LDtk project. IDEMPOTENT — safe to run any number of times.

WHY THIS IS A SCRIPT: LDtk keeps the whole project in memory and rewrites the
entire file on save, so any edit made on disk while LDtk is open is silently
reverted the next time you save from that session. That has already eaten
hand-made edits twice. Rather than hand-edit again, run this — and if a save
ever does wipe a definition, just run it again.

    python3 tools/ldtk_entities.py

Entities that Godot expects (see scripts/ldtk_entities_post_import.gd):
    PlayerStart  Door  Checkpoint  RumiTrigger  Hazard   (authored by hand)
    Exit         -> room exit / two-way door
    MusicNote    -> solid musical tile, NoteIndex 1-5
"""
import json
import os
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
LDTK = os.path.join(ROOT, "ldtk", "hooshang_claude.ldtk")


def field_str(identifier, uid, doc=""):
    return _field(identifier, uid, "F_String", "String", doc)


def field_int(identifier, uid, doc="", vmin=None, vmax=None):
    f = _field(identifier, uid, "F_Int", "Int", doc)
    f["min"] = vmin
    f["max"] = vmax
    return f


def _field(identifier, uid, ftype, shown, doc):
    return {
        "identifier": identifier, "doc": doc or None,
        "__type": shown, "uid": uid, "type": ftype,
        "isArray": False, "canBeNull": True,
        "arrayMinLength": None, "arrayMaxLength": None,
        "editorDisplayMode": "NameAndValue", "editorDisplayScale": 1,
        "editorDisplayPos": "Above", "editorLinkStyle": "StraightArrow",
        "editorDisplayColor": None, "editorAlwaysShow": False,
        "editorShowInWorld": True, "editorCutLongValues": True,
        "editorTextSuffix": None, "editorTextPrefix": None,
        "useForSmartColor": False, "exportToToc": False, "searchable": False,
        "defaultOverride": None, "textLanguageMode": None,
        "symmetricalRef": False, "autoChainRef": True,
        "allowOutOfLevelRef": True, "allowedRefs": "OnlySame",
        "allowedRefsEntityUid": None, "allowedRefTags": [],
        "tilesetUid": None, "regex": None, "acceptFileTypes": None,
        "min": None, "max": None,
    }


def entity(identifier, uid, w, h, color, pivot, doc, fields):
    return {
        "identifier": identifier, "uid": uid, "tags": [],
        "exportToToc": False, "allowOutOfBounds": False, "doc": doc,
        "width": w, "height": h,
        "resizableX": False, "resizableY": False,
        "minWidth": None, "maxWidth": None, "minHeight": None, "maxHeight": None,
        "keepAspectRatio": False,
        "tileOpacity": 1, "fillOpacity": 0.7, "lineOpacity": 1, "hollow": False,
        "color": color, "renderMode": "Rectangle", "showName": True,
        "tilesetId": None, "tileRenderMode": "FitInside",
        "tileRect": None, "uiTileRect": None, "nineSliceBorders": [],
        "maxCount": 0, "limitScope": "PerLevel", "limitBehavior": "PreventAdding",
        "pivotX": pivot[0], "pivotY": pivot[1],
        "fieldDefs": fields,
    }


def build(uid):
    """Definitions to ensure, as {identifier: factory(uid) -> (def, uids_used)}."""
    return {
        "Exit": lambda u: (entity(
            "Exit", u, 16, 32, "#3FA34D", (0.5, 1.0),
            "Room exit / two-way door. Touching it slides to the next room; "
            "walking back into the edge you came in through returns you. "
            "Leave NextRoom blank to use the next room by world position.",
            [field_str("NextRoom", u + 1,
                       "Optional: room identifier to jump to. "
                       "Blank = next room by world position.")]), 2),
    }


# The five musical tiles are five SEPARATE entities rather than one entity with
# a NoteIndex field. An LDtk entity's colour lives on its DEFINITION, not per
# instance, so a single shared definition renders every tile identically in the
# editor — and every instance whose field you forget to fill silently collapses
# to the same note, which is exactly how the first attempt failed. One entity
# per note means nothing to fill in and each one looks like what it is.
NOTE_COLORS = ["#C43E3E", "#D6842A", "#56AA4E", "#3E80D0", "#9658C8"]


def note_entities(uid, tileset_uid):
    """MusicNote1..MusicNote5, each showing its real tile art in the editor."""
    out = {}
    for i in range(1, 6):
        def make(u, idx=i):
            e = entity(
                "MusicNote%d" % idx, u, 16, 16, NOTE_COLORS[idx - 1], (0.5, 0.5),
                "Solid musical tile, one cell — note %d of 5. Step on it or "
                "head-butt it from below to sound it. Hit 1..5 in order to "
                "earn the glow; a wrong one restarts the run." % idx,
                [])
            if tileset_uid is not None:
                e["renderMode"] = "Tile"
                e["tilesetId"] = tileset_uid
                rect = {"tilesetUid": tileset_uid,
                        "x": (idx - 1) * 16, "y": 0, "w": 16, "h": 16}
                e["tileRect"] = rect
                e["uiTileRect"] = rect
            return e, 1
        out["MusicNote%d" % i] = make
    return out


def ensure_note_tileset(d, uid):
    """Tileset for the 5-tile icon strip, so LDtk draws the actual art."""
    for t in d["defs"]["tilesets"]:
        if t["identifier"] == "MusicNotes":
            return t["uid"], uid
    d["defs"]["tilesets"].append({
        "__cWid": 5, "__cHei": 1,
        "identifier": "MusicNotes", "uid": uid,
        "relPath": "art/note_strip.png",
        "pxWid": 80, "pxHei": 16,
        "tileGridSize": 16, "spacing": 0, "padding": 0,
        "tags": [], "tagsSourceEnumUid": None, "enumTags": [],
        "customData": [], "savedSelections": [],
        "cachedPixelData": None, "embedAtlas": None,
    })
    print("  ADDED   tileset MusicNotes")
    return uid, uid + 1


def migrate_legacy_notes(d):
    """The first design was one `MusicNote` entity + a NoteIndex field. Any
    already-placed instances are converted to MusicNote1..5 in left-to-right
    order per level, so an existing row of tiles keeps working instead of all
    collapsing to note 1. Rearrange them afterwards however you like."""
    defs = {e["identifier"]: e for e in d["defs"]["entities"]}
    legacy = defs.get("MusicNote")
    if legacy is None:
        return 0
    moved = 0
    for lvl in d["levels"]:
        for layer in lvl.get("layerInstances", []) or []:
            if layer["__type"] != "Entities":
                continue
            olds = [e for e in layer["entityInstances"]
                    if e["__identifier"] == "MusicNote"]
            olds.sort(key=lambda e: e["px"][0])
            for i, inst in enumerate(olds[:5]):
                target = defs.get("MusicNote%d" % (i + 1))
                if target is None:
                    continue
                inst["__identifier"] = target["identifier"]
                inst["defUid"] = target["uid"]
                inst["fieldInstances"] = []
                inst["__tags"] = []
                inst["__tile"] = target.get("tileRect")
                inst["__smartColor"] = target["color"]
                moved += 1
    if moved:
        # drop the now-unused single-entity definition
        d["defs"]["entities"] = [e for e in d["defs"]["entities"]
                                 if e["identifier"] != "MusicNote"]
        print("  MIGRATED %d placed MusicNote -> MusicNote1..5 (by x order)" % moved)
    return moved


def main():
    if not os.path.exists(LDTK):
        sys.exit("no LDtk project at %s" % LDTK)
    with open(LDTK) as f:
        d = json.load(f)

    uid = max(d.get("nextUid", 1), 1)
    changed = False

    tileset_uid, uid = ensure_note_tileset(d, uid)
    if tileset_uid == uid - 1:
        changed = True

    wanted = build(uid)
    wanted.update(note_entities(uid, tileset_uid))
    for name, make in wanted.items():
        if name in {e["identifier"] for e in d["defs"]["entities"]}:
            print("  ok      %s (already present)" % name)
            continue
        e, used = make(uid)
        d["defs"]["entities"].append(e)
        uid += used
        changed = True
        print("  ADDED   %s" % name)

    if migrate_legacy_notes(d):
        changed = True

    if not changed:
        print("nothing to do — all definitions present")
        return
    d["nextUid"] = uid
    with open(LDTK, "w") as f:
        json.dump(d, f, indent=2)
    print("\nwrote %s" % os.path.relpath(LDTK, ROOT))
    print("If LDtk is OPEN, quit it WITHOUT saving and reopen, or its in-memory\n"
          "copy will overwrite this. Re-run this script if that happens.")


if __name__ == "__main__":
    main()
