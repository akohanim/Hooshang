extends Control
## High-resolution, quiet thumb guides; the game stays on its 320x180 surface.
const INK := Color(1, 0.86, 0.60, 0.58)
const PANEL := Color(0.045, 0.04, 0.065, 0.38)

func _draw() -> void:
	var touch := get_parent()
	var center: Vector2 = touch.stick_origin
	draw_circle(center, touch.stick_radius, PANEL)
	draw_arc(center, touch.stick_radius, 0, TAU, 64, INK, 2.0, true)
	draw_circle(touch.stick_position, 26, Color(1, 0.86, 0.60, 0.28))
	for direction in [Vector2.LEFT, Vector2.RIGHT, Vector2.UP, Vector2.DOWN]:
		var tip: Vector2 = center + direction * 62
		var base: Vector2 = center + direction * 52
		var side: Vector2 = direction.orthogonal() * 6
		draw_polyline(PackedVector2Array([base + side, tip, base - side]), INK, 2, true)
	_text(Vector2(104, 672), "MOVE / CLIMB", 22)
	draw_circle(Vector2(1100, 548), 74, PANEL)
	draw_arc(Vector2(1100, 548), 74, 0, TAU, 64, INK, 2, true)
	_text(Vector2(1066, 547), "TAP", 26)
	_text(Vector2(1064, 580), "JUMP", 22)
	_text(Vector2(944, 672), "SWIPE TO DASH", 22)
	_text(Vector2(968, 642), "HOLD TO JUMP HIGHER", 18)
	draw_style_box(_button_style(), touch.PAUSE_RECT)
	draw_line(Vector2(1176, 58), Vector2(1176, 94), INK, 6)
	draw_line(Vector2(1192, 58), Vector2(1192, 94), INK, 6)
	draw_style_box(_button_style(), touch.GLOW_RECT)
	_text(Vector2(1000, 76), "GLOW", 23)
	_text(Vector2(1000, 104), "1 LEMON", 17)
	if touch.action_finger >= 0:
		draw_line(touch.action_origin, touch.action_position, INK, 4, true)
		draw_circle(touch.action_position, 10, INK)

func _text(at: Vector2, text: String, font_size: int) -> void:
	draw_string(ThemeDB.fallback_font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, INK)

func _button_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = PANEL
	style.border_color = INK
	style.set_border_width_all(1)
	style.set_corner_radius_all(14)
	return style
