extends Node2D
## A maintenance hatch tears open under the runner. Tile edits are temporary,
## local to the loaded room, and restored before the next room becomes visible.
@export var source_room_name := "Level_14"
@export var target_room_name := "Level_15"
## Exit-triggered hatch centre, in pixels inward from the room boundary.
@export var exit_inset := 16.0
## Brief metal flex before the two leaves drop inward.
@export var buckle_time := 0.05
## Time for the hinges to swing open.
@export var opening_time := 0.10
## Cartoon hesitation after the leaves have fully opened.
@export var hover_time := 0.6
var hovering := false

var world: LdtkWorld
var shadow: Darkshang
var source_room: Node2D
var target_room: Node2D
var active := false
var opening := 0.0
var _draw_hatch := false
var _tiles: Array[Dictionary] = []

func _ready() -> void:
	$Metal.stream = preload("res://assets/sfx/trapdoor_open.tres")
	$Landing.stream = preload("res://assets/sfx/trapdoor_land.tres")

func bind(to_world: LdtkWorld, pursuer: Darkshang) -> void:
	world = to_world
	shadow = pursuer
	for room in world.rooms:
		if room.name == source_room_name: source_room = room
		if room.name == target_room_name: target_room = room
	if source_room == null or target_room == null:
		set_physics_process(false)
		return
	world.exit_overrides[source_room] = _exit_requested
	# Re-applied at every world boot, including older saves with a reciprocal
	# 15 -> 14 route, and when returning to 15 from later escape rooms.
	world.block_return_route(target_room, source_room)

func _exit_requested(target: Node2D) -> bool:
	if target != target_room:
		return false
	# Claim the exit even if a dialogue currently owns input. It may be retried
	# once speech ends.
	request_drop()
	return true

func request_drop() -> void:
	if active or world.current_room != source_room or world._transitioning:
		return
	if world.player.input_locked or world.player.state == Player.State.DEAD:
		return
	active = true
	# Claim the chase immediately, before the next overlap check can ingest him.
	shadow.stand_down()
	# Freeze and protect him in this same tick; tile changes wait for the flex.
	_run_drop()

func _run_drop() -> void:
	await world.transition_with_sequence(target_room, _depart, _arrive)
	active = false

func _depart() -> void:
	var player := world.player
	var feet := player.hitbox_rect().end.y
	var room_bounds := world.room_rect(source_room)
	var on_left := player.global_position.x < room_bounds.get_center().x
	var hatch_x := room_bounds.position.x + exit_inset if on_left else room_bounds.end.x - exit_inset
	var from := Vector2(hatch_x, feet - 1.0)
	var ray := PhysicsRayQueryParameters2D.create(from, Vector2(from.x, room_bounds.end.y + 8), 1)
	var hit := get_world_2d().direct_space_state.intersect_ray(ray)
	var floor_y: float = hit.position.y if not hit.is_empty() else room_bounds.end.y - 8.0
	global_position = Vector2(hatch_x, roundf(maxf(floor_y, feet)))
	opening = 0.0
	_draw_hatch = true
	queue_redraw()
	player.visual.play("fall")
	# Freeze the camera at departure: the drop should leave the picture, not drag
	# the viewport down into the temporary hole.
	player.camera.set_as_top_level(true)
	var flex := create_tween()
	flex.tween_interval(buckle_time)
	await flex.finished
	$Metal.play()
	_cut_floor()
	var hinges := create_tween()
	hinges.tween_method(_set_opening, 0.0, 1.0, opening_time).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	await hinges.finished
	hovering = true
	await player.play_trapdoor_flail(hover_time)
	hovering = false
	# Release only after the suspended reaction; use ordinary falling gravity.
	var fall_speed := 0.0
	while player.global_position.y < global_position.y + 36.0:
		await get_tree().physics_frame
		var delta := get_physics_process_delta_time()
		fall_speed = minf(fall_speed + player.fall_gravity * delta, player.max_fall_speed)
		player.global_position.y = minf(player.global_position.y + fall_speed * delta, global_position.y + 36.0)
	var fade := create_tween()
	fade.tween_property($FadeLayer/Fade, "color:a", 1.0, 0.12)
	await fade.finished
	_restore_floor()
	_draw_hatch = false
	queue_redraw()
	player.camera.set_as_top_level(false)
	player.camera.position = Vector2.ZERO

