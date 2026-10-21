extends Node
var layer: WaterLayer
var terrain: TileMapLayer
func _ready() -> void:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(320,180)
	viewport.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(viewport)
	var bg := ColorRect.new()
	bg.color = Color("254958")
	bg.size = Vector2(320,180)
	viewport.add_child(bg)
	var scene := Node2D.new()
	scene.position = Vector2(88,12)
	viewport.add_child(scene)
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
	scene.add_child(terrain)
	scene.add_child(layer)

	terrain.visible = false
	var floor_art := ColorRect.new()
	floor_art.position = Vector2(8,120)
	floor_art.size = Vector2(112,16)
	floor_art.color = Color("a38957")
	scene.add_child(floor_art)
	await get_tree().process_frame
	var effects := layer.get_node("WaterLifeEffects")
	effects.set_process(false)
	for fish in effects.get_node("Fish").get_children(): fish.set_process(false)
	for i in 16:
		effects._process(0.12)
		for fish in effects.get_node("Fish").get_children(): fish._process(0.12)
		await get_tree().process_frame
		await RenderingServer.frame_post_draw
		var img := viewport.get_texture().get_image()
		img.resize(960,540,Image.INTERPOLATE_NEAREST)
		img.save_png("res://artifacts/water-life-%d.png" % i)
	print("Water preview captured")
	get_tree().quit()
