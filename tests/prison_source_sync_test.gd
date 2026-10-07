extends Node
## Prove the imported room geometry equals the editable LDtk source, not a cache.
func _ready() -> void:
	SaveGame.unbind()
	var world=load("res://ldtk/Act2World.tscn").instantiate()
	world.debug_start_room="Prison_Hub"
	add_child(world)
	for frame in 12: await get_tree().physics_frame
	var source: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://ldtk/hooshang_act2.ldtk"))
	var failures:=0
	var checked:=0
	for level in source.levels:
		if not str(level.identifier).begins_with("Prison_"): continue
		var room: Node
		for candidate in world.rooms:
			if str(candidate.name)==level.identifier: room=candidate
		if room==null:
			failures+=1;continue
		var geo=room.get_node("PrisonGeometry")
		for layer in level.layerInstances:
			if layer.__identifier!="Collision": continue
			for index in layer.intGridCsv.size():
				if geo.value_at(Vector2i(index%int(layer.__cWid),index/int(layer.__cWid)))!=int(layer.intGridCsv[index]):
					failures+=1;push_error("Stale imported geometry: "+str(level.identifier));break
		checked+=1
	var runtime: Image=load("res://ldtk/art/prison/school.png").get_image()
	var disk:=Image.new()
	disk.load_png_from_buffer(FileAccess.get_file_as_bytes("res://ldtk/art/prison/school.png"))
	if runtime==null:
		failures+=1
	else:
		runtime.convert(Image.FORMAT_RGBA8);disk.convert(Image.FORMAT_RGBA8)
		# Godot's fix_alpha_border expands RGB under fully transparent pixels.
		# Those invisible RGB values are not stale art; compare visible pixels.
		var matches:=runtime.get_size()==disk.get_size()
		for y in disk.get_height():
			for x in disk.get_width():
				var original:=disk.get_pixel(x,y)
				var imported:=runtime.get_pixel(x,y)
				if original.a!=imported.a or (original.a>0 and original.to_rgba32()!=imported.to_rgba32()): matches=false
		if not matches: failures+=1;push_error("Stale prison atlas import")
	world.queue_free()
	for frame in 3: await get_tree().physics_frame
	print("PRISON SOURCE SYNC: ",checked," rooms and scaffold atlas; ",failures," failures")
	get_tree().quit(0 if failures==0 and checked==17 else 1)
