extends Node2D
## An untimed painting break: real player movement, persistent brush marks,
## three wall areas, and a deliberate return to Jamshid to resume the story.
var active := false
var has_can := false
var painting := false
var completed := false
var areas: Array[bool] = [false, false, false]
var color_index := 0
var _player: Player
var _mural: Node2D
var _can: Sprite2D
var _cousin: Node2D
var _owner: Node
var _spray_clock := 0.0
var _audio_clock := 0.0
var _spray_point := Vector2.ZERO
var _held_can_index := -1
var _pick_was_pressed := false
var _spray_was_pressed := false
var _down_was_pressed := false
var _queued_pick := 0
var _queued_spray := 0
@onready var _ground_cans: Array[Sprite2D] = [$BlueCan, $RedCan, $GoldCan]

func play(player: Player, mural: Node2D, can: Sprite2D, cousin: Node2D, owner: Node) -> void:
	_player = player
	_mural = mural
	_can = can
	_cousin = cousin
	_owner = owner
	has_can = false
	completed = false
	areas = [false, false, false]
	_held_can_index = -1
	painting = false
	_pick_was_pressed = Input.is_action_pressed("jump")
	_spray_was_pressed = Input.is_action_pressed("dash")
	_down_was_pressed = Input.is_action_pressed("move_down")
	_queued_pick = 0
	_queued_spray = 0
	_player.set_interaction_controls(true)
	active = true
	show()
	$HUD/Panel.show()
	_can.hide()
	while active and not Dialogue.scene_skip_requested(owner):
		await get_tree().physics_frame
	active = false
	painting = false
	_stop_spray()
	_player.set_interaction_controls(false)
	$HUD/Panel.hide()
	hide()

func _input(event: InputEvent) -> void:
	if not active: return
	var pick := event.is_action("jump")
	var spray := event.is_action("dash")
	if not pick and not spray: return
	# Preserve short taps that begin and end between two physics ticks.
	if event.is_pressed() and not event.is_echo():
		if pick: _queued_pick += 1
		if spray: _queued_spray += 1
	# The SubViewportContainer already delivers these events. Consume them on
	# both surfaces so Screen's root _unhandled_input cannot forward the SAME
	# press a second time and immediately reverse a pickup/spray toggle.
	get_viewport().set_input_as_handled()
	get_tree().root.set_input_as_handled()

