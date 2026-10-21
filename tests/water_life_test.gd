extends Node2D
var failures := 0
var layer: WaterLayer
var terrain: TileMapLayer
var effects: Node2D
func check(label: String, ok: bool) -> void:
	print("%s %s" % ["PASS" if ok else "FAIL", label])
	if not ok: failures += 1
func _ready() -> void:
	var ts := TileSet.new()
	ts.tile_size = Vector2i(8,8)
	var atlas := TileSetAtlasSource.new()
	atlas.texture = preload("res://ldtk/art/act2_water_tiles.png")
	atlas.texture_region_size = Vector2i(8,8)
	for y in 3:
		for x in 5: atlas.create_tile(Vector2i(x,y))
	ts.add_source(atlas,0)
	layer = WaterLayer.new()
	layer.name = "Water"
	layer.tile_set = ts
	layer.collision_enabled = false
	# Two separated pools, the upper one suspended over the lower one.
	for y in range(2,5):
		for x in range(2,10):layer.set_cell(Vector2i(x,y),0,Vector2i.ZERO)
	for y in range(10,15):
		for x in range(1,15):layer.set_cell(Vector2i(x,y),0,Vector2i.ZERO)
	terrain = TileMapLayer.new()
	terrain.tile_set = ts.duplicate(true)
	terrain.tile_set.add_physics_layer()
	var solid: TileData = terrain.tile_set.get_source(0).get_tile_data(Vector2i.ZERO,0)
	solid.add_collision_polygon(0)
	solid.set_collision_polygon_points(0,0,PackedVector2Array([Vector2(-4,-4),Vector2(4,-4),Vector2(4,4),Vector2(-4,4)]))
	for x in range(1,15):terrain.set_cell(Vector2i(x,15),0,Vector2i.ZERO)
	add_child(terrain)
	add_child(layer)
	await get_tree().process_frame
	effects = layer.get_node("WaterLifeEffects")
	effects.rebuild()
	check("algae rooted along submerged floor", effects.algae.size() == 14)
	check("suspended water pours into lower pool", effects.falls.size() == 8)
	check("falls end at receiving surface", effects.falls[0].end.y == 80)
	check("painted pools contain multiple fish", effects.get_node("Fish").get_child_count() >= 5)
	var moved := false
	for fish in effects.get_node("Fish").get_children():
		var start: Vector2 = fish.position
		for tick in 300:
			fish._process(0.1)
			if not layer.has_water_at(fish.to_global(Vector2(-6,0))) or not layer.has_water_at(fish.to_global(Vector2(6,0))):
				check("fish body stays in its own water lane", false)
				break
			if fish.position.distance_to(start) > 1.0: moved = true
	check("fish actually travel while remaining contained", moved)
	# An intervening ledge catches the stream, no waterfall through masonry.
	terrain.set_cell(Vector2i(3,7),0,Vector2i.ZERO)
	effects.rebuild()
	var caught := false
	for fall in effects.falls:
		if fall.position.x == 24: caught = fall.end.y == 56
	check("intervening solid catches falling water",caught)
	terrain.set_cell(Vector2i(3,5),0,Vector2i.ZERO)
	effects.rebuild()
	check("supported upper water does not pour through floor",effects.falls.size() == 7)
	var marks := TileMapLayer.new()
	marks.name = "WaterLife"
	marks.tile_set = ts
	marks.collision_enabled = false
	marks.set_cell(Vector2i(12,12),0,Vector2i(1,0))
	add_child(marks)
	var before: int = effects.get_node("Fish").get_child_count()
	effects.rebuild()
	check("Fish brush adds another fish",effects.get_node("Fish").get_child_count()==before+1)
	layer.erase_cell(Vector2i(1,14))
	effects.rebuild()
	check("erasing water removes its algae",not effects.algae.has(Vector2i(1,14)))
	var count: int = effects.get_node("Fish").get_child_count()
	effects.rebuild()
	check("rebuilding never duplicates fish",effects.get_node("Fish").get_child_count()==count)
	effects.automatic_algae = false
	effects.automatic_fish = false
	effects.automatic_waterfalls = false
	marks.set_cell(Vector2i(12,14),0,Vector2i(0,0))
	marks.set_cell(Vector2i(4,4),0,Vector2i(2,0))
	effects.rebuild()
	check("Algae brush independently places a rooted tuft", effects.algae == [Vector2i(12,14)])
	check("Outlet brush independently creates a waterfall", effects.falls.size()==1 and effects.falls[0].position.x==32)
	check("manual fish works without automatic schools", effects.get_node("Fish").get_child_count()==1)
	check("authoring markers are hidden during play", not marks.visible)
	print("WATER LIFE: %d failures" % failures)
	get_tree().quit(0 if failures==0 else 1)
