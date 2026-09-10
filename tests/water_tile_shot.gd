extends Node
## Dev capture harness, not pass/fail (see room_shot.gd for the family):
## photograph a PAINTED Water shape — deliberately irregular (a rectangle
## with an L-shaped notch bitten out of one corner) so the edge/corner auto
## tiles actually get exercised, not just the top/fill an all-rectangle test
## would settle for. Runs WINDOWED — 2D does not rasterise headless.
##
## Usage: Godot --path . res://tests/water_tile_shot.tscn
## Shot lands in user://shots/water_tiles.png — the absolute path is printed.

const WATER_SHEET := preload("res://ldtk/art/act2_water_tiles.png")
const WATER_LAYER_SCRIPT := preload("res://scripts/ldtk_water_layer.gd")
const PLAYER := preload("res://scenes/characters/hooshang/Hooshang.tscn")
const VIEW_SIZE := Vector2i(320, 180)
const CELL := 8


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute("user://shots")
	var container := SubViewportContainer.new()
	add_child(container)
	var viewport := SubViewport.new()
	viewport.size = VIEW_SIZE
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	container.add_child(viewport)

	var scene := Node2D.new()
	viewport.add_child(scene)

	var checker := Node2D.new()
	scene.add_child(checker)
	for y in range(0, VIEW_SIZE.y, CELL):
		for x in range(0, VIEW_SIZE.x, CELL):
			var tile := ColorRect.new()
			tile.size = Vector2(CELL, CELL)
			tile.position = Vector2(x, y)
			tile.color = Color(0.85, 0.7, 0.4) if ((x / CELL + y / CELL) % 2 == 0) else Color(0.55, 0.4, 0.18)
			checker.add_child(tile)

	var tile_set := TileSet.new()
	tile_set.tile_size = Vector2i(CELL, CELL)
	var source := TileSetAtlasSource.new()
	source.texture = WATER_SHEET
	source.texture_region_size = Vector2i(CELL, CELL)
	for ty in 3:
		for tx in 5:
			source.create_tile(Vector2i(tx, ty))
	var source_id := tile_set.add_source(source)

	var layer := TileMapLayer.new()
	layer.tile_set = tile_set
	layer.position = Vector2(80.0, 40.0)

	# An 18x10 rectangle with an 8x6 notch bitten out of the top-right corner
	# — irregular on purpose, so top/left/corner all actually get exercised
	# on more than one flat rectangle's worth of edge.
	var painted := {}
	for gy in range(10):
		for gx in range(18):
			if gx >= 10 and gy < 6:
				continue  # the notch
			painted[Vector2i(gx, gy)] = true
	# There is no LDtk auto-rule running in this harness (that only happens
	# through the real importer), so fake its 4-rule outcome by hand: corner
	# if north AND west are both open, top if just north is open, left if
	# just west is open, fill otherwise — same pattern
	# tools/ldtk_add_act2_water_tiles.py wires into LDtk for real.
	for coord in painted:
		var north_open := not painted.has(coord + Vector2i(0, -1))
		var west_open := not painted.has(coord + Vector2i(-1, 0))
		var col := 0
		if north_open and west_open:
			col = 3
		elif north_open:
			col = 1
		elif west_open:
			col = 2
		layer.set_cell(coord, source_id, Vector2i(col, 0))
	# Script assigned BEFORE entering the tree, so add_child's own _ready()
	# call does the real depth-retarget/animation-registration pass — the
	# exact lifecycle a real LDtk import drives it through, no manual
	# re-invocation needed.
	layer.set_script(WATER_LAYER_SCRIPT)
	scene.add_child(layer)

	var player: Player = PLAYER.instantiate()
	scene.add_child(player)
	player.input_locked = true
	await get_tree().process_frame
	player.respawn(layer.position + Vector2(50.0, 30.0))
	# No LdtkWorld here to drive _in_water_tile()/enter_swim() (this harness
	# only cares about the ART), so nothing would ever stop him falling —
	# freeze() holds him exactly where placed, camera included.
	player.freeze()
	await _frames(90)
	await RenderingServer.frame_post_draw
	var img: Image = viewport.get_texture().get_image()
	img.resize(img.get_width() * 3, img.get_height() * 3, Image.INTERPOLATE_NEAREST)
	img.save_png("user://shots/water_tiles.png")
	print("saved %s  (player state %s, swimming %s)" % [
		ProjectSettings.globalize_path("user://shots/water_tiles.png"),
		player.state_name(), player.swimming()])
	get_tree().quit()


func _frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame
