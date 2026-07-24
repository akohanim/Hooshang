extends Node
## Dev screenshot harness: loads a level, teleports the camera to a few x
## positions, and saves viewport PNGs. Runs WINDOWED (not headless) so the 2D
## content actually renders. Output goes to /tmp/shot_*.png.
## Usage: Godot --path . res://tests/screenshot.tscn

const LEVEL := "res://scenes/levels/act1_office/Level1Office.tscn"
const SHOTS := [140, 380, 620]   # camera x positions to capture
var level: Node2D
var player: Node2D


func _ready() -> void:
	level = load(LEVEL).instantiate()
	add_child(level)
	player = level.get_node("Player")
	player.input_locked = true
	var cam: Camera2D = player.get_node("Camera2D")
	cam.position_smoothing_enabled = false
	await get_tree().process_frame
	for i in SHOTS.size():
		player.global_position = Vector2(SHOTS[i], 150)
		for f in 8:
			await get_tree().process_frame
		var img := get_viewport().get_texture().get_image()
		img.save_png("/tmp/shot_%d.png" % SHOTS[i])
		print("saved /tmp/shot_%d.png" % SHOTS[i])
	get_tree().quit()
