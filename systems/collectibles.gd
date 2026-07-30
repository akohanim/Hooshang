extends Node
## Running total of pomegranates (autoload "Collectibles").
##
## Lives here rather than on the player or a level because the count has to
## survive everything that throws those away: room changes inside an Act, death
## and respawn, and Act -> Act loads through Screen.load_scene(). An autoload is
## the project's home for cross-level state (STYLE_GUIDE §5).
##
## It also remembers WHICH fruit have been taken, not just how many. Rooms in an
## Act all stay loaded, so picking one up frees that node and it stays gone — but
## reloading the world (retrying from the debug picker, or coming back to an Act)
## would otherwise re-spawn fruit you already banked and let you farm the count.

signal changed(total: int)
signal collected(total: int)

## The banked total, carried across every level.
var total := 0

## collect_id -> true, for fruit already taken this session.
var _taken := {}

var _hud: CanvasLayer
var _label: Label


func _ready() -> void:
	_build_hud()


## Identifies the world a fruit belongs to, so two Acts can't collide on
## position alone.
func world_key() -> String:
	return Screen.current_path() if Screen.current != null else "?"


func is_taken(id: String) -> bool:
	return _taken.has(id)


func collect(id: String, amount := 1) -> void:
	if _taken.has(id):
		return
	_taken[id] = true
	total += amount
	changed.emit(total)
	collected.emit(total)
	_refresh()


## Wipe the run — a fresh game, not a respawn. Nothing calls this yet; it is the
## hook for a proper new-game flow.
func reset() -> void:
	total = 0
	_taken.clear()
	changed.emit(total)
	_refresh()


## Counter in the corner. Built in code and parented here so it outlives every
## level, exactly like Game's fade layer. It sits OUTSIDE the game's
## sub-viewport, so it is drawn at the window's real resolution — see
## systems/screen.gd.
func _build_hud() -> void:
	_hud = CanvasLayer.new()
	_hud.name = "CollectibleHud"
	_hud.layer = 92  # over the world, under the dialogue box (95)
	_hud.scale = Vector2(0.25, 0.25)  # authored at 1280x720, like DialogueBox
	add_child(_hud)

	var icon := TextureRect.new()
	icon.texture = load("res://assets/props/pomegranate/frame_000.png")
	icon.position = Vector2(40, 36)
	icon.size = Vector2(52, 52)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hud.add_child(icon)

	_label = Label.new()
	_label.position = Vector2(100, 36)
	_label.size = Vector2(180, 52)
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_label.add_theme_font_size_override("font_size", 34)
	_label.add_theme_color_override("font_color", Color(0.98, 0.93, 0.9))
	_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.65))
	_label.add_theme_constant_override("shadow_offset_x", 2)
	_label.add_theme_constant_override("shadow_offset_y", 2)
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hud.add_child(_label)
	_refresh()


func _refresh() -> void:
	if _label != null:
		_label.text = str(total)
