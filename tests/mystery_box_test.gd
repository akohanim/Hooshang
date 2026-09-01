extends Node
## The Mario-style mystery box: solid, bumps only on a genuine upward hit,
## gives up exactly one mushroom per life, and comes back on reset. The
## mushroom itself: rises out of the block, then walks right with gravity,
## bounces off a wall and falls off a ledge. And the power it grants: 30s of
## thought-hazard immunity that a dark/light cloud passes through, a grey one
## dissolves to, and the paintable thought tiles stop killing for.
##
## Run:  godot --headless res://tests/mystery_box_test.tscn

const MYSTERY_BOX := preload("res://scenes/props/MysteryBox.tscn")
const PLAYER := preload("res://scenes/characters/hooshang/Hooshang.tscn")
const DARK_THOUGHT := preload("res://scenes/props/hazards/DarkThought.tscn")
const LIGHT_THOUGHT := preload("res://scenes/props/hazards/LightThought.tscn")
const GREY_THOUGHT := preload("res://scenes/props/hazards/GreyThought.tscn")

var failures: Array[String] = []
var world: Node2D
var player: Player


func _ready() -> void:
	world = Node2D.new()
	add_child(world)
	player = PLAYER.instantiate()
	world.add_child(player)
	await _run()


func _run() -> void:
	# --- the block itself: solid, and only an UPWARD hit bumps it ----------
	var box: MysteryBox = MYSTERY_BOX.instantiate()
	box.position = Vector2(100, 100)
	world.add_child(box)
	await _frames(2)
	_check(box.get_collision_layer_value(1), "the box is solid  [layer 1]")
	_check(box.is_in_group("mystery_box"), "...and findable for the reset sweep")

	# Resting/falling against the underside must NOT bump it.
	player.respawn(Vector2(100, 116))
	player.input_locked = true
	player.velocity = Vector2(0, 40)  # falling, i.e. velocity.y >= 0
	await _frames(10)
	_check(not box._spent, "drifting up into the underside slowly does not bump it")

	# A genuine upward hit (jump/dash into it) does.
	player.respawn(Vector2(100, 130))
	player.velocity = Vector2(0, -240)
	var mushroom: Mushroom = null
	for i in 60:
		await _frames(1)
		if box._spent:
			break
	player.input_locked = false
	_check(box._spent, "jumping into the underside bumps the block")
	# The spawn itself is deferred (see mystery_box.gd's _spawn_mushroom note)
	# — `_spent` flips synchronously, but the mushroom is not yet a child of
	# the room on the very same frame.
	await _frames(2)
	for child in world.get_children():
		if child is Mushroom:
			mushroom = child
	_check(mushroom != null, "...and a mushroom is spawned in the room")

	# One per life: a second upward hit does nothing further.
	var mushroom_count := 0
	for child in world.get_children():
		if child is Mushroom:
			mushroom_count += 1
	player.respawn(Vector2(100, 130))
	player.input_locked = true
	player.velocity = Vector2(0, -240)
	await _frames(10)
	player.input_locked = false
	var mushroom_count_after := 0
	for child in world.get_children():
		if child is Mushroom:
			mushroom_count_after += 1
	_check(mushroom_count_after == mushroom_count,
		"...and a second hit while spent gives up nothing more  [%d -> %d]"
			% [mushroom_count, mushroom_count_after])

	# --- reset puts the block back ------------------------------------------
	MysteryBox.reset_all(get_tree())
	_check(not box._spent, "reset_all un-spends the block")

	# --- the mushroom: emerge, then walk right with gravity -----------------
	if mushroom != null:
		var start_y := mushroom.global_position.y
		await _frames(1)
		_check(mushroom.global_position.y < start_y,
			"emerging: it rises  [%.1f -> %.1f]" % [start_y, mushroom.global_position.y])
		# Give it a generous budget to finish rising and settle onto the block.
		var settled := false
		for i in 60:
			await _frames(1)
			if mushroom._phase == 1:  # _Phase.WALKING
				settled = true
				break
		_check(settled, "...and finishes emerging within a second")
		_check(mushroom.walk_dir > 0.0, "...starting off to the RIGHT")
		# One more frame so a real move_and_slide() has actually run in the
		# WALKING phase — the frame _phase flips returns before reaching it.
		await _frames(1)
		_check(mushroom.is_on_floor(),
			"...standing on top of the block once it clears it")
		var stand_y := mushroom.global_position.y
		var x0 := mushroom.global_position.x
		# Long enough to cross the 16px-wide block and walk off its far edge.
		await _frames(60)
		_check(mushroom.global_position.x > x0,
			"...and is actually walking that way  [%.1f -> %.1f]"
				% [x0, mushroom.global_position.x])
		_check(mushroom.global_position.y > stand_y + 5.0,
			"...then walks off the block's own edge and gravity takes it  [%.1f -> %.1f]"
				% [stand_y, mushroom.global_position.y])

	# --- bounces off a wall, falls off a ledge -------------------------------
	# A wide floor with a wall rising from it well short of the far edge, so
	# the mushroom is solidly grounded when it meets the wall rather than
	# falling off a ledge first.
	var floor1 := _solid(Vector2(300, 200), Vector2(100, 8))   # spans x 250..350
	var wall := _solid(Vector2(346, 180), Vector2(8, 40))       # spans x 342..350
	var runner: Mushroom = preload("res://scenes/props/Mushroom.tscn").instantiate()
	world.add_child(runner)
	# Starts a few px above the floor so it settles onto it under gravity
	# before it ever reaches the wall, the same way the box's own mushroom
	# lands after emerging.
	runner.begin_emerge(Vector2(300, 186), 186.0)
	await _frames(15)  # time to fall the few px onto the floor and settle
	_check(runner.is_on_floor(), "it lands on the floor before reaching the wall")
	var before_dir := runner.walk_dir
	var hit_wall := false
	for i in 150:
		await _frames(1)
		if runner.walk_dir != before_dir:
			hit_wall = true
			break
	_check(hit_wall, "...and reverses direction on hitting the wall  [was %.0f]" % before_dir)

	var floor2 := _solid(Vector2(500, 200), Vector2(60, 8))    # spans x 470..530
	var runner2: Mushroom = preload("res://scenes/props/Mushroom.tscn").instantiate()
	world.add_child(runner2)
	runner2.begin_emerge(Vector2(480, 186), 186.0)
	await _frames(15)
	_check(runner2.is_on_floor(), "the ledge runner also lands and walks first")
	var y_on_floor := runner2.global_position.y
	await _frames(150)  # enough to cross the ~50px to the floor's right edge
	_check(runner2.global_position.y > y_on_floor + 10.0,
		"...then walks off the ledge and falls rather than turning back  [%.1f -> %.1f]"
			% [y_on_floor, runner2.global_position.y])
	runner.queue_free()
	runner2.queue_free()
	floor1.queue_free()
	wall.queue_free()

	# --- the power: dark/light pass through, grey dissolves ------------------
	# Built BEFORE the power is granted: set_glow_suppressed() is a sweep over
	# whatever is in the "dark_thought" group at the moment the power starts,
	# the same as every real room's hazards — all of a world's rooms live
	# under it from load, so nothing is ever added to that group mid-power.
	var dark: DarkThought = DARK_THOUGHT.instantiate()
	dark.position = Vector2(700, 500)
	dark.motion = DarkThought.Motion.VERTICAL
	dark.amplitude = 0.0  # parked, so it cannot drift out from under the test
	world.add_child(dark)
	var grey: DarkThought = GREY_THOUGHT.instantiate()
	grey.position = Vector2(720, 500)
	grey.amplitude = 0.0
	world.add_child(grey)
	await _frames(2)
	_check(dark.get_node("Glow").visible,
		"a dark thought's halo is on before the power runs")

	# --- picking one up grants the power -------------------------------------
	if mushroom != null and is_instance_valid(mushroom):
		_check(not player.has_thought_immunity(),
			"before touching it, no immunity yet")
		player.global_position = mushroom.global_position
		await _frames(15)  # past the pickup's own 0.08s pop-and-free tween
		_check(not is_instance_valid(mushroom) or mushroom.is_queued_for_deletion(),
			"touching it consumes the mushroom")
		_check(player.has_thought_immunity(),
			"...and grants thought immunity")
		_check(player.mushroom_power_type == Mushroom.MushroomType.BLACK_WHITE,
			"...of the type it was carrying")

	player.input_locked = true
	player.velocity = Vector2.ZERO
	player.global_position = dark.position
	await _frames(3)
	_check(player.state != Player.State.DEAD,
		"immune: touching a dark thought does not kill him")
	_check(not dark.get_node("Glow").visible,
		"...and the power turns its warning glow off world-wide")

	player.global_position = grey.position
	await _frames(3)
	_check(player.state != Player.State.DEAD,
		"immune: touching a grey thought does not kill him either")
	_check(not grey.monitoring,
		"...and the grey thought dissolves instead  [monitoring off]")

	# Reset brings the dissolved grey thought back.
	DarkThought.reset_all(get_tree())
	_check(grey.monitoring, "reset_all restores the dissolved grey thought")

	# --- the power expires, and immunity + the glow suppression end with it --
	player.global_position = Vector2(900, 900)  # clear of every hazard above
	await _frames(2)
	player._mushroom_power_timer = 0.05
	await _frames(10)
	_check(not player.has_thought_immunity(), "the power runs out")
	_check(dark.get_node("Glow").visible,
		"...and the suppressed glow comes back")

	# A death cuts the power immediately too, same as the lemon glow.
	player.global_position = Vector2(950, 900)
	await _frames(2)
	player.consume_mushroom(Mushroom.MushroomType.BLACK_WHITE)
	_check(player.has_thought_immunity(), "granted again, to prove death cuts it")
	player.die()
	await _frames(2)
	_check(not player.has_thought_immunity(), "...and a death ends it instantly")
	_check(dark.get_node("Glow").visible,
		"...restoring the glow the same as letting it run out")
	player.input_locked = false

	# --- the import hook: MushroomType actually reaches the prop -------------
	var hook = load("res://scripts/ldtk_entities_post_import.gd").new()
	var built: MysteryBox = hook._build_mystery_box({
		"identifier": "MysteryBox",
		"position": Vector2.ZERO,
		"size": Vector2(16.0, 16.0),
		"fields": {"MushroomType": "MushroomType.BlackWhite"},
	})
	_check(built.mushroom_type == Mushroom.MushroomType.BLACK_WHITE,
		"import: MushroomType.BlackWhite reaches the prop")
	built.free()
	var unset: MysteryBox = hook._build_mystery_box({
		"identifier": "MysteryBox",
		"position": Vector2.ZERO, "size": Vector2(16.0, 16.0),
		"fields": {"MushroomType": null},
	})
	_check(unset.mushroom_type == Mushroom.MushroomType.BLACK_WHITE,
		"...and an unset field falls back to the default rather than nothing")
	unset.free()

	if failures.is_empty():
		print("MYSTERY BOX TEST: ALL PASS")
	else:
		print("MYSTERY BOX TEST: %d FAILURE(S)" % failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)


func _solid(at: Vector2, size: Vector2) -> StaticBody2D:
	var body := StaticBody2D.new()
	body.collision_layer = 1
	body.position = at
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = size
	shape.shape = rect
	body.add_child(shape)
	world.add_child(body)
	return body


func _frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func _check(cond: bool, name: String) -> void:
	print(("  PASS  " if cond else "  FAIL  ") + name)
	if not cond:
		failures.append(name)
