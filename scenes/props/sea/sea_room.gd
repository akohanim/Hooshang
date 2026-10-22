class_name SeaRoom
extends Node2D
## One Act III room's own geometry, water and look — added to every `Act3_`
## level at import (scripts/act3/sea_import.gd), built here at runtime.
##
## Collision authority is the semantic `Collision` IntGrid (imported as the
## hidden `Collision-values` layer): 1 solid, 2 one-way, 4 water. The visible
## terrain is the `Collisions` auto-layer (assets/act3/terrain.png) and never
## collides — tools/build_act3_world.py writes both from one drawing, the same
## split the prison uses (scenes/props/prison/prison_room.gd), and for the same
## reason: an invisible ceiling over an open shore needs a solid cell with no
## art, which a single painted layer cannot express.
##
## Everything visible is recoloured by WORLD DEPTH (scripts/act3/sea_palette.gd):
## the backdrop, the terrain, the water and the planks.

const BACKDROP_SHADER := preload("res://assets/shaders/act3_backdrop.gdshader")
const TINT_SHADER := preload("res://assets/shaders/act3_depth_tint.gdshader")
const WATER_SHADER := preload("res://assets/shaders/act3_water.gdshader")

## Pins the room to one depth (>= 0) instead of its world y — the epilogue
## rooms, which do not belong to the sea's ramp. Set by SeaWorld from the room
## table in tools/build_act3_world.py (level field `FixedDepth`).
var fixed_depth := -1.0
## World y of the shore's horizon for the backdrop, < 0 for none.
var horizon_y := -1.0
## "" for the sea; "sunrise" for the real sea (natural colour), "dawn" for the
## office at dawn. From resources/levels/act3_rooms.json via the import.
var mode := ""
var grid: TileMapLayer
var size_cells := Vector2i.ZERO
var geometry: TileMapLayer
var water: ColorRect
var backdrop: ColorRect
var _planks: Array[Vector2i] = []


func _ready() -> void:
	var level := get_parent()
	for visual in level.find_children("*", "TileMapLayer", true, false):
		(visual as TileMapLayer).collision_enabled = false
	grid = level.get_node_or_null("Collision-values") as TileMapLayer
	size_cells = Vector2i(level.size) / 8 if "size" in level else Vector2i(40, 24)
	fixed_depth = float(level.get_meta("fixed_depth", -1.0))
	horizon_y = float(level.get_meta("horizon", -1.0))
	mode = str(level.get_meta("mode", ""))
	if horizon_y >= 0.0:
		horizon_y += level.global_position.y
	_shallow_chase_pits()
	_build_physics()
	_build_backdrop()
	_tint_terrain(level.get_node_or_null("Collisions") as TileMapLayer)
	_tint_crumbling(level)
	_build_water()
	z_index = 0
	queue_redraw()


## The two chase ditches used to be 32/40px deep in a 24px-wide slot: the
## player could fall below the tiger's trail and wait there indefinitely.
## Keep an 8px depression, with matching semantic and visible terrain. This
## also repairs previously packed worlds without an LDtk/editor cache rebuild.
func _shallow_chase_pits() -> void:
	var patches := {
		"Act3_Level_29": Rect2i(20, 17, 3, 3),
		"Act3_Level_30": Rect2i(22, 17, 3, 4),
	}
	var name := str(get_parent().name)
	if grid == null or not patches.has(name):
		return
	var patch: Rect2i = patches[name]
	var terrain := get_parent().get_node_or_null("Collisions") as TileMapLayer
	var semantic_source := grid.get_cell_source_id(Vector2i(patch.position.x - 1, patch.position.y))
	if semantic_source == -1:
		return
	var changed := false
	for y in range(patch.position.y, patch.end.y):
		for x in range(patch.position.x, patch.end.x):
			var cell := Vector2i(x, y)
			if value_at(cell) == 0:
				grid.set_cell(cell, semantic_source, Vector2i.ZERO)
				changed = true
	if not changed or terrain == null:
		return
	var source := terrain.get_cell_source_id(Vector2i(patch.position.x - 1, patch.position.y))
	if source == -1:
		return
	# The existing connected Grass atlas has 47 normalized masks, in sorted
	# order (tools/act3_connected_terrain.py). Reconnect the filled cells AND
	# their neighbors, removing the former vertical lips and bottom grass line.
	var masks: Array[int] = []
	for raw in 256:
		var normalized := _terrain_mask(raw)
		if normalized not in masks:
			masks.append(normalized)
	masks.sort()
	var neighbors := [Vector2i.UP, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT,
		Vector2i(-1, -1), Vector2i(1, -1), Vector2i(1, 1), Vector2i(-1, 1)]
	for y in range(patch.position.y - 1, patch.end.y + 1):
		for x in range(patch.position.x - 1, patch.end.x + 1):
			var cell := Vector2i(x, y)
			if value_at(cell) != 1:
				continue
			var mask := 0
			for i in neighbors.size():
				if value_at(cell + neighbors[i]) == 1:
					mask |= 1 << i
			var tile := 32 + 47 + masks.find(_terrain_mask(mask))
			terrain.set_cell(cell, source, Vector2i(tile % 8, tile / 8))


