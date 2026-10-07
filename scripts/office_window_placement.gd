class_name OfficeWindowPlacement
extends RefCounted
## Place office window frames wholly in free wall space. Lights travel with them.
const FRAME := Rect2(-24, -32, 48, 64)
const GAP := 4.0

static func obstacles(room: Node2D) -> Array[Rect2]:
	var out: Array[Rect2] = []
	for child in room.get_children():
		if child is TileMapLayer and child.visible and not str(child.name).ends_with("-values") and child.z_index >= 0:
			for cell in child.get_used_cells():
				var size := Vector2(child.tile_set.tile_size)
				out.append(Rect2(child.position + child.map_to_local(cell) - size * 0.5, size))
	var entities := room.get_node_or_null("Entities")
	if entities:
		_prop_bounds(entities, room, out)
	# Hand-placed furniture is a sibling of imported rooms.
	var world := room.get_parent()
	while world != null and not world is LdtkWorld:
		world = world.get_parent()
	if world is LdtkWorld:
		var props := world.get_node_or_null("Props")
		if props: _prop_bounds(props, room, out)
	return out

static func _prop_bounds(node: Node, room: Node2D, out: Array[Rect2]) -> void:
	if node is CanvasItem and not node.is_visible_in_tree(): return
	var rect := Rect2()
	if node is Sprite2D and node.texture != null:
		rect = node.get_rect()
	elif node is AnimatedSprite2D and node.sprite_frames != null:
		var texture: Texture2D = node.sprite_frames.get_frame_texture(node.animation, node.frame)
		if texture: rect = Rect2(-texture.get_size() * 0.5, texture.get_size())
	elif node is Control:
		rect = Rect2(Vector2.ZERO, node.size)
	elif node is Polygon2D and not node.polygon.is_empty():
		rect = Rect2(node.polygon[0], Vector2.ZERO)
		for point in node.polygon: rect = rect.expand(point)
	elif node is CollisionShape2D and node.get_parent() is PhysicsBody2D and node.shape != null:
		rect = node.shape.get_rect()
	if rect.has_area():
		out.append(room.global_transform.affine_inverse() * node.get_global_transform() * rect)
	for child in node.get_children(): _prop_bounds(child, room, out)

static func clear(rect: Rect2, bounds: Rect2, blocked: Array[Rect2]) -> bool:
	if not bounds.encloses(rect.grow(GAP)): return false
	for obstacle in blocked:
		if rect.grow(GAP).intersects(obstacle): return false
	return true

static func find_position(preferred: Vector2, shape: Rect2, bounds: Rect2, blocked: Array[Rect2]) -> Vector2:
	if clear(Rect2(preferred + shape.position, shape.size), bounds, blocked): return preferred
	var best := Vector2.INF
	var distance := INF
	for y in range(int(bounds.position.y - shape.position.y + GAP), int(bounds.end.y - shape.end.y - GAP) + 1, 8):
		for x in range(int(bounds.position.x - shape.position.x + GAP), int(bounds.end.x - shape.end.x - GAP) + 1, 8):
			var point := Vector2(x, y)
			var score := point.distance_squared_to(preferred)
			if score < distance and clear(Rect2(point + shape.position, shape.size), bounds, blocked):
				best = point
				distance = score
	return best

static func apply(world: LdtkWorld) -> void:
	var backdrop := world.get_node_or_null("Backdrop")
	if backdrop == null: return
	var blocked_by_room: Dictionary = {}
	for room in world.rooms:
		blocked_by_room[room] = obstacles(room)
		_place_baked(world, room, blocked_by_room[room])
	for window in backdrop.get_children():
		if not window is MoonWindow and not str(window.name).begins_with("DawnWindow"): continue
		var room: Node2D = null
		# Names establish ownership even after LDtk rearranges the world canvas.
		var label := str(window.name)
		var identifier := ""
		if label.begins_with("OfficeWindow_"):
			identifier = label.trim_prefix("OfficeWindow_").rsplit("_", true, 1)[0]
		else:
			identifier = "Level_" + label.get_slice("Room", 1).trim_suffix("B")
		for candidate in world.rooms:
			if str(candidate.name).to_lower() == identifier.to_lower(): room = candidate; break
		if room == null:
			for candidate in world.rooms:
				if world.room_rect(candidate).has_point(world.to_local(window.global_position)): room = candidate; break
		var pool_name := label + "Pool" if label.begins_with("OfficeWindow_") else label.replace("MoonWindow", "MoonGlow").replace("DawnWindow", "DawnGlow")
		var pool := world.get_node_or_null("Lights/" + pool_name) as Node2D
		if room == null or world._room_has_music_puzzle(room):
			window.hide()
			window.set_meta("window_excluded", true)
			if pool: pool.hide()
			continue
		window.set_meta("window_room", room)
		if not window.visible: continue
		var bounds := world.room_rect(room)
		bounds.position -= room.position
		var preferred := room.to_local(window.global_position)
		if not bounds.has_point(preferred): preferred = bounds.get_center() + Vector2(0, -24)
		var blocked: Array[Rect2] = blocked_by_room[room]
		var point := find_position(preferred, FRAME, bounds, blocked)
		if point == Vector2.INF:
			window.hide()
			window.set_meta("window_excluded", true)
			if pool: pool.hide()
			continue
		var movement: Vector2 = room.to_global(point) - window.global_position
		window.global_position += movement
		if pool: pool.global_position += movement
		blocked.append(Rect2(point + FRAME.position, FRAME.size))
		window.set_meta("placement_rect", Rect2(point + FRAME.position, FRAME.size))


static func _place_baked(world: LdtkWorld, room: Node2D, blocked: Array[Rect2]) -> void:
	var existing := room.get_node_or_null("RoomBackdrop/WindowCutout0")
	if existing != null:
		for cutout in existing.get_parent().get_children():
			if not str(cutout.name).begins_with("WindowCutout"): continue
			if world._room_has_music_puzzle(room): cutout.hide()
			elif cutout.visible: blocked.append(cutout.get_meta("placement_rect"))
		return
	var panes := OfficeWindowPanes.for_room(str(room.name))
	if panes.is_empty(): return
	var panel := room.get_node_or_null("RoomBackdrop") as TextureRect
	if panel == null or panel.material is not ShaderMaterial: return
	var frame: Rect2 = panes[0]
	for pane: Rect2 in panes: frame = frame.merge(pane)
	frame = frame.grow(4)
	var source_regions: Array = world.room_moon_regions.get(str(room.name), [])
	if source_regions.is_empty(): return
	var bounds := Rect2(Vector2.ZERO, panel.size)
	var erased := PackedVector4Array()
	var base_material: ShaderMaterial = panel.material.duplicate()
	for i in source_regions.size():
		var shift: Vector2 = source_regions[i].get_center() - source_regions[0].get_center()
		var original := Rect2(frame.position + shift, frame.size).intersection(bounds)
		erased.append(Vector4(original.position.x, original.position.y, original.size.x, original.size.y))
		var at := Vector2.INF
		var fit_scale := 1.0
		if not world._room_has_music_puzzle(room):
			for candidate_scale: float in [1.0, 0.75, 0.5]:
				at = find_position(original.position, Rect2(Vector2.ZERO, original.size * candidate_scale), bounds, blocked)
				if at != Vector2.INF:
					fit_scale = candidate_scale
					break
		var rig := preload("res://scenes/props/backdrop/window_cutout/WindowCutout.tscn").instantiate()
		panel.add_child(rig)
		rig.name = "WindowCutout%d" % i
		rig.visible = at != Vector2.INF
		rig.set_meta("window_room", room)
		rig.set_meta("window_excluded", not rig.visible)
		var art: Sprite2D = rig.get_node("Art")
		art.texture = panel.texture
		art.region_rect = original
		art.position = original.get_center()
		art.material = base_material
		art.self_modulate = panel.self_modulate
		if rig.visible:
			rig.scale = Vector2.ONE * fit_scale
			rig.position = at - original.position * fit_scale
			rig.set_meta("placement_rect", Rect2(at, original.size * fit_scale))
			blocked.append(Rect2(at, original.size * fit_scale))
		if i == 0:
			for child in panel.get_children():
				if child is OfficeMoon: child.reparent(rig, false)
			var dawn := room.get_node_or_null("OfficeDawn") as Node2D
			if dawn != null:
				dawn.reparent(rig, false)
				dawn.z_index = 0
				dawn.set_meta("window_excluded", not rig.visible)
				for light_name in ["DawnGlowRoom26", "DawnSpillRoom26a", "DawnSpillRoom26b", "SunShaftRoom26"]:
					var light := world.get_node_or_null("Lights/" + light_name) as Node2D
					if light:
						light.position += rig.position
						if not rig.visible: light.hide()
	panel.material.set_shader_parameter("cleared_window_count", erased.size())
	erased.resize(32)
	panel.material.set_shader_parameter("cleared_windows", erased)
