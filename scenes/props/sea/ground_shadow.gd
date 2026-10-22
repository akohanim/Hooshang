class_name GroundShadow
extends Sprite2D
## A soft shadow on the ground under whatever it is added to (the way home's
## tigers): found by a ray straight down onto the world each frame, so it stays
## on the ground when its owner leaps, shrinking and fading with the height. It
## lies ON the ground's top row, so it draws one z above the terrain (at the
## terrain's own z it came out underneath it, the tigers being added to the world
## before its rooms draw).

## The widest it gets (its owner on the ground), px.
@export var width := 24
## Above this height over the ground it is gone, px.
@export var reach := 48.0
## How dark at its middle, on the ground.
@export var strength := 0.34

var _sizes := {}


func _ready() -> void:
	texture = _ellipse(width)
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	centered = false
	z_as_relative = false
	z_index = 1


func _physics_process(_delta: float) -> void:
	var owner_node := get_parent() as Node2D
	if owner_node == null or not owner_node.is_visible_in_tree():
		visible = false
		return
	var from := owner_node.global_position + Vector2(0, -4)
	var query := PhysicsRayQueryParameters2D.create(from, from + Vector2(0, reach + 4.0), 1)
	var hit := get_world_2d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		visible = false
		return
	var height := maxf(0.0, (hit.position as Vector2).y - owner_node.global_position.y)
	var k := 1.0 - height / reach
	visible = k > 0.05
	# Whole-pixel widths, two apart, so it stays centred as it shrinks.
	var w := maxi(6, int(round(width * (0.55 + 0.45 * k) / 2.0)) * 2)
	if not _sizes.has(w):
		_sizes[w] = _ellipse(w)
	texture = _sizes[w]
	offset = Vector2(-w * 0.5, -1.0)
	modulate.a = 0.35 + 0.65 * k
	global_position = Vector2(round(owner_node.global_position.x), (hit.position as Vector2).y)


## Darkest in the middle, two steps out to the rim: soft, but still pixels.
func _ellipse(w: int) -> ImageTexture:
	var img := Image.create(w, 4, false, Image.FORMAT_RGBA8)
	for x in w:
		for y in 4:
			var d := absf(x + 0.5 - w / 2.0) / (w / 2.0) + absf(y - 1.5) / 2.0
			if d < 1.0:
				img.set_pixel(x, y, Color(0, 0, 0, strength * (1.0 if d < 0.55 else 0.55)))
	return ImageTexture.create_from_image(img)
