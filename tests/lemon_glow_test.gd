extends Node
## The 'z' ability: spend one lemon for 30s of light, which blinks a warning in
## its last few seconds and does not linger through death (nor refund the
## lemon it cost).
## Run:  godot --headless res://tests/lemon_glow_test.tscn

const PLAYER := preload("res://scenes/characters/hooshang/Hooshang.tscn")

var failures: Array[String] = []
var world: Node2D
var player: Player


func _ready() -> void:
	Collectibles.reset()
	world = Node2D.new()
	add_child(world)
	player = PLAYER.instantiate()
	world.add_child(player)
	await _frames(2)

	# --- it is PAINT, not a light --------------------------------------------
	#
	# A PointLight2D only shows up where it has something dim to brighten — it
	# MULTIPLIES the surface under it, so it visibly glows over an unlit
	# stretch of room and does almost nothing crossing an already-lit patch, and
	# it competes for this renderer's per-canvas-item light cap. "The player
	# only glows in shadow" was exactly that. Pinned here as node TYPE and
	# material, not just behaviour, so a well-meaning revert back to a light
	# fails loudly instead of only showing up as a bug report from a bright room.
	_check(player.lemon_glow_light is Sprite2D,
		"GLOW: LemonGlowLight is a Sprite2D, not a Light2D  [%s]"
			% player.lemon_glow_light.get_class())
	var mat := player.lemon_glow_light.material as CanvasItemMaterial
	_check(mat != null and mat.light_mode == CanvasItemMaterial.LIGHT_MODE_UNSHADED
			and mat.blend_mode == CanvasItemMaterial.BLEND_MODE_ADD,
		"GLOW: ...drawn unshaded and additive, so it cannot be crushed by "
			+ "CanvasModulate or starved by the light budget")

	# --- no lemons, no glow --------------------------------------------------
	_check(Collectibles.total == 0, "starts with no lemons")
	await _tap("glow")
	await _frames(2)
	_check(not player.lemon_glow_light.visible,
		"GLOW: pressing z with no lemons does nothing")
	_check(Collectibles.total == 0, "GLOW: ...and nothing is spent")

	# --- one lemon: pressing z lights him and spends it -----------------------
	Collectibles.total = 1
	await _tap("glow")
	await _frames(2)
	_check(Collectibles.total == 0, "GLOW: pressing z with a lemon spends it")
	_check(player.lemon_glow_light.visible and player.lemon_glow_light.modulate.r > 0.0,
		"GLOW: ...and lights him up  [visible=%s modulate=%s]"
			% [player.lemon_glow_light.visible, player.lemon_glow_light.modulate])
	# Close to lemon_glow_time rather than exactly it — a few physics frames
	# have already ticked it down by the time this checks.
	_check(player._lemon_glow_timer > player.lemon_glow_time - 1.0,
		"GLOW: ...for close to the full duration  [%.2fs of %.1fs]"
			% [player._lemon_glow_timer, player.lemon_glow_time])

	# --- pressing again mid-glow spends nothing -------------------------------
	Collectibles.total = 5
	await _tap("glow")
	await _frames(2)
	_check(Collectibles.total == 5,
		"GLOW: pressing again while already lit spends nothing  [%d]"
			% Collectibles.total)

	# --- steady while more than the flicker window remains --------------------
	player._lemon_glow_timer = player.lemon_glow_flicker_time + 1.0
	player._apply_lemon_glow()
	_check(player.lemon_glow_light.visible,
		"GLOW: steady while more than the flicker window remains")

	# --- flickers on and off through the warning window -----------------------
	var saw_on := false
	var saw_off := false
	player._lemon_glow_timer = player.lemon_glow_flicker_time
	while player._lemon_glow_timer > 0.0:
		player._lemon_glow_timer = maxf(player._lemon_glow_timer - (1.0 / 60.0), 0.0)
		player._apply_lemon_glow()
		if player.lemon_glow_light.visible:
			saw_on = true
		else:
			saw_off = true
	_check(saw_on and saw_off,
		"GLOW: flickers on and off in the warning window  [on=%s off=%s]"
			% [saw_on, saw_off])

	# --- and turns off for good once the timer runs out ------------------------
	_check(not player.lemon_glow_light.visible,
		"GLOW: turns off once the timer reaches zero")

	# --- death cancels it, and does not refund the lemon -----------------------
	Collectibles.total = 1
	player.respawn(Vector2.ZERO)
	await _frames(10)  # clear respawn's brief invulnerable_timer, or die() no-ops
	await _tap("glow")
	await _frames(2)
	_check(player.lemon_glow_light.visible, "DEATH: lit before dying")
	player.die()
	await _frames(2)
	_check(not player.lemon_glow_light.visible and player._lemon_glow_timer == 0.0,
		"DEATH: dying cuts the glow immediately  [visible=%s, %.1fs left]"
			% [player.lemon_glow_light.visible, player._lemon_glow_timer])
	_check(Collectibles.total == 0,
		"DEATH: ...and the spent lemon is not refunded  [%d]" % Collectibles.total)

	if failures.is_empty():
		print("LEMON GLOW TEST: ALL PASS")
	else:
		print("LEMON GLOW TEST: %d FAILURE(S)" % failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)


## One press-and-release of an action, straight into the input system —
## exercises the real 'glow' InputMap action rather than calling the
## player's method directly, so a rebound or dropped key shows up here.
func _tap(action: String) -> void:
	Input.action_press(action)
	await _frames(1)
	Input.action_release(action)


func _frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func _check(cond: bool, name: String) -> void:
	print(("  PASS  " if cond else "  FAIL  ") + name)
	if not cond:
		failures.append(name)
