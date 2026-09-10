extends Node2D
## Paintable Water tiles — the tile-based counterpart to the resizable Pond
## entity (see pond_test.gd for that one; the two are kept side by side, not
## one replacing the other).
##
## Two halves, same split thought_tiles_test.gd uses for ThoughtHazards:
##
##  1. World integration — a real Act 2 room's Water layer exists, collision
##     is off, LdtkWorld caches it, and painting a cell (in memory, no LDtk
##     round trip needed) starts and ends a swim exactly like standing in a
##     Pond does — including a checkpoint-style re-entry, which is the one
##     way this family of bug (see slide_zone.gd's own note on it) shows up.
##
##  2. WaterLayer itself, built on a bare TileMapLayer with a TileSet
##     constructed in code from the real sheet (no LDtk round trip either):
##     a cell two rows under an opening gets retargeted to the deep tile, a
##     shimmering cell's frame actually advances, and — unlike Pond — no fish
##     get spawned at all.
##
## Run:  godot --headless res://tests/water_tile_test.tscn

const WATER_SHEET := preload("res://ldtk/art/act2_water_tiles.png")
const WATER_LAYER_SCRIPT := preload("res://scripts/ldtk_water_layer.gd")

var _ok := 0
var _fail := 0
var _world: LdtkWorld


func _ready() -> void:
	SaveGame.slot = -1
	_world = preload("res://ldtk/Act2World.tscn").instantiate()
	LdtkWorld.debug_start_room = "Act_2_Level_0"
	add_child(_world)
	_run.call_deferred()


func _run() -> void:
	await get_tree().process_frame
	await get_tree().process_frame

	_world_integration()
	await _layer_unit()

	print("WATER TILE TEST: %d pass, %d fail" % [_ok, _fail])
	get_tree().quit(0 if _fail == 0 else 1)


# --------------------------------------------------------- world integration
func _world_integration() -> void:
	var room := _world.current_room
	_check("started in Act_2_Level_0", room != null and room.name == "Act_2_Level_0")
	if room == null:
		return

	var layer := room.get_node_or_null("Water") as TileMapLayer
	_check("Water layer exists in the room", layer != null)
	if layer == null:
		return
	_check("collision disabled (pass-through)", not layer.collision_enabled)
	_check("ldtk_world cached the water layer", _world._water_layer == layer)

	var player := _world.player
	player.input_locked = true
	var cell := layer.local_to_map(layer.to_local(player.global_position))
	_check("empty cell is not water", not _world._in_water_tile())
	_check("clear of any painted cell, he is not swimming", not player.swimming())

	var source_id := -1
	for i in layer.tile_set.get_source_count():
		source_id = layer.tile_set.get_source_id(i)
		break
	if source_id == -1:
		_check("tile source exists on the layer", false)
		return

	# Paint a plain fill cell at the player's own position.
	layer.set_cell(cell, source_id, Vector2i(WATER_LAYER_SCRIPT.Tile.FILL, 0))
	_check("_in_water_tile() detects the painted cell", _world._in_water_tile())
	_world._physics_process(1.0 / 60.0)
	_check("standing on it starts a swim  [state %s]" % player.state_name(),
		player.swimming() and player.state_name() == "SWIM")

	# Step clear of it — same as walking to the far bank or surfacing.
	layer.erase_cell(cell)
	_world._physics_process(1.0 / 60.0)
	_check("stepping off the painted cell ends the swim", not player.swimming())

	# ...and a checkpoint-style re-entry (teleported back onto a still-painted
	# cell, no boundary ever crossed) starts it again — the exact bug
	# player.gd's own respawn() note and pond_test.gd's "respawning INSIDE
	# it" check both exist for, on the Pond path.
	layer.set_cell(cell, source_id, Vector2i(WATER_LAYER_SCRIPT.Tile.FILL, 0))
	player.global_position = layer.to_global(layer.map_to_local(cell))
	_world._physics_process(1.0 / 60.0)
	_check("teleporting straight onto a painted cell also starts a swim",
		player.swimming())
	layer.erase_cell(cell)
	_world._physics_process(1.0 / 60.0)


