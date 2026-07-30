extends CanvasLayer
## Debug level picker: a quick launcher for testing levels — and individual
## ROOMS of the LDtk world — without playing through the game. Set this as the
## main scene during dev, then swap back to Level1Office.tscn before shipping.
##
## The room buttons are built at runtime from the world scene itself, so rooms
## added in LDtk show up here with no changes to this file.

## The LDtk world. Its rooms each get their own button.
const WORLD_SCENE := "res://ldtk/Act1World.tscn"

## Hand-built scenes that aren't rooms of the LDtk world.
const LEVELS := {
	"Level1": "res://scenes/levels/act1_office/Level1Office.tscn",
	"Level2": "res://scenes/levels/act1_office/Level2.tscn",
	"LDtkOffice": "res://ldtk/Level_1_Office_Test.tscn",
	"Act1World": WORLD_SCENE,
}

## Font size for the generated room buttons, matching the ones in the scene.
const ROOM_FONT_SIZE := 20
## Window height the font sizes in this scene were picked against. The menu is
## scaled by (real height / this) so it fills the same share of a small window
## and a maximised one — see _unscale_ui().
const DESIGN_HEIGHT := 720.0

@onready var box: VBoxContainer = $Center/VBox

var _saved_scale := {}


func _ready() -> void:
	_unscale_ui()
	for name: String in LEVELS:
		var btn := box.get_node_or_null(name) as Button
		if btn:
			btn.pressed.connect(_on_level_pressed.bind(LEVELS[name]))
	_build_room_buttons()


## Render this menu at the window's real resolution.
##
## The game renders into a 320x180 viewport and is blown up 4x with nearest
## filtering — correct for pixel art, but it turned every glyph in this menu into
## a chunky 4x-magnified block. So while the picker is up, the window scales
## CANVAS ITEMS only, at its native size (content_scale_size zeroed): fonts are
## then rasterised at their real pixel size instead of being magnified, and
## content_scale_factor grows the whole menu with the window so it doesn't shrink
## to a postage stamp when maximised. Everything is put back before handing over
## to a level, so the game itself still gets pixel-perfect integer scaling.
func _unscale_ui() -> void:
	var w := get_window()
	_saved_scale = {
		"mode": w.content_scale_mode,
		"aspect": w.content_scale_aspect,
		"size": w.content_scale_size,
		"factor": w.content_scale_factor,
	}
	w.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	w.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_IGNORE
	w.content_scale_size = Vector2i.ZERO  # zero = "use the window's own size"
	w.content_scale_factor = clampf(w.size.y / DESIGN_HEIGHT, 1.0, 3.0)


func _restore_scale() -> void:
	if _saved_scale.is_empty():
		return
	var w := get_window()
	w.content_scale_mode = _saved_scale["mode"]
	w.content_scale_aspect = _saved_scale["aspect"]
	w.content_scale_size = _saved_scale["size"]
	w.content_scale_factor = _saved_scale["factor"]


## One button per room of the LDtk world, in play order.
##
## Act1World's rooms only exist once its LdtkWorld has instantiated the imported
## .ldtk scene in _ready(), which hasn't happened here — so read the world scene
## off the (tree-less) root instead of hardcoding the .ldtk path a second time,
## and let LdtkWorld.rooms_in() decide the ordering so this list can't disagree
## with the order the game actually plays them in.
func _build_room_buttons() -> void:
	var holder := load(WORLD_SCENE).instantiate() as LdtkWorld
	if holder == null:
		return
	var world_scene: PackedScene = holder.world_scene
	holder.free()
	if world_scene == null:
		return

	var world := world_scene.instantiate()
	var rooms := LdtkWorld.rooms_in(world)
	for i in rooms.size():
		var btn := Button.new()
		btn.text = "Room %d  —  %s" % [i + 1, rooms[i].name]
		btn.add_theme_font_size_override("font_size", ROOM_FONT_SIZE)
		btn.pressed.connect(_on_room_pressed.bind(rooms[i].name))
		$Center/VBox/Rooms.add_child(btn)
	world.free()


func _on_room_pressed(room_name: String) -> void:
	LdtkWorld.debug_start_room = room_name
	_launch(WORLD_SCENE)


func _on_level_pressed(path: String) -> void:
	LdtkWorld.debug_start_room = ""  # a normal launch always opens room 1
	_launch(path)


func _launch(path: String) -> void:
	_restore_scale()
	get_tree().change_scene_to_file(path)
