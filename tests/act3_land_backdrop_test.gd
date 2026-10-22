extends Node
## The way home's backdrops in depth (scenes/props/sea/land_backdrop.gd, painted
## by tools/gen_act3_land_backdrops.py), every room from the real sea to the edge:
##   - each room hangs its planes, clipped to its own rect (their margins would
##     otherwise lie over the neighbouring rooms);
##   - every plane covers its room, and HOLDS STILL: the mountains, the sea and
##     every other plane stay exactly where they are while he crosses the room
##     and the camera goes from its top to its bottom (they used to slide with
##     him by depth, which read as the mountains and the sea moving);
##   - clouds drift, and the earth under the grass is shaded with depth;
##   - the edge's far wall is drawn over the terrain (on a plane of its own it
##     slid off the real rock and read as a box stuck to it);
##   - a tiger's shadow stays on the ground under it when it leaps.
##
## Headless:  Godot --headless --path . res://tests/act3_land_backdrop_test.tscn

const ROOMS := ["Act3_Level_25", "Act3_Level_26", "Act3_Level_27", "Act3_Level_28",
	"Act3_Level_29", "Act3_Level_30", "Act3_Level_31"]

var world: SeaWorld
var failures := 0


func _ready() -> void:
	get_tree().create_timer(120.0, true, false, true).timeout.connect(func():
		print("ACT3_LAND: TIMEOUT"); get_tree().quit(3))
	SaveGame.unbind()
	Sfx.muted = true
	LdtkWorld.debug_start_room = "Act3_Level_28"
	world = load("res://ldtk/Act3World.tscn").instantiate()
	world.set_meta("no_beats", true)
	Screen.set_scene(world)
	await frames(20)
	for room_name in ROOMS:
		await room_checks(room_name)
	await shadow_checks()
	print("ACT3_LAND: %d failures" % failures)
	get_tree().quit(0 if failures == 0 else 1)


func room(room_name: String) -> Node2D:
	for r in world.rooms:
		if str(r.name) == room_name:
			return r
	return null


func room_checks(room_name: String) -> void:
	var level := room(room_name)
	var planes := level.find_child("LandBackdrop", true, false) as LandBackdrop if level != null else null
	check(planes != null and not planes._planes.is_empty(), "%s hangs its planes" % room_name)
	if planes == null:
		return
	var clip := planes.get_node_or_null("Clip") as Control
	check(clip != null and clip.clip_contents and clip.size == planes.room_size,
		"%s: clipped to its own room" % room_name)

	var uncovered := 0
	for plane in planes._planes:
		var sprite := plane.node as Sprite2D
		if plane.layer and not Rect2(sprite.position, sprite.texture.get_size()).encloses(Rect2(Vector2.ZERO, planes.room_size)):
			uncovered += 1
	check(uncovered == 0, "%s: every plane covers the room  [%d short]" % [room_name, uncovered])

	# Walk him from one end to the other (and, in the tall room, the camera from
	# its top to its bottom): nothing in the backdrop may move with him.
	world._enter_room(level, true)
	await frames(4)
	var rect := world.room_rect(level)
	var player := world.player
	var first := {}
	var moved := 0
	for at in [Vector2(rect.position.x + 16, rect.position.y + 40), Vector2(rect.end.x - 16, rect.end.y - 40)]:
		player.global_position = at
		player.freeze()
		await frames(40)
		for plane in planes._planes:
			var node := plane.node as Node2D
			if not first.has(node):
				first[node] = node.global_position
			elif node.global_position != first[node]:
				moved += 1
		player.unfreeze()
	check(moved == 0, "%s: the mountains, the sea and every plane hold still  [%d moved]" % [room_name, moved])

	if not planes._clouds.is_empty():
		var cloud := planes._clouds[0].node as Node2D
		var was := cloud.position
		planes._t += 10.0
		planes._drift_clouds()
		check(cloud.position != was, "%s: the clouds drift" % room_name)

	var terrain := level.get_node_or_null("Collisions") as TileMapLayer
	var mat := terrain.material as ShaderMaterial if terrain != null else null
	check(mat != null and float(mat.get_shader_parameter("earth_depth")) > 0.0,
		"%s: the earth is shaded with depth" % room_name)

	if room_name == "Act3_Level_31":
		var wall := clip.get_node_or_null("Wall") as Sprite2D
		check(wall != null and wall.z_index > terrain.z_index,
			"the edge's far wall is drawn over the terrain, at the room's own depth")


func shadow_checks() -> void:
	# A tiger 20px over the meadow: its shadow stays on the ground, fainter.
	var level := room("Act3_Level_28")
	world._enter_room(level, true)
	await frames(6)
	var feet := world.spawn_point_for(level) + Vector2(0, Player.HALF_HEIGHT)
	var tiger := ChaseTiger.new()
	world.add_child(tiger)
	var shadow: GroundShadow = null
	for child in tiger.get_children():
		if child is GroundShadow:
			shadow = child
	check(shadow != null, "a tiger carries a shadow")
	if shadow == null:
		return
	tiger.global_position = feet
	await frames(3)
	var ground_y := shadow.global_position.y
	check(shadow.visible and absf(ground_y - feet.y) <= 4.0,
		"on the ground, its shadow is at its feet  [%.1f vs %.1f]" % [ground_y, feet.y])
	var full := shadow.modulate.a
	tiger.global_position = feet - Vector2(0, 20)
	await frames(3)
	check(shadow.visible and absf(shadow.global_position.y - ground_y) < 0.5,
		"leaping, its shadow stays on the ground  [%.1f]" % shadow.global_position.y)
	check(shadow.modulate.a < full and shadow.texture.get_width() < shadow.width,
		"...and is fainter and smaller with the height")
	tiger.queue_free()


func frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func check(ok: bool, message: String) -> void:
	print(("  PASS " if ok else "  FAIL ") + message)
	if not ok:
		failures += 1