# ------------------------------------------------------------ layer unit ----
func _layer_unit() -> void:
	var tile_set := TileSet.new()
	tile_set.tile_size = Vector2i(8, 8)
	var source := TileSetAtlasSource.new()
	source.texture = WATER_SHEET
	source.texture_region_size = Vector2i(8, 8)
	for y in 3:
		for x in 5:
			source.create_tile(Vector2i(x, y))
	var source_id := tile_set.add_source(source)

	var layer := TileMapLayer.new()
	layer.tile_set = tile_set
	layer.set_script(WATER_LAYER_SCRIPT)

	# A 1-wide, 3-tall column: row 0 is the surface (TOP, as LDtk's own rule
	# would have placed for "nothing painted above"), rows 1 and 2 are plain
	# FILL, as LDtk's fill rule places every painted cell before this script
	# ever touches it. Plus one isolated LEFT cell elsewhere, its own
	# 1-cell region, to prove a second region is counted separately.
	layer.set_cell(Vector2i(0, 0), source_id, Vector2i(WATER_LAYER_SCRIPT.Tile.TOP, 0))
	layer.set_cell(Vector2i(0, 1), source_id, Vector2i(WATER_LAYER_SCRIPT.Tile.FILL, 0))
	layer.set_cell(Vector2i(0, 2), source_id, Vector2i(WATER_LAYER_SCRIPT.Tile.FILL, 0))
	layer.set_cell(Vector2i(5, 5), source_id, Vector2i(WATER_LAYER_SCRIPT.Tile.LEFT, 0))
	# MIRRORED cells, the way LDtk's own auto-rules actually place the other
	# edges: only four tiles are ever drawn, and the right bank is `left`
	# flipped X while the floor is `top` flipped Y. Both kinds are here
	# because this script rewrites them by two different routes — the depth
	# pass in _ready() for the static ones, the shimmer in _process() for the
	# animated ones — and it dropped the transform on BOTH.
	layer.set_cell(Vector2i(9, 1), source_id, Vector2i(WATER_LAYER_SCRIPT.Tile.LEFT, 0),
		TileSetAtlasSource.TRANSFORM_FLIP_H)
	layer.set_cell(Vector2i(9, 0), source_id, Vector2i(WATER_LAYER_SCRIPT.Tile.TOP, 0),
		TileSetAtlasSource.TRANSFORM_FLIP_V)
	add_child(layer)
	await get_tree().process_frame

	_check("1 row under the surface stays shallow (fill)  [got %d]"
			% layer.get_cell_atlas_coords(Vector2i(0, 1)).x,
		layer.get_cell_atlas_coords(Vector2i(0, 1)).x == WATER_LAYER_SCRIPT.Tile.FILL)
	_check("2 rows under the surface is retargeted to fill_deep  [got %d]"
			% layer.get_cell_atlas_coords(Vector2i(0, 2)).x,
		layer.get_cell_atlas_coords(Vector2i(0, 2)).x == WATER_LAYER_SCRIPT.Tile.FILL_DEEP)
	_check("the surface tile itself is untouched (still top)  [got %d]"
			% layer.get_cell_atlas_coords(Vector2i(0, 0)).x,
		layer.get_cell_atlas_coords(Vector2i(0, 0)).x == WATER_LAYER_SCRIPT.Tile.TOP)

	var before_frame := layer.get_cell_atlas_coords(Vector2i(0, 0)).y
	layer._process(WATER_LAYER_SCRIPT.FRAME_TIME * 1.5)
	var after_frame := layer.get_cell_atlas_coords(Vector2i(0, 0)).y
	_check("the surface shimmer actually advances a frame  [%d -> %d]"
			% [before_frame, after_frame], before_frame != after_frame)
	_check("a plain fill/left cell is never touched by the animation pass",
		layer.get_cell_atlas_coords(Vector2i(0, 1)) == Vector2i(WATER_LAYER_SCRIPT.Tile.FILL, 0)
		and layer.get_cell_atlas_coords(Vector2i(5, 5)) == Vector2i(WATER_LAYER_SCRIPT.Tile.LEFT, 0))

	# The auto-rules' MIRRORING survives every rewrite. Reported from play as
	# "horizontal and vertical lines that shouldn't be there": set_cell()'s
	# `alternative_tile` argument defaults to 0 (the untransformed tile), so
	# re-drawing a cell without handing the flip back silently reverted it to
	# the unmirrored drawing — and the contact line the tile was DRAWN with
	# then landed a full cell inside the water instead of against the bank it
	# was placed at, with nothing to be the contact line of.
	_check("a flipped LEFT (the right bank) keeps its mirroring through the depth pass  [alt %d]"
			% layer.get_cell_alternative_tile(Vector2i(9, 1)),
		layer.get_cell_alternative_tile(Vector2i(9, 1)) & TileSetAtlasSource.TRANSFORM_FLIP_H != 0)
	_check("a flipped TOP (the floor) keeps its mirroring through the shimmer  [alt %d]"
			% layer.get_cell_alternative_tile(Vector2i(9, 0)),
		layer.get_cell_alternative_tile(Vector2i(9, 0)) & TileSetAtlasSource.TRANSFORM_FLIP_V != 0)
	_check("...and an UNflipped cell is not given a transform it never had  [alt %d]"
			% layer.get_cell_alternative_tile(Vector2i(0, 0)),
		layer.get_cell_alternative_tile(Vector2i(0, 0)) == 0)

	# Unlike Pond, painted water spawns no fish at all — see WaterLayer's own
	# class doc for why.
	_check("painted water spawns no fish",
		layer.get_children().filter(func(c): return c is Fish).is_empty())


func _check(msg: String, ok: bool) -> void:
	print("  %s  %s" % ["PASS" if ok else "FAIL", msg])
	if ok:
		_ok += 1
	else:
		_fail += 1
