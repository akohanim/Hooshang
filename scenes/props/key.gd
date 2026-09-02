class_name Key
extends Area2D
## One of Act 2's four quest keys. Placed by hand in LDtk and turned into this
## node by scripts/ldtk_entities_post_import.gd.
##
## CARRY-AND-DELIVER, not touch-to-collect. Touching the key only PICKS IT UP —
## it attaches to the player, hovering near them (above the head) at
## `carry_scale`, and follows for as long as it is carried. Act2Quest.collect()
## does NOT fire at that point. Every physics frame while carried, the distance
## from the player to the nearest node in the "jamshid_cage" group is checked;
## dropping under `deliver_radius` is DELIVERY — the moment Act2Quest.collect()
## actually fires (which is what JamshidCage listens for) — followed by a short
## flourish toward the cage and the prop freeing itself.
##
## Mirrors Lemon's CELESTE STRAWBERRY RULE for its own carried/"pending" window:
## a death while carrying an undelivered key restores it — position, scale,
## trigger — exactly as if it had never been touched. Since Act2Quest.collect()
## has not fired yet at that point, nothing needs to be un-banked; see
## lemon.gd's _pending/_on_player_died_pending/_restore for the shape this
## follows (the same reason this connects to Player.died and is careful to
## disconnect it again, both on restore and on delivery).
##
## Multiple keys can be carried at once (there are 4 in the world). `_carried`
## is a class-level list of every key currently being carried, in pickup
## order — used to stagger simultaneously-carried keys into a small fan so
## they read as distinct rather than stacked exactly on top of each other.
##
## Only the SPRITE travels while carried, the same trick Lemon uses for its own
## pending fruit: the Area2D root (and its collision shape) stays exactly where
## it was placed the whole time — monitoring is off during the carry anyway, so
## nothing needs it to move, and it means `_restore()` never has to remember or
## reapply a placement position.
##
## Physics: layer 4 "triggers", masking the player only — the same rule every
## other trigger in the project follows.

## Which of the four keys this is. Set from LDtk's KeyID field
## (tools/ldtk_add_key.py); Act2Quest tracks collection by this id, so two
## keys placed with the same id would count as the same key — a level-author
## mistake this node cannot see, the same way two Lemons placed on the exact
## same cell would collide on Collectibles' own position-derived id.
@export var key_id: String = ""

## Idle bob height/time (before pickup) and delivery-flourish time — same
## shape as Lemon's own exports.
@export var bob_height := 2.0
@export var bob_time := 1.4
@export var pop_time := 0.12

## How close (px), player to nearest JamshidCage, counts as delivered.
@export var deliver_radius := 50.0

## How small the key is drawn while carried — visibly smaller than its resting
## size so it reads as "picked up", not "still sitting there".
@export var carry_scale := 0.65

## Where the key hovers relative to the player while carried, before the
## per-carry stagger offset (see _carry_offset) is added. Above the head.
@export var carry_hover := Vector2(0, -14)

@onready var _sprite: Sprite2D = $Sprite

## Every Key currently carried, in pickup order — used to fan out
## simultaneously-carried keys instead of overlapping them. Class-level: keys
## are separate node instances that otherwise have no way to see each other.
static var _carried: Array[Key] = []

## Final state: delivered and on the way out. Guards against a stray
## body_entered or a second delivery reaching an already-freed key.
var _delivered := false
## Picked up but not yet delivered — following the player.
var _carrying := false
## Who is carrying it. Stored so _physics_process can measure the distance to
## a cage without hunting for a player, and so the died signal has a
## connection to drop.
var _player: Player
var _bob: Tween


func _ready() -> void:
	add_to_group("key")
	collision_layer = 8  # layer 4 "triggers"
	collision_mask = 2   # player only
	body_entered.connect(_on_body_entered)

	# Already delivered on a previous visit to this room (or a re-run of the
	# world)? Then it should not be here at all.
	if Act2Quest.is_taken(key_id):
		queue_free()
		return

	_start_bob()


