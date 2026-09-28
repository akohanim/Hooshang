extends CanvasLayer
## Reusable, root-level results overlay. Set stats before adding to the tree.
## Running ActResults.tscn directly supplies preview data without touching saves.
signal continued
const CONFIG = preload("res://resources/scoring/act_score.gd")
@export var tally_time := 0.65
@export var line_pause := 0.18
@export var tick_interval := 0.045
var stats: Dictionary = {}
var complete := false
var _score: Dictionary
var _rows: Array[Control] = []
var _values: Array[int] = []
var _line := 0
var _elapsed := 0.0
var _tick_elapsed := 0.0
var _was_paused := false
var _leaving := false
var _preview := false
var _touch_gesture = preload("res://scenes/ui/touch/touch_menu_gesture.gd").new()
var _pop: Tween

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_was_paused = get_tree().paused
	get_tree().paused = true
	_preview = stats.is_empty()
	if _preview:
		stats = {"world": "res://ldtk/Act1World.tscn", "seconds": 423.0,
			"lemons": 8, "available": 8, "deaths": 12}
	_score = CONFIG.calculate(stats)
	$Root/Title.text = str(_score.title) + "  /  ACT COMPLETE"
	var font := FontVariation.new()
	font.base_font = ThemeDB.fallback_font
	font.variation_embolden = 0.28
	font.spacing_glyph = 1
	for label in $Root.find_children("*", "Label", true, false):
		label.add_theme_font_override("font", font)
	_rows.assign($Root/Rows.get_children())
	_values = [int(_score.time), int(_score.lemons), int(_score.deaths),
		int(_score.all_lemons), int(_score.deathless), int(_score.final)]
	_rows[0].get_node("Name").text = "TIME   %s" % _format_time(float(stats.seconds))
	_rows[1].get_node("Name").text = "LEMONS   %d / %d" % [stats.lemons, stats.available]
	_rows[2].get_node("Name").text = "DEATHS   %d" % stats.deaths
	for row in _rows:
		row.visible = false
	_rows[0].visible = true
	_draw_value(0, 0)

func _process(delta: float) -> void:
	if InputDevice.is_touch():
		$Root/Hint.text = "TAP TO CONTINUE" if complete else "TAP TO SKIP TALLY"
	if complete or _leaving:
		return
	_elapsed += delta
	if _elapsed <= tally_time:
		var progress := clampf(_elapsed / tally_time, 0.0, 1.0)
		_draw_value(_line, roundi(_values[_line] * progress))
		_tick_elapsed += delta
		if _values[_line] != 0 and _tick_elapsed >= tick_interval:
			_tick_elapsed = 0.0
			$Tick.play()
	elif not _rows[_line].has_meta("done"):
		_draw_value(_line, _values[_line])
		_rows[_line].set_meta("done", true)
		$Tick.stop()
		$LineDone.play()
		if _line == _rows.size() - 1:
			_reveal_final()
	if _elapsed >= tally_time + line_pause:
		_line += 1
		_elapsed = 0.0
		_tick_elapsed = 0.0
		if _line == _rows.size():
			_finish()
		else:
			_rows[_line].visible = true
			_draw_value(_line, 0)

func _draw_value(index: int, value: int) -> void:
	var prefix := "+" if value > 0 and index != _rows.size() - 1 else ""
	_rows[index].get_node("Value").text = prefix + str(value)

func _reveal_final() -> void:
	var row: Control = _rows.back()
	row.pivot_offset = row.size * 0.5
	row.scale = Vector2(1.10, 1.10)
	_pop = create_tween()
	_pop.tween_property(row, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	$FinalDone.play()

func _finish() -> void:
	complete = true
	$Tick.stop()
	$Root/Hint.text = "TAP TO CONTINUE" if InputDevice.is_touch() else "JUMP / CONFIRM TO CONTINUE"

func skip_tally() -> void:
	if complete:
		return
	for i in _rows.size():
		_rows[i].visible = true
		_draw_value(i, _values[i])
	_reveal_final()
	_finish()

func _input(event: InputEvent) -> void:
	if event.is_echo() or _leaving:
		return
	if event is InputEventScreenTouch or event is InputEventScreenDrag:
		InputDevice.note_touch()
		get_viewport().set_input_as_handled()
		if _touch_gesture.read(event).has("tap"):
			_confirm()
		return
	if event.is_action_pressed("jump") or event.is_action_pressed("ui_accept"):
		get_viewport().set_input_as_handled()
		_confirm()

func _confirm() -> void:
	if not complete:
		skip_tally()
	else:
		_leaving = true
		get_tree().paused = _was_paused
		continued.emit()
		if _preview:
			get_tree().quit()

func _exit_tree() -> void:
	get_tree().paused = _was_paused

static func _format_time(value: float) -> String:
	var whole := int(value)
	return "%02d:%02d" % [whole / 60, whole % 60]
