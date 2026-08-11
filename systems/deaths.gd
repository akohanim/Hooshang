extends Node
## Running death count for the run (autoload "Deaths"), shown top-right.
##
## Same reasoning as Collectibles: the count has to survive everything that
## throws the player away — room changes inside an Act, death and respawn, and
## Act -> Act loads through Screen.load_scene() — so it lives in an autoload,
## which is this project's home for cross-level state (STYLE_GUIDE §5).
##
## The player reports its own deaths by calling `record()` from `die()`, rather
## than this node hunting for a player to connect to. Levels build their player
## at different times (LdtkWorld makes one in its own _ready), so any "find the
## player after a scene loads" wiring is a race; a one-line call from the thing
## that actually knows it died is not.

signal changed(total: int)

## Deaths so far this run.
var total := 0

## Icon box in HUD px. skull.png is 16px and this layer is scaled by 0.25 onto a
## 320x180 design space, so 64 puts it on screen at exactly 4x — an integer
## multiple, which is the whole point. 52 (matching the fruit counter, whose art
## is much larger) worked out at 3.25x and visibly chewed the eye sockets.
const ICON := 64.0

var _hud: CanvasLayer
var _root: Control
var _label: Label
var _punch: Tween


func _ready() -> void:
	_build_hud()
	# Nothing to count with no world up (the title screen), so nothing to draw.
	Screen.scene_loaded.connect(func(scene: Node) -> void: _hud.visible = scene != null)


## One death. Called by Player.die(), which already guards against re-entry, so
## a single death counts once however many times the kill plane fires.
func record() -> void:
	total += 1
	changed.emit(total)
	_refresh()
	_punch_counter()


## Wipe the run — a fresh game, not a respawn. SaveGame.start_new() calls this
## alongside Collectibles.reset().
func reset() -> void:
	total = 0
	changed.emit(total)
	_refresh()


## This much of a save slot (see systems/save_game.gd). A death count is the one
## number in this game a player might actually be proud of, so it is carried
## rather than recomputed — and there is nothing to recompute it from.
func save_state() -> Dictionary:
	return {"total": total}


func load_state(state: Dictionary) -> void:
	total = int(state.get("total", 0))
	changed.emit(total)
	_refresh()


## Counter in the top-right corner, mirroring Collectibles' fruit count on the
## left. Built in code and parented here so it outlives every level. It sits
## OUTSIDE the game's sub-viewport, so it is drawn at the window's real
## resolution rather than at 320x180 — see systems/screen.gd.
##
## Laid out in a 1280x720 space and scaled down by 4, the same trick DialogueBox
## uses to get type that isn't a magnified pixel grid.
func _build_hud() -> void:
	_hud = CanvasLayer.new()
	_hud.name = "DeathHud"
	_hud.layer = 92  # over the world, under the dialogue box (95)
	_hud.scale = Vector2(0.25, 0.25)
	add_child(_hud)

	# Anchors would resolve against the 320x180 design space and then get scaled
	# by 0.25, landing the group a quarter of the way across the screen. So the
	# right edge is positioned by hand: 320 * 4 = 1280, less a 40px margin.
	_root = Control.new()
	_root.position = Vector2(1048, 30)
	_root.size = Vector2(192, ICON)
	_root.pivot_offset = Vector2(192, ICON * 0.5)  # punch grows leftward, right edge fixed
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hud.add_child(_root)

	var icon := TextureRect.new()
	icon.texture = load("res://assets/skull.png")
	icon.position = Vector2(0, 0)
	icon.size = Vector2(ICON, ICON)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(icon)

	_label = Label.new()
	_label.position = Vector2(72, 0)
	_label.size = Vector2(120, ICON)
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_label.add_theme_font_size_override("font_size", 34)
	_label.add_theme_color_override("font_color", Color(0.98, 0.93, 0.9))
	_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.65))
	_label.add_theme_constant_override("shadow_offset_x", 2)
	_label.add_theme_constant_override("shadow_offset_y", 2)
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_label)
	# Hidden until a world is up: the game boots to the title screen, and a
	# counter floating over the menu belongs to no run at all.
	_hud.visible = Screen.current != null
	_refresh()


func _refresh() -> void:
	if _label != null:
		_label.text = str(total)


## A short knock when the number goes up — enough to catch the eye on a respawn
## without becoming a thing you look at instead of the room.
func _punch_counter() -> void:
	if _root == null:
		return
	if _punch and _punch.is_valid():
		_punch.kill()
	_root.scale = Vector2(1.25, 1.25)
	_punch = create_tween()
	_punch.tween_property(_root, "scale", Vector2.ONE, 0.28) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
