extends Node
## Menu navigation on a CONTROLLER.
##
## The bug this pins: `move_up`/`move_down` are bound to the left stick as well
## as the d-pad and the arrows, with a 0.25 deadzone tuned for walking. The menus
## used to move the cursor from input EVENTS, and a stick that is off centre
## emits a continuous stream of InputEventJoypadMotion — so one nudge ran the
## cursor down the whole list, and a pad whose stick rests slightly off centre
## scrolled the menu forever on its own. It worked perfectly on a keyboard, which
## is why it survived: every test drove it with keys.
##
## Both menus poll instead now, so all three input kinds behave the same. What is
## asserted here is the behaviour, not the mechanism:
##   - a stick resting below the threshold moves nothing, however long you wait
##   - one push moves exactly ONE row
##   - holding repeats, but only after a delay a human would read as deliberate
##   - letting go stops it
##
## Run:  godot --headless res://tests/menu_nav_test.tscn

const MENU := "res://scenes/ui/MainMenu.tscn"

var failures: Array[String] = []
var menu: Node


func _ready() -> void:
	SaveGame.dir = "user://_test_nav_saves"
	await get_tree().process_frame
	menu = load(MENU).instantiate()
	get_tree().root.add_child(menu)
	await _hold(0.4)
	_check(menu._rows.size() >= 3,
		"the menu has enough rows to navigate  [%d]" % menu._rows.size())
	if menu._rows.size() < 3:
		return _finish()

	# --- a resting stick must do nothing -------------------------------------
	# The single most important line here. 0.30 is over the walking deadzone
	# (0.25) and under the menu's own threshold, which is exactly where a tired
	# pad sits when nobody is touching it.
	menu.selected = 0
	Input.action_press("move_down", 0.30)
	await _hold(1.2)
	Input.action_release("move_down")
	_check(menu.selected == 0,
		"a stick resting at 0.30 does not move the cursor at all  [row %d after 1.2s]"
			% menu.selected)

	# --- one push, one row ---------------------------------------------------
	menu.selected = 0
	Input.action_press("move_down", 0.95)
	await _hold(0.10)                       # well inside repeat_delay
	Input.action_release("move_down")
	await _frames(2)
	_check(menu.selected == 1,
		"one push moves exactly one row  [row %d]" % menu.selected)

	# --- held, it repeats — but not instantly --------------------------------
	# MOVES are counted, not row numbers compared: the list wraps, so on a short
	# menu "further down" is not a thing that can be asserted.
	menu.selected = 0
	Input.action_press("move_down", 0.95)
	var moves := 0
	var last: int = menu.selected
	var elapsed := 0.0
	var before_delay := -1
	while elapsed < menu.repeat_delay + menu.repeat_rate * 3.5:
		await get_tree().process_frame
		elapsed += get_process_delta_time()
		if menu.selected != last:
			moves += 1
			last = menu.selected
		if before_delay < 0 and elapsed >= menu.repeat_delay * 0.8:
			before_delay = moves
	Input.action_release("move_down")
	await _frames(2)
	_check(before_delay == 1,
		"one move only, until the repeat delay is up  [%d moves in the first %.2fs]"
			% [before_delay, menu.repeat_delay * 0.8])
	_check(moves >= 2, "and it repeats once held past it  [%d moves]" % moves)
	# Not a runaway. The event-driven version this replaced could clear the list
	# several times over in the same window; one move per repeat_rate is the bar.
	_check(moves <= 8, "at a readable rate, not a blur  [%d moves]" % moves)

	# --- letting go stops it -------------------------------------------------
	var settled: int = menu.selected
	await _hold(0.5)
	_check(menu.selected == settled,
		"releasing stops the cursor dead  [row %d, was %d]" % [menu.selected, settled])

	# --- and up works the same way ------------------------------------------
	menu.selected = 2
	Input.action_press("move_up", 0.95)
	await _hold(0.10)
	Input.action_release("move_up")
	await _frames(2)
	_check(menu.selected == 1, "up moves one row too  [row %d]" % menu.selected)

	await _mouse_checks()
	_finish()


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _hold(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout


func _check(cond: bool, name: String) -> void:
	print(("  PASS  " if cond else "  FAIL  ") + name)
	if not cond:
		failures.append(name)


func _finish() -> void:
	for action in ["move_up", "move_down"]:
		if Input.is_action_pressed(action):
			Input.action_release(action)
	if failures.is_empty():
		print("MENU NAV TEST: ALL PASS")
	else:
		print("MENU NAV TEST: %d FAILURE(S)" % failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)


func _mouse_checks() -> void:
	# Actual viewport input, including the CanvasLayer scale, rather than
	# invoking menu callbacks. A click must select its target without a prior hover.
	menu.show_root()
	await _frames(2)
	var first := menu.rows.get_child(0) as Control
	_mouse(menu.rows.get_child(1), false)
	_check(menu.selected == 1, "mouse hover selects the pointed title row")
	_mouse(first, true)
	_check(menu.page == MainMenu.Page.SLOTS, "click opens the new-game slot menu")
	_mouse(menu.back_button, true)
	_check(menu.page == MainMenu.Page.ROOT, "clickable Back returns to title")
	menu._show_confirm(0)
	_mouse(menu.rows.get_child(0), true)
	_check(menu.page == MainMenu.Page.SLOTS, "click Keep It cancels overwrite")
	menu.show_root()
	var miss := InputEventMouseButton.new()
	miss.button_index = MOUSE_BUTTON_LEFT
	miss.pressed = true
	miss.position = Vector2(1, 1)
	get_viewport().push_input(miss, true)
	_check(menu.page == MainMenu.Page.ROOT, "background click does not activate a row")

	var entries: Array[Dictionary] = []
	for i in 10:
		entries.append(menu._row("ROOM %d" % i, "", func() -> void: menu.set_meta("clicked", i)))
	menu._populate(entries)
	for i in 7:
		var wheel := InputEventMouseButton.new()
		wheel.button_index = MOUSE_BUTTON_WHEEL_DOWN
		wheel.pressed = true
		get_viewport().push_input(wheel, true)
	_check(menu._top > 0, "mouse wheel reveals rows beyond the visible window")
	var expected: int = menu._top + 2
	_mouse(menu.rows.get_child(2), true)
	_check(menu.get_meta("clicked", -1) == expected, "click activates the correct scrolled entry")
	menu._move(1)
	var keyboard_row: int = menu.selected
	await _frames(3)
	_check(menu.selected == keyboard_row, "stationary mouse leaves keyboard selection alone")

	menu.visible = false
	menu.process_mode = Node.PROCESS_MODE_DISABLED
	# Exercise the pause menu through the viewport while the tree is paused.
	process_mode = Node.PROCESS_MODE_ALWAYS
	Pause.open = true
	Pause.visible = true
	get_tree().paused = true
	_mouse(Pause.rows.get_child(PauseMenu.Item.RETRY), false)
	_check(Pause.selected == PauseMenu.Item.RETRY, "mouse hover selects a paused menu row")
	_mouse(Pause.rows.get_child(PauseMenu.Item.RESUME), true)
	_check(not Pause.open and not get_tree().paused, "click Resume unpauses the game")
	await _hold(Pause.fade_time + 0.05)


func _mouse(control: Control, click: bool) -> void:
	var point := control.get_global_transform_with_canvas() * (control.size * 0.5)
	if click:
		var event := InputEventMouseButton.new()
		event.position = point
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = true
		get_viewport().push_input(event, true)
		event = event.duplicate()
		event.pressed = false
		get_viewport().push_input(event, true)
	else:
		var event := InputEventMouseMotion.new()
		event.position = point
		get_viewport().push_input(event, true)
