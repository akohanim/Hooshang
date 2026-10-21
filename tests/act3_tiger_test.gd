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
## And the lemon waits on his words: while a line is up he is on the vine facing
## the cliff (never stood up by the dialogue box), and the first bite comes only
## after "I never ate a single one." has been read and dismissed.
##
## Headless:  Godot --headless --path . --fixed-fps 60 res://tests/act3_tiger_test.tscn

var world: SeaWorld
var player: Player
var failures := 0


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
	for i in 5400:
		await frames(1)
		since += 1
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
		if str(player.visual.animation) == "hang_eat":
			ate = true
			if not read_last_line:
				eat_ok = false
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
	check(bool(world.story.get("scene:vine", false)), "the scene plays out to the end of the act")


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
