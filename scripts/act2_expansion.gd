extends Node
## Instantiate reusable room dressing after the imported entities are ready.
const GARDEN := preload("res://scenes/props/backdrop/sky_gardens/SkyGarden.tscn")
func _ready() -> void:
	call_deferred("_dress")
func _dress() -> void:
	var world := get_parent() as LdtkWorld
	for room in world.rooms:
		if str(room.fields.get("wing", "")).begins_with("Escape"):
			room.add_child(preload("res://scenes/props/friendly_chase/ChaseRoom.tscn").instantiate())
		if str(room.name) == "Level_2":
			room.add_child(preload("res://scenes/props/carpet_lesson/CarpetLesson.tscn").instantiate())
		if str(room.fields.get("wing", "")).begins_with("Castle"):
			room.add_child(preload("res://scenes/props/castle/CastleRoom.tscn").instantiate())
	var recipes: Array = JSON.parse_string(FileAccess.get_file_as_string("res://resources/levels/act2_expansion.json"))
	for recipe: Dictionary in recipes:
		for room in world.rooms:
			if str(room.name) == recipe.name:
				room.set_meta("return_at_spawn_edge", true)
				var garden := GARDEN.instantiate()
				garden.recipe = recipe.duplicate(true)
				# The garden now leads into the LDtk-authored prison mission.
				if world.has_method("is_prison"):
					garden.recipe["final"] = false
				room.add_child(garden)
