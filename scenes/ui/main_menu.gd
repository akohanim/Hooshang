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
## `ui_cancel` or `pause`. Mouse and touch use the same selection model.
##
## SCREENS. The chapter browser adds CHAPTERS and EXPLORE to the save pages.
## Every room is available, independently of save progress. Rows are built in code
## rather than authored per screen, so a slot card that gains a field, or an Act
## that gains rooms, changes one function and no layout. EXPLORE pairs the room
## list with that Act's WORLD MAP (world_map.gd): the two share one selection,
## and either one can pick the room to play.

## The pages this menu moves between. SLOTS serves all three things you can do
## to a slot; `_slot_mode` says which.
enum Page { ROOT, SLOTS, LEVELS, CONFIRM, CHAPTERS, EXPLORE }
## What choosing a slot on the SLOTS screen means.
enum SlotMode { NEW, LOAD, PRACTICE }

const SCENE := "res://scenes/ui/MainMenu.tscn"
## The chapter browser is the player-facing launcher; developer scenes remain
## available from the editor.
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
@export var dimmed_color := Color(0.74, 0.78, 0.84, 0.85)
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
var _touch_gesture = preload("res://scenes/ui/touch/touch_menu_gesture.gd").new()

var _room_cursors := [0,0,0]
var _chapter := 1
var _selection_tween: Tween
var _catalog: Array = []
const WorldMap := preload("res://scenes/ui/world_map.gd")
var _map: WorldMap
## True while a hover on the map is what moved the selection — the map then lights
## the room where it stands instead of panning to it (see world_map.gd).
var _map_hover := false
var _hero: TextureRect
var _eyebrow: Label
var _caption: Label
var _counter: Label
var _selection: Panel

var _fade: Tween
var _font: FontVariation
## Which way the cursor is being held right now (-1 up, 0 neutral, 1 down), and
## how long until it repeats. See _process.
var _nav_held := 0
var _repeat_in := 0.0
## Smooth scrolling: the window still steps a whole row at a time (`_top`), but
## the labels slide the difference over a few frames instead of jumping, so a
## wheel flick reads as the list moving rather than the text being swapped.
var _slide := 0.0
@export var slide_speed := 18.0
## The scrollbar beside a list that overflows its window: a track you can click
## anywhere on and a thumb you can drag.
var _track: ColorRect
var _thumb: ColorRect
var _dragging_bar := false
## Wheel/trackpad deltas below one row accumulate rather than being dropped.
var _wheel_accum := 0.0

@onready var root: Control = $Root
@onready var title: Label = $Root/Title
@onready var subtitle: Label = $Root/Subtitle
@onready var caret: Label = $Root/Caret
@onready var rows: Control = $Root/Rows
@onready var detail: Label = $Root/Detail
@onready var hint: Label = $Root/Hint
@onready var back_button: Label = $Root/Back
@onready var more_above: Label = $Root/MoreAbove
@onready var more_below: Label = $Root/MoreBelow
@onready var menu_music: AudioStreamPlayer = $MenuMusic


func _ready() -> void:
	# Found by group, so the pause menu can hand the game back to whichever title
	# screen exists without knowing where in the tree it sits (STYLE_GUIDE §4).
	add_to_group("main_menu")
	# ALWAYS, not inherited: if anything ever leaves the tree paused on its way
	# out of a level, a title screen that cannot be navigated is a dead game.
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_font()
	_build_explorer()
	show_root()
	root.modulate.a = 0.0
	_fade_to(1.0)
	menu_music.play()
	if OS.has_feature("web") and bool(JavaScriptBridge.eval("window.HooshangTouchTest != null")):
		_open_touch_test.call_deferred()


func _open_touch_test() -> void:
	menu_music.stop()
	hide()
	process_mode = Node.PROCESS_MODE_DISABLED
	Screen.set_scene(preload("res://scenes/ui/touch/touch_test_room.gd").new())


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
	menu_music.play()
	show_root()
	root.modulate.a = 0.0
	_fade_to(1.0)


