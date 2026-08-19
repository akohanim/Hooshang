class_name MainMenu
extends CanvasLayer
## The title screen, and the game's front door (`run/main_scene`).
##
## WHERE THIS DRAWS. Same arrangement as the pause menu, for the same reason:
## a CanvasLayer authored at 1280x720 and scaled by 0.25, on the WINDOW's own
## surface rather than inside Screen's 320x180 game viewport, where it would come
## back as a 4x-magnified pixel grid. Layer 110 puts it over the pause menu (100)
## and under Game's fade (128) — the fade owns the screen during a level load and
## nothing should be painted on top of it.
##
## WHY IT HIDES INSTEAD OF FREEING ITSELF. The debug picker, which this replaces
## as the main scene, frees itself when it hands over to a level — fine for a
## one-way door. This one is walked back through: the pause menu's QUIT now
## returns here rather than killing the process. Staying in the tree (hidden and
## PROCESS_MODE_DISABLED, so it cannot eat a key meant for the world) means
## coming back is a boolean rather than a scene load, and `current_scene` stays
## pointing at something real the whole time.
##
## NAVIGATION. Deliberately the pause menu's, key for key: confirm on `jump` or
## `ui_accept`, move on `move_up`/`move_down` as well as the arrows, back out on
## `ui_cancel` or `pause`. No mouse anywhere — this is a pad-and-keyboard game
## and a menu you can only leave with a cursor is one a controller cannot leave.
##
## SCREENS. One scene, four screens, because they are the same list of words with
## different rows in it (ROOT, SLOTS, LEVELS, CONFIRM). Rows are built in code
## rather than authored per screen, so a slot card that gains a field, or an Act
## that gains rooms, changes one function and no layout.

## The pages this menu moves between. SLOTS serves all three things you can do
## to a slot; `_slot_mode` says which.
enum Page { ROOT, SLOTS, LEVELS, CONFIRM }
## What choosing a slot on the SLOTS screen means.
enum SlotMode { NEW, LOAD, PRACTICE }

const SCENE := "res://scenes/ui/MainMenu.tscn"
## The dev launcher. Kept reachable — the tests and the token-density prototype
## both go through it — but off the menu in a release build, where a player has
## no business dropping into room 14 of a run they never played.
@export_group("Controller")
## How far a stick must be pushed before the cursor moves. Well above the 0.25
## deadzone the movement actions use in project.godot: that number is tuned for
## walking, where a light touch should register, and a menu wants the opposite —
## a pad resting on a table must never scroll the list on its own.
@export var stick_press := 0.55
## How far it must fall back before another move is allowed. The gap between
## this and stick_press is hysteresis; equal values stutter.
@export var stick_release := 0.35
## Beat before a held direction starts repeating.
@export var repeat_delay := 0.42
## Gap between repeats once it has. Roughly eight rows a second.
@export var repeat_rate := 0.12

const PICKER := "res://scenes/debug_level_picker.tscn"

## How long the screen takes to fade in, seconds. Short: a title screen that
## makes you wait for it is one you resent by the fifth launch.
@export var fade_time := 0.25
## The row the cursor is on.
@export var selected_color := Color(1.0, 0.82, 0.42, 1.0)
## Every other row. Dim enough to read as "not this one" at a glance.
@export var dimmed_color := Color(0.74, 0.75, 0.82, 0.5)
## Gap between the caret and the word it points at, in the menu's 1280x720 space.
@export var caret_gap := 26.0
## Height of one row, and the pitch between them, in that same space.
@export var row_height := 52.0
@export var row_step := 62.0
## How many rows are on screen at once. The level select is the only list that
## can outgrow it — Act I is 22 rooms — and it scrolls rather than shrinking the
## type, which is what makes this read like the rest of the game's UI.
@export var visible_rows := 6
## Weight added to the UI font, matching DialogueBox and the pause menu — Godot's
## default font ships in one weight and a little synthetic emboldening is what
## gives this project's type its solid look.
@export_range(0.0, 1.0) var font_weight := 0.28
## Extra pixels between glyphs, same reason: this type reads cramped without it.
@export var letter_spacing := 2

## Which row the cursor is on. Public so a test can drive the menu the way a
## player does rather than calling the actions directly.
var selected := 0
## Which page is up, as a plain int — the trap dialogue_box.gd's Side enum
## documents: the analyser treats `Page` named from inside this class and from
## outside it as different types and rejects the comparison.
var page := 0

