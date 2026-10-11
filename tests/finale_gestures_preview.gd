extends Node
const OUT := "res://output/act2_polish/finale_staging"
var captured := {}
func _ready() -> void:
	SaveGame.unbind()
	Game.completed = false
	LdtkWorld.debug_start_room = "Act_2_Level_21"
	Screen.load_scene("res://ldtk/Act2World.tscn")
	for i in 30: await get_tree().physics_frame
	var world = Screen.current
	var ending = world.get_node("Act2Ending")
	DirAccess.make_dir_recursive_absolute(OUT)
	Input.action_press("move_right")
	for tick in 3000:
		await get_tree().process_frame
		if ending.playing: Input.action_release("move_right")
		var actor: AnimatedSprite2D = ending.get_node("Gestures/Actor")
		if actor.visible and actor.animation == &"pickup": await capture("pickup")
		if ending.paint_progress > 0.3 and ending.paint_progress < 0.6: await capture("painting")
		if actor.visible and actor.animation == &"salute" and actor.frame >= 2: await capture("salute")
		if actor.visible and actor.animation == &"pickup_coat" and actor.frame >= 2: await capture("coat_pickup")
		if ending.coat_collected: await capture("coat_collected")
		if ending._shown:
			await capture("complete")
			break
		if Dialogue._active:
			Dialogue._finish_reveal_instantly()
			await capture("line_%d" % ending.line_index)
			Dialogue.line_finished.emit()
	Input.action_release("move_right")
	print("FINALE GESTURES PREVIEW completed=",ending._shown," captures=",captured.keys())
	get_tree().quit(0 if ending._shown else 1)
func capture(label: String) -> void:
	if captured.has(label): return
	captured[label] = true
	await get_tree().process_frame
	RenderingServer.force_draw()
	Screen.viewport.get_texture().get_image().save_png(OUT+"/"+label+"_native.png")
	get_tree().root.get_texture().get_image().save_png(OUT+"/"+label+"_ui.png")
