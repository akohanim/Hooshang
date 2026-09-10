extends Node2D
## Runtime staging plus asset contracts: catches a new sheet that looks right
## on disk but still glides, floats, or releases its gift from the idle pose.

var failures: Array[String] = []
var moved := false
var gifted := false


func _ready() -> void:
	var frames := LdtkRumiTrigger.RUMI_FRAMES
	for clip: StringName in [&"idle", &"walk", &"give_glow"]:
		var seen := {}
		for index in frames.get_frame_count(clip):
			var tex := frames.get_frame_texture(clip, index)
			_check(tex.get_size() == Vector2(96, 96), "%s frame canvas" % clip)
			var img := tex.get_image()
			var rect := img.get_used_rect()
			_check(rect.end.y == 80, "%s frame %d planted foot baseline" % [clip, index])
			_check(rect.size.y <= 36, "%s stays at game scale" % clip)
			seen[hash(img.get_data())] = true
			for y in range(0, 96, 2):
				for x in range(0, 96, 2):
					var c := img.get_pixel(x, y)
					_check(c.a == 0.0 or c.a == 1.0, "binary alpha, no extraction halos")
					for offset in [Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1)]:
						var other := img.get_pixel(x+offset.x, y+offset.y)
						# Godot repairs RGB under transparent edges on import.
						_check(c.a == other.a and (c.a == 0.0 or c == other),
							"whole world pixels at half scale")
		_check(seen.size() > 1, "%s actually changes pose" % clip)
	_check(not frames.get_animation_loop(&"give_glow"), "gift plays once")
	var rumi := LdtkRumiTrigger.make()
	rumi.snap_to_ground = false
	rumi.position = Vector2(80, 70)
	add_child(rumi)
	var sprite: AnimatedSprite2D = rumi.get_node("Rumi")
	_check(sprite.sprite_frames == frames and sprite.is_playing(), "factory starts new idle")
	_check(sprite.material == LdtkRumiTrigger.RUMI_MATERIAL
		and sprite.modulate.r == 1.0 and sprite.modulate.g == 1.0 and sprite.modulate.b == 1.0,
		"self-lit palette is not tinted or clipped by the old samurai lighting")
	_move(rumi, 130.0)
	await get_tree().process_frame
	_check(sprite.animation == &"walk" and not sprite.flip_h, "approach right walks right")
	while not moved:
		await get_tree().process_frame
	_check(sprite.animation == &"idle", "arrival returns to idle")
	_check(is_equal_approx(sprite.global_position.x, 116.0), "stops at arm's length")
	moved = false
	_move(rumi, 60.0)
	await get_tree().process_frame
	_check(sprite.animation == &"walk" and sprite.flip_h, "approach left mirrors walk")
	while not moved:
		await get_tree().process_frame
	_check(sprite.animation == &"idle", "left arrival returns to idle")
	var target := Node2D.new()
	target.position = Vector2(50, 80)
	add_child(target)
	_give(rumi, target)
	await get_tree().process_frame
	_check(sprite.animation == &"give_glow" and sprite.flip_h, "gift faces recipient")
	_check(rumi.get_node_or_null("Gift") == null, "no mote before raised-hand pose")
	var release_frame := -1
	var sampled_release := false
	while not gifted:
		if not sampled_release and rumi.get_node_or_null("Gift") != null:
			release_frame = sprite.frame
			sampled_release = true
		await get_tree().process_frame
	_check(release_frame == 3, "mote releases on extended-hand frame")
	await get_tree().create_timer(0.2).timeout
	_check(sprite.animation == &"idle", "gift finishes and returns to idle")
	var staged := LdtkRumiTrigger.staged(Vector2.ZERO)
	add_child(staged)
	_check(staged.get_node("Rumi").sprite_frames == frames, "staged ending uses new art")
	# The real imported trigger path is also covered by intro_test. This test
	# stays independent of level data and checks both runtime factories.
	if failures.is_empty():
		print("RUMI ANIMATION TEST: ALL PASS")
	else:
		for failure in failures:
			push_error(failure)
	get_tree().quit(0 if failures.is_empty() else 1)


func _move(rumi: LdtkRumiTrigger, target_x: float) -> void:
	await rumi.step_to(target_x, 14.0, 0.2)
	moved = true


func _give(rumi: LdtkRumiTrigger, target: Node2D) -> void:
	await rumi.give_to(target)
	gifted = true


func _check(ok: bool, message: String) -> void:
	if not ok and not failures.has(message):
		failures.append(message)