var _rows: Array[Dictionary] = []
var _top := 0
var _slot_mode := 0
var _fade: Tween
var _font: FontVariation
## Which way the cursor is being held right now (-1 up, 0 neutral, 1 down), and
## how long until it repeats. See _process.
var _nav_held := 0
var _repeat_in := 0.0

@onready var root: Control = $Root
@onready var title: Label = $Root/Title
@onready var subtitle: Label = $Root/Subtitle
@onready var caret: Label = $Root/Caret
@onready var rows: Control = $Root/Rows
@onready var detail: Label = $Root/Detail
@onready var hint: Label = $Root/Hint
@onready var more_above: Label = $Root/MoreAbove
@onready var more_below: Label = $Root/MoreBelow


func _ready() -> void:
	# Found by group, so the pause menu can hand the game back to whichever title
	# screen exists without knowing where in the tree it sits (STYLE_GUIDE §4).
	add_to_group("main_menu")
	# ALWAYS, not inherited: if anything ever leaves the tree paused on its way
	# out of a level, a title screen that cannot be navigated is a dead game.
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_font()
	show_root()
	root.modulate.a = 0.0
	_fade_to(1.0)


## Bring the title screen back — the pause menu's QUIT, and anything else that
## ends a run. Static because the caller has a tree and no reference: the menu
## may be hidden in it (the ordinary case) or absent entirely, which is what
## launching from the debug picker leaves behind.
static func open(tree: SceneTree) -> void:
	# The world goes first. `Screen.current` being null is what tells the pause
	# menu there is nothing to pause and the HUD counters there is nothing to
	# count, so it is the same switch that keeps the menu from being pausable.
	Screen.clear()
	SaveGame.unbind()
	for node in tree.get_nodes_in_group("main_menu"):
		(node as MainMenu).reopen()
		return
	# No title screen in the tree: the run was launched from the debug picker,
	# which frees itself on the way out. This is the ONE change_scene_to_file in
	# the project that is correct — the rule it breaks (CLAUDE.md) is about the
	# WORLD, which has to land inside Screen's viewport, and this is the one
	# scene that must not.
	tree.change_scene_to_file(SCENE)


func reopen() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = true
	show_root()
	root.modulate.a = 0.0
	_fade_to(1.0)


# --------------------------------------------------------------- screens ----

func show_root() -> void:
	page = Page.ROOT
	title.text = "HOOSHANG"
	subtitle.text = "ACT I  —  THE OFFICE"
	var built: Array[Dictionary] = []
	# CONTINUE is offered only when there is something to continue, and it takes
	# the most recent slot without asking. A player who wants a different one has
	# LOAD GAME directly below; a player with one run should not have to choose.
	var latest := SaveGame.latest_slot()
	if latest >= 0:
		built.append(_row("CONTINUE", _describe(latest, "SLOT %d" % (latest + 1)),
			func() -> void: _start(func() -> void: SaveGame.resume(latest))))
	built.append(_row("NEW GAME", "a fresh run, in a slot you pick",
		func() -> void: _show_slots(SlotMode.NEW)))
	if SaveGame.has_any():
		built.append(_row("LOAD GAME", "pick up any of the three runs",
			func() -> void: _show_slots(SlotMode.LOAD)))
		built.append(_row("LEVEL SELECT", "replay a room you have reached — nothing is saved",
			func() -> void: _show_slots(SlotMode.PRACTICE)))
	# Shown in EXPORTED builds too, not just debug ones. It used to be gated on
	# OS.is_debug_build(), which is false in a release export — so the row was
	# missing from the itch.io build, which is the one build anybody other than
	# the developer ever sees. That is now deliberate: this game ships with its
	# room list open, so a player can jump straight to anything.
	#
	# It still writes to no save slot (see scenes/debug_level_picker.gd), so an
	# afternoon spent in here cannot touch a real run.
	built.append(_row("DEBUG PICKER", "jump straight to any room or scene",
		func() -> void: _start(func() -> void:
			LdtkWorld.debug_start_room = ""
			get_tree().change_scene_to_file(PICKER))))
	built.append(_row("QUIT", "leave the office the other way",
		func() -> void: get_tree().quit()))
	_populate(built)


func _show_slots(mode: int) -> void:
	page = Page.SLOTS
	_slot_mode = mode
	match mode:
		SlotMode.NEW:
			title.text = "NEW GAME"
			subtitle.text = "choose a slot"
		SlotMode.LOAD:
			title.text = "LOAD GAME"
			subtitle.text = "choose a run"
		_:
			title.text = "LEVEL SELECT"
			subtitle.text = "choose a run to replay from"
	var built: Array[Dictionary] = []
	for i in SaveGame.SLOTS:
		var used := SaveGame.has_save(i)
		# An empty slot is somewhere to START a game and nothing else — offering
		# it under LOAD or LEVEL SELECT would be a row that can only say no.
		if not used and mode != SlotMode.NEW:
			continue
		var label := "SLOT %d" % (i + 1)
		built.append(_row(label, _describe(i, label), _slot_action(mode, i, used)))
	if built.is_empty():
		built.append(_row("— NO RUNS YET —", "start a new game first", Callable()))
	_populate(built)


func _slot_action(mode: int, i: int, used: bool) -> Callable:
	match mode:
		SlotMode.NEW:
			# Occupied slots go through a confirmation. This is the only
			# destructive thing the menu can do, and it is one button press away
			# from the row a returning player lands on.
			if used:
				return func() -> void: _show_confirm(i)
			return func() -> void: _begin_new_run(i, false)
		SlotMode.LOAD:
			return func() -> void: _start(func() -> void: SaveGame.resume(i))
		_:
			return func() -> void: _show_levels(i)


func _show_confirm(i: int) -> void:
	page = Page.CONFIRM
	title.text = "OVERWRITE?"
	subtitle.text = "slot %d already holds a run" % (i + 1)
	_populate([
		# KEEP IT is first, so the cursor lands on it: a confirmation whose
		# default answer is "yes, destroy it" is not a confirmation.
		_row("KEEP IT", "go back without changing anything",
			func() -> void: _show_slots(SlotMode.NEW)),
		_row("ERASE AND START", _describe(i, "this is what goes"),
			func() -> void: _begin_new_run(i, true)),
	])


## Begin a run in slot `i`: the opening film, then the world.
##
## The ONLY two callers are the two NEW GAME rows — an empty slot, and an
## occupied one past its overwrite guard. CONTINUE, LOAD GAME, level select and
## both debug pickers all reach SaveGame directly and therefore skip the film,
## which is the whole rule: story setup belongs to starting a story, and a
## returning player has already had it.
##
## The film plays BEFORE the world is built rather than over it. Nothing is
## loaded behind it and nothing is ticking, so skipping lands on a game that has
## not started yet instead of one already several seconds in — and a 47-second
## world load cannot stutter the playback.
func _begin_new_run(i: int, erase_first: bool) -> void:
	_start(func() -> void:
		if erase_first:
			SaveGame.erase(i)
		await IntroVideo.play_for(get_tree())
		SaveGame.start_new(i))


func _show_levels(i: int) -> void:
	page = Page.LEVELS
	title.text = "LEVEL SELECT"
	subtitle.text = "slot %d  —  rooms you have reached" % (i + 1)
	var built: Array[Dictionary] = []
	for room_name in SaveGame.unlocked_rooms(i):
		var number := LdtkWorld.index_in_name(room_name) + 1
		# The detail says what a level-select run IS rather than naming the LDtk
		# level: "ROOM 5 / Level_5" reads as an off-by-one bug report, and the
		# thing a player needs told here is that this trip does not count.
		built.append(_row("ROOM %d" % number, "practice run  —  nothing is saved",
			func() -> void: _start(func() -> void: SaveGame.practice(i, room_name))))
	if built.is_empty():
		built.append(_row("— NOTHING REACHED YET —", "", Callable()))
	_populate(built)


## Everything a slot card says, on one line. Also the CONTINUE row's detail, so
## the player can see which run that button means without opening LOAD GAME.
func _describe(i: int, when_empty: String) -> String:
	var card := SaveGame.summary(i)
	if card.get("empty", true):
		return "%s  —  empty" % when_empty
	return "ROOM %d   %d LEMONS   %d DEATHS   %s" % [
		card["room_number"], card["lemons"], card["deaths"],
		_clock(card["play_seconds"])]


