@tool
extends Node2D
## Native-resolution architectural pixel art. No collision: every playable edge
## belongs to LDtk. The self-lit, subdued wall leaves real lamps to light terrain.
@export var room_size := Vector2(640, 352)
var _clock := 0.0
var _frame := -1

func _ready() -> void:
	if not Engine.is_editor_hint():
		var moon := $Moon as OfficeMoon
		moon.configure(null, Rect2(68, 46, 16, 16))
		moon.set_window_openings([Rect2(48,24,62,56)])
		moon.set_pool_enabled(false)

func _process(delta: float) -> void:
	_clock += delta
	var frame := int(_clock * 12.0)
	if frame != _frame:
		_frame = frame
		queue_redraw()

func _box(x: float, y: float, w: float, h: float, color: String) -> void:
	draw_rect(Rect2(x, y, w, h), Color(color))

func _draw() -> void:
	_box(0, 0, room_size.x, room_size.y, "111923")
	# Layered air: quiet indigo below, cool glass high above.
	for y in range(8, 344, 4):
		var c := Color("1b2b38").lerp(Color("111821"), float(y) / 352.0)
		draw_rect(Rect2(8, y, 624, 4), c)
	for x in [48, 248, 448]:
		_window(x, 24, 128, 284)
	# Pilasters and inset service panels make the void feel built, not abstract.
	for x in [16, 204, 408, 608]:
		_box(x, 8, 18, 336, "141d28")
		_box(x, 8, 2, 336, "34434c")
		_box(x + 3, 8, 2, 336, "202f3b")
		_box(x + 15, 8, 3, 336, "0d151f")
		for y in range(24, 336, 40):
			_box(x + 5, y, 8, 16, "182532")
			_box(x + 5, y, 8, 1, "2b3944")
			_box(x + 1, y + 24, 2, 2, "657079")
	# Behind-route steel crossbeams, dark and thin so they cannot read as ledges.
	for y in [88, 176, 264, 328]:
		_box(8, y, 624, 5, "101821")
		_box(8, y, 624, 1, "35424a")
		for x in range(32, 620, 24):
			_box(x, y + 2, 1, 1, "56616a")
	# Copper cable trunks and small pipe collars.
	for x in [192, 592]:
		_box(x, 12, 5, 316, "30272b")
		_box(x + 1, 12, 1, 316, "72504b")
		_box(x + 2, 12, 1, 316, "493b3b")
		for y in range(32, 328, 48):
			_box(x - 1, y, 7, 3, "5b5555")
			_box(x - 1, y + 2, 7, 1, "29292f")
	# Catenary cables draped below the rafters.
	for origin in [28, 220, 420]:
		var last := Vector2(origin, 12)
		for u in range(1, 161):
			var p := Vector2(origin + u, 12 + roundf(sin(float(u) / 160.0 * PI) * 20.0))
			draw_line(last, p, Color("080f18"), 1.0)
			last = p
	# Ventilation cabinets and a tiny terminal at the two safe stopping places.
	_cabinet(256, 216, 32, 24)
	_cabinet(448, 160, 48, 24)
	_box(260, 220, 11, 7, "132329")
	_box(262, 222, 7, 1, "599186")
	_box(262, 224, 4, 1, "466e68")
	_box(480, 165, 7, 2, "bc956b")
	# Brass route chevrons on the wall beside the direction changes.
	_arrow(Vector2(76, 302), 1)
	_arrow(Vector2(486, 144), -1)
	_arrow(Vector2(338, 53), 1)
	# Lower pit has layered silhouettes and red warning beads, never bright fill.
	for x in range(104, 624, 16):
		_box(x, 334, 8, 2, "26252c")
		_box(x + 3, 336, 3, 2, "614047")
	# Suspended dust, quantized to whole pixels and decorrelated per mote.
	for i in 44:
		var x := 24 + (i * 97) % 592
		var y := 18 + fposmod(i * 43.0 + _clock * (1.0 + i % 3), 310.0)
		var c := Color("69818a")
		c.a = 0.15 + 0.2 * (0.5 + 0.5 * sin(_clock + i))
		draw_rect(Rect2(x, floorf(y), 1, 1), c)

func _window(x: int, y: int, w: int, h: int) -> void:
	_box(x - 4, y - 4, w + 8, h + 8, "0b131e")
	_box(x - 3, y - 3, w + 6, 2, "52606a")
	_box(x - 3, y, 2, h, "354854")
	for row in range(h):
		var c := Color("304c60").lerp(Color("15252f"), float(row) / h)
		draw_rect(Rect2(x, y + row, w, 1), c)
	# Distant office towers, each with its own sparse window rhythm.
	for i in 7:
		var bx := x + i * 19
		var top := y + 90 + (i * 37 + x) % 100
		_box(bx, top, 15, y + h - top, "1b303d")
		_box(bx, top, 15, 1, "304350")
		for wy in range(top + 6, y + h - 4, 9):
			for wx in range(bx + 3, mini(bx + 14, x + w), 5):
				if (wx * 7 + wy * 3) % 11 < 4:
					_box(wx, wy, 2, 3, "5e635e" if (wx + wy) % 3 == 0 else "3c5965")
	# Tall translucent reflected bands, clipped to the pane by construction.
	for i in 3:
		var bx := x + 9 + i * 37
		draw_rect(Rect2(bx, y + 4, 3, h - 8), Color(0.45, 0.65, 0.72, 0.05))
	for wy in range(y + 56, y + h, 64):
		_box(x, wy, w, 4, "172430")
		_box(x, wy, w, 1, "4a5c65")
	_box(x + w / 2 - 2, y, 4, h, "101f2b")
	_box(x + w / 2 - 2, y, 1, h, "4a5f6c")
	_box(x - 4, y + h, w + 8, 5, "111a24")
	_box(x - 4, y + h, w + 8, 1, "495860")

func _cabinet(x: int, y: int, w: int, h: int) -> void:
	_box(x, y, w, h, "25333b")
	_box(x, y, w, 1, "576268")
	_box(x, y, 1, h, "3b4c54")
	_box(x + w - 2, y + 1, 2, h - 1, "111d28")
	for row in range(y + 5, y + h - 3, 3):
		_box(x + w - 12, row, 7, 1, "0e1b25")

func _arrow(at: Vector2, direction: int) -> void:
	for i in 3:
		var a := at + Vector2(i * 5 * direction, 0)
		draw_line(a + Vector2(-2 * direction, -3), a, Color("947b59"), 1)
		draw_line(a, a + Vector2(-2 * direction, 3), Color("947b59"), 1)
