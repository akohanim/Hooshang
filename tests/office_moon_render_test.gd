extends Node
## Windowed isolated lighting probe: emission survives black ambient, while
## the separate pool genuinely lights a shaded surface.
func _ready() -> void:
	var world := Node2D.new()
	var ambient := CanvasModulate.new()
	ambient.color = Color.BLACK
	world.add_child(ambient)
	var wall := ColorRect.new()
	wall.size = Vector2(320, 180)
	wall.color = Color(0.4, 0.4, 0.4)
	world.add_child(wall)
	var moon = load("res://scenes/props/backdrop/office_moon/OfficeMoon.tscn").instantiate()
	world.add_child(moon)
	moon.configure(load("res://assets/background/act1_office/level_1.png"), Rect2(87, 35, 6, 6))
	Screen.set_scene(world)
	moon.set_pool_enabled(true)
	await _frame()
	var on := Screen.viewport.get_texture().get_image()
	moon.get_node("Halo").hide()
	moon.set_pool_enabled(false)
	await _frame()
	var off := Screen.viewport.get_texture().get_image()
	var core_on := on.get_pixel(90, 38).get_luminance()
	var core_off := off.get_pixel(90, 38).get_luminance()
	var pool_on := on.get_pixel(112, 38).get_luminance()
	var pool_off := off.get_pixel(112, 38).get_luminance()
	var passed := core_off > 0.6 and core_on > 0.6 and pool_on > pool_off + 0.005
	print("MOON RENDER: core %.3f / %.3f; pool %.3f / %.3f; pass %s" % [core_on, core_off, pool_on, pool_off, passed])
	get_tree().quit(0 if passed else 1)

func _frame() -> void:
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
