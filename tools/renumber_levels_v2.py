"""One-shot: fold Level_25 and the V1-V4 rooms into the numbered run.

New play order:
  Level_0 .. Level_5, Level_6 (was Level_25), Level_V1..Level_V4,
  Level_7 (was Level_6), Level_8 (was Level_7), ... Level_25 (was Level_24)

Renumbering old Level_6..Level_24 by +1, with old Level_25 landing in the
gap that opens at Level_6, is a rotation over one set of identifiers -- done
as a single in-memory pass (not sequential file-style renames), so there is
no intermediate collision to worry about.

play_index() (scripts/ldtk_world.gd) sorts rooms by the TRAILING DIGITS of
their identifier, and Level_V1..Level_V4 end in 1..4 -- the same digits as
Level_1..Level_4. That means the ARRAY fallback ("next room in sort order")
silently walks Level_1 -> Level_V1 instead of Level_1 -> Level_2 the moment
the V-rooms exist, for every room from Level_1 to Level_6 inclusive. Every
Exit along the seam therefore gets an explicit NextRoom override; nothing
past Level_7 needs one, since no V-room's digit collides with 7-25.
"""
import json
import os

LDTK_PATH = "ldtk/hooshang_act1.ldtk"

# old identifier -> new identifier. Only entries that actually change.
RENAME = {"Level_25": "Level_6"}
for n in range(6, 25):
    RENAME[f"Level_{n}"] = f"Level_{n + 1}"

# Explicit forward wiring for the whole seam (old identifiers on neither
# side collide with anything below Level_7, so nothing past this needs it).
NEXT_ROOM = {
    "Level_1": "Level_2",
    "Level_2": "Level_3",
    "Level_3": "Level_4",
    "Level_4": "Level_5",
    "Level_5": "Level_6",
    "Level_6": "Level_V1",
    "Level_V1": "Level_V2",
    "Level_V2": "Level_V3",
    "Level_V3": "Level_V4",
    "Level_V4": "Level_7",
}


def main() -> None:
    with open(LDTK_PATH, "r", encoding="utf-8") as f:
        data = json.load(f)

    renamed = 0
    for level in data["levels"]:
        old = level["identifier"]
        if old in RENAME:
            new = RENAME[old]
            level["identifier"] = new
            print(f"rename  {old:12s} -> {new}")
            renamed += 1

    wired = 0
    by_ident = {lvl["identifier"]: lvl for lvl in data["levels"]}
    for room_ident, target in NEXT_ROOM.items():
        level = by_ident.get(room_ident)
        if level is None:
            print(f"!! room {room_ident} not found, skipping NextRoom -> {target}")
            continue
        found_exit = False
        for layer in level.get("layerInstances", []):
            if layer.get("__identifier") != "Entities":
                continue
            for entity in layer.get("entityInstances", []):
                if entity.get("__identifier") != "Exit":
                    continue
                found_exit = True
                for field in entity.get("fieldInstances", []):
                    if field.get("__identifier") == "NextRoom":
                        field["__value"] = target
                        print(f"wire    {room_ident:12s} --Exit--> {target}")
                        wired += 1
        if not found_exit:
            print(f"!! room {room_ident} has no Exit entity, skipping -> {target}")

    with open(LDTK_PATH, "w", encoding="utf-8") as f:
        json.dump(data, f, indent=4)

    print(f"\n{renamed} levels renamed, {wired} Exit NextRoom fields wired.")


if __name__ == "__main__":
    main()
