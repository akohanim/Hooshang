extends Node
## SpringPlatform: a bounce pad. A genuine downward landing launches him
## straight up hard, via Player.bounce(); rising into its underside does not.
## Reusable — it launches again on the next landing, with no "spent" state to
## reset, unlike CrumblingPlatform.
##
## Run:  godot --headless res://tests/spring_platform_test.tscn

const SPRING_SCENE := preload("res://scenes/props/platforms/SpringPlatform.tscn")
const PLAYER := preload("res://scenes/characters/hooshang/Hooshang.tscn")

var failures: Array[String] = []
var world: Node2D
var player: Player
var spring: SpringPlatform


func _ready() -> void:
	world = Node2D.new()
	add_child(world)
	player = PLAYER.instantiate()
	world.add_child(player)
	await _run()


func _run() -> void:
	spring = SPRING_SCENE.instantiate()
	spring.position = Vector2(100, 100)
	world.add_child(spring)
	await _frames(2)
	_check(spring.get_collision_layer_value(1), "the platform is solid  [layer 1]")
	_check(spring.is_in_group("platform"), "...and grouped with the other platforms")

	# --- rising into the underside does not launch ---
	player.input_locked = true
	player.respawn(Vector2(100, 116))  # below the platform
	player.velocity = Vector2(0, -60)  # rising, i.e. velocity.y < 0
	await _frames(6)
	_check(player.state != Player.State.JUMP or player.velocity.y > -50.0,
		"rising into the underside does not launch him  [state %s, vy %.1f]"
			% [player.state_name(), player.velocity.y])

	# --- a genuine downward landing launches him, hard ---
	player.respawn(Vector2(100, 60))
	player.velocity = Vector2(0, 40)  # falling toward it
	var launched := false
	for i in 60:
		await _frames(1)
		if player.velocity.y < -50.0:
			launched = true
			break
	_check(launched, "landing on it launches him upward")
	_check(player.velocity.y <= -spring.launch_speed + 5.0,
		"...at (about) the configured launch speed  [%.1f, want %.1f]"
			% [player.velocity.y, -spring.launch_speed])
	_check(player.state == Player.State.JUMP,
		"...and lands him in the JUMP state, so gravity flies the arc  [%s]"
			% player.state_name())

	# --- the release beat: a genuinely taller EXPANDED frame, not a scale
	# trick played on IDLE, extending UP off the same standable surface ---
	# See spring_platform.gd's FIXED SIZE note and _apply_frame's own doc: the
	# sprite is bottom-anchored to FIXED_SIZE regardless of the texture's own
	# height, so a taller texture's extra pixels are added entirely above
	# where he actually stood, not split or added below into the mount.
	#
	# Checked INSIDE the apex-measurement loop below rather than as its own
	# sequential await _frames() beforehand — a first version did that, and
	# the extra ~0.2s it spent waiting on the frame swap before `start_y` was
	# even captured ate a real chunk of the player's upward arc, so the apex
	# it went on to measure came back reading as ~0: the measurement started
	# from somewhere already close to the top, not from the launch.
	var idle_top: float = spring.FIXED_SIZE.y * 0.5 - spring.IDLE.get_height()
	var expanded_top: float = spring.FIXED_SIZE.y * 0.5 - spring.EXPANDED.get_height()
	_check(expanded_top < idle_top,
		"sanity: EXPANDED's own canvas is taller than IDLE's, so its anchored top sits higher  [idle top %.1f, expanded top %.1f]"
			% [idle_top, expanded_top])
	var tile: Sprite2D = spring._visual.get_child(0)

	# --- the whole point: it reaches WAY higher than a normal jump ---
	# Reference is classic Mario's spring — a bounce that clears a platform
	# out of a normal jump's reach, not an assisted hop. Player.jump_speed's
	# own doc measures a full held jump's apex at 34px; a spring that cannot
	# clear that by a wide margin is not reading as a spring at all, which is
	# exactly the bug this check would have caught (it shipped at ~12px, HALF
	# a normal jump, until this was measured directly against the reference).
	const FULL_JUMP_APEX := 34.0
	var start_y: float = player.global_position.y
	var apex := 0.0
	var checked_expanded := false
	var checked_idle_again := false
	for i in 90:
		await _frames(1)
		apex = maxf(apex, start_y - player.global_position.y)
		var elapsed := (i + 1) / 60.0
		if not checked_expanded and elapsed >= spring.compress_time:
			checked_expanded = true
			_check(tile.texture == spring.EXPANDED,
				"compress_time after landing, the EXPANDED frame is showing")
			_check(is_equal_approx(tile.position.y, expanded_top),
				"...bottom-anchored so it extends further up, not repositioned some other way  [%.1f, want %.1f]"
					% [tile.position.y, expanded_top])
		elif not checked_idle_again and elapsed >= spring.compress_time + spring.expand_time:
			checked_idle_again = true
			_check(tile.texture == spring.IDLE,
				"expand_time later, it has handed back to IDLE")
			_check(is_equal_approx(tile.position.y, idle_top),
				"...back at IDLE's own anchored position  [%.1f, want %.1f]" % [tile.position.y, idle_top])
		if player.velocity.y >= 0.0 and i > 5:
			break  # past the top of the arc
	_check(checked_expanded and checked_idle_again,
		"the frame-swap checks above actually ran inside the apex-measurement window")
	_check(apex >= FULL_JUMP_APEX * 1.5,
		"the bounce clears a full held jump's own apex by a wide margin  "
			+ "[%.1fpx vs a %.0fpx jump]" % [apex, FULL_JUMP_APEX])

	# --- it is NOT a held jump: nothing extends it, unlike a real jump ---
	Input.action_press("jump")
	await _frames(4)
	Input.action_release("jump")
	_check(player.jump_hold_timer <= 0.0,
		"the launch does not arm the variable-jump hold  [%.2f]"
			% player.jump_hold_timer)

	# --- reusable: no state to reset, it launches again next landing ---
	# Generous budget: the much bigger bounce (see above) takes noticeably
	# longer to fall back from than the old ~12px one did.
	await _frames(150)  # let gravity bring him back down onto it
	var relaunched := false
	for i in 60:
		await _frames(1)
		if player.velocity.y < -50.0:
			relaunched = true
			break
	_check(relaunched, "it launches again on the very next landing  [no 'spent' flag]")
	player.input_locked = false

	# --- the LDtk side: SpringPlatform reuses the same builder as Platform ---
	var importer = load("res://scripts/ldtk_entities_post_import.gd").new()
	var built: StaticBody2D = importer._build_platform(
		{"position": Vector2(40.0, 20.0), "size": Vector2(48.0, 8.0)},
		SPRING_SCENE)
	# _build_platform() assigns `.size` before `built` is in the tree, and
	# _rebuild() (like Platform's own) refuses to do anything while
	# `not is_inside_tree()` — so "Shape" does not exist yet at this point,
	# only once it is actually parented and _ready() runs _rebuild() for
	# real. Skipping this add_child() reads as "the importer path is broken"
	# when it is really just "nothing built it yet".
	world.add_child(built)
	await _frames(1)
	_check(built is SpringPlatform, "the importer builds a SpringPlatform from the entity")
	_check(built.position == Vector2(40.0, 20.0),
		"...placed from the LDtk entity  [%s]" % built.position)
	# NOT sized from the entity — this is the point of FIXED_SIZE (see
	# spring_platform.gd's class doc). The builder above handed it a 48px-wide
	# request, same as the old resizable behaviour would have; the actual
	# collision footprint has to come back FIXED_SIZE regardless, or "this
	# should be the only size for this entity" is just a comment nobody
	# enforces. Checked on the real CollisionShape2D, not the inherited `size`
	# field — `size` still faithfully stores whatever it was asked for
	# (Godot refuses to let a subclass redeclare a property its parent
	# exports, so there is no shadowing it away), which is exactly why
	# checking `size` alone would not have caught a _rebuild() that quietly
	# went back to using it.
	var built_shape: RectangleShape2D = built.get_node("Shape").shape
	_check(built_shape.size == SpringPlatform.FIXED_SIZE,
		"...but its actual footprint is always FIXED_SIZE, even asked for 48px wide  [%s]"
			% built_shape.size)
	built.free()

	if failures.is_empty():
		print("SPRING PLATFORM TEST: ALL PASS")
	else:
		print("SPRING PLATFORM TEST: %d FAILURE(S)" % failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)


func _frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func _check(cond: bool, name: String) -> void:
	print(("  PASS  " if cond else "  FAIL  ") + name)
	if not cond:
		failures.append(name)
