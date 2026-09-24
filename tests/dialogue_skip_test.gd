extends Node
## Deterministic input timing with real waits for banner transitions.
var failures: Array[String] = []
var _closed_count := 0

func _ready() -> void:
	var box: DialogueBox = Dialogue
	box.set_process(false)
	box.chars_per_second = 0.1
	box.dialogue_closed.connect(func(): _closed_count += 1)
	box.begin_conversation(self)
	await _say_line(box, "Hooshang", "A long unread sentence. Another sentence follows.")
	Input.action_press("skip_dialogue")
	_tick(box, 0.5)
	_check(box._active and box._revealing, "short hold leaves speech playing")
	_check(box.skip_hint.visible and box.skip_progress.value > 0.4, "holding immediately shows progress")
	Input.action_release("skip_dialogue")
	_tick(box, 0.02)
	_check(box.skip_progress.value == 0.0, "release cancels progress")
	Input.action_press("skip_dialogue")
	_tick(box, 0.5)
	_check(box._active, "separate short holds never accumulate")
	box._notification(NOTIFICATION_APPLICATION_FOCUS_OUT)
	_tick(box, 2.0)
	_check(box._active, "focus loss cancels the hold")
	Input.action_release("skip_dialogue")
	_tick(box, 0.02)
	Input.action_press("skip_dialogue")
	_tick(box, box.skip_hold_time + 0.05)
	_check(not box._active, "completed hold closes the current line")
	Input.action_release("skip_dialogue")
	_tick(box, 0.02)
	await _close(box)
	_check(_closed_count == 1, "one smooth close and one close signal")
	_tick(box, 3.0)
	await box.say("Rumi", "This later line should never open, even after a long pause.")
	_check(not box.visible, "skip remains committed after release and pauses")
	box.end_conversation()
	Input.action_press("skip_dialogue")
	box.begin_conversation(self)
	await _say_line(box, "Rumi", "A new conversation must be readable.")
	_tick(box, 2.0)
	_check(box._active, "button held before scene cannot skip it")
	Input.action_release("skip_dialogue")
	_tick(box, 0.02)
	var confirm := InputEventAction.new()
	confirm.action = "ui_accept"
	confirm.pressed = true
	box._unhandled_input(confirm)
	_check(not box._revealing and box._active, "confirm reveals without dismissing")
	box._unhandled_input(confirm)
	await _close(box)
	box.end_conversation()
	box.begin_conversation(self)
	await _say_line(box, "", "A line in an eligible conversation.")
	_tick(box, box.hint_delay + 0.05)
	_check(box.skip_hint.visible, "hint appears without needing a hold")
	InputDevice._note(InputDevice.Device.CONTROLLER)
	_tick(box, 0.02)
	_check("□" in box.skip_hint.text, "controller prompt shows face button")
	InputDevice._note(InputDevice.Device.KEYBOARD)
	_tick(box, 0.02)
	_check("Hold X" in box.skip_hint.text, "keyboard prompt returns live")
	await _close(box)
	box.end_conversation()
	# No length threshold or protected categories. A one-line conversation and
	# standalone system text use the exact same hold and release protection.
	for text in ["A short greeting.", "An opening scene.", "An essential tutorial.", "One long exchange. ".repeat(40)]:
		box.begin_conversation(self)
		await _say_line(box, "Rumi", text)
		Input.action_press("skip_dialogue")
		_tick(box, box.skip_hold_time + 0.1)
		_check(not box._active and box._skip_armed(), "every scoped dialogue can be skipped: " + text.left(25))
		Input.action_release("skip_dialogue")
		_tick(box, 0.02)
		await _close(box)
		box.end_conversation()
	await _say_line(box, "", "Standalone speech also supports skipping.")
	Input.action_press("skip_dialogue")
	_tick(box, 2.0)
	_check(not box._active and box._skip_armed(), "standalone speech uses the same skip action")
	Input.action_release("skip_dialogue")
	await _close(box)
	_check(not box._skip_armed(), "standalone close clears skip for next line")
	await _say_line(box, "", "This next standalone line must open normally.")
	_check(box._active, "standalone skip cannot leak to next dialogue")
	await _close(box)
	print("DIALOGUE SKIP TEST: %s" % ("ALL PASS" if failures.is_empty() else str(failures)))
	get_tree().quit(0 if failures.is_empty() else 1)


func _tick(box: DialogueBox, seconds: float) -> void:
	var steps := int(ceil(seconds * 60.0))
	for i in steps:
		box._process(1.0 / 60.0)


func _say_line(box: DialogueBox, speaker: String, text: String) -> void:
	box.say(speaker, text, Color(1, 1, 1, 1))
	await _frames(int(maxf(box.entrance_time, box.portrait_entrance_time) * 60.0) + 3)
	var guard := 0
	while not box._revealing and guard < 30:
		await _frames(1)
		guard += 1


## Drains any still-open pages by hand, THEN keeps waiting on real physics
## frames until `visible` actually drops — not just until `_active` does.
## Skip-armed closing (see say()'s own `break`) can set `_active = false` the
## instant the hold crosses the threshold, well before the real close-out
## timer it then starts has actually elapsed; treating `_active == false` as
## "fully closed" races that timer exactly the way an idle/physics frame
## mismatch used to (see _frames' own note).
func _close(box: DialogueBox) -> void:
	while box._active:
		box.line_finished.emit()
		await _frames(3)
	var guard := 0
	while box.visible and guard < 60:
		await _frames(1)
		guard += 1


## PHYSICS frames, not idle — say()'s own entrance/close waits are physics
## SceneTreeTimers (see its own note on why), and idle process_frame signals
## have no fixed relationship to those, headless or otherwise (intro_test.gd
## documents the same reasoning). Waiting on the wrong clock let one say()
## call's close-out still be mid-flight — physically overlapping the NEXT
## call's fresh _active/_revealing state — when this helper had already
## declared the box free to reuse.
func _frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func _check(cond: bool, name: String) -> void:
	print(("  PASS  " if cond else "  FAIL  ") + name)
	if not cond:
		failures.append(name)