func _terrain_mask(raw: int) -> int:
	var result := raw
	for corner in [[4, 0, 3], [5, 0, 1], [6, 1, 2], [7, 2, 3]]:
		if raw & (1 << corner[1]) == 0 or raw & (1 << corner[2]) == 0:
			result &= ~(1 << corner[0])
	return result


func value_at(cell: Vector2i) -> int:
	if grid == null or grid.get_cell_source_id(cell) == -1:
		return 0
	return grid.get_cell_atlas_coords(cell).x + 1


func cell_at(world_pos: Vector2) -> Vector2i:
	return Vector2i(((world_pos - get_parent().global_position) / 8.0).floor())


func has_water_at(world_pos: Vector2) -> bool:
	return value_at(cell_at(world_pos)) == 4


## Waterline above `world_pos`: walk up the column to the first non-water cell.
## INF when the point is not in water.
##
## Only AIR above the water is a surface. Rock above it is a ceiling — he is
## submerged under it, with nothing to float up to and no breath to take — so
## that, and a column running on into the room overhead, both report -INF
## ("deep"). Treating the underside of every overhang as a waterline is what
## had buoyancy springing him toward cave roofs and dragging every dive down to
## two-thirds speed.
func surface_y_at(world_pos: Vector2) -> float:
	var cell := cell_at(world_pos)
	if value_at(cell) != 4:
		return INF
	while cell.y > 0 and value_at(cell + Vector2i.UP) == 4:
		cell.y -= 1
	if cell.y == 0 or value_at(cell + Vector2i.UP) in [1, 2]:
		return -INF
	return get_parent().global_position.y + cell.y * 8.0


func _build_physics() -> void:
	var set := TileSet.new()
	set.tile_size = Vector2i(8, 8)
	set.add_physics_layer()
	set.set_physics_layer_collision_layer(0, 1)
	var atlas := TileSetAtlasSource.new()
	atlas.texture = ImageTexture.create_from_image(Image.create(16, 8, false, Image.FORMAT_RGBA8))
	atlas.texture_region_size = Vector2i(8, 8)
	set.add_source(atlas, 0)
	for v in [0, 1]:
		atlas.create_tile(Vector2i(v, 0))
		var td := atlas.get_tile_data(Vector2i(v, 0), 0)
		td.set_collision_polygons_count(0, 1)
		td.set_collision_polygon_points(0, 0, PackedVector2Array([
			Vector2(-4, -4), Vector2(4, -4), Vector2(4, 4), Vector2(-4, 4)]))
		td.set_collision_polygon_one_way(0, 0, v == 1)
	geometry = TileMapLayer.new()
	geometry.name = "Physics"
	geometry.tile_set = set
	geometry.visible = false
	add_child(geometry)
	if grid == null:
		return
	for cell in grid.get_used_cells():
		var value := value_at(cell)
		if value in [1, 2]:
			geometry.set_cell(cell, 0, Vector2i(value - 1, 0))
		if value == 2:
			_planks.append(cell)


func _material(shader: Shader) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = shader
	SeaPalette.bind(m)
	m.set_shader_parameter("fixed_depth", fixed_depth)
	return m


func _build_backdrop() -> void:
	# A 'land' room (the way home) hangs its own painting instead of the sea:
	# planes in depth where it has them (LandBackdrop), else one flat picture.
	if LandBackdrop.exists_for(str(get_parent().name)):
		var planes := LandBackdrop.new()
		planes.name = "LandBackdrop"
		add_child(planes)
		if planes.build(str(get_parent().name)):
			return
		planes.free()
	var painted := str(get_parent().get_meta("backdrop", ""))
	if painted != "" and ResourceLoader.exists(painted):
		var art := Sprite2D.new()
		art.name = "LandBackdrop"
		art.texture = load(painted)
		art.centered = false
		art.z_as_relative = false
		art.z_index = -8
		art.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		add_child(art)
		return
	backdrop = ColorRect.new()
	backdrop.name = "SeaBackdrop"
	backdrop.size = Vector2(size_cells * 8)
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	backdrop.z_as_relative = false
	backdrop.z_index = -8
	var m := _material(BACKDROP_SHADER)
	m.set_shader_parameter("horizon_y", horizon_y)
	var origin: Vector2 = get_parent().global_position
	m.set_shader_parameter("room_rect", Vector4(origin.x, origin.y, size_cells.x * 8, size_cells.y * 8))
	m.set_shader_parameter("sunrise", 1.0 if mode == "sunrise" else 0.0)
	m.set_shader_parameter("dawn", 1.0 if mode == "dawn" else 0.0)
	backdrop.material = m
	add_child(backdrop)


func _tint_terrain(layer: TileMapLayer) -> void:
	if layer == null:
		return
	layer.material = _material(TINT_SHADER)
	if mode == "sunrise":
		(layer.material as ShaderMaterial).set_shader_parameter("fixed_fill", Vector3(0.78, 0.6, 0.38))
		(layer.material as ShaderMaterial).set_shader_parameter("fixed_line", Vector3(1.0, 0.9, 0.7))
	var level := get_parent()
	if level.has_meta("terrain_fill"):
		(layer.material as ShaderMaterial).set_shader_parameter("fixed_fill", level.get_meta("terrain_fill"))
		(layer.material as ShaderMaterial).set_shader_parameter("fixed_line", level.get_meta("terrain_line"))
	var planes := get_node_or_null("LandBackdrop") as LandBackdrop
	if planes != null:
		planes.shade_earth(layer.material as ShaderMaterial)
	for extra in ["Background", "Foreground"]:
		var other := get_parent().get_node_or_null(extra) as TileMapLayer
		if other != null:
			other.material = _material(TINT_SHADER)


## Act III's crumbling panels are drawn in the act's black and white (white
## chunks, black cracks): recolour them by depth like the terrain they sit in.
func _tint_crumbling(level: Node) -> void:
	for node in level.find_children("*", "", true, false):
		if node is CrumblingPlatform:
			var vis := node.get("_visual") as CanvasItem
			if vis != null:
				var m := _material(TINT_SHADER)
				m.set_shader_parameter("grain", 0.0)
				vis.material = m


func _build_water() -> void:
	if grid == null:
		return
	# Red = water, green = solid: the shader draws a waterline only where AIR
	# sits on the water, never along the underside of a ceiling.
	var img := Image.create(size_cells.x, size_cells.y, false, Image.FORMAT_RG8)
	var any := false
	for cell in grid.get_used_cells():
		if cell.x < 0 or cell.y < 0 or cell.x >= size_cells.x or cell.y >= size_cells.y:
			continue
		var v := value_at(cell)
		if v == 4:
			img.set_pixel(cell.x, cell.y, Color(1, 0, 0))
			any = true
		elif v in [1, 2]:
			img.set_pixel(cell.x, cell.y, Color(0, 1, 0))
	if not any:
		return
	water = ColorRect.new()
	water.name = "SeaWater"
	water.size = Vector2(size_cells * 8)
	water.mouse_filter = Control.MOUSE_FILTER_IGNORE
	water.z_as_relative = false
	water.z_index = 6
	var m := _material(WATER_SHADER)
	m.set_shader_parameter("mask", ImageTexture.create_from_image(img))
	m.set_shader_parameter("origin", get_parent().global_position)
	m.set_shader_parameter("cells", Vector2(size_cells))
	water.material = m
	add_child(water)


## The one-way planks: a rail along the top with posts every other cell, the
## pier's language, in the room's line colour.
func _draw() -> void:
	if _planks.is_empty():
		return
	var y_world: float = get_parent().global_position.y
	for cell in _planks:
		var at := Vector2(cell * 8)
		var line := SeaPalette.at(SeaPalette.LINE, y_world + at.y) if fixed_depth < 0.0 \
			else SeaPalette.at(SeaPalette.LINE, fixed_depth * SeaPalette.BOTTOM_Y)
		var fill := SeaPalette.at(SeaPalette.FILL, y_world + at.y) if fixed_depth < 0.0 \
			else SeaPalette.at(SeaPalette.FILL, fixed_depth * SeaPalette.BOTTOM_Y)
		draw_rect(Rect2(at, Vector2(8, 3)), fill)
		draw_rect(Rect2(at, Vector2(8, 1)), line)
		draw_rect(Rect2(at + Vector2(0, 2), Vector2(8, 1)), line.darkened(0.35))
		if (cell.x % 2) == 0:
			draw_rect(Rect2(at + Vector2(3, 3), Vector2(1, 3)), line.darkened(0.45))
