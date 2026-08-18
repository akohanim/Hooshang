@tool
class_name Platform
extends StaticBody2D
## A suspended office-ceiling panel you can stand on, any number of cells wide.
##
## Placed by hand in LDtk and turned into this node by
## scripts/ldtk_entities_post_import.gd, which is why `size` is an export with a
## setter rather than something read once in _ready: the importer hands it the
## rectangle the level author dragged, and the editor preview has to follow the
## same path.
##
## THE ART IS A REPEATING UNIT, not a stretched sprite. tools/gen_platforms.py
## cuts one 24x8 tile out of the source render, and this lays copies of it end to
## end — a stretched sprite would smear the ceiling grid and put the standing lip
## at a different thickness on every platform in the game.
##
## One cell tall by definition. A platform is a LEDGE; two cells of it reads as
## architecture and stops being something you land on, and the collision box
## would then be as tall as Hooshang is (12px).
##
## Solid on every side, not one-way. The source art has a lit underside and a
## hanger rail, so it is a thing in the room rather than a ledge you pop up
## through, and a one-way version would want its own art and its own entity.

## The repeating unit, matching tools/gen_platforms.py.
const TILE := Vector2(24.0, 8.0)
## The LDtk grid. Widths snap to this, so a platform can never land half a cell
## out from the geometry around it.
const CELL := 8.0

const PLAIN := preload("res://assets/props/platform/solid.png")
const LIT := preload("res://assets/props/platform/solid_lit.png")

## The rectangle it fills, in px. Width is snapped to whole cells and the height
## is forced to one — see the note above.
@export var size := Vector2(72.0, 8.0):
	set(value):
		size = Vector2(maxf(snappedf(value.x, CELL), CELL), CELL)
		_rebuild()
## A lit ceiling panel every Nth tile. 0 = none. The light panels are what say
## "office ceiling" rather than "grey ledge", but one in every tile reads as a
## strip light, so they are spaced.
@export var lit_every := 2:
	set(value):
		lit_every = maxi(value, 0)
		_rebuild()

var _visual: Node2D
var _shape: CollisionShape2D


func _ready() -> void:
	# Layer 1 "world" so the player's mask already sees it, the same as the
	# tilemap. Nothing needs to mask against platforms specifically.
	collision_layer = 1
	collision_mask = 0
	_rebuild()


## Lay the tiles out and size the box. Safe to call at any time; it throws away
## whatever it built last.
func _rebuild() -> void:
	if not is_inside_tree():
		return
	if _visual == null:
		_visual = Node2D.new()
		_visual.name = "Visual"
		add_child(_visual)
	if _shape == null:
		_shape = CollisionShape2D.new()
		_shape.name = "Shape"
		_shape.shape = RectangleShape2D.new()
		add_child(_shape)
	for child in _visual.get_children():
		child.queue_free()

	(_shape.shape as RectangleShape2D).size = size
	# CENTRED on the node, which is the convention every other sized prop in the
	# project uses (Hazard puts its rect at -size/2, GlassSpikes draws from
	# -CELL/2) and which matches the LDtk entity pivot of 0.5. Drawing from the
	# corner instead was the first version and it places every platform half its
	# own width and half a cell off, in a way that looks deliberate.
	_shape.position = Vector2.ZERO

	var count := int(ceilf(size.x / TILE.x))
	for i in count:
		var tile := Sprite2D.new()
		tile.texture = LIT if lit_every > 0 and i % lit_every == 0 else PLAIN
		tile.centered = false
		tile.position = Vector2(i * TILE.x, 0.0) - size * 0.5
		# The last tile is clipped rather than allowed to overhang: a platform
		# whose art runs past its own collision is a ledge you cannot stand on
		# the end of, which is the exact complaint footing_width exists for.
		var over := size.x - i * TILE.x
		if over < TILE.x:
			tile.region_enabled = true
			tile.region_rect = Rect2(0.0, 0.0, over, TILE.y)
		_visual.add_child(tile)
	_after_rebuild()


## Hook for subclasses that need to rebuild their own bits alongside the art.
func _after_rebuild() -> void:
	pass


## The top surface, in global coordinates — what "standing on it" is measured
## against.
func top_y() -> float:
	return global_position.y - size.y * 0.5
