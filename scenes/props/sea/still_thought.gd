class_name StillThought
extends Node2D
## The finale's thoughts (Act3_Level_21, "SEVEN — THE FLOOR OF THE SEA"): spores
## lifting off the shadow and drifting at Hooshang from every side. "There is
## nowhere they are not."
##
## The rule of the scene, which is the whole game's rule said plainly: if he is
## STILL when one reaches him, it passes through him and goes out like a
## candle; if he is moving, it stings (a death, and the scene starts again).
## Still = no movement input and barely any velocity, for `still_grace`.
##
## Drawn with Act I's own dark-thought sheet — the thoughts he first met in the
## office — so the last ones are recognisably the first ones.

signal resolved(thought: StillThought, passed: bool)

const SHEET := preload("res://assets/hazards/dark_thought.png")
const GLOW := preload("res://assets/light_radial.png")

var target: Player
var speed := 16.0
var _t := 0.0
var _gone := false
var _sprite: Sprite2D
var _halo: Sprite2D
var _sway := 0.0


func _ready() -> void:
	z_index = 8
	_halo = Sprite2D.new()
	_halo.texture = GLOW
	_halo.scale = Vector2.ONE * 0.45
	var add := CanvasItemMaterial.new()
	add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	add.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	_halo.material = add
	_halo.modulate = Color(0.35, 0.08, 0.06)
	add_child(_halo)
	_sprite = Sprite2D.new()
	add_child(_sprite)
	_sway = randf() * TAU
	_frame()


func _frame() -> void:
	var tex := AtlasTexture.new()
	tex.atlas = SHEET
	tex.region = Rect2(int(_t / 0.14) % 4 * 16, 0, 16, 16)
	_sprite.texture = tex


func _process(delta: float) -> void:
	if _gone or target == null:
		return
	_t += delta
	_frame()
	var to := target.global_position - global_position
	var dir := to.normalized()
	global_position += (dir * speed + Vector2(-dir.y, dir.x) * sin(_t * 1.7 + _sway) * 6.0) * delta
	if to.length() < 7.0:
		_reach()


func _reach() -> void:
	_gone = true
	if is_still(target):
		resolved.emit(self, true)
		# Goes out like a candle: a flare, then nothing.
		var t := create_tween().set_parallel()
		t.tween_property(_sprite, "modulate", Color(4.0, 3.6, 2.6, 0.0), 0.5)
		t.tween_property(_halo, "modulate", Color(1.0, 0.8, 0.5, 0.0), 0.5)
		t.tween_property(_halo, "scale", Vector2.ONE * 0.9, 0.5)
		await t.finished
		queue_free()
	else:
		resolved.emit(self, false)
		target.die()
		queue_free()


static func is_still(p: Player) -> bool:
	return p.movement_input() == Vector2.ZERO and p.velocity.length() < 12.0
