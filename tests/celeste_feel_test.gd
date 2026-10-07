extends Node2D
## Real physics/input regression for phase timing and stopped-belt launch grace.
var failures := 0
var player: Player
var belt: ConveyorBelt

func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)

func frames(count: int) -> void:
	for i in count:
		await get_tree().physics_frame
		await get_tree().process_frame

func settle() -> void:
	Input.action_release("jump")
	Input.action_release("move_right")
	belt.speed = 0.0
	player.respawn(Vector2(200, 180))
	await frames(25)
	check(player.is_on_floor(), "Test player must settle on real floor")

func _ready() -> void:
	SaveGame.slot = -1
	var floor_body := StaticBody2D.new()
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(800, 16)
	shape.shape = rect
	floor_body.add_child(shape)
	floor_body.position = Vector2(400, 208)
	add_child(floor_body)
	belt = preload("res://scenes/props/zones/ConveyorBelt.tscn").instantiate()
	belt.solid = false
	belt.size = Vector2(180, 8)
	belt.position = Vector2(200, 204)
	belt.speed = 0.0
	add_child(belt)
	player = preload("res://scenes/characters/hooshang/Hooshang.tscn").instantiate()
	player.position = Vector2(200, 180)
	add_child(player)
	player.has_dash = true
	await settle()
	var phases := {}
	Input.action_press("jump")
	for i in 90:
		await frames(1)
		phases[str(player.visual.animation)] = true
		if i == 11:
			Input.action_release("jump")
	for clip in ["takeoff", "rise", "apex", "fall", "land", "recover", "idle"]:
		check(phases.has(clip), "Jump/landing must display phase " + clip + " (saw " + str(phases.keys()) + ")")
	# Visual landing recovery cannot lock the next action.
	player.landing_anim_timer = 0.12
	Input.action_press("jump")
	await frames(1)
	check(player.velocity.y < 0.0, "Jump must interrupt landing without input delay")
	Input.action_release("jump")
	await settle()
	player.landing_anim_timer = 0.12
	Input.action_press("move_right")
	await frames(1)
	check(player.velocity.x > 0.0 and player.visual.animation == &"run", "Running interrupts planted recovery immediately")
	Input.action_release("move_right")
	# Moving, recently stopped, and expired surfaces must produce different launches.
	for delay in [0, 3, 12]:
		await settle()
		belt.speed = 60.0
		await frames(5)
		check(belt.carrying(player), "Belt must really carry the player before stopping")
		belt.speed = 0.0
		await frames(delay)
		Input.action_press("jump")
		await frames(1)
		var boosted := player.velocity.x > 30.0
		check(boosted == (delay < 6), "Stopped belt grace at %d frames, vx=%.2f" % [delay, player.velocity.x])
		Input.action_release("jump")
	# A dash from a charged surface remains the controller's fixed-speed dash.
	await settle()
	belt.speed = 60.0
	await frames(5)
	player._try_dash(Vector2.RIGHT)
	await frames(6)
	check(is_equal_approx(player.velocity.x, player.dash_speed), "Platform momentum must not amplify a dash")
	await settle()
	check(is_zero_approx(player.velocity.x), "Respawn clears previous handed momentum")
	# The moving carpet uses measured displacement, so stopping against geometry
	# cannot keep handing out its configured speed forever.
	var carpet := preload("res://scenes/props/zones/MagicCarpet.tscn").instantiate()
	carpet.position = Vector2(450, 140)
	carpet.size = Vector2(100, 8)
	carpet.speed = 0.0
	add_child(carpet)
	for delay in [3, 12]:
		carpet.reset()
		carpet.speed = 0.0
		player.respawn(Vector2(450, 120))
		await frames(30)
		check(carpet.carrying(player), "Test player boards the actual moving carpet")
		carpet.speed = 40.0
		await frames(5)
		carpet.speed = 0.0
		await frames(delay)
		Input.action_press("jump")
		await frames(1)
		check((player.velocity.x > 20.0) == (delay < 6), "Stopped carpet grace at %d frames, vx=%.2f" % [delay, player.velocity.x])
		Input.action_release("jump")
	print("CELESTE FEEL: %d failures" % failures)
	get_tree().quit(1 if failures else 0)
