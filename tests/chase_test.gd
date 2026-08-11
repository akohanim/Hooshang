extends Node
## The Darkshang chase: a shadow that is a DELAYED ECHO of the player.
##
## Driven by the real player, in the real world scene, in the real Level_11 —
## the same reasoning as conveyor_test.gd. Every claim this mechanic makes is a
## claim about the relationship between two positions over time, and a test that
## wrote those positions by hand would be asserting its own arithmetic.
##
## The five things that must hold, in the order a player would meet them:
##   1. he retraces the player's path at the delay, to the pixel
##   2. solid geometry does not slow him, stop him or bend him
##   3. a surge closes the gap, and the delay decays back afterwards
##   4. contact runs the EXISTING death exactly once (Deaths.total)
##   5. a respawn is survivable — never an instant re-catch
## Run:  godot --headless res://tests/chase_test.tscn

const DARKSHANG_SCENE := preload("res://scenes/props/chase/Darkshang.tscn")
const BUFFER_SCENE := preload("res://scenes/props/chase/PlayerPositionBuffer.tscn")
const SURGE_SCENE := preload("res://scenes/props/chase/SurgePointTrigger.tscn")
const GATE_SCENE := preload("res://scenes/props/chase/DarkshangTrigger.tscn")
const SAFE_SCENE := preload("res://scenes/props/chase/SafeZoneTrigger.tscn")

var failures: Array[String] = []
var world: LdtkWorld
var player: Player
var room: Node2D
var shadow: Darkshang
var tick := 60.0
var floor_point := Vector2.ZERO


func _ready() -> void:
	tick = float(Engine.physics_ticks_per_second)

	# --- the tape, on its own ---
	# Before anything real touches it: a ring buffer that reads back the wrong
	# frame is a chase that is subtly, unfalsifiably too easy, and nothing
	# downstream would ever look wrong enough to investigate.
	await _test_buffer()

	# --- the world ---
	world = load("res://ldtk/Act1World.tscn").instantiate()
	Screen.set_scene(world)
	for i in 30:
		if not world.rooms.is_empty():
			break
		await get_tree().process_frame
	await _frames(30)
	player = world.player
	player.input_locked = false
	player.has_dash = true

	room = _room_named("Level_11")
	_check(room != null, "Level_11 is in the world")
	if room == null:
		_finish()
		return
	world._enter_room(room, true)
	await _frames(20)

	# Level_11's OWN surge points and safe zone are stood down for the whole run.
	# They are real, they are asserted on below, and they are also strewn across
	# the only floor this test has to work with — a player driven 120 frames to
	# the right walks through them, which turns "he retraces the path" into "he
	# retraces the path except for the surge nobody asked for". The staged
	# triggers further down are the ones under test; these are the room.
	var room_surges := _in_room("surge_point")
	var room_safes := _in_room("safe_zone")
	print("  NOTE  Level_11 imported %d SurgePoint(s) and %d SafeZone(s) from LDtk"
		% [room_surges.size(), room_safes.size()])
	for t in room_surges + room_safes:
		t.spent = true
		t.monitoring = false
	for t in room_surges:
		var sp: SurgePointTrigger = t
		_check(sp.surge_duration > 0.0 and sp.surge_intensity > 0.0
				and sp.surge_intensity <= 1.0,
			"a placed SurgePoint arrives configured, not zeroed  [%.1fs at %.1f]" % [
				sp.surge_duration, sp.surge_intensity])

	# The chase lives in Level_11 and nowhere else. If the LDtk entity is already
	# placed, that is the one under test; if the .ldtk has not caught up yet, one
	# is instanced at the same spot, which is exactly what the importer branch
	# does. Either way nothing outside this room gains a Darkshang.
	var placed := _find_darkshang(world)
	if placed != null:
		shadow = placed
		print("  NOTE  using the DarkshangSpawn entity placed in LDtk")
	else:
		shadow = DARKSHANG_SCENE.instantiate()
		room.get_node("Entities").add_child(shadow)
		shadow.global_position = world.spawn_point_for(room)
		print("  NOTE  no DarkshangSpawn in the .ldtk yet — instanced the prefab "
			+ "into Level_11 at its PlayerStart")
	shadow.auto_start = false  # every section below starts the chase deliberately
	await _frames(4)
	_check(shadow.get_parent() != null and room.is_ancestor_of(shadow),
		"and he is inside Level_11, not in a shared scene")
	_check(_count_darkshang(world) == 1,
		"exactly one shadow exists in the whole Act  [%d]" % _count_darkshang(world))

	# Where he actually comes to rest on Level_11's floor. Measured, not guessed —
	# the same trick conveyor_test uses, so nothing below depends on my reading of
	# a tile row.
	player.global_position = world.spawn_point_for(room)
	player.velocity = Vector2.ZERO
	await _frames(20)
	floor_point = player.global_position
	_check(player.is_on_floor(), "the player stands on Level_11's floor  [%s]" % floor_point)

	# --- he is not a body, and cannot become one ---
	# Asked of the live object rather than written as `is not CharacterBody2D`,
	# which GDScript rejects at parse time as statically impossible — true today,
	# and exactly the check that has to keep being true tomorrow.
	_check(ClassDB.is_parent_class(shadow.get_class(), "Area2D")
			and not shadow.has_method("move_and_slide"),
		"Darkshang is an Area2D with no body move on it  [%s]" % shadow.get_class())
	_check(shadow.collision_mask == 2,
		"he detects the player and nothing else  [mask %d]" % shadow.collision_mask)
	_check(shadow.collision_mask & 1 == 0,
		"the world layer is not in his mask at all, so geometry cannot stop him")

	await _test_following()
	await _test_pass_through()
	await _test_surge()
	await _test_catch_and_respawn()
	await _test_interruption()
	await _test_triggers()
	_test_importer()
	_finish()


# ------------------------------------------------------------------- tape ----

## The ring buffer alone, with the physics recorder switched off so the samples
## are exactly the ones written here.
func _test_buffer() -> void:
	var buf: PlayerPositionBuffer = BUFFER_SCENE.instantiate()
	add_child(buf)
	buf.set_physics_process(false)
	_check(buf.capacity >= int(buf.max_delay * tick),
		"the tape covers its own max_delay with headroom  [%d frames for %.1fs]" % [
			buf.capacity, buf.max_delay])
	_check(buf.samples() == 0, "and starts empty")

	# A straight run right at 1px a frame, so "where was he N frames ago" has an
	# answer anyone can check in their head.
	for i in 200:
		buf.record(Vector2(float(i), 0.0))
	_check(is_equal_approx(buf.get_position_at_delay(0.0).x, 199.0),
		"delay 0 is the live position  [%.1f]" % buf.get_position_at_delay(0.0).x)
	var one_second := buf.get_position_at_delay(1.0).x
	_check(is_equal_approx(one_second, 199.0 - tick),
		"one second back is exactly %d frames back  [%.1f, want %.1f]" % [
			int(tick), one_second, 199.0 - tick])
	# Half a frame between two samples: the echo has to move smoothly, not in
	# 1/60s steps, or a chase at 108px reads as a stutter rather than a stalk.
	var half := buf.get_position_at_delay(0.5 / tick).x
	_check(absf(half - 198.5) < 0.01,
		"and a half-frame delay interpolates between them  [%.2f]" % half)
	_check(is_equal_approx(buf.get_position_at_delay(999.0).x, 0.0),
		"a delay deeper than the tape clamps to the oldest sample, not to zero")

	# Reseeding: the whole point is that Following starts CLEAN. A flat seed
	# reads back as the player's own position at every depth, which is an instant
	# death on the first frame of every life.
	buf.clear_and_seed(Vector2(500.0, 10.0))
	_check(buf.get_position_at_delay(2.0) == Vector2(500.0, 10.0),
		"a flat reseed answers the same everywhere  [%s]" % buf.get_position_at_delay(2.0))
	buf.clear_and_seed(Vector2(500.0, 10.0), Vector2.LEFT, 90.0)
	var seeded := buf.get_position_at_delay(1.2)
	_check(absf(seeded.x - (500.0 - 108.0)) < 1.0,
		"a seeded run-in puts the echo a real gap behind  [%.1f, want %.1f]" % [
			seeded.x, 500.0 - 108.0])

	# The teleport guard. A room slide moves the player hundreds of px in one
	# frame; a tape that replayed that as a path would walk the shadow across the
	# level in a single step.
	var jumps: Array[Vector2] = []
	buf.teleported.connect(func(to: Vector2) -> void: jumps.append(to))
	buf.record(Vector2(504.0, 10.0))   # 4px — a fast dash frame, not a teleport
	_check(jumps.is_empty(), "a dash-speed frame is not mistaken for a teleport")
	buf.record(Vector2(2000.0, 10.0))
	_check(jumps.size() == 1 and jumps[0] == Vector2(2000.0, 10.0),
		"but a room-sized jump is reported  [%d]" % jumps.size())
	_check(buf.latest() == Vector2(504.0, 10.0),
		"and is NOT written to the tape  [%s]" % buf.latest())
	buf.queue_free()
	await _frames(1)


# -------------------------------------------------------------- following ----

## He stands where the player stood, `follow_delay` ago. Asserted against a
## history this test records itself, frame by frame — the buffer is the thing
## under test, so it cannot also be the reference.
func _test_following() -> void:
	await _settle()
	shadow.start_chase()
	shadow.reset_to_checkpoint(player.global_position)
	await _frames(2)

	var delay_frames := int(round(shadow.follow_delay * tick))
	var history: Array[Vector2] = []
	var worst := 0.0
	var samples := 0
	Input.action_press("move_left")
	for i in 120:
		await get_tree().physics_frame
		history.append(player.global_position)
		var k := history.size() - 1 - delay_frames
		if k >= 0:
			worst = maxf(worst, shadow.global_position.distance_to(history[k]))
			samples += 1
	Input.action_release("move_left")

	_check(samples > 30, "the run is long enough to measure the delay  [%d frames]" % samples)
	_check(worst < 1.0,
		"he stands exactly where the player stood %.1fs ago  [worst %.2fpx over %d frames]"
			% [shadow.follow_delay, worst, samples])
	# ...and it is genuinely a DELAY, not "he is glued to the player".
	var gap := shadow.gap()
	_check(gap > 60.0,
		"which at a full run is a real gap, not a shadow on his heels  [%.0fpx]" % gap)
	await _frames(20)


# ------------------------------------------------------------ pass-through ----

## Solid geometry does not slow him, stop him, or bend his line.
##
## Driven with a surge, because a surge is the one time he moves in a straight
## line of his own choosing — Following can only ever put him where the PLAYER
## has been, which is by definition never inside a wall. He is started outside
## the room and lunges in through its left wall.
func _test_pass_through() -> void:
	await _settle()
	var was_warning := shadow.surge_warning
	shadow.surge_warning = 0.0  # no telegraph: the line he travels is what is under test
	# His kill box is switched off for the run, not shrunk. Shrinking it does NOT
	# stop him catching anybody — a 0.01px box sitting exactly on the player still
	# overlaps the player's own 8x12 — and a catch mid-measurement freezes him,
	# which reads as geometry having stopped him. It is turned back on below.
	shadow.monitoring = false
	shadow.state = Darkshang.State.FOLLOWING
	shadow.global_position = floor_point + Vector2(140.0, 0.0)
	await _frames(1)
	shadow.surge(4.0, 0.7)
	await _frames(1)

	var step := shadow.surge_speed / tick
	var fastest := 0.0
	var slowest := INF
	var inside_at := Vector2.INF
	var drift := 0.0
	var last := shadow.global_position
	for i in 50:
		await get_tree().physics_frame
		var moved := shadow.global_position.distance_to(last)
		if shadow.gap() > step * 1.5:
			fastest = maxf(fastest, moved)
			slowest = minf(slowest, moved)
		if shadow.in_geometry and inside_at == Vector2.INF:
			inside_at = shadow.global_position
		drift = maxf(drift, absf(shadow.global_position.y - floor_point.y))
		last = shadow.global_position
	shadow.surge_warning = was_warning

	_check(inside_at != Vector2.INF,
		"crossing the room's wall, the probe reports him inside geometry")
	_check(absf(fastest - step) < 0.05 and absf(slowest - step) < 0.05,
		"and he moves the same distance every frame, wall or no wall  "
			+ "[%.3f..%.3f px/frame, want %.3f]" % [slowest, fastest, step])
	_check(shadow.global_position.x < floor_point.x + 20.0,
		"so he comes out the far side rather than piling up against it  [%.0fpx]"
			% (shadow.global_position.x - floor_point.x))
	_check(drift < 0.5,
		"a straight line stays straight through it  [%.2fpx of vertical drift]" % drift)

	# Parked INSIDE the wall with his detection back on: the probe still says he
	# is in geometry, and his own kill box — the one thing that could ever stop
	# him — has nothing in it. That is the pass-through guarantee stated the way
	# it will fail if somebody ever adds layer 1 to his mask.
	if inside_at != Vector2.INF:
		shadow.state = Darkshang.State.DORMANT
		shadow.global_position = inside_at
		shadow.monitoring = true
		await _frames(3)
		_check(shadow.in_geometry and shadow.get_overlapping_bodies().is_empty(),
			"parked inside a wall he sees nothing at all  [in_geometry %s, %d bodies]" % [
				shadow.in_geometry, shadow.get_overlapping_bodies().size()])
	shadow.monitoring = true


