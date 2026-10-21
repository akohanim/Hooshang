class_name SeaCurrent
extends Node2D
## A river in the sea: while he SWIMS inside this box, its flow is added to the
## target his stroke turns toward (Player.set_current / _state_swim). Out of the
## water it does nothing. Strong enough to out-swim him (flow > swim_speed) and
## the Dive is the only way across.
##
## Overlap is a plain Rect2 test against Player.hitbox_rect(), asked fresh every
## physics frame — the "no physics-cache lag" rule ldtk_world.gd's
## _return_strip_rect documents, and the same polling shape Pond/SlideZone use
## so a respawn or a teleport inside the box works with no boundary crossed.
##
## A COLUMN (flow pointing up) draws as rising bubbles; everything else as
## streaks running along the flow. Both in the depth ramp's glint colour.

@export var size := Vector2(64.0, 32.0)
@export var flow := Vector2(80.0, 0.0)

var _player: Player
var _streaks: Array[Vector3] = []  # x, y (local, from top-left), phase
var _time := 0.0


func _ready() -> void:
	z_index = 3
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(Vector2i(global_position))
	var count := clampi(int(size.x * size.y / 140.0), 4, 60)
	for i in count:
		_streaks.append(Vector3(rng.randf() * size.x, rng.randf() * size.y, rng.randf()))


func is_column() -> bool:
	return flow.y < -absf(flow.x)


func rect() -> Rect2:
	return Rect2(global_position - size * 0.5, size)


func _physics_process(_delta: float) -> void:
	if _player == null or not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player") as Player
		if _player == null:
			return
	if _player.swimming() and rect().intersects(_player.hitbox_rect()):
		_player.set_current(self, flow)
	else:
		_player.clear_current(self)


func _exit_tree() -> void:
	if _player != null and is_instance_valid(_player):
		_player.clear_current(self)


func _process(delta: float) -> void:
	_time += delta
	queue_redraw()


func _draw() -> void:
	var glint := SeaPalette.at(SeaPalette.GLINT, global_position.y)
	var speed := flow.length()
	var dir := flow / maxf(speed, 1.0)
	var origin := -size * 0.5
	for s in _streaks:
		# Each streak travels along the flow and wraps inside the box.
		var travel := fposmod(s.z * 97.0 + _time * speed * 0.6, size.x + size.y)
		var p := Vector2(s.x, s.y) + dir * travel
		p = Vector2(fposmod(p.x, size.x), fposmod(p.y, size.y))
		var fade := sin(fposmod(_time * 0.9 + s.z, 1.0) * PI)
		var col := Color(glint, 0.18 + 0.32 * fade)
		if is_column():
			var r := 1.0 if s.z < 0.6 else 2.0
			var at := (origin + p).floor()
			at.x += floor(sin(_time * 3.0 + s.z * 9.0) * 1.2)
			if r < 1.5:
				draw_rect(Rect2(at, Vector2.ONE), col)
			else:
				draw_rect(Rect2(at + Vector2(1, 0), Vector2(1, 1)), col)
				draw_rect(Rect2(at + Vector2(0, 1), Vector2(1, 1)), col)
				draw_rect(Rect2(at + Vector2(2, 1), Vector2(1, 1)), col)
				draw_rect(Rect2(at + Vector2(1, 2), Vector2(1, 1)), col)
		else:
			var length := clampf(speed * 0.06, 3.0, 8.0)
			var a := (origin + p).floor()
			var b := (a + dir * length).floor()
			draw_line(a, b, col, 1.0)
