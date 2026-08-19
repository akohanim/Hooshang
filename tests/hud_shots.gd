extends Node
## Dev capture harness for the two HUD counters: the death count top-right, and
## the lemon's flight from where it was picked up into the counter on the
## left. Runs WINDOWED so 2D actually rasterises.
##
## Captures the ROOT viewport, not Screen.viewport — the counters deliberately
## live outside the game's sub-viewport so they draw at the window's real
## resolution, and a sub-viewport grab would miss them entirely.
## Usage: Godot --path . res://tests/hud_shots.tscn

const OUT := "/private/tmp/claude-501/-Users-ari-Hooshang-claude/b22aa35b-7d00-4a4c-9021-c09146d39912/scratchpad"

var world: LdtkWorld


func _ready() -> void:
	# Start away from room 1. Act1Beats only plays the waking scene where he
	# actually wakes, so this skips the black fade AND the dialogue banner —
	# which sits across the top of the screen, exactly over both counters.
	LdtkWorld.debug_start_room = "Level_3"
	world = load("res://ldtk/Act1World.tscn").instantiate()
	Screen.set_scene(world)
	for i in 30:
		if not world.rooms.is_empty():
			break
		await get_tree().process_frame
	var player := world.player
	player.input_locked = true
	(player.get_node("Camera2D") as Camera2D).position_smoothing_enabled = false
	await _frames(30)

	await _shoot_deaths(player)
	await _shoot_fruit(player)
	get_tree().quit()


func _shoot_deaths(player: Node2D) -> void:
	Deaths.reset()
	await _save("hud_deaths_0")
	for i in 3:
		player.die()
		await _frames(4)
		await _save("hud_deaths_%d" % (i + 1))
		player.respawn(player.global_position)
		await _frames(4)
	print("  deaths total = %d" % Deaths.total)


func _shoot_fruit(player: Node2D) -> void:
	var fruit := get_tree().get_first_node_in_group("lemon") as Node2D
	if fruit == null:
		print("no lemon in the world")
		return
	Collectibles.reset()
	# Stand in its room so the camera is actually looking at it — but off to one
	# side, or the pickup fires before anything has been captured.
	world._enter_room(_room_holding(fruit), true)
	var spot := fruit.global_position
	player.global_position = spot + Vector2(-40, 0)
	await _frames(20)
	await _save("hud_fruit_0")
	print("  fruit at %s, shown=%d total=%d" % [
		spot, Collectibles._shown, Collectibles.total])
	player.global_position = spot  # walk into it: the real pickup path
	await _frames(2)
	for i in 6:
		await _frames(5)
		await _save("hud_fruit_%d" % (i + 1))
	await _frames(20)
	await _save("hud_fruit_7_landed")
	print("  after flight: shown=%d total=%d" % [Collectibles._shown, Collectibles.total])


func _room_holding(n: Node) -> Node2D:
	var p := n.get_parent()
	while p != null:
		if world.rooms.has(p):
			return p
		p = p.get_parent()
	return world.current_room


func _save(name: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("%s/%s.png" % [OUT, name])
	print("saved %s" % name)


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame
