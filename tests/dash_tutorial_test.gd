extends Node
## Level_2's dash lesson: the prompt arrives where the move becomes necessary,
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

	# The lesson needs him to end up BELOW what he has to reach, and this used to
	# ask that of a hardcoded tile row rather than of the panels — so when the run
	# was raised level with the ledge, the check went on passing against a row
	# nothing stands on any more. It reads the panels themselves now.
	var panel_top := INF
	for n in get_tree().get_nodes_in_group("crumbling"):
		var pl := n as CrumblingPlatform
		if pl != null and rect.has_point(pl.global_position):
			panel_top = minf(panel_top, pl.top_y())
	var hang_y: float = tut.ledge_top_y + tut.hang_offset.y
	_check(hang_y > tut.ledge_top_y + 8.0,
		"he is caught below the ledge he has to reach  [hang %.0f, ledge %.0f, panels %.0f]"
			% [hang_y, tut.ledge_top_y, panel_top])
	# ...and he FALLS there rather than being put there: the catch line has to be
	# below the floor he was walking on, or the freeze is a teleport again.
	_check(hang_y > panel_top - 6.0,
		"and the fall to it is a fall  [%.0fpx below the run]" % (hang_y - (panel_top - 6.0)))

	# --- he is CAUGHT when the floor goes, not left to fall -----------------
	#
	# Rumi's lines are emptied for the run rather than pressed through. The box
	# waits on the JUMP key, and driving it from here makes him jump mid-beat —
	# the test ends up measuring the fight between the two instead of the thing
	# it is about. What the lines say is asserted here; that they play is the
	# game's job.
	_check(not tut.lines.is_empty(), "Rumi has something to say  [%d lines]"
		% tut.lines.size())
	_check(not tut.gift_lines.is_empty(), "...including the hand-over  [%d lines]"
		% tut.gift_lines.size())
	tut.lines = []
	tut.gift_lines = []

	var p := world.player
	p.input_locked = false
	# DASHLESS. This room is where the dash comes from now — Rumi hands it over
	# at the catch, in the breath before the lesson that needs it — so a test
	# that grants the dash up front is a test of a room nobody plays.
	p.has_dash = false
	# Dropped in ABOVE the panels, past the dash point, already falling.
	p.respawn(Vector2(tut.arm_at_x + 10.0, tut.ledge_top_y - 40.0))
	var caught := false
	var locked_falling := false
	for i in 240:
		await _frames(1)
		# THE FALL IS NOT HIS. His controls go the moment the floor does, so he
		# cannot steer or dash out of the drop the lesson is about — and they come
		# back with the prompt, or there is nothing he can press to answer it.
		if tut._pulled and not tut._held and p.input_locked:
			locked_falling = true
		if tut._prompt != null:
			caught = true
			break
	_check(caught, "he is caught mid-fall and the prompt arrives")
	_check(p.has_dash, "and Rumi has handed him the dash he is about to need")
	_check(locked_falling, "his controls are gone for the fall")
	_check(not p.input_locked, "and back in his hands at the hang point")

	# THE FLOOR IS TAKEN, not waited for. Relaxed enough to hold while he crosses,
	# the panels also held long enough to walk the whole run and never need the
	# move at all — so reaching the point pulls what is left of them.
	#
	# `bounds`, not `rect`: this scope already has a `rect` further up, and the
	# redeclaration is a PARSE error, which does not fail the run — the script
	# simply never loads, so quit() is never reached and the process hangs with
	# its output still buffered. Silent, and it looks exactly like a deadlock.
	_check(tut._pulled, "reaching the point pulls the floor")
	# ...and given time to finish. The collapse is STAGGERED left to right, so a
	# count taken on the frame he is caught finds most of the run still standing
	# — which is the effect working, not failing.
	var bounds := world.room_rect(world.current_room)
	var span := tut.collapse_time + 19.0 * tut.collapse_stagger + 0.5
	for i in int(span * 60.0):
		await _frames(1)
	var standing := 0
	for n in get_tree().get_nodes_in_group("crumbling"):
		var cp := n as CrumblingPlatform
		if cp != null and bounds.has_point(cp.global_position) \
				and cp.get_collision_layer_value(1):
			standing += 1
	_check(standing == 0,
		"and every panel in the room is gone  [%d still solid]" % standing)

	if caught:
		var at := p.global_position
		_check(at.distance_to(tut._hang) < 2.0,
			"...held at the hang point  [%s vs %s]" % [at, tut._hang])
		# FROZEN: a second later he is still there, not sliding or sinking.
		await _frames(60)
		_check(p.global_position.distance_to(tut._hang) < 2.0,
			"and he is still there a second later  [%s]" % p.global_position)
		# Not zero — ONE frame of gravity. The pin runs after his physics, so he
		# is always carrying whatever gravity added since it last fired; what
		# matters is that it never accumulates into a fall, which the position
		# checks either side of this already say. A whole frame at rise_gravity
		# is ~27, so anything under 40 is that and nothing more.
		_check(p.velocity.length() < 40.0,
			"and gravity never builds on him  [%s]" % p.velocity)

		# A flat dash is not the lesson: it plays out, and the pin takes him back.
		await _dash(false)
		_check(tut._prompt != null,
			"a flat dash does not count as having learned it")
		for i in 90:
			await _frames(1)
			if p.global_position.distance_to(tut._hang) < 2.0:
				break
		_check(p.global_position.distance_to(tut._hang) < 2.0,
			"and he is put back where he was  [%s]" % p.global_position)

		# The diagonal releases him.
		await _dash(true)
		var cleared := false
		for i in 90:
			await _frames(1)
			if tut._prompt == null:
				cleared = true
				break
		_check(cleared, "the diagonal dash clears the prompt")
		_check(not tut._held, "and lets go of him")
		await _frames(30)
		_check(p.global_position.distance_to(tut._hang) > 8.0,
			"so he actually leaves the spot  [%s]" % p.global_position)
		# AND IT HAS TO REACH. "He left the spot" also describes falling into the
		# pit, which is what the room does to a dash that comes up short — so the
		# lesson is only taught if the move that answers it lands him on the ledge.
		# The catch depth is set against this: the dash rises a flat 33px and he
		# has to finish 6px above the surface, so every pixel he is caught lower
		# comes straight off the margin.
		for i in 120:
			await _frames(1)
			if p.is_on_floor():
				break
		_check(p.is_on_floor() and p.global_position.y < tut.ledge_top_y - 2.0
				and p.global_position.x > tut.ledge_x,
			"and the dash puts him on the ledge  [%s, ledge top %.0f x %.0f]"
				% [p.global_position, tut.ledge_top_y, tut.ledge_x])
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


func _frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func _check(cond: bool, name: String) -> void:
	print(("  PASS  " if cond else "  FAIL  ") + name)
	if not cond:
		failures.append(name)