func _physics_process(delta: float) -> void:
	if not active: return
	var at := to_local(_player.global_position)
	# Keep the break inside the courtyard, away from the palace/room exits.
	var bounded := clampf(at.x, 28.0, 222.0)
	if bounded != at.x:
		_player.global_position.x = to_global(Vector2(bounded, 0)).x
		_player.velocity.x = 0
		at.x = bounded
	_spray_clock = maxf(0, _spray_clock - delta)
	_audio_clock = maxf(0, _audio_clock - delta)
	# These buttons are reserved from the normal jump/dash controller. Poll
	# rising edges so held buttons and keyboard repeat never toggle repeatedly.
	var pick_pressed := Input.is_action_pressed("jump")
	var spray_pressed := Input.is_action_pressed("dash")
	var down_pressed := Input.is_action_pressed("move_down")
	var finish_pressed := down_pressed and not _down_was_pressed
	var pick_count := _queued_pick
	var spray_count := _queued_spray
	if pick_count == 0 and pick_pressed and not _pick_was_pressed: pick_count = 1
	if spray_count == 0 and spray_pressed and not _spray_was_pressed: spray_count = 1
	_queued_pick = 0
	_queued_spray = 0
	for i in pick_count: _toggle_can()
	for i in spray_count:
		if has_can: _set_spraying(not painting)
	_pick_was_pressed = pick_pressed
	_spray_was_pressed = spray_pressed
	_down_was_pressed = down_pressed
	if has_can:
		if painting:
			var aim := Input.get_vector("move_left", "move_right", "move_up", "move_down")
			if TouchControls.move_finger >= 0: aim = TouchControls.movement
			_spray_point += aim * 60.0 * delta
			_spray_point.x = clampf(_spray_point.x, 32, 218)
			_spray_point.y = clampf(_spray_point.y, -100, -13)
		else:
			_spray_point = Vector2(clampf(at.x + _player.facing * 9, 32, 218), clampf(at.y - 15, -100, -13))
		_can.global_position = _player.global_position + Vector2(_player.facing * 6, -7)
		_can.rotation = (_spray_point - to_local(_can.global_position)).angle() + PI / 2
		_can.modulate = _mural.PAINT_COLORS[color_index]
		if painting and _spray_clock <= 0:
			_spray_clock = 0.06
			_mural.spray(_spray_point, color_index)
			areas[clampi(int((_spray_point.x - 32.0) / 60.0), 0, 2)] = true
			if _audio_clock <= 0 and _owner.world.has_node("Act2Audio"):
				_owner.world.get_node("Act2Audio").play_cue(&"Spray")
				_audio_clock = 3.9
	if not painting: _stop_spray()
	var count := areas.count(true)
	if count == 3: _mural.stage = 2
	var near_cousin := absf(_player.global_position.x - _cousin.global_position.x) < 22 and _player.is_on_floor()
	if count == 3 and near_cousin and not painting and finish_pressed:
		completed = true
		_mural.stage = 3
		active = false
	var controls := "C/A NEAR A CAN: PICK UP\nARROWS/STICK: WALK"
	if has_can:
		controls = "C/A: PUT DOWN - X: START SPRAY\nARROWS/STICK: WALK"
	if painting:
		controls = "X: STOP SPRAY - C/A: PUT DOWN\nARROWS/STICK: AIM"
	var goal := "PAINT %d/3 AREAS - HOLD Z/Y TO SKIP" % count
	if count == 3:
		goal = "3/3 - KEEP PAINTING OR X TO STOP" if painting else "DOWN BY JAMSHID: FINISH - HOLD Z/Y: SKIP"
	$HUD/Panel/Hint.text = controls + "\n" + goal
	queue_redraw()

func _toggle_can() -> void:
	if has_can:
		_set_spraying(false)
		var dropped: Sprite2D = _ground_cans[_held_can_index]
		dropped.global_position = _player.global_position + Vector2(_player.facing * 7, 2)
		dropped.show()
		has_can = false
		_held_can_index = -1
		_can.hide()
		return
	var nearest := -1
	var distance := 22.0
	for i in _ground_cans.size():
		var candidate := _ground_cans[i]
		var gap := _player.global_position.distance_to(candidate.global_position)
		if candidate.visible and gap < distance:
			nearest = i
			distance = gap
	if nearest < 0: return
	_held_can_index = nearest
	color_index = nearest
	has_can = true
	_ground_cans[nearest].hide()
	_can.show()
	_spray_point = to_local(_player.global_position) + Vector2(_player.facing * 9, -15)

func _set_spraying(value: bool) -> void:
	painting = value and has_can
	_player.set_interaction_controls(true, painting)
	if not painting: _stop_spray()

func _exit_tree() -> void:
	if is_instance_valid(_player): _player.set_interaction_controls(false)

func _stop_spray() -> void:
	if _audio_clock > 0 and _owner.world.has_node("Act2Audio"):
		_owner.world.get_node("Act2Audio").stop_cue(&"Spray")
	_audio_clock = 0

func _draw() -> void:
	if not active: return
	for area in 3:
		var ink := Color("cbb884")
		ink.a = 0.22 if areas[area] else 0.55
		draw_rect(Rect2(32 + area * 60, -43, 54, 32), ink, false, 1)
	if has_can:
		var ink: Color = _mural.PAINT_COLORS[color_index]
		draw_arc(_spray_point, 4, 0, TAU, 12, ink, 1)
		if painting:
			var nozzle := to_local(_can.global_position) + Vector2(0, -3)
			for offset in [-2, 0, 2]:
				draw_line(nozzle, _spray_point + Vector2(offset, offset), Color(ink, 0.65), 1)
