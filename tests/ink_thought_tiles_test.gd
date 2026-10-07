extends Node
## Imported ink brush coverage, animation atlas and full-body contact contract.
var failures := 0
func check(ok: bool, label: String) -> void:
	print("PASS " if ok else "FAIL ", label)
	if not ok: failures += 1
func _ready() -> void:
	SaveGame.slot = -1
	LdtkWorld.debug_start_room = "Act_2_Level_10"
	Screen.load_scene("res://ldtk/Act2World.tscn")
	for i in 8: await get_tree().process_frame
	var world := Screen.current as LdtkWorld
	var player := world.player
	world.set_physics_process(false)
	player.set_physics_process(false)
	for room in world.rooms:
		var number := int(str(room.name).get_slice("_", 3))
		var layer := room.get_node_or_null("InkThoughtHazards") as TileMapLayer
		check(layer != null, "%s imports the brush" % room.name)
		if layer == null: continue
		check(not layer.collision_enabled, "%s ink is pass-through" % room.name)
		if number < 3:
			check(layer.get_used_cells().is_empty(), "%s retains its original hazards" % room.name)
		else:
			check(layer is ThoughtHazardLayer and (number == 8 or not layer.get_used_cells().is_empty()), "%s has the animated ink brush" % room.name)
			for child in room.get_node("Entities").get_children():
				check(not child is ConeSpikes, "%s contains no spike entity: %s" % [room.name, child.name])
	var layer := world._ink_thought_layer
	var source_id := layer.get_cell_source_id(layer.get_used_cells()[0])
	var atlas := layer.tile_set.get_source(source_id) as TileSetAtlasSource
	check(atlas.texture.resource_path.ends_with("act2_ink_thought_tiles.png"), "new artwork is imported")
	for mask in 64:
		for frame in 6:
			check(atlas.has_tile(Vector2i(mask, frame)), "atlas mask %d frame %d exists" % [mask, frame])
	var sampled_cell: Vector2i = layer.get_used_cells()[0]
	var original_column := layer.get_cell_atlas_coords(sampled_cell).x
	var seen := {}
	var contour_stable := true
	layer.set_process(false)
	for tick in 200:
		layer._process(1.0 / 60.0)
		var coords := layer.get_cell_atlas_coords(sampled_cell)
		seen[coords.y] = true
		contour_stable = contour_stable and coords.x == original_column
	check(contour_stable, "animation preserves connected contour")
	check(seen.size() == 6, "ink cell displays all six animation frames")
	# Paint a fresh isolated cell high above geometry; test all four contacts.
	var cell := Vector2i(12, 8)
	layer.set_cell(cell, source_id, Vector2i.ZERO)
	var origin := layer.to_global(layer.map_to_local(cell))
	var probes := [Vector2(0,-9), Vector2(0,9), Vector2(-7.5,0), Vector2(7.5,0)]
	for delta: Vector2 in probes:
		player.global_position = origin + delta
		check(world._in_thought_tile(), "body edge contact kills even with centre outside: %s" % delta)
	for delta: Vector2 in [Vector2(0,-10), Vector2(0,10), Vector2(-8.5,0), Vector2(8.5,0)]:
		player.global_position = origin + delta
		check(not world._in_thought_tile(), "exact boundary without overlap is safe: %s" % delta)
	player.global_position = origin
	player._mushroom_power_timer = 1.0
	world._physics_process(1.0/60.0)
	check(player.state != Player.State.DEAD, "thought immunity protects against ink")
	player._mushroom_power_timer = 0.0
	world._physics_process(1.0/60.0)
	check(player.state == Player.State.DEAD, "unprotected contact kills on physics tick")
	print("INK_THOUGHT_TILES: %d failures" % failures)
	get_tree().quit(1 if failures else 0)
