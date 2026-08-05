@tool
class_name ConveyorBeltVisual
extends Node2D
## What a ConveyorBelt looks like: a grimy rubber-and-steel belt laid into the
## floor, its tread scrolling, with an amber chevron recessed in the skirt every
## few cells pointing the way it carries you.
##
## This node knows nothing about the belt except what it is told. `set_belt()`
## is the ONLY input — there is deliberately no exported direction or speed
## here, because two copies of "which way does this go" is two chances for the
## art to disagree with the physics, and a belt whose arrows lie is worse than a
## belt with no arrows at all.
##
## The strip is built a 16px cell at a time from assets/props/conveyor_belt.png:
## a static base layer (skirt, rubber, roller drums, capped at both ends), a
## tread layer of transparent cleats drawn over it, and the chevrons on top.
## Only the tread layer animates, and it animates by swapping which 16px column
## of the sheet it points at — 8 phases, one per pixel of an 8px cleat spacing,
## so the loop is exact and every step is a whole pixel. Re-generate the art
## with tools/gen_conveyor_belt.py.
##
## @tool, so all of this has to survive being poked before _ready: the layers
## are made on demand and `set_belt` is safe to call at any point.

## Mirrors ConveyorBelt.Direction. Kept as plain ints rather than referencing
## that class, so the two scripts can be edited independently and a belt whose
## logic is mid-rewrite can never stop the art from parsing.
const LEFT := 0
const RIGHT := 1

const SHEET := preload("res://assets/props/conveyor_belt.png")
const CELL := 16.0

## Sheet rows. Base tiles across row 0, one row of tread phases per silhouette,
## the two chevrons on the last row.
const ROW_BASE := 0
const ROW_TREAD_MID := 1
const ROW_TREAD_CAP_LEFT := 2
const ROW_TREAD_CAP_RIGHT := 3
const ROW_TREAD_SINGLE := 4
const ROW_ARROW := 5

## Base tile order, shared with the glass spikes and every other strip prop:
## [single][first][middle A][middle B][last].
enum Base { SINGLE, CAP_LEFT, MID_A, MID_B, CAP_RIGHT }

## Which row of tread phases fits which base tile. Middles share one, the ends
## have their own so the cleats follow the curve and stay off the roller.
const TREAD_ROW := {
	Base.SINGLE: ROW_TREAD_SINGLE,
	Base.CAP_LEFT: ROW_TREAD_CAP_LEFT,
	Base.MID_A: ROW_TREAD_MID,
	Base.MID_B: ROW_TREAD_MID,
	Base.CAP_RIGHT: ROW_TREAD_CAP_RIGHT,
}

## Phases in the tread loop, and equally the cleat spacing in pixels — the two
## are the same number because each phase is the cleats moved exactly 1px.
const TREAD_FRAMES := 8

## Cells between chevrons. Close enough that a belt is never ambiguous from a
## standing start, far enough that a long one is not a runway of arrows.
const ARROW_EVERY := 4

var _direction := RIGHT
var _speed := 0.0
var _size := Vector2(CELL * 4.0, CELL)

## Distance the tread has travelled, wrapped to one loop. Kept as a float so a
## slow belt still creeps: the DISPLAYED phase is this floored, so the art moves
## in whole pixels while the underlying rate stays exactly `speed`.
var _scroll := 0.0
var _phase := 0

var _base_layer: Node2D
var _tread_layer: Node2D
var _arrow_layer: Node2D

## One AtlasTexture per tread row, shared by every cell that uses it — moving
## its region moves every cleat on the belt in one assignment.
var _tread_tex := {}


func _ready() -> void:
	_rebuild()


## The whole interface. The logic node calls this whenever anything changes:
## `direction` is ConveyorBelt.Direction (0 = LEFT, 1 = RIGHT), `speed` is a
## positive px/sec, `size` is the zone's full size and the belt is size.x wide
## and one cell tall, centred on the origin.
func set_belt(direction: int, speed: float, size: Vector2) -> void:
	_direction = LEFT if direction == LEFT else RIGHT
	_speed = maxf(speed, 0.0)
	_size = size
	_rebuild()


