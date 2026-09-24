extends Node
## Ride-only carpets retain four colors, steer beyond their old range, and
## stop at room boundaries and solid geometry with clearance for the rider.

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

	# --- steering continues beyond the old 20px amplitude ---
	var carpet_y0 := carpet.position.y
	Input.action_press("move_up")
	await _frames(120)
	Input.action_release("move_up")
	var risen := carpet_y0 - carpet.position.y
	_check(risen > 5.0, "up input steers it upward  [%.1fpx]" % risen)
	_check(risen > 100.0,
		"steering is not limited by distance from the placed point [%.1fpx]" % risen)

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
	# still-scaled clock here would silently slow the later movement
	# measurement below it. Same fix pause_test.gd uses to get a deterministic
	# clock back.
	Engine.time_scale = 1.0

	# --- reset puts it back at its placed point, cycle and steer cleared ---
	carpet.position += Vector2(30, -10)
	MagicCarpet.reset_all(get_tree())
	_check(carpet.position == carpet._origin,
		"reset_all puts a RIDE carpet back at its placed point  [%s]" % carpet.position)

	# A same-sensor retry never crosses the Area boundary again. Reacquire
	# that rider through overlap polling rather than waiting for a new signal.
	_stand_on_carpet()
	await _frames(5)
	carpet.reset()
	player.respawn(carpet.global_position-Vector2(0,10))
	await _frames(8)
	_check(carpet.activated and carpet.carrying(player),
		"reset while still inside the sensor permits boarding again")
	player.respawn(Vector2.ZERO)

	await _test_limits()

	# --- the LDtk side ---
	var importer = load("res://scripts/ldtk_entities_post_import.gd").new()
	var built: Area2D = importer._build_magic_carpet({
		"position": Vector2(8.0, 4.0), "size": Vector2(64.0, 8.0),
		"fields": {"CarpetPattern": "CarpetPattern.Bob", "Speed": 25.0,
			"Amplitude": 15.0, "SteerRange": 30.0},
	})
	_check(built.position == Vector2(8.0, 4.0) and built.size == Vector2(64.0, 8.0),
		"the importer places and sizes it from LDtk  [%s %s]" % [built.position, built.size])
	_check(built.pattern == MagicCarpet.CarpetPattern.RIDE and built.carpet_color == MagicCarpet.CarpetColor.TEAL,
		"legacy Bob imports as Ride with its teal artwork")
	_check(is_equal_approx(built.speed, 25.0), "imports flight speed")
	built.free()
	var bare: Area2D = importer._build_magic_carpet(
		{"position": Vector2.ZERO, "size": Vector2(32.0, 8.0), "fields": {}})
	_check(bare.pattern == MagicCarpet.CarpetPattern.RIDE,
		"an unset CarpetPattern falls back to RIDE, not a still carpet")
	bare.free()

	for color in ["Crimson", "Teal", "Violet", "Amber"]:
		var rug = importer._build_magic_carpet({"position": Vector2.ZERO,
			"size": Vector2(32, 8), "fields": {"CarpetColor": "CarpetColor." + color}})
		world.add_child(rug)
		_check(rug._visual.get_child(0).texture == MagicCarpet.TILES[["Crimson", "Teal", "Violet", "Amber"].find(color)],
			"qualified color selects its own artwork: " + color)
		_check(rug.pattern == MagicCarpet.CarpetPattern.RIDE, "color keeps Ride behavior")
		rug.free()

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


func _test_limits() -> void:
	carpet.reset()
	carpet.set_physics_process(false)
	var room := LDTKLevel.new()
	room.size = Vector2i(320, 240)
	room.position = Vector2(1000, 500)
	world.add_child(room)
	var rug: MagicCarpet = CARPET_SCENE.instantiate()
	rug.position = Vector2(160, 140)
	rug.size = Vector2(48, 8)
	rug.speed = 0
	rug.steer_speed = 120
	room.add_child(rug)
	player.respawn(rug.global_position - Vector2(0, 10))
	player.input_locked = true
	await _frames(8)
	Input.action_press("move_up")
	await _frames(90)
	Input.action_release("move_up")
	_check(player.hitbox_rect().position.y >= room.global_position.y - 0.1,
		"room top contains the rider's entire body")
	_check(player.hitbox_rect().position.y < room.global_position.y + 1,
		"steering reaches the room top beyond the old range")
	_check(rug.carrying(player), "top edge does not eject the rider")
	Input.action_press("move_down")
	await _frames(140)
	Input.action_release("move_down")
	_check(absf(rug.position.y + 4 - 240) < 0.1, "room bottom contains the whole carpet")
	rug.speed = 120
	await _frames(100)
	_check(absf(rug.position.x + 24 - 320) < 0.1, "room right edge stops flight")
	rug.speed = -120
	await _frames(170)
	_check(absf(rug.position.x - 24) < 0.1, "room left edge stops flight")
	# A wall blocks the carpet even where the rider's narrower body fits.
	rug.reset()
	rug.speed = 120
	var wall := _solid(room, Rect2(220, 0, 8, 240))
	player.respawn(rug.global_position - Vector2(0, 10))
	await _frames(80)
	_check(rug.position.x + 24 <= 220 and rug.position.x > 190,
		"solid wall stops the carpet's leading edge")
	_check(rug.carrying(player), "blocked forward flight keeps the rider aboard")
	wall.free()
	rug.speed = 0
	var ceiling := _solid(room, Rect2(0, 80, 320, 8))
	await _frames(2)
	Input.action_press("move_up")
	await _frames(70)
	Input.action_release("move_up")
	_check(player.hitbox_rect().position.y >= room.global_position.y + 88,
		"low ceiling stops flight before the rider hits it")
	_check(player.hitbox_rect().position.y < room.global_position.y + 89,
		"low ceiling is actually reached [%s, rug %s]" % [player.hitbox_rect(), rug.position])
	_check(rug.carrying(player), "ceiling does not separate carpet and rider")
	ceiling.free()
	await _frames(2)
	Input.action_press("move_up")
	await _frames(60)
	Input.action_release("move_up")
	_check(player.hitbox_rect().position.y < room.global_position.y + 1,
		"removing obstacle permits continued travel to room boundary")
	player.respawn(Vector2.ZERO)
	room.free()


func _solid(parent: Node, box: Rect2) -> StaticBody2D:
	var solid := StaticBody2D.new()
	var shape := CollisionShape2D.new()
	var rectangle := RectangleShape2D.new()
	rectangle.size = box.size
	shape.shape = rectangle
	solid.position = box.get_center()
	solid.add_child(shape)
	parent.add_child(solid)
	return solid
