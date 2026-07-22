extends CanvasLayer
## Debug level picker: a quick launcher for testing individual levels without
## playing through the whole game. Set this as the main scene during dev, then
## swap back to Level1Office.tscn before shipping.

const LEVELS := {
	"Level1": "res://scenes/levels/act1_office/Level1Office.tscn",
	"Level2": "res://scenes/levels/act1_office/Level2.tscn",
}


func _ready() -> void:
	for name: String in LEVELS.keys():
		var btn = get_node_or_null("VBox/" + name)
		if btn:
			btn.pressed.connect(_on_level_pressed.bind(LEVELS[name]))


func _on_level_pressed(path: String) -> void:
	get_tree().change_scene_to_file(path)
