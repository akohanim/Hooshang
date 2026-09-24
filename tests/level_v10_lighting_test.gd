extends Node
## V10 keeps the world's ambient tint through its darkness controller's cycle.

func _ready() -> void:
	SaveGame.slot = -1
	LdtkWorld.debug_start_room = "Level_V10"
	var world: LdtkWorld = load("res://ldtk/Act1World.tscn").instantiate()
	add_child(world)
	for i in 10:
		await get_tree().physics_frame
	var room := world.current_room
	var chamber := room.get_node("DarknessRoom")
	var tint: CanvasModulate = world.get_node("CanvasModulate")
	var failures := 0
	world.player.set_physics_process(false)
	world.player.input_locked = false
	world.player.state = Player.State.IDLE
	chamber.set_physics_process(false)
	for phase in [0, 1, 2, 3]:
		chamber.set("phase", phase)
		chamber.set("presence", float(phase) / 3.0)
		chamber.call("_physics_process", 1.0 / 60.0)
		if not tint.color.is_equal_approx(world._ambient_color):
			failures += 1
			push_error("V10 changed the standard ambient tint in phase %d" % phase)
	var next := world._room_after(room)
	world._enter_room(next, true)
	if not tint.color.is_equal_approx(world.music_room_color if world._room_has_music_puzzle(next) else world._ambient_color):
		failures += 1
		push_error("V10 lighting leaked into the next room")
	print("V10 LIGHTING: %d failures" % failures)
	get_tree().quit(0 if failures == 0 else 1)
