extends Node
## Regression: dying anywhere in Level_v6 past its entrance used to bounce the
## player straight back to Level_v5.
##
## Level_v6 has no Checkpoint of its own, so every death in it respawns him at
## the same PlayerStart the return door is built around — 16px off the edge he
## entered through, inside the 16px return strip that starts 6px in (see the
## note on LdtkWorld._resolve_return_arming). Walking clear of that strip once,
## like ordinary forward play does, arms the door; a LATER death anywhere else
## in the room then TELEPORTS him straight back inside it. Area2D.overlaps_body()
## lags a teleport like that by an extra physics step — measured directly,
## body_entered for a respawn landing back inside an already-armed strip fired
## on the THIRD physics frame after the teleport, one frame later than
## _resolve_return_arming's own two-frame wait — so that function used to read
## "clear" on stale information, arm the door, and then get bounced by the real
## signal arriving a frame late. Fixed by checking a plain Rect2
## (LdtkWorld._return_strip_rect) instead of the Area2D's monitoring cache.
## Run:  godot --headless res://tests/level_v6_return_race_test.tscn

var failures: Array[String] = []
var world: LdtkWorld
var player: Player


func _ready() -> void:
	world = load("res://ldtk/Act1World.tscn").instantiate()
	Screen.set_scene(world)
	for i in 30:
		if not world.rooms.is_empty():
			break
		await get_tree().process_frame

	player = world.player
	player.input_locked = true

	var v5: Node2D = null
	var v6: Node2D = null
	for r in world.rooms:
		if r.name == "Level_v5":
			v5 = r
		elif r.name == "Level_v6":
			v6 = r
	_check(v5 != null and v6 != null, "the world has Level_v5 and Level_v6")

	# Walk in the front door, exactly like ordinary forward play: enter v5,
	# arm its own return door, then trip its Exit into v6 (which arms v6's).
	world._enter_room(v5, true)
	await _frames(5)
	world._arm_return(world._room_before(v5))
	await _frames(5)
	var ex := world._exit_in(v5)
	var rect := world.room_rect(v5)
	var dir := 1.0 if ex.global_position.x < rect.get_center().x else -1.0
	player.global_position = ex.global_position + Vector2(dir * 12.0, 0.0)
	await _frames(1)
	player.global_position = ex.global_position
	for i in 200:
		await _frames(1)
		if not world._transitioning and world.current_room != v5:
			break
	await _frames(25)
	_check(world.current_room == v6, "walked from Level_v5 into Level_v6")

	# Walk clear of the return strip, same as any player heading further in —
	# this is what arms the door.
	player.input_locked = false
	Input.action_press("move_right")
	for i in 60:
		await get_tree().physics_frame
		if world._return_armed:
			break
	Input.action_release("move_right")
	_check(world._return_armed, "walking clear of the entrance arms the return door")

	# Die far from the entrance — the checkpoint is still the PlayerStart
	# (Level_v6 has no Checkpoint of its own), so respawn teleports him
	# straight back inside the now-armed strip.
	player.input_locked = true
	player.die()
	for i in 400:
		await get_tree().process_frame
		if player.state != Player.State.DEAD:
			break
	# Give the return door's own (possibly stale) signal every chance to fire.
	await _frames(40)
	_check(world.current_room == v6,
		"dying past the entrance does not bounce him back to Level_v5  [now in %s]"
			% (world.current_room.name if world.current_room else "null"))

	if failures.is_empty():
		print("LEVEL_V6 RETURN RACE TEST: ALL PASS")
	else:
		print("LEVEL_V6 RETURN RACE TEST: %d FAILURE(S)" % failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)


func _frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func _check(ok: bool, msg: String) -> void:
	print(("  PASS  " if ok else "  FAIL  ") + msg)
	if not ok:
		failures.append(msg)
