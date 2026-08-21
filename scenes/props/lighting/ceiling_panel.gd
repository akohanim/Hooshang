@tool
class_name CeilingPanel
extends LampFixture
## A run of suspended office ceiling with a light panel set into it.
##
## The fixture is not hung from the ceiling — it IS the ceiling: T-bar grid,
## acoustic tiles, and one cell where a flat luminous panel sits flush where a
## tile would otherwise be. Placed along a room's ceiling line rather than
## dangling into the room.
##
## EXTENDS LampFixture, the same way GlassSpikes extends Hazard: colour, energy,
## pool size, the `lights` group and the flicker all come from there and cannot
## drift out of step with every other light in the Act.
##
## THE ART IS A REPEATING UNIT, not a stretched sprite — the same 24x8 cell
## `tools/gen_platforms.py` cuts its ceiling strip at, and for the same reason.
## Stretching would smear the grid and give every instance a different rail
## thickness. `run_tiles` copies are laid end to end and the MIDDLE one is the
## panel, so the node's position is the panel and the ceiling grows evenly
## either side of it.
##
## THE PANEL'S GLOW IS A LIGHT, NOT A SPRITE, and that is why this is not just a
## picture of a ceiling. `CanvasModulate` is 0.05 in Act I and multiplies every
## CanvasItem, so a painted luminous panel arrives at 5% of what was drawn —
## the trap SunShaft and WallPattern document. The glow is a PointLight2D
## wearing `ceiling_light_glow.png`: the panel's shape is art, its brightness is
## light. The tiles around it are ordinary paint, lit by the panel between them.
##
## Because the glow is a light, the flicker reaches it for free — `_process`
## reads the pool's energy back rather than recomputing the waveform, so the two
## cannot drift. A panel whose pool stutters while its face burns steadily reads
## as a bug in the game rather than a fault in the building.
##
## `light_energy = 0` with `panel_energy = 0` gives a DEAD panel: the frame is
## still in the grid, nothing comes out of it. It needs another light near it or
## there is nothing to see, which is the whole point of leaving one where the
## moon can find it.
##
## IT IS ALSO SOLID. A suspended ceiling is a thing in the room, not a picture of
## one, and a jump that goes up through the tiles says so immediately. The body
## is built from the run rather than placed, so it is exactly as wide as the art
## is — including the rounding up to an odd cell count, which a hand-drawn
## collider would silently disagree with the first time somebody dragged a run
## to an even width.

## The repeating unit, matching tools/gen_ceiling_panel.py.
const TILE := Vector2(24.0, 8.0)

const PLAIN := preload("res://assets/props/ceiling/ceiling_tile.png")
const PANEL := preload("res://assets/props/ceiling/ceiling_light.png")
## What this prop's own panel emits — the 24px cell's glow. Instances that light
## a painted 8px cell override it; see `panel_texture`.
const PANEL_GLOW := preload("res://assets/props/ceiling/ceiling_light_glow.png")

## How many cells of ceiling to lay, panel included. Forced ODD: the panel is
## the middle cell, and an even run has no middle — it would put the light half
## a tile off the position you placed it at.
@export var run_tiles := 5:
	set(value):
		run_tiles = maxi(value, 1) | 1
		_rebuild()
## How brightly the panel's own face reads, separate from the pool it throws.
## Two different jobs: the pool is how far the light carries, this is how bright
## the thing looks. Turning the pool down without this leaves a dim room lit by
## a panel that still looks brand new.
@export var panel_energy := 1.6:
	set(value): panel_energy = value; _apply()
## How far BELOW the ceiling the room pool is centred.
##
## The one honest fudge here, and it is the same trade LIGHTING.md already makes
## for hanging lamps. A panel in the ceiling is ~164px above this room's floor,
## so a pool centred on it needs a 164px radius to reach the ground — and that
## is wider than half a room, which puts it straight through the seam into the
## room next door. Dropping the POOL (not the fixture) keeps the reach honest
## and the rooms independent; the panel is still visibly the thing it comes from.
@export var pool_drop := 50.0:
	set(value): pool_drop = value; _apply()
## The panel's emission, worn by the light as its texture.
##
## Per instance because the SAME fixture is used at two scales: the prop draws a
## 24px cell whose panel is 17px across, and the painted `ceiling` tile is an 8px
## cell whose panel is 5. A glow made for the wrong one either floats past the
## tile's frame or sits inside it looking like a chip of paint.
@export var panel_texture: Texture2D = PANEL_GLOW:
	set(value): panel_texture = value; _apply()
## WHICH cell of the run is the lit one, counted from the middle. 0 is the
## middle; -1 is one cell left, +1 one right.
##
## What it is for: two runs stacked into a two-row ceiling put their panels in
## the same column and the result reads as vertical PAIRS rather than as a
## ceiling. Offsetting the lower row by one breaks that up without moving either
## run, so both still span the same stretch of wall and neither end goes ragged.
##
## The light moves with the panel, obviously — but it is worth saying, because
## the panel is art and the light is a separate node sitting at the fixture's
## origin, and the two would otherwise part company the moment this is not 0.
@export var panel_offset := 0:
	set(value): panel_offset = value; _apply()

@export_group("Motion sensor")
## How close he has to get before this fixture wakes up, in px. **0 keeps it
## simply on**, which is what every panel placed before this existed does.
##
## Measured to the POOL, not to the fixture. The fixture is in the ceiling and he
## walks on the floor ~164px below it, so a radius to the fixture would have to
## be enormous before it ever tripped, and every number a designer typed would be
## off by the height of the room. `glow` already sits `pool_drop` below the panel
## — where the light actually lands — so a range measured from there is a range
## measured from the bit of floor the fixture lights.
@export var motion_range := 0.0:
	set(value): motion_range = maxf(value, 0.0); _apply()
