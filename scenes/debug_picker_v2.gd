extends CanvasLayer
## Debug picker v2: every room of the world, opened as a FINISHED player.
##
## Why a second picker rather than a flag on the first. The original launches a
## room cold — no dash, no re-routed doorways, no story flags — which is the
## right thing when you want to see a room in isolation. It is the wrong thing
## for almost everything in the back half of Act I, because that half only exists
## once the story has changed the world: Level_11's entrance points at Level_12
## only after Darkshang has been met, and without it the escape route is not
## there to walk. A room opened cold is a room no player will ever stand in.
##
## So: same list, opposite premise. This one hands you the world as it is after
## the credits — see SaveGame.open_finished() for exactly what that means and,
## more usefully, what it deliberately leaves undone.
##
## Nothing here writes to a save slot. The picker binds nothing, so an afternoon
## spent jumping between rooms cannot touch a real run.
##
## Reached from the main menu's DEBUG PICKER V2 row in debug builds. Escape goes
## back there.
##
## Rows are Buttons in a VBoxContainer, so they work with the mouse AND with the
## keyboard/gamepad through Godot's own focus neighbours — the first row grabs
## focus on open. The original picker is mouse-only, which is a real trap on a
## list long enough to run off the screen.

## The LDtk world every room in this list belongs to.
const WORLD_SCENE := "res://ldtk/Act1World.tscn"
const MENU_SCENE := "res://scenes/ui/MainMenu.tscn"

## Font sizes, in the window's own pixels — this menu renders at native
## resolution rather than through the 320x180 game viewport.
const TITLE_SIZE := 30
const NOTE_SIZE := 15
const ROOM_SIZE := 20

@onready var box: VBoxContainer = $Scroll/Center/VBox

var _first: Button


func _ready() -> void:
	_unscale_ui()
	_build()


## Render at the window's real resolution.
##
## The game draws into a 320x180 viewport and is integer-upscaled with nearest
## filtering, which is correct for pixel art and turns menu text into 4x blocks.
## While this picker is up the window scales CANVAS ITEMS at its native size, the
## same trick scenes/debug_level_picker.gd uses — see the note there.
func _unscale_ui() -> void:
	var w := get_window()
	w.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	w.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_IGNORE
	w.content_scale_size = Vector2i.ZERO
	w.content_scale_factor = 1.0


func _build() -> void:
	box.add_child(_label("DEBUG PICKER  v2", TITLE_SIZE))
	box.add_child(_label("every room, opened as a player who has finished the game",
		NOTE_SIZE))
	box.add_child(_label("dash granted  ·  escape route open  ·  shadow already met",
		NOTE_SIZE))
	box.add_child(HSeparator.new())

	# Read off the world itself, so a room added in LDtk appears here with no
	# change to this file — the same reason the original builds its list at
	# runtime. The holder is stood up and freed without ever entering the tree:
	# LdtkWorld.rooms_in is static precisely so a menu can ask what the rooms are
	# without paying for a player, lights and signal wiring to find out.
	var holder: Node = load(WORLD_SCENE).instantiate()
	var world_scene: PackedScene = holder.world_scene
	holder.free()
	if world_scene == null:
		box.add_child(_label("Act1World has no world_scene — the .tscn is broken",
			ROOM_SIZE))
		return
	var world := world_scene.instantiate()
	var rooms := LdtkWorld.rooms_in(world)
	for i in rooms.size():
		var name := rooms[i].name
		var btn := Button.new()
		btn.text = "Room %-3d %s" % [i + 1, name]
		btn.add_theme_font_size_override("font_size", ROOM_SIZE)
		btn.pressed.connect(_open.bind(name))
		box.add_child(btn)
		if _first == null:
			_first = btn
	world.free()

	box.add_child(HSeparator.new())
	box.add_child(_label("ESC — back to the main menu", NOTE_SIZE))
	if _first != null:
		_first.grab_focus()


func _open(room_name: String) -> void:
	SaveGame.open_finished(room_name)
	queue_free()


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("pause"):
		get_viewport().set_input_as_handled()
		# Handled BEFORE leaving, because change_scene_to_file frees this node
		# and get_viewport() is null the moment it does — the bug that made the
		# first picker look broken from the menu (see main_menu.gd's _input).
		get_tree().change_scene_to_file(MENU_SCENE)


func _label(text: String, size: int) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", size)
	return l
