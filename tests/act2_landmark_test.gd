extends Node
var failures:=0
func check(ok:bool,label:String) -> void:
	print("PASS " if ok else "FAIL ",label)
	if not ok:failures+=1
func _ready() -> void:
	SaveGame.slot=-1
	LdtkWorld.debug_start_room="Act_2_Level_3"
	Screen.load_scene("res://ldtk/Act2World.tscn")
	for i in 12:await get_tree().process_frame
	var world:=Screen.current as LdtkWorld
	world.player.set_physics_process(false)
	world.get_node("Act2Beats").set_process(false)
	var sky:=world.get_node("Backdrop/SkyBackdrop")
	var gallery:=sky.get_node("Landmarks")
	check(gallery.paintings.size()==6,"six original landmark paintings packaged")
	var textures:={}
	var size:=Vector2(320,180)
	for panel:Dictionary in gallery.panels:
		var bounds:Rect2=panel.bounds
		var sprite:Sprite2D=panel.sprite
		textures[sprite.texture.resource_path]=true
		check(sprite.texture.get_width()>=1000,"high resolution source preserved: "+panel.room)
		for corner in [bounds.position,bounds.end-size]:
			gallery.frame_view(Rect2(corner,size),size)
			var art:=Rect2(sprite.position,sprite.texture.get_size()*sprite.scale)
			check(sprite.visible and sprite.modulate.a>0.99,"room's landmark fully visible: "+panel.room)
			check(art.encloses(Rect2(Vector2.ZERO,size)),"painting covers camera without gaps")
			check(sprite.scale.x==sprite.scale.y,"architecture keeps its proportions")
	check(textures.size()==gallery.panels.size(),"every existing landmark room has distinct art")
	check(gallery.panels.size()==6,"all six expansion rooms receive art")
	var first:Rect2=gallery.panels[0].bounds
	gallery.frame_view(Rect2(first.position,size),size)
	var sprite:Sprite2D=gallery.panels[0].sprite
	var before:=sprite.position
	gallery.frame_view(Rect2(first.position+Vector2(120,50),size),size)
	check(sprite.position==before,"landmark stays fixed while the camera moves horizontally and vertically")
	gallery.frame_view(Rect2(first.position,size),size)
	check(sprite.position==before,"backtracking restores exactly the same framing")
	# Sweep each entire doorway in both directions. Effective layer weights
	# must sum to one: no base panorama/sun leakage, no flash or sudden swap.
	for i in gallery.panels.size()-1:
		var seam:float=gallery.panels[i].bounds.end.x
		var previous:=0.0
		var samples: Array[float]=[]
		for step in 65:
			var center:=seam-160.0+step*5.0
			gallery.frame_view(Rect2(Vector2(center-size.x*.5,first.position.y),size),size)
			var back:Sprite2D=gallery.panels[i].sprite
			var front:Sprite2D=gallery.panels[i+1].sprite
			var front_weight:=front.modulate.a
			var back_weight:=back.modulate.a*(1.0-front_weight)
			check(absf(back_weight+front_weight-1.0)<0.0001,"seam %d frame %d remains opaque" % [i,step])
			check(front_weight>=previous and front_weight-previous<0.025,"dissolve advances smoothly")
			previous=front_weight;samples.append(front_weight)
		for step in range(64,-1,-1):
			gallery.frame_view(Rect2(Vector2(seam-160.0+step*5.0-size.x*.5,first.position.y),size),size)
			check(is_equal_approx(gallery.panels[i+1].sprite.modulate.a,samples[step]),"reverse transition restores the exact same blend")
	# Every picture, including the extra-wide paintings, stays put throughout
	# a whole room sweep, rather than having aspect-dependent drift speeds.
	for panel:Dictionary in gallery.panels:
		var bounds:Rect2=panel.bounds
		gallery.frame_view(Rect2(bounds.position,size),size)
		var origin:Vector2=panel.sprite.position
		for step in 11:
			gallery.frame_view(Rect2(bounds.position+(bounds.size-size)*step/10.0,size),size)
			check(panel.sprite.position==origin,"fixed framing across "+panel.room)
		var material:=panel.sprite.material as ShaderMaterial
		check(material!=null and material.get_shader_parameter("contrast")<0.7 and material.get_shader_parameter("saturation")<0.75,"only the landmark gets atmospheric contrast reduction")
	var old_room:Rect2=world.room_rect(world.rooms[0])
	gallery.frame_view(Rect2(old_room.position,size),size)
	var hidden:=true
	for panel:Dictionary in gallery.panels:hidden=hidden and not panel.sprite.visible
	check(hidden,"earlier Act 2 rooms retain the original panorama")
	check(sky.get_children().filter(func(n):return n.name=="Sun").size()==1,"landmarks retain the single shared sun")
	if DisplayServer.get_name()!="headless":await rendered_stationarity(world)
	print("ACT2_LANDMARKS: ",failures," failures")
	get_tree().quit(0 if failures==0 else 1)

func rendered_stationarity(world:LdtkWorld) -> void:
	# Real rendered pixels, not just Node coordinates: a late camera update
	# can move an otherwise "fixed" sprite by one frame on the actual screen.
	world.set_physics_process(false)
	world.player.hide()
	# Teleporting the camera through a hazard must not emit a death burst
	# into this background-only comparison.
	world.player.collision_layer=0
	world.player.collision_mask=0
	world.player.invulnerable_timer=INF
	world.player.camera.position_smoothing_enabled=false
	for room in world.rooms:room.hide()
	for room in world.rooms:
		if not str(room.name).begins_with("Act_2_Level_") or int(str(room.name).get_slice("_",3))<3:continue
		world._enter_room(room,false)
		room.hide()
		var bounds:=world.room_rect(room)
		var first:=await camera_image(world,bounds.position+Vector2(160,90))
		var last:=await camera_image(world,bounds.end-Vector2(160,90))
		var different:=0
		var a:=first.get_data();var b:=last.get_data()
		for i in a.size():
			if absi(int(a[i])-int(b[i]))>1:different+=1
		if different>0:
			first.save_png("res://output/act2_landmarks/calm/first.png")
			last.save_png("res://output/act2_landmarks/calm/last.png")
		check(different==0,"rendered landmark pixels stay stationary through room sweep: "+str(room.name)+" (%d changed channels)" % different)

func camera_image(world:LdtkWorld,at:Vector2) -> Image:
	world.player.global_position=at
	world.player.camera.reset_smoothing()
	world.player.camera.force_update_scroll()
	for i in 3:await get_tree().process_frame
	RenderingServer.force_draw()
	return Screen.viewport.get_texture().get_image()
