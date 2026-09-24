extends Node
## Instantiate reusable room dressing after the imported entities are ready.
const GARDEN := preload("res://scenes/props/backdrop/sky_gardens/SkyGarden.tscn")
func _ready() -> void:
	call_deferred("_dress")
func _dress() -> void:
	var world := get_parent() as LdtkWorld
	var recipes: Array = JSON.parse_string(FileAccess.get_file_as_string("res://resources/levels/act2_expansion.json"))
	for recipe: Dictionary in recipes:
		for room in world.rooms:
			if str(room.name) == recipe.name:
				room.set_meta("return_at_spawn_edge", true)
				var garden := GARDEN.instantiate()
				garden.recipe = recipe
				room.add_child(garden)
