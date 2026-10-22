extends Node
## THE TIGER and THE VINE (SCRIPT.md TWELVE and THIRTEEN), with real input.
##
## The tiger is a pursuer, not an echo (scenes/props/sea/chase_tiger.gd). It used
## to replay his path a second behind, which copied his pacing and his jumps on
## the spot and walked away from him when he doubled back, so he could chase it.
## Checked here:
##   - it never moves AWAY from him, frame by frame, while he runs, stops and
##     turns round;
##   - turning round to face it gets him caught, not a tiger running off;
##   - jumping on the spot is not copied: it stays on the ground and comes on;
##   - a respawn lays it down a run-up behind him, and it holds until he moves.
## The vine scene is staged on the rock: the vine is rooted in the cliff top and
## hangs down IN FRONT of the face (most of it over the rock), it never moves,
## not even while the mice gnaw; both mice stand on the cliff top, solid ground
## under their feet by a physics ray; and the lemon is the game's own collectible
## lemon. And the lemon waits on his words: while a line is up he is on the vine facing
## the cliff (never stood up by the dialogue box); the lemon stays growing on the
## cliff through both "All those lemons." and "I never ate a single one." (taken
## sooner it sat over his face and read as eaten); and he picks it and eats it
## between that line and "...Oh. That's good.".
##
## Headless:  Godot --headless --path . --fixed-fps 60 res://tests/act3_tiger_test.tscn

var world: SeaWorld
var player: Player
var failures := 0
var _captures := {}


func _ready() -> void:
	get_tree().create_timer(600.0, true, false, true).timeout.connect(func():
		print("ACT3_TIGER: TIMEOUT"); get_tree().quit(3))
	SaveGame.unbind()
	Sfx.muted = true
	await chase_checks()
	await vine_checks()
	print("ACT3_TIGER: %d failures" % failures)
	get_tree().quit(0 if failures == 0 else 1)


func open(room_name: String) -> void:
	if is_instance_valid(world):
		# Drain the previous retry's deferred overlap checks before replacing it.
		world.player.set_physics_process(false)
		await frames(6)
	LdtkWorld.debug_start_room = room_name
	world = load("res://ldtk/Act3World.tscn").instantiate()
	Screen.set_scene(world)
	await frames(40)
	player = world.player


func chase_checks() -> void:
	# The wood, opened cold: the tiger has already roared and is on him.
	await open("Act3_Level_29")
	var tiger := world.get_node_or_null("Tiger") as ChaseTiger
	check(tiger != null and tiger.chasing, "opening mid-chase puts the tiger on him")
	if tiger == null:
		return
	check(player.global_position.x - tiger.global_position.x > 50.0,
		"it starts a run-up behind him  [gap %.0f]" % (player.global_position.x - tiger.global_position.x))

	# Run on, stop, turn round: every frame it moves toward him or not at all.
	var away := 0
	var plan := [["move_right", 50], ["", 25], ["move_left", 70]]
	var died := false
	for leg in plan:
		release()
		if leg[0] != "":
			Input.action_press(leg[0])
		for i in int(leg[1]):
			var before := tiger.global_position.x
			var him := player.global_position.x
			await frames(1)
			if player.state == Player.State.DEAD:
				died = true
				break
			var moved := tiger.global_position.x - before
			if absf(moved) > 0.01 and signf(moved) != signf(him - before):
				away += 1
		if died:
			break
		if leg[0] == "move_right":
			await capture("chase")
	release()
	check(away == 0, "the tiger never moves away from him  [%d frames it did]" % away)
	check(died, "turning round to face it gets him caught, not a tiger running off")

	# A respawn: it is laid down behind him and waits for him to move.
	await settle_dead()
	await frames(4)
	var gap := player.global_position.x - tiger.global_position.x
	check(gap > 50.0, "after a respawn it is a run-up behind him  [gap %.0f]" % gap)
	var held := tiger.global_position
	await frames(40)
	check(tiger.global_position.distance_to(held) < 0.5, "...and holds there while he stands still")

	# Jumping on the spot is not copied: it stays on the ground and comes on.
	var ground_y := tiger.global_position.y
	var highest := ground_y
	died = false
	for i in 420:
		if i % 30 == 0:
			Input.action_press("jump")
		elif i % 30 == 12:
			Input.action_release("jump")
		await frames(1)
		highest = minf(highest, tiger.global_position.y)
		if player.state == Player.State.DEAD:
			died = true
			break
	release()
	check(ground_y - highest < 2.0, "it does not copy his jumps on the spot  [rose %.1f px]" % (ground_y - highest))
	check(died, "jumping on the spot does not keep it off him")
	await settle_dead()


