extends Node
## Dev capture harness for the crumbling platform, not pass/fail. Loads the
## world a room belongs to, frames each of that room's crumbling platforms in
## turn and photographs the 320x180 game surface, so the panel can be judged
## against the scaffolding around it. Hooshang is frozen and hidden, so nothing
## lands on a panel and starts it cracking. Runs WINDOWED, like room_shot.
##
## Usage: Godot --path . res://tests/crumble_world_shot.tscn -- <room> [label] [x y]
## Shots land in user://crumble_shots/<label>_<room>_<n>.png (label "shot").
## `x y` (room-relative px) first drops a 6-cell panel into the room, for an
## Act with none placed yet; it wears whatever look that world gives it.

const OUT := "user://crumble_shots"


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	var room_name: String = args[0] if args.size() > 0 else "Level_V7"
	var label: String = args[1] if args.size() > 1 else "shot"
	DirAccess.make_dir_recursive_absolute(OUT)
	# Never let a capture run touch a player's save (see systems/save_game.gd).
	SaveGame.slot = -1
	LdtkWorld.debug_start_room = room_name
	var world_path := "res://ldtk/Act1World.tscn"
	if room_name.begins_with("Act_2_") or room_name.begins_with("Prison_"):
		world_path = "res://ldtk/Act2World.tscn"
	elif room_name.begins_with("Act3_"):
		world_path = "res://ldtk/Act3World.tscn"
	var world: LdtkWorld = load(world_path).instantiate()
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
	if args.size() > 3:
		var placed: CrumblingPlatform = \
			preload("res://scenes/props/platforms/CrumblingPlatform.tscn").instantiate()
		placed.size = Vector2(48, 8)
		placed.position = Vector2(float(args[2]), float(args[3]))
		room.add_child(placed)
	world._enter_room(room, true)
	var player := world.player
	player.input_locked = true
	player.freeze()
	player.visible = false
	(player.get_node("Camera2D") as Camera2D).position_smoothing_enabled = false
	var panels: Array[CrumblingPlatform] = []
	for node in get_tree().get_nodes_in_group("crumbling"):
		if node is CrumblingPlatform and room.is_ancestor_of(node):
			panels.append(node)
	# One shot per screenful: panels within a camera's reach of one already
	# framed would only photograph the same thing twice.
	var framed: Array[Vector2] = []
	for panel in panels:
		var at := panel.global_position
		if framed.any(func(f: Vector2) -> bool: return absf(f.x - at.x) < 120.0 and absf(f.y - at.y) < 60.0):
			continue
		framed.append(at)
		player.global_position = at + Vector2(0, -24)
		await _frames(20)
		await _save("%s_%s_%d" % [label, room_name, framed.size() - 1])
	print("shots in %s" % ProjectSettings.globalize_path(OUT))
	get_tree().quit()


func _save(name: String) -> void:
	await RenderingServer.frame_post_draw
	var img: Image = Screen.viewport.get_texture().get_image()
	# x4 nearest so the pixel art is legible when read back.
	img.resize(img.get_width() * 4, img.get_height() * 4, Image.INTERPOLATE_NEAREST)
	img.save_png("%s/%s.png" % [OUT, name])
	print("saved %s" % name)


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame
