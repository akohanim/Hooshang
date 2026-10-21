class_name InkFlood
extends Node2D
## Darkshang in the trench (Act III, chapter V): the shadow pouring down after
## him "like ink". A wall across the whole room whose lower FRONT descends at
## `speed`; once the front reaches his head he is caught.
##
## It waits at the threshold the way Act I's shadow does (chase_entry_test):
## nothing moves until he has committed — dropped `hold_distance` below where he
## came in, or `hold_time` has passed — so a respawn always gives him the same
## start. Reset on every respawn and room entry (reset_all).
##
## Placed by tools/build_act3_world.py at the room's top-left; `size` is the
## room. The front starts `start_depth` px down from the top.

const EYE := Color(0.95, 0.2, 0.25)
const RIM := Color(0.45, 0.28, 0.75)

@export var size := Vector2(320.0, 384.0)
@export var speed := 34.0
@export var start_depth := 4.0
@export var hold_distance := 16.0
@export var hold_time := 2.5
## Extra speed per second of the chase, so a long trench tightens.
@export var acceleration := 0.0

var front := 0.0
var _armed := false
var _hold := 0.0
var _entry_y := INF
var _time := 0.0
var _live_speed := 0.0


func _ready() -> void:
	add_to_group("ink_flood")
	z_index = 7
	reset()


func reset() -> void:
	front = start_depth
	_armed = false
	_hold = 0.0
	_entry_y = INF
	_live_speed = speed
	queue_redraw()


static func reset_all(tree: SceneTree) -> void:
	for node in tree.get_nodes_in_group("ink_flood"):
		(node as InkFlood).reset()


func _room_active(player: Player) -> bool:
	var r := Rect2(global_position, size)
	return r.has_point(player.global_position)


func _physics_process(delta: float) -> void:
	var player := get_tree().get_first_node_in_group("player") as Player
	if player == null or not _room_active(player) or player.state == Player.State.DEAD:
		return
	if player.input_locked:
		return
	if not _armed:
		if _entry_y == INF:
			_entry_y = player.global_position.y
		_hold += delta
		if player.global_position.y - _entry_y >= hold_distance or _hold >= hold_time:
			_armed = true
			Sfx.play(&"darkshang_gather")
		return
	_live_speed += acceleration * delta
	front = minf(front + _live_speed * delta, size.y + 40.0)
	if player.hitbox_rect().position.y < global_position.y + front - 3.0:
		player.die()


func _process(delta: float) -> void:
	_time += delta
	queue_redraw()


func _draw() -> void:
	var body := maxf(front - 10.0, 0.0)
	if body > 0.0:
		draw_rect(Rect2(0.0, -40.0, size.x, body + 40.0), Color.BLACK)
	# The front: tendrils hanging off it, each column its own length and sway.
	var x := 0.0
	while x < size.x:
		var n := sin(x * 0.17 + _time * 1.7) * 0.5 + sin(x * 0.051 - _time * 0.9) * 0.5
		var length := 4.0 + (n * 0.5 + 0.5) * 9.0
		if fposmod(x, 14.0) < 2.0:
			length += 5.0 + 4.0 * sin(_time * 2.3 + x)
		var top := body
		draw_rect(Rect2(x, top, 2.0, length + 10.0 - 6.0), Color.BLACK)
		draw_rect(Rect2(x, top + length + 4.0, 2.0, 1.0), RIM)
		x += 2.0
	# Eyes open and close in the mass, never more than a few at once.
	for i in 6:
		var seed := float(i) * 37.1
		var cycle := fposmod(_time * 0.35 + seed * 0.13, 1.0)
		if cycle > 0.55:
			continue
		var ex := fposmod(seed * 53.0 + floor(_time * 0.35 + seed * 0.13) * 91.0, size.x - 12.0) + 6.0
		var ey := body - 10.0 - fposmod(seed * 17.0, 30.0)
		if ey < -30.0:
			continue
		if cycle > 0.5:
			continue  # blinking
		draw_rect(Rect2(ex, ey, 2.0, 1.0), EYE)
		draw_rect(Rect2(ex + 4.0, ey, 2.0, 1.0), EYE)
