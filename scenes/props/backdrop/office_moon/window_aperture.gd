class_name WindowAperture
extends RefCounted
## Share the same glass geometry across the disc, atmosphere and eclipse shadow.
## Duplicate materials per sprite so different rooms cannot overwrite each other.
static func apply(sprite: Sprite2D, openings: Array, offset := Vector2.ZERO) -> void:
	if not sprite.has_meta("aperture_material"):
		sprite.material = sprite.material.duplicate()
		sprite.set_meta("aperture_material", true)
	var material := sprite.material as ShaderMaterial
	var packed := PackedVector4Array()
	for opening: Rect2 in openings:
		packed.append(Vector4(opening.position.x, opening.position.y, opening.size.x, opening.size.y))
	material.set_shader_parameter("pane_count", mini(packed.size(), 32))
	packed.resize(32)
	material.set_shader_parameter("panes", packed)
	var bounds := sprite.transform * sprite.get_rect()
	bounds.position += offset
	material.set_shader_parameter("sprite_rect", Vector4(bounds.position.x, bounds.position.y, bounds.size.x, bounds.size.y))
