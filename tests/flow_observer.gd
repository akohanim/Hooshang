extends Node
## Persistent observer for the real level-flow test. Lives on the tree root so
## it survives change_scene(). It boots Level 1, walks the player into the exit,
## and confirms the game actually transitions to Level 2.


func _ready() -> void:
	await get_tree().process_frame
	get_tree().change_scene_to_file(Game.LEVELS[0])          # Level 1
	if not await _wait_for(Game.LEVELS[0], 180):
		_fail("Level 1 never loaded")
		return
	# Walk into Level 1's exit sign.
	var p: Node2D = get_tree().current_scene.get_node("Player")
	p.global_position = Vector2(784, 150)
	# The exit triggers a real fade + change_scene to Level 2.
	if await _wait_for(Game.LEVELS[1], 240):
		print("FLOW TEST: ALL PASS  (Level 1 exit fades into Level 2, index=%d)" % Game.current_index)
		get_tree().quit(0)
	else:
		_fail("Level 2 did not become the current scene after the exit")


func _wait_for(path: String, max_frames: int) -> bool:
	for i in max_frames:
		await get_tree().process_frame
		var cur := get_tree().current_scene
		if cur != null and cur.scene_file_path == path:
			return true
	return false


func _fail(msg: String) -> void:
	print("FLOW TEST: FAIL  (%s)" % msg)
	get_tree().quit(1)
