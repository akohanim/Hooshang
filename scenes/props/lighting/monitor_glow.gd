@tool
class_name MonitorGlow
extends Node2D
## A computer screen left on overnight: a small bright panel plus the cold light
## it throws. One of the diegetic light sources the office is lit by — every
## light in Act I comes from something you can see (see LIGHTING.md).
##
## Same pattern as LampFixture: exported knobs, joins the "lights" group so the
## future manager light-sweep can find it, and all settings pushed onto the
## children in one place.

## Colour of the screen and its light. Cold CRT/LCD blue by default.
@export var screen_color := Color(0.55, 0.78, 0.95):
	set(v): screen_color = v; _apply()
## Brightness of the pool it throws.
@export var light_energy := 0.9:
	set(v): light_energy = v; _apply()
## Size of that pool (PointLight2D.texture_scale) — radius is 64 x this.
@export var light_scale := 1.1:
	set(v): light_scale = v; _apply()
## Screen size in pixels.
@export var screen_size := Vector2(10, 8):
	set(v): screen_size = v; _apply()
## Slow brightness wander, as if something is playing on it. Much gentler and
## slower than a failing fluorescent tube — this should read as alive, not broken.
@export var glows := true
@export var glow_amount := 0.12
@export var glow_speed := 2.2

@onready var screen: ColorRect = $Screen
@onready var glow: PointLight2D = $Glow

var _t := 0.0


func _ready() -> void:
	add_to_group("lights")
	_apply()


func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	if not glows:
		return
	_t += delta * glow_speed
	# Two out-of-step sines so the wander never settles into an obvious loop.
	var wander := (sin(_t) + sin(_t * 0.37)) * 0.5
	glow.energy = light_energy * (1.0 + wander * glow_amount)


func _apply() -> void:
	if screen == null:
		return
	screen.color = screen_color
	screen.size = screen_size
	screen.position = -screen_size * 0.5   # centred on the node's origin
	glow.color = screen_color
	glow.energy = light_energy
	glow.texture_scale = light_scale
