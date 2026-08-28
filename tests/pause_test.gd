extends Node
## The pause screen: it stops the world, gives it back unchanged, and knows when
## it is not welcome.
##
## Every assertion here is driven through the real key, not through the menu's
## own methods where it can be helped: a pause menu that only opens when a test
## calls pause_game() is a menu nobody can open. The two exceptions are marked
## and are there to freeze a moment a key press cannot be timed to (the exact
## frame of a resume, and a hitstop that is over in 40 milliseconds).
##
## Run:  godot --headless res://tests/pause_test.tscn

var failures: Array[String] = []
var world: LdtkWorld
var player: Player


func _ready() -> void:
	# The test itself has to outlive the pauses it creates.
	process_mode = Node.PROCESS_MODE_ALWAYS
	LdtkWorld.debug_start_room = "Level_5"
	world = Screen.load_scene("res://ldtk/Act1World.tscn")
	await _frames(60)
	player = world.player
	player.input_locked = false

	_check_bindings()
	_check_surface()
	await _check_stops_the_world()
	await _check_hitstop()
	await _check_refused_mid_cutscene()
	await _check_retry()
	await _check_leaves_playerless_scenes_alone()

	if failures.is_empty():
		print("PAUSE TEST: ALL PASS")
	else:
		print("PAUSE TEST: %d FAILURE(S)" % failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)


## The action exists and carries both a keyboard and a pad binding. Asserted
## because the whole feature is one project.godot entry away from being
## unreachable on a controller, silently, with the keyboard still working.
func _check_bindings() -> void:
	_check(InputMap.has_action("pause"), "there is a `pause` action")
	if not InputMap.has_action("pause"):
		return
	var keys: Array[int] = []
	var buttons: Array[int] = []
	for ev in InputMap.action_get_events("pause"):
		if ev is InputEventKey:
			keys.append((ev as InputEventKey).physical_keycode)
		elif ev is InputEventJoypadButton:
			buttons.append((ev as InputEventJoypadButton).button_index)
	_check(keys.has(KEY_ESCAPE), "Escape pauses  %s" % str(keys))
	_check(buttons.has(JOY_BUTTON_START), "so does Start on a pad  %s" % str(buttons))
	_check(buttons.has(JOY_BUTTON_BACK), "and Select, for pads that label it that way")


## A pause menu is UI, so it belongs on the window's own surface — the world's
## 320x180 sub-viewport would rasterise it into a magnified pixel grid, which is
## the whole argument systems/screen.gd settles.
func _check_surface() -> void:
	_check(not Screen.viewport.is_ancestor_of(Pause),
		"the pause screen is NOT inside the world's 320x180 viewport")
	_check(Pause.layer > Dialogue.layer,
		"it draws in front of the dialogue box (layer %d vs %d)" % [Pause.layer, Dialogue.layer])
	_check(Pause.process_mode == Node.PROCESS_MODE_ALWAYS,
		"and keeps processing while the tree is paused, or it could never close")


## The pause itself: the world stops dead, and starts again from exactly where
## it stopped rather than from wherever a frame of physics put it.
func _check_stops_the_world() -> void:
	Input.action_press("move_right")
	await _frames(15)
	var running := player.global_position.x
	_check(player.velocity.x > 0.0, "he is moving before the pause (%.0f px/s)" % player.velocity.x)

	_press(KEY_ESCAPE)
	await _frames(3)
	_check(get_tree().paused, "Escape pauses the tree")
	_check(Pause.open, "and puts the menu up")
	_check(Pause.selected == PauseMenu.Item.RESUME, "with the cursor on Resume")

	var held_at := player.global_position
	var held_vel := player.velocity
	var held_state := player.state
	# move_right is still held down the whole time.
	await _frames(40)
	_check(player.global_position == held_at,
		"the world does not move while paused, held input and all  (%s)" % player.global_position)
	_check(player.global_position.x > running - 0.001, "and he did not rewind")

	# Closed directly, not with the key: the point of this check is that NO
	# physics runs between the resume and the comparison, and a key press is
	# dispatched on a process frame that a physics frame can slip past.
	Pause.resume_game()
	_check(not get_tree().paused, "resuming unpauses the tree")
	_check(not Pause.open, "and takes the menu down")
	_check(player.global_position == held_at and player.velocity == held_vel
			and player.state == held_state,
		"he comes back in exactly the state he was paused in")

	await _frames(20)
	_check(player.global_position.x > held_at.x + 2.0,
		"and carries straight on running  (+%.1fpx)" % (player.global_position.x - held_at.x))
	Input.action_release("move_right")
	await _frames(10)

	# The key has to work both ways, which the direct close above skips over.
	_press(KEY_ESCAPE)
	await _frames(3)
	var opened := Pause.open
	_press(KEY_ESCAPE)
	await _frames(3)
	_check(opened and not Pause.open and not get_tree().paused,
		"the same key closes it again")


