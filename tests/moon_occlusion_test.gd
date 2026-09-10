extends Node
## Pixel-level regression: emission is clipped by glass, including mullions.
func _ready() -> void:
	var world := Node2D.new()
	var wall := ColorRect.new()
	wall.size = Vector2(320, 180)
	wall.color = Color.BLACK
	world.add_child(wall)
	var ambient := CanvasModulate.new()
	ambient.color = Color.BLACK
	world.add_child(ambient)
	var moon = load("res://scenes/props/backdrop/office_moon/OfficeMoon.tscn").instantiate()
	world.add_child(moon)
	moon.configure(load("res://assets/background/moon.png"), Rect2(92, 72, 16, 16))
	moon.set_window_openings([Rect2(94, 60, 5, 40), Rect2(102, 60, 5, 40)])
	Screen.set_scene(world)
	for frame in 3:
		await get_tree().process_frame
	MoonVisibility.refresh()
	RenderingServer.force_draw(false)
	var shot := Screen.viewport.get_texture().get_image()
	var failures := 0
	# Bright through either pane; black behind the divider and outside the sash.
	for probe in [90, 95, 100, 105, 110]:
		print("opening probe ", probe, ": ", shot.get_pixel(probe, 80).get_luminance())
	for x in [95, 105]:
		if shot.get_pixel(x, 80).get_luminance() < 0.5:
			failures += 1
	for x in [90, 100, 110]:
		if shot.get_pixel(x, 80).get_luminance() > 0.01:
			failures += 1
	# Moving the source completely behind the wall must hide disc AND halo.
	moon.position = Vector2(150, 80)
	await get_tree().process_frame
	RenderingServer.force_draw(false)
	shot = Screen.viewport.get_texture().get_image()
	if shot.get_pixel(150, 80).get_luminance() > 0.01:
		failures += 1
	world.remove_child(moon)
	moon.free()
	var window = load("res://scenes/props/backdrop/MoonWindow.tscn").instantiate()
	window.position = Vector2(200, 80)
	world.add_child(window)
	for blood in [false, true]:
		if blood:
			window.eclipse(0.0)
		await get_tree().process_frame
		MoonVisibility.refresh()
		RenderingServer.force_draw(false)
		shot = Screen.viewport.get_texture().get_image()
		print("window blood ", blood, " inside/outside ", shot.get_pixel(193, 73).get_luminance(), " / ", shot.get_pixel(180, 73).get_luminance())
		if shot.get_pixel(193, 73).get_luminance() < 0.02:
			failures += 1
		if shot.get_pixel(180, 73).get_luminance() > 0.01:
			failures += 1
	print("MOON OCCLUSION: panes, mullion, outside wall; %d failures" % failures)
	get_tree().quit(0 if failures == 0 else 1)
