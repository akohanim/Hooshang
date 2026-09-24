extends Node

const OUT := "res://output/hooshang_18px/run_cadence"
var players: Array[Player] = []
var records: Array = []

func _ready() -> void:
	SaveGame.slot = -1
	var level := Node2D.new()
	Screen.set_scene(level)
	for i in 3:
		var floor_body := StaticBody2D.new()
		floor_body.position = Vector2(160, 52 + i * 56)
		var shape := RectangleShape2D.new()
		shape.size = Vector2(320, 8)
		var collision := CollisionShape2D.new()
		collision.shape = shape
		floor_body.add_child(collision)
		level.add_child(floor_body)
		var ground := Polygon2D.new()
		ground.polygon = PackedVector2Array([Vector2(0,48+i*56),Vector2(320,48+i*56),Vector2(320,56+i*56),Vector2(0,56+i*56)])
		ground.color = Color("515965")
		level.add_child(ground)
		for x in range(0,320,12):
			var mark := Line2D.new()
			mark.add_point(Vector2(x,48+i*56))
			mark.add_point(Vector2(x,51+i*56))
			mark.width = 1
			mark.default_color = Color("a8b5c5")
			level.add_child(mark)
		var player: Player = load("res://scenes/characters/hooshang/Hooshang.tscn").instantiate()
		player.position = Vector2(36,42+i*56)
		level.add_child(player)
		player.camera.enabled = false
		player.visual.sprite_frames = player.visual.sprite_frames.duplicate()
		player.visual.sprite_frames.set_animation_speed("run", 1000.0 * (1.2 + i * 0.2))
		players.append(player)
		var label := Label.new()
		label.position = Vector2(5,2+i*56)
		label.add_theme_font_size_override("font_size", 8)
		label.text = "+%d%% | %.1f fps" % [20+i*20,(1.2+i*0.2)/0.09]
		level.add_child(label)
	for warmup in 40:
		await get_tree().physics_frame
	Input.action_press("move_right")
	for frame in 110:
		await get_tree().physics_frame
		if frame >= 12 and frame % 2 == 0:
			await RenderingServer.frame_post_draw
			var im := Screen.viewport.get_texture().get_image()
			im.save_png(OUT + "/frame_%03d.png" % frame)
			records.append({"frame":frame,"x":players[0].position.x,"vx":players[0].velocity.x,"poses":[players[0].visual.frame,players[1].visual.frame,players[2].visual.frame]})
	Input.action_release("move_right")
	var file := FileAccess.open(OUT + "/measurements.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(records,"\t"))
	get_tree().quit()