## Seconds as h:mm:ss, or m:ss under an hour — the shape a player reads as "time
## played" rather than as a number.
func _clock(seconds: float) -> String:
	var total := int(maxf(seconds, 0.0))
	var hours := total / 3600
	var minutes := (total / 60) % 60
	if hours > 0:
		return "%d:%02d:%02d" % [hours, minutes, total % 60]
	return "%d:%02d" % [minutes, total % 60]


# ------------------------------------------------------------------ rows ----

func _row(text: String, note: String, action: Callable) -> Dictionary:
	return {"text": text, "detail": note, "action": action}


func _populate(built: Array[Dictionary]) -> void:
	_rows = built
	# Every page opens on its first row. Carrying a cursor across pages that
	# hold different things means landing on whatever happens to sit at that
	# index, which on the overwrite page would be the destructive one.
	selected = 0
	_top = 0
	_rebuild()


## Draw the window of rows the cursor is currently inside.
##
## The labels are rebuilt rather than reused because the window SLIDES: row 0 on
## screen is a different entry before and after a scroll, and keeping a pool of
## labels in step with that is more code than making six of them.
func _rebuild() -> void:
	for child in rows.get_children():
		# Removed as well as freed. queue_free() alone leaves the old labels in
		# the tree until the end of the frame, so the new ones land BEHIND them
		# in the child list — and every index below (which row is gold, which one
		# the caret measures) then addresses the previous page. It renders as a
		# menu whose highlight and caret sit on rows nobody chose.
		rows.remove_child(child)
		child.queue_free()
	var shown := mini(visible_rows, _rows.size())
	for i in shown:
		var entry := _rows[_top + i]
		var label := Label.new()
		label.text = str(entry["text"])
		label.position = Vector2(0.0, i * row_step)
		label.size = Vector2(rows.size.x, row_height)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.add_theme_font_size_override("font_size", 34)
		label.add_theme_font_override("font", _font)
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		rows.add_child(label)
	more_above.visible = _top > 0
	more_below.visible = _top + shown < _rows.size()
	_refresh()


func _refresh() -> void:
	var shown := rows.get_child_count()
	for i in shown:
		var label := rows.get_child(i) as Label
		label.add_theme_color_override("font_color",
			selected_color if _top + i == selected else dimmed_color)
	detail.text = str(_rows[selected]["detail"]) if selected < _rows.size() else ""
	_place_caret()


## Park the caret just left of the selected word.
##
## Measured from the TEXT, not from the label: every row is a full-width centred
## label, so using the label's own rect would pin the caret to the screen edge.
## Straight out of pause_menu.gd, which had the same problem first.
func _place_caret() -> void:
	var index := selected - _top
	if index < 0 or index >= rows.get_child_count():
		caret.visible = false
		return
	caret.visible = true
	var row := rows.get_child(index) as Label
	var font := row.get_theme_font("font")
	if font == null:
		return
	var width := font.get_string_size(row.text, HORIZONTAL_ALIGNMENT_LEFT, -1.0,
		row.get_theme_font_size("font_size")).x
	caret.position = Vector2(
		rows.position.x + rows.size.x * 0.5 - width * 0.5 - caret_gap - caret.size.x,
		rows.position.y + row.position.y + (row.size.y - caret.size.y) * 0.5)


# ----------------------------------------------------------------- input ----

## The pause menu's keys exactly. `_input` rather than `_unhandled_input`, and
## every consumed press marked handled, so nothing reaches the world Screen
## forwards events into — which matters the moment a level is loading behind a
## menu that has not finished fading out.
func _input(event: InputEvent) -> void:
	var taken := Callable()
	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("pause"):
		taken = back
	elif _rows.is_empty():
		return
	elif event.is_action_pressed("jump") or event.is_action_pressed("ui_accept"):
		taken = choose
	elif _is_nav(event):
		# Swallowed but NOT acted on — moving is _process's job now (see there).
		# Consumed anyway so a stick pushed at a menu cannot also reach the world
		# behind it, which is the same reason every other press here is consumed.
		get_viewport().set_input_as_handled()
		return
	else:
		return
	# Marked handled BEFORE the row is run, not after. A row is allowed to take
	# this node down with it — the DEBUG PICKER one hands over with
	# change_scene_to_file, which frees the current scene, and the current scene
	# is this menu. Calling get_viewport() afterwards then dereferences null, and
	# in an editor run that breaks into the debugger and stops the game dead:
	# "the picker doesn't work". Exported and headless builds only print it,
	# which is why it survived every test.
	get_viewport().set_input_as_handled()
	taken.call()


