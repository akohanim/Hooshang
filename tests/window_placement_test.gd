extends Node
const OfficeWindowPlacement = preload("res://scripts/office_window_placement.gd")
func _ready() -> void:
	SaveGame.slot = -1
	var world: LdtkWorld = load("res://ldtk/Act1World.tscn").instantiate()
	Screen.set_scene(world)
	await get_tree().process_frame
	var failures := 0
	var checked := 0
	for window in world.get_node("Backdrop").get_children():
		if not window is MoonWindow: continue
		if window.visible:
			var room: Node2D = window.get_meta("window_room", null)
			if room == null: failures += 1; continue
			var bounds := world.room_rect(room)
			bounds.position -= room.position
			var rect := Rect2(room.to_local(window.global_position) + OfficeWindowPlacement.FRAME.position, OfficeWindowPlacement.FRAME.size)
			if world._room_has_music_puzzle(room) or not OfficeWindowPlacement.clear(rect, bounds, OfficeWindowPlacement.obstacles(room)):
				failures += 1
			print("WINDOW ", window.name, " ", room.name, " ", rect)
			checked += 1
		else: print("HIDDEN ", window.name)
	for room in world.rooms:
		var panel := room.get_node_or_null("RoomBackdrop")
		if panel == null: continue
		var bounds := world.room_rect(room); bounds.position -= room.position
		var blocked := OfficeWindowPlacement.obstacles(room)
		for cutout in panel.get_children():
			if not str(cutout.name).begins_with("WindowCutout"): continue
			if cutout.visible:
				var rect: Rect2 = cutout.get_meta("placement_rect")
				if world._room_has_music_puzzle(room) or not OfficeWindowPlacement.clear(rect, bounds, blocked): failures += 1
				# Independently check the hand-placed cubicle panels that live outside rooms.
				for prop in world.get_node("Props").get_children():
					var panel_prop := prop.get_node_or_null("BackPanel") as Control
					if panel_prop != null:
						var panel_rect := Rect2(room.to_local(panel_prop.global_position), panel_prop.size)
						if rect.intersects(panel_rect): failures += 1
				print("BAKED ",room.name," ",rect)
				checked += 1
			else: print("BAKED OMITTED ", room.name)
	# Exercise a newly added musical tile, not just today's named puzzle rooms.
	var room: Node2D = world.rooms[0]
	var note := Node2D.new()
	note.add_to_group("note_tile")
	room.add_child(note)
	var future := preload("res://scenes/props/backdrop/MoonWindow.tscn").instantiate()
	future.name = "MoonWindowRoom0"
	world.get_node("Backdrop").add_child(future)
	future.global_position = room.global_position + Vector2(100, 70)
	OfficeWindowPlacement.apply(world)
	if future.visible: failures += 1
	MoonVisibility.refresh()
	if future.get_node("Moon").visible: failures += 1
	print("WINDOW PLACEMENT: %d visible windows; %d failures" % [checked,failures])
	get_tree().quit(1 if failures else 0)
