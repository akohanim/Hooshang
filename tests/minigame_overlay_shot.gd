extends Node
## Dev capture harness for RetroTV's full-window picture, not pass/fail. Shows
## a 1px checkerboard "game" through the real overlay and measures, in the
## WINDOW's own pixels, how wide each game pixel came out — every one should be
## the same whole number. Run windowed at a size whose integer stretch is odd
## (960x540 is x3) to see the difference:
##   Godot --path . --windowed --resolution 960x540 res://tests/minigame_overlay_shot.tscn -- before


class Checker extends Node2D:
	signal exit_requested
	signal finished
	func activate() -> void: pass
	func deactivate() -> void: pass
	func _draw() -> void:
		for y in 120:
			for x in 160:
				draw_rect(Rect2(x, y, 1, 1), Color.WHITE if (x + y) % 2 == 0 else Color.BLACK)


func _ready() -> void:
	var tag := "shots"
	var args := OS.get_cmdline_user_args()
	if not args.is_empty(): tag = args[0]
	var tv := RetroTV.new()
	tv.game = Checker.new()
	add_child(tv)
	for i in 3: await get_tree().process_frame
	tv._show_overlay()
	for i in 4: await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	var dir := "res://output/minigames/%s" % tag
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir))
	img.save_png("%s/overlay_%dx%d.png" % [dir, img.get_width(), img.get_height()])
	# Run lengths of light/dark along the middle row of the picture.
	var y := img.get_height() / 2
	var runs := {}
	var run := 0
	var last := -1
	var first := true
	for x in img.get_width():
		var lit := 1 if img.get_pixel(x, y).get_luminance() > 0.2 else 0
		if lit == last: run += 1
		else:
			if last != -1 and not first: runs[run] = runs.get(run, 0) + 1
			if last != -1: first = false
			last = lit
			run = 1
	print("window %s, stretch scale %s" % [img.get_size(), get_tree().root.get_final_transform().get_scale()])
	print("game-pixel widths along the middle row (width: count): ", runs)
	get_tree().quit()
