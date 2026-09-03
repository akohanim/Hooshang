import json
import os

def main():
    ldtk_path = "ldtk/hooshang_act1.ldtk"
    if not os.path.exists(ldtk_path):
        print(f"Error: {ldtk_path} not found")
        return

    with open(ldtk_path, "r", encoding="utf-8") as f:
        data = json.load(f)

    changed_count = 0
    # Level_V1's Exit iid that should not be shifted because it was placed correctly with pivot (0,0)
    level_v1_exit_iid = "13abf110-96d0-11f1-9b40-9b4cf24a68a7"

    for level in data.get("levels", []):
        for layer in level.get("layerInstances", []):
            if layer.get("__identifier") == "Entities":
                for entity in layer.get("entityInstances", []):
                    if entity.get("__identifier") == "Exit":
                        iid = entity.get("iid")
                        if iid == level_v1_exit_iid:
                            print(f"Skipping Level_V1 exit {iid}")
                            continue
                        
                        height = entity.get("height", 32)
                        
                        # Shift up by height
                        old_y = entity["px"][1]
                        entity["px"][1] -= height
                        entity["__worldY"] -= height
                        entity["__grid"][1] = entity["px"][1] // 8
                        
                        print(f"Shifted Exit in {level.get('identifier')} from y={old_y} to y={entity['px'][1]}")
                        changed_count += 1

    if changed_count > 0:
        with open(ldtk_path, "w", encoding="utf-8") as f:
            json.dump(data, f, indent=4)
        print(f"Successfully updated {changed_count} Exit instances in {ldtk_path}")
    else:
        print("No Exit instances needed modification.")

if __name__ == "__main__":
    main()
