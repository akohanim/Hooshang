extends Node
var failures: Array[String] = []
func _ready() -> void:
	SaveGame.slot = -1
	LdtkWorld.debug_start_room = "Level_26"
	var world: LdtkWorld = load("res://ldtk/Act1World.tscn").instantiate()
	Screen.set_scene(world)
	for i in 30:
		await get_tree().physics_frame
	var room := world.current_room
	_check(room.find_child("OfficeDawn", true, false) != null, "finale uses dawn in its existing window panes")
	_check(room.find_children("*", "OfficeMoon", true, false).is_empty(), "finale has no moon or stars")
	for name in ["DawnGlowRoom26", "DawnSpillRoom26a", "DawnSpillRoom26b", "SunShaftRoom26"]:
		_check(world.get_node("Lights/" + name).is_visible_in_tree(), name + " is enabled")
	var opening: Node2D
	for r in world.rooms:
		if r.name == "Level_0": opening = r
	_check(not opening.find_children("*", "OfficeMoon", true, false).is_empty(), "opening retains its night moon")
	if DisplayServer.get_name() != "headless":
		world.player.global_position = room.global_position + Vector2(160, 90)
		world.player.freeze()
		world.player.camera.position_smoothing_enabled = false
		world.player.camera.reset_smoothing()
		for i in 15:
			await get_tree().physics_frame
		RenderingServer.force_draw(false)
		var img := Screen.viewport.get_texture().get_image()
		img.resize(1280, 720, Image.INTERPOLATE_NEAREST)
		img.save_png("/tmp/hooshang-finale-dawn.png")
	world._enter_room(opening, true)
	_check(not world.get_node("Lights/SunShaftRoom26").visible, "dawn light turns off outside the finale")
	print("FINALE DAWN TEST: %s" % ("ALL PASS" if failures.is_empty() else str(failures)))
	get_tree().quit(0 if failures.is_empty() else 1)
func _check(ok: bool, message: String) -> void:
	print(("PASS " if ok else "FAIL ") + message)
	if not ok: failures.append(message)