## Whether this event is one of the navigation actions, in any of their bindings.
func _is_nav(event: InputEvent) -> bool:
	for action in ["move_up", "move_down", "ui_up", "ui_down"]:
		if event.is_action(action):
			return true
	return false


## Cursor movement, POLLED rather than driven by input events.
##
## An analog stick is why. `move_up`/`move_down` are bound to the left stick as
## well as the d-pad and the arrows, and a stick that is off centre emits a
## continuous stream of InputEventJoypadMotion — so a single nudge fired _move()
## over and over and the cursor bolted down the list. Worse on a pad whose stick
## rests a little off centre, where the 0.25 deadzone in project.godot is enough
## to hold the action "pressed" forever and the menu simply scrolls on its own.
##
## Polling collapses every binding into one number, so keyboard, d-pad and stick
## all get the same behaviour: one move on the way past the threshold, then a
## held direction repeats. Holding an arrow key now repeats too, which it did not
## before — a menu that ignores a held key feels broken in the other direction.
func _process(delta: float) -> void:
	if _rows.is_empty():
		return
	var axis := Input.get_action_strength("move_down") - Input.get_action_strength("move_up")
	var dir := 0
	if absf(axis) >= stick_press:
		# signf, NOT signi: signi() takes an INT, so signi(0.95) truncates its
		# argument to 0 and returns 0 — the direction came out neutral on every
		# frame and the cursor never moved at all. Silent, and it type-checks.
		dir = int(signf(axis))
	elif absf(axis) > stick_release:
		# Between the two thresholds: keep whatever we already had. That gap is
		# hysteresis — without it a stick wavering across a single threshold
		# stutters between moving and not.
		dir = _nav_held

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


## Move the cursor, wrapping, and scroll the window to keep it visible. Wrapping
## because these lists are short enough that stopping at the end reads as broken
## rather than as safe — the same call the pause menu makes.
func _move(step: int) -> void:
	selected = (selected + step + _rows.size()) % _rows.size()
	var shown := mini(visible_rows, _rows.size())
	_top = clampi(_top, maxi(selected - shown + 1, 0), selected)
	_top = clampi(_top, 0, maxi(_rows.size() - shown, 0))
	_rebuild()


## Take the highlighted row. Public so a test can drive the menu without
## synthesising a key press for every step of a five-screen walk.
func choose() -> void:
	if selected >= _rows.size():
		return
	var action: Callable = _rows[selected]["action"]
	if action.is_valid():
		action.call()


## Back out one screen. ROOT has nowhere to go, and deliberately does NOT quit
## the game on Escape — a title screen that closes itself when you press the key
## you use to leave every other screen is a bad afternoon.
func back() -> void:
	match page:
		Page.SLOTS, Page.LEVELS:
			show_root()
		Page.CONFIRM:
			_show_slots(SlotMode.NEW)


# -------------------------------------------------------------- plumbing ----

## Hand over to the game. The menu goes dark and deaf FIRST: `action` loads a
## world into Screen's viewport, and a menu still taking input over the top of it
## would swallow the first jump.
func _start(action: Callable) -> void:
	visible = false
	# DISABLED, not merely hidden: a hidden node still receives _input, and this
	# one binds `jump`.
	process_mode = Node.PROCESS_MODE_DISABLED
	action.call()


## Emboldened, tracked-out variant of the default font. Built in code rather than
## saved as a .tres because it needs ThemeDB's fallback font as its base, which a
## scene file cannot reference — dialogue_box.gd and pause_menu.gd do the same.
func _build_font() -> void:
	_font = FontVariation.new()
	_font.base_font = ThemeDB.fallback_font
	_font.variation_embolden = font_weight
	_font.spacing_glyph = letter_spacing
	for node: Control in [title, subtitle, caret, detail, hint, more_above, more_below]:
		node.add_theme_font_override("font", _font)


func _fade_to(a: float) -> void:
	if _fade and _fade.is_valid():
		_fade.kill()
	_fade = create_tween()
	_fade.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_fade.tween_property(root, "modulate:a", a, fade_time)
