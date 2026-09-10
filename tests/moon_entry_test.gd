extends Node
## Regression: the moon must be LIVE the instant a room slide begins, not a beat
## after the camera lands. current_room only advances at the slide's END (a death
## mid-slide has to respawn in the room you left), so a moon gated on current_room
## alone stayed dark for the whole crossing and then popped into the level once
## the slide finished — reported as "the moon renders in the level after the
## player enters it". LdtkWorld.transition_target + is_room_active() close that
## gap; this pins it so it cannot silently reopen.
##
## Drives the REAL _slide_to_room (which runs synchronously up to its first await,
## setting the destination live) rather than simulating the state by hand, so a
## future change that moved transition_target back to the slide's end would fail
## here, not just a change to the helper.

func _ready() -> void:
	SaveGame.slot = -1
	var world = load("res://ldtk/Act1World.tscn").instantiate()
	var beats = world.get_node("Act1Beats")
	world.remove_child(beats)
	beats.free()
	Screen.set_scene(world)
	await get_tree().process_frame
	world.player.set_physics_process(false)
	world.player.camera.position_smoothing_enabled = false

	var failures := 0

	# Two rooms that both own a moon (Level_0..Level_6 carry office moons).
	var origin := _room_named(world, "Level_0")
	var dest := _room_named(world, "Level_1")
	if origin == null or dest == null:
		print("MOON ENTRY: could not find both moon rooms — cannot run")
		get_tree().quit(1)
		return
	var origin_moon := _moon_in(world, origin)
	var dest_moon := _moon_in(world, dest)
	if origin_moon == null or dest_moon == null:
		print("MOON ENTRY: a chosen room has no moon — cannot run")
		get_tree().quit(1)
		return

	# Settled in the origin: only its moon is live.
	world._enter_room(origin, true)
	MoonVisibility.refresh()
	if not _lit(origin_moon):
		failures += 1
		print("  origin moon should be lit before the slide")
	if _lit(dest_moon):
		failures += 1
		print("  destination moon should be dark before the slide")

	# Begin the real slide. _slide_to_room runs to its first await (the camera
	# tween) synchronously, so by the time this returns the destination is
	# already announced live — current_room, though, is still the origin.
	world._slide_to_room(dest)
	if world.current_room != origin:
		failures += 1
		print("  current_room must NOT advance until the slide lands")
	if world.transition_target != dest:
		failures += 1
		print("  transition_target should be the destination during the slide")

	# The whole point: mid-slide the destination moon is already lit as it
	# scrolls in, and the departing moon has NOT popped out under the camera.
	MoonVisibility.refresh()
	if not _lit(dest_moon):
		failures += 1
		print("  destination moon must be lit DURING the entry slide, not after")
	if not _lit(origin_moon):
		failures += 1
		print("  departing moon must stay lit until the slide lands (no pop-out)")

	# And it stays lit across every frame of the crossing, never flickering.
	for _i in range(30):
		MoonVisibility.refresh()
		if not _lit(dest_moon):
			failures += 1
			print("  destination moon flickered mid-slide")
			break

	# Land the slide by hand (the real tween would, a few frames on): the
	# destination becomes current, the origin falls dark, still no pop.
	world.transition_target = null
	world._enter_room(dest, false)
	MoonVisibility.refresh()
	if not _lit(dest_moon):
		failures += 1
		print("  destination moon must stay lit after arrival")
	if _lit(origin_moon):
		failures += 1
		print("  origin moon must fall dark once left behind")

	print("MOON ENTRY: destination lit through the whole slide; %d failures" % failures)
	get_tree().quit(0 if failures == 0 else 1)


func _room_named(world, n: String):
	for room in world.rooms:
		if room.name == n:
			return room
	return null


func _moon_in(world, room):
	var r: Rect2 = world.room_rect(room)
	for moon in get_tree().get_nodes_in_group("moon_candidates"):
		if r.has_point(world.to_local(moon.global_position)):
			return moon
	return null


func _lit(moon) -> bool:
	return moon.get_node("Core" if moon.has_node("Core") else "Moon").visible