func vine_checks() -> void:
	# The edge, opened cold: run off it, then read each line before going on.
	await open("Act3_Level_31")
	Input.action_press("move_right")
	for i in 600:
		if i % 20 == 0:
			Input.action_press("jump")
		elif i % 20 == 8:
			Input.action_release("jump")
		await frames(1)
		if player.input_locked:
			break
	release()
	var stood_up := 0
	var faced_away := 0
	var read_last_line := false
	var line_up := ""
	var eat_ok := true
	var ate := false
	var since := 0
	var lemon: Node2D = null
	var lemon_home := Vector2.ZERO
	var lemon_early := false
	var oh_seen := false
	var ate_before_oh := false
	var walked_mice := false
	var chewed_black := {}
	var chewed_white := {}
	var mice_inward := true
	var lower_tiger_shown := false
	var beats := world.get_node("Act3Beats")
	var lip: Vector2 = beats._lip(world.current_room)
	var vine_at := Vector2.INF
	var vine_moved := 0
	var mouse_frames := 0
	var mice_off_ground := 0
	for i in 5400:
		await frames(1)
		since += 1
		var black := world.current_room.get_node_or_null("MouseBlack") as VineMouse
		var white := world.current_room.get_node_or_null("MouseWhite") as VineMouse
		var vine := world.current_room.get_node_or_null("Vine") as Sprite2D
		if vine != null:
			if vine_at == Vector2.INF:
				vine_at = vine.global_position
			elif vine.global_position != vine_at or vine.rotation != 0.0:
				vine_moved += 1
		for mouse: VineMouse in [black, white]:
			if mouse != null and mouse.modulate.a > 0.5:
				mouse_frames += 1
				if not _on_ground(mouse):
					mice_off_ground += 1
		if black != null and white != null:
			walked_mice = walked_mice or black.animation == &"black_walk"
			if black.animation == &"black_gnaw" and white.animation == &"white_gnaw":
				chewed_black[black.frame] = true
				chewed_white[white.frame] = true
				mice_inward = mice_inward and not black.flip_h and white.flip_h
				await capture("vine_mice")
		var below := world.current_room.get_node_or_null("TigerBelow") as ChaseTiger
		if below != null and below.visual.animation == &"look_up":
			var view := Rect2(player.camera.get_screen_center_position() - Vector2(160, 90), Vector2(320, 180))
			lower_tiger_shown = lower_tiger_shown or view.has_point(below.global_position - Vector2(0, 10))
			await capture("tiger_below")
		var box: Node = Dialogue
		var line := ""
		if box.visible:
			line = str(box.text_label.get_parsed_text())
			var anim := str(player.visual.animation)
			if not anim.begins_with("hang"):
				stood_up += 1
			if not player.visual.flip_h:
				faced_away += 1
		if line != line_up:
			if line_up == "I never ate a single one." and line == "":
				read_last_line = true
			line_up = line
			since = 0
		if lemon == null:
			lemon = world.current_room.get_node_or_null("Lemon") as Node2D
			if lemon != null:
				lemon_home = lemon.global_position
		# The lemon stays growing on the cliff until both his lines are done.
		if lemon != null and not read_last_line and lemon.global_position.distance_to(lemon_home) > 0.5:
			lemon_early = true
		if line.begins_with("...Oh."):
			oh_seen = true
		if str(player.visual.animation) == "hang_eat":
			ate = true
			if not read_last_line:
				eat_ok = false
			if not oh_seen:
				ate_before_oh = true
		# Read each line for a second, then press on, as a player does.
		if box.visible and since == 70:
			_tap(&"jump", true)
		elif since == 74:
			_tap(&"jump", false)
		if world.story.get("scene:vine", false):
			break
	check(stood_up == 0, "on the vine through every line, never stood up by the dialogue  [%d frames]" % stood_up)
	check(faced_away == 0, "facing the cliff and the lemon while he speaks  [%d frames]" % faced_away)
	check(ate, "he eats the lemon")
	check(eat_ok, "the first bite waits until \"I never ate a single one.\" has been read")
	check(not lemon_early, "the lemon stays on the cliff until both his lines are done")
	check(ate_before_oh, "he has eaten it by the time he says \"...Oh. That's good.\"")
	check(walked_mice, "both new mouse actors walk out before gnawing")
	check(mouse_frames > 0 and mice_off_ground == 0,
		"the mice stand on the cliff top, never in the air  [%d of %d frames off]" % [mice_off_ground, mouse_frames])
	check(vine_at != Vector2.INF and vine_moved == 0, "the vine holds still, even while they gnaw  [%d frames moved]" % vine_moved)
	var vine_node := world.current_room.get_node_or_null("Vine") as Sprite2D
	var over := _share_over_face(vine_node, lip)
	check(over > 0.75, "the vine hangs in front of the cliff face, not beside it  [%d%% over the rock]" % int(over * 100))
	check(vine_node != null and vine_node.z_index > 0, "...drawn in front of the terrain")
	var fruit := world.current_room.get_node_or_null("Lemon") as AnimatedSprite2D
	check(fruit != null and fruit.sprite_frames == load("res://assets/props/lemon/lemon_frames.tres"),
		"the lemon on the cliff is the game's own collectible lemon")
	check(mice_inward, "mice face inward while gnawing")
	check(lower_tiger_shown, "camera actually reveals the lower tiger during its upward look")
	check(chewed_black.size() >= 3 and chewed_white.size() >= 3, "both mice animate through the final conversation")
	check(bool(world.story.get("scene:vine", false)), "the scene plays out to the end of the act")
	await capture("ending")


