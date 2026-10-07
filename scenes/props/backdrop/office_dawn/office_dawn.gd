extends Node2D
## Dawn occupies only the authored glass apertures; the cubicle, sash and
## mullions keep their original artwork and receive the actual window lights.

func _ready() -> void:
	var unshaded := CanvasItemMaterial.new()
	unshaded.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	material = unshaded
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var room := get_parent() as Node2D
	var ancestor := room.get_parent()
	while ancestor != null and not ancestor is LdtkWorld:
		ancestor = ancestor.get_parent()
	var world := ancestor as LdtkWorld
	if world != null:
		var follow := func(_room: Node2D) -> void:
			for light_name in ["DawnGlowRoom26", "DawnSpillRoom26a", "DawnSpillRoom26b", "SunShaftRoom26"]:
				world.get_node("Lights/" + light_name).visible = world.is_room_active(room) and not get_meta("window_excluded", false)
		world.room_changed.connect(follow)
		world.transition_started.connect(follow)
		follow.call(room)

func _draw() -> void:
	for pane: Rect2 in OfficeWindowPanes.for_room("Level_26"):
		for y in range(int(pane.position.y), int(pane.end.y)):
			var height := clampf((y - 47.0) / 48.0, 0.0, 1.0)
			var sky := Color("777a9b").lerp(Color("f4b878"), height)
			draw_rect(Rect2(pane.position.x, y, pane.size.x, 1), sky)
			# The low sun is clipped by the glass just like the sky, never drawn
			# over the window frame. Native pixels keep its edge crisp.
			for x in range(int(pane.position.x), int(pane.end.x)):
				if Vector2(x, y).distance_to(Vector2(235, 93)) <= 12.0:
					draw_rect(Rect2(x, y, 1, 1), Color("ffedb5"))
