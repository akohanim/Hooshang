class_name MirrorGame
extends Node2D
## Child Hooshang crosses the fractured mirror toward his adult self. The last
## two rooms are seen through the child's eyes. Contact restarts only that room.
signal exit_requested
signal finished

const W := 160
const H := 120
const FONT := preload("res://assets/fonts/pixel5x7.fnt")
const ADULT := preload("res://assets/minigame/simorgh/hooshang_sheet.png")
const CHILD := preload("res://assets/characters/hooshang_child/act2/packed/idle/frame_000.png")
const START := Vector2(17, 89)
const GOAL := Vector2(143, 89)
const SPEED := 52.0
const STAGE_NAMES := ["THE GLASS", "MOVING SHARDS", "FALSE DOORS", "THE PURSUER", "THE OTHER SIDE"]
const STAGES := [
	{"walls":[Rect2(64,20,7,46)], "shards":[Vector2(79,88)], "movers":[], "chasers":0, "pulse":false},
	{"walls":[Rect2(51,71,7,37),Rect2(105,20,7,46)], "shards":[Vector2(79,43)], "movers":[Vector2(64,53),Vector2(99,87)], "chasers":0, "pulse":false},
	{"walls":[Rect2(48,20,7,54),Rect2(91,61,7,47)], "shards":[Vector2(71,36)], "movers":[Vector2(72,87)], "chasers":0, "pulse":true},
	{"walls":[Rect2(48,20,7,44),Rect2(84,72,7,36)], "shards":[Vector2(68,91)], "movers":[Vector2(106,48)], "chasers":1, "pulse":false},
	{"walls":[Rect2(45,20,7,44),Rect2(79,68,7,40),Rect2(112,20,7,46)], "shards":[Vector2(62,88),Vector2(99,43)], "movers":[Vector2(64,45),Vector2(100,87)], "chasers":2, "pulse":true}
]
enum Mode { TITLE, MIRROR, STAGE, BETWEEN, REUNION }
var active := false
var mode := Mode.TITLE
var stage := 0
var clock := 0.0
var stage_clock := 0.0
var mode_time := 0.0
var reflection := START
var chasers: Array[Vector2] = []
var deaths := 0
var hit_flash := 0.0
var _background: ImageTexture
var _sfx: AudioStreamPlayer

func _ready() -> void:
	_background = ImageTexture.create_from_image(_make_background())
	_sfx = AudioStreamPlayer.new()
	_sfx.volume_db = -11.0
	add_child(_sfx)
	set_physics_process(true)

func activate() -> void:
	active = true
	mode = Mode.TITLE
	stage = 0
	clock = 0.0
	mode_time = 0.0
	deaths = 0
	hit_flash = 0.0
	_reset_stage()

func deactivate() -> void:
	active = false
	mode = Mode.TITLE
	queue_redraw()

func _reset_stage() -> void:
	reflection = START
	stage_clock = 0.0
	chasers.clear()
	for i in int(STAGES[stage].chasers):
		chasers.append(Vector2(24 + i * 13, 25 + i * 12))
	queue_redraw()

func _physics_process(delta: float) -> void:
	clock += delta
	mode_time += delta
	hit_flash = maxf(0.0, hit_flash - delta)
	if active and Input.is_action_just_pressed("pause"):
		exit_requested.emit()
		return
	if not active:
		queue_redraw()
		return
	match mode:
		Mode.TITLE:
			if Input.is_action_just_pressed("jump") or Input.is_action_just_pressed("move_up"):
				mode = Mode.MIRROR
				mode_time = 0.0
				_sound("stinger")
		Mode.MIRROR:
			if mode_time >= 2.0:
				mode = Mode.STAGE
				mode_time = 0.0
		Mode.STAGE:
			_tick_stage(delta)
		Mode.BETWEEN:
			if mode_time >= 1.25:
				mode = Mode.STAGE
				mode_time = 0.0
		Mode.REUNION:
			if mode_time >= 2.4:
				mode = Mode.TITLE
				active = false
				finished.emit()
	queue_redraw()

