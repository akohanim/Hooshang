extends Node
## The office ceiling you can stand on: two platforms, one of which does not
## hold, and the suspended ceiling run itself.
## Run:  godot --headless res://tests/platform_test.tscn

const PLATFORM := preload("res://scenes/props/platforms/Platform.tscn")
const CRUMBLING := preload("res://scenes/props/platforms/CrumblingPlatform.tscn")
const CEILING_PANEL := preload("res://scenes/props/lighting/CeilingPanel.tscn")
const CEILING_LIGHT := preload("res://scenes/props/lighting/CeilingLight.tscn")
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

	# --- the suspended ceiling run is solid ---------------------------------
	#
	# It draws the ceiling, so it has to BE the ceiling. Before this it was a
	# picture: a jump went straight up through the tiles.
	var run: CeilingPanel = CEILING_PANEL.instantiate()
	run.position = Vector2(800, 100)
	run.run_tiles = 5
	world.add_child(run)
	await _frames(2)
	var box: RectangleShape2D = run.get_node("Solid/CollisionShape2D").shape
	# Exactly the width of the art, which is the only rule that cannot drift:
	# the run rounds UP to an odd number of cells, so a collider written down by
	# hand disagrees with what is drawn the first time somebody asks for four.
	_check(box.size == Vector2(CeilingPanel.TILE.x * 5, CeilingPanel.TILE.y),
		"the run's collider is as wide as the run  [%s, 5 cells of %.0f]"
			% [box.size, CeilingPanel.TILE.x])
	run.run_tiles = 4
	await _frames(2)
	_check(run.run_tiles == 5 and box.size.x == CeilingPanel.TILE.x * 5,
		"...and follows it through the rounding to an odd count  [%d cells, %.0fpx]"
			% [run.run_tiles, box.size.x])

	player.respawn(Vector2(800, 70))
	var on_ceiling := await _settle(120)
	_check(on_ceiling, "he lands on top of the ceiling run")
	_check(absf(player.global_position.y + Player.HALF_HEIGHT
			- (run.position.y - CeilingPanel.TILE.y * 0.5)) < 1.5,
		"...on its top surface  [feet %.1f, surface %.1f]"
			% [player.global_position.y + Player.HALF_HEIGHT,
			   run.position.y - CeilingPanel.TILE.y * 0.5])

	# And from underneath: he must bonk, not pass through. Fired up hard rather
	# than jumped, so this is about the collider and not about his jump height.
	player.respawn(Vector2(800, 160))
	player.input_locked = true
	await _frames(1)
	var top := 999.0
	for i in 40:
		player.velocity.y = -240.0
		await _frames(1)
		top = minf(top, player.global_position.y)
	player.input_locked = false
	_check(top - Player.HALF_HEIGHT >= run.position.y + CeilingPanel.TILE.y * 0.5 - 1.0,
		"he cannot punch up through it from below  [head %.1f, underside %.1f]"
			% [top - Player.HALF_HEIGHT, run.position.y + CeilingPanel.TILE.y * 0.5])

	# --- but the bare light is not ------------------------------------------
	#
	# CeilingLight draws no run at all: it lights a PAINTED 8px cell, and that
	# tile already carries the room's own collision. A body here would be an
	# invisible slab hanging in front of the tiles it is lighting.
	var lamp: CeilingPanel = CEILING_LIGHT.instantiate()
	lamp.position = Vector2(1000, 100)
	world.add_child(lamp)
	await _frames(2)
	_check(lamp.get_node("Solid/CollisionShape2D").disabled,
		"a bare CeilingLight has no collider working")
	player.respawn(Vector2(1000, 60))
	var passed_through := false
	for i in 90:
		await _frames(1)
		if player.global_position.y > lamp.position.y + 40.0:
			passed_through = true
			break
	_check(passed_through, "...and he falls straight through where it is")

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
