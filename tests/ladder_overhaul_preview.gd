extends Node
func _ready() -> void:
	var configs:Array=JSON.parse_string(FileAccess.get_file_as_string("res://resources/levels/act1_expansion.json"))
	var authored:Node=load("res://ldtk/Act1World.tscn").instantiate()
	var reference:Color=authored.get_node("CanvasModulate").color
	authored.free()
	for c:Dictionary in configs.slice(0,5):
		var viewport:=SubViewport.new()
		viewport.size=Vector2i(c.width,c.height)
		viewport.canvas_item_default_texture_filter=Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
		viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS
		add_child(viewport)
		var room:Node2D=load("res://ldtk/levels/hooshang_act1/%s.scn" % c.name).instantiate()
		room.position=Vector2.ZERO
		viewport.add_child(room)
		var ambient:=CanvasModulate.new()
		ambient.color=reference if c.encounter.mode=="security" else Color(.13,.15,.2)
		viewport.add_child(ambient)
		for i in 12:await get_tree().process_frame
		RenderingServer.force_draw()
		var shot:=viewport.get_texture().get_image()
		shot.resize(c.width*3,c.height*3,Image.INTERPOLATE_NEAREST)
		shot.save_png("res://output/ladder_overhaul/%s.png" % c.name)
		viewport.queue_free()
		await get_tree().process_frame
	get_tree().quit()
