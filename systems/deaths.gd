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

## The counter is not on screen the whole run — it surfaces for HUD_SHOW_TIME
## after a death, then fades out over HUD_FADE_TIME and gets out of the way.
const HUD_SHOW_TIME := 2.0
const HUD_FADE_TIME := 0.2

var _hud: CanvasLayer
var _root: Control
var _label: Label
var _punch: Tween
var _fade: Tween
## Bumped every time the counter is brought up, so a death while it is already
## showing invalidates the earlier hide timer — it stays up a full HUD_SHOW_TIME
## from the LATEST death rather than hiding on the first one's clock.
var _show_token := 0


func _ready() -> void:
	_build_hud()
	# The counter stays hidden during play and surfaces only on a death (see
	# _show_briefly). This just makes sure a world going away — back to the title
	# screen — always leaves it hidden; it never turns it back ON.
	Screen.scene_loaded.connect(func(scene: Node) -> void:
		if scene == null:
			_hud.visible = false)


## One death. Called by Player.die(), which already guards against re-entry, so
## a single death counts once however many times the kill plane fires.
func record() -> void:
	total += 1
	changed.emit(total)
	_refresh()
	_punch_counter()
	# Bring the counter up for a couple of seconds so the death reads, then hide.
	_show_briefly()


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
	# Hidden to begin with, on the title screen and in play alike — it comes up
	# only when the player dies (see _show_briefly).
	_hud.visible = false
	_refresh()


func _refresh() -> void:
	if _label != null:
		_label.text = str(total)


## Bring the counter up and (re)start the countdown to hiding it. Called on every
## death: a second one while it is still showing bumps _show_token, so the
## earlier timer's timeout is ignored and it stays up a full HUD_SHOW_TIME from
## the latest death, then fades out.
func _show_briefly() -> void:
	if _hud == null or _root == null:
		return
	if _fade and _fade.is_valid():
		_fade.kill()
	_root.modulate.a = 1.0
	_hud.visible = true
	_show_token += 1
	var token := _show_token
	# A plain SceneTreeTimer, so it PAUSES with the game — the counter must not
	# tick away behind the pause menu (same reasoning as the respawn holds).
	get_tree().create_timer(HUD_SHOW_TIME).timeout.connect(func() -> void:
		if token != _show_token or _hud == null or _root == null:
			return
		_fade = create_tween()
		_fade.tween_property(_root, "modulate:a", 0.0, HUD_FADE_TIME)
		_fade.tween_callback(func() -> void:
			if token == _show_token and _hud != null:
				_hud.visible = false))


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
