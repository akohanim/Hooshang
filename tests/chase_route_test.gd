extends Node
## Regression: meeting Darkshang re-points the boss room's entrance.
##
## Level_13 is walked into from the left and the reveal turns Hooshang round, so
## the way out is the doorway he came in through. That doorway is the generic
## return door, which leads to the room behind — and the room behind is Level_12,
## a room he has already cleared. The escape actually continues into Level_14,
## which hangs below the row and is authored right to left (PlayerStart at its
## right end, Exit at its left).
##
## Three things this pins, in the order they broke:
##   1. BEFORE the encounter the doorway is ordinary backtracking and must stay
##      ordinary — the re-route is the encounter's doing, not the room's.
##   2. AFTER it, the same doorway lands him at Level_14's ENTRANCE.
##   3. It holds. The return door is rebuilt every time it is used, so a
##      re-route written once into _return_room would survive exactly until the
##      player walked back INTO the boss room and then quietly revert to layout
##      order — which reads in play as "it worked the first time".
##
## And a fourth, which is about the same threshold rather than the same feature:
## the doorway and the MOON hang off two different signals on purpose. The
## doorway re-points on `triggered`, the instant he crosses the line, because a
## route that gets missed strands the player. The moon turns on `chase_begun`,
## after the reveal dialogue, because on `triggered` its eight-second ramp played
## out entirely underneath the dialogue banner — the most deliberate visual in
## the Act, spent behind a text box. Pinned here because "which signal" is a
## one-word edit that nothing else would notice.
## Run:  godot --headless res://tests/chase_route_test.tscn

var failures: Array[String] = []
var world: LdtkWorld
var from_room: Node2D
var chase_room: Node2D
var next_room: Node2D


