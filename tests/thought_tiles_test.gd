extends Node2D
## Paintable thought-hazard tiles: the ThoughtHazards IntGrid layer imports as a
## pass-through TileMapLayer whose tile overlap kills the player.

var _ok := 0
var _fail := 0
var _world: LdtkWorld


func _ready() -> void:
	SaveGame.slot = -1
	_world = preload("res://ldtk/Act1World.tscn").instantiate()
	LdtkWorld.debug_start_room = "TEST"
	add_child(_world)
	_run.call_deferred()


func _run() -> void:
	await get_tree().process_frame
	await get_tree().process_frame

	var room := _world.current_room
	_check("started in TEST room", room != null and room.name == "TEST")

	# --- layer exists and collision is off --------------------------------
	var layer := room.get_node_or_null("ThoughtHazards") as TileMapLayer
	_check("ThoughtHazards layer exists in room", layer != null)
	if layer != null:
		_check("collision disabled (pass-through)", not layer.collision_enabled)

	# --- the world cached it ----------------------------------------------
	_check("ldtk_world cached the thought layer", _world._thought_layer == layer)

	# --- tile overlap check works -----------------------------------------
	# Paint a thought tile at the player's position and verify _in_thought_tile()
	# returns true. Do this on the layer in memory — no LDtk round trip needed.
	if layer != null:
		var player := _world.player
		var cell := layer.local_to_map(layer.to_local(player.global_position))

		# Before painting: no tile → not in hazard
		_check("empty cell is not a hazard",
			layer.get_cell_source_id(cell) == -1)
		_check("_in_thought_tile() is false on empty cell",
			not _world._in_thought_tile())

		# Paint a tile (source_id 0 = fill tile at atlas 0,0)
		var source_id := -1
		for i in layer.tile_set.get_source_count():
			source_id = layer.tile_set.get_source_id(i)
			break
		if source_id != -1:
			layer.set_cell(cell, source_id, Vector2i(0, 0))
			_check("painted tile is occupied",
				layer.get_cell_source_id(cell) != -1)
			_check("_in_thought_tile() detects the painted cell",
				_world._in_thought_tile())

			# Verify it actually kills the player on the next physics tick
			var alive_before := player.state != Player.State.DEAD
			_check("player alive before stepping into tile", alive_before)

			# Simulate a physics tick
			_world._physics_process(1.0 / 60.0)
			_check("player DEAD after stepping into thought tile",
				player.state == Player.State.DEAD)

			# Clean up
			layer.erase_cell(cell)
		else:
			_check("tile source exists on the layer", false)

	_finish()


func _check(what: String, ok: bool) -> void:
	if ok:
		_ok += 1
		print("  PASS  %s" % what)
	else:
		_fail += 1
		print("  FAIL  %s" % what)


func _finish() -> void:
	var total := _ok + _fail
	if _fail == 0:
		print("THOUGHT TILES TEST: ALL PASS  (%d checks)" % total)
	else:
		print("THOUGHT TILES TEST: %d FAILED out of %d" % [_fail, total])
	get_tree().quit(1 if _fail > 0 else 0)
