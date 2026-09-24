extends Node
func _ready()->void:
	var view:=SubViewport.new()
	view.size=Vector2i(320,192)
	view.canvas_item_default_texture_filter=Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	view.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	add_child(view)
	var room=load("res://ldtk/levels/hooshang_act1/Level_8.scn").instantiate()
	room.position=Vector2.ZERO
	view.add_child(room)
	var ambient:=CanvasModulate.new();ambient.color=Color.BLACK;view.add_child(ambient)
	var portal=preload("res://scenes/props/music_exit/MusicExit.tscn").instantiate()
	portal.position=Vector2(288,48);view.add_child(portal)
	for exit in get_tree().get_nodes_in_group("exit"):
		for child in exit.get_children():
			if child is CanvasItem and not child is CollisionShape2D:child.hide()
	for opened in [false,true]:
		portal.set_state(5 if opened else 0,5,opened)
		ambient.color=Color(.855,.81,.702) if opened else Color.BLACK
		portal.gate._process(1)
		portal._process(1.5)
		for i in 5:await get_tree().process_frame
		RenderingServer.force_draw()
		var shot:=view.get_texture().get_image()
		shot.resize(960,576,Image.INTERPOLATE_NEAREST)
		shot.save_png("res://output/music_exit/%s.png" % ("open" if opened else "locked"))
	get_tree().quit()
