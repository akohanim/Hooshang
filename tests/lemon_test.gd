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
const CRUMBLING_PLATFORM := preload("res://scenes/props/platforms/CrumblingPlatform.tscn")

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

	# --- the "+1000" -------------------------------------------------------
	#
	# On the HUD layer rather than in the world, and that is the whole reason it
	# is visible at all: the world is rasterised under a CanvasModulate of 0.05,
	# which would take a painted tag to 5% of what was drawn. Same layer the
	# flying fruit uses.
	#
	# CHECKED WITHOUT WAITING, deliberately. The counter assertions below turn on
	# the fruit still being in the air, so a wait parked here reads as the flight
	# having landed early — which is exactly what it did the first time this was
	# written. The tag's LIFETIME is measured at the end instead.
	var tag := _popup_tag()
	_check(tag != null, "a +1000 pops off the fruit")
	# The score is a SEPARATE number from the fruit count, banked on contact the
	# way the fruit is — nothing may wait on the tag or the roll.
	_check(Points.total == Points.LEMON,
		"and the lemon paid into the score  [%d]" % Points.total)
	_check(Points.shown() < Points.total,
		"...which the counter is still running up to  [showing %d of %d]"
			% [Points.shown(), Points.total])
	# Five glyphs for "+1000", one per character, composed from the sheet.
	_check(tag != null and tag.get_child_count() >= 5,
		"the tag is built per digit, so it can say any number  [%d children]"
			% (tag.get_child_count() if tag != null else -1))
	if tag != null:
		# Over the fruit, not parked at the corner: a tag at the origin is what
		# you get when the source's screen position was never asked for.
		var where: Vector2 = tag.position + tag.size * 0.5
		_check(where.length() > 40.0 and where.x < 1280.0 and where.y < 720.0,
			"...over the fruit rather than at the origin  [%s]" % where)
		# The filter lives on the GLYPHS, not on the tag: the tag is a Control
		# holding one TextureRect per character now.
		var glyph := tag.get_child(0) as TextureRect
		_check(glyph != null
				and glyph.texture_filter == CanvasItem.TEXTURE_FILTER_NEAREST,
			"...drawn with square pixels, not smoothed")

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

	# --- how long the tag lives -------------------------------------------
	#
	# Timed rather than sampled at one moment: "a second" is the whole ask, and
	# an assertion that only looks once cannot tell a tag that lasts 1.0s from
	# one that lasts 0.3s and one that never goes away.
	Collectibles.collect("popup:probe", 1, world.player)
	var frames := 0
	while _popup_tag() != null and frames < 240:
		await _frames(1)
		frames += 1
	var life := frames / 60.0
	_check(Points.shown() == Points.total,
		"the counter has caught up by then  [%d]" % Points.shown())
	_check(life >= 0.7 and life <= 1.6,
		"the +1000 is up for about a second  [%.2fs]" % life)

	# ---- Celeste strawberry rule: arm-then-land banks exactly once ---------
	#
	# Touching mid-air arms the fruit; it is NOT banked until the player is back
	# on the ground. The total stays at zero while pending and goes to 1 on
	# landing — and only 1, not 2.
	Collectibles.reset()
	world = Screen.load_scene("res://ldtk/Act1World.tscn")
	await _frames(60)
	p = world.player
	p.input_locked = false
	var ground_y := p.global_position.y

	# Place the lemon 50px above the player (well in the air).
	var air_lemon: Lemon = LEMON.instantiate()
	air_lemon.position = Vector2(p.global_position.x, ground_y - 50)
	world.add_child(air_lemon)
	await _frames(5)
	var air_id: String = air_lemon.collect_id()

	# Teleport the player to the lemon — they overlap and are now airborne.
	p.global_position = air_lemon.global_position
	await _frames(3)

	_check(air_lemon._pending,
		"STRAWBERRY: touching mid-air arms the lemon")
	_check(Collectibles.total == 0,
		"STRAWBERRY: the total stays at 0 while pending  [%d]" % Collectibles.total)
	_check(not Collectibles.is_taken(air_id),
		"STRAWBERRY: the fruit is NOT in the taken set while pending")

	# Wait for the player to fall (~19 frames for 50px at 980 px/s^2) and land.
	await _frames(40)
	_check(p.is_on_floor(), "STRAWBERRY: the player has landed  [y=%.1f]" % p.global_position.y)
	_check(Collectibles.total == 1,
		"STRAWBERRY: landing banks the fruit exactly once  [%d]" % Collectibles.total)
	_check(Collectibles.is_taken(air_id),
		"STRAWBERRY: the fruit IS in the taken set after banking")
	# After banking the lemon frees itself (a short pop tween, then queue_free),
	# which is itself proof it is no longer pending — a pending lemon never frees.
	# If it is still mid-pop it must already have cleared _pending.
	_check(not is_instance_valid(air_lemon) or not air_lemon._pending,
		"STRAWBERRY: no longer pending after banking")

	# ---- Celeste strawberry rule: arm-then-die restores --------------------
	#
	# A death while the fruit is armed un-arms it and puts it back exactly where
	# it was — art, glow, bob and trigger. The player can then collect it again.
	Collectibles.reset()
	world = Screen.load_scene("res://ldtk/Act1World.tscn")
	await _frames(60)
	p = world.player
	p.input_locked = false
	ground_y = p.global_position.y

	var death_lemon: Lemon = LEMON.instantiate()
	death_lemon.position = Vector2(p.global_position.x, ground_y - 50)
	world.add_child(death_lemon)
	await _frames(5)
	var death_id: String = death_lemon.collect_id()

	# Arm the lemon mid-air.
	p.global_position = death_lemon.global_position
	await _frames(3)
	_check(death_lemon._pending, "DEATH-RESTORE: armed before dying")

	# Die while still airborne.
	p.die()
	await _frames(40)  # respawn delay (~9 frames) + settling

	_check(not death_lemon._pending,
		"DEATH-RESTORE: death un-arms the fruit")
	_check(Collectibles.total == 0,
		"DEATH-RESTORE: death did not bank the fruit  [%d]" % Collectibles.total)
	_check(not Collectibles.is_taken(death_id),
		"DEATH-RESTORE: the fruit is NOT in the taken set after death")
	_check(is_instance_valid(death_lemon),
		"DEATH-RESTORE: the lemon node survives the death")
	if is_instance_valid(death_lemon):
		_check(death_lemon.monitoring,
			"DEATH-RESTORE: the trigger is re-armed after death")

		# Re-collect: teleport the player to the restored lemon and wait for
		# landing. The player respawned on the ground, so teleporting up puts
		# them airborne again.
		p.global_position = death_lemon.global_position
		await _frames(40)
		_check(Collectibles.total == 1,
			"DEATH-RESTORE: the lemon can be re-collected  [%d]" % Collectibles.total)

	# ---- Celeste strawberry rule: pending absent from save -----------------
	#
	# A pending lemon must NOT appear in Collectibles.save_state(), which is
	# what the room-transition autosave captures. If it did, a save written
	# while the player is airborne would bank a fruit they never earned.
	Collectibles.reset()
	world = Screen.load_scene("res://ldtk/Act1World.tscn")
	await _frames(60)
	p = world.player
	p.input_locked = false
	ground_y = p.global_position.y

	var save_lemon: Lemon = LEMON.instantiate()
	save_lemon.position = Vector2(p.global_position.x, ground_y - 50)
	world.add_child(save_lemon)
	await _frames(5)
	var save_id: String = save_lemon.collect_id()

	# Arm the lemon mid-air.
	p.global_position = save_lemon.global_position
	await _frames(3)
	_check(save_lemon._pending, "SAVE: armed for save test")

	var state := Collectibles.save_state()
	var taken_in_save: Array = state.get("taken", [])
	_check(not taken_in_save.has(save_id),
		"SAVE: a pending lemon is absent from Collectibles.save_state()")
	_check(int(state.get("total", 0)) == 0,
		"SAVE: total in save is 0 while the lemon is still pending  [%s]"
			% str(state.get("total")))

	# ---- collapsing platforms are NOT solid ground -------------------------
	#
	# A CrumblingPlatform is a floor for movement (is_on_floor() reads true on
	# it) but it is about to vanish, so it must not count as the "solid ground"
	# the strawberry rule bank on. The fruit stays pending while he rests on
	# one and only banks once he reaches real ground below it.
	Collectibles.reset()
	world = Screen.load_scene("res://ldtk/Act1World.tscn")
	await _frames(60)
	p = world.player
	p.input_locked = false
	ground_y = p.global_position.y

	var crumb: CrumblingPlatform = CRUMBLING_PLATFORM.instantiate()
	crumb.position = Vector2(p.global_position.x, ground_y - 40)
	crumb.size = Vector2(24, 8)
	world.add_child(crumb)
	await _frames(2)

	var crumb_lemon: Lemon = LEMON.instantiate()
	crumb_lemon.position = Vector2(p.global_position.x, ground_y - 60)
	world.add_child(crumb_lemon)
	await _frames(5)

	# Arm the lemon mid-air, above the platform.
	p.global_position = crumb_lemon.global_position
	await _frames(3)
	_check(crumb_lemon._pending,
		"CRUMBLING GROUND: armed mid-air, above the platform")

	# Let him fall and land ON the crumbling platform.
	var landed_on_crumb := false
	for i in 90:
		await _frames(1)
		if p.is_on_floor():
			landed_on_crumb = true
			break
	_check(landed_on_crumb, "CRUMBLING GROUND: falls and lands on the platform")
	_check(not p.is_on_solid_ground(),
		"CRUMBLING GROUND: the platform itself does not read as solid ground")
	_check(crumb_lemon._pending,
		"CRUMBLING GROUND: still pending while resting on the crumbling platform")
	_check(Collectibles.total == 0,
		"CRUMBLING GROUND: not banked while standing on a platform about to give way  [%d]"
			% Collectibles.total)

	# Wait for it to crumble and drop him through to real ground below.
	var banked := false
	for i in int((crumb.crumble_time + crumb.fall_time) * 60.0) + 60:
		await _frames(1)
		if Collectibles.total == 1:
			banked = true
			break
	_check(banked, "CRUMBLING GROUND: banks once he reaches real ground below")
	_check(p.is_on_solid_ground(),
		"CRUMBLING GROUND: ...and that ground reads as solid  [on_floor=%s]"
			% p.is_on_floor())

	# ---- crossing the SEAM between two collapsing platforms ---------------
	#
	# is_on_solid_ground() used to probe with a single ray under his centre and
	# treat a MISS as solid ground, on the theory that nothing in the way meant
	# nothing crumbling either. That is backwards exactly at the seam between
	# two adjacent CrumblingPlatforms: his centre ray drops through the gap
	# between their two collision boxes, finds nothing, and used to read that
	# as ground he could bank on — so walking from one onto the other banked a
	# pending lemon without his feet ever finding brick. This walks the whole
	# span and checks every frame, since the miss can land anywhere along it,
	# not necessarily at the midpoint either test would think to sample.
	Collectibles.reset()
	world = Screen.load_scene("res://ldtk/Act1World.tscn")
	await _frames(60)
	p = world.player
	p.input_locked = false
	ground_y = p.global_position.y

	var seam_y := ground_y - 40.0
	var plat_a: CrumblingPlatform = CRUMBLING_PLATFORM.instantiate()
	plat_a.size = Vector2(32, 8)
	plat_a.position = Vector2(p.global_position.x - 16.0, seam_y)
	world.add_child(plat_a)
	var plat_b: CrumblingPlatform = CRUMBLING_PLATFORM.instantiate()
	plat_b.size = Vector2(32, 8)
	plat_b.position = Vector2(p.global_position.x + 16.0, seam_y)
	world.add_child(plat_b)
	await _frames(2)

	var seam_lemon: Lemon = LEMON.instantiate()
	seam_lemon.position = Vector2(plat_a.position.x, seam_y - 20.0)
	world.add_child(seam_lemon)
	await _frames(5)

	# Arm mid-air, then let him fall and settle onto the first platform.
	p.global_position = seam_lemon.global_position
	await _frames(3)
	_check(seam_lemon._pending, "SEAM: armed mid-air, above the first platform")
	var settled := false
	for i in 60:
		await _frames(1)
		if p.is_on_floor():
			settled = true
			break
	_check(settled, "SEAM: falls and settles on the first platform")
	_check(Collectibles.total == 0,
		"SEAM: not banked on landing  [%d]" % Collectibles.total)

	# Walk him across onto the second platform, checking EVERY physics frame.
	var start_x := p.global_position.x
	Input.action_press("move_right")
	var banked_early := false
	for i in 180:
		await _frames(1)
		if Collectibles.total != 0:
			banked_early = true
			break
		if p.global_position.x >= plat_b.position.x:
			break
	Input.action_release("move_right")
	_check(not banked_early,
		"SEAM: crossing onto the second platform never banks it early")
	_check(seam_lemon._pending, "SEAM: still pending after the crossing")
	_check(p.global_position.x > start_x + 16.0 and p.is_on_floor(),
		"SEAM: ...and he actually made the crossing  [x %.1f -> %.1f]"
			% [start_x, p.global_position.x])

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
## The "+N" tag, if one is up. It belongs to Points now, not to Collectibles:
## the fruit count and the score are separate numbers with separate owners, and
## the tag is the score's.
func _popup_tag() -> Control:
	var hud: CanvasLayer = Points.get_node_or_null("PointsHud")
	if hud == null:
		return null
	return hud.get_node_or_null("PointsTag") as Control


func _tokens_on_surface() -> Array[Node]:
	var found: Array[Node] = []
	if Screen.token_viewport == null:
		return found
	for child in Screen.token_viewport.get_children():
		if child is AnimatedSprite2D:
			found.append(child)
	return found