## A mouse is on the ground when the world is solid just under both ends of its
## body: a ray down from its feet, at its tail and at its nose.
func _on_ground(mouse: VineMouse) -> bool:
	var space := world.get_world_2d().direct_space_state
	var feet := mouse.global_position + Vector2(0, Act3Beats.MOUSE_FEET)
	for dx in [-5.0, 5.0]:
		var from := feet + Vector2(dx, -1.0)
		var hit := space.intersect_ray(PhysicsRayQueryParameters2D.create(from, from + Vector2(0, 3.0), 1))
		if hit.is_empty():
			return false
	return true


## How much of the vine below the cliff top is drawn over the rock (left of the
## lip) rather than out in the air beside it.
func _share_over_face(vine: Sprite2D, lip: Vector2) -> float:
	if vine == null:
		return 0.0
	var img := vine.texture.get_image()
	var w := img.get_width() / vine.hframes
	var over := 0
	var total := 0
	for y in img.get_height():
		for x in w:
			if img.get_pixel(x, y).a < 0.5:
				continue
			var at := vine.global_position + Vector2(x + 0.5, y + 0.5)
			if at.y < lip.y + 4.0:
				continue
			total += 1
			if at.x < lip.x:
				over += 1
	return float(over) / maxf(1.0, total)


func capture(label: String) -> void:
	if not "--capture" in OS.get_cmdline_user_args() or _captures.has(label):
		return
	_captures[label] = true
	await RenderingServer.frame_post_draw
	var image := Screen.viewport.get_texture().get_image()
	image.resize(1280, 720, Image.INTERPOLATE_NEAREST)
	image.save_png("res://artifacts/act3_finale/%s.png" % label)


func _tap(action: StringName, pressed: bool) -> void:
	var ev := InputEventAction.new()
	ev.action = action
	ev.pressed = pressed
	Input.parse_input_event(ev)


func settle_dead() -> void:
	release()
	for i in 300:
		if player.state != Player.State.DEAD and not world._transitioning:
			return
		await frames(1)


func release() -> void:
	for a in ["move_left", "move_right", "move_up", "move_down", "jump", "dash"]:
		Input.action_release(a)


func frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func check(ok: bool, message: String) -> void:
	print(("  PASS " if ok else "  FAIL ") + message)
	if not ok:
		failures += 1