# ------------------------------------------------------------------ surge ----

## A surge shortens the delay, closes the gap, and then decays back.
func _test_surge() -> void:
	await _settle()
	shadow.reset_to_checkpoint(player.global_position)
	await _frames(2)
	_check(is_equal_approx(shadow.read_delay, shadow.follow_delay),
		"following, he reads at the base delay  [%.2f]" % shadow.read_delay)

	var warned: Array[float] = []
	var started: Array[float] = []
	shadow.surge_warned.connect(func(w: float) -> void: warned.append(w))
	shadow.surge_started.connect(func(d: float, _i: float) -> void: started.append(d))

	Input.action_press("move_left")
	await _frames(45)  # up to speed, with a real gap open behind him
	var before := shadow.gap()
	shadow.surge(1.2, 0.7)
	await _frames(1)
	_check(warned.size() == 1 and started.is_empty(),
		"a surge telegraphs first and does not snap  [%d warned, %d started]" % [
			warned.size(), started.size()])
	_check(warned.size() == 1 and is_equal_approx(warned[0], shadow.surge_warning),
		"with the warning time the player is promised  [%.2fs]" % shadow.surge_warning)
	_check(shadow.state == Darkshang.State.FOLLOWING,
		"and he is still merely following while it winds up")

	await _frames(int(shadow.surge_warning * tick) + 2)
	_check(started.size() == 1 and shadow.state == Darkshang.State.SURGING,
		"then he leaves the path  [%d started, state %d]" % [started.size(), shadow.state])
	_check(absf(shadow.read_delay - shadow.follow_delay * 0.3) < 0.01,
		"the read-delay is cut by the surge's intensity  [%.2f, want %.2f]" % [
			shadow.read_delay, shadow.follow_delay * 0.3])

	await _frames(int(1.2 * tick))
	var during := shadow.gap()
	Input.action_release("move_left")
	_check(during < before - 30.0,
		"and the gap closes hard  [%.0fpx -> %.0fpx]" % [before, during])
	_check(shadow.state != Darkshang.State.SURGING, "the lunge ends on its own")

	# The decay. Measured on read_delay rather than on the gap, because measuring
	# the gap needs the player to keep running for another two seconds and this
	# room is 320px wide — the delay IS the mechanic, and the gap is its shadow.
	# Detection is stood down for the wait: he is closing on a parked player by
	# design here, and being eaten stops the clock (a CAUGHT shadow does not tick)
	# and then resets the delay on respawn, which is a measurement of nothing.
	shadow.monitoring = false
	var shrunk := shadow.read_delay
	await _frames(int(1.0 * tick))
	var recovering := shadow.read_delay
	_check(recovering > shrunk + 0.2,
		"afterwards the delay walks back up  [%.2f -> %.2f]" % [shrunk, recovering])
	await _frames(int(2.0 * tick))
	_check(absf(shadow.read_delay - shadow.follow_delay) < 0.02,
		"all the way to the base delay, and stops there  [%.2f]" % shadow.read_delay)
	shadow.reset_to_checkpoint(player.global_position)
	shadow.monitoring = true
	await _frames(2)


# ------------------------------------------------------- caught / respawn ----