func _ready() -> void:
	# Open in Level_12 rather than at the start of the Act: the opening cutscene
	# locks input and waits on a button press that headless will never send.
	LdtkWorld.debug_start_room = "Level_12"
	world = load("res://ldtk/Act1World.tscn").instantiate()
	add_child(world)
	await _frames(10)
	LdtkWorld.debug_start_room = ""

	from_room = _room("Level_12")
	chase_room = _room("Level_13")
	next_room = _room("Level_14")
	_check(from_room != null and chase_room != null and next_room != null,
		"the three rooms of the chase all exist")
	if from_room == null or chase_room == null or next_room == null:
		return _finish()
	_check(world.current_room == from_room,
		"opened in Level_12  [%s]" % world.current_room.name)

	# The wiring itself, before any of the behaviour: Act I claims the encounter.
	# Checked separately because if this connection is missing every assertion
	# below still passes the moment the test emits `triggered` by hand.
	var trigger := _chase_trigger()
	_check(trigger != null, "Level_13 has a DarkshangTrigger")
	if trigger == null:
		return _finish()
	_check(trigger.triggered.get_connections().size() > 0,
		"and something claimed its `triggered` beat  [%d listener(s)]"
			% trigger.triggered.get_connections().size())

	# --- 1. before the encounter, the doorway is an ordinary way back ---------
	await _go_forward()
	_check(world.current_room == chase_room,
		"walked into Level_13  [%s]" % world.current_room.name)
	await _go_back()
	_check(world.current_room == from_room,
		"untriggered, backing out of Level_13 still leads to Level_12  [%s]"
			% world.current_room.name)

	# --- 2. after it, the same doorway continues the escape -------------------
	await _go_forward()
	_check(world.current_room == chase_room, "back in Level_13 for the encounter")
	# The crossing itself, not _play(): the reveal awaits two lines of dialogue
	# and a button press each. `triggered` is what the trigger emits on the frame
	# the player breaks the line, before any of that — see darkshang_trigger.gd.
	# The moon must NOT move on this signal. Read off shadow_amount, the umbra the
	# eclipse tween actually drives, rather than off a flag — a moon that sets
	# "turning = true" and never reaches the window is the failure worth catching,
	# and it stays invisible until the escape row looks wrong ten rooms later.
	#
	# BOTH windows, not just the first. Level_13's back wall carries two moons and
	# they are one sky: a test that watched only the window named by
	# `blood_moon_window` would pass with the second one never wired up at all,
	# and the room would play with one red moon and one blue one.
	var moons := _moons()
	var glows := _moon_glows()
	_check(moons.size() == 2,
		"Act1Beats drives BOTH of the boss room's moon windows  [%d]" % moons.size())
	_check(glows.size() == moons.size(),
		"and each of them has its light paired with it  [%d]" % glows.size())
	if moons.is_empty():
		return _finish()
	var moon: MoonWindow = moons[0]
	var before: float = moon.shadow_amount
	_check(_all_in_step(moons), "they start on the same moon  [%s]" % _amounts(moons))
	var glow_before: float = glows[0].light_energy if not glows.is_empty() \
			and glows[0] != null else -1.0
	trigger.triggered.emit(world.player)
	await _frames(20)
	_check(is_equal_approx(moon.shadow_amount, before),
		"crossing the line does NOT start the moon — the dialogue would hide it  [%.3f]"
			% moon.shadow_amount)
	_check(_all_in_step(moons),
		"and it starts none of the others either  [%s]" % _amounts(moons))
	# And it does turn, once the beat that was hiding it is over. Given a real
	# slice of the ramp rather than a few frames: the crossing is eased IN, so
	# half a second of an eight-second turn is a couple of thousandths and
	# would read the same as nothing happening.
	trigger.chase_begun.emit()
	await _frames(180)
	_check(moon.shadow_amount > before + 0.05,
		"...and finishing the reveal starts it  [%.3f -> %.3f]"
			% [before, moon.shadow_amount])
	# The second window is the assertion. Every one of them has moved, and they
	# are all at the SAME point of the ramp — one call site, one frame, one
	# duration, so nothing can have started late or on a different curve.
	for m in moons:
		_check(m.shadow_amount > before + 0.05,
			"...every window in the room turns  [%s = %.3f]" % [m.name, m.shadow_amount])
	_check(_all_in_step(moons),
		"...and they turn together, in step  [%s]" % _amounts(moons))
	# The lights they are paired with go with them, or a second window turns red
	# over a room still lit cold blue.
	for g in glows:
		_check(g != null and g.light_energy < glow_before - 0.05,
			"...and each paired light drains with it  [%s = %.3f]"
				% [g.name if g != null else "<none>",
					g.light_energy if g != null else -1.0])
	_check(glows.size() < 2 or is_equal_approx(glows[0].light_energy, glows[1].light_energy),
		"...in step as well  [%.3f vs %.3f]"
			% [glows[0].light_energy, glows[1].light_energy])
	# The RESUME path is the same call with `animated` false — a slot loaded after
	# the encounter snaps the moon rather than replaying the turn. It has to snap
	# EVERY window: a second window wired into only the animated path comes back
	# from a save as a blue moon beside a red one.
	var beats := world.get_node_or_null("Act1Beats") as Act1Beats
	_check(beats != null, "the world has an Act1Beats to resume through")
	if beats != null:
		beats._turn_the_moon(false)
		await _frames(2)
		for m in moons:
			_check(is_equal_approx(m.shadow_amount, m.blood_shadow_amount)
					and m.moon_color.is_equal_approx(m.blood_moon_color),
				"a resumed save snaps it, and snaps all of it  [%s = %.3f]"
					% [m.name, m.shadow_amount])
	await _go_back()
	_check(world.current_room == next_room,
		"after meeting him it leads to Level_14 instead  [%s]" % world.current_room.name)
	# At its ENTRANCE — a re-routed door is a way onward, so it lands where the
	# room begins rather than beside the Exit an ordinary backtrack arrives at.
	# _checkpoint is where the slide actually put him, exactly.
	_check(world._checkpoint.is_equal_approx(world.spawn_point_for(next_room)),
		"landing at Level_14's PlayerStart  [%s vs %s]"
			% [world._checkpoint, world.spawn_point_for(next_room)])

	# --- 3. and it holds, however many times the doorway is used --------------
	await _go_back()
	_check(world.current_room == chase_room,
		"Level_14 still backs out into Level_13  [%s]" % world.current_room.name)
	await _go_back()
	_check(world.current_room == next_room,
		"and leaving Level_13 a second time still goes to Level_14  [%s]"
			% world.current_room.name)

	# Level_12 is behind him for good, which is the point: the room he cleared on
	# the way in is not somewhere the chase can spill back into.
	await _go_back()
	_check(world._return_room == next_room,
		"the boss room's doorway no longer points at Level_12  [%s]"
			% world._return_room.name)
	# Only the one doorway moved, and its mirror. Every other room is left to
	# layout order, which is what backtrack_test walks end to end.
	_check(world._way_back.size() == 2
			and world._way_back.get(chase_room.name) == next_room.name
			and world._way_back.get(next_room.name) == chase_room.name,
		"and the re-route is the two halves of one door  [%s]" % world._way_back)

	# --- 4. the chase carries on past Level_14 -------------------------------
	# Level_15 sits to the LEFT of Level_14 on the bottom row, so world-sort order
	# runs ... Level_13, Level_15, Level_14 while the chase runs 11 -> 12 -> 13.
	# Layout order is wrong for this whole branch, and every fallback in the room
	# manager is layout order — which is why both directions are walked here.
	var last_room := _room("Level_15")
	_check(last_room != null, "Level_15 exists")
	if last_room != null:
		await _go_back()             # back into Level_14, facing its Exit
		_check(world.current_room == next_room, "back in Level_14")
		await _go_forward()
		_check(world.current_room == last_room,
			"Level_14's Exit reaches Level_15  [%s]" % world.current_room.name)
		await _go_back()
		_check(world.current_room == next_room,
			"and Level_15 backs out into Level_14  [%s]" % world.current_room.name)

	_finish()