func _arrive() -> void:
	var player := world.player
	# PlayerStart can sit a few pixels above its platform. Settle through real
	# collision before the prone pose so he never gets up while floating.
	for i in 90:
		if player.dialogue_land_step(1.0 / Engine.physics_ticks_per_second):
			break
		await get_tree().physics_frame
	player.look(-1)
	$Landing.play()
	var fade := create_tween()
	fade.tween_property($FadeLayer/Fade, "color:a", 0.0, 0.10)
	await player.play_fall_recovery()

func _set_opening(value: float) -> void:
	opening = value
	queue_redraw()

func _cut_floor() -> void:
	var hole := Rect2(global_position + Vector2(-16, 0), Vector2(32, 40))
	for node in source_room.get_children():
		if node is not TileMapLayer: continue
		var layer := node as TileMapLayer
		if layer.tile_set == null: continue
		var cell_size := Vector2(layer.tile_set.tile_size)
		for cell in layer.get_used_cells():
			var center := layer.to_global(layer.map_to_local(cell))
			if not hole.intersects(Rect2(center - cell_size * 0.5, cell_size)): continue
			_tiles.append({"layer": layer, "cell": cell, "source": layer.get_cell_source_id(cell), "atlas": layer.get_cell_atlas_coords(cell), "alternative": layer.get_cell_alternative_tile(cell)})
			layer.erase_cell(cell)

func _restore_floor() -> void:
	for tile in _tiles:
		if is_instance_valid(tile.layer):
			tile.layer.set_cell(tile.cell, tile.source, tile.atlas, tile.alternative)
	_tiles.clear()

func _exit_tree() -> void:
	_restore_floor()
	if is_instance_valid(world) and is_instance_valid(source_room):
		world.exit_overrides.erase(source_room)

func _draw() -> void:
	if not _draw_hatch: return
	# Black shaft, shaded steel rim, inset screws and worn amber caution marks.
	# All edges are whole game pixels; leaves foreshorten rather than blur-rotate.
	draw_rect(Rect2(-18, -2, 36, 5), Color("343c42"))
	draw_rect(Rect2(-16, 0, 32, 40), Color("080b10"))
	var leaf_width := roundf(15.0 * (1.0 - opening))
	var depth := roundf(14.0 * opening)
	for side in [-1, 1]:
		var outer := float(side * 16)
		var inner := float(side) * (16.0 - leaf_width)
		var points := PackedVector2Array([Vector2(outer, 0), Vector2(inner, depth), Vector2(inner, depth + 3), Vector2(outer, 3)])
		draw_colored_polygon(points, Color("555d60"))
		draw_line(Vector2(outer, 0), Vector2(inner, depth), Color("8b9290"), 1)
		draw_line(Vector2(outer, 3), Vector2(inner, depth + 3), Color("252c32"), 1)
		for i in 3:
			var x := lerpf(outer, inner, (i + 0.5) / 3.0)
			var y := lerpf(0.0, depth, (i + 0.5) / 3.0)
			draw_rect(Rect2(roundf(x), roundf(y), 2, 1), Color("9e8752"))
		draw_rect(Rect2(outer - 1, -1, 2, 2), Color("adb2aa"))
	# Falling plaster flecks give the new opening the same decay as the office.
	if opening > 0.0:
		for i in 7:
			var x := -13 + (i * 11) % 27
			var y := 5 + int(opening * float(8 + i * 3))
			draw_rect(Rect2(x, y, 1 + i % 2, 1), Color("84796b"))
