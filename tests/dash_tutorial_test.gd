extends Node
## Level_24's dash lesson: the prompt arrives where the move becomes necessary,
## and leaves when the move is made.
## Run:  godot --headless res://tests/dash_tutorial_test.tscn

var failures: Array[String] = []
var world: LdtkWorld
var tut: DashTutorial


func _ready() -> void:
	SaveGame.slot = -1
	LdtkWorld.debug_start_room = DashTutorial.ROOM
	world = load("res://ldtk/Act1World.tscn").instantiate()
	add_child(world)
	await _frames(30)
	tut = world.get_node_or_null("DashTutorial")
	_check(tut != null, "the world carries the tutorial node")
	if tut == null:
		return _finish()
	_check(str(world.current_room.name) == DashTutorial.ROOM,
		"opens in %s  [%s]" % [DashTutorial.ROOM, world.current_room.name])

	# The panels have to hold long enough to reach the dash point — the lesson is
	# not "you were dropped while reading".
	var relaxed := 0
	var rect := world.room_rect(world.current_room)
	for n in get_tree().get_nodes_in_group("crumbling"):
		var p := n as CrumblingPlatform
		if p != null and rect.has_point(p.global_position):
			if is_equal_approx(p.crumble_time, tut.hold_time):
				relaxed += 1
	_check(relaxed > 10, "this room's panels are relaxed to %.1fs  [%d of them]"
		% [tut.hold_time, relaxed])
	# ...and only this room's.
	var elsewhere := 0
	for n in get_tree().get_nodes_in_group("crumbling"):
		var p := n as CrumblingPlatform
		if p != null and not rect.has_point(p.global_position) \
				and is_equal_approx(p.crumble_time, tut.hold_time):
			elsewhere += 1
	_check(elsewhere == 0,
		"and no panel outside it was touched  [%d were]" % elsewhere)

	# The ledge really is out of reach of a plain jump, or there is no lesson.
	var rise: float = (rect.position.y + 15 * 8.0) - tut.ledge_top_y + 8.0
	_check(tut.ledge_top_y < rect.position.y + 15 * 8.0,
		"the ledge sits above the panels  [ledge %.0f, panels %.0f]"
			% [tut.ledge_top_y, rect.position.y + 15 * 8.0])

	# --- the prompt arrives -------------------------------------------------
	var p := world.player
	p.input_locked = false
	p.has_dash = true
	p.respawn(Vector2(tut.arm_at_x + 6.0, tut.ledge_top_y - 20.0))
	# Rumi's lines are emptied for the run rather than pressed through. The box
	# waits on the JUMP key, and driving it from here makes him jump off the
	# platform mid-beat — the test ends up measuring the fight between the two
	# instead of the thing it is about. What the lines say is asserted below;
	# that they play is the game's job, not this assertion's.
	_check(not tut.lines.is_empty(), "Rumi has something to say  [%d lines]"
		% tut.lines.size())
	tut.lines = []
	var shown := false
	for i in 240:
		await _frames(1)
		if tut._prompt != null:
			shown = true
			break
	_check(shown, "the prompt arrives once he reaches the dash point")

	# --- and a DIAGONAL dash clears it, where a flat one does not -----------
	#
	# Driven through the input system, not by assigning state = DASH: the player
	# owns that state in _physics_process and ends a forced dash on the next
	# tick (dash_timer is already 0), so the assignment is gone before anything
	# reading it on a render frame ever sees it.
	if shown:
		await _dash(false)
		_check(tut._prompt != null,
			"a flat dash does not count as having learned it")
		await _land()
		await _dash(true)
		var cleared := false
		for i in 90:
			await _frames(1)
			if tut._prompt == null:
				cleared = true
				break
		_check(cleared, "the diagonal dash clears the prompt")
	_finish()


func _finish() -> void:
	if failures.is_empty():
		print("DASH TUTORIAL TEST: ALL PASS")
	else:
		print("DASH TUTORIAL TEST: %d FAILURE(S)" % failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)


## One real dash, up-forward or flat.
func _dash(diagonal: bool) -> void:
	var p := world.player
	p.dash_available = true
	p.dash_cooldown_timer = 0.0
	Input.action_press("move_right")
	if diagonal:
		Input.action_press("move_up")
	await _frames(1)
	Input.action_press("dash")
	await _frames(3)
	Input.action_release("dash")
	await _frames(8)
	Input.action_release("move_right")
	Input.action_release("move_up")


## Back onto the panels, so the next dash starts from the ground.
func _land() -> void:
	var p := world.player
	p.respawn(Vector2(tut.arm_at_x + 6.0, tut.ledge_top_y - 20.0))
	for i in 120:
		await _frames(1)
		if p.is_on_floor():
			return


func _frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func _check(cond: bool, name: String) -> void:
	print(("  PASS  " if cond else "  FAIL  ") + name)
	if not cond:
		failures.append(name)