## Contact runs the EXISTING death, exactly once, and what comes back is
## survivable.
func _test_catch_and_respawn() -> void:
	await _settle()
	shadow.reset_to_checkpoint(player.global_position)
	Deaths.reset()
	await _frames(2)

	var caught: Array[Player] = []
	shadow.caught_player.connect(func(p: Player) -> void: caught.append(p))

	# Standing still is what kills you: the echo closes the whole gap in
	# follow_delay seconds and there is nowhere for it to stop.
	var locked_during_ingest := false
	var deaths_during_ingest := -1
	for i in 300:
		await get_tree().physics_frame
		if shadow.state == Darkshang.State.CAUGHT:
			locked_during_ingest = player.input_locked
			deaths_during_ingest = Deaths.total
			break
	_check(caught.size() == 1, "standing still, the echo catches him  [%d]" % caught.size())
	_check(locked_during_ingest, "his input is locked for the ingestion")
	_check(deaths_during_ingest == 0,
		"and nothing has died yet — the animation runs FIRST  [%d]" % deaths_during_ingest)

	var caught_at := Time.get_ticks_msec()
	for i in 400:
		await get_tree().physics_frame
		if Deaths.total > 0:
			break
	var held := float(Time.get_ticks_msec() - caught_at) / 1000.0
	_check(Deaths.total == 1,
		"then the existing death fires, exactly once  [Deaths.total %d]" % Deaths.total)
	_check(held >= shadow.ingest_time - 0.15,
		"after the full ingestion, not during it  [%.2fs of %.2fs]" % [held, shadow.ingest_time])

	# Wait out the existing respawn (LdtkWorld holds for player.death_time).
	for i in 400:
		await get_tree().physics_frame
		if player.state != Player.State.DEAD:
			break
	# The gap the reset actually opened, read ON the frame the reset fires.
	#
	# Sampling a window around the respawn instead does not measure this: the
	# player teleports to the checkpoint a frame or two BEFORE the shadow is
	# repositioned, and in that window the gap is whatever distance the teleport
	# happened to leave — 152px here, against the 108 the reset then sets. A
	# maximum over those frames reports the teleport, not the mechanic.
	var reset_gaps: Array[float] = []
	shadow.chase_reset.connect(func(_at: Vector2) -> void:
		reset_gaps.append(shadow.gap()))
	await _frames(6)
	var back_gap: float = reset_gaps[-1] if not reset_gaps.is_empty() else -1.0
	_check(Deaths.total == 1,
		"and the respawn does not count a second one  [%d]" % Deaths.total)
	_check(not player.input_locked, "control comes back with him")

	# --- the respawn is survivable ---
	_check(shadow.state == Darkshang.State.FOLLOWING,
		"he comes back Following, never mid-surge  [state %d]" % shadow.state)
	_check(is_equal_approx(shadow.read_delay, shadow.follow_delay),
		"at the base delay  [%.2f]" % shadow.read_delay)
	_check(absf(back_gap - shadow.respawn_gap) < 4.0,
		"and exactly respawn_gap behind the checkpoint  [%.0fpx, want %.0f]" % [
			back_gap, shadow.respawn_gap])
	var behind := (player.global_position - shadow.global_position).dot(
		shadow.route_direction.normalized())
	_check(behind > 0.0, "BEHIND it, along the route  [%.0fpx]" % behind)

	# Frame one of a new life must not be a death, and neither must playing well.
	var deaths_at_respawn := Deaths.total
	Input.action_press("move_left")
	await _frames(int(1.5 * tick))
	Input.action_release("move_left")
	_check(Deaths.total == deaths_at_respawn,
		"and running from him he survives the next 1.5s  [%d deaths]" % [
			Deaths.total - deaths_at_respawn])
	await _settle()


## An ingestion cut short still pays its death — once, and only once.
func _test_interruption() -> void:
	await _settle()
	Deaths.reset()
	shadow.reset_to_checkpoint(player.global_position)
	await _frames(2)
	for i in 300:
		await get_tree().physics_frame
		if shadow.state == Darkshang.State.CAUGHT:
			break
	_check(shadow.state == Darkshang.State.CAUGHT, "caught again, mid-ingestion")
	shadow.stop_chase()   # a SafeZone, a scene change, a debug reload
	await _frames(2)
	_check(Deaths.total == 1,
		"cutting it short still respawns him  [%d]" % Deaths.total)
	# The animation's own await is still in flight; it must find nothing owed.
	await _frames(int(shadow.ingest_time * tick) + 30)
	_check(Deaths.total == 1,
		"and the interrupted animation does not kill him a second time  [%d]" % Deaths.total)
	for i in 400:
		await get_tree().physics_frame
		if player.state != Player.State.DEAD:
			break
	await _settle()


