extends CanvasLayer
## Independent touch input, never synthesized keyboard actions. Releasing a
## finger cannot cancel a held physical key or change a swipe's dash direction.

## Thumb travel in the overlay's 1280x720 design space for full movement speed.
@export var stick_radius := 84.0
## Ignore small resting-thumb movement.
@export var stick_deadzone := 0.22
## Minimum travel before an action finger commits one directional dash.
@export var swipe_distance := 52.0
## A stationary hold jumps after this delay; a quicker release is a tap jump.
@export var hold_delay := 0.12
## A quick tap sustains a small jump; a held finger allows the full jump.
@export var tap_hold_time := 0.08

var enabled := false
var movement := Vector2.ZERO
var stick_origin := Vector2(160, 548)
var stick_position := Vector2(160, 548)
var move_finger := -1
var action_finger := -1
var action_origin := Vector2.ZERO
var action_position := Vector2.ZERO
var _action_age := 0.0
var _action_committed := false
var _action_jumping := false
var _tap_hold := 0.0
var _jump_queued := false
var _dash_queued := Vector2.ZERO
var _glow_queued := false
var _player: Player
var _browser_callback: JavaScriptObject
var _was_playing := false

const PAUSE_RECT := Rect2(1128, 32, 112, 88)
const GLOW_RECT := Rect2(980, 32, 128, 88)

@onready var overlay: Control = $Overlay


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	# Update held gestures before the player consumes them.
	process_physics_priority = -100
	enabled = DisplayServer.is_touchscreen_available() or "--touch-controls" in OS.get_cmdline_user_args()
	if OS.has_feature("web"):
		enabled = enabled or bool(JavaScriptBridge.eval("navigator.maxTouchPoints > 0"))
		_browser_callback = JavaScriptBridge.create_callback(_browser_suspend)
		var window := JavaScriptBridge.get_interface("window")
		window.addEventListener("blur", _browser_callback)
		window.addEventListener("pagehide", _browser_callback)
		JavaScriptBridge.get_interface("document").addEventListener("visibilitychange", _browser_callback)
	if enabled:
		InputDevice.note_touch()
	InputDevice.changed.connect(_device_changed)
	Screen.scene_loaded.connect(_scene_changed)
	Pause.opened.connect(reset)
	Dialogue.dialogue_opened.connect(reset)
	get_viewport().size_changed.connect(_resized)
	overlay.visible = false


func _exit_tree() -> void:
	if OS.has_feature("web") and _browser_callback != null:
		var window := JavaScriptBridge.get_interface("window")
		window.removeEventListener("blur", _browser_callback)
		window.removeEventListener("pagehide", _browser_callback)
		JavaScriptBridge.get_interface("document").removeEventListener("visibilitychange", _browser_callback)


func _scene_changed(_scene: Node) -> void:
	reset()
	_player = null


func _device_changed(_device: int) -> void:
	if not InputDevice.is_touch():
		reset()


func _browser_suspend(_arguments: Array) -> void:
	if enabled:
		suspend.call_deferred()


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and enabled:
		suspend()


func suspend() -> void:
	reset()
	if is_instance_valid(Pause) and Pause.can_pause():
		Pause.pause_game()


func _resized() -> void:
	reset()
	if enabled and DisplayServer.window_get_size().x < DisplayServer.window_get_size().y:
		suspend()


func gameplay_available() -> bool:
	if not enabled or not InputDevice.is_touch() or get_tree().paused or Screen.current == null or Dialogue.is_active():
		return false
	if not is_instance_valid(_player):
		_player = Pause.player()
	return is_instance_valid(_player) and not _player.input_locked \
		and not _player._frozen and _player.state != Player.State.DEAD


