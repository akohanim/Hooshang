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

## The repeating unit, matching tools/gen_ceiling_panel.py.
const TILE := Vector2(24.0, 8.0)

const PLAIN := preload("res://assets/props/ceiling/ceiling_tile.png")
const PANEL := preload("res://assets/props/ceiling/ceiling_light.png")

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

@onready var panel: PointLight2D = $Panel

var _tiles: Node2D


func _ready() -> void:
	super()
	_rebuild()


func _apply() -> void:
	super()
	if panel == null:
		return
	# The inherited cable and bulb are the greybox lamp's body. This fixture has
	# no body hanging in the room at all — it is in the ceiling.
	cable.visible = false
	bulb.visible = false
	panel.energy = panel_energy
	glow.position = Vector2(0.0, pool_drop)
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
	for i in run_tiles:
		var cell := Sprite2D.new()
		cell.texture = PANEL if i == middle else PLAIN
		cell.position = Vector2((i - middle) * TILE.x, 0.0)
		_tiles.add_child(cell)


func _process(delta: float) -> void:
	super(delta)
	if Engine.is_editor_hint() or panel == null or glow == null:
		return
	# Keep the panel's face in step with the pool. Read back off the pool rather
	# than recomputing the flicker, so there is one waveform and no drift.
	panel.energy = panel_energy * (glow.energy / maxf(light_energy, 0.0001))
