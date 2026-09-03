import json
import os

def main():
    ldtk_path = "ldtk/hooshang_act1.ldtk"
    if not os.path.exists(ldtk_path):
        print(f"Error: {ldtk_path} not found")
        return

    with open(ldtk_path, "r", encoding="utf-8") as f:
        data = json.load(f)

    # Desired play order:
    #   Level_0 -> Level_1 -> Level_2 -> Level_3 -> Level_4 -> Level_5
    #   -> Level_V1 -> Level_V2 -> Level_V3
    #   -> Level_6 -> Level_7 -> ... -> Level_24
    #
    # The V-levels sort interleaved with the numbered levels (V1 has
    # play_index 1, V2 has 2, V3 has 3), so every link that must skip
    # over a V-level or route into/out of the V-block needs an explicit
    # NextRoom override.
    updates = {
        # Skip V-levels in the numbered run
        "Level_1": "Level_2",
        "Level_2": "Level_3",
        "Level_3": "Level_4",
        # Detour into V-block after Level_5
        "Level_5": "Level_V1",
        # Chain through V-block
        "Level_V1": "Level_V2",
        "Level_V2": "Level_V3",
        # Return to numbered run
        "Level_V3": "Level_6",
    }

    updated_count = 0
    for level in data.get("levels", []):
        lvl_id = level.get("identifier")
        if lvl_id in updates:
            target_room = updates[lvl_id]
            for layer in level.get("layerInstances", []):
                if layer.get("__identifier") == "Entities":
                    for entity in layer.get("entityInstances", []):
                        if entity.get("__identifier") == "Exit":
                            for field in entity.get("fieldInstances", []):
                                if field.get("__identifier") == "NextRoom":
                                    field["__value"] = target_room
                                    print(f"Set NextRoom for Exit in {lvl_id} to {target_room}")
                                    updated_count += 1

    if updated_count > 0:
        with open(ldtk_path, "w", encoding="utf-8") as f:
            json.dump(data, f, indent=4)
        print(f"Successfully updated {updated_count} Exit instances in {ldtk_path}")
    else:
        print("No Exit instances needed modification.")

if __name__ == "__main__":
    main()
