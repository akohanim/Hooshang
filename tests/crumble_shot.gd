extends Node
func _ready() -> void:
	var stage := Node2D.new()
	Screen.set_scene(stage)
	RenderingServer.set_default_clear_color(Color("18212d"))
	var p = preload("res://scenes/props/platforms/CrumblingPlatform.tscn").instantiate()
	p.position = Vector2(160,80)
	p.size = Vector2(48,8)
	stage.add_child(p)
	await get_tree().create_timer(0.15).timeout
	await shot("intact")
	p.give_way(0.6)
	await get_tree().create_timer(0.3).timeout
	await shot("warning")
	await get_tree().create_timer(0.5).timeout
	await shot("fall")
	await get_tree().create_timer(0.5).timeout
	await shot("outline")
	await get_tree().create_timer(1.5).timeout
	await shot("still_collapsed")
	p.reset()
	await shot("restored")
	get_tree().quit()
func shot(label: String) -> void:
	await RenderingServer.frame_post_draw
	var img := Screen.viewport.get_texture().get_image()
	img.resize(1280,720,Image.INTERPOLATE_NEAREST)
	img.save_png("res://output/crumble_"+label+".png")
