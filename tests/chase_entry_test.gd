extends Node
## The shadow waits at the threshold: after a respawn or a room change he stays
## OUT of the room until the player has committed to leaving it.
##
## He arrives `respawn_gap` behind you, which is right while you are running and
## wrong when you are not. Entering a room or coming back from a death puts you
## at a standstill with a shadow materialising a few frames' sprint away, before
## you have even looked at the floor you are about to cross. So the reset now
## parks him out of sight until you have travelled `entry_hold_distance` along
## the route.
##
## What this pins, and why each one is here rather than assumed:
##   - standing still keeps him out, however long you stand there
##   - backing UP keeps him out too. The gate is distance along the route, not
##     distance travelled, and a plain length() would let jittering on the spot
##     or retreating a step summon him
##   - he cannot kill while he is waiting. Being invisible is not the guarantee;
##     the Area2D is still there and the reset may well have parked him on top
##     of a player who respawned mid-corridor
##   - crossing the line lets him in, at the FULL gap measured from where the
##     player is by then — not from where the room originally put him, which is
##     the whole reason the hold has to re-place him
##
## Run:  godot --headless res://tests/chase_entry_test.tscn

var failures: Array[String] = []
var world: LdtkWorld
var player: Player
var shadow: Darkshang


func _ready() -> void:
	LdtkWorld.debug_start_room = "Level_14"
	world = load("res://ldtk/Act1World.tscn").instantiate()
	Screen.set_scene(world)
	for i in 30:
		if not world.rooms.is_empty():
			break
		await get_tree().process_frame
	await _frames(20)
	LdtkWorld.debug_start_room = ""
	player = world.player
	player.input_locked = false

	for node in get_tree().get_nodes_in_group("darkshang"):
		if node is Darkshang:
			shadow = node
	_check(shadow != null, "Level_14 has a Darkshang")
	if shadow == null:
		return _finish()
	_check(shadow.entry_hold_distance > 0.0,
		"the entry hold is armed  [%.0fpx]" % shadow.entry_hold_distance)

	# The chase has to be RUNNING for a reset to mean anything — reset_to_checkpoint
	# on a dormant shadow is a no-op by design (a death in room 3 must not wake
	# the boss), so a test that skipped this would pass on a shadow that never
	# does anything at all.
	shadow.start_chase()
	await _frames(4)
	_check(shadow.state == Darkshang.State.FOLLOWING, "and the chase is running")

	var route: Vector2 = shadow.route_direction.normalized()
	var at := player.global_position

	# --- the reset parks him out of the room ---------------------------------
	shadow.reset_to_checkpoint(at)
	await _frames(2)
	_check(not shadow.visible, "a respawn leaves him out of the room")
	var parked := shadow.global_position

	# --- standing still keeps him out ----------------------------------------
	for i in 60:
		player.global_position = at
		player.velocity = Vector2.ZERO
		await _frames(1)
	_check(not shadow.visible,
		"...and standing still keeps him out, for as long as you like")
	_check(shadow.global_position.is_equal_approx(parked),
		"...without creeping closer while he waits  [%s vs %s]"
			% [shadow.global_position, parked])

	# --- and he cannot kill from where he is parked ---------------------------
	#
	# Standing the player ON him: a respawn can put the two of them in the same
	# place, and "he is invisible" is not the same guarantee as "he cannot catch
	# you". The Area2D is still in the room.
	var deaths_before := Deaths.total
	for i in 30:
		player.global_position = shadow.global_position
		player.velocity = Vector2.ZERO
		await _frames(1)
	_check(Deaths.total == deaths_before,
		"...and cannot kill while he waits, even standing on him  [%d deaths]"
			% (Deaths.total - deaths_before))

	# --- backing up is not committing -----------------------------------------
	player.global_position = at
	await _frames(2)
	for i in 20:
		player.global_position = at - route * 24.0   # the WRONG way up the route
		player.velocity = Vector2.ZERO
		await _frames(1)
	_check(not shadow.visible,
		"backing up the route does not let him in, however far  [24px the wrong way]")

	# --- crossing the line does ------------------------------------------------
	var gone: Vector2 = at + route * (shadow.entry_hold_distance + 2.0)
	# The gap is read on the frame he ARRIVES, not later. He is FOLLOWING from
	# that moment, and this test holds the player still — so he correctly walks
	# the whole gap in over follow_delay, and a reading taken twenty frames after
	# the fact measures the chase working, not the placement.
	var gap := -1.0
	for i in 20:
		player.global_position = gone
		player.velocity = Vector2.ZERO
		await _frames(1)
		if shadow.visible and gap < 0.0:
			gap = route.dot(player.global_position - shadow.global_position)
	_check(shadow.visible,
		"moving %.0fpx along the route lets him in" % shadow.entry_hold_distance)
	# At the FULL gap from where the player is BY THEN. Seeding from the stale
	# reset point would drop him in already short of the distance the chase is
	# tuned around — the difference between a fair re-entry and an ambush.
	_check(gap > 0.0 and absf(gap - shadow.respawn_gap) < 4.0,
		"...at the full gap behind where the player is by then  [%.1f, want %.0f]"
			% [gap, shadow.respawn_gap])

	_finish()


func _frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func _check(cond: bool, name: String) -> void:
	print(("  PASS  " if cond else "  FAIL  ") + name)
	if not cond:
		failures.append(name)


func _finish() -> void:
	if failures.is_empty():
		print("CHASE ENTRY TEST: ALL PASS")
	else:
		print("CHASE ENTRY TEST: %d FAILURE(S)" % failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)
