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

		# --- per-cell randomized animation ---------------------------------
		#
		# Godot's own tile animation is ONE shared clock per atlas tile — every
		# painted cell plays the identical frame at the identical instant,
		# world-wide. scripts/ldtk_thought_hazard_layer.gd fixes this by driving
		# each cell on its OWN clock and OWN speed, hashed from its coordinate.
		# Prove three things: painted cells actually change frame over time (it
		# still animates), different cells read different frames at the same
		# tick (decorrelated — not secretly one shared clock with an offset that
		# happens to look different), and the SAME layout reproduces the SAME
		# frame sequence on a fresh scan (hashed, not RNG — a room has to look
		# the same way every time you walk into it).
		if source_id != -1:
			var coords: Array[Vector2i] = []
			for i in 8:
				coords.append(Vector2i(i, 0))

			var anim_a := _build_anim_layer(layer.tile_set, source_id, coords)
			add_child(anim_a)
			await get_tree().process_frame

			var frames_over_time: Array[Array] = []
			for tick in 200:  # ~3.3s of physics time — several cycles at any speed
				anim_a._process(1.0 / 60.0)
				var frames: Array[int] = []
				for c in coords:
					frames.append(anim_a.get_cell_atlas_coords(c).y)
				frames_over_time.append(frames)

			var seen: Dictionary = {}
			for frames in frames_over_time:
				seen[frames[0]] = true
			_check("thought tiles: a painted cell actually animates over time  "
					+ "[%d distinct frames seen]" % seen.size(), seen.size() > 1)

			var diverged := false
			for frames in frames_over_time:
				for f in frames:
					if f != frames[0]:
						diverged = true
						break
				if diverged:
					break
			_check("...and different cells read different frames at the same tick "
					+ "(decorrelated, not one shared clock)", diverged)

			# Reproducibility: a second, freshly scanned layer painted the SAME
			# way must land on the exact same frame per cell after the same
			# number of ticks — the phase comes from the cell coordinate, not
			# from anything that could differ between runs.
			var anim_b := _build_anim_layer(layer.tile_set, source_id, coords)
			add_child(anim_b)
			await get_tree().process_frame
			for tick in 200:
				anim_b._process(1.0 / 60.0)

			var reproduced := true
			for c in coords:
				if anim_a.get_cell_atlas_coords(c) != anim_b.get_cell_atlas_coords(c):
					reproduced = false
					break
			_check("...and the same layout reproduces the same frames on a fresh "
					+ "scan (hashed, not random)", reproduced)

			anim_a.queue_free()
			anim_b.queue_free()

	_finish()


## A standalone TileMapLayer, painted at `coords` with the fill tile and
## carrying the real animation driver — built fresh so its _ready() scans a
## known, controlled set of cells rather than whatever the TEST room happens
## to have painted at import time.
func _build_anim_layer(tile_set: TileSet, source_id: int,
		coords: Array[Vector2i]) -> TileMapLayer:
	var l := TileMapLayer.new()
	l.tile_set = tile_set
	for c in coords:
		l.set_cell(c, source_id, Vector2i(0, 0))
	l.set_script(load("res://scripts/ldtk_thought_hazard_layer.gd"))
	return l


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
