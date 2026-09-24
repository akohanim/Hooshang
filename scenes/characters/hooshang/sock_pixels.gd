extends Node2D
## Keep the two Aseprite ankle marks one GAME pixel under sprite reduction,
## facing changes, swimming rotation and Juice's squash/stretch. No new art:
## source frame coordinates come from the same Aseprite export as SpriteFrames.

@onready var _visual: AnimatedSprite2D = get_parent().get_node("SpriteSquash/Visual")


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	if not is_instance_valid(_visual) or not _visual.is_visible_in_tree():
		return
	var frames := _visual.sprite_frames
	if not frames.get_meta("child_hooshang", false):
		return
	var clips: Dictionary = frames.get_meta("sock_pixels", {})
	var positions: Array = clips.get(String(_visual.animation), [])
	if _visual.frame >= positions.size():
		return
	var texture := frames.get_frame_texture(_visual.animation, _visual.frame)
	var center := texture.get_size() * 0.5 if _visual.centered else Vector2.ZERO
	var visual_to_screen := _visual.get_global_transform_with_canvas()
	# Cancel this node's transform only for the marks. Rounding in the actual
	# game viewport keeps each mark exactly 1x1 even with a fractional camera.
	draw_set_transform_matrix(get_global_transform_with_canvas().affine_inverse())
	for point: Vector2 in positions[_visual.frame]:
		var local_point := point + Vector2(0.5, 0.5) - center
		if _visual.flip_h:
			local_point.x = -local_point.x
		if _visual.flip_v:
			local_point.y = -local_point.y
		var screen_point := visual_to_screen * (local_point + _visual.offset)
		draw_rect(Rect2(screen_point.floor(), Vector2.ONE), Color.WHITE)
