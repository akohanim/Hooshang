extends Node
## The lemon collectible: pickup, the global count, and the two things
## that are easy to get wrong — the total surviving a level change, and a taken
## fruit staying taken if the world is reloaded.
##
## The prefab is placed directly here rather than read from LDtk, because the
## levels deliberately contain none: they are authored by hand in the LDtk app.
## The LDtk -> node path itself lives in ldtk_entities_post_import.gd.
## Run:  godot --headless res://tests/lemon_test.tscn

const LEMON := preload("res://scenes/props/Lemon.tscn")

var failures: Array[String] = []
var world: LdtkWorld


func _ready() -> void:
	Collectibles.reset()
	world = Screen.load_scene("res://ldtk/Act1World.tscn")
	await _frames(60)
	var p := world.player
	p.input_locked = false

	_check(Collectibles.total == 0, "starts empty")

	var baseline_tokens := _tokens_on_surface().size()
	var lemon: Area2D = LEMON.instantiate()
	lemon.position = p.global_position + Vector2(0, -2)
	world.add_child(lemon)
	await _frames(5)
	_check(lemon.collision_layer == 8 and lemon.collision_mask == 2,
		"sits on layer 4 'triggers' and masks the player only (%d/%d)"
			% [lemon.collision_layer, lemon.collision_mask])
	# Eight: the bounce sheet tools/gen_lemon.py cuts has eight poses. The count
	# is pinned rather than just checked non-zero because a SpriteFrames that
	# silently lost its frames still animates — it just holds one pose forever,
	# which is not something you notice in a room you have walked a hundred times.
	var spin: SpriteFrames = lemon.get_node("Sprite").sprite_frames
	_check(spin.get_frame_count("spin") == 8,
		"bounces through all 8 painted frames  [%d]" % spin.get_frame_count("spin"))
	# The bounce is BAKED INTO THE FRAMES (see tools/gen_lemon.py), so the prop's
	# own bob tween has to be off or the fruit hovers twice at two rates and the
	# squash drifts out of step with the bottom of the bounce.
	_check(is_zero_approx(lemon.bob_height),
		"the prop's own bob is off, since the frames carry it  [%.1f]" % lemon.bob_height)
	# Square, all four the same, and a plausible size for a collectible. The exact
	# number is the generator's argument and is meant to be retuned by eye, so
	# pinning it here would fail the suite every time the art is nudged — but a
	# frame that comes back 0x0 or 455x455 means the import is stale or the
	# source sheet moved, and both are silent in play.
	var frame_size: Vector2 = spin.get_frame_texture("spin", 0).get_size()
	var ragged := false
	for i in spin.get_frame_count("spin"):
		if spin.get_frame_texture("spin", i).get_size() != frame_size:
			ragged = true
	_check(not ragged and frame_size.x == frame_size.y
			and frame_size.x >= 8.0 and frame_size.x <= 32.0,
		"every frame square, the same size, and collectible-sized  [%s]" % frame_size)
	# --- it is drawn on the TOKEN surface, not in the world ------------------
	# The whole point of the third surface: the world is rasterised at 320x180
	# and a fruit drawn in it can never be finer than that. Checked through the
	# real prop rather than by inspecting Screen, because what matters is that
	# the prop actually hands its picture over.
	_check(Screen.token_viewport != null, "Screen has a token surface")
	# Counted as a DELTA against the baseline taken before this fruit was added:
	# every lemon in the loaded world puts a picture on this surface, so
	# the absolute number is a fact about the level, not about the prop.
	var tokens := _tokens_on_surface()
	_check(tokens.size() == baseline_tokens + 1,
		"the fruit put its picture on it  [%d, was %d]" % [tokens.size(), baseline_tokens])
	_check(not lemon.get_node("Sprite").visible,
		"and took the world copy down, so there is only one fruit on screen")
	if tokens.size() > baseline_tokens:
		var copy: AnimatedSprite2D = tokens[-1]
		var dense: Vector2 = copy.sprite_frames.get_frame_texture("spin", 0).get_size()
		var flat: Vector2 = spin.get_frame_texture("spin", 0).get_size()
		_check(dense == flat * Screen.TOKEN_DENSITY,
			"at density x the texels  [%s vs %s]" % [dense, flat])
		# Scale times density must net out to 1, or the token is a different SIZE
		# rather than the same size at a finer grain — which is the mistake that
		# looked like a triumph the first time this was prototyped.
		_check(is_equal_approx(copy.scale.x * Screen.TOKEN_DENSITY, 1.0),
			"and the same world footprint, not a bigger fruit  [scale %.2f]" % copy.scale.x)
		# Within a pixel, not exact. The fruit bobs on a tween and the copy
		# mirrors it once a frame, so the two can legitimately be a fraction of
		# one frame's bob apart — about 0.05px at this speed. A pixel is
		# comfortably tighter than any misalignment a player could see and
		# comfortably looser than the lag that is supposed to be there.
		var drift: float = copy.global_position.distance_to(
			lemon.get_node("Sprite").global_position)
		_check(drift < 1.0,
			"standing where the real one is, within a pixel  [%.3fpx]" % drift)

	var id: String = lemon.collect_id()

	# Walk into it.
	p.global_position = lemon.global_position
	await _frames(20)
	_check(Collectibles.total == 1, "picking one up banks it (total=%d)" % Collectibles.total)

	_check(Collectibles.is_taken(id), "the fruit is remembered as taken")
	# The fruit flies to the counter and the DISPLAYED number ticks over when it
	# lands — but the banked total goes up on contact. Nothing the rest of the
	# game reads may wait on an animation, so the two are checked apart.
	_check(Collectibles.shown() == 0,
		"the counter hasn't ticked yet — the fruit is still in the air (shown=%d)"
			% Collectibles.shown())
	await _frames(60)
	_check(Collectibles.shown() == 1,
		"it ticks over when the fruit lands (shown=%d)" % Collectibles.shown())
	_check(not is_instance_valid(lemon), "the node goes away after the pop")
	# The copy has to go with it. A token left behind on the other surface is a
	# lemon hanging in the air over a fruit that no longer exists, and
	# nothing in the world would ever clean it up.
	_check(_tokens_on_surface().size() == baseline_tokens,
		"and the token went with it  [%d, baseline %d]" % [
			_tokens_on_surface().size(), baseline_tokens])

	# The requirement: the count carries from level to level.
	Screen.load_scene("res://scenes/levels/act1_office/Level2.tscn")
	await _frames(40)
	_check(Collectibles.total == 1,
		"the total survives loading another level (total=%d)" % Collectibles.total)

	# Death must not refund or reset it either.
	world = Screen.load_scene("res://ldtk/Act1World.tscn")
	await _frames(60)
	world.player.die()
	await _frames(40)
	_check(Collectibles.total == 1, "dying does not cost you fruit (total=%d)" % Collectibles.total)

	# And the same fruit cannot be farmed by reloading the world it lives in.
	var again: Area2D = LEMON.instantiate()
	again.position = Vector2(120, 248)
	world.add_child(again)
	await _frames(10)
	var same: Area2D = LEMON.instantiate()
	same.global_position = Vector2(120, 248)
	world.add_child(same)
	await _frames(10)
	Collectibles.collect(again.collect_id())
	var after: int = Collectibles.total
	Collectibles.collect(again.collect_id())
	_check(Collectibles.total == after,
		"collecting the same fruit twice counts once (total=%d)" % Collectibles.total)

	if failures.is_empty():
		print("LEMON TEST: ALL PASS")
	else:
		print("LEMON TEST: %d FAILURE(S)" % failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)


func _frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func _check(cond: bool, name: String) -> void:
	print(("  PASS  " if cond else "  FAIL  ") + name)
	if not cond:
		failures.append(name)


## Every lemon picture currently on Screen's token surface.
func _tokens_on_surface() -> Array[Node]:
	var found: Array[Node] = []
	if Screen.token_viewport == null:
		return found
	for child in Screen.token_viewport.get_children():
		if child is AnimatedSprite2D:
			found.append(child)
	return found
