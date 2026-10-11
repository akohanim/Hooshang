extends Node
## Render each uncollected key, then hide it: visible pixels must actually change.
func _ready() -> void:
	SaveGame.unbind()
	var world=load("res://ldtk/Act2World.tscn").instantiate()
	world.debug_start_room="Prison_Hub"
	Screen.set_scene(world)
	await get_tree().create_timer(0.2).timeout
	var failures:=0
	var count:=0
	DirAccess.make_dir_recursive_absolute("res://output/prison_build/room_checkpoints/keys")
	for prop in world.props:
		if prop.kind=="Checkpoint": failures+=1;push_error("Checkpoint flag still imported")
		if prop.kind!="Key": continue
		count+=1
		var room: Node2D=prop.get_parent().get_parent()
		var label: String=prop.key_id.to_upper()+" KEY"
		var label_start: float=prop.position.x+prop.label_offset(label,-24).x
		var label_end: float=label_start+prop.FONT.get_string_size(label,HORIZONTAL_ALIGNMENT_LEFT,-1,7).x
		if label_start<8 or label_end>room.size.x-8:
			failures+=1;push_error("Key label leaves its room: "+prop.key_id)
		world._enter_room(room,true)
		world.player.respawn(world.spawn_point_for(room))
		await get_tree().create_timer(0.15).timeout
		await RenderingServer.frame_post_draw
		var before: Image=Screen.viewport.get_texture().get_image()
		before.save_png("res://output/prison_build/room_checkpoints/keys/"+prop.key_id+".png")
		prop.hide()
		await RenderingServer.frame_post_draw
		await RenderingServer.frame_post_draw
		var after: Image=Screen.viewport.get_texture().get_image()
		var center: Vector2=prop.global_position-world.player.camera.get_screen_center_position()+Vector2(before.get_size())/2
		var changed:=0
		for y in range(maxi(0,int(center.y)-34),mini(before.get_height(),int(center.y)+12)):
			for x in range(maxi(0,int(center.x)-28),mini(before.get_width(),int(center.x)+28)):
				if before.get_pixel(x,y)!=after.get_pixel(x,y): changed+=1
		if changed<120: failures+=1;push_error("Key not visibly rendered: "+prop.key_id)
		print("KEY VISIBILITY ",prop.key_id,": ",changed," changed pixels")
		prop.show()
	print("PRISON KEY VISIBILITY: ",count," keys, ",failures," failures")
	get_tree().quit(0 if count==4 and failures==0 else 1)
