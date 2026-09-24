extends Node
## Windowed proof using the real 320x180 game viewport and real player input.

const OUT := "res://output/hooshang_18px/integration"
var player: Player


func _ready() -> void:
	SaveGame.slot = -1
	var level: Node2D = load("res://scenes/levels/TestLevel.tscn").instantiate()
	Screen.set_scene(level)
	player = level.get_node("Player")
	(player.get_node("Camera2D") as Camera2D).position_smoothing_enabled = false
	await frames(40)
	await capture("idle")
	Input.action_press("move_right")
	await frames(10)
	await capture("run")
	Input.action_press("jump")
	await frames(7)
	Input.action_release("jump")
	await capture("jump")
	Input.action_press("dash")
	# Dash has real-time hitstop before entering its state. Do not photograph
	# the jump that is deliberately frozen during those first few ticks.
	for i in 60:
		await frames(1)
		if player.visual.animation == &"dash":
			break
	Input.action_release("dash")
	await frames(2)
	await capture("dash")
	Input.action_release("move_right")
	await frames(30)
	print("NATIVE18 REVIEW: real game frames saved to ", ProjectSettings.globalize_path(OUT))
	get_tree().quit()


func frames(count: int) -> void:
	for i in count:
		await get_tree().physics_frame


func capture(label: String) -> void:
	await RenderingServer.frame_post_draw
	var im := Screen.viewport.get_texture().get_image()
	im.save_png(OUT + "/godot_" + label + "_native.png")
	im.resize(1280, 720, Image.INTERPOLATE_NEAREST)
	im.save_png(OUT + "/godot_" + label + ".png")
	print(label, ": animation=", player.visual.animation, " frame=", player.visual.frame,
		" scale=", player.visual.scale, " viewport=", Screen.viewport.size)
