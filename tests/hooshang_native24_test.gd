extends Node
## Real resource/scene contract: native art, transparent contours, state routing,
## foot placement, and the Act 2 library swap that must keep its old scale.

var failures := 0


func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)


func _ready() -> void:
	SaveGame.slot = -1
	var player: Player = load("res://scenes/characters/hooshang/Hooshang.tscn").instantiate()
	add_child(player)
	player.set_physics_process(false)
	player.state = Player.State.IDLE
	player._update_visual()
	var visual := player.visual
	var frames := visual.sprite_frames
	check(visual.scale == Vector2.ONE, "adult sprite must render at 1:1")
	check(visual.texture_filter == CanvasItem.TEXTURE_FILTER_NEAREST, "nearest filtering")
	check((player.get_node("CollisionShape2D").shape as RectangleShape2D).size == Vector2(9, 12), "collision dimensions preserved")
	for animation in frames.get_animation_names():
		for i in frames.get_frame_count(animation):
			var texture := frames.get_frame_texture(animation, i)
			check(texture.get_size() == Vector2(18, 18), "%s frame size" % animation)
			var im := texture.get_image()
			check(not im.is_empty() and im.get_used_rect().has_area(), "%s nonempty frame" % animation)
			for y in 18:
				for x in 18:
					var color := im.get_pixel(x, y)
					check(color.a == 0.0 or color.a == 1.0, "%s has partially transparent pixels" % animation)
	var standing := frames.get_frame_texture("idle", 0).get_image().get_used_rect()
	check(float(standing.end.y) - 9.0 + visual.offset.y == 6.0, "feet align with hitbox bottom")
	check(frames.get_frame_count("run") == 8, "eight-frame run cycle")
	# The slide is carried by player physics. Its face and braced hand must
	# not hop independently inside the artwork as the animation loops.
	var slide_anchor := frames.get_frame_texture("wall_slide", 0).get_image()
	for i in frames.get_frame_count("wall_slide"):
		var slide_frame := frames.get_frame_texture("wall_slide", i).get_image()
		for region in [Rect2i(5, 0, 8, 8), Rect2i(14, 3, 4, 8)]:
			check(slide_frame.get_region(region).get_data() == slide_anchor.get_region(region).get_data(), "wall slide head and hand stay anchored")
	check(frames.get_frame_texture("exit_water", frames.get_frame_count("exit_water") - 1).get_image().get_data() == frames.get_frame_texture("idle", 0).get_image().get_data(), "climb-out settles into exact idle pose")
	check(not frames.get_animation_loop("dash") and not frames.get_animation_loop("jump"), "dash and jump must hold their ending pose")
	player.visual.speed_scale = -1.0
	player.state = Player.State.RUN
	player.facing = -1
	player._update_visual()
	check(visual.animation == &"run" and visual.flip_h, "run mirrors for leftward movement")
	check(visual.speed_scale == 1.0, "descending ladder must not reverse the next run")
	visual.set_frame_and_progress(0, 0.0)
	await get_tree().create_timer(0.2).timeout
	check(visual.frame > 0, "run animation actually advances in Godot")
	for pair in [[Player.State.IDLE, "idle"], [Player.State.JUMP, "jump"], [Player.State.FALL, "fall"], [Player.State.DASH, "dash"], [Player.State.WALL_SLIDE, "wall_slide"], [Player.State.CLIMB, "climb_idle"], [Player.State.SWIM, "swim_idle"], [Player.State.EXIT_WATER, "exit_water"]]:
		player.state = pair[0]
		player._update_visual()
		check(visual.animation == StringName(pair[1]), "state routes to %s" % pair[1])
	player.state = Player.State.CLIMB
	player.velocity.y = -20.0
	player._update_visual()
	check(visual.animation == &"climb" and visual.is_playing(), "ladder ascent")
	player.velocity.y = 20.0
	player._update_visual()
	check(visual.animation == &"climb_down" and visual.speed_scale == 1.0, "ladder descent uses forward-authored down clip")
	player.velocity.y = 0.0
	player._update_visual()
	check(visual.animation == &"climb_idle" and not visual.is_playing(), "ladder hold freezes")
	check(frames.get_frame_count("swim") == 6 and frames.has_animation("crouch"), "additional approved clips imported")
	check(is_equal_approx(frames.get_frame_duration("run", 0) / frames.get_animation_speed("run"), 0.09 / 1.6), "run cadence is 60% faster than source timing")
	player.state = Player.State.DASH
	player._update_visual()
	await get_tree().create_timer(0.3).timeout
	check(visual.frame == frames.get_frame_count("dash") - 1 and not visual.is_playing(), "dash holds its ending frame instead of looping")
	visual.sprite_frames = load("res://assets/characters/hooshang_child/act2_frames.tres")
	player.state = Player.State.IDLE
	player._update_visual()
	check(visual.scale.is_equal_approx(Vector2(0.39, 0.39)), "child keeps its original scale")
	check(visual.offset == Vector2(0, -7), "child keeps its original foot offset")
	player.state = Player.State.CLIMB
	player.velocity.y = 20.0
	player._update_visual()
	check(visual.animation == &"climb" and visual.speed_scale == -1.0, "child descent retains reverse-climb fallback")
	player.velocity.y = 0.0
	player._update_visual()
	check(not visual.is_playing(), "child holds on ladder")
	print("HOOSHANG NATIVE18 TEST: %d failures" % failures)
	get_tree().quit(1 if failures else 0)
