extends Node
## Visual QA: actual 320x180 game surface at each authored cutscene stage.
## macOS: Godot --rendering-method mobile --rendering-driver metal --path .
## res://tests/act2_encounter_shot.tscn; captures land in /tmp/act2_*.png.
var captured := {}
func _ready() -> void:
	SaveGame.slot = -1
	LdtkWorld.debug_start_room = "Act_2_Level_1"
	Screen.load_scene("res://ldtk/Act2World.tscn")
	await get_tree().create_timer(1.0).timeout
	var world := Screen.current as LdtkWorld
	var beats := world.get_node("Act2Beats") as Act2Beats
	var npc := beats._speaker
	world.player.global_position = npc.global_position + Vector2(-35, -8)
	Engine.time_scale = 4.0
	for i in 20000:
		await get_tree().process_frame
		if i % 8 == 0:
			var event := InputEventAction.new()
			event.action = "jump"
			event.pressed = true
			Input.parse_input_event(event)
		var key := ""
		if Dialogue.visible:
			var line: String = Dialogue.get_node("TextLabel").text
			if "Cousin joon" in line: key = "meeting"
			if "mother know" in line: key = "sunset"
			if "beginning" in line: key = "night"
			if "woke up here" in line: key = "dawn"
			if "how you get" in line: key = "carpet"
		if beats._caught and not captured.has("catch"): key = "catch"
		if key != "" and not captured.has(key):
			await RenderingServer.frame_post_draw
			var img := Screen.viewport.get_texture().get_image()
			img.save_png("/tmp/act2_%s.png" % key)
			get_viewport().get_texture().get_image().save_png("/tmp/act2_ui_%s.png" % key)
			captured[key] = true
			print("CAPTURE ", key, " player ",world.player.global_position," npc ",npc.global_position," fish ",beats._pond_fish.global_position)
		if beats._played and not world.player.input_locked:
			break
	Engine.time_scale = 1.0
	get_tree().quit()