# --------------------------------------------------------------- triggers ----

func _test_triggers() -> void:
	await _settle()
	shadow.start_chase()
	shadow.reset_to_checkpoint(player.global_position)

	# One point ahead of the player, one behind, so "consumed state resets for
	# what you have to cross again" can be told apart from "everything resets".
	var ahead: SurgePointTrigger = SURGE_SCENE.instantiate()
	var behind: SurgePointTrigger = SURGE_SCENE.instantiate()
	room.get_node("Entities").add_child(ahead)
	room.get_node("Entities").add_child(behind)
	ahead.global_position = floor_point + Vector2(-64.0, -16.0)
	behind.global_position = floor_point + Vector2(32.0, -16.0)
	ahead.size = Vector2(8.0, 96.0)
	behind.size = Vector2(8.0, 96.0)
	await _frames(4)

	# Counted into arrays, never into an int. A GDScript lambda captures a local
	# by VALUE, so `warned += 1` inside one increments a copy and the outer
	# variable stays 0 forever — a test that silently always fails (or, worse,
	# always passes). An Array is captured the same way, but the copy points at
	# the same object, so appending is visible outside.
	var tripped: Array[float] = []
	ahead.tripped.connect(func(d: float, _i: float) -> void: tripped.append(d))
	var warned: Array[float] = []
	shadow.surge_warned.connect(func(w: float) -> void: warned.append(w))

	Input.action_press("move_left")
	await _frames(60)
	Input.action_release("move_left")
	_check(tripped.size() == 1 and ahead.spent,
		"walking into a SurgePoint trips it  [%d]" % tripped.size())
	_check(warned.size() >= 1, "and telegraphs a surge  [%d]" % warned.size())
	# Walk back and forth through it: a set piece that re-fires is a stutter.
	Input.action_press("move_right")
	await _frames(50)
	Input.action_release("move_right")
	Input.action_press("move_left")
	await _frames(50)
	Input.action_release("move_left")
	_check(tripped.size() == 1, "crossing it again does nothing  [%d]" % tripped.size())

	behind.spent = true
	shadow.reset_to_checkpoint(floor_point)
	_check(not ahead.spent,
		"a respawn re-arms the points still ahead of the checkpoint")
	_check(behind.spent,
		"and leaves the ones already behind it spent")

	# --- the threshold that starts it all ---
	# The reveal order is the whole reason this entity is separate from the
	# spawn: he has to be VISIBLE and STILL while the two lines play. A chase
	# that started with the dialogue would spend it closing the gap on a player
	# who cannot move, which is a boss fight that opens by killing you for
	# reading.
	await _settle()
	shadow.stop_chase()
	shadow.visible = false
	var gate: DarkshangTrigger = GATE_SCENE.instantiate()
	room.get_node("Entities").add_child(gate)
	gate.reveal_pause = 0.05
	gate.global_position = floor_point + Vector2(-40.0, -16.0)
	gate.size = Vector2(16.0, 96.0)
	await _frames(4)
	var gate_fired: Array[int] = []
	var gate_begun: Array[int] = []
	gate.triggered.connect(func(_p: Player) -> void: gate_fired.append(1))
	gate.chase_begun.connect(func() -> void: gate_begun.append(1))

	Input.action_press("move_left")
	await _frames(30)
	_check(gate_fired.size() == 1, "crossing the threshold fires it  [%d]" % gate_fired.size())
	_check(shadow.visible, "the shadow is revealed")
	_check(shadow.global_position.is_equal_approx(shadow.spawn_point),
		"at his spawn point, not wherever he was  [%s vs %s]" % [
			shadow.global_position, shadow.spawn_point])
	_check(shadow.state == Darkshang.State.DORMANT and gate_begun.is_empty(),
		"but he is not hunting yet — the beat plays first  [state %d]" % shadow.state)
	_check(player.input_locked, "and the player is held for it")

	# Dismiss the two lines the way a player would.
	for i in 30:
		_press_jump()
		await _frames(4)
		if not gate_begun.is_empty():
			break
	Input.action_release("move_left")
	_check(gate_begun.size() == 1, "the beat ends and the chase begins  [%d]" % gate_begun.size())
	_check(shadow.state == Darkshang.State.FOLLOWING,
		"he is hunting now  [state %d]" % shadow.state)
	_check(not player.input_locked, "and control is back")

	Input.action_press("move_left")
	await _frames(20)
	Input.action_release("move_left")
	_check(gate_fired.size() == 1, "crossing it again does nothing  [%d]" % gate_fired.size())
	gate.queue_free()
	await _frames(2)

	# --- SafeZone ---
	var safe: SafeZoneTrigger = SAFE_SCENE.instantiate()
	room.get_node("Entities").add_child(safe)
	safe.end_dialogue_id = "darkshang_outrun"
	safe.global_position = floor_point + Vector2(-80.0, -16.0)
	safe.size = Vector2(16.0, 96.0)
	await _frames(4)
	var reached: Array[String] = []
	safe.reached.connect(func(id: String) -> void: reached.append(id))
	await _settle()
	shadow.reset_to_checkpoint(player.global_position)
	# Connected AFTER _settle(), not before. _settle() halts the chase itself as
	# housekeeping, so a counter armed any earlier records that tidy-up as the
	# first "chase ended" and every reading here is one too high.
	#
	# An Array, not an int: GDScript lambdas capture locals BY VALUE, so an
	# `ended += 1` inside one increments a copy and the outer variable stays 0
	# forever — the signal fires, the assertion fails, and nothing about the
	# product is wrong. `reached` above is an Array for the same reason.
	var ended: Array[int] = []
	shadow.chase_ended.connect(func() -> void: ended.append(1))
	Input.action_press("move_left")
	await _frames(70)
	Input.action_release("move_left")
	_check(reached.size() == 1 and reached[0] == "darkshang_outrun",
		"reaching the SafeZone announces the end beat  [%s]" % str(reached))
	_check(ended.size() == 1 and shadow.state == Darkshang.State.DORMANT,
		"and halts the chase  [%d ended, state %d]" % [ended.size(), shadow.state])
	var parked := shadow.global_position
	await _frames(40)
	_check(shadow.global_position == parked,
		"a halted shadow does not move  [%s]" % (shadow.global_position - parked))

	ahead.queue_free()
	behind.queue_free()
	safe.queue_free()
	await _frames(2)


