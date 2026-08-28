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

## How many times denser the token surface is than the world. A whole number, so
## its texels land on whole output pixels and the composite never resamples —
## which would undo the entire exercise.
const TOKEN_DENSITY := 2

var container: SubViewportContainer
var viewport: SubViewport

## The token surface: a THIRD surface, between the world and the UI.
##
## Collectibles are drawn here instead of in the world. The world is rasterised
## at 320x180 and nothing in it can be finer than that — not a different node
## type, not a different z band, not a Parallax2D; density is a property of the
## render target. This viewport is 640x360 framing the SAME world rectangle, so
## a token drawn in it occupies the same screen space out of four times as many
## texels.
##
## Tokens and not scenery, deliberately. The two objections to a high-density
## layer are camera sync and lighting: anything here is outside the world's
## CanvasModulate and Light2Ds, so it ignores the room's darkness. For a wall
## that would be fatal. For a collectible it is close to what you want — it
## stays legible in a black cave, the way a Celeste strawberry does.
var token_container: SubViewportContainer
var token_viewport: SubViewport
var token_camera: Camera2D

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
	# A SubViewport built in code does NOT pick up the project's own
	# textures/canvas_textures/default_texture_filter=0 (Nearest) setting —
	# that only seeds the ROOT viewport. Every SubViewport has its own copy of
	# this property and it starts on the engine's hardcoded default, Linear,
	# regardless of the project setting. Silently, because nothing here ever
	# asked the question: the whole world — every tile, every sprite, every
	# UI bubble drawn inside it — has been rasterising SOFT instead of the
	# crisp pixel art CLAUDE.md and every art tool in tools/ assumes, and nothing
	# short of sampling actual rendered pixels caught it (a screenshot's own
	# nearest-neighbour upscale on the way to disk, in room_shot.gd and
	# elsewhere, just blows the blur up bigger — it cannot un-blend pixels that
	# were already blended before it ran). token_viewport below already carries
	# this exact line for the same reason; this was the one surface that didn't.
	viewport.canvas_item_default_texture_filter = \
		Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	# Positional sound (the musical tiles) needs a listener in the viewport that
	# actually contains the AudioStreamPlayer2Ds, or they play silently.
	viewport.audio_listener_enable_2d = true
	container.add_child(viewport)

	# In front of the world (a later sibling on the same layer), behind every UI
	# CanvasLayer — the dialogue box is 95, the counters 92.
	token_container = SubViewportContainer.new()
	token_container.name = "TokenView"
	# stretch OFF: it would drag this viewport back down to the container's size
	# and there would be no density left. Instead the container is its full
	# 640x360 and scaled by 1/density, so it covers the same design rect.
	token_container.stretch = false
	token_container.size = Vector2(GAME_SIZE * TOKEN_DENSITY)
	token_container.scale = Vector2.ONE / float(TOKEN_DENSITY)
	token_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(token_container)

	token_viewport = SubViewport.new()
	token_viewport.name = "TokenViewport"
	token_viewport.size = GAME_SIZE * TOKEN_DENSITY
	token_viewport.transparent_bg = true     # the world shows through
	token_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	token_viewport.canvas_item_default_texture_filter = \
		Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	token_container.add_child(token_viewport)

	token_camera = Camera2D.new()
	token_camera.name = "TokenCamera"
	# Zoom = density, so this viewport frames exactly the world rectangle the
	# game viewport does: 640px at 2x covers the same 320 world units.
	token_camera.zoom = Vector2(TOKEN_DENSITY, TOKEN_DENSITY)
	token_viewport.add_child(token_camera)
	# After everything else, so the sync below reads a camera that has already
	# finished smoothing and clamping this frame rather than last frame's.
	process_priority = 100


## Keep the token surface framed on exactly what the world surface is showing.
##
## Mirrors the game camera's SCREEN CENTRE, not its position: the player's
## Camera2D smooths and is clamped to the room's limits, so its `position` is
## where it is heading and `get_screen_center_position()` is where it actually
## ended up. Using the first makes every token swim against the wall behind it
## while the camera settles.
func _process(_delta: float) -> void:
	if token_camera == null or viewport == null:
		return
	var cam := viewport.get_camera_2d()
	if cam != null:
		token_camera.global_position = cam.get_screen_center_position()


## Put a visual on the token surface. World coordinates carry across unchanged —
## both viewports frame the same rectangle — so a node added here appears exactly
## where its global_position says, at density x the resolution.
##
## Returns false if there is no token surface (a test that built the world by
## hand rather than through Screen), so callers can fall back to drawing
## themselves in the world.
func add_token(node: Node2D) -> bool:
	if token_viewport == null:
		return false
	token_viewport.add_child(node)
	return true


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
	if scene != null:
		viewport.add_child(scene)
	scene_loaded.emit(scene)
	return scene


## Take the world down without putting another one up — leaving a level for the
## title screen, which is the only thing that ever wants an empty game viewport.
##
## `current` going null is the signal the rest of the game already reads: the
## pause menu refuses to open with no world (see PauseMenu.can_pause), and the
## two HUD counters take themselves off screen, so the menu is not drawn over a
## death count from a run that is no longer loaded.
func clear() -> void:
	set_scene(null)


## Path of the loaded world, for code that used to read
## `get_tree().current_scene.scene_file_path`.
func current_path() -> String:
	return current.scene_file_path if current != null else ""