func _start_bob() -> void:
	if _sprite == null or is_zero_approx(bob_height):
		return
	_bob = create_tween().set_loops()
	_bob.tween_property(_sprite, "position:y", -bob_height, bob_time * 0.5) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_bob.tween_property(_sprite, "position:y", 0.0, bob_time * 0.5) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func _on_body_entered(body: Node2D) -> void:
	if _carrying or _delivered or body is not Player:
		return
	# --- PICK UP, do not bank. ------------------------------------------------
	# Act2Quest.collect() is deferred to _deliver(), which fires the first
	# physics frame the player is within deliver_radius of a JamshidCage.
	_carrying = true
	_player = body
	_player.died.connect(_on_player_died_carrying)
	set_deferred("monitoring", false)

	# Kill the bob — the key is leaving its pedestal — and shrink it to its
	# carried size.
	if _bob != null and _bob.is_valid():
		_bob.kill()
	_sprite.position = Vector2.ZERO
	_sprite.scale = Vector2.ONE * carry_scale
	_carried.append(self)


## Follow the player. Only the sprite moves — see the class doc for why.
func _process(delta: float) -> void:
	if not _carrying or _player == null or not is_instance_valid(_player):
		return
	var target := _player.global_position + carry_hover + _carry_offset()
	_sprite.global_position = _sprite.global_position.lerp(
		target, clampf(15.0 * delta, 0.0, 1.0))


## The delivery check: while carried, poll the player's distance to the
## nearest cage every physics frame and deliver the moment it is close enough.
func _physics_process(_delta: float) -> void:
	if not _carrying or _delivered:
		return
	if _player == null or not is_instance_valid(_player):
		return
	var cage := _nearest_cage(_player.global_position)
	if cage != null \
			and _player.global_position.distance_to(cage.global_position) <= deliver_radius:
		_deliver()


func _exit_tree() -> void:
	# A carried key leaving the tree without being delivered is NOT banked —
	# see lemon.gd's own _exit_tree note, same reasoning. Disconnect so the
	# player's died signal does not fire into a freed node.
	_disconnect_player()
	_carried.erase(self)


## Fan-out offset for this key among every key currently carried, ordered by
## pickup — so 2-3 simultaneously-carried keys are visibly distinct instead of
## sitting exactly on top of one another.
func _carry_offset() -> Vector2:
	var idx := _carried.find(self)
	if idx < 0:
		return Vector2.ZERO
	var total := _carried.size()
	var mid := (total - 1) / 2.0
	var d := idx - mid
	return Vector2(d * 7.0, -absf(d) * 3.0)


## The nearest "jamshid_cage" node to `from`, or null if there is none in the
## tree (a test world with no cage, say).
func _nearest_cage(from: Vector2) -> Node2D:
	var best: Node2D = null
	var best_dist := INF
	for node in get_tree().get_nodes_in_group("jamshid_cage"):
		if node is Node2D:
			var d: float = from.distance_to((node as Node2D).global_position)
			if d < best_dist:
				best_dist = d
				best = node
	return best


## The carried key reached a JamshidCage — bank it for real and play the
## flourish (fly to the cage, shrink further, fade), then free.
func _deliver() -> void:
	_delivered = true
	_carrying = false
	_carried.erase(self)
	_disconnect_player()
	_player = null
	set_deferred("monitoring", false)
	Act2Quest.collect(key_id)

	var cage := _nearest_cage(_sprite.global_position)
	var t := create_tween().set_parallel()
	if cage != null:
		t.tween_property(_sprite, "global_position", cage.global_position, pop_time) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	t.tween_property(_sprite, "scale", _sprite.scale * 0.4, pop_time)
	t.tween_property(self, "modulate:a", 0.0, pop_time)
	await t.finished
	queue_free()


## The player died while carrying this key — put it back as if nothing
## happened. Act2Quest.collect() never fired, so there is nothing to un-bank;
## just undo the pickup.
func _on_player_died_carrying() -> void:
	if not _carrying:
		return
	_carrying = false
	_carried.erase(self)
	_disconnect_player()
	_player = null
	_restore()


## Put the sprite back the way _ready left it and re-arm the trigger. The
## Area2D root never moved (see class doc), so there is no position to restore.
func _restore() -> void:
	_sprite.position = Vector2.ZERO
	_sprite.scale = Vector2.ONE
	modulate.a = 1.0
	set_deferred("monitoring", true)
	_start_bob()


func _disconnect_player() -> void:
	if _player != null and is_instance_valid(_player) \
			and _player.died.is_connected(_on_player_died_carrying):
		_player.died.disconnect(_on_player_died_carrying)