## How long it takes to come up, and to go back down, in seconds. 0 snaps.
@export var motion_fade := 0.25:
	set(value): motion_fade = maxf(value, 0.0)
## Whether the run stops the player, or is scenery he passes through.
##
## On, because this IS the ceiling. Also gated on `show_body`: a run that draws
## nothing has nothing to bump into, and that is not a corner case — it is the
## CeilingLight variant, which exists to light a PAINTED 8px cell whose tile
## already carries the room's own collision. A solid body there would put an
## invisible slab in front of the tiles it is lighting.
@export var solid := true:
	set(value): solid = value; _rebuild()

## World geometry, the same layer the room's tilemap is on. Mask 0: it is a wall,
## it does not go looking for anything.
const SOLID_LAYER := 1

@onready var panel: PointLight2D = $Panel

var _tiles: Node2D
var _body: StaticBody2D
var _body_shape: CollisionShape2D
## How far up this fixture currently is, 0..1. Sensored panels start at 0 — dark
## until something walks under them — and unsensored ones sit at 1 forever.
var _lit := 1.0
## Who it is watching for, re-found when he is replaced. A respawn frees the old
## player, so holding this across one leaves the fixture watching a dead node and
## dark for the rest of the run.
var _watched: Node2D = null


func _ready() -> void:
	super()
	_rebuild()


func _apply() -> void:
	super()
	if panel == null:
		return
	# A sensored fixture is OFF until it sees him. Starting lit means every panel
	# in the room is on for the first frame of the room, which reads as the
	# lights failing rather than as a sensor arming.
	if motion_range > 0.0 and not Engine.is_editor_hint():
		_lit = 0.0
	# The inherited cable and bulb are the greybox lamp's body. This fixture has
	# no body hanging in the room at all — it is in the ceiling.
	cable.visible = false
	bulb.visible = false
	panel.energy = panel_energy
	panel.texture = panel_texture
	var across := (_lit_cell() - run_tiles / 2) * TILE.x
	panel.position = Vector2(across, 0.0)
	glow.position = Vector2(across, pool_drop)
	_rebuild()


## Lay the run out. Safe to call at any time; it throws away what it built last.
func _rebuild() -> void:
	if not is_inside_tree():
		return
	if _tiles == null:
		_tiles = Node2D.new()
		_tiles.name = "Tiles"
		add_child(_tiles)
	for child in _tiles.get_children():
		child.queue_free()
	_tiles.visible = show_body
	var middle := run_tiles / 2
	var lit := _lit_cell()
	for i in run_tiles:
		var cell := Sprite2D.new()
		cell.texture = PANEL if i == lit else PLAIN
		cell.position = Vector2((i - middle) * TILE.x, 0.0)
		_tiles.add_child(cell)
	_fit_body()


## Size the collider to the run that was just laid.
##
## The body is kept and resized rather than freed and rebuilt with the tiles.
## Dragging a run out to a width in LDtk re-enters this on every cell, and a
## collision node that comes and goes under a physics server mid-frame is a
## class of crash nobody should have to reproduce.
func _fit_body() -> void:
	if _body == null:
		_body = StaticBody2D.new()
		_body.name = "Solid"
		_body.collision_layer = SOLID_LAYER
		_body.collision_mask = 0
		_body_shape = CollisionShape2D.new()
		# Named, or Godot invents one like "@CollisionShape2D@37" and nothing can
		# path to it — including the test that checks the collider is there.
		_body_shape.name = "CollisionShape2D"
		_body_shape.shape = RectangleShape2D.new()
		_body.add_child(_body_shape)
		add_child(_body)
	var box: RectangleShape2D = _body_shape.shape
	# Centred on the node, like the art: an odd run puts its middle cell on the
	# origin, so the whole strip is symmetric about it however wide it gets.
	box.size = Vector2(TILE.x * run_tiles, TILE.y)
	_body_shape.disabled = not (solid and show_body)


## Index of the panel cell, clamped into the run. An offset that would push it
## off the end lights the end cell instead of nothing at all — a run with no
## panel in it is indistinguishable from a bulb that has gone, and this is a
## typo, not a design decision.
func _lit_cell() -> int:
	return clampi(run_tiles / 2 + panel_offset, 0, run_tiles - 1)


func _process(delta: float) -> void:
	super(delta)
	if Engine.is_editor_hint() or panel == null or glow == null:
		return
	_tick_motion(delta)
	# The pool as the FLICKER left it, before the sensor gets a say. Read back off
	# glow only in the flickering case — that is the one where super() just wrote
	# it, from light_energy rather than from its own last value. Reading it back
	# in the steady case instead would multiply this frame's fade into last
	# frame's, and a fixture that is meant to hold at half would sink to nothing
	# over a second.
	var flickered := glow.energy if flickers else light_energy
	glow.energy = flickered * _lit
	# Keep the panel's face in step with the pool. Read back off the pool rather
	# than recomputing the flicker, so there is one waveform and no drift — and
	# so the sensor's fade reaches the face for free.
	panel.energy = panel_energy * (glow.energy / maxf(light_energy, 0.0001))


## Walk `_lit` toward whether he is standing in range.
func _tick_motion(delta: float) -> void:
	if motion_range <= 0.0:
		_lit = 1.0
		return
	if not is_instance_valid(_watched):
		_watched = get_tree().get_first_node_in_group("player") as Node2D
	var want := 0.0
	if _watched != null and is_instance_valid(_watched) \
			and glow.global_position.distance_to(_watched.global_position) <= motion_range:
		want = 1.0
	if motion_fade <= 0.0:
		_lit = want
		return
	_lit = move_toward(_lit, want, delta / motion_fade)
