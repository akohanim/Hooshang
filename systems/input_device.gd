extends Node
## Which input device he was last seen using — keyboard/mouse or a controller
## (autoload "InputDevice"). Godot has no "which device is active" query, only
## events, so this watches every one that arrives and remembers the last KIND
## it saw. Exists for on-screen prompts (InputPrompt) that show a key on a
## keyboard and a button on a pad — see JumpTutorial for the first user.
##
## Starts KEYBOARD, since that is how most sessions begin, and only flips to
## CONTROLLER on an actual button press or a stick pushed well past centre —
## an axis event fires continuously at rest with tiny centering noise, and
## reacting to that would flap the icon between the two on every idle frame.

enum Device { KEYBOARD, CONTROLLER, TOUCH }

signal changed(device: Device)

var current := Device.KEYBOARD

## Below this, a resting stick's own jitter must not count as "picked up the
## pad" — see the class comment.
const AXIS_DEADZONE := 0.5
const TOUCH_MOUSE_GRACE_MS := 500
var _last_touch_ms := -TOUCH_MOUSE_GRACE_MS


func _input(event: InputEvent) -> void:
	if event is InputEventMouse:
		if event.device == InputEvent.DEVICE_ID_EMULATION:
			return
		# Web touch drags can arrive with a companion MouseMotion whose device
		# is 0, so the emulation ID alone is insufficient. Switching devices
		# here resets TouchControls BEFORE its ScreenDrag can move either thumb.
		# Keep ownership through a held gesture and its trailing mouse events.
		if is_touch() and (TouchControls.has_active_gesture() \
				or Time.get_ticks_msec() - _last_touch_ms < TOUCH_MOUSE_GRACE_MS):
			return
	if event is InputEventScreenTouch or event is InputEventScreenDrag:
		note_touch()
	elif event is InputEventKey or event is InputEventMouseButton \
			or event is InputEventMouseMotion:
		_note(Device.KEYBOARD)
	elif event is InputEventJoypadButton:
		_note(Device.CONTROLLER)
	elif event is InputEventJoypadMotion \
			and absf((event as InputEventJoypadMotion).axis_value) > AXIS_DEADZONE:
		_note(Device.CONTROLLER)


## Named to dodge Object's own reserved _set(property, value) — a same-named
## override with a different signature is a parse error, not a shadow.
func _note(device: Device) -> void:
	if device == current:
		return
	current = device
	changed.emit(current)


func is_controller() -> bool:
	return current == Device.CONTROLLER


func note_touch() -> void:
	_last_touch_ms = Time.get_ticks_msec()
	_note(Device.TOUCH)


func is_touch() -> bool:
	return current == Device.TOUCH
