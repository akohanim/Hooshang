@tool
class_name Fish
extends Node2D
## A tiny ambient pond fish: patrols back and forth inside whatever Pond
## spawned it (see pond.gd's _rebuild_fish), tail flicking through its own
## 3-frame sheet. Decorative and non-colliding. Act2Beats may hook an existing
## fish, taking over its travel while its tail keeps animating.

## How far it swims to either side of where it was placed, in px.
@export var patrol_width := 24.0
## Which way it starts swimming, 1 = toward +x (east), -1 = toward -x. East is
## unflipped, matching every other sprite in this project (see hooshang_frames
## / player.gd's flip_h convention) — west is this same art mirrored, not
## separate frames.
@export var start_dir := 1
## Top swim speed, px/s. Slow — it is drifting inside a pond, not fleeing it.
@export var speed := 10.0
## Full tail-flick cycles per second.
@export var flick_speed := 2.2

const SHEET := preload("res://assets/props/pond_fish/fish.png")
const FRAME := Vector2(12.0, 8.0)
const FRAME_COUNT := 3

@onready var _sprite: Sprite2D = $Sprite2D

var _frames: Array[AtlasTexture] = []
var _origin_x := 0.0
var _dir := 1
## Its own clock, offset by a per-fish phase so two fish in one pond don't
## flick their tails in lockstep — see _ready().
var _clock := 0.0
var _hooked := false


func _ready() -> void:
	for i in FRAME_COUNT:
		var tex := AtlasTexture.new()
		tex.filter_clip = true
		tex.atlas = SHEET
		tex.region = Rect2(i * FRAME.x, 0.0, FRAME.x, FRAME.y)
		_frames.append(tex)
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_origin_x = position.x
	_dir = signi(start_dir) if start_dir != 0 else 1
	# Hashed from the placed position, not randf() — the same "a room looks
	# the same on every visit" rule DarkThought.reset() and the thought tile
	# clocks follow elsewhere in this project, applied to a phase instead of
	# a position.
	_clock = _hash01(int(position.x), int(position.y))
	set_process(not Engine.is_editor_hint())
	_apply_frame()


func _process(delta: float) -> void:
	_clock += delta
	if _hooked:
		_apply_frame()
		return
	position.x += _dir * speed * delta
	var offset := position.x - _origin_x
	if absf(offset) >= patrol_width * 0.5:
		_dir = -_dir
		position.x = _origin_x + signf(offset) * patrol_width * 0.5
	_apply_frame()


func _apply_frame() -> void:
	if _sprite == null or _frames.is_empty():
		return
	_sprite.flip_h = _dir < 0
	var idx := int(fmod(_clock * flick_speed, 1.0) * FRAME_COUNT)
	_sprite.texture = _frames[clampi(idx, 0, FRAME_COUNT - 1)]


## Deterministic float in [0, 1) from two integers — same integer-mix and same
## reasoning as Pond._hash01 (see that function's doc); kept as its own copy
## rather than a cross-class call, per this project's self-contained-script
## convention.
static func _hash01(a: int, b: int) -> float:
	var n := a * 374761393 + b * 668265263
	n = (n ^ (n >> 13)) * 1274126177
	n = n ^ (n >> 16)
	return float(n & 0x7fffffff) / float(0x7fffffff)


func reset_patrol_origin() -> void:
	_origin_x = position.x


func hook() -> void:
	_hooked = true
	_dir = 1


func cook() -> void:
	set_process(false)
	_sprite.texture = _frames[1]
	_sprite.flip_h = false
	_sprite.modulate = Color(0.75, 0.62, 0.48)
	var unshaded := CanvasItemMaterial.new()
	unshaded.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	_sprite.material = unshaded
	queue_redraw()


func _draw() -> void:
	if not is_processing():
		draw_line(Vector2(-11, 1), Vector2(11, 1), Color(0.38, 0.22, 0.12), 1.0)
		draw_line(Vector2(-10, 1), Vector2(-10, 22), Color(0.38, 0.22, 0.12), 1.0)
		draw_line(Vector2(10, 1), Vector2(10, 22), Color(0.38, 0.22, 0.12), 1.0)