## Leave the current room by tripping its Exit.
func _go_forward() -> void:
	var from: Node2D = world.current_room
	var ex := world._exit_in(from)
	if ex == null:
		_check(false, "%s has no Exit to walk out of" % from.name)
		return
	world.player.global_position = ex.global_position + Vector2(0, -8)
	await _settle(from)


## Walk into the return strip on the edge we came in through. Which edge that is
## comes from the world, not from an assumption here — Level_14 sits to the LEFT
## of Level_13 despite being the room after it, so a hardcoded left edge would
## test the wrong wall on the way home.
func _go_back() -> void:
	var from: Node2D = world.current_room
	world.player.global_position = world._return_zone.global_position
	await _settle(from)


func _settle(from: Node2D) -> void:
	for i in 200:
		await _frames(1)
		if not world._transitioning and world.current_room != from:
			break
	await _frames(25)   # let _arm_return finish its two-frame confirmation


func _room(name: String) -> Node2D:
	for r in world.rooms:
		if r.name == name:
			return r
	return null


## The window Act1Beats turns to blood, found the way the game finds it —
## through the beats node's own exported NodePath. A test that reached for any
## MoonWindow in the scene would pass with the export blank, which is the one
## thing that stops the moon turning at all.
func _moon() -> MoonWindow:
	var found := _moons()
	return found[0] if not found.is_empty() else null


## EVERY window it turns — the single export first, then the list beside it, in
## the order _turn_the_moon walks them. Same rule as _moon(): found through the
## beats node's own exports, so a blank one is a failure and not a silent pass.
func _moons() -> Array[MoonWindow]:
	var found: Array[MoonWindow] = []
	var beats := world.get_node_or_null("Act1Beats") as Act1Beats
	if beats == null:
		return found
	for path in _moon_paths(beats):
		var window := beats.get_node_or_null(path) as MoonWindow
		if window != null:
			found.append(window)
	return found


## The lights paired with them, in the same order.
func _moon_glows() -> Array[LampFixture]:
	var found: Array[LampFixture] = []
	var beats := world.get_node_or_null("Act1Beats") as Act1Beats
	if beats == null:
		return found
	var paths: Array[NodePath] = []
	if not beats.blood_moon_window.is_empty():
		paths.append(beats.blood_moon_glow)
	paths.append_array(beats.blood_moon_glows)
	for path in paths:
		if path.is_empty():
			continue
		var glow := beats.get_node_or_null(path) as LampFixture
		if glow != null:
			found.append(glow)
	return found


func _moon_paths(beats: Act1Beats) -> Array[NodePath]:
	var paths: Array[NodePath] = []
	if not beats.blood_moon_window.is_empty():
		paths.append(beats.blood_moon_window)
	for path in beats.blood_moon_windows:
		if not path.is_empty():
			paths.append(path)
	return paths


## Whether every window is at the same point of the ramp. Two tweens started in
## the same frame with the same duration land on the same value every frame; two
## started a frame apart do not, and that is exactly the drift worth catching.
func _all_in_step(moons: Array[MoonWindow]) -> bool:
	for m in moons:
		if not is_equal_approx(m.shadow_amount, moons[0].shadow_amount):
			return false
	return true


func _amounts(moons: Array[MoonWindow]) -> String:
	var parts: Array[String] = []
	for m in moons:
		parts.append("%s=%.3f" % [m.name, m.shadow_amount])
	return ", ".join(parts)


func _chase_trigger(node: Node = null) -> DarkshangTrigger:
	var here: Node = node if node != null else chase_room
	if here is DarkshangTrigger:
		return here
	for child in here.get_children():
		var found := _chase_trigger(child)
		if found != null:
			return found
	return null


func _frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func _check(cond: bool, name: String) -> void:
	print(("  PASS  " if cond else "  FAIL  ") + name)
	if not cond:
		failures.append(name)


func _finish() -> void:
	if failures.is_empty():
		print("CHASE ROUTE TEST: ALL PASS")
	else:
		print("CHASE ROUTE TEST: %d FAILURE(S)" % failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)
