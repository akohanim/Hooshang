extends Node
## Dev capture harness, not pass/fail (see room_shot.gd for the family):
## photograph a Pond and a swimming Hooshang in isolation, no LdtkWorld
## needed. Runs WINDOWED — 2D does not rasterise headless.
##
## The backdrop is a checkerboard rather than a flat colour specifically so
## the shot can prove the water is TRANSPARENT and not a solid tint — a flat
## backdrop would look the same either way.
##
## Usage: Godot --path . res://tests/pond_shot.tscn
## Shot lands in user://shots/pond.png — the absolute path is printed.

const OUT := "user://shots"
const POND_SCENE := preload("res://scenes/props/zones/Pond.tscn")
const PLAYER := preload("res://scenes/characters/hooshang/Hooshang.tscn")
const VIEW_SIZE := Vector2i(320, 180)


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	# SubViewportContainer + SubViewport, the same pair systems/screen.gd
	# itself uses for the game surface — a bare SubViewport with no container
	# never actually renders (measured: it just returns a blank frame).
	var container := SubViewportContainer.new()
	add_child(container)
	var viewport := SubViewport.new()
	viewport.size = VIEW_SIZE
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	# A SubViewport built in code does NOT inherit the project's
	# default_texture_filter=0 — see CLAUDE.md's screen_test note on this
	# exact gotcha (it shipped once as the whole game rasterising soft).
	viewport.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	container.add_child(viewport)

	var scene := Node2D.new()
	viewport.add_child(scene)

	var checker := Node2D.new()
	scene.add_child(checker)
	for y in range(0, VIEW_SIZE.y, 8):
		for x in range(0, VIEW_SIZE.x, 8):
			var tile := ColorRect.new()
			tile.size = Vector2(8, 8)
			tile.position = Vector2(x, y)
			tile.color = Color(0.85, 0.7, 0.4) if ((x / 8 + y / 8) % 2 == 0) else Color(0.55, 0.4, 0.18)
			checker.add_child(tile)

	var pond: Area2D = POND_SCENE.instantiate()
	pond.size = Vector2(160.0, 96.0)
	pond.fish_count = 5
	scene.add_child(pond)
	pond.position = Vector2(VIEW_SIZE.x * 0.5, VIEW_SIZE.y * 0.5 + 10.0)

	var player: Player = PLAYER.instantiate()
	scene.add_child(player)
	player.input_locked = true
	await get_tree().process_frame
	player.respawn(pond.position + Vector2(-20.0, 10.0))

	await _frames(90)  # let him settle into a swim and the shimmer/fish animate
	await RenderingServer.frame_post_draw
	var img: Image = viewport.get_texture().get_image()
	img.resize(img.get_width() * 3, img.get_height() * 3, Image.INTERPOLATE_NEAREST)
	img.save_png("%s/pond.png" % OUT)
	print("saved %s/pond.png  (player state %s, swimming %s)" % [
		ProjectSettings.globalize_path(OUT), player.state_name(), player.swimming()])
	get_tree().quit()


func _frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame
