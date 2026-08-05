@tool
class_name ZoneFloor
extends StaticBody2D
## The walkable surface under a zone volume — the thing that makes a conveyor
## belt or a slide a piece of FLOOR rather than a region of air that happens to
## push you around.
##
## Shared by both zones rather than written twice, because "which physics layer
## is the world" and "where exactly is the top of this thing" are the two facts
## that must not drift between two props the player stands on.
##
## It is the BOTTOM CELL of the zone that is solid, never the whole box: a slide
## dragged three cells tall is a volume you fall through with a slick floor under
## it, not a solid block. For a one-cell prop like the belt, the bottom cell is
## the whole prop, so the same rule gives the obvious answer.

const CELL := 16.0

var _shape: CollisionShape2D


func _ready() -> void:
	collision_layer = 1  # world — this is what the player lands on
	collision_mask = 0   # it never goes looking for anything itself


## Sit the slab in the bottom cell of a zone box of `zone_size`, centred on the
## zone's origin. Built on demand rather than in _ready: the zones are @tool and
## size their contents while the scene is still being assembled, which is before
## any child's _ready has run.
func fit(zone_size: Vector2) -> void:
	if _shape == null:
		_shape = CollisionShape2D.new()
		_shape.shape = RectangleShape2D.new()
		add_child(_shape)
	var height := minf(CELL, maxf(zone_size.y, 1.0))
	(_shape.shape as RectangleShape2D).size = Vector2(maxf(zone_size.x, 1.0), height)
	_shape.position = Vector2(0.0, zone_size.y * 0.5 - height * 0.5)


## World-space y of the surface the player stands on. Public because a zone that
## draws its own floor art has to line the art up with the collider, and reading
## it back beats both of them keeping their own copy of the same number.
func top_y() -> float:
	if _shape == null:
		return global_position.y
	var height: float = (_shape.shape as RectangleShape2D).size.y
	return global_position.y + _shape.position.y - height * 0.5
