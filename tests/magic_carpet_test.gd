extends Node
## MagicCarpet: a rideable moving platform. RIDE carries right and hands off
## the instant a rider is airborne (same contract as ConveyorBelt); a rider
## can steer it up/down within steer_range. BOB/SWEEP/BOUNCE each move on
## their own declared axis and no other, measured over time — the same
## "measured-travel control" idea dark_thought_test.tscn uses for
## DarkThought.Motion.
##
## Run:  godot --headless res://tests/magic_carpet_test.tscn

const CARPET_SCENE := preload("res://scenes/props/zones/MagicCarpet.tscn")
const PLAYER := preload("res://scenes/characters/hooshang/Hooshang.tscn")

var failures: Array[String] = []
var world: Node2D
var player: Player
var carpet: MagicCarpet


func _ready() -> void:
	world = Node2D.new()
	add_child(world)
	player = PLAYER.instantiate()
	world.add_child(player)
	await _run()


func _run() -> void:
	carpet = CARPET_SCENE.instantiate()
	carpet.position = Vector2(100, 100)
	carpet.size = Vector2(48, 8)
	carpet.pattern = MagicCarpet.CarpetPattern.RIDE
	carpet.speed = 40.0
	carpet.steer_range = 20.0
	carpet.steer_speed = 60.0
	world.add_child(carpet)
	await _frames(2)

	# --- riding: carries right, and it moves the surface, not his velocity ---
	player.input_locked = true
	_stand_on_carpet()
	await _frames(4)
	_check(carpet.riders.has(player), "standing on it he is inside it")
	_check(carpet.carrying(player), "and it is carrying him")

	var start_x: float = player.global_position.x
	await _frames(30)
	var moved := player.global_position.x - start_x
	var want := carpet.speed * 30.0 / float(Engine.physics_ticks_per_second)
	_check(absf(moved - want) <= 2.0,
		"RIDE carries him right at its speed  [%+.1fpx, want %+.1f]" % [moved, want])
	_check(absf(player.velocity.x) < 1.0,
		"...and never writes his velocity to do it  [%.1f px/s]" % player.velocity.x)

	# --- steering up/down, within steer_range and no further ---
	var carpet_y0 := carpet.position.y
	Input.action_press("move_up")
	await _frames(120)  # far longer than steer_range / steer_speed
	Input.action_release("move_up")
	var risen := carpet_y0 - carpet.position.y
	_check(risen > 5.0, "up input steers it upward  [%.1fpx]" % risen)
	_check(risen <= carpet.steer_range + 1.0,
		"...and no further than steer_range  [%.1fpx, range %.1f]"
			% [risen, carpet.steer_range])

	# --- steering must never shake him loose or push him sideways ---
	# Regression: reversing the steer direction — or simply switching from
	# holding UP to holding DOWN — used to eject the rider mid-ride with no
	# jump, no dash and nothing else in the room to blame. See
	# MagicCarpet._carry_body's doc comment for the actual mechanism: the
	# carpet's own ZoneFloor moves (on the CPU side) a beat before the
	# physics server's own copy of its transform catches up, so the rider's
	# manual catch-up move collided with the very floor it was following.
	# Holding UP alone (the block above) never showed it — catching up away
	# from a stale, lower floor collides with nothing — which is why this
	# drives DOWN, and a rapid up/down flip, too.
	var ever_not_carried := false
	var ever_airborne := false
	var max_ride_vel_x := 0.0

	Input.action_press("move_down")
	for i in 60:
		await _frames(1)
		ever_not_carried = ever_not_carried or not carpet.carrying(player)
		ever_airborne = ever_airborne or not player.is_on_floor()
		max_ride_vel_x = maxf(max_ride_vel_x, absf(player.velocity.x))
	Input.action_release("move_down")

	for i in 60:  # rapid direction flips: the worst case for the stale-floor race
		if i % 2 == 0:
			Input.action_press("move_up")
			Input.action_release("move_down")
		else:
			Input.action_press("move_down")
			Input.action_release("move_up")
		await _frames(1)
		ever_not_carried = ever_not_carried or not carpet.carrying(player)
		ever_airborne = ever_airborne or not player.is_on_floor()
		max_ride_vel_x = maxf(max_ride_vel_x, absf(player.velocity.x))
	Input.action_release("move_up")
	Input.action_release("move_down")

	_check(not ever_airborne,
		"steering alone (up, down, or flipping fast) never lifts him off the floor")
	_check(not ever_not_carried,
		"...and never drops him out of carrying(), with nothing else in the room to blame")
	_check(max_ride_vel_x < 1.0,
		"...and never writes a surprise kick to his velocity.x while riding  [%.1f px/s]"
			% max_ride_vel_x)

	# --- airborne, it does not carry him ---
	# input_locked comes off for this: a locked player never processes the
	# jump action at all (see player.gd's jump handling), so testing "jumping
	# off it" while still locked would just be testing that nothing happens.
	player.input_locked = false
	_stand_on_carpet()
	await _frames(4)
	Input.action_press("jump")
	await _frames(4)
	Input.action_release("jump")
	var airborne := not player.is_on_floor()
	var carried_in_air := carpet.carrying(player)
	_check(airborne, "jumping off it he is airborne")
	_check(not carried_in_air, "...and it is no longer carrying him")
	await _frames(20)
	player.input_locked = true

	# --- a dead player is not carried, even standing on the box ---
	_stand_on_carpet()
	await _frames(2)
	player.die()
	await _frames(2)
	_check(not carpet.carrying(player), "a dead player is not carried")
	player.respawn(Vector2(0, 0))
	await _frames(4)
	# A death triggers Juice's hitstop (Engine.time_scale dropped to 0.05 for a
	# few REAL seconds, restored by a real-time timer — see juice.gd). This
	# test measures motion by physics-frame COUNT, not wall-clock time, so a
	# still-scaled clock here would silently starve every _clock-driven
	# measurement below it. Same fix pause_test.gd uses to get a deterministic
	# clock back.
	Engine.time_scale = 1.0

	# --- reset puts it back at its placed point, cycle and steer cleared ---
	carpet.position += Vector2(30, -10)
	MagicCarpet.reset_all(get_tree())
	_check(carpet.position == carpet._origin,
		"reset_all puts a RIDE carpet back at its placed point  [%s]" % carpet.position)

	# --- BOB: vertical only, bounded, no horizontal drift by default ---
	var bob: MagicCarpet = CARPET_SCENE.instantiate()
	bob.pattern = MagicCarpet.CarpetPattern.BOB
	bob.position = Vector2(300, 300)
	bob.amplitude = 12.0
	bob.cycle_speed = 2.0  # fast, so a short test window still sees a full swing
	bob.speed = 0.0
	world.add_child(bob)
	await _frames(2)
	var bob_x0 := bob.position.x
	var min_y := bob.position.y
	var max_y := bob.position.y
	for i in 60:
		await _frames(1)
		min_y = minf(min_y, bob.position.y)
		max_y = maxf(max_y, bob.position.y)
	_check(absf(bob.position.x - bob_x0) < 0.5,
		"BOB does not drift horizontally  [%.2fpx]" % (bob.position.x - bob_x0))
	_check(max_y - min_y >= bob.amplitude,
		"...and swings vertically by (about) its amplitude  [%.1fpx, want >= %.1f]"
			% [max_y - min_y, bob.amplitude])

	# --- SWEEP: horizontal only, bounded ---
	var sweep: MagicCarpet = CARPET_SCENE.instantiate()
	sweep.pattern = MagicCarpet.CarpetPattern.SWEEP
	sweep.position = Vector2(400, 300)
	sweep.amplitude = 14.0
	sweep.cycle_speed = 2.0
	world.add_child(sweep)
	await _frames(2)
	var sweep_y0 := sweep.position.y
	var min_x := sweep.position.x
	var max_x := sweep.position.x
	for i in 60:
		await _frames(1)
		min_x = minf(min_x, sweep.position.x)
		max_x = maxf(max_x, sweep.position.x)
	_check(absf(sweep.position.y - sweep_y0) < 0.5,
		"SWEEP does not drift vertically  [%.2fpx]" % (sweep.position.y - sweep_y0))
	_check(max_x - min_x >= sweep.amplitude,
		"...and swings horizontally by (about) its amplitude  [%.1fpx, want >= %.1f]"
			% [max_x - min_x, sweep.amplitude])

	# --- BOUNCE: drifts right while pulsing vertically, never above origin ---
	var bounce: MagicCarpet = CARPET_SCENE.instantiate()
	bounce.pattern = MagicCarpet.CarpetPattern.BOUNCE
	bounce.position = Vector2(500, 300)
	bounce.amplitude = 10.0
	bounce.cycle_speed = 2.0
	bounce.speed = 20.0
	world.add_child(bounce)
	# Baseline off _origin, captured before anything has moved — NOT a position
	# sampled a few frames in, which is already partway into the first pulse
	# and would understate "highest" by exactly however far it had already
	# risen by the time the baseline was taken.
	var bounce_x0 := bounce._origin.x
	var bounce_y0 := bounce._origin.y
	var highest := 0.0  # how far above origin it ever gets
	for i in 90:
		await _frames(1)
		highest = maxf(highest, bounce_y0 - bounce.position.y)
	_check(bounce.position.x > bounce_x0 + 1.0,
		"BOUNCE drifts right  [%+.1fpx]" % (bounce.position.x - bounce_x0))
	_check(highest >= bounce.amplitude - 1.0,
		"...and pulses up by (about) its amplitude  [%.1fpx, want >= %.1f]"
			% [highest, bounce.amplitude])
	_check(highest <= bounce.amplitude + 1.0,
		"...and never past it  [%.1fpx, want <= %.1f]" % [highest, bounce.amplitude])

	# --- the LDtk side ---
	var importer = load("res://scripts/ldtk_entities_post_import.gd").new()
	var built: Area2D = importer._build_magic_carpet({
		"position": Vector2(8.0, 4.0), "size": Vector2(64.0, 8.0),
		"fields": {"CarpetPattern": "CarpetPattern.Bob", "Speed": 25.0,
			"Amplitude": 15.0, "SteerRange": 30.0},
	})
	_check(built.position == Vector2(8.0, 4.0) and built.size == Vector2(64.0, 8.0),
		"the importer places and sizes it from LDtk  [%s %s]" % [built.position, built.size])
	_check(built.pattern == MagicCarpet.CarpetPattern.BOB,
		"...reads a qualified CarpetPattern enum value correctly")
	_check(is_equal_approx(built.speed, 25.0) and is_equal_approx(built.amplitude, 15.0)
			and is_equal_approx(built.steer_range, 30.0),
		"...and its numeric fields  [speed %.0f, amp %.0f, steer %.0f]"
			% [built.speed, built.amplitude, built.steer_range])
	built.free()
	var bare: Area2D = importer._build_magic_carpet(
		{"position": Vector2.ZERO, "size": Vector2(32.0, 8.0), "fields": {}})
	_check(bare.pattern == MagicCarpet.CarpetPattern.RIDE,
		"an unset CarpetPattern falls back to RIDE, not a still carpet")
	bare.free()

	if failures.is_empty():
		print("MAGIC CARPET TEST: ALL PASS")
	else:
		print("MAGIC CARPET TEST: %d FAILURE(S)" % failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)


func _stand_on_carpet() -> void:
	_release_all()
	player.velocity = Vector2.ZERO
	player.global_position = carpet.global_position - Vector2(0, carpet.size.y * 0.5 + 6.0)


func _release_all() -> void:
	for action in ["jump", "dash", "move_left", "move_right", "move_up", "move_down"]:
		Input.action_release(action)


func _frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func _check(cond: bool, name: String) -> void:
	print(("  PASS  " if cond else "  FAIL  ") + name)
	if not cond:
		failures.append(name)
