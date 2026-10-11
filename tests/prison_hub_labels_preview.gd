extends Node
## Staged camera views for visual review, not traversal evidence.
func _ready() -> void:
	SaveGame.unbind()
	LdtkWorld.debug_start_room="Prison_Hub"
	Screen.load_scene("res://ldtk/Act2World.tscn")
	for i in 20:await get_tree().physics_frame
	var world=Screen.current
	for point in [Vector2(100,58),Vector2(560,106),Vector2(440,322),Vector2(292,346)]:
		if point.x==292:
			world.rescued=true
			world._refresh()
		world.player.respawn(world.current_room.global_position+point)
		for i in 45:await get_tree().physics_frame
		await RenderingServer.frame_post_draw
		Screen.viewport.get_texture().get_image().save_png("res://output/prison_challenge/hub/labels_%d.png" % int(point.x))
	world.queue_free()
	for i in 3:await get_tree().physics_frame
	get_tree().quit()
