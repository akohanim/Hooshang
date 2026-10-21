extends Node
const GAME := preload("res://scenes/minigame/mirror_game.gd")

func _ready() -> void:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(160, 120)
	viewport.transparent_bg = false
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	add_child(viewport)
	var game = GAME.new()
	viewport.add_child(game)
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://artifacts/mirror_game"))
	viewport.get_texture().get_image().save_png("res://artifacts/mirror_game/title.png")
	game.mode = GAME.Mode.STAGE
	game.stage = 0
	game._reset_stage()
	game.reflection = Vector2(37, 92)
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	viewport.get_texture().get_image().save_png("res://artifacts/mirror_game/stage1.png")
	game.stage = 3
	game._reset_stage()
	game.reflection = Vector2(103, 65)
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	viewport.get_texture().get_image().save_png("res://artifacts/mirror_game/stage4.png")
	game.stage = 4
	game._reset_stage()
	game.reflection = Vector2(127, 94)
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	viewport.get_texture().get_image().save_png("res://artifacts/mirror_game/stage5.png")
	get_tree().quit()
