extends Node
## A room owns its moon for its entire lifetime. Camera movement never selects
## a different window. Future MoonWindow instances share this same rule.
func _ready() -> void:
	RenderingServer.frame_pre_draw.connect(refresh)

func refresh() -> void:
	var chosen: Dictionary = {}
	for moon in get_tree().get_nodes_in_group("moon_candidates"):
		moon.set_moon_selected(false)
		if not moon.is_visible_in_tree() or moon.get_meta("window_excluded", false):
			continue
		var world: Node = moon.get_parent()
		while world != null and not world is LdtkWorld:
			world = world.get_parent()
		if world == null:
			# Standalone previews also keep one stable source per viewport.
			var key := moon.get_viewport().get_instance_id()
			if not chosen.has(key):
				chosen[key] = moon
				moon.set_moon_selected(true)
			continue
		var owner_room: Node2D = null
		for room in world.rooms:
			if world.room_rect(room).has_point(world.to_local(moon.global_position)):
				owner_room = room
				break
		if owner_room != null and world._room_has_music_puzzle(owner_room):
			continue
		if owner_room == null:
			continue
		var key := owner_room.get_instance_id()
		if chosen.has(key):
			continue
		chosen[key] = moon
		if moon is MoonWindow:
			moon.night_progress = float(world.rooms.find(owner_room)) / maxf(world.rooms.size() - 1, 1)
		# Live when its room is the one the player is in — which, mid-slide, is
		# the room being ENTERED as well as the one being left, so the moon of the
		# room scrolling in is already lit rather than popping in once the camera
		# lands. See LdtkWorld.is_room_active().
		moon.set_moon_selected(world.is_room_active(owner_room))
