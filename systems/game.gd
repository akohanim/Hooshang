extends Node
## Global level progression + Celeste-style room transitions (autoload "Game").
##
## Levels are chained in LEVELS order. Reaching a level's exit fades out, loads
## the next level, and fades back in. The currently-loaded level IS the running
## checkpoint: death respawns at its start (see LevelBase), and completed levels
## are never replayed — so passing an exit sign permanently banks progress.

signal level_changed(index: int)

const LEVELS: Array[String] = [
	"res://scenes/levels/act1_office/Level1Office.tscn",
	"res://scenes/levels/act1_office/Level2.tscn",
]

## Fade duration each way, seconds. Short = snappy, Celeste-like.
@export var fade_time := 0.18

## Tests flip this on to exercise progression logic without swapping scenes.
var test_mode := false
var current_index := 0
var completed := false

var _busy := false
var _fade: ColorRect
var _banner: Label


func _ready() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 128  # above everything, incl. dialogue + debug overlay
	add_child(layer)
	_fade = ColorRect.new()
	_fade.color = Color(0, 0, 0, 0)
	_fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(_fade)
	_banner = Label.new()
	_banner.set_anchors_preset(Control.PRESET_FULL_RECT)
	_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_banner.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_banner.add_theme_font_size_override("font_size", 16)
	_banner.modulate = Color(1, 0.85, 0.4)
	_banner.visible = false
	layer.add_child(_banner)


## Sync the tracked index to whatever level is actually running, so launching a
## level directly (F6) still tracks progress correctly. Called by LevelBase.
func set_current(scene_path: String) -> void:
	var i := LEVELS.find(scene_path)
	if i != -1:
		current_index = i


## Advance past the current level's exit to the next level (or finish the run).
func advance() -> void:
	if _busy:
		return
	_busy = true
	var has_next := current_index + 1 < LEVELS.size()

	if test_mode:  # progression logic only, no scene swap
		if has_next:
			current_index += 1
		else:
			completed = true
		level_changed.emit(current_index)
		_busy = false
		return

	await _fade_to(1.0)
	if has_next:
		current_index += 1
		get_tree().change_scene_to_file(LEVELS[current_index])
		await get_tree().process_frame
		level_changed.emit(current_index)
		await _fade_to(0.0)
	else:
		# No further level yet — a brief "escaped" beat, then restart the run.
		completed = true
		_banner.text = "YOU ESCAPED\n(for now)"
		_banner.visible = true
		await get_tree().create_timer(1.6).timeout
		current_index = 0
		get_tree().change_scene_to_file(LEVELS[0])
		await get_tree().process_frame
		_banner.visible = false
		await _fade_to(0.0)
	_busy = false


func _fade_to(a: float) -> void:
	var t := create_tween()
	t.tween_property(_fade, "color:a", a, fade_time)
	await t.finished
