extends Node
## The two office-ceiling platforms: one holds, one does not.
## Run:  godot --headless res://tests/platform_test.tscn

const PLATFORM := preload("res://scenes/props/platforms/Platform.tscn")
const CRUMBLING := preload("res://scenes/props/platforms/CrumblingPlatform.tscn")
const PLAYER := preload("res://scenes/characters/hooshang/Hooshang.tscn")

var failures: Array[String] = []
var world: Node2D
var player: Player


func _ready() -> void:
	world = Node2D.new()
	add_child(world)
	player = PLAYER.instantiate()
	world.add_child(player)
	_run()


func _run() -> void:
	# --- the solid one holds ------------------------------------------------
	var solid: StaticBody2D = PLATFORM.instantiate()
	solid.position = Vector2(0, 100)
	solid.size = Vector2(72, 8)
	world.add_child(solid)
	await _frames(2)
	_check(solid.size == Vector2(72, 8),
		"a solid platform keeps the width it was given  [%s]" % solid.size)
	# Width snaps to whole cells; the height is forced to one however it is set.
	solid.size = Vector2(70, 40)
	await _frames(2)
	_check(solid.size == Vector2(72, 8),
		"...snapped to whole cells, and always one cell tall  [%s]" % solid.size)

	player.respawn(Vector2(36, 70))
	var landed := await _settle(120)
	_check(landed, "he lands on the solid platform")
	# The prop is CENTRED on its position, so a platform at y=100 that is one
	# cell tall has its surface at 96.
	_check(absf(player.global_position.y + Player.HALF_HEIGHT - solid.top_y()) < 1.5,
		"...on its top surface  [feet %.1f, surface %.1f]"
			% [player.global_position.y + Player.HALF_HEIGHT, solid.top_y()])
	await _frames(120)
	_check(player.is_on_floor(), "and it is still there two seconds later")

	# --- the crumbling one does not ----------------------------------------
	var crumb: StaticBody2D = CRUMBLING.instantiate()
	crumb.position = Vector2(400, 100)
	crumb.size = Vector2(48, 8)
	world.add_child(crumb)
	await _frames(2)
	_check(crumb.crumble_time < 1.0,
		"it goes in under a second  [%.2fs]" % crumb.crumble_time)
	_check(crumb.is_in_group("crumbling"),
		"and it is findable for the reset sweep")

	player.respawn(Vector2(424, 70))
	var stood := await _settle(120)
	_check(stood, "he lands on the crumbling platform")
	# It must hold long enough to be a platform rather than a trap.
	await _frames(6)
	_check(player.is_on_floor(), "it holds for the first few frames")

	var fell := false
	for i in int((crumb.crumble_time + crumb.fall_time) * 60.0) + 40:
		await _frames(1)
		if not player.is_on_floor():
			fell = true
			break
	_check(fell, "then it gives way and drops him")
	_check(not crumb.get_collision_layer_value(1),
		"its collision is off once it has gone")

	# --- and it comes back --------------------------------------------------
	CrumblingPlatform.reset_all(get_tree())
	await _frames(2)
	_check(crumb.get_collision_layer_value(1),
		"reset_all puts its collision back")
	_check(is_equal_approx(crumb.get_node("Visual").modulate.a, 1.0)
			and crumb.get_node("Visual").position == Vector2.ZERO,
		"...and the wreckage back where it started")

	# It has to be STANDABLE again, not merely flagged as solid: the reset used
	# to look right and still drop him, because _spent was never cleared.
	player.respawn(Vector2(424, 70))
	var again := await _settle(120)
	_check(again, "he can stand on it again after a reset")
	await _frames(6)
	_check(player.is_on_floor(), "and it holds again, rather than being spent")

	if failures.is_empty():
		print("PLATFORM TEST: ALL PASS")
	else:
		print("PLATFORM TEST: %d FAILURE(S)" % failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)


func _settle(budget: int) -> bool:
	for i in budget:
		await _frames(1)
		if player.is_on_floor():
			return true
	return false


func _frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func _check(cond: bool, name: String) -> void:
	print(("  PASS  " if cond else "  FAIL  ") + name)
	if not cond:
		failures.append(name)
