extends Node
## The UI and the world render on separate surfaces, and stay that way.
##
## The world lives in Screen's 320x180 SubViewport; the dialogue box and other UI
## live on the window's own full-resolution surface, in front of it. This exists
## because they were once the same surface: making the window render at native
## resolution so dialogue type could be sharp also stopped the world being
## rasterised at 320x180, and Hooshang's sprites (88px art at 0.39 scale) quietly
## gained ~2.6x detail. A font change must never redraw the character again.
## Run:  godot --headless res://tests/screen_test.tscn

var failures: Array[String] = []
var world: LdtkWorld


func _ready() -> void:
	LdtkWorld.debug_start_room = "Level_4"
	world = Screen.load_scene("res://ldtk/Act1World.tscn")
	await _frames(60)
	world.player.input_locked = false

	_check(Screen.viewport.size == Screen.GAME_SIZE,
		"the world renders into a %s viewport (got %s)" % [Screen.GAME_SIZE, Screen.viewport.size])
	_check(world.get_viewport() == Screen.viewport,
		"the loaded world is inside that viewport, not the window")
	_check(Screen.current == world and Screen.current_path() != "",
		"Screen.current tracks the loaded world")
	_check(Dialogue.layer > 0,
		"the dialogue box is a CanvasLayer in FRONT of the world (layer %d)" % Dialogue.layer)
	_check(not Screen.viewport.is_ancestor_of(Dialogue),
		"the dialogue box is NOT inside the world's viewport")

	# The isolation itself: nothing the dialogue box does may reach the world.
	var before_size := Screen.viewport.size
	var before_scale: Vector2 = world.player.visual.scale
	Dialogue.say("Hooshang", "A line long enough to wrap onto a second row of type.",
		Color.WHITE)
	Dialogue.text_label.add_theme_font_size_override("font_size", 96)
	Dialogue.scale = Vector2(0.5, 0.5)
	await _frames(10)
	_check(Screen.viewport.size == before_size,
		"restyling the dialogue leaves the game viewport untouched (%s)" % Screen.viewport.size)
	_check(world.player.visual.scale == before_scale,
		"restyling the dialogue leaves the player's sprite untouched")
	Dialogue.line_finished.emit()
	await _frames(5)

	# Polled input (the controller reads Input directly).
	var x0 := world.player.global_position.x
	Input.action_press("move_right")
	await _frames(30)
	Input.action_release("move_right")
	_check(world.player.global_position.x > x0 + 4.0,
		"held input still drives the player (dx=%.1f)" % (world.player.global_position.x - x0))
	await _frames(20)

	# _unhandled_input has to be forwarded INTO the sub-viewport by hand; a
	# SubViewport gets no key events of its own.
	_check(await _retry_key_reaches_world(),
		"R-to-retry reaches the world through the viewport forwarding")

	_check(Screen.viewport.audio_listener_enable_2d,
		"positional audio has a listener in the world's viewport")

	await _check_dash_trail()

	if failures.is_empty():
		print("SCREEN TEST: ALL PASS")
	else:
		print("SCREEN TEST: %d FAILURE(S)" % failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)


## Dash afterimages must be born INSIDE the world.
##
## They used to be parented to get_tree().current_scene. Once levels moved into
## this sub-viewport that stopped being the world — and because the debug picker
## frees itself on launch, current_scene was outright NULL in play, so every dash
## frame threw "Cannot call method 'add_child' on a null value" and the run died.
##
## Asserting WHERE the trail is born catches both halves of that, and needs no
## null trickery: under the old code the afterimages land on current_scene, which
## in this harness is the test node itself — outside the game viewport.
func _check_dash_trail() -> void:
	var p := world.player
	p.input_locked = false
	p.has_dash = true
	p.global_position = Vector2(1000, 200)
	await _frames(10)
	Input.action_press("move_right")
	Input.action_press("dash")
	await _frames(5)
	Input.action_release("dash")
	Input.action_release("move_right")
	await _frames(3)
	print("    [trail] dashed, walking tree")

	var inside := 0
	var outside := 0
	for n in _sprites(get_tree().root):
		if n.modulate.a < 1.0 and n.get_parent() != null:
			if Screen.viewport.is_ancestor_of(n):
				inside += 1
			else:
				outside += 1
	_check(inside > 0, "dashing spawns afterimages inside the world (%d)" % inside)
	_check(outside == 0, "no afterimage escapes onto the UI surface (%d)" % outside)


func _sprites(n: Node) -> Array:
	var out := []
	if n is Sprite2D:
		out.append(n)
	for c in n.get_children():
		out += _sprites(c)
	return out


func _retry_key_reaches_world() -> bool:
	world.player.input_locked = false
	var ev := InputEventKey.new()
	ev.keycode = KEY_R
	ev.physical_keycode = KEY_R
	ev.pressed = true
	Input.parse_input_event(ev)
	# Input is dispatched on process frames, not physics frames.
	for i in 8:
		await get_tree().process_frame
		if world.player.state == Player.State.DEAD:
			return true
	return false


func _frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func _check(cond: bool, name: String) -> void:
	print(("  PASS  " if cond else "  FAIL  ") + name)
	if not cond:
		failures.append(name)
