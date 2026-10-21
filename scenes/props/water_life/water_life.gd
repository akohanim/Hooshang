extends Node2D
## Dressing inferred from painted Water, plus explicit WaterLife tile brushes.
## No collision or swim volume is created by a waterfall.
const SHEET := preload("res://ldtk/art/act2_water_life.png")
const ALGAE := preload("res://assets/props/water_life/algae.png")
const FISH := preload("res://scenes/props/Fish.tscn")
@export var automatic_algae := true
@export var automatic_fish := true
@export var automatic_waterfalls := true
var water: TileMapLayer
var algae: Array[Vector2i] = []
var falls: Array[Rect2] = []
var clock := 0.0
var _geometry: Array[TileMapLayer] = []
var _painted := {}

func _ready() -> void:
	water = get_parent() as TileMapLayer
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	# Sibling terrain must finish entering the tree before it is inspected.
	rebuild.call_deferred()

func solid_at(cell: Vector2i) -> bool:
	var point := water.to_global(water.map_to_local(cell))
	for layer in _geometry:
		var at := layer.local_to_map(layer.to_local(point))
		var data := layer.get_cell_tile_data(at)
		if data != null and layer.tile_set.get_physics_layers_count() > 0:
			if data.get_collision_polygons_count(0) > 0:
				return true
	return false

func rebuild() -> void:
	algae.clear()
	falls.clear()
	_painted.clear()
	_geometry.clear()
	for fish in $Fish.get_children():
		fish.free()
	if water == null or water.tile_set == null:
		return
	for node in water.get_parent().find_children("*", "TileMapLayer", true, false):
		if node != water and node.collision_enabled and node.tile_set != null:
			_geometry.append(node)
	var cells := water.get_used_cells()
	cells.sort_custom(func(a: Vector2i, b: Vector2i): return a.y < b.y or (a.y == b.y and a.x < b.x))
	for cell in cells:
		_painted[cell] = true
	for cell in cells:
		var below := cell + Vector2i.DOWN
		if not _painted.has(below):
			if automatic_algae and solid_at(below):
				algae.append(cell)
			elif automatic_waterfalls:
				_add_fall(cell, false)
		# One small school per broad horizontal lane, never in narrow shafts.
		if automatic_fish and cell.y % 3 == 1 and not _painted.has(cell + Vector2i.LEFT):
			var right := cell.x
			while _painted.has(Vector2i(right + 1, cell.y)):
				right += 1
			if right - cell.x >= 4:
				for i in mini(3, (right - cell.x + 1) / 5):
					_add_fish(Vector2i(cell.x + 2 + i * 5, cell.y))
	var marks := water.get_parent().get_node_or_null("WaterLife") as TileMapLayer
	if marks != null:
		marks.visible = false
		for mark in marks.get_used_cells():
			var cell := water.local_to_map(water.to_local(marks.to_global(marks.map_to_local(mark))))
			match marks.get_cell_atlas_coords(mark).x:
				0:
					if _painted.has(cell) and solid_at(cell + Vector2i.DOWN) and not algae.has(cell):
						algae.append(cell)
				1: _add_fish(cell)
				2: _add_fall(cell, true)
	set_process(not algae.is_empty() or not falls.is_empty())
	queue_redraw()

func _add_fish(cell: Vector2i) -> void:
	if not _painted.has(cell):
		return
	var left := cell.x
	var right := cell.x
	while _painted.has(Vector2i(left - 1, cell.y)) and not solid_at(Vector2i(left - 1, cell.y)):
		left -= 1
	while _painted.has(Vector2i(right + 1, cell.y)) and not solid_at(Vector2i(right + 1, cell.y)):
		right += 1
	if right - left < 2 or solid_at(cell):
		return
	var fish := FISH.instantiate() as Fish
	fish.artwork = preload("res://assets/props/water_life/koi.png")
	var low := left * 8.0 + 7.0
	var high := (right + 1) * 8.0 - 7.0
	fish.position = Vector2(clampf(cell.x * 8.0 + 4.0, low, high), cell.y * 8.0 + 4.0)
	fish.patrol_width = maxf(0.0, minf(fish.position.x - low, high - fish.position.x) * 2.0)
	fish.speed = 6.0 + WaterLayer._hash01(cell.x, cell.y) * 6.0
	fish.start_dir = -1 if cell.x % 2 else 1
	$Fish.add_child(fish)

func _add_fall(cell: Vector2i, explicit: bool) -> void:
	if not _painted.has(cell) or _painted.has(cell + Vector2i.DOWN) or solid_at(cell + Vector2i.DOWN):
		return
	# Imported rooms use their actual height; isolated fixtures use painted bounds.
	var bottom := water.get_used_rect().end.y
	if water.get_parent() is LDTKLevel:
		bottom = water.get_parent().size.y / 8
	elif explicit:
		bottom = maxi(bottom, cell.y + 32)
	for y in range(cell.y + 1, bottom):
		var probe := Vector2i(cell.x, y)
		var blocked := solid_at(probe)
		if _painted.has(probe) or blocked:
			if y > cell.y + 1:
				var rect := Rect2(cell.x * 8, (cell.y + 1) * 8, 8, (y - cell.y - 1) * 8)
				if not falls.has(rect):
					falls.append(rect)
			return

func _process(delta: float) -> void:
	clock += delta
	queue_redraw()

func _draw() -> void:
	for cell in algae:
		var frame := int(clock * 6.0 + WaterLayer._hash01(cell.x, cell.y) * 8) % 8
		var height := 16 if _painted.has(cell + Vector2i.UP) else 8
		draw_texture_rect_region(ALGAE, Rect2(Vector2(cell) * 8 - Vector2(0,height-8), Vector2(8,height)), Rect2(0,frame*16+16-height,8,height))
	for fall in falls:
		for y in range(0, int(fall.size.y), 8):
			var frame := (int(clock * 12) + y / 8 + int(WaterLayer._hash01(int(fall.position.x), 7) * 8)) % 8
			draw_texture_rect_region(SHEET, Rect2(fall.position + Vector2(0,y),Vector2(8,8)), Rect2(24,frame*8,8,8))
		var frame := int(clock * 10) % 8
		draw_texture_rect_region(SHEET, Rect2(fall.position + Vector2(0,fall.size.y-4),Vector2(8,8)), Rect2(32,frame*8,8,8))
