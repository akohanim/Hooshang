extends Node2D

# ── Level registry ─────────────────────────────────────────────────────────────
# Add entries here as new levels are created.
const LEVELS : Array[Dictionary] = [
	{ "label": "Tutorial",  "scene": "res://scenes/Main.tscn"   },
	{ "label": "Level 1",   "scene": "res://scenes/Level1.tscn" },
	{ "label": "Level 2",   "scene": "res://scenes/Level2.tscn" },
	{ "label": "Level 3",   "scene": "res://scenes/Level3.tscn" },
	{ "label": "Level 4",   "scene": "res://scenes/Level4.tscn" },
]

# ── Layout constants ──────────────────────────────────────────────────────────
const BUTTON_W    := 200
const BUTTON_H    := 34
const ANIM_STEP   := 0.06   # s between each button fading in
# Vertical positions are computed dynamically in _build_ui() so any number
# of levels fits between the separator (y≈130) and the footer (y≈332).

# ── Node refs (built at runtime, no external tscn dependencies needed) ────────
var _buttons : Array[Button] = []
var _selected := 0   # index of the currently highlighted button

# ── Internal ──────────────────────────────────────────────────────────────────
var _cx : float = 0.0   # screen centre x


func _ready() -> void:
	_cx = get_viewport_rect().size.x / 2.0
	_build_ui()
	_stagger_in()


# ══ UI construction ════════════════════════════════════════════════════════════

func _build_ui() -> void:
	var vp := get_viewport_rect().size

	# ── Background ────────────────────────────────────────────────────────────
	var bg := ColorRect.new()
	bg.color            = Color(0.07, 0.07, 0.11, 1.0)
	bg.size             = vp
	add_child(bg)

	# ── Title ─────────────────────────────────────────────────────────────────
	var title := Label.new()
	title.text          = "HOOSHANG"
	title.add_theme_font_size_override("font_size", 28)
	title.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 1.0))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.size          = Vector2(vp.x, 40)
	title.position      = Vector2(0, 56)
	add_child(title)

	# ── Subtitle ──────────────────────────────────────────────────────────────
	var sub := Label.new()
	sub.text            = "SELECT A LEVEL"
	sub.add_theme_font_size_override("font_size", 10)
	sub.add_theme_color_override("font_color", Color(0.60, 0.60, 0.75, 1.0))
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.size            = Vector2(vp.x, 20)
	sub.position        = Vector2(0, 100)
	add_child(sub)

	# ── Separator line ────────────────────────────────────────────────────────
	var sep := ColorRect.new()
	sep.color           = Color(0.25, 0.25, 0.40, 1.0)
	sep.size            = Vector2(180, 1)
	sep.position        = Vector2(_cx - 90, 128)
	add_child(sep)

	# ── Level buttons — positions spread evenly between separator and footer ──
	var n        := LEVELS.size()
	var area_top := 136.0          # just below separator at y=128
	var area_bot := vp.y - 36.0   # just above the footer hint
	var step     := (area_bot - area_top) / n
	var first_y  := area_top + (step - BUTTON_H) * 0.5

	for i in range(n):
		var entry  := LEVELS[i]
		var btn    := Button.new()
		btn.text   = entry["label"]
		btn.size   = Vector2(BUTTON_W, BUTTON_H)
		btn.position = Vector2(_cx - BUTTON_W / 2.0, first_y + i * step)
		btn.modulate.a = 0.0   # start invisible (stagger-in animates to 1)
		_style_button(btn, i == 0)
		btn.pressed.connect(_on_level_pressed.bind(i))
		btn.mouse_entered.connect(_on_hover.bind(i))
		add_child(btn)
		_buttons.append(btn)

	# ── Footer hint ───────────────────────────────────────────────────────────
	var hint := Label.new()
	hint.text           = "ARROW KEYS / WASD  ·  SPACE / Z  ·  SHIFT / X to dash"
	hint.add_theme_font_size_override("font_size", 8)
	hint.add_theme_color_override("font_color", Color(0.40, 0.40, 0.55, 1.0))
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.size           = Vector2(vp.x, 20)
	hint.position       = Vector2(0, vp.y - 28)
	add_child(hint)


func _style_button(btn: Button, selected: bool) -> void:
	var normal := StyleBoxFlat.new()
	normal.bg_color        = Color(0.15, 0.15, 0.28, 1.0) if not selected \
							 else Color(0.30, 0.20, 0.55, 1.0)
	normal.border_width_left   = 2
	normal.border_width_right  = 2
	normal.border_width_top    = 2
	normal.border_width_bottom = 2
	normal.border_color    = Color(0.50, 0.35, 0.90, 1.0) if selected \
							 else Color(0.25, 0.25, 0.40, 1.0)
	normal.corner_radius_top_left     = 4
	normal.corner_radius_top_right    = 4
	normal.corner_radius_bottom_left  = 4
	normal.corner_radius_bottom_right = 4
	btn.add_theme_stylebox_override("normal",   normal)
	btn.add_theme_stylebox_override("hover",    normal)
	btn.add_theme_stylebox_override("pressed",  normal)
	btn.add_theme_stylebox_override("focus",    normal)
	btn.add_theme_color_override("font_color",         Color(1.0, 1.0, 1.0, 1.0))
	btn.add_theme_color_override("font_hover_color",   Color(1.0, 1.0, 1.0, 1.0))
	btn.add_theme_color_override("font_pressed_color", Color(1.0, 1.0, 1.0, 1.0))
	btn.add_theme_font_size_override("font_size", 12)


# ── Stagger-in: each button fades in with a small delay ──────────────────────

func _stagger_in() -> void:
	for i in range(_buttons.size()):
		var btn := _buttons[i]
		var t   := get_tree().create_timer(i * ANIM_STEP)
		t.timeout.connect(func() -> void:
			var tw := create_tween()
			tw.tween_property(btn, "modulate:a", 1.0, 0.18)
		)


# ── Input ─────────────────────────────────────────────────────────────────────

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("move_up"):
		_move_selection(-1)
	elif event.is_action_pressed("move_down"):
		_move_selection(1)
	elif event.is_action_pressed("jump") or event.is_action_pressed("dash"):
		_launch(_selected)


func _move_selection(dir: int) -> void:
	_style_button(_buttons[_selected], false)
	_selected = wrapi(_selected + dir, 0, _buttons.size())
	_style_button(_buttons[_selected], true)


func _on_hover(index: int) -> void:
	_style_button(_buttons[_selected], false)
	_selected = index
	_style_button(_buttons[_selected], true)


func _on_level_pressed(index: int) -> void:
	_launch(index)


func _launch(index: int) -> void:
	var scene : String = LEVELS[index]["scene"]
	# Flash the selected button white before transitioning.
	var tw := create_tween()
	tw.tween_property(_buttons[index], "modulate",
					   Color(1.5, 1.5, 1.5, 1.0), 0.06)
	tw.tween_callback(func() -> void:
		get_tree().change_scene_to_file(scene)
	)
