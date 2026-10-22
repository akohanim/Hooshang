extends Node
## Dev capture harness for the prison hub's three minigames (HOOSHANG 64,
## SUPER SIMORGH, THE OTHER SIDE), not pass/fail. Each game runs in its own
## 160x120 SubViewport, the same size RetroTV gives it, and is driven by real
## input actions; the shots are the game's own pixels upscaled x4 nearest.
## Windowed (2D does not rasterise headless). Shots land in
## output/minigames/<tag>/:
##   Godot --path . res://tests/minigame_shot.tscn -- after
## A second argument, h64=<path to a retro_game.gd>, photographs HOOSHANG 64
## from that copy instead (an older one, for a before shot; strip its
## class_name first).

const SCALE := 4
var tag := "shots"
var dir := ""
var viewport: SubViewport
var h64_script: Script = RetroGame


func _ready() -> void:
	SaveGame.unbind()
	var args := OS.get_cmdline_user_args()
	if not args.is_empty(): tag = args[0]
	for a in args:
		if a.begins_with("h64="): h64_script = load(a.trim_prefix("h64="))
	dir = "res://output/minigames/%s" % tag
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir))
	await _hooshang_64()
	await _simorgh()
	await _mirror()
	print("MINIGAME SHOTS -> ", ProjectSettings.globalize_path(dir))
	get_tree().quit()


func _fresh(game: Node2D) -> void:
	if viewport != null: viewport.queue_free()
	viewport = SubViewport.new()
	viewport.size = Vector2i(160, 120)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	add_child(viewport)
	viewport.add_child(game)


func _frames(n: int) -> void:
	for i in n: await get_tree().physics_frame


func _tap(action: String) -> void:
	Input.action_press(action)
	await _frames(3)
	Input.action_release(action)


func _release_all() -> void:
	for a in ["move_left", "move_right", "move_up", "move_down", "jump", "dash"]:
		Input.action_release(a)


func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var img := viewport.get_texture().get_image()
	img.resize(img.get_width() * SCALE, img.get_height() * SCALE, Image.INTERPOLATE_NEAREST)
	img.save_png("%s/%s.png" % [dir, name])


func _hooshang_64() -> void:
	var g: Node2D = h64_script.new()
	_fresh(g)
	await _frames(2)
	g.activate()
	await _frames(40)
	await _shot("h64_title")
	await _tap("jump")
	await _frames(20)
	await _shot("h64_play")
	# Back at the checkpoint after a death: what is coming at him.
	g._respawn(92 * 8)
	g.mode = RetroGame.Mode.PLAY
	await _frames(30)
	await _shot("h64_checkpoint_0.5s")
	# The flag, and the walk away from it.
	g._respawn(173 * 8)
	g.mode = RetroGame.Mode.PLAY
	Input.action_press("move_right")
	await _frames(4)
	Input.action_press("jump")
	while g.mode != RetroGame.Mode.CLEAR: await _frames(1)
	_release_all()
	while g.mode_t < 2.6: await _frames(1)
	await _shot("h64_clear_walkoff")
	while g.mode_t < 4.2: await _frames(1)
	await _shot("h64_clear_end")
	# The stair well between the two staircases.
	g._respawn(156 * 8 + 2)
	g.pos.y = 40
	g.mode = RetroGame.Mode.PLAY
	await _frames(40)
	await _shot("h64_stair_well")
	# A game over: where it leaves him.
	g.lives = 1
	g._die()
	while g.mode != RetroGame.Mode.TITLE: await _frames(1)
	await _frames(40)
	await _shot("h64_after_game_over")
	g.deactivate()
	await _frames(2)


func _simorgh() -> void:
	var g := SimorghGame.new()
	_fresh(g)
	await _frames(2)
	g.activate()
	g.glitch_t = 6.0
	await _frames(40)
	await _shot("sim_title")
	await _tap("jump")
	while g.mode == SimorghGame.Mode.INTRO and g.mode_t < 2.5: await _frames(1)
	await _shot("sim_intro")
	while g.mode == SimorghGame.Mode.INTRO: await _frames(1)
	await _frames(20)
	await _shot("sim_play_start")
	# A player who reads it as a side-scroller and holds Right.
	Input.action_press("move_right")
	await _frames(45)
	_release_all()
	await _shot("sim_held_right")
	while g.mode != SimorghGame.Mode.CAUGHT: await _frames(1)
	while g.mode_t < 4.6: await _frames(1)
	await _shot("sim_consumed")
	while g.mode == SimorghGame.Mode.CAUGHT: await _frames(1)
	await _frames(10)
	await _shot("sim_after_consumed")
	g.deactivate()
	await _frames(2)


func _mirror() -> void:
	var g := MirrorGame.new()
	_fresh(g)
	await _frames(2)
	g.activate()
	await _frames(40)
	await _shot("mirror_title")
	for s in [0, 2]:
		g.mode = MirrorGame.Mode.STAGE
		g.stage = s
		g._reset_stage()
		g.stage_clock = 2.4
		await _frames(2)
		await _shot("mirror_stage%d" % (s + 1))
	# First person: a straight-ahead shard, then hold Right for half a second.
	g.mode = MirrorGame.Mode.STAGE
	g.stage = 3
	g._reset_stage()
	g.stage_clock = 2.4
	g.reflection = Vector2(40, 91)
	await _frames(2)
	await _shot("mirror_fp_start")
	Input.action_press("move_right")
	await _frames(20)
	_release_all()
	await _shot("mirror_fp_held_right")
	g.deactivate()
	await _frames(2)
