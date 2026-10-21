extends Node
## Dev capture harness for Act III, not pass/fail: photographs whole rooms of
## the sea (two frames for a tall room, top and bottom) so the depth palette,
## water and props can be judged. Windowed — 2D does not rasterise headless.
## Binds no save slot.
##
##   Godot --path . res://tests/act3_shot.tscn -- Act3_Level_0 Act3_Level_8
##   Godot --path . res://tests/act3_shot.tscn            # every room
##   ... -- Act3_Level_12 --beats                          # with the story on
## Shots land in user://act3_shots/ (absolute path printed on the way out).

const OUT := "user://act3_shots"


func _ready() -> void:
	var names := OS.get_cmdline_user_args()
	# --beats keeps the story on (the dark floor is only dark with it).
	var beats := "--beats" in names
	names.erase("--beats")
	DirAccess.make_dir_recursive_absolute(OUT)
	SaveGame.slot = -1
	LdtkWorld.debug_start_room = names[0] if not names.is_empty() else "Act3_Level_0"
	var world: SeaWorld = load("res://ldtk/Act3World.tscn").instantiate()
	if not beats:
		world.set_meta("no_beats", true)
	Screen.set_scene(world)
	for i in 60:
		if not world.rooms.is_empty():
			break
		await get_tree().process_frame
	if names.is_empty():
		for r in world.rooms:
			names.append(str(r.name))
	var player := world.player
	var cam := player.camera
	for room_name in names:
		var room: Node2D = null
		for r in world.rooms:
			if str(r.name) == room_name:
				room = r
		if room == null:
			print("no room ", room_name)
			continue
		world._enter_room(room, true)
		player.global_position = world.spawn_point_for(room)
		player.freeze()
		cam.position_smoothing_enabled = false
		var rect := world.room_rect(room)
		var frames := 2 if rect.size.y > 200.0 else 1
		for f in frames:
			cam.set_as_top_level(true)
			cam.global_position = Vector2(rect.get_center().x,
				rect.position.y + 90.0 if f == 0 else rect.end.y - 90.0)
			await _frames(12)
			await RenderingServer.frame_post_draw
			var img: Image = Screen.viewport.get_texture().get_image()
			img.resize(img.get_width() * 3, img.get_height() * 3, Image.INTERPOLATE_NEAREST)
			img.save_png("%s/%s_%d.png" % [OUT, room_name, f])
		cam.set_as_top_level(false)
		cam.position = Vector2.ZERO
		player.unfreeze()
	print("shots in %s" % ProjectSettings.globalize_path(OUT))
	get_tree().quit()


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame
