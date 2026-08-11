class_name PauseMenu
extends CanvasLayer
## The pause screen (autoload "Pause"): Escape on a keyboard, Start on a pad.
##
## WHERE THIS DRAWS. On the window's own surface, in front of everything —
## never inside Screen's 320x180 game viewport. A menu rasterised down there
## would come back as a 4x-magnified pixel grid, which is precisely the fight
## systems/screen.gd exists to settle. So this is a CanvasLayer authored at
## 1280x720 and scaled by 0.25, the same arrangement DialogueBox and the two
## HUD counters use, and it sits at layer 100: over the counters (92) and the
## dialogue box (95), under Game's fade (128), which owns the screen during a
## level load and should not have a menu painted on top of it.
##
## WHAT KEEPS RUNNING. `get_tree().paused = true` stops every node whose
## process_mode is inherited, which is all of them — the world in the
## sub-viewport, Screen's input forwarding, the HUD counters' tweens, a
## pomegranate still in flight. That is the whole point: they all freeze mid-air
## and carry on from the same place. This node is the one exception
## (PROCESS_MODE_ALWAYS, set in _ready), because a pause menu that pauses itself
## can never be dismissed.
##
## WHEN PAUSE IS REFUSED — see can_pause(). Short version: only while Hooshang
## has his controls. `input_locked` is the project's cutscene flag, so a
## dialogue beat, a story door, a room slide and Game's level fade all say no on
## their own without this file knowing any of them exist. The title screen is
## covered by the same gate from the other end: leaving a run clears the world
## (Screen.clear), and no world is nothing to pause — so a player sitting in the
## main menu cannot put a pause menu over the top of it.
##
## TIME SCALE. Juice's hitstop drops Engine.time_scale to 0.05 for a few real
## milliseconds on a dash and on a death. Pausing inside that window and
## resuming out of it would hand the player back a world running at a twentieth
## speed — the bug Juice._exit_tree already exists to prevent from the other
## direction. Opening the menu therefore puts the clock back to 1.0 and leaves
## it there; a 40ms cosmetic freeze is not worth preserving across a pause, and
## Juice's own restore timer setting it to 1.0 again later costs nothing.

signal opened
signal closed

## The rows, top to bottom. Must match the order of Rows' children in
## PauseMenu.tscn — the enum names them, the scene draws them.
enum Item { RESUME, RETRY, QUIT }

## How much of the room still shows through behind the menu. Darker reads as a
## harder stop; lighter keeps the level present behind the words.
@export var scrim_color := Color(0.04, 0.035, 0.06, 0.88)
## How long the screen takes to fade in and back out, seconds. Short, so pausing
## feels like a switch rather than a transition.
@export var fade_time := 0.1
## The row the cursor is on.
@export var selected_color := Color(1.0, 0.82, 0.42, 1.0)
## Every other row. Dim enough to read as "not this one" at a glance.
@export var dimmed_color := Color(0.74, 0.75, 0.82, 0.5)
## Gap between the caret and the word it points at, in the box's 1280x720 space.
@export var caret_gap := 26.0
## Weight added to the UI font, matching DialogueBox — Godot's default font
## ships in one weight and a little synthetic emboldening is what gives this
## project's type its solid look.
@export_range(0.0, 1.0) var font_weight := 0.28
## Extra pixels between glyphs, same reason: this type reads cramped without it.
@export var letter_spacing := 2

@export_group("Controller")
## How far a stick must be pushed before the cursor moves — well above the 0.25
## walking deadzone, so a pad resting on a table cannot scroll the menu.
@export var stick_press := 0.55
## How far it must fall back before another move is allowed (hysteresis).
@export var stick_release := 0.35
## Beat before a held direction repeats, and the gap between repeats after that.
@export var repeat_delay := 0.42
@export var repeat_rate := 0.12

## True while the menu is up. Public so anything that needs to know the game is
## held (a test, a future autosave) can ask rather than watch the tree.
var open := false

## Which row the cursor is on, as a plain int rather than as `Item`. GDScript's
## analyser treats the enum named from inside this class and the same enum named
## as `PauseMenu.Item` from outside it as different types and rejects the
## comparison — the trap dialogue_box.gd's Side enum documents.
var selected := 0

var _fade: Tween
## Which way the cursor is held (-1 up, 0 neutral, 1 down) and its repeat clock.
var _nav_held := 0
var _repeat_in := 0.0

@onready var scrim: ColorRect = $Root/Scrim
@onready var caret: Label = $Root/Caret
@onready var rows: Control = $Root/Rows
@onready var root: Control = $Root


func _ready() -> void:
	# The one node that outlives the pause it creates.
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	root.modulate.a = 0.0
	scrim.color = scrim_color
	_apply_font()
	_refresh()


## Emboldened, tracked-out variant of the default font. Built in code rather
## than saved as a .tres because it needs ThemeDB's fallback font as its base,
## which a scene file cannot reference — dialogue_box.gd does the same.
func _apply_font() -> void:
	var fv := FontVariation.new()
	fv.base_font = ThemeDB.fallback_font
	fv.variation_embolden = font_weight
	fv.spacing_glyph = letter_spacing
	for node: Control in [$Root/Title, caret] + _rows():
		node.add_theme_font_override("font", fv)


func _rows() -> Array[Label]:
	var out: Array[Label] = []
	for child in rows.get_children():
		out.append(child as Label)
	return out


## Is there anything to pause?
##
## Only a live world with a player who currently has his controls. That covers
## more than it looks: `input_locked` is set for the length of every dialogue
## beat (scripts/act1_beats.gd), every story-door walkthrough, every room slide
## (ldtk_world.gd's `_transitioning` sets it), and Game's fade out of a finished
## level — so a pause opened in the middle of any of those, and worse a resume
## out of one, is refused without this file naming a single one of them.
##
## The two "no world" cases are real and both reachable: the debug level picker
## is the main scene and is not loaded through Screen at all, and the token
## density prototype IS a Screen scene but has no player. Escape belongs to each
## of them, and this must not steal it — which is also why the key is only
## consumed when the menu actually opens.
func can_pause() -> bool:
	if Screen.current == null:
		return false
	var p := player()
	if p == null:
		return false
	return not p.input_locked


## The one player, found by group rather than by path (STYLE_GUIDE §4): levels
## build theirs at different times and in different places — LdtkWorld makes its
## own in _ready, LevelBase has one as a scene child.
func player() -> Player:
	for n in get_tree().get_nodes_in_group("player"):
		if n is Player:
			return n
	return null


## Open, if the game is in a state that can be paused. Returns whether it did.
func pause_game() -> bool:
	if open or not can_pause():
		return false
	open = true
	selected = Item.RESUME
	# Before the tree stops, not after: a paused tree still runs Juice's restore
	# timer (it was created process_always), but nothing may depend on that — see
	# the TIME SCALE note at the top.
	Engine.time_scale = 1.0
	get_tree().paused = true
	visible = true
	_refresh()
	_fade_to(1.0)
	opened.emit()
	return true


## Let go. The tree resumes on the same frame the choice was made; the menu
## fades out over the top of a world that is already moving again, which reads
## as the game coming back rather than as a screen being cleared away first.
func resume_game() -> void:
	if not open:
		return
	open = false
	get_tree().paused = false
	closed.emit()
	await _fade_to(0.0)
	if not open:  # re-opened during the fade — leave it up
		visible = false


## Escape/Start toggles; while the menu is up it owns the keyboard.
##
## _input rather than _unhandled_input, and set_input_as_handled() on everything
## consumed here, so a press can never also reach the world: Screen forwards
## unhandled events into the game sub-viewport by hand, and R-to-retry lives on
## the other side of that forwarding.
func _input(event: InputEvent) -> void:
	if not open:
		if event.is_action_pressed("pause") and pause_game():
			get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("pause") or event.is_action_pressed("ui_cancel"):
		resume_game()
	elif event.is_action_pressed("jump") or event.is_action_pressed("ui_accept"):
		_choose()
	elif _is_nav(event):
		# Consumed, but the move itself is _process's job — see _process below.
		get_viewport().set_input_as_handled()
		return
	else:
		return
	get_viewport().set_input_as_handled()


## Whether this event is one of the navigation actions, in any binding.
func _is_nav(event: InputEvent) -> bool:
	for action in ["move_up", "move_down", "ui_up", "ui_down"]:
		if event.is_action(action):
			return true
	return false


## Cursor movement, POLLED rather than event-driven — the same fix, and the same
## reason, as MainMenu._process: `move_up`/`move_down` are bound to the left
## stick as well as the d-pad, an off-centre stick emits a continuous stream of
## motion events, and each one moved the cursor. Three rows scrolled past faster
## than anyone could read them. Polling gives one move per push plus a proper
## held repeat, identically for keyboard, d-pad and stick.
func _process(delta: float) -> void:
	if not open:
		return
	var axis := Input.get_action_strength("move_down") - Input.get_action_strength("move_up")
	var dir := 0
	if absf(axis) >= stick_press:
		# signf, NOT signi: signi() takes an INT, so signi(0.95) truncates its
		# argument to 0 and returns 0 — the direction came out neutral on every
		# frame and the cursor never moved at all. Silent, and it type-checks.
		dir = int(signf(axis))
	elif absf(axis) > stick_release:
		dir = _nav_held       # hysteresis band: hold what we had
	if dir == 0:
		_nav_held = 0
		return
	if dir != _nav_held:
		_nav_held = dir
		_repeat_in = repeat_delay
		_move(dir)
		return
	_repeat_in -= delta
	if _repeat_in <= 0.0:
		_repeat_in = repeat_rate
		_move(dir)


## Move the cursor, wrapping. A three-item list is short enough that running off
## the end and stopping feels broken rather than safe.
func _move(step: int) -> void:
	var count := rows.get_child_count()
	selected = (selected + step + count) % count
	_refresh()


func _choose() -> void:
	match selected:
		Item.RESUME:
			resume_game()
		Item.RETRY:
			_retry()
		Item.QUIT:
			_quit_to_title()


## Leave the run for the title screen.
##
## This used to be get_tree().quit(), and had to be: there was no title screen to
## go back TO, so the only thing "quit" could mean was the process. Now there is
## one, and a pause menu that closes the whole game is a mistake a player makes
## once and does not forgive. Leaving the program is the title screen's own QUIT,
## one screen further out, where it is the only thing that row can mean.
##
## Order matters, twice. The pause is let go FIRST — this node is the only one
## that runs under it, so anything reached after would be frozen. Then the run is
## written down, while there is still a world to ask; SaveGame no-ops without a
## bound slot, so a debug launch or a level-select run passes straight through
## and MainMenu.open() drops the world and unbinds on the way in.
func _quit_to_title() -> void:
	resume_game()
	SaveGame.save_now()
	MainMenu.open(get_tree())


## Same thing R does mid-play, reached from the menu instead: hand the game back
## first, then kill him, because the respawn hold is a timer on the level and a
## paused level never finishes counting it.
func _retry() -> void:
	var p := player()
	resume_game()
	if p != null and p.state != Player.State.DEAD:
		p.die()


func _refresh() -> void:
	var list := _rows()
	for i in list.size():
		list[i].add_theme_color_override("font_color",
			selected_color if i == selected else dimmed_color)
	_place_caret()


## Park the caret just left of the selected word.
##
## Measured from the TEXT, not from the label: every row is a full-width centred
## label, so using the label's own rect would leave the caret pinned to the
## screen edge. Measuring means the caret sits the same distance from "RESUME"
## as it does from "QUIT" rather than drifting with the word length.
func _place_caret() -> void:
	var list := _rows()
	if selected < 0 or selected >= list.size():
		return
	var row := list[selected]
	var font := row.get_theme_font("font")
	if font == null:
		return
	var width := font.get_string_size(row.text, HORIZONTAL_ALIGNMENT_LEFT, -1.0,
		row.get_theme_font_size("font_size")).x
	caret.position = Vector2(
		rows.position.x + rows.size.x * 0.5 - width * 0.5 - caret_gap - caret.size.x,
		rows.position.y + row.position.y + (row.size.y - caret.size.y) * 0.5)


## Fade the whole screen as one. Bound to this node, which is PROCESS_MODE_ALWAYS,
## so the tween keeps ticking through the pause it is announcing.
func _fade_to(a: float) -> void:
	if _fade and _fade.is_valid():
		_fade.kill()
	_fade = create_tween()
	_fade.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_fade.tween_property(root, "modulate:a", a, fade_time)
	await _fade.finished
