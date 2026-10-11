extends Node
## Debug entry, followed by actual inputs through all four rises and the exit.
func _ready() -> void:
	SaveGame.unbind()
	LdtkWorld.debug_start_room = "Act_2_Level_17"
	Screen.load_scene("res://ldtk/Act2World.tscn")
	for i in 30: await get_tree().physics_frame
	var driver = load("res://tests/chase_alley_driver.gd").new()
	driver.world = Screen.current
	driver.world.player._ledge_cooldown = 3600
	add_child(driver)
	var ok: bool = await driver.traverse()
	get_tree().quit(0 if ok else 1)