## Pausing inside hitstop must not resume into slow motion.
##
## Juice drops Engine.time_scale to 0.05 for `hitstop_time` real seconds on
## every dash start — 40ms, which is about two frames and far too short to aim a
## key press at. So the window is widened first (the same trade death_test makes
## with death_time) and the dash itself is a real one, through the controller.
func _check_hitstop() -> void:
	var juice: Juice = player.juice
	var real_hitstop: float = juice.hitstop_time
	juice.hitstop_time = 0.6
	player.has_dash = true
	await _frames(10)

	Input.action_press("move_right")
	Input.action_press("dash")
	# PHYSICS frames, not process frames. The dash is read in _physics_process,
	# and headless runs process frames as fast as the machine allows while
	# physics stays pinned to 60Hz — so two process frames can pass in
	# microseconds with no physics frame between them, the dash never starts, and
	# there is no hitstop to find. That is what made this assertion flake.
	await _physics(2)
	Input.action_release("dash")
	Input.action_release("move_right")
	_check(Engine.time_scale < 1.0,
		"dashing really does slow the engine down  (%.2f)" % Engine.time_scale)

	# Opened directly for the same reason as above: the freeze is measured in
	# frames and a parsed key event costs some of them.
	Pause.pause_game()
	_check(is_equal_approx(Engine.time_scale, 1.0),
		"pausing inside hitstop puts the clock back to normal  (%.2f)" % Engine.time_scale)
	await _frames(30)
	Pause.resume_game()
	await _frames(60)
	_check(is_equal_approx(Engine.time_scale, 1.0),
		"and the game resumes at full speed  (%.2f)" % Engine.time_scale)

	juice.hitstop_time = real_hitstop
	await _frames(20)


## `input_locked` is the project's cutscene flag — dialogue beats, story doors
## and room slides all set it — so refusing on it refuses all of them at once.
## A pause opened mid-beat, and worse a resume out of one, is the obvious way
## this breaks.
func _check_refused_mid_cutscene() -> void:
	player.input_locked = true
	_check(not Pause.can_pause(), "pause is refused while his controls are locked")
	_press(KEY_ESCAPE)
	await _frames(5)
	_check(not get_tree().paused and not Pause.open,
		"and the key does nothing at all mid-cutscene")
	player.input_locked = false
	await _frames(2)
	_check(Pause.can_pause(), "and is allowed again the moment the beat ends")


## Retry is the menu's half of R: it hands the game back first, then kills him,
## because the respawn hold is a timer on the level and a paused level never
## finishes counting one.
func _check_retry() -> void:
	Deaths.reset()
	_press(KEY_ESCAPE)
	await _frames(5)
	_check(Pause.open, "the menu opens for the retry check")

	# HELD across a frame, not tapped. The menu polls the movement actions now
	# rather than reacting to their events (PauseMenu._process — an analog stick
	# fires a stream of motion events and the old way moved the cursor once per
	# event). A press-and-release inside one frame is invisible to polling, which
	# is exactly what _press does.
	Input.action_press("move_down")
	await _frames(3)
	Input.action_release("move_down")
	await _frames(1)
	_check(Pause.selected == PauseMenu.Item.RETRY,
		"holding down moves the cursor to Retry (%d)" % Pause.selected)

	_press(KEY_C)  # jump = confirm, same key the dialogue box advances on
	await _frames(5)
	_check(not get_tree().paused and not Pause.open, "choosing Retry lets go of the pause")

	for i in 400:
		await get_tree().process_frame
		if Deaths.total >= 1 and player.state != Player.State.DEAD:
			break
	_check(Deaths.total == 1,
		"and costs exactly one death, like any other retry (%d)" % Deaths.total)
	_check(player.state != Player.State.DEAD, "with the respawn actually arriving")


## Escape already belongs to two things that are not levels: the debug level
## picker, which is the main scene and never goes through Screen at all, and the
## token density prototype, which does go through Screen but has no player and
## uses Escape to leave (tests/token_density.gd). Neither may lose its key.
##
## Stood up as a bare world rather than by loading either of them, because what
## decides the answer is the absence of a player, and that is the one thing both
## of those scenes have in common.
func _check_leaves_playerless_scenes_alone() -> void:
	Screen.set_scene(Node2D.new())
	await _frames(5)
	_check(not Pause.can_pause(),
		"a scene with no player is not a thing to pause")
	_press(KEY_ESCAPE)
	await _frames(5)
	_check(not get_tree().paused and not Pause.open,
		"so Escape stays the prototype's, not the pause menu's")


## One press and release of a physical key, straight into the input system.
## Released as well as pressed so a held action cannot leak into the next check.
func _press(key: Key) -> void:
	for down in [true, false]:
		var ev := InputEventKey.new()
		ev.keycode = key
		ev.physical_keycode = key
		ev.pressed = down
		Input.parse_input_event(ev)


## Physics frames, for the few checks that wait on something the player
## controller does rather than on something input does. See the dash above.
func _physics(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


## Process frames, not physics: input is dispatched on process frames, and these
## have to keep ticking through a pause.
func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _check(cond: bool, name: String) -> void:
	print(("  PASS  " if cond else "  FAIL  ") + name)
	if not cond:
		failures.append(name)
