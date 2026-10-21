class_name SeaDecor
extends Node2D
## Set dressing for Act III — kelp, coral, rock, shells, reeds, a school of fish,
## the wreck's furniture and flickering tubes, the whale's bones. No collision,
## never in the way: the rooms are built from the semantic grid alone.
##
## Drawn in the act's own LINE language (white on black, assets/act3/sea/
## decor.png from tools/gen_act3_sea_art.py) and recoloured by the same depth
## shader as the terrain, so a strand of kelp is white line art on the shore and
## gold at the floor without a second drawing. `kind` picks the cell on the
## sheet; tall kinds (kelp, reeds) are stacked `height` cells high and sway.

const SHEET := preload("res://assets/act3/sea/decor.png")
const TINT_SHADER := preload("res://assets/shaders/act3_depth_tint.gdshader")
## kind -> [sheet column, sheet row, cells wide, cells tall, sways, stacks]
const KINDS := {
	"kelp": [0, 0, 1, 1, true, true],
	"reed": [1, 0, 1, 1, true, true],
	"seagrass": [2, 0, 1, 1, true, false],
	"coral": [3, 0, 2, 2, false, false],
	"fan": [5, 0, 2, 2, true, false],
	"rock": [7, 0, 2, 1, false, false],
	"shell": [9, 0, 1, 1, false, false],
	"desk": [0, 2, 3, 2, false, false],
	"cabinet": [3, 2, 2, 3, false, false],
	"partition": [5, 2, 1, 3, false, false],
	"chair": [6, 2, 2, 2, false, false],
	"tube": [8, 2, 3, 1, false, false],
	"rib": [0, 5, 2, 4, false, false],
	"skull": [2, 5, 4, 3, false, false],
	"anchor": [6, 5, 2, 3, false, false],
	"lantern": [8, 5, 1, 2, true, false],
	"pier_post": [9, 5, 1, 3, false, false],
}
const CELL := 8

@export var kind := "kelp"
@export var height := 1
@export var flip := false

var _parts: Array[Sprite2D] = []
var _time := 0.0
var _sways := false
var _flicker := false


func _ready() -> void:
	var spec: Array = KINDS.get(kind, KINDS["rock"])
	_sways = spec[4]
	_flicker = kind == "tube"
	z_index = -2 if kind not in ["seagrass", "reed"] else 1
	var mat := ShaderMaterial.new()
	mat.shader = TINT_SHADER
	SeaPalette.bind(mat)
	var room := get_parent().get_parent() if get_parent() != null else null
	if room != null and room.has_meta("fixed_depth"):
		mat.set_shader_parameter("fixed_depth", float(room.get_meta("fixed_depth")))
	mat.set_shader_parameter("grain", 0.0)
	var count := maxi(height, 1) if spec[5] else 1
	for i in count:
		var s := Sprite2D.new()
		var tex := AtlasTexture.new()
		tex.atlas = SHEET
		# A stack uses its cap cell on top and the stem below it.
		var row: int = spec[1] + (1 if spec[5] and i > 0 else 0)
		tex.region = Rect2(spec[0] * CELL, row * CELL, spec[2] * CELL, spec[3] * CELL)
		s.texture = tex
		s.centered = false
		s.flip_h = flip
		s.offset = Vector2(-spec[2] * CELL * 0.5, -spec[3] * CELL * (i + 1))
		s.material = mat
		add_child(s)
		_parts.append(s)
	_time = fposmod(global_position.x * 0.037, TAU)


func _process(delta: float) -> void:
	_time += delta
	if _sways:
		# Each stacked cell leans a little further than the one under it — a
		# strand bending, in whole pixels.
		for i in _parts.size():
			_parts[i].position.x = roundf(sin(_time * 1.3 + i * 0.5) * (0.4 + i * 0.55))
	if _flicker:
		var on := sin(_time * 23.0) > -0.82 or sin(_time * 3.1) > 0.3
		modulate.a = 1.0 if on else 0.45
