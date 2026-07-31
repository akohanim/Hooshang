@tool
class_name LampFixture
extends Node2D
## Reusable ceiling lamp fixture: a light source with an optional visible body
## (cable + bulb). Instance this anywhere a lamp is needed — the cubicle, the
## corridor, wherever — and tweak per instance with the exported vars below
## instead of duplicating the scene. Editing the lamp (look, falloff, flicker)
## then means editing ONE scene, not every level that uses it.
##
## Joins the "lights" group in _ready() so a system can find every lamp at once
## (e.g. the future manager light-sweep that snuffs them out).

## Cold fluorescent by default; warm lamps just recolour this per instance.
@export var light_color := Color(0.78, 0.92, 0.88):
	set(v): light_color = v; _apply()
## Brightness of the light pool.
@export var light_energy := 1.0:
	set(v): light_energy = v; _apply()
## Size of the light pool (PointLight2D.texture_scale).
@export var light_scale := 2.2:
	set(v): light_scale = v; _apply()
## Show the physical fixture (cable + bulb). Off = just a glow, e.g. a light
## recessed in the ceiling.
@export var show_body := true:
	set(v): show_body = v; _apply()
## How far the bulb hangs below its ceiling attach point, in pixels.
@export var cable_length := 12.0:
	set(v): cable_length = v; _apply()
## Fluorescent buzz/sputter. Off by default so lamps are steady unless asked.
@export var flickers := false
@export var flicker_amount := 0.18
@export var flicker_speed := 14.0

@onready var cable: ColorRect = $Cable
@onready var bulb: ColorRect = $Bulb
@onready var glow: PointLight2D = $Glow

var _t := 0.0


func _ready() -> void:
	add_to_group("lights")
	_apply()


## Push the exported values onto the child nodes. Safe to call from setters
## before _ready (guards on the @onready refs being null).
func _apply() -> void:
	if glow == null:
		return
	glow.color = light_color
	glow.energy = light_energy
	glow.texture_scale = light_scale
	cable.visible = show_body
	bulb.visible = show_body
	# Root sits at the light-pool centre; the cable rises to the ceiling.
	cable.position = Vector2(-1.0, -cable_length)
	cable.size = Vector2(2.0, cable_length)


func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	if not flickers or glow == null:
		return
	_t += delta * flicker_speed
	# Two-frequency wobble so the buzz doesn't read as a clean sine.
	var n := sin(_t) * 0.6 + sin(_t * 2.3 + 1.0) * 0.4
	glow.energy = light_energy * (1.0 - flicker_amount * (0.5 + 0.5 * n))