func _process(delta: float) -> void:
	if _speed <= 0.0 or _tread_tex.is_empty():
		return
	_scroll = fposmod(_scroll + _speed * delta * _sign(), float(TREAD_FRAMES))
	var phase := int(_scroll)
	if phase != _phase:
		_phase = phase
		_apply_phase()


func _sign() -> float:
	return -1.0 if _direction == LEFT else 1.0


func _rebuild() -> void:
	_ensure_layers()
	for layer in [_base_layer, _tread_layer, _arrow_layer]:
		for old in layer.get_children():
			old.free()   # free, not queue_free: this reruns every time the zone
						 # is nudged in the editor, and queued nodes would still
						 # be here on the next pass and stack up.
	_tread_tex.clear()
	var cells := maxi(int(round(_size.x / CELL)), 1)
	var left := -cells * CELL * 0.5
	var top := -CELL * 0.5
	for i in cells:
		var variant := _variant(i, cells)
		var x := left + i * CELL
		_base_layer.add_child(_sprite(_atlas(int(variant), ROW_BASE), x, top))
		_tread_layer.add_child(_sprite(_tread_texture(TREAD_ROW[variant]), x, top))
	var arrow := _atlas(0 if _direction == RIGHT else 1, ROW_ARROW)
	for i in _arrow_cells(cells):
		_arrow_layer.add_child(_sprite(arrow, left + i * CELL, top))


## Capped at both ends, alternating in the middle, so a long belt does not read
## as one stamp repeated.
func _variant(i: int, cells: int) -> Base:
	if cells == 1:
		return Base.SINGLE
	if i == 0:
		return Base.CAP_LEFT
	if i == cells - 1:
		return Base.CAP_RIGHT
	return Base.MID_A if i % 2 else Base.MID_B


## Which cells carry a chevron: every ARROW_EVERY cells, centred over the run,
## and never on a roller cap unless the belt is too short to have anything else.
func _arrow_cells(cells: int) -> Array:
	var first := 1
	var last := cells - 2
	if last < first:
		return [cells / 2]
	var span := last - first + 1
	var count := maxi(1, span / ARROW_EVERY)
	var used := (count - 1) * ARROW_EVERY + 1
	var start := first + (span - used) / 2
	var out := []
	for k in count:
		out.append(start + k * ARROW_EVERY)
	return out


func _ensure_layers() -> void:
	if _base_layer != null:
		return
	_base_layer = _layer("Base")
	_tread_layer = _layer("Tread")
	_arrow_layer = _layer("Arrows")


## Three plain Node2Ds, added back to front — draw order is tree order, so the
## cleats land on the rubber and the chevrons on top of both with no z_index to
## get out of step with anything else in the room.
func _layer(node_name: String) -> Node2D:
	var node := Node2D.new()
	node.name = node_name
	add_child(node)
	return node


func _sprite(tex: Texture2D, x: float, y: float) -> Sprite2D:
	var s := Sprite2D.new()
	s.texture = tex
	s.centered = false
	s.position = Vector2(x, y)
	return s


func _atlas(col: int, row: int) -> AtlasTexture:
	var tex := AtlasTexture.new()
	tex.atlas = SHEET
	tex.region = Rect2(col * CELL, row * CELL, CELL, CELL)
	return tex


func _tread_texture(row: int) -> AtlasTexture:
	if not _tread_tex.has(row):
		_tread_tex[row] = _atlas(_phase, row)
	return _tread_tex[row]


func _apply_phase() -> void:
	for row in _tread_tex:
		var tex: AtlasTexture = _tread_tex[row]
		tex.region = Rect2(_phase * CELL, row * CELL, CELL, CELL)
