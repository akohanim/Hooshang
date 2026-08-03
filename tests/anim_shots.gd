extends Node
## Dev capture harness for the two animations Rumi and the note tiles own:
## the light Rumi hands over, and the pads' resting/sounding glow. Runs
## WINDOWED so 2D actually rasterises.
## Usage: Godot --path . res://tests/anim_shots.tscn

const OUT := "/private/tmp/claude-501/-Users-ari-Hooshang-claude/b22aa35b-7d00-4a4c-9021-c09146d39912/scratchpad"

var world: LdtkWorld


func _ready() -> void:
	# Into the game SubViewport, not this node — anything else is hidden behind
	# Screen's (empty, black) container and every capture comes back blank.
	world = load("res://ldtk/Act1World.tscn").instantiate()
	Screen.set_scene(world)
	for i in 30:
		if not world.rooms.is_empty():
			break
		await get_tree().process_frame
	var player := world.player
	player.input_locked = true
	var cam: Camera2D = player.get_node("Camera2D")
	cam.position_smoothing_enabled = false

	# The gift goes first: room 1 opens on Act1Beats' black fade, and anything
	# captured before that lifts comes back as an all-zero frame.
	await _shoot_gift(player)
	await _shoot_tiles(player)
	get_tree().quit()


# The pads: one frame at rest, one the instant a pad sounds.
func _shoot_tiles(player: Node2D) -> void:
	var tiles := get_tree().get_nodes_in_group("note_tile")
	if tiles.is_empty():
		print("no note tiles found")
		return
	tiles.sort_custom(func(a, b): return a.global_position.x < b.global_position.x)
	var mid: Node2D = tiles[tiles.size() / 2]
	# Move the ROOM, not just the player: camera limits are clamped to whatever
	# room the world thinks it is in, so teleporting alone leaves the camera
	# pinned in room 1.
	world._enter_room(_room_holding(mid), true)
	player.global_position = mid.global_position + Vector2(0, -40)
	await _frames(20)
	await _save("tiles_idle")
	for t in tiles:
		t.sound()
	await _frames(2)
	await _save("tiles_lit")


# The gift: frames across the crossing, plus the burst on impact.
func _shoot_gift(player: Node2D) -> void:
	var room: Node2D = null
	for r in world.rooms:
		if r.name == "Level_1_Office":
			room = r
	var trigger := _find_trigger(room)
	if trigger == null:
		print("no rumi trigger in room 1")
		return
	player.global_position = trigger.global_position + Vector2(-6, 8)
	await _frames(10)
	await trigger.appear(24.0)
	trigger.breathe(true)
	await trigger.step_to(player.global_position.x)
	await trigger.swell()
	await _save("gift_0_before")
	print("  Rumi sprite at %s, Hooshang at %s" % [
		trigger.get_node("Rumi").global_position, player.global_position])
	trigger.give_to(player)
	for i in 5:
		await _frames(6)
		var mote := trigger.get_node_or_null("Gift")
		print("  mote %d at %s" % [i + 1, mote.global_position if mote else "gone"])
		await _save("gift_%d_travel" % (i + 1))
	await _frames(3)
	await _save("gift_6_impact")
	await _frames(8)
	await _save("gift_7_burst")


func _room_holding(n: Node) -> Node2D:
	var p := n.get_parent()
	while p != null:
		if world.rooms.has(p):
			return p
		p = p.get_parent()
	return world.current_room


func _find_trigger(n: Node) -> LdtkRumiTrigger:
	if n == null:
		return null
	if n is LdtkRumiTrigger:
		return n
	for c in n.get_children():
		var f := _find_trigger(c)
		if f != null:
			return f
	return null


func _save(name: String) -> void:
	await RenderingServer.frame_post_draw
	var img := Screen.viewport.get_texture().get_image()
	img.save_png("%s/%s.png" % [OUT, name])
	print("saved %s" % name)


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame
