@tool
class_name SlideZone
extends Area2D
## A stretch of floor that will not hold him: while Hooshang is inside, he is
## dragged along `angle`, his steering is throttled to `control_strength`, and
## jump and dash are gone until he is out. Full control comes back on exit.
##
## Not a Hazard — nothing here kills. It takes the player's footing away and
## lets the room do the rest, which is why it lives in props/zones/ with the
## other volumes-that-do-something rather than in props/hazards/ where
## everything is lethal.
##
## The zone describes the slide; it never writes velocity. Player.enter_slide()
## hands the numbers over and player.gd does the moving, all in one frame order
## — a zone pushing from its own _physics_process would land either side of the
## player's move_and_slide() depending on tree order, and that is a bug that
## only ever shows up in one room.
##
## Drop one in LDtk as a `SlideZone` entity and stretch it over the stretch of
## floor that should be treacherous; the three fields are on the entity.

## Full size of the zone in pixels. LDtk sets this from the box you drag.
@export var size := Vector2(16.0, 16.0):
	set(value):
		size = value
		_update_extents()

## Which way it drags him, in degrees. Screen space, like every other angle in
## Godot: 0 is right and POSITIVE IS DOWNWARD, because +Y points down. So the
## 60 default is a steep slide down and to the right; -60 sends him up-right,
## 120 down-left.
@export var angle := 60.0:
	set(value):
		angle = value
		queue_redraw()

## How much steering he keeps, 0 = none at all, 1 = his usual footing. This
## scales how fast he can change direction, not his top speed — see
## Player._apply_run().
@export_range(0.0, 1.0) var control_strength := 0.35

## How hard the drag builds, in px/s^2. It starts at whatever speed he came in
## with and climbs at this rate, up to the player's own max_slide_speed. 0 makes
## the zone a pure loss-of-control with no push of its own.
@export var speed_ramp := 220.0

## Whether the zone is a piece of floor in its own right. On, it carries a
## walkable surface (ZoneFloor) along its bottom cell and draws the slick tile
## you are standing on. Off only if you are laying it over floor the room
## already has — the original intent, and wrong as a default: a zone that is
## invisible AND intangible is one the player falls through without ever
## learning there was a slide there.
@export var solid := true:
	set(value):
		solid = value
		_update_extents()

## Colour of the editor-only overlay — the box and the drag arrow, which are
## staging aids, not art.
const EDITOR_TINT := Color(0.45, 0.75, 1.0, 0.22)

## The slick floor itself. Drawn a cell at a time with capped ends, the same way
## the glass spikes are; re-generate it with tools/gen_slide_zone.py.
const SHEET := preload("res://assets/props/slide_floor.png")
const CELL := 16.0
enum Tile { SINGLE, FIRST, MIDDLE_A, MIDDLE_B, LAST }

const ZONE_FLOOR_SCENE := preload("res://scenes/props/zones/ZoneFloor.tscn")

var _shape: CollisionShape2D
var _floor: ZoneFloor
var _surface: Node2D
## The player this zone currently holds, so it knows whose slide to end.
var _held: Player


func _ready() -> void:
	collision_layer = 8  # layer 4 "triggers"
	collision_mask = 2   # player only
	_shape = CollisionShape2D.new()
	_shape.shape = RectangleShape2D.new()
	add_child(_shape)
	_surface = Node2D.new()
	_surface.name = "Surface"
	add_child(_surface)
	_update_extents()


## Unit vector the zone drags along.
func direction() -> Vector2:
	return Vector2.RIGHT.rotated(deg_to_rad(angle))


## Nothing here builds anything until _ready has: `_shape` being null means this
## node's own children do not exist yet, which is the state the LDtk importer
## sets `size` in. A child added at import time gets PACKED into the level, and
## then _ready adds a second one at runtime — two colliders, one visible.
func _update_extents() -> void:
	if _shape == null:
		return
	_shape.shape.size = size.max(Vector2.ONE)
	_fit_floor()
	_rebuild_surface()
	queue_redraw()


## Keep the walkable surface in step with the zone box. A child node rather than
## a second shape on this Area2D, because an Area2D's shapes are all detection —
## nothing lands on them.
func _fit_floor() -> void:
	if not solid:
		if _floor != null:
			_floor.queue_free()
			_floor = null
		return
	if _floor == null:
		_floor = ZONE_FLOOR_SCENE.instantiate()
		_floor.name = "Floor"
		add_child(_floor)
	_floor.fit(size)


## Lay the slick tile along the bottom cell — the part you actually stand on.
## Only that cell: the rest of the zone is the air above a slippery floor, and
## painting the whole volume would draw a solid slab over the room.
func _rebuild_surface() -> void:
	if _surface == null:
		return
	for old in _surface.get_children():
		old.free()   # free, not queue_free: this reruns on every size nudge in
					 # the editor, and queued nodes would still be here for the
					 # next pass and stack up.
	if not solid:
		return
	var cells := maxi(int(round(size.x / CELL)), 1)
	var top := size.y * 0.5 - minf(CELL, maxf(size.y, 1.0))
	for i in cells:
		var slab := Sprite2D.new()
		slab.texture = _tile(_variant(i, cells))
		slab.centered = false
		slab.position = Vector2(i * CELL - cells * CELL * 0.5, top)
		_surface.add_child(slab)


## Capped at both ends, alternating in the middle.
func _variant(i: int, cells: int) -> Tile:
	if cells == 1:
		return Tile.SINGLE
	if i == 0:
		return Tile.FIRST
	if i == cells - 1:
		return Tile.LAST
	return Tile.MIDDLE_A if i % 2 else Tile.MIDDLE_B


func _tile(which: Tile) -> AtlasTexture:
	var tex := AtlasTexture.new()
	tex.atlas = SHEET
	tex.region = Rect2(int(which) * CELL, 0.0, CELL, CELL)
	return tex


## Who is in the zone, asked fresh every frame rather than tracked from
## body_entered / body_exited.
##
## Those signals only fire when the boundary is CROSSED, and there are four ways
## to be inside without crossing it: respawning at a checkpoint under the zone, a
## room loading with him already standing in it, the debug picker dropping him
## there, and the frame after any teleport, when the overlap list has not caught
## up yet. The signal version got two of those wrong in opposite directions — it
## left him with full control inside a chute, and it left him sliding forever
## after he respawned two hundred pixels away, off one stale frame.
##
## Re-deriving the whole answer every frame cannot get stuck: a stale frame
## starts or ends the slide one frame early or late, which nobody can see, and
## the next frame corrects it.
func _physics_process(_delta: float) -> void:
	if Engine.is_editor_hint():
		return
	var inside: Player = null
	for body in get_overlapping_bodies():
		if body is Player:
			inside = body
			break
	if inside != null:
		# Only a player sliding on NOTHING, so two overlapping zones do not
		# spend every frame stealing him off each other.
		if not inside.sliding():
			inside.enter_slide(self, direction(), control_strength, speed_ramp)
			_held = inside
	elif _held != null:
		if is_instance_valid(_held):
			_held.exit_slide(self)
		_held = null


## Editor only: the box, and an arrow showing which way it drags. The arrow is
## the whole point of drawing anything — `angle` is a number in an inspector,
## and a number is very easy to get 180 degrees wrong.
func _draw() -> void:
	if not Engine.is_editor_hint():
		return
	draw_rect(Rect2(-size * 0.5, size), EDITOR_TINT)
	var reach: float = minf(size.x, size.y) * 0.35 + 6.0
	var tip := direction() * reach
	var line := Color(EDITOR_TINT, 0.9)
	draw_line(-tip, tip, line, 1.0)
	for side in [140.0, -140.0]:
		draw_line(tip, tip + direction().rotated(deg_to_rad(side)) * 5.0, line, 1.0)