# --------------------------------------------------------------- importer ----

## The LDtk side: every field falls back to the prefab's own default, because an
## unset LDtk field arrives as `null` and a null that becomes 0.0 is a surge that
## lasts no time at all — worse than the default, because it looks configured.
func _test_importer() -> void:
	var importer = load("res://scripts/ldtk_entities_post_import.gd").new()

	var spawn: Darkshang = importer._build_darkshang({
		"position": Vector2(48.0, 96.0), "size": Vector2i(16, 16), "fields": {}})
	_check(spawn.position == Vector2(48.0, 96.0),
		"DarkshangSpawn places the shadow  [%s]" % spawn.position)

	var point: SurgePointTrigger = importer._build_surge_point({
		"position": Vector2(32.0, 64.0), "size": Vector2i(16, 96),
		"fields": {"surge_duration": 2.0, "surge_intensity": 0.4}})
	_check(point.position == Vector2(32.0, 64.0) and point.size == Vector2(16.0, 96.0),
		"SurgePoint takes its place and the box you dragged  [%s %s]" % [
			point.position, point.size])
	_check(is_equal_approx(point.surge_duration, 2.0)
			and is_equal_approx(point.surge_intensity, 0.4),
		"and both fields  [%.1fs at %.1f]" % [point.surge_duration, point.surge_intensity])

	var unset: SurgePointTrigger = importer._build_surge_point({
		"position": Vector2.ZERO, "size": Vector2i(16, 48),
		"fields": {"surge_duration": null, "surge_intensity": null}})
	_check(is_equal_approx(unset.surge_duration, 1.2)
			and is_equal_approx(unset.surge_intensity, 0.7),
		"an untyped field falls back to the prefab, not to zero  [%.1fs at %.1f]" % [
			unset.surge_duration, unset.surge_intensity])
	var mad: SurgePointTrigger = importer._build_surge_point({
		"position": Vector2.ZERO, "size": Vector2i(16, 48),
		"fields": {"surge_duration": -3.0, "surge_intensity": 9.0}})
	_check(is_equal_approx(mad.surge_duration, 0.0) and is_equal_approx(mad.surge_intensity, 1.0),
		"and impossible numbers are clamped rather than trusted  [%.1fs at %.1f]" % [
			mad.surge_duration, mad.surge_intensity])

	var zone: SafeZoneTrigger = importer._build_safe_zone({
		"position": Vector2(8.0, 8.0), "size": Vector2i(48, 64),
		"fields": {"end_dialogue_id": "chase_over"}})
	_check(zone.position == Vector2(8.0, 8.0) and zone.size == Vector2(48.0, 64.0)
			and zone.end_dialogue_id == "chase_over",
		"SafeZone carries the beat it should play  [%s]" % zone.end_dialogue_id)
	var quiet: SafeZoneTrigger = importer._build_safe_zone({
		"position": Vector2.ZERO, "size": Vector2i(32, 48),
		"fields": {"end_dialogue_id": null}})
	_check(quiet.end_dialogue_id == "",
		"an empty one is legitimate — the signal still fires  [%s]" % quiet.end_dialogue_id)

	# Never entered a tree, so nothing else will free them; left alone they are
	# the whole of the "RIDs leaked at exit" report.
	for orphan in [spawn, point, unset, mad, zone, quiet]:
		orphan.free()


