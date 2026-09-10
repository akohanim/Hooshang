extends Node

var failures := 0
func check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
		push_error(what)

func _ready() -> void:
	SaveGame.slot = -1
	var world = load("res://ldtk/Act1World.tscn").instantiate()
	Screen.set_scene(world)
	await get_tree().process_frame
	var textures := {}
	for room in world.rooms:
		check(world.room_backdrop_overrides.has(str(room.name)), "%s has an authored background" % room.name)
		var panel = room.get_node("RoomBackdrop")
		check(panel is TextureRect, "%s uses art" % room.name)
		check(panel.texture.get_size() == world.room_rect(room).size, "%s art matches room pixels" % room.name)
		check(panel.texture_filter == CanvasItem.TEXTURE_FILTER_NEAREST, "%s is crisp" % room.name)
		check(not textures.has(panel.texture.resource_path), "%s has its own art" % room.name)
		textures[panel.texture.resource_path] = true
		world._enter_room(room, true)
		if world._room_has_music_puzzle(room):
			check(world.get_node("CanvasModulate").color == Color.BLACK, "%s retains black ambient" % room.name)
	# The original story controls still drive both reveal windows and pools.
	var beats = world.get_node("Act1Beats")
	check(beats._moon_pairs().size() == 2, "Both original eclipse windows stay wired")
	beats._turn_the_moon(false)
	for pair in beats._moon_pairs():
		var moon = beats.get_node(pair[0])
		check(moon.moon_color == moon.blood_moon_color, "Eclipse resumes blood red")
		check(is_equal_approx(moon.shadow_amount, moon.blood_shadow_amount), "Eclipse resumes its umbra")
	var last_shadow := 1.0
	for number in [15, 16, 17, 18, 20, 21, 24]:
		var moon = world.get_node("Backdrop/MoonWindowRoom%d" % number)
		check(moon.shadow_amount < last_shadow, "Night progressively clears at %d" % number)
		last_shadow = moon.shadow_amount
	var dawn = world.get_node("Backdrop/DawnWindowRoom25")
	check(dawn.scene_file_path == "res://scenes/props/backdrop/DawnWindow.tscn", "Original dawn art retained")
	check(dawn.position == Vector2(176, 1232), "Original dawn composition retained")
	check(is_equal_approx(world.get_node("Lights/DawnGlowRoom25").light_energy, 2.6), "Original dawn energy retained")
	check(world.get_node("Props/HooshangCubicleRoom25").position == Vector2(48, 1280), "Original cubicle retained")
	check(beats.collapse_first_room == 16 and beats.collapse_last_room == 25, "Physical collapse sequence retained")
	print("ALL ACT I BACKGROUNDS: %d rooms, %d unique textures, %d failures" % [world.rooms.size(), textures.size(), failures])
	get_tree().quit(0 if failures == 0 else 1)
