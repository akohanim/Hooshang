class_name Lemon
extends Area2D
## A collectable lemon — the game's "coin". Placed by hand in LDtk and
## turned into this node by scripts/ldtk_entities_post_import.gd.
##
## CELESTE STRAWBERRY RULE: touching the fruit only ARMS it (pending). The real
## collect fires on the first frame the player is back on the ground. A death
## while pending UN-ARMS it and puts it right back where it was — art, glow, bob
## and trigger — exactly as if it had never been touched. The point: grabbing a
## collectible mid-air over a pit should not pay out if the jump was a mistake.
##
## "The ground" means SOLID ground — Player.is_on_solid_ground(), not plain
## is_on_floor(). A CrumblingPlatform is a floor for movement purposes but is
## about to disappear out from under him, so landing on one keeps a fruit
## pending instead of banking it; only touching real ground (after the panel
## has dropped him, or by walking off it) pays it out.
##
## ROOM TRANSITION WHILE PENDING: the pending state CARRIES across room
## boundaries. All LDtk rooms live as children of the same world node, so the
## lemon stays in the tree and _physics_process keeps polling. The fruit banks
## when the player next touches ground, whether that is in the same room or the
## next one. If the player dies before landing, the lemon restores in its
## original room. A pending lemon is therefore NOT in Collectibles' taken set
## when a room-transition autosave fires — collect() has not been called yet.
##
## It only knows how to be picked up and look alive; the running total lives in
## the Collectibles autoload, so the count survives room changes, deaths and
## Act -> Act scene loads (STYLE_GUIDE §5: cross-level state is an autoload).
##
## Physics: layer 4 "triggers", masking the player ONLY — the same rule every
## other trigger follows, so a future enemy can never vacuum up the fruit.
##
## WHERE IT IS DRAWN. The fruit is a TOKEN, and tokens are drawn on Screen's
## high-density surface rather than in the world (see systems/screen.gd). The
## trigger, the light and the bob all stay here in the world; only the picture
## moves. A world sprite can never be finer than the 320x180 the world is
## rasterised at, and this fruit is meant to be looked at.
##
## The token surface uses the same world coordinates, so the copy over there
## just mirrors this node's sprite each frame — one line, and nothing about the
## pickup or the flight to the counter changes.

## Bob height in px, and how long one up-down cycle takes.
@export var bob_height := 2.0
@export var bob_time := 1.6
## How fast the fruit clears the world on pickup. Short: the flourish itself is
## the flight to the counter, which Collectibles stages on the HUD layer, and a
## slow fade here would leave two lemons on screen at once.
@export var pop_time := 0.1
## Small warm light so the fruit is findable in the dark rooms. 0 disables it.
@export var light_energy := 0.55

## Frames drawn at Screen.TOKEN_DENSITY x, for the token surface.
const DENSE_FRAMES := preload("res://assets/props/lemon/dense/lemon_frames.tres")

var _taken := false
## Armed but not yet banked. True between touching the fruit and the first frame
## the player is back on the ground. A death clears it and restores the prop.
var _pending := false
## After a death restores the fruit, re-arming is blocked until the area is
## observed CLEAR of the player. Without this, the respawning player falling back
## through the fruit's position re-arms it and banks on landing — which hands you
## the berry you just died holding, exactly what the strawberry rule exists to
## prevent (a checkpoint near a grabbed berry would otherwise auto-regrant it).
## Cleared in _physics_process the first frame no player overlaps, so a fresh,
## deliberate touch after the player has moved off arms it again.
var _block_rearm := false
## Who touched the fruit. Stored so _physics_process can check is_on_floor()
## without hunting for a player, and so the died signal has a connection to drop.
var _player: Player
## collect_id() at placement — stable even while the sprite follows the player,
## because the Area2D node itself never moves.
var _cached_id: String
## The bob tween, stored so it can be killed on arm and restarted on restore.
var _bob: Tween
## The copy on the token surface, if there is one. Null means no Screen (a test
## that built the world by hand), and then the world sprite is shown instead.
var _token: AnimatedSprite2D

@onready var _sprite: AnimatedSprite2D = $Sprite


func _ready() -> void:
	add_to_group("lemon")
	collision_layer = 8  # layer 4 "triggers"
	collision_mask = 2   # player only
	body_entered.connect(_on_body_entered)

	# Cache before anything can move the node.
	_cached_id = _compute_collect_id()

	# Already picked up on a previous visit to this room (or a re-run of the
	# world)? Then it should not be here at all.
	if Collectibles.is_taken(_cached_id):
		queue_free()
		return

	_sprite.play("spin")
	_make_token()
	_start_bob()
	if light_energy <= 0.0 and has_node("Glow"):
		$Glow.queue_free()
	elif has_node("Glow"):
		$Glow.energy = light_energy


## Hand the picture to the token surface, and hide the world one.
##
## Scaled by 1/density under a density-times zoom, which nets out to the same
## world footprint the 20px sprite had — Godot's zoom scales the DRAWING, not
## just the framing, so without the scale the fruit comes out twice the size of
## everything around it.
func _make_token() -> void:
	var copy := AnimatedSprite2D.new()
	copy.sprite_frames = DENSE_FRAMES
	copy.animation = "spin"
	copy.scale = Vector2.ONE / float(Screen.TOKEN_DENSITY)
	copy.global_position = _sprite.global_position
	if not Screen.add_token(copy):
		copy.free()          # no token surface: the world sprite stays visible
		return
	copy.play("spin")
	_token = copy
	_sprite.visible = false


## Start or restart the bob animation. Kills any running bob first and resets
## the sprite to local zero so the loop starts from the right place.
func _start_bob() -> void:
	if _bob and _bob.is_valid():
		_bob.kill()
	_sprite.position = Vector2.ZERO
	if is_zero_approx(bob_height):
		return
	_bob = create_tween().set_loops()
	_bob.tween_property(_sprite, "position:y", -bob_height, bob_time * 0.5) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_bob.tween_property(_sprite, "position:y", 0.0, bob_time * 0.5) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


## Keep the copy where the real fruit is — including the bob, which is tweened
## on the world sprite and read from it here rather than being run twice.
## While pending, the sprite follows the player so the fruit trails behind.
func _process(delta: float) -> void:
	if _pending and _player != null and is_instance_valid(_player):
		var target := _player.global_position + Vector2(0, -14)
		_sprite.global_position = _sprite.global_position.lerp(target,
			clampf(15.0 * delta, 0.0, 1.0))
	if _token != null and is_instance_valid(_token):
		_token.global_position = _sprite.global_position
		_token.modulate = _sprite.modulate * modulate


## The landing check: while a fruit is pending, poll the player every physics
## frame and bank the moment they are back on the ground.
func _physics_process(_delta: float) -> void:
	# Lift the post-death re-arm block once the area is genuinely clear of the
	# player. Gated on `monitoring` so the deferred re-enable from _restore has
	# taken effect and the overlap set is current — otherwise the very first
	# frame reads empty and clears the block while the respawn is still passing
	# through. Once cleared, a deliberate re-touch arms the fruit normally.
	if _block_rearm and monitoring and not _player_overlaps():
		_block_rearm = false
	if not _pending or _player == null or not is_instance_valid(_player):
		return
	if _player.is_on_solid_ground():
		_bank()


func _exit_tree() -> void:
	# A pending lemon leaving the tree is NOT banked — the world is being torn
	# down (back to the title screen, or a full scene change) and the fruit was
	# never earned. Disconnect so the player's died signal does not fire into a
	# freed node, and nothing in Collectibles is left half-collected because
	# collect() was never called.
	_disconnect_player()
	if _token != null and is_instance_valid(_token):
		_token.queue_free()


## Stable identity for "this particular fruit", so reloading the world cannot
## hand out the same one twice. World position is unique within an Act and is
## fixed by the LDtk placement, which makes it a better key than any runtime id.
## Uses a cached value so the id is stable even while the sprite follows the
## player — the Area2D node itself never moves.
func collect_id() -> String:
	if _cached_id != "":
		return _cached_id
	return _compute_collect_id()


func _compute_collect_id() -> String:
	return "%s@%d,%d" % [Collectibles.world_key(),
		roundi(global_position.x), roundi(global_position.y)]


func _on_body_entered(body: Node2D) -> void:
	if _taken or _pending or _block_rearm or body is not Player:
		return
	# --- ARM, do not bank. ---------------------------------------------------
	# Collectibles.collect() is deferred to _bank(), which fires the first frame
	# the player is on the floor. Everything that used to happen on contact — the
	# flight animation, the Points "+N" tag, the total bump — happens there
	# instead, so a lemon grabbed mid-air over a pit does not pay out for a
	# failed jump.
	_pending = true
	_player = body
	_player.died.connect(_on_player_died_pending)
	set_deferred("monitoring", false)

	# Kill the bob — the fruit is leaving its pedestal.
	if _bob and _bob.is_valid():
		_bob.kill()
	# Dim the glow immediately; the sprite will start following the player in
	# _process on the next frame.
	if has_node("Glow"):
		$Glow.energy = 0.0


## The player landed while carrying this fruit — award it.
func _bank() -> void:
	_pending = false
	_taken = true
	_disconnect_player()
	# Pass the PLAYER as the source: the flight animation starts from where the
	# player (and therefore the lemon's sprite, which has been following them) is,
	# not from the node's original placement position.
	Collectibles.collect(_cached_id, 1,
		_player if _player != null and is_instance_valid(_player) else null)
	_player = null

	# Clear out — same as the old immediate-collect path.
	var t := create_tween().set_parallel()
	t.tween_property(self, "modulate:a", 0.0, pop_time)
	if has_node("Glow"):
		t.tween_property($Glow, "energy", 0.0, pop_time)
	await t.finished
	queue_free()


## The player died with this fruit armed — put it back as if nothing happened.
func _on_player_died_pending() -> void:
	if not _pending:
		return
	_pending = false
	_disconnect_player()
	_player = null
	_restore()


## Put everything back the way _ready left it: art, glow, bob loop, and the
## trigger re-armed so the player can collect it on the next attempt.
func _restore() -> void:
	_sprite.position = Vector2.ZERO
	modulate.a = 1.0
	# Deferred: if body_entered and died fire in the same physics step (the
	# player touches both a lemon and a hazard on the same frame), the arm's
	# deferred monitoring=false is still queued. Setting monitoring=true directly
	# here would be overridden by that pending deferred. Both deferred, FIFO
	# order guarantees the restore wins.
	set_deferred("monitoring", true)
	# Block re-arming until the player has cleared the area — see _block_rearm.
	# The respawn can drop the player straight back through where the fruit hangs,
	# and without this that pass-through would re-arm and re-bank the very fruit
	# the death was supposed to return.
	_block_rearm = true
	_start_bob()
	if has_node("Glow") and light_energy > 0.0:
		$Glow.energy = light_energy


## Is the player currently inside the trigger? Used to lift the re-arm block once
## the respawn has carried them clear of the fruit.
func _player_overlaps() -> bool:
	for body in get_overlapping_bodies():
		if body is Player:
			return true
	return false


func _disconnect_player() -> void:
	if _player != null and is_instance_valid(_player) \
			and _player.died.is_connected(_on_player_died_pending):
		_player.died.disconnect(_on_player_died_pending)