# ------------------------------------------------------------------ helpers ---

## Player back on Level_11's floor, standing still, with the shadow parked out of
## reach so the next section starts from a known board.
func _settle() -> void:
	_release_all()
	# Spend the room's OWN set pieces before every section. Level_11 holds a real
	# DarkshangTrigger and two real SurgePoints, and the player start is a few
	# dozen pixels from the first of them — so a section that runs him along the
	# route trips one mid-measurement. That is what a 108px steady-state gap
	# reading back as 32px was: a surge nobody asked for, closing it. Each of
	# those things is tested in its own section, with its own instance, where the
	# firing is the point rather than the noise.
	for node in _in_room("darkshang_trigger"):
		(node as DarkshangTrigger).spent = true
	for node in _in_room("surge_point"):
		(node as SurgePointTrigger).spent = true
	if shadow != null:
		shadow.stop_chase()
		shadow.global_position = floor_point + Vector2(200.0, 0.0)
	if player.state == Player.State.DEAD:
		for i in 200:
			await get_tree().physics_frame
			if player.state != Player.State.DEAD:
				break
	player.global_position = floor_point
	player.velocity = Vector2.ZERO
	player.input_locked = false
	await _frames(10)
	if shadow != null:
		shadow.start_chase()


## Everything in `group` that belongs to Level_11. Scoped to the room on purpose:
## with the whole Act loaded at once, an unscoped get_nodes_in_group() reaches
## rooms the player has never visited (STYLE_GUIDE §9).
func _in_room(group: String) -> Array[Node]:
	var found: Array[Node] = []
	for n in get_tree().get_nodes_in_group(group):
		if n is Node2D and room.is_ancestor_of(n):
			found.append(n)
	return found


func _room_named(what: String) -> Node2D:
	for r in world.rooms:
		if r.name == what:
			return r
	return null


func _find_darkshang(node: Node) -> Darkshang:
	if node is Darkshang:
		return node
	for child in node.get_children():
		var found := _find_darkshang(child)
		if found != null:
			return found
	return null


func _count_darkshang(node: Node) -> int:
	var n := 1 if node is Darkshang else 0
	for child in node.get_children():
		n += _count_darkshang(child)
	return n


func _release_all() -> void:
	for action in ["jump", "dash", "move_right", "move_left"]:
		Input.action_release(action)


func _check(ok: bool, msg: String) -> void:
	print("  %s  %s" % ["PASS" if ok else "FAIL", msg])
	if not ok:
		failures.append(msg)


func _frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func _finish() -> void:
	if failures.is_empty():
		print("CHASE TEST: ALL PASS")
	else:
		print("CHASE TEST: %d FAILURE(S)" % failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)


## A real jump press. DialogueBox listens in _unhandled_input, which
## Input.action_press() does not feed — the same note as intro_test.gd.
func _press_jump() -> void:
	var ev := InputEventAction.new()
	ev.action = "jump"
	ev.pressed = true
	Input.parse_input_event(ev)