# --------------------------------------------------------------- screens ----

func show_root() -> void:
	_chapter = 1
	page = Page.ROOT
	title.text = "HOOSHANG"
	subtitle.text = "A JOURNEY BACK TO YOURSELF"
	var built: Array[Dictionary] = []
	built.append(_row("EXPLORE CHAPTERS", "Every room unlocked. Your next journey is yours to choose.", _show_chapters))
	# CONTINUE is offered only when there is something to continue, and it takes
	# the most recent slot without asking. A player who wants a different one has
	# LOAD GAME directly below; a player with one run should not have to choose.
	var latest := SaveGame.latest_slot()
	if latest >= 0:
		if SaveGame.summary(latest).get("world", "") == "res://ldtk/Act2World.tscn":
			subtitle.text = "ACT II  —  THE POND"
		built.append(_row("CONTINUE", _describe(latest, "SLOT %d" % (latest + 1)),
			func() -> void: _start(func() -> void: SaveGame.resume(latest))))
	built.append(_row("NEW GAME", "a fresh run, in a slot you pick",
		func() -> void: _show_slots(SlotMode.NEW)))
	if SaveGame.has_any():
		built.append(_row("LOAD GAME", "pick up any of the three runs",
			func() -> void: _show_slots(SlotMode.LOAD)))
	if not OS.has_feature("web"):
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
	var world_path: String = SaveGame.summary(i).get("world", SaveGame.FIRST_WORLD)
	for room_name in SaveGame.unlocked_rooms(i):
		var room_label := SaveGame.room_label(world_path, room_name)
		# The detail says what a level-select run IS rather than naming the LDtk
		# level: "ROOM 5 / Level_6" reads as an off-by-one bug report, and the
		# thing a player needs told here is that this trip does not count.
		built.append(_row(room_label, "practice run  —  nothing is saved",
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
	return "%s   %d LEMONS   %d DEATHS   %s" % [
		card["room_label"], card["lemons"], card["deaths"],
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
	back_button.visible = page != Page.ROOT
	# The room lists are long (Act 2 has 39 rooms), so they get compact rows and
	# a taller window; the short title/slot pages keep the big type.
	if page == Page.EXPLORE:
		row_step = 40.0
		row_height = 38.0
		visible_rows = 9
	else:
		row_step = 56.0
		row_height = 48.0
		visible_rows = 6
	rows.size.y = visible_rows * row_step
	_slide = 0.0
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
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.add_theme_font_size_override("font_size", 20 if page == Page.EXPLORE else 24)
		label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		label.add_theme_font_override("font", _font)
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		rows.add_child(label)
	# A list with a scrollbar does not also need the ^/v arrows.
	var overflow := _rows.size() > shown
	more_above.visible = _top > 0 and not (overflow and _track != null)
	more_below.visible = _top + shown < _rows.size() and not (overflow and _track != null)
	_layout_rows()
	_update_scrollbar()
	_refresh()


## Scroll the window so `top` is its first row, sliding rather than jumping.
## The selection stays where it is: scrolling is looking, not choosing.
func _scroll_to(top: int) -> void:
	var shown := mini(visible_rows, _rows.size())
	top = clampi(top, 0, maxi(_rows.size() - shown, 0))
	if top == _top:
		return
	_slide += (top - _top) * row_step
	_slide = clampf(_slide, -row_step * 3.0, row_step * 3.0)
	_top = top
	_rebuild()


func _layout_rows() -> void:
	for i in rows.get_child_count():
		(rows.get_child(i) as Control).position.y = i * row_step + _slide


## Thumb size is the visible share of the list, its position the window's share.
func _update_scrollbar() -> void:
	if _track == null:
		return
	var shown := mini(visible_rows, _rows.size())
	var overflow := _rows.size() > shown
	_track.visible = overflow
	_thumb.visible = overflow
	if not overflow:
		return
	_track.position = rows.position + Vector2(rows.size.x + 22.0, 0.0)
	_track.size = Vector2(6.0, shown * row_step)
	var share := float(shown) / _rows.size()
	var span := _track.size.y
	var thumb_h := maxf(span * share, 24.0)
	var max_top := maxi(_rows.size() - shown, 1)
	var t := (float(_top) - _slide / row_step) / max_top
	_thumb.size = Vector2(10.0, thumb_h)
	_thumb.position = _track.position + Vector2(-2.0, clampf(t, 0.0, 1.0) * (span - thumb_h))
	_thumb.color = selected_color


## A click or drag at `y` (in Root space) on the scrollbar: centre the thumb there.
func _scroll_bar_to(y: float) -> void:
	var shown := mini(visible_rows, _rows.size())
	var span := _track.size.y - _thumb.size.y
	var t := clampf((y - _track.position.y - _thumb.size.y * 0.5) / maxf(span, 1.0), 0.0, 1.0)
	_scroll_to(roundi(t * (_rows.size() - shown)))


func _refresh() -> void:
	_update_explorer()
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
	caret.visible = false
	if _selection != null:
		_selection.visible = index >= 0 and index < rows.get_child_count()
	if index < 0 or index >= rows.get_child_count():
		return
	if _selection_tween and _selection_tween.is_valid(): _selection_tween.kill()
	_selection_tween = create_tween()
	_selection_tween.tween_property(_selection,"position",rows.position + Vector2(-16,index*row_step + _slide),0.10).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_selection.size = Vector2(rows.size.x+32,row_height)


# ----------------------------------------------------------------- input ----

## The pause menu's keys exactly. `_input` rather than `_unhandled_input`, and
## every consumed press marked handled, so nothing reaches the world Screen
## forwards events into — which matters the moment a level is loading behind a
## menu that has not finished fading out.
func _input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventScreenTouch or event is InputEventScreenDrag:
		InputDevice.note_touch()
		get_viewport().set_input_as_handled()
		var gesture: Dictionary = _touch_gesture.read(event, true)
		if gesture.has("scroll"):
			_scroll_to(_top + int(gesture.scroll))
		elif gesture.has("tap"):
			var click := InputEventMouseButton.new()
			click.button_index = MOUSE_BUTTON_LEFT
			click.pressed = true
			click.position = gesture.tap
			_mouse_input(click)
			if visible:
				var lift := click.duplicate() as InputEventMouseButton
				lift.pressed = false
				_mouse_input(lift)
		return
	if event is InputEventMouse and event.device == InputEvent.DEVICE_ID_EMULATION:
		return
	if event is InputEventMouse:
		_mouse_input(event)
		return
	if page == Page.EXPLORE and (event.is_action_pressed("ui_left") or event.is_action_pressed("ui_right")):
		get_viewport().set_input_as_handled()
		_show_explore(posmod(_chapter + (1 if event.is_action_pressed("ui_right") else -1),3))
		return
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


## Convert viewport coordinates through the canvas transform: the menu is
## authored at 1280x720 but its CanvasLayer is scaled down to the game design size.
func _mouse_input(event: InputEventMouse) -> void:
	get_viewport().set_input_as_handled()
	var at := root.get_global_transform_with_canvas().affine_inverse() * event.position
	var click: bool = event is InputEventMouseButton and event.pressed
	var release: bool = event is InputEventMouseButton and not event.pressed and event.button_index == MOUSE_BUTTON_LEFT
	# The world map takes its own clicks, drags and wheel (zoom), and keeps a drag
	# that wanders off it. Ahead of the release check below, which would otherwise
	# swallow the end of a map drag. Right-click still means BACK, there too.
	if page == Page.EXPLORE and _map.visible and not _dragging_bar:
		var right: bool = event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT
		if not right and (_map.is_pressing() or Rect2(_map.position, _map.size).has_point(at)):
			_map.mouse(event, at - _map.position)
			return
		_map.set_hover(-1)
	if release:
		_dragging_bar = false
		return
	if event is InputEventMouseMotion and _dragging_bar:
		_scroll_bar_to(at.y)
		return
	if click and event.button_index == MOUSE_BUTTON_RIGHT:
		back()
		return
	# The wheel SCROLLS the list; it no longer moves the selection a row per
	# notch. Trackpads send fractional `factor`s, so small deltas add up.
	if click and event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
		if not _rows.is_empty():
			var amount: float = event.factor if event.factor > 0.0 else 1.0
			_wheel_accum += amount * (-1.0 if event.button_index == MOUSE_BUTTON_WHEEL_UP else 1.0)
			var whole := int(_wheel_accum)
			if whole != 0:
				_wheel_accum -= whole
				_scroll_to(_top + whole)
		return
	if click and event.button_index == MOUSE_BUTTON_LEFT and back_button.visible:
		var back_point := back_button.get_global_transform_with_canvas().affine_inverse() * event.position
		if Rect2(Vector2.ZERO, back_button.size).has_point(back_point):
			back()
			return
	if click and event.button_index == MOUSE_BUTTON_LEFT:
		# Scrollbar: click anywhere on the track (generously wide) to jump, then drag.
		if _track != null and _track.visible and Rect2(_track.position - Vector2(14, 0), _track.size + Vector2(28, 0)).has_point(at):
			_dragging_bar = true
			_scroll_bar_to(at.y)
			return
		var shown := mini(visible_rows, _rows.size())
		for arrow: Label in [more_above, more_below]:
			if arrow.visible and Rect2(arrow.position, arrow.size).has_point(at):
				_scroll_to(_top + (shown if arrow == more_below else -shown))
				return
	if not event is InputEventMouseMotion and not (click and event.button_index == MOUSE_BUTTON_LEFT):
		return
	# Each row's hit band is its whole step, gaps included, so there is no dead
	# strip between two rows where a click does nothing.
	for i in rows.get_child_count():
		var row := rows.get_child(i) as Control
		var point := row.get_global_transform_with_canvas().affine_inverse() * event.position
		var gap := (row_step - row.size.y) * 0.5
		if Rect2(Vector2(-24.0, -gap), Vector2(row.size.x + 24.0, row_step)).has_point(point):
			if _top + i >= _rows.size():
				return
			if selected != _top + i:
				selected = _top + i
				if page == Page.EXPLORE: _room_cursors[_chapter] = selected
				_refresh()
			if click:
				choose()
			return


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
	if not is_zero_approx(_slide):
		_slide = lerpf(_slide, 0.0, clampf(slide_speed * delta, 0.0, 1.0))
		if absf(_slide) < 0.5:
			_slide = 0.0
		_layout_rows()
		_update_scrollbar()
		if _selection != null and _selection.visible:
			if _selection_tween and _selection_tween.is_valid(): _selection_tween.kill()
			_selection.position = rows.position + Vector2(-16, (selected - _top) * row_step + _slide)
	hint.text = "TAP TO SELECT    SWIPE TO SCROLL" if InputDevice.is_touch() else ("↑ ↓  ROOM    ← →  CHAPTER    ENTER / CLICK  PLAY    DRAG / WHEEL  MOVE MAP    ESC  BACK" if page == Page.EXPLORE else "W/S / STICK  MOVE    ENTER / A / CLICK  SELECT    ESC / B  BACK")
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
	if _rows.is_empty(): return
	selected = (selected + step + _rows.size()) % _rows.size()
	if page == Page.EXPLORE: _room_cursors[_chapter] = selected
	var shown := mini(visible_rows, _rows.size())
	var top := clampi(_top, maxi(selected - shown + 1, 0), selected)
	top = clampi(top, 0, maxi(_rows.size() - shown, 0))
	if top != _top:
		# A jump of more than a window (wrapping from last to first) snaps
		# instead of sliding through rows that are not shown.
		if absi(top - _top) > shown:
			_top = top
			_slide = 0.0
			_rebuild()
		else:
			_scroll_to(top)
	else:
		_refresh()


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
		Page.CHAPTERS:
			show_root()
		Page.EXPLORE:
			_room_cursors[_chapter] = selected
			_show_chapters()
			_move(_chapter)


# -------------------------------------------------------------- plumbing ----

## Hand over to the game. The menu goes dark and deaf FIRST: `action` loads a
## world into Screen's viewport, and a menu still taking input over the top of it
## would swallow the first jump.
func _start(action: Callable) -> void:
	menu_music.stop()
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
	for node: Control in [title, subtitle, caret, detail, hint, back_button, more_above, more_below]:
		node.add_theme_font_override("font", _font)


func _fade_to(a: float) -> void:
	if _fade and _fade.is_valid():
		_fade.kill()
	_fade = create_tween()
	_fade.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_fade.tween_property(root, "modulate:a", a, fade_time)


const CHAPTERS := [
	{"name":"THE OFFICE", "subtitle":"I  /  BREAK THE ROUTINE", "note":"Fluorescent nights. Impossible deadlines. One way out.", "color":"b7bccd", "art":"res://assets/background/act1_office/level_1.png"},
	{"name":"THE GARDENS OF MEMORY", "subtitle":"II  /  RETURN TO IRAN", "note":"Sunlit gardens, an old friendship, and four keys to freedom.", "color":"e6bb78", "art":"res://assets/backdrop/act2_sky/center.png"},
	{"name":"BENEATH THE SURFACE", "subtitle":"III  /  INTO THE BLUE", "note":"Leave the noise behind. Find your rhythm in the depths.", "color":"76d6d5", "art":"res://assets/act3/showcase_room.png"}
]

func _build_explorer() -> void:
	_catalog = JSON.parse_string(FileAccess.get_file_as_string("res://resources/menu/rooms.json"))
	for act: Array in _catalog:
		act.sort_custom(func(a: Dictionary,b: Dictionary) -> bool: return LdtkWorld.index_in_name(a.id)<LdtkWorld.index_in_name(b.id))
	root.get_node("Backdrop").color = Color("0d1520")
	root.get_node("Rule").visible = false
	subtitle.add_theme_color_override("font_color",Color("a4b1c3"))
	hint.add_theme_color_override("font_color",Color("95a6bb"))
	detail.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	title.position = Vector2(64,68)
	title.size = Vector2(1120,80)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	title.add_theme_font_size_override("font_size",48)
	subtitle.position = Vector2(68,146)
	subtitle.size = Vector2(1100,34)
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	subtitle.add_theme_font_size_override("font_size",18)
	rows.position = Vector2(80,238)
	rows.size = Vector2(400,360)
	row_step = 56
	row_height = 48
	more_above.position = Vector2(64,202)
	more_above.size.x = 430
	more_below.position = Vector2(64,574)
	more_below.size.x = 430
	detail.position = Vector2(64,615)
	detail.size = Vector2(1150,40)
	detail.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	detail.add_theme_font_size_override("font_size",18)
	hint.add_theme_font_size_override("font_size",16)
	back_button.position = Vector2(1080,28)
	back_button.size = Vector2(160,44)
	back_button.add_theme_font_size_override("font_size",18)
	rows.clip_contents = true
	_track = ColorRect.new()
	_track.color = Color("273342")
	_track.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_track)
	_thumb = ColorRect.new()
	_thumb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_thumb)
	_selection = Panel.new()
	_selection.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Color("273342")
	style.border_color = Color("e6bb78")
	style.border_width_left = 3
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_right = 8
	_selection.add_theme_stylebox_override("panel",style)
	root.add_child(_selection)
	root.move_child(_selection,root.get_node("Rows").get_index())
	_hero = TextureRect.new()
	_hero.position = Vector2(552,220)
	_hero.size = Vector2(664,350)
	_hero.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_hero.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_hero.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_hero)
	_map = WorldMap.new()
	_map.position = _hero.position
	_map.size = _hero.size
	_map.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_map.font = _font
	root.add_child(_map)
	# Hovering the map selects where it stands; a click plays the selected room or,
	# on a tap with no hover before it, selects that room first; the overview
	# inset jumps the camera across the Act.
	_map.room_hovered.connect(func(i: int) -> void: _pick_room(i, false))
	_map.room_pressed.connect(func(i: int) -> void:
		if i == selected:
			choose()
		else:
			_pick_room(i, true))
	_map.room_picked.connect(func(i: int) -> void: _pick_room(i, true))
	_eyebrow = _explorer_label(Vector2(552,190),16)
	_caption = _explorer_label(Vector2(552,575),18)
	_counter = _explorer_label(Vector2(64,28),14)

func _explorer_label(at: Vector2, font_size: int) -> Label:
	var label := Label.new()
	label.position = at
	label.size = Vector2(664,30)
	label.add_theme_font_override("font",_font)
	label.add_theme_font_size_override("font_size",font_size)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(label)
	return label

func _show_chapters() -> void:
	page = Page.CHAPTERS
	title.text = "CHOOSE YOUR CHAPTER"
	subtitle.text = "THE COMPLETE JOURNEY  /  ALL ROOMS OPEN"
	var built: Array[Dictionary] = []
	for i in 3:
		built.append(_row(CHAPTERS[i].name,CHAPTERS[i].note,func() -> void: _show_explore(i)))
	_populate(built)

func _room_title(id: String) -> String:
	if id == "Prison_Hub": return "The four-key courtyard"
	if id.begins_with("Prison_"):
		var wing: String = {"R":"Red", "G":"Green", "B":"Blue", "Y":"Gold"}.get(id.substr(7,1),"Castle")
		return "%s wing · %02d" % [wing,int(id.right(2))]
	return id.replace("Act_2_", "").replace("Act3_", "").replace("Level_", "Room ").replace("_"," ")

func _show_explore(act: int) -> void:
	if page == Page.EXPLORE: _room_cursors[_chapter] = selected
	_chapter = act
	page = Page.EXPLORE
	title.text = CHAPTERS[act].name
	subtitle.text = "SELECT A ROOM  /  %d AVAILABLE" % _catalog[act].size()
	var built: Array[Dictionary] = []
	for room: Dictionary in _catalog[act]:
		built.append(_row(room.title if room.title != "" else _room_title(room.id),room.idea if room.idea != "" else "REPLAY  /  Your save files stay untouched.",func() -> void: _start(func() -> void: SaveGame.replay_room(act+1,room.id))))
	_map.set_world(act, _catalog[act], Color(CHAPTERS[act].color))
	_populate(built)
	_move(_room_cursors[act])
	_map.snap()

## Select room `index` in EXPLORE from the map, scrolling the list to it. `follow`
## pans the map there too; a hover on the map itself does not (world_map.gd).
func _pick_room(index: int, follow: bool) -> void:
	if page != Page.EXPLORE or index == selected and not follow:
		return
	_map_hover = not follow
	_move(index - selected)
	_map_hover = false

func _update_explorer() -> void:
	if _hero == null: return
	var act := selected if page == Page.CHAPTERS else _chapter
	act = clampi(act,0,2)
	var chapter: Dictionary = CHAPTERS[act]
	selected_color = Color(chapter.color)
	_eyebrow.text = chapter.subtitle
	_eyebrow.modulate = selected_color
	_counter.text = "HOOSHANG  /  THE COMPLETE JOURNEY"
	_hero.visible = page != Page.EXPLORE
	_map.visible = page == Page.EXPLORE
	if _map.visible:
		_map.show_room(selected, not _map_hover)
		_caption.text = "%02d / %02d   •   %s   •   CLICK TO PLAY" % [selected+1,_catalog[act].size(),_room_title(_catalog[act][selected].id)]
		_eyebrow.text = "WORLD MAP  /  GOLD: EXIT   MINT: START"
	else:
		_hero.texture = load(chapter.art)
		_caption.text = "%d ROOMS   /   ALL UNLOCKED" % _catalog[act].size()
		if page == Page.ROOT:
			_caption.text = "%d ROOMS   /   THREE CHAPTERS   /   ALL OPEN" % (_catalog[0].size()+_catalog[1].size()+_catalog[2].size())