func _physics_process(delta: float) -> void:
	var playing := gameplay_available()
	overlay.visible = playing
	if not playing:
		if _was_playing:
			reset()
		_was_playing = false
		return
	_was_playing = true
	var real_delta := delta / maxf(Engine.time_scale, 0.001)
	_tap_hold = maxf(0.0, _tap_hold - real_delta)
	if action_finger >= 0 and not _action_committed:
		_action_age += real_delta
		if _action_age >= hold_delay:
			_action_committed = true
			_action_jumping = true
			_jump_queued = true
	overlay.queue_redraw()


func _input(event: InputEvent) -> void:
	if not (event is InputEventScreenTouch or event is InputEventScreenDrag):
		return
	enabled = true
	InputDevice.note_touch()
	# Menus, dialogue and the film own their touches. No queued gameplay
	# action is allowed to escape one of those contexts into the next.
	if not gameplay_available():
		reset()
		return
	get_viewport().set_input_as_handled()
	var point: Vector2 = overlay.get_global_transform_with_canvas().affine_inverse() * event.position
	if event is InputEventScreenTouch:
		if event.canceled:
			_release_finger(event.index, true)
		elif event.pressed:
			_begin_finger(event.index, point)
		else:
			# Some browsers coalesce the last motion into touchend.
			_move_finger(event.index, point)
			_release_finger(event.index, false)
	else:
		_move_finger(event.index, point)
	overlay.queue_redraw()


func _begin_finger(index: int, point: Vector2) -> void:
	if PAUSE_RECT.has_point(point):
		reset()
		Pause.pause_game()
	elif GLOW_RECT.has_point(point):
		_glow_queued = true
	elif point.x < 600 and point.y > 260 and move_finger < 0:
		move_finger = index
		stick_origin = point
		stick_position = point
		movement = Vector2.ZERO
	elif point.x >= 600 and point.y > 160 and action_finger < 0:
		action_finger = index
		action_origin = point
		action_position = point
		_action_age = 0.0
		_action_committed = false
		_action_jumping = false


func _move_finger(index: int, point: Vector2) -> void:
	if index == move_finger:
		var offset := (point - stick_origin).limit_length(stick_radius)
		stick_position = stick_origin + offset
		var strength := offset.length() / stick_radius
		movement = Vector2.ZERO if strength <= stick_deadzone else offset / stick_radius
	elif index == action_finger:
		action_position = point
		var offset := point - action_origin
		# One swipe per finger, even if it zigzags or remains held.
		if offset.length() >= swipe_distance and (not _action_committed or _action_jumping):
			_dash_queued = Vector2.RIGHT.rotated(roundf(offset.angle() / (PI / 4.0)) * PI / 4.0)
			_action_committed = true
			_action_jumping = false
			_tap_hold = 0.0


func _release_finger(index: int, canceled: bool) -> void:
	if index == move_finger:
		move_finger = -1
		movement = Vector2.ZERO
		stick_origin = Vector2(160, 548)
		stick_position = stick_origin
	elif index == action_finger:
		if not canceled and not _action_committed:
			_jump_queued = true
			_tap_hold = tap_hold_time
		if canceled:
			_jump_queued = false
			_dash_queued = Vector2.ZERO
			_tap_hold = 0.0
		action_finger = -1
		_action_jumping = false


func reset() -> void:
	move_finger = -1
	action_finger = -1
	movement = Vector2.ZERO
	stick_origin = Vector2(160, 548)
	stick_position = stick_origin
	_action_jumping = false
	_action_committed = false
	_jump_queued = false
	_dash_queued = Vector2.ZERO
	_glow_queued = false
	_tap_hold = 0.0
	if is_instance_valid(overlay):
		overlay.queue_redraw()


func consume_jump() -> bool:
	var queued := _jump_queued
	_jump_queued = false
	return queued


func jump_held() -> bool:
	return _action_jumping or _tap_hold > 0.0


func consume_dash() -> Vector2:
	var queued := _dash_queued
	_dash_queued = Vector2.ZERO
	return queued


func consume_glow() -> bool:
	var queued := _glow_queued
	_glow_queued = false
	return queued
