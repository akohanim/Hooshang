extends Node
## Dev capture harness: stand in a room and photograph it. Runs WINDOWED (not
## headless) so 2D actually rasterises, and grabs Screen.viewport — the 320x180
## game surface — so what lands on disk is the room and not the HUD around it.
##
## Prints the frame's mean and peak luminance beside each shot, which are the
## numbers LIGHTING.md's targets are quoted in — eyeballing a dark room is
## unreliable, and this is how the room 22 dawn was balanced.
##
## Usage: Godot --path . res://tests/room_shot.tscn -- Level_25 [x_offsets...]
## Offsets are in pixels from the room's left edge; the default sweeps it.
## Shots land in user://shots/ — the absolute path is printed on the way out.

const OUT := "user://shots"

var world: LdtkWorld


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	var room_name: String = args[0] if args.size() > 0 else "Level_25"
	var offsets: Array = []
	for i in range(1, args.size()):
		offsets.append(float(args[i]))

	DirAccess.make_dir_recursive_absolute(OUT)
	# Never let a capture run touch a player's save (see systems/save_game.gd).
	SaveGame.slot = -1
	LdtkWorld.debug_start_room = room_name
	# Act 2 rooms are always prefixed uniquely (CLAUDE.md's own naming rule,
	# needed so the two Acts' rooms can never collide in the shared
	# ldtk/levels/ folder) — currently "Act_2_" — which the same prefix picks
	# which world to load here.
	var world_path := "res://ldtk/Act2World.tscn" if room_name.begins_with("Act_2_") \
		or room_name.begins_with("Act2_") else "res://ldtk/Act1World.tscn"
	world = load(world_path).instantiate()
	Screen.set_scene(world)
	for i in 60:
		if not world.rooms.is_empty():
			break
		await get_tree().process_frame
	var room: Node2D = null
	for r in world.rooms:
		if str(r.name) == room_name:
			room = r
	if room == null:
		print("no room named %s" % room_name)
		get_tree().quit(1)
		return

	var rect := world.room_rect(room)
	print("%s rect %s" % [room_name, rect])
	world._enter_room(room, true)
	var player := world.player
	player.input_locked = true
	(player.get_node("Camera2D") as Camera2D).position_smoothing_enabled = false
	if offsets.is_empty():
		offsets = [80.0, 160.0, 240.0]

	await _frames(40)
	for off in offsets:
		player.global_position = Vector2(rect.position.x + off, rect.end.y - 60.0)
		await _frames(20)
		await _save("%s_%d" % [room_name, int(off)])
	print("shots in %s" % ProjectSettings.globalize_path(OUT))
	get_tree().quit()


func _save(name: String) -> void:
	await RenderingServer.frame_post_draw
	var img: Image = Screen.viewport.get_texture().get_image()
	# Upscale x4 with nearest so the pixel art is legible when read back.
	img.resize(img.get_width() * 4, img.get_height() * 4, Image.INTERPOLATE_NEAREST)
	img.save_png("%s/%s.png" % [OUT, name])
	var stats := _brightness(Screen.viewport.get_texture().get_image())
	print("saved %s   mean %.1f  peak %.0f" % [name, stats.x, stats.y])


## Mean and peak luminance of the frame, for the LIGHTING.md targets.
func _brightness(img: Image) -> Vector2:
	var total := 0.0
	var peak := 0.0
	var n := 0
	for y in range(0, img.get_height(), 2):
		for x in range(0, img.get_width(), 2):
			var c := img.get_pixel(x, y)
			var l := (c.r * 0.299 + c.g * 0.587 + c.b * 0.114) * 255.0
			total += l
			peak = maxf(peak, l)
			n += 1
	return Vector2(total / maxf(n, 1), peak)


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame
