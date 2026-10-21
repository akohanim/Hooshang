class_name AirBubble
extends Node2D
## The sea's refill crystal: a pocket of air the size of a breath. Touch it
## (in the water or out) and the Dive and the dash both come back
## (Player.refill_swim_dash); it pops, and grows back after `regrow_time`.
## Comes back on every respawn and room entry too (reset_all), so a retry finds
## the room the way it was built.

const SHEET := preload("res://assets/act3/sea/air_bubble.png")
const FRAME := 16
const FRAMES := 4
## Overlap radius, px. A little generous: it is a reward, not a hazard.
const RADIUS := 7.0

@export var regrow_time := 2.5

var _sprite: Sprite2D
var _popped := false
var _regrow := 0.0
var _time := 0.0
var _pop_t := -1.0
var _origin := Vector2.ZERO


func _ready() -> void:
	add_to_group("air_bubble")
	_origin = position
	z_index = 2
	_sprite = Sprite2D.new()
	_sprite.texture = _frame(0)
	add_child(_sprite)
	_time = fposmod(position.x * 0.013, 1.0) * 3.0


func _frame(i: int) -> AtlasTexture:
	var tex := AtlasTexture.new()
	tex.atlas = SHEET
	tex.region = Rect2(i * FRAME, 0, FRAME, FRAME)
	return tex


func _process(delta: float) -> void:
	_time += delta
	position = _origin + Vector2(0.0, roundf(sin(_time * 2.2) * 1.5))
	if _popped:
		_regrow -= delta
		if _pop_t >= 0.0:
			_pop_t += delta
			queue_redraw()
		if _regrow <= 0.0:
			reset()
		return
	_sprite.texture = _frame(int(_time / 0.2) % FRAMES)


func _physics_process(_delta: float) -> void:
	if _popped:
		return
	var player := get_tree().get_first_node_in_group("player") as Player
	if player == null or player.state == Player.State.DEAD:
		return
	var box := player.hitbox_rect().grow(RADIUS - 3.0)
	if not box.has_point(global_position):
		return
	# Already full: leave it for later rather than wasting it.
	if player.dash_available and (player.swim_dash_available or not player.has_swim_dash):
		return
	player.refill_swim_dash()
	_popped = true
	_regrow = regrow_time
	_pop_t = 0.0
	_sprite.visible = false
	Sfx.play(&"bubble")


func _draw() -> void:
	if not _popped or _pop_t < 0.0 or _pop_t > 0.3:
		return
	var glint := SeaPalette.at(SeaPalette.GLINT, global_position.y)
	var r := 4.0 + _pop_t * 30.0
	var col := Color(glint, 1.0 - _pop_t / 0.3)
	for i in 8:
		var a := TAU * i / 8.0
		draw_rect(Rect2((Vector2(cos(a), sin(a)) * r).floor(), Vector2.ONE), col)


func reset() -> void:
	_popped = false
	_pop_t = -1.0
	_regrow = 0.0
	_sprite.visible = true
	queue_redraw()


static func reset_all(tree: SceneTree) -> void:
	for node in tree.get_nodes_in_group("air_bubble"):
		(node as AirBubble).reset()
