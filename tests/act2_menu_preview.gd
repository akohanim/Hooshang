extends Node
const OUT := "res://output/act2_polish/menu_labels"
func _ready() -> void:
	SaveGame.dir = "user://act2_menu_preview"
	SaveGame.unbind()
	for i in 3: SaveGame.erase(i)
	SaveGame._write(0, {"schema":SaveGame.SCHEMA,"world":"res://ldtk/Act2World.tscn",
		"saved_at":1,"world_state":{"room":"Prison_Y03"},
		"visited":["Act_2_Level_0","Level_2","Prison_Hub","Prison_R01","Prison_B03","Prison_Y03"],
		"collectibles":{"total":16},"deaths":{"total":2},"play_seconds":125})
	var menu := preload("res://scenes/ui/MainMenu.tscn").instantiate()
	add_child(menu)
	for i in 60: await get_tree().physics_frame
	DirAccess.make_dir_recursive_absolute(OUT)
	await capture("continue")
	menu._show_levels(0)
	await capture("level_select")
	SaveGame.erase(0)
	get_tree().quit()
func capture(label: String) -> void:
	await get_tree().process_frame
	RenderingServer.force_draw()
	get_tree().root.get_texture().get_image().save_png(OUT + "/" + label + ".png")
