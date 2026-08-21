@tool
class_name CrumblingPlatform
extends Platform
## A ceiling panel that has already given up: stand on it and it goes.
##
## It arms the instant he is on top of it, not when he next touches its edge —
## see `_try_arm`.
##
## Timeline, once he first stands on it — `crumble_time` total, under a second by
## design, so it is a thing you cross rather than a thing you wait on:
##
##   0                 crumble_time        + fall_time
##   |-- frames 0,1,2 --|-- collision off --|-- gone
##      cracking, shaking      it drops and fades
##
## It comes BACK. Every one of these resets when the player respawns and when a
## room is entered (LdtkWorld calls reset_all), so a room is always the room you
## first walked into — dying to a gap you made unusable on your last attempt is
## the kind of thing that turns a retry loop into a restart loop. Resetting the
## LEVEL from the menu reloads the world outright, so that path needs nothing.
##
## WHY THERE IS A SKIN. A StaticBody2D emits no contact signals, so it cannot
## know he is on it; the Area2D standing proud of the box is how NoteTile solves
## the same problem, for the same reason. It answers "is he against me", and
## `_standing_on` narrows that to "is he on top of me" — a platform that crumbles
## when you brush its underside is a bug you only find in a shaft.

## How far the detection skin stands proud of the solid box.
const SKIN := 2.0
const FRAMES := [
	preload("res://assets/props/platform/crumble_0.png"),
	preload("res://assets/props/platform/crumble_1.png"),
	preload("res://assets/props/platform/crumble_2.png"),
]

## How long from first footfall to the floor going away. Under a second, and the
## three damage frames are spread across it.
@export var crumble_time := 0.75
## How long the wreckage takes to fall out of sight afterwards.
@export var fall_time := 0.5
## How far it drops while falling.
@export var fall_distance := 40.0
## How hard it shakes while it is going, in px.
@export var shudder := 0.6

var _skin: Area2D
var _skin_shape: CollisionShape2D
## Armed once, by the first footfall. Cleared only by reset().
var _spent := false
## Set by reset() so a panel restored UNDER a standing player does not arm on
## the spot. Polling every frame (see `_try_arm`) otherwise loses the one
## guarantee `body_entered` gave for free: that arming needs a fresh entry. He
## has to be clear of the skin once before it will count him again — which
## costs nothing on a real landing, because he was outside it a frame earlier.
var _needs_clear := false
var _timer := 0.0
var _falling := false
var _fall_tween: Tween


func _ready() -> void:
	super()
	add_to_group("crumbling")
	set_process(not Engine.is_editor_hint())


func _after_rebuild() -> void:
	if _skin == null:
		_skin = Area2D.new()
		_skin.name = "Skin"
		# Layer 4 "triggers", masking the player only — the rule every other
		# trigger in the project follows.
		_skin.collision_layer = 8
		_skin.collision_mask = 2
		_skin_shape = CollisionShape2D.new()
		_skin_shape.shape = RectangleShape2D.new()
		_skin.add_child(_skin_shape)
		add_child(_skin)
		_skin.body_entered.connect(_on_touched)
	(_skin_shape.shape as RectangleShape2D).size = size + Vector2(SKIN, SKIN) * 2.0
	# Centred, like the solid box it wraps — see platform.gd._rebuild.
	_skin_shape.position = Vector2.ZERO
	_apply_frame(0)


## Frames are swapped on every tile at once, so the whole panel cracks together.
func _apply_frame(i: int) -> void:
	if _visual == null:
		return
	var tex: Texture2D = FRAMES[clampi(i, 0, FRAMES.size() - 1)]
	for child in _visual.get_children():
		if child is Sprite2D:
			(child as Sprite2D).texture = tex


func _on_touched(body: Node2D) -> void:
	_try_arm(body)


## Start the countdown, if this body is a player and he is on top right now.
##
## Reached from TWO directions, and it needs both. `body_entered` is the fast
## path — a clean landing arms on the very frame he touches down. But that
## signal fires once per entry, and `_standing_on` can perfectly well be false
## at that instant: he rises into the skin from below, or clips its end while
## moving upward. Nothing fires again once he is inside, so a signal-only
## version leaves him standing on a panel that has decided it was never landed
## on. `_process` therefore re-asks the same question every frame until it is
## armed, which is what makes "as soon as he stands on top" true regardless of
## how he got there.
func _try_arm(body: Node2D) -> void:
	if _spent or _falling or _needs_clear or Engine.is_editor_hint() or body is not Player:
		return
	if not _standing_on(body as Player):
		return
	_spent = true
	_timer = 0.0


## Every player currently inside the detection skin — usually none or one.
func _players_on_skin() -> Array[Player]:
	var found: Array[Player] = []
	if _skin == null:
		return found
	for body in _skin.get_overlapping_bodies():
		if body is Player:
			found.append(body as Player)
	return found


## On TOP of it, not merely touching it. His feet have to be at the platform's
## own surface, within the slack the skin adds — anything else is a head-butt
## from underneath or a brush past the end.
func _standing_on(who: Player) -> bool:
	var feet := who.global_position.y + Player.HALF_HEIGHT
	return feet <= top_y() + SKIN * 2.0 and who.velocity.y >= 0.0


func _process(delta: float) -> void:
	if _falling:
		return
	if not _spent:
		var players := _players_on_skin()
		if _needs_clear:
			# Nothing to be clear of any more — the next entry counts.
			if players.is_empty():
				_needs_clear = false
			return
		for who in players:
			_try_arm(who)
		if not _spent:
			return
	_timer += delta
	var t := clampf(_timer / maxf(crumble_time, 0.01), 0.0, 1.0)
	_apply_frame(int(t * FRAMES.size()))
	if _visual != null:
		# Shakes harder the closer it is to going, so the warning is legible
		# without a sound cue.
		var k := shudder * t
		_visual.position = Vector2(randf_range(-k, k), randf_range(-k, k))
	if t >= 1.0:
		_drop()


## The floor goes away, and the wreckage falls after it. Collision first, so
## nothing depends on how long the animation takes.
func _drop() -> void:
	_falling = true
	set_collision_layer_value(1, false)
	if _visual == null:
		return
	_visual.position = Vector2.ZERO
	_fall_tween = create_tween().set_parallel()
	_fall_tween.tween_property(_visual, "position:y", fall_distance, fall_time) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_fall_tween.tween_property(_visual, "modulate:a", 0.0, fall_time) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)


## Take this panel away on purpose, `after` seconds from now.
##
## The tutorial needs the floor to GO at a chosen moment rather than whenever he
## happens to have stood on something long enough — with a relaxed timer he can
## simply walk the whole run and never learn anything. Routed through the same
## countdown the footfall uses, so a forced collapse cracks and shudders exactly
## like an earned one; only the moment it starts is different.
func give_way(after := 0.0) -> void:
	if _spent or _falling:
		return
	_spent = true
	_timer = maxf(crumble_time - maxf(after, 0.0), 0.0)


## Put it back exactly as it was placed.
func reset() -> void:
	# The fall tween FIRST. It owns position and alpha for fall_time seconds, so
	# a reset that only assigns them is overwritten on the next frame and the
	# platform sinks away again while solid — which is how this was caught: the
	# collision came back, he could stand on it, and it was invisible.
	if _fall_tween != null and _fall_tween.is_valid():
		_fall_tween.kill()
	_spent = false
	_falling = false
	_timer = 0.0
	# If he is inside the skin right now — he just fell through this panel, or a
	# respawn put him on it — make him leave before it can arm again.
	_needs_clear = not _players_on_skin().is_empty()
	set_collision_layer_value(1, true)
	if _visual != null:
		_visual.position = Vector2.ZERO
		_visual.modulate.a = 1.0
	_apply_frame(0)


## Reset every crumbling platform in the tree.
##
## A static helper on the class rather than a loop written out at each call site:
## LdtkWorld calls it from two places (a respawn and a room entry) and LevelBase
## would be a third, and a group name copied into three files is a group name
## that gets renamed in two of them.
static func reset_all(tree: SceneTree) -> void:
	for node in tree.get_nodes_in_group("crumbling"):
		if node is CrumblingPlatform:
			(node as CrumblingPlatform).reset()
