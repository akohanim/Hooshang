extends Node

const Act2ParallaxBackdrop = preload("res://scripts/act2_parallax_backdrop.gd")

var failures: Array[String] = []

func _check(condition: bool, description: String) -> void:
	if condition:
		print("  PASS  %s" % description)
	else:
		print("  FAIL  %s" % description)
		failures.append(description)

func _ready() -> void:
	print("--- Running Act 2 Parallax Backdrop Tests ---")
	var backdrop = Act2ParallaxBackdrop.new()
	add_child(backdrop)

	# 1. Verify layers created
	_check(backdrop._layer_sun != null, "Layer 0 (Sun & Sky) Parallax2D exists")
	_check(backdrop._layer_clouds != null, "Layer 1 (Clouds) Parallax2D exists")
	_check(backdrop._layer_mountains != null, "Layer 2 (Mountains) Parallax2D exists")
	_check(backdrop._layer_dunes != null, "Layer 3 (Dunes) Parallax2D exists")

	# 2. Verify scroll scales (depth progression)
	_check(backdrop._layer_sun.scroll_scale.x < backdrop._layer_clouds.scroll_scale.x,
		"Sun moves slower than clouds (celestial depth)")
	_check(backdrop._layer_clouds.scroll_scale.x < backdrop._layer_mountains.scroll_scale.x,
		"Clouds move slower than mountains")
	_check(backdrop._layer_mountains.scroll_scale.x < backdrop._layer_dunes.scroll_scale.x,
		"Mountains move slower than near dunes")

	# 3. Verify horizontal repeat
	_check(backdrop._layer_clouds.repeat_size.x > 0.0, "Clouds have horizontal repeat")
	_check(backdrop._layer_mountains.repeat_size.x > 0.0, "Mountains have horizontal repeat")
	_check(backdrop._layer_dunes.repeat_size.x > 0.0, "Dunes have horizontal repeat")

	# 4. Verify textures loaded
	_check(Act2ParallaxBackdrop.TEX_SKY_SUN != null and Act2ParallaxBackdrop.TEX_SKY_SUN.get_width() > 0,
		"Sky & Sun texture valid")
	_check(Act2ParallaxBackdrop.TEX_CLOUDS != null and Act2ParallaxBackdrop.TEX_CLOUDS.get_width() > 0,
		"Clouds texture valid")
	_check(Act2ParallaxBackdrop.TEX_MOUNTAINS != null and Act2ParallaxBackdrop.TEX_MOUNTAINS.get_width() > 0,
		"Mountains texture valid")
	_check(Act2ParallaxBackdrop.TEX_DUNES != null and Act2ParallaxBackdrop.TEX_DUNES.get_width() > 0,
		"Dunes texture valid")

	await _entry_slide_frames_destination()

	if failures.is_empty():
		print("ACT 2 PARALLAX TEST: ALL PASS")
		get_tree().quit(0)
	else:
		print("ACT 2 PARALLAX TEST: %d FAILURE(S)" % failures.size())
		get_tree().quit(1)


## Regression: the backdrop must be framed for the room being ENTERED for the
## whole entry slide, not snap to it a beat after the camera lands — the same
## pop-in the moon had, driven by current_room only advancing at the slide's end
## (see LdtkWorld.transition_started / MoonVisibility). Driven against a real
## Act2World with its two real rooms so it exercises the actual signal wiring.
func _entry_slide_frames_destination() -> void:
	SaveGame.slot = -1
	var world = load("res://ldtk/Act2World.tscn").instantiate()
	add_child(world)
	for _i in 60:
		await get_tree().process_frame
		if world.player != null and not world.rooms.is_empty():
			break
	var bd = world.get_node("Backdrop/SkyBackdrop")
	for _i in 30:
		if bd._world != null:
			break
		await get_tree().process_frame
	var l0 = _room_of(world, "Act_2_Level_0")
	var l1 = _room_of(world, "Act_2_Level_1")
	if l0 == null or l1 == null or bd._world == null:
		_check(false, "entry-slide setup: two rooms and a connected backdrop")
		world.queue_free()
		return
	world.player.set_physics_process(false)

	# What each room frames the deep sun at (the layer the eye tracks).
	world._enter_room(l0, true)
	var off_origin: Vector2 = bd._layer_sun.scroll_offset
	bd._on_room_changed(l1)
	var off_dest: Vector2 = bd._layer_sun.scroll_offset
	bd._on_room_changed(l0)
	_check(off_origin != off_dest,
		"the two rooms frame the backdrop differently (so the check is meaningful)")

	# Begin the real slide. _slide_to_room runs to its first await synchronously,
	# announcing the destination live — current_room stays on the origin.
	world._enter_room(l0, true)
	world._slide_to_room(l1)
	_check(world.current_room == l0,
		"current_room does not advance until the slide lands")
	_check(bd._layer_sun.scroll_offset == off_dest,
		"backdrop is framed for the DESTINATION during the entry slide, not after")

	world.queue_free()


func _room_of(world, n: String):
	for room in world.rooms:
		if room.name == n:
			return room
	return null