func _tick_stage(delta: float) -> void:
	stage_clock += delta
	var direction := _movement_axis()
	var step := direction * SPEED * delta
	var candidate := Vector2(clampf(reflection.x + step.x, 8, 152), reflection.y)
	if not _hits_wall(candidate): reflection.x = candidate.x
	candidate = Vector2(reflection.x, clampf(reflection.y + step.y, 21, 105))
	if not _hits_wall(candidate): reflection.y = candidate.y
	for i in chasers.size():
		if reflection.x > 48:
			chasers[i] += (reflection - chasers[i]).normalized() * (12.0 + stage * 2.0) * delta
		if reflection.distance_to(chasers[i]) < 7.0:
			_die()
			return
	var info: Dictionary = STAGES[stage]
	for point: Vector2 in info.shards:
		if reflection.distance_to(point) < 7.0:
			_die()
			return
	for i in info.movers.size():
		if reflection.distance_to(_mover(i)) < 7.0:
			_die()
			return
	if bool(info.pulse) and _pulse_on() and _pulse_rect().grow(2).has_point(reflection):
		_die()
		return
	if reflection.distance_to(GOAL) < 10.0:
		if stage == STAGES.size() - 1:
			mode = Mode.REUNION
			_sound("portal")
		else:
			stage += 1
			_reset_stage()
			mode = Mode.BETWEEN
			_sound("coin")
		mode_time = 0.0

func _first_person() -> bool:
	return stage >= 3

func _movement_axis() -> Vector2:
	var horizontal := Input.get_action_strength("move_right") - Input.get_action_strength("move_left")
	var vertical := Input.get_action_strength("move_down") - Input.get_action_strength("move_up")
	# In first person, Up walks toward adult Hooshang and Left/Right strafe.
	return (Vector2(-vertical, horizontal) if _first_person() else Vector2(horizontal, vertical)).normalized()

func _hits_wall(at: Vector2) -> bool:
	for wall: Rect2 in STAGES[stage].walls:
		if wall.grow(3).has_point(at): return true
	return false

func _mover(i: int) -> Vector2:
	var point: Vector2 = STAGES[stage].movers[i]
	return point + Vector2(sin(stage_clock * (1.1 + stage * 0.18) + i * 2.1) * 11.0, cos(stage_clock * (1.4 + stage * 0.14) + i) * 12.0)

func _pulse_on() -> bool:
	return fposmod(stage_clock, 3.0) >= 1.55

func _pulse_rect() -> Rect2:
	return Rect2(121, 24, 4, 65)

func _die() -> void:
	deaths += 1
	hit_flash = 0.35
	_sound("hit")
	_reset_stage()

func _sound(name: String) -> void:
	if _sfx == null: return
	_sfx.stream = load("res://assets/minigame/simorgh/" + name + ".wav")
	_sfx.play()

func _make_background() -> Image:
	var image := Image.create(W, H, false, Image.FORMAT_RGBA8)
	for y in H:
		for x in W:
			var edge := absf(float(x - 80)) / 80.0
			var glow := maxf(0.0, 1.0 - Vector2((x - 80) * 0.009, (y - 56) * 0.013).length())
			var dither := float((x * 17 + y * 29) % 7) * 0.004
			image.set_pixel(x, y, Color(0.065 + glow * 0.16 + dither, 0.045 + glow * 0.08, 0.16 + glow * 0.25 - edge * 0.035))
	return image

func _draw() -> void:
	draw_texture(_background, Vector2.ZERO)
	_draw_arches()
	if mode == Mode.TITLE:
		_draw_mirror(Vector2(80, 61), 24.0)
		_draw_person(Vector2(80, 79), true)
		draw_rect(Rect2(9, 91, 142, 28), Color("140d2b", 0.93))
		draw_rect(Rect2(9, 91, 142, 28), Color("d8b9ef", 0.75), false, 1)
		_text("THE OTHER SIDE", Vector2(25, 17), Color("ffe4ac"), 9)
		_text("MOVE TO THE LIGHT", Vector2(32, 102), Color("ded0ff"), 7)
		_text("JUMP TO ENTER", Vector2(44, 114), Color("fff2d2"), 7)
		return
	if mode == Mode.MIRROR:
		_draw_mirror(Vector2(80, 62), 30.0)
		var split := minf(mode_time / 2.0, 1.0)
		_draw_person(Vector2(80 - split * 24, 82), true)
		_draw_person(Vector2(80 + split * 24, 82), false)
		_text("FIND YOUR FUTURE SELF", Vector2(24, 111), Color("ffe4ac"), 8)
		return
	if _first_person():
		_draw_first_person()
	else:
		_draw_stage()
	if mode == Mode.BETWEEN:
		draw_rect(Rect2(13, 45, 134, 31), Color("130d2c", 0.94))
		draw_rect(Rect2(13, 45, 134, 31), Color("e7c5ff"), false, 1.0)
		_text(STAGE_NAMES[stage], Vector2(22, 64), Color("ffe4ac"), 8)
	elif mode == Mode.REUNION:
		draw_rect(Rect2(17, 43, 126, 37), Color("130d2c", 0.95))
		_text("I'M HERE.", Vector2(45, 59), Color("ffe4ac"), 9)
		_text("5 LEMONS FOUND", Vector2(29, 73), Color("fff0c5"), 7)
	if hit_flash > 0.0:
		draw_rect(Rect2(0, 0, W, H), Color("f77baa", hit_flash * 0.46))
		_text("TRY AGAIN", Vector2(49, 61), Color("fff4df"), 8)

func _draw_arches() -> void:
	# Tile mosaic and fine gold ornament keep the dream tied to Act II.
	draw_rect(Rect2(0, 83, W, 37), Color("3a2251", 0.48))
	for row in 5:
		for col in 21:
			var cell := Vector2(col * 8 + (row % 2) * 4 - 4, 82 + row * 8)
			var tile := Rect2(cell, Vector2(7, 7))
			draw_rect(tile, Color("795078", 0.23 if (row + col) % 2 == 0 else 0.12))
			if (row * 7 + col * 3) % 5 == 0:
				draw_line(cell + Vector2(2, 3), cell + Vector2(4, 5), Color("e6b991", 0.38))
	for i in 5:
		var w := 41.0 + i * 26.0 + sin(clock * 0.55 + i) * 2.0
		var h := 58.0 + i * 8.0
		var tint := Color.from_hsv(0.71 + i * 0.035, 0.41, 0.56 - i * 0.065, 0.8)
		draw_arc(Vector2(80, 91 - h * 0.38), w * 0.5, PI, TAU, 20, tint, 1.0)
		draw_line(Vector2(80 - w * 0.5, 91 - h * 0.38), Vector2(80 - w * 0.5, 108), tint)
		draw_line(Vector2(80 + w * 0.5, 91 - h * 0.38), Vector2(80 + w * 0.5, 108), tint)
		for side in [-1, 1]:
			var edge: float = 80.0 + side * w * 0.5
			for y in range(33, 99, 10):
				draw_circle(Vector2(edge, y), 1.0, Color("ffe1af", 0.25))
	draw_line(Vector2(5, 108), Vector2(155, 108), Color("f0c48a", 0.8))
	for i in 9:
		var x := float(i * 23 - 12)
		draw_line(Vector2(80 + (x - 80) * 0.25, 81), Vector2(x, 108), Color("ca9c8c", 0.27))
	for i in 16:
		var x := fposmod(float(i * 47) + sin(clock * 0.7 + i) * 8, 160)
		var y := fposmod(float(i * 31) + clock * (2 + i % 3), 116)
		draw_circle(Vector2(x, y), 0.7, Color("ffe3aa", 0.55))

func _draw_stage() -> void:
	var tint := Color.from_hsv(0.74 + stage * 0.045, 0.55, 0.8)
	draw_rect(Rect2(0, 0, W, 16), Color("160e2c", 0.94))
	draw_line(Vector2(0, 15), Vector2(W, 15), Color("c69fc9", 0.7))
	for wall: Rect2 in STAGES[stage].walls:
		draw_rect(wall, Color("22143f"))
		draw_rect(wall, tint, false, 1)
		for y in range(int(wall.position.y) + 4, int(wall.end.y), 8):
			draw_line(Vector2(wall.position.x + 1, y), Vector2(wall.end.x - 2, y - 3), Color("f6d5c8", 0.28))
	for point: Vector2 in STAGES[stage].shards: _draw_shard(point, 0.0)
	for i in STAGES[stage].movers.size(): _draw_shard(_mover(i), stage_clock + i)
	if bool(STAGES[stage].pulse):
		var gate := _pulse_rect()
		draw_rect(gate, Color("ff71be", 0.8 if _pulse_on() else 0.17))
		draw_line(gate.position + Vector2(-2, 0), gate.position + Vector2(6, 0), Color("fff0bf"))
		draw_line(gate.position + Vector2(-2, gate.size.y), gate.position + Vector2(6, gate.size.y), Color("fff0bf"))
	for pursuer in chasers: _draw_person(pursuer, true, Color("ed629c"))
	draw_circle(GOAL + Vector2(0, -6), 13, Color("ffe2a1", 0.2))
	draw_arc(GOAL + Vector2(0, -6), 12, 0, TAU, 24, Color("ffe2a1", 0.75), 1)
	_draw_person(GOAL, false)
	_draw_person(reflection, true)
	for i in 5:
		var c := Color("f6d49d") if i <= stage else Color("5b4a6e")
		draw_circle(Vector2(12 + i * 10, 8), 2.5, c)
	_text("%d / 5" % (stage + 1), Vector2(130, 11), Color("fff0d2"), 7)
	if mode == Mode.STAGE and stage_clock < 2.3:
		draw_rect(Rect2(17, 18, 126, 11), Color("160e2c", 0.82))
		_text(STAGE_NAMES[stage], Vector2(25, 26), Color("ffe4ac"), 7)

## Perspective camera fixed to child Hooshang's eyes. The same authoritative
## stage geometry drives collision and drawing; the player sprite is absent.
func _draw_first_person() -> void:
	draw_rect(Rect2(0, 0, W, 58), Color("1e163b"))
	draw_rect(Rect2(0, 58, W, 62), Color("443056"))
	var vanishing := Vector2(80, 53)
	for depth in range(120, 0, -12):
		var x: float = reflection.x + depth
		var left := _project(Vector2(x, 105))
		var right := _project(Vector2(x, 21))
		draw_line(left, right, Color("d4a6b9", 0.11 + 0.21 * (1.0 - depth / 120.0)))
	for boundary in [21.0, 105.0]:
		draw_line(vanishing, _project(Vector2(reflection.x + 3, boundary)), Color("e6be9d", 0.55))
	for lane in range(29, 106, 16):
		draw_line(vanishing, _project(Vector2(reflection.x + 3, lane)), Color("aa8bd2", 0.25))
	for depth in range(110, 0, -25):
		var arch_x: float = reflection.x + depth
		var arch_left := _project(Vector2(arch_x, 105))
		var arch_right := _project(Vector2(arch_x, 21))
		var rise := clampf(26.0 * _perspective_scale(depth), 2.0, 72.0)
		var arch_color := Color("aa78d5", 0.18 + 0.4 * (1.0 - depth / 120.0))
		draw_line(arch_left, arch_left - Vector2(0, rise), arch_color)
		draw_line(arch_right, arch_right - Vector2(0, rise), arch_color)
		draw_arc(Vector2((arch_left.x + arch_right.x) * 0.5, minf(arch_left.y, arch_right.y) - rise * 0.65),
			absf(arch_right.x - arch_left.x) * 0.5, PI, TAU, 20, arch_color, 1.0)
	var objects: Array[Dictionary] = []
	for wall: Rect2 in STAGES[stage].walls:
		objects.append({"kind":"wall", "depth":wall.position.x - reflection.x, "rect":wall})
	for point: Vector2 in STAGES[stage].shards:
		objects.append({"kind":"shard", "depth":point.x - reflection.x, "point":point})
	for i in STAGES[stage].movers.size():
		var point := _mover(i)
		objects.append({"kind":"shard", "depth":point.x - reflection.x, "point":point})
	if bool(STAGES[stage].pulse):
		objects.append({"kind":"gate", "depth":_pulse_rect().position.x - reflection.x, "rect":_pulse_rect()})
	objects.append({"kind":"adult", "depth":GOAL.x - reflection.x, "point":GOAL})
	objects.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a.depth) > float(b.depth))
	for item in objects:
		if float(item.depth) <= 1.0: continue
		match str(item.kind):
			"wall": _draw_first_person_wall(item.rect, false)
			"gate": _draw_first_person_wall(item.rect, true)
			"shard": _draw_first_person_shard(item.point)
			"adult": _draw_first_person_adult(item.point)
	_draw_first_person_warning()
	draw_rect(Rect2(0, 0, W, 16), Color("160e2c", 0.95))
	for i in 5:
		draw_circle(Vector2(12 + i * 10, 8), 2.5, Color("f6d49d") if i <= stage else Color("5b4a6e"))
	_text("%d / 5" % (stage + 1), Vector2(130, 11), Color("fff0d2"), 7)
	draw_rect(Rect2(0, 108, W, 12), Color("160e2c", 0.9))
	_text("UP: GO  LEFT/RIGHT: STRAFE", Vector2(11, 116), Color("ffe9c6"), 7)
	if mode == Mode.STAGE and stage_clock < 2.3:
		draw_rect(Rect2(26, 19, 108, 11), Color("160e2c", 0.84))
		_text(STAGE_NAMES[stage], Vector2(32, 27), Color("ffe4ac"), 7)

func _perspective_scale(depth: float) -> float:
	return 75.0 / maxf(12.0, depth + 12.0)

func _project(point: Vector2) -> Vector2:
	var depth := point.x - reflection.x
	var scale := _perspective_scale(depth)
	return Vector2(80.0 - (point.y - reflection.y) * scale, 53.0 + 19.0 * scale)

func _draw_first_person_wall(rect: Rect2, gate: bool) -> void:
	var left := _project(Vector2(rect.position.x, rect.end.y))
	var right := _project(Vector2(rect.position.x, rect.position.y))
	var scale := _perspective_scale(rect.position.x - reflection.x)
	var top := left.y - 34.0 * scale
	var shade := Color("f46bb7", 0.75 if _pulse_on() else 0.18) if gate else Color("5b3886")
	draw_colored_polygon(PackedVector2Array([Vector2(left.x, top), Vector2(right.x, top), right, left]), shade)
	for edge in [left.x, right.x]:
		draw_line(Vector2(edge, top), Vector2(edge, left.y), Color("fff0bd", 0.65 if gate else 0.55), 1)
	if not gate:
		for n in 4:
			var y := lerpf(top, left.y, (n + 1) / 5.0)
			draw_line(Vector2(left.x, y), Vector2(right.x, y), Color("d6a5ec", 0.25))

func _draw_first_person_shard(point: Vector2) -> void:
	var at := _project(point)
	var size := clampf(5.0 * _perspective_scale(point.x - reflection.x), 2.0, 39.0)
	draw_circle(at - Vector2(0, size), size * 1.3, Color("ed75d6", 0.23))
	draw_colored_polygon(PackedVector2Array([at - Vector2(0, size * 2), at + Vector2(size * 0.65, -size), at, at + Vector2(-size * 0.65, -size)]), Color("ff83d1"))
	draw_line(at - Vector2(0, size * 2), at, Color("fff2ff"), 1)

func _draw_first_person_adult(point: Vector2) -> void:
	var at := _project(point)
	var height := clampf(20.0 * _perspective_scale(point.x - reflection.x), 8.0, 85.0)
	draw_circle(at - Vector2(0, height * 0.65), height * 0.8, Color("ffd99d", 0.24))
	draw_arc(at - Vector2(0, height * 0.58), height * 0.66, 0, TAU, 24, Color("ffe5b1", 0.8), 1)
	draw_texture_rect_region(ADULT, Rect2(at - Vector2(height * 0.32, height), Vector2(height * 0.64, height)),
		Rect2(0, 0, 32, 48))

func _draw_first_person_warning() -> void:
	var nearest := INF
	for pursuer in chasers:
		nearest = minf(nearest, reflection.distance_to(pursuer))
	if nearest > 38.0: return
	var strength := clampf((38.0 - nearest) / 38.0, 0.0, 0.75)
	draw_rect(Rect2(0, 0, 7, H), Color("ef5a9c", strength))
	draw_rect(Rect2(W - 7, 0, 7, H), Color("ef5a9c", strength))

func _draw_shard(at: Vector2, spin: float) -> void:
	var s := sin(clock * 2.1 + spin) * 2.0
	var p := PackedVector2Array([at + Vector2(0, -8 - s), at + Vector2(5, 0), at + Vector2(0, 8 + s), at + Vector2(-5, 0)])
	draw_colored_polygon(p, Color("ff77c6"))
	draw_line(p[0], p[2], Color("fff2ff", 0.75))
	draw_circle(at, 1.3, Color.WHITE)

func _draw_mirror(at: Vector2, radius: float) -> void:
	draw_circle(at, radius + 4, Color("c49770"))
	draw_circle(at, radius + 2, Color("ffe4ac"))
	draw_circle(at, radius, Color("66519b"))
	draw_circle(at + Vector2(-5, -4), radius * 0.68, Color("ac94dc", 0.65))
	for i in 5:
		var point := at + Vector2.from_angle(i * 2.3 + clock * 0.12) * radius * 0.7
		draw_line(at, point, Color("e9d8ff", 0.45), 1)

func _draw_person(at: Vector2, child: bool, shade := Color.WHITE) -> void:
	if child:
		draw_circle(at + Vector2(0, -6), 10.0, Color("b26aff", 0.24))
		draw_texture_rect_region(CHILD, Rect2(at - Vector2(7, 15), Vector2(14, 20)),
			Rect2(31, 23, 28, 40), shade)
		draw_line(at + Vector2(-4, 5), at + Vector2(4, 5), Color("f8d7ff"), 1)
	else:
		draw_texture_rect_region(ADULT, Rect2(at - Vector2(7, 16), Vector2(14, 21)),
			Rect2(0, 0, 32, 48), shade)

func _text(label: String, at: Vector2, color: Color, size: int) -> void:
	draw_string(FONT, at + Vector2(1, 1), label, HORIZONTAL_ALIGNMENT_LEFT, -1, size, Color("140e2c"))
	draw_string(FONT, at, label, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)
