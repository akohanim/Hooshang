extends Node
## Owns the window's two independent render surfaces, so UI work can never
## change how the game looks.
##
## WHY THIS EXISTS
## The game is pixel art authored for a 320x180 screen; the dialogue box wants
## real type, which needs far more than 180 scanlines to rasterise. Those two
## wants used to fight over one setting: making the whole window render at
## native resolution (so fonts could be sharp) also stopped the world being
## rasterised at 320x180 — and Hooshang's sprites, which are 88px source art
## displayed at 0.39 scale, silently gained about 2.6x more detail. Changing a
## font is not supposed to redraw the character.
##
## So they get separate surfaces:
##
##   root viewport (window resolution)     <- UI: DialogueBox, overlays, fades
##     └─ GameView (SubViewportContainer)
##          └─ GameViewport (320x180)      <- the world: levels, player, tiles
##
## Everything inside GameViewport is rasterised at 320x180 and then scaled up by
## a whole number, exactly as before. Everything outside it is drawn at the
## window's real resolution. Neither can affect the other's sampling, which is
## the entire point — the dialogue box's font, size and animations are now
## invisible to the world, and the world's pixel grid is invisible to the UI.
##
## Levels are loaded with `Screen.load_scene()` rather than
## `get_tree().change_scene_to_file()`, because the world has to land INSIDE the
## sub-viewport. `Screen.current` is the equivalent of `get_tree().current_scene`.

signal scene_loaded(scene: Node)

## The game's authored resolution. Must match display/window/size/viewport_* in
## project.godot, which is what the whole window's design space is sized to.
const GAME_SIZE := Vector2i(320, 180)

var container: SubViewportContainer
var viewport: SubViewport

## The world scene currently loaded, or null. Mirrors get_tree().current_scene
## for anything running inside the sub-viewport.
var current: Node


func _ready() -> void:
	# Behind the UI: this is layer 0, the dialogue box sits on CanvasLayer 95.
	container = SubViewportContainer.new()
	container.name = "GameView"
	container.stretch = true          # keeps the SubViewport sized to this
	container.size = Vector2(GAME_SIZE)
	container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(container)

	viewport = SubViewport.new()
	viewport.name = "GameViewport"
	viewport.size = GAME_SIZE
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	# Positional sound (the musical tiles) needs a listener in the viewport that
	# actually contains the AudioStreamPlayer2Ds, or they play silently.
	viewport.audio_listener_enable_2d = true
	container.add_child(viewport)


## Hand the world any input the UI didn't want.
##
## A SubViewport does not receive the window's key events on its own, so
## _unhandled_input() inside the world (R-to-retry on LdtkWorld and LevelBase)
## never fired until this forwarded them. Doing it from _unhandled_input rather
## than _input is deliberate and is the isolation working in the other
## direction: the dialogue box calls set_input_as_handled() on the key that
## advances a line, so that press is consumed before it ever reaches here and
## cannot also make Hooshang jump.
func _unhandled_input(event: InputEvent) -> void:
	if viewport != null:
		viewport.push_input(event)


## Replace the world with `path`. The equivalent of change_scene_to_file(), but
## landing inside the game viewport.
func load_scene(path: String) -> Node:
	return set_scene(load(path).instantiate())


func set_scene(scene: Node) -> Node:
	for child in viewport.get_children():
		viewport.remove_child(child)
		child.queue_free()
	current = scene
	viewport.add_child(scene)
	scene_loaded.emit(scene)
	return scene


## Path of the loaded world, for code that used to read
## `get_tree().current_scene.scene_file_path`.
func current_path() -> String:
	return current.scene_file_path if current != null else ""
