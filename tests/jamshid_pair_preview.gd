extends Node
## Audition the production resources on the actual 320x180 nearest viewport.
const HOOSHANG := preload("res://assets/characters/hooshang_child/act2_frames.tres")
const JAMSHID := preload("res://scenes/characters/jamshid/Jamshid.tscn")
var POSES := HOOSHANG.get_animation_names()
var pairs: Array[AnimatedSprite2D] = []

func _ready() -> void:
	var world := Node2D.new()
	Screen.set_scene(world)
	var bg := Polygon2D.new()
	bg.polygon = PackedVector2Array([Vector2.ZERO, Vector2(320,0), Vector2(320,180), Vector2(0,180)])
	bg.color = Color("303b40")
	world.add_child(bg)
	for i in POSES.size():
		var x: int = 6 + (i % 6) * 53
		var y: int = 12 + int(i / 6) * 43
		var label := Label.new()
		label.text = POSES[i]
		label.add_theme_font_size_override("font_size", 6)
		label.position = Vector2(x, y)
		world.add_child(label)
		var h := AnimatedSprite2D.new()
		h.sprite_frames = HOOSHANG
		h.scale = Vector2.ONE * 0.375
		h.offset = Vector2(0,-3)
		h.position = Vector2(x+12,y+26)
		world.add_child(h)
		h.play(POSES[i])
		pairs.append(h)
		var marks := preload("res://scenes/characters/hooshang/SockPixels.tscn").instantiate()
		marks.visual_path = NodePath(h.name)
		world.add_child(marks)
		var j := JAMSHID.instantiate()
		j.position = Vector2(x+35,y+32)
		world.add_child(j)
		j.visual.animation_finished.disconnect(j._on_animation_finished)
		j.play_pose(POSES[i])
		pairs.append(j.visual)
	if "--capture" in OS.get_cmdline_user_args():
		for phase in range(8):
			for sprite in pairs:
				sprite.pause()
				sprite.frame = mini(phase, sprite.sprite_frames.get_frame_count(sprite.animation)-1)
			await RenderingServer.frame_post_draw
			var im := Screen.viewport.get_texture().get_image()
			im.save_png("res://output/jamshid_pair/phase_%d_native.png" % phase)
			im.resize(1280,720,Image.INTERPOLATE_NEAREST)
			im.save_png("res://output/jamshid_pair/phase_%d.png" % phase)
		get_tree().quit()
