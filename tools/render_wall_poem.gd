extends Node
## Authoring only: rasterize Persian script with the host's licensed system font.
## The exported game consumes the PNG, never the system font.
func _ready() -> void:
	var second := OS.get_cmdline_user_args().has("--second")
	var view := SubViewport.new()
	view.size = Vector2i(232,40)
	view.transparent_bg = true
	view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(view)
	var font := SystemFont.new()
	font.font_names = PackedStringArray(["Geeza Pro"])
	var text := Label.new()
	text.add_theme_font_override("font", font)
	text.add_theme_font_size_override("font_size",14)
	text.add_theme_color_override("font_color",Color("305953"))
	text.text_direction = Control.TEXT_DIRECTION_RTL
	text.language = "fa"
	text.text = "حفره‌کن زندان و خود را وا رهان" if second else "این جهان زندان و ما زندانیان"
	text.size = Vector2(232,40)
	text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	view.add_child(text)
	await RenderingServer.frame_post_draw
	view.get_texture().get_image().save_png("res://assets/props/school_wall/poem_second_line.png" if second else "res://assets/props/school_wall/poem_first_line.png")
	get_tree().quit()
