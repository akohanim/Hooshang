extends CanvasLayer
## Debug level picker: a quick launcher for testing levels — and individual
## ROOMS of the LDtk world — without playing through the game.
##
## NOT the front door any more. `run/main_scene` is MainMenu.tscn; this is
## reached from its DEBUG PICKER row, which ships in EXPORTED builds too — the
## gate on OS.is_debug_build() was removed on purpose, because it hid this from
## the itch.io build, which is the only one most people play. The player-facing
## LEVEL SELECT still exists alongside it and still shows only what a save has
## reached; this is the unrestricted list. Both are on the menu deliberately.
##
## The distinction is the whole reason both exist: this one lists
## every room and every scene in the project including prototypes, with no notion
## of what a run has unlocked, because that is what a developer wants and exactly
## what a player must not have. The player-facing level select lives on the main
## menu and offers only rooms a save slot has actually stood in.
##
## Nothing here writes to a save slot: launching from the picker leaves
## SaveGame's slot unbound, so a session spent jumping between rooms cannot
## overwrite a run.
##
## The room buttons are built at runtime from the world scene itself, so rooms
## added in LDtk show up here with no changes to this file.

## The LDtk worlds. Each gets a labelled button per room, so a second Act
## shows up here with no changes beyond adding its entry to this dict.
const WORLDS := {
	"Act1": "res://ldtk/Act1World.tscn",
	"Act2": "res://ldtk/Act2World.tscn",
	"Act3": "res://ldtk/Act3World.tscn",
}

## Hand-built scenes that aren't rooms of an LDtk world.
const LEVELS := {
	"Act1World": "res://ldtk/Act1World.tscn",
	"Act2World": "res://ldtk/Act2World.tscn",
	"Act3World": "res://ldtk/Act3World.tscn",
}

## Font size for the generated room buttons, matching the ones in the scene.
const ROOM_FONT_SIZE := 20
## Window height the font sizes in this scene were picked against. The menu is
## scaled by (real height / this) so it fills the same share of a small window
## and a maximised one — see _unscale_ui().
const DESIGN_HEIGHT := 720.0

@onready var box: VBoxContainer = $Scroll/Center/VBox

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


## One button per room of every world in WORLDS, in play order, labelled by
## which Act it belongs to.
##
## A world's rooms only exist once its LdtkWorld has instantiated the imported
## .ldtk scene in _ready(), which hasn't happened here — so read the world
## scene off the (tree-less) root instead of hardcoding the .ldtk path a
## second time, and let LdtkWorld.rooms_in() decide the ordering so this list
## can't disagree with the order the game actually plays them in.
func _build_room_buttons() -> void:
	for world_label: String in WORLDS:
		_build_room_buttons_for(world_label, WORLDS[world_label])


func _build_room_buttons_for(world_label: String, world_path: String) -> void:
	var holder := load(world_path).instantiate() as LdtkWorld
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
		btn.text = "%s Room %d  —  %s" % [world_label, i + 1, rooms[i].name]
		btn.add_theme_font_size_override("font_size", ROOM_FONT_SIZE)
		btn.pressed.connect(_on_room_pressed.bind(rooms[i].name, world_path))
		$Scroll/Center/VBox/Rooms.add_child(btn)
	world.free()


func _on_room_pressed(room_name: String, world_path: String) -> void:
	LdtkWorld.debug_start_room = room_name
	_launch(world_path)


func _on_level_pressed(path: String) -> void:
	LdtkWorld.debug_start_room = ""  # a normal launch always opens room 1
	_launch(path)


## Hand over to the world. The level goes into Screen's game viewport, not the
## scene root, so the picker (and every other UI scene) stays on the window's
## own full-resolution surface — see systems/screen.gd.
func _launch(path: String) -> void:
	_restore_scale()
	# Unbound, and cleared of anything a previous run staged: a dev launch must
	# neither write to a slot nor inherit one's dash and re-routed doorways, or
	# "start me in room 14" would silently mean "start me in room 14 as whoever
	# last played".
	SaveGame.unbind()
	Screen.load_scene(path)
	queue_free()
