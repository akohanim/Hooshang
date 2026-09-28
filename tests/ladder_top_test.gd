extends Node
## Ladder TOP behaves as a platform: reaching the top of a rail he stands on it
## (he cannot climb clear off the top, only rest there or climb back down), a
## jump from the top is a FULL normal jump rather than the reduced mid-rail
## hop-off, and pressing down from the top resumes climbing down.
##
## Driven with real input actions (Input.action_press) rather than by writing
## velocity or calling _state_climb by hand: "a jump off the top is full power"
## and "down climbs back down" are both claims about the input path, and the
## clamp that keeps him gripping at the top only means anything if the ladder's
## own overlap logic (ladder.gd) still reads him as held there.
## Run:  godot --headless res://tests/ladder_top_test.tscn

## Typed as Area2D rather than Ladder, reached through the scene rather than the
## class name — the same reason slide_test avoids the class name: a headless run
## started before the editor has scanned for `class_name` cannot parse a script
## that names the new type.
const LADDER_SCENE := preload("res://scenes/props/zones/Ladder.tscn")

## An isolated rail in open air. A partial floor is added later to reproduce
## the top-edge dismount bug without depending on changing story-room geometry.
const RAIL_X := 100.0
const RAIL_HEIGHT := 40.0
const TOP_Y := 190.0

var failures: Array[String] = []
var world: Node2D
var player: Player
var ladder: Area2D


func _ready() -> void:
	# Isolated geometry: room 0 now has a cutscene and floor in the old test site.
	world = Node2D.new()
	add_child(world)
	player = preload("res://scenes/characters/hooshang/Hooshang.tscn").instantiate()
	world.add_child(player)
	player.input_locked = false
	player.has_dash = true

	ladder = LADDER_SCENE.instantiate()
	ladder.height = RAIL_HEIGHT
	world.add_child(ladder)
	# Area2D origin is the shape's CENTRE, so top edge = centre.y - height/2.
	ladder.global_position = Vector2(RAIL_X, TOP_Y + RAIL_HEIGHT * 0.5)
	await _frames(5)

	var top_y: float = ladder.global_position.y - RAIL_HEIGHT * 0.5

	# --- reaching the top clamps him there, still gripping ---
	await _grip_from(Vector2(RAIL_X, top_y + RAIL_HEIGHT - 4.0))
	_check(player.climbing(), "pressing up at the foot grips the rail  [state %s]" % player.state_name())
	Input.action_press("move_up")
	await _frames(60)   # long enough to climb the whole rail and press against the top
	var settled_y := player.global_position.y
	_check(player.climbing(), "he is still gripping at the top, not dropped into a fall  [state %s]" % player.state_name())
	_check(absf(settled_y - top_y) <= 4.0,
		"his box centre settles at the rail's top edge  [%.1f vs top %.1f]" % [settled_y, top_y])
	await _frames(30)   # keep holding up
	_check(player.climbing() and player.global_position.y >= top_y - 1.0,
		"holding up never carries him off the top  [rose %.1fpx over the edge]" % (top_y - player.global_position.y))
	Input.action_release("move_up")

	for action in ["move_left", "move_right"]:
		Input.action_press(action)
		await _frames(12)
		Input.action_release(action)
		_check(player.climbing() and absf(player.global_position.x - RAIL_X) < 1.0,
			"horizontal input keeps a secure top grip: " + action)

	# Up must remain held THROUGH the jump, reproducing the reported re-grab.
	Input.action_press("move_up")
	# --- a jump from the top is a FULL jump ---
	# Captured as launch speed, not apex height, so a ceiling over the rail could
	# never make a full jump read as a hop. Full ≈ -jump_speed; the mid-rail hop
	# is 0.6*jump_speed with no sustained hold.
	var top_launch := await _jump_launch_speed()
	_check(top_launch < -(player.jump_speed * 0.9),
		"jumping from the top launches at full jump_speed  [%.0f of -%.0f]" % [top_launch, player.jump_speed])

	Input.action_release("move_up")

	# --- a mid-rail jump is still the reduced hop ---
	await _grip_from(Vector2(RAIL_X, top_y + RAIL_HEIGHT - 4.0))
	# Grip only — do NOT ride to the top, so this jump comes from mid-rail.
	_check(player.climbing() and player.global_position.y > top_y + 4.0,
		"gripping low, not yet at the top  [%.1f]" % player.global_position.y)
	var hop_launch := await _jump_launch_speed()
	_check(hop_launch > -(player.jump_speed * 0.8),
		"a mid-rail jump is still the softer hop  [%.0f]" % hop_launch)
	_check(top_launch < hop_launch - 20.0,
		"the top jump is clearly stronger than the hop  [%.0f vs %.0f]" % [top_launch, hop_launch])

	# --- he can climb back DOWN from the top ---
	await _grip_from(Vector2(RAIL_X, top_y + RAIL_HEIGHT - 4.0))
	Input.action_press("move_up")
	await _frames(60)   # ride up to the top and rest
	Input.action_release("move_up")
	await _frames(4)
	var at_top := player.global_position.y
	Input.action_press("move_down")
	await _frames(20)
	Input.action_release("move_down")
	_check(player.climbing() and player.global_position.y > at_top + 8.0,
		"pressing down from the top climbs back down the rail  [%.1f -> %.1f]" % [at_top, player.global_position.y])

	# A real floor brushing one half of the top used to release the grip or
	# trigger ledge-slip. Keep support under just one edge of the player.
	var shelf := StaticBody2D.new()
	var shape := CollisionShape2D.new()
	var rectangle := RectangleShape2D.new()
	rectangle.size = Vector2(16, 8)
	shape.shape = rectangle
	shelf.add_child(shape)
	world.add_child(shelf)
	shelf.global_position = Vector2(RAIL_X + 10, top_y + 10)
	await _grip_from(Vector2(RAIL_X, top_y - 1))
	Input.action_press("move_down")
	await _frames(5)
	Input.action_release("move_down")
	_check(player.is_on_floor(), "top-edge fixture really touches floor")
	for action in ["move_left", "move_right"]:
		Input.action_press(action)
		await _frames(15)
		Input.action_release(action)
		_check(player.state == Player.State.CLIMB and player.at_ladder_top(),
			"brushing floor then steering keeps top grip: " + action)
	_release_all()

	if failures.is_empty():
		print("LADDER TOP TEST: ALL PASS")
	else:
		print("LADDER TOP TEST: %d FAILURE(S)" % failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)


# ------------------------------------------------------------------ moves ----

## Put him overlapping the rail at `where`, gravity-free once gripping, and press
## up briefly so the ladder's own overlap poll (ladder.gd) grips him — the real
## entry path, not a hand-set state.
func _grip_from(where: Vector2) -> void:
	_release_all()
	if player.climbing():
		player.exit_ladder(ladder)
	player.respawn(where)
	await _frames(4)
	Input.action_press("move_up")
	await _frames(3)
	Input.action_release("move_up")
	await _frames(2)


## The strongest upward speed in the first few frames after a jump press, in px/s
## (negative is up). Independent of any ceiling above the rail.
func _jump_launch_speed() -> float:
	var vmin := 0.0
	Input.action_press("jump")
	for i in 4:
		await _frames(1)
		vmin = minf(vmin, player.velocity.y)
	if Input.is_action_pressed("move_up"):
		_check(not player.climbing() and player.global_position.y < TOP_Y - 4.0,
			"holding Up through jump clears the rail without re-grabbing")
	Input.action_release("jump")
	await _frames(20)   # land / settle before the next measurement
	return vmin


func _release_all() -> void:
	for action in ["jump", "dash", "move_left", "move_right", "move_up", "move_down"]:
		Input.action_release(action)


func _check(ok: bool, msg: String) -> void:
	print("  %s  %s" % ["PASS" if ok else "FAIL", msg])
	if not ok:
		failures.append(msg)


## PHYSICS frames, not idle ones — the same reason slide_test spells this out:
## overlaps and jump arcs happen in the physics step, and headless idle frames
## run faster than physics frames.
func _frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame
