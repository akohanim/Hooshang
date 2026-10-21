extends Control
## The Explore Chapters WORLD MAP: one Act's rooms laid out where LDtk puts
## them, drawn from the menu catalog (`tools/build_menu_catalog.py`) so the title
## screen never has to instance a world to show one. Authored in the menu's
## 1280x720 space, like everything else on it.
##
## BAKED, NOT DRAWN PER CELL. The whole Act's terrain goes into one texture, a
## texel per 8px cell, and is drawn as a single quad — a draw_rect per cell is
## tens of thousands of calls a frame while the camera glides. The selected room
## is that same texture again, cropped to its rect and drawn at full brightness
## over a dimmed world, which is what makes it light up rather than just gain a
## border.
##
## THE CAMERA FOLLOWS THE LIST, NOT THE CURSOR. A pick from the keyboard, the
## list or the overview inset glides the camera to the room; a room picked by
## HOVERING the map is selected where it stands. A map that pans to whatever is
## under a resting cursor slides a different room under it, which selects that
## one, which pans again.
##
## INPUT ARRIVES FORWARDED. The menu reads every event in `_input` with its
## Controls set to MOUSE_FILTER_IGNORE, so it hands this node mouse events in
## local coordinates (`mouse()`) rather than this node taking gui input.

## The pointer moved onto a room on the map.
signal room_hovered(index: int)
## A click (press and release, no drag) on a room on the map.
signal room_pressed(index: int)
## A click on the overview inset: the room under it, or the nearest one.
signal room_picked(index: int)

const CELL := 8

## How much of the panel the focused room should fill, width and height. Lower
## shows more of its neighbours; higher reads its terrain better.
@export var frame_share := Vector2(0.42, 0.5)
## The farthest the camera pulls back for a big room, in menu px per world px —
## before the room is clamped to fit, so a very long room still fits whole.
@export var min_zoom := 0.5
## The most of the panel a room may take when it has to be shrunk to fit.
@export var fit_share := Vector2(0.92, 0.82)
## How quickly the camera closes on its target, per second. Higher snaps.
@export var glide := 11.0
## How far a press must travel before it is a drag rather than a click.
@export var drag_threshold := 6.0
## Zoom per wheel notch, and how far the wheel may push it either way.
@export var zoom_step := 1.2
@export var zoom_range := Vector2(0.35, 3.0)
## The overview inset's largest size; it keeps the world's aspect inside it.
@export var inset_max := Vector2(196.0, 64.0)

var font: Font
var accent := Color("e6bb78")
var selected := -1
var hovered := -1

var _rooms: Array = []
var _rects: Array[Rect2] = []
var _bounds := Rect2()
var _texture: Texture2D
## One baked texture per Act, so flipping chapters back and forth bakes once.
var _baked := {}
var _center := Vector2.ZERO
var _zoom := 1.0
var _target_center := Vector2.ZERO
var _target_zoom := 1.0
## Where the camera sits relative to the selected room once dragged, and how far
## the wheel has zoomed it — both world-space, so they survive the glide.
var _pan := Vector2.ZERO
var _zoom_bias := 1.0
var _pressing := false
var _dragging := false
var _press_at := Vector2.ZERO
var _last_at := Vector2.ZERO


func _ready() -> void:
	clip_contents = true
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST


## Show Act `key`'s rooms, in play order (their index is their room number).
func set_world(key: int, rooms: Array, color: Color) -> void:
	_rooms = rooms
	accent = color
	_rects.clear()
	for room: Dictionary in rooms:
		_rects.append(Rect2(Vector2(room.pos[0], room.pos[1]), Vector2(room.size[0], room.size[1])))
	_bounds = _rects[0] if not _rects.is_empty() else Rect2()
	for rect in _rects:
		_bounds = _bounds.merge(rect)
	if not _baked.has(key):
		_baked[key] = _bake()
	_texture = _baked[key]
	selected = -1
	hovered = -1
	_pan = Vector2.ZERO
	_zoom_bias = 1.0
	_pressing = false
	_dragging = false
	queue_redraw()


## Select room `index`. `follow` moves the camera to it; a hover passes false.
func show_room(index: int, follow: bool) -> void:
	if index < 0 or index >= _rects.size():
		return
	selected = index
	if follow:
		_pan = Vector2.ZERO
		_aim()
	queue_redraw()


## Put the camera on its target now instead of gliding there — entering a
## chapter should open on its room, not fly in from the last one.
func snap() -> void:
	_center = _target_center
	_zoom = _target_zoom
	queue_redraw()


func set_hover(index: int) -> void:
	if hovered == index:
		return
	hovered = index
	queue_redraw()
	if index >= 0:
		room_hovered.emit(index)


## True from a press until its release, wherever the pointer has gone since, so
## the menu keeps forwarding a drag that leaves the panel.
func is_pressing() -> bool:
	return _pressing


func room_at(at: Vector2) -> int:
	var point := local_to_world(at)
	var best := -1
	for i in _rects.size():
		if _rects[i].has_point(point) and (best < 0 or _rects[i].get_area() < _rects[best].get_area()):
			best = i
	return best


func world_to_local(point: Vector2) -> Vector2:
	return (point - _center) * _zoom + size * 0.5


func local_to_world(at: Vector2) -> Vector2:
	return (at - size * 0.5) / _zoom + _center


## Where room `index` is drawn right now, in local coordinates.
func room_rect(index: int) -> Rect2:
	return Rect2(world_to_local(_rects[index].position), _rects[index].size * _zoom)


func mouse(event: InputEventMouse, at: Vector2) -> void:
	if _rects.is_empty():
		return
	if event is InputEventMouseButton:
		var button := event as InputEventMouseButton
		if button.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
			if button.pressed:
				var notches: float = button.factor if button.factor > 0.0 else 1.0
				_zoom_by(pow(zoom_step, notches * (1.0 if button.button_index == MOUSE_BUTTON_WHEEL_UP else -1.0)))
		elif button.button_index == MOUSE_BUTTON_LEFT:
			if button.pressed:
				_pressing = true
				_dragging = false
				_press_at = at
				_last_at = at
			elif _pressing:
				_pressing = false
				if not _dragging:
					if _inset_rect().has_point(at):
						room_picked.emit(_inset_pick(at))
					else:
						var index := room_at(at)
						if index >= 0:
							room_pressed.emit(index)
				_dragging = false
		return
	if _pressing and (_dragging or at.distance_to(_press_at) > drag_threshold):
		_dragging = true
		_move_camera(-(at - _last_at) / _zoom)
		_last_at = at
		set_hover(-1)
		return
	_last_at = at
	set_hover(-1 if _inset_rect().has_point(at) else room_at(at))


func _process(delta: float) -> void:
	if _rects.is_empty():
		return
	if _center == _target_center and _zoom == _target_zoom:
		return
	var t := 1.0 - exp(-glide * delta)
	_center = _center.lerp(_target_center, t)
	# Zoom eases in log space, so pulling back from 2x feels as quick as from 0.5x.
	_zoom = exp(lerpf(log(_zoom), log(_target_zoom), t))
	if _center.distance_to(_target_center) * _zoom < 0.25 and absf(_zoom / _target_zoom - 1.0) < 0.001:
		snap()
	queue_redraw()


## Frame the selected room: a share of the panel, never so far out that its
## terrain is unreadable, never so far in that a long room overflows.
func _aim() -> void:
	var rect := _rects[selected]
	var zoom := maxf(minf(frame_share.x * size.x / rect.size.x, frame_share.y * size.y / rect.size.y), min_zoom)
	zoom = minf(zoom, minf(fit_share.x * size.x / rect.size.x, fit_share.y * size.y / rect.size.y))
	_target_zoom = zoom * _zoom_bias
	_target_center = (rect.get_center() + _pan).clamp(_bounds.position, _bounds.end)


func _move_camera(by: Vector2) -> void:
	_pan += by
	_target_center = (_target_center + by).clamp(_bounds.position, _bounds.end)
	_center = (_center + by).clamp(_bounds.position, _bounds.end)
	queue_redraw()


func _zoom_by(factor: float) -> void:
	var bias := clampf(_zoom_bias * factor, zoom_range.x, zoom_range.y)
	_target_zoom *= bias / _zoom_bias
	_zoom_bias = bias
	queue_redraw()


## The Act's terrain, a texel per cell. Transparent where nothing is, so the
## room backings drawn under it show through.
func _bake() -> Texture2D:
	var width := int(_bounds.size.x) / CELL
	var height := int(_bounds.size.y) / CELL
	var data := PackedByteArray()
	data.resize(width * height * 4)
	# Keyed by the grid's character codes — see build_menu_catalog.py.
	var palette := {
		"#".unicode_at(0): accent,
		"=".unicode_at(0): accent.lerp(Color.WHITE, 0.45),
		"^".unicode_at(0): Color("d8706a"),
		"~".unicode_at(0): Color("5fb3d6"),
	}
	for i in _rooms.size():
		var cols := int(_rooms[i].size[0]) / CELL
		var origin := Vector2i((_rects[i].position - _bounds.position) / CELL)
		var grid: PackedByteArray = str(_rooms[i].grid).to_ascii_buffer()
		for j in grid.size():
			var color: Variant = palette.get(grid[j])
			if color == null:
				continue
			var at := ((origin.y + j / cols) * width + origin.x + j % cols) * 4
			data[at] = color.r8
			data[at + 1] = color.g8
			data[at + 2] = color.b8
			data[at + 3] = 255
	return ImageTexture.create_from_image(Image.create_from_data(width, height, false, Image.FORMAT_RGBA8, data))


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color("0e1824"))
	if _rects.is_empty():
		return
	_draw_grid()
	var panel := Rect2(Vector2.ZERO, size)
	for i in _rects.size():
		var rect := room_rect(i)
		if rect.intersects(panel):
			draw_rect(rect, Color(accent, 0.05))
			draw_rect(rect, Color(accent, 0.2), false, 1.0)
	if selected >= 0:
		var rect := room_rect(selected)
		for k in 3:
			draw_rect(rect.grow(3.0 + k * 4.0), Color(accent, 0.12 - k * 0.035), false, 4.0)
		draw_rect(rect, Color(accent, 0.13))
	# The world, dimmed; then the rooms that matter, at full strength over it.
	draw_texture_rect(_texture, Rect2(world_to_local(_bounds.position), _bounds.size * _zoom), false, Color(0.42, 0.45, 0.52))
	if hovered >= 0 and hovered != selected:
		_draw_room_terrain(hovered, Color(1, 1, 1, 0.75))
		draw_rect(room_rect(hovered), Color(accent, 0.6), false, 1.5)
	if selected >= 0:
		_draw_room_terrain(selected, Color.WHITE)
		draw_rect(room_rect(selected), accent, false, 2.0)
		_draw_markers(selected)
	_draw_numbers(panel)
	_draw_inset()
	draw_rect(panel, Color(accent, 0.3), false, 1.0)


func _draw_room_terrain(index: int, tint: Color) -> void:
	var source := Rect2((_rects[index].position - _bounds.position) / CELL, _rects[index].size / CELL)
	draw_texture_rect_region(_texture, room_rect(index), source, tint)


## Map-paper lines, anchored to the world so they slide with the camera, at the
## finest power-of-two spacing that stays at least 24 menu px apart.
func _draw_grid() -> void:
	var step := float(CELL)
	while step * _zoom < 24.0:
		step *= 2.0
	var top_left := local_to_world(Vector2.ZERO)
	var line := Color(0.8, 0.9, 1.0, 0.035)
	var x := floorf(top_left.x / step) * step
	while world_to_local(Vector2(x, 0)).x <= size.x:
		var at := world_to_local(Vector2(x, 0)).x
		draw_line(Vector2(at, 0), Vector2(at, size.y), line)
		x += step
	var y := floorf(top_left.y / step) * step
	while world_to_local(Vector2(0, y)).y <= size.y:
		var at := world_to_local(Vector2(0, y)).y
		draw_line(Vector2(0, at), Vector2(size.x, at), line)
		y += step


## Start (mint) and the way on (gold) for the selected room — the colours the
## eyebrow above the map names.
func _draw_markers(index: int) -> void:
	for marker: Array in _rooms[index].markers:
		var start: bool = marker[2] in ["PlayerStart", "PlayerSpawn", "Checkpoint"]
		var color := Color("8fdfbb") if start else Color("f6da86")
		var at := world_to_local(_rects[index].position + Vector2(marker[0], marker[1]))
		draw_circle(at, 7.0, Color(color, 0.18))
		draw_circle(at, 3.5, color)


## Each room's number in its corner, matching the list's "07 / 39". Skipped on a
## room drawn too small to hold one.
func _draw_numbers(panel: Rect2) -> void:
	if font == null:
		return
	for i in _rects.size():
		var rect := room_rect(i)
		if rect.size.x < 30.0 or rect.size.y < 22.0 or not rect.intersects(panel):
			continue
		var color := accent if i == selected else Color(0.78, 0.84, 0.92, 0.55)
		var text := "%02d" % (i + 1)
		# On a dark chip: a room's own corner is often solid ceiling in the accent
		# colour, and the number would vanish into it.
		var chip := Rect2(rect.position + Vector2(4, 4), Vector2(font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x + 8, 18))
		draw_rect(chip, Color(0.04, 0.07, 0.1, 0.85))
		draw_string(font, chip.position + Vector2(4, 14), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, color)


## The whole Act at a glance, bottom right: every room, the selected one lit, and
## the frame the camera is showing.
func _inset_rect() -> Rect2:
	var box := _bounds.size * _inset_scale() + Vector2(12, 12)
	return Rect2(size - box - Vector2(10, 10), box)


func _inset_scale() -> float:
	return minf(inset_max.x / _bounds.size.x, inset_max.y / _bounds.size.y)


func _inset_pick(at: Vector2) -> int:
	var box := _inset_rect()
	var point := (at - box.position - Vector2(6, 6)) / _inset_scale() + _bounds.position
	var best := 0
	var best_distance := INF
	for i in _rects.size():
		var distance := point.clamp(_rects[i].position, _rects[i].end).distance_to(point)
		if distance < best_distance:
			best = i
			best_distance = distance
	return best


func _draw_inset() -> void:
	var box := _inset_rect()
	var ratio := _inset_scale()
	var origin := box.position + Vector2(6, 6)
	draw_rect(box, Color(0.04, 0.07, 0.1, 0.92))
	draw_rect(box, Color(accent, 0.35), false, 1.0)
	for i in _rects.size():
		var rect := Rect2(origin + (_rects[i].position - _bounds.position) * ratio, (_rects[i].size * ratio).max(Vector2.ONE))
		draw_rect(rect, accent if i == selected else Color(accent, 0.38))
	var view := Rect2(origin + (local_to_world(Vector2.ZERO) - _bounds.position) * ratio, size / _zoom * ratio)
	view = view.intersection(box.grow(-1.0))
	if view.has_area():
		draw_rect(view, Color(1, 1, 1, 0.7), false, 1.0)
