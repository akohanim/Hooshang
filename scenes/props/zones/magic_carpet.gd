@tool
class_name MagicCarpet
extends Area2D
## A rideable moving platform: waits at its placed point until a real top
## landing activates it. After dismounting, it flies on for five seconds
## before returning to its parked origin; boarding again cancels that return.
## Stand on it and it carries you, the same
## "carries a rider, lets go the instant they're airborne" contract
## conveyor_belt.gd documents and proves (layer 4 trigger, mask the player
## only, process_physics_priority AFTER the player's own move_and_slide, the
## surface is MOVED rather than his velocity written).
##
## GENERALIZES THE BELT'S TRICK TO 2D. A belt moves nothing itself — it stays
## put and displaces the RIDER by `drift() * delta` every frame. A carpet has
## to move itself too (it is the platform doing the flying), so instead this
## computes its own planned displacement from flight speed and input, moves
## ITSELF by it, and then move_and_collide()s every current rider by that same
## vector. One code path covers both the carpet's own autonomous motion and a
## rider steering it — the rider is just along for whatever displacement the
## carpet decided on this frame, exactly the way ConveyorBelt's rider is along
## for whatever the belt decided.
##
## All colors share the same ride: forward drift and unrestricted vertical
## steering, stopped by room edges and solid geometry (including rider clearance).
enum CarpetPattern { RIDE }
enum CarpetColor { CRIMSON, TEAL, VIOLET, AMBER }

const TILES := {
	CarpetColor.CRIMSON: preload("res://assets/props/magic_carpet/ride.png"),
	CarpetColor.TEAL: preload("res://assets/props/magic_carpet/bob.png"),
	CarpetColor.VIOLET: preload("res://assets/props/magic_carpet/sweep.png"),
	CarpetColor.AMBER: preload("res://assets/props/magic_carpet/bounce.png"),
}
const TILE := Vector2(16.0, 8.0)

## Full size of the carpet in pixels. LDtk sets this from the box dragged in
## the editor; the carpet is one cell tall and stretches sideways, matching
## Platform/ConveyorBelt's own convention.
@export var size := Vector2(32.0, 8.0):
	set(value):
		size = value
		_update_extents()

## Rug color and motif; does not change the ride controls.
@export var carpet_color: CarpetColor = CarpetColor.CRIMSON:
	set(value):
		carpet_color = value
		_rebuild_visual()

## Legacy packed scenes preserve their old artwork but always use Ride.
@export_storage var pattern: int = CarpetPattern.RIDE:
	set(value):
		if value > 0:
			carpet_color = clampi(value, 0, 3) as CarpetColor
		pattern = CarpetPattern.RIDE

## Forward flight speed in pixels per second.
@export var speed := 40.0
## Vertical steering speed in pixels per second.
@export var steer_speed := 36.0
## How far ABOVE the drawn box a body still counts as riding — same job as
## ConveyorBelt.rider_reach, same default (the player's hitbox height).
@export var rider_reach := 12.0
## Seconds of continued flight after dismounting before returning to the start.
@export_range(0.1, 30.0) var respawn_delay := 5.0

const ZONE_FLOOR_SCENE := preload("res://scenes/props/zones/ZoneFloor.tscn")

var _shape: CollisionShape2D
var _visual: Node2D
var _floor: ZoneFloor

## Bodies inside the trigger box, riding or not — same public contract
## ConveyorBelt.riders documents (a test needs to tell "not touching it" apart
## from "touching it but not being carried").
var riders: Array[Node2D] = []
## Who was being carried last frame, by instance id — same departure-detection
## trick as ConveyorBelt._riding.
var _riding := {}

var _origin := Vector2.ZERO
var _had_rider := false
## Negative means no return is pending; counts gameplay seconds while empty.
var _return_left := -1.0
## Armed by a real top landing, reset on death/room entry.
var activated := false


func _ready() -> void:
	collision_layer = 8  # layer 4 "triggers"
	collision_mask = 2   # player only
	process_physics_priority = 1  # after the player's own move_and_slide
	_origin = position
	_shape = CollisionShape2D.new()
	_shape.shape = RectangleShape2D.new()
	add_child(_shape)
	_update_extents()
	if Engine.is_editor_hint():
		set_physics_process(false)
		return
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)


## True when `body` is not merely inside the carpet's box but actually
## standing on it — same shape as ConveyorBelt.carrying(), including the same
## dash exemption (dash distance is tuned to clear specific gaps, and a carpet
## adding or subtracting its own speed mid-dash would make the same dash a
## different move depending on where the carpet happened to be).
func carrying(body: Node2D) -> bool:
	if not is_instance_valid(body) or not riders.has(body):
		return false
	if body is Player:
		var who := body as Player
		if who.state == Player.State.DEAD or who.state == Player.State.DASH:
			return false
	return body is CharacterBody2D and (body as CharacterBody2D).is_on_floor()


func _physics_process(delta: float) -> void:
	if not activated:
		# A reset/respawn can leave a body inside the same sensor, so no new
		# body_entered signal follows. Reacquire before testing its feet.
		for body in get_overlapping_bodies():
			_on_body_entered(body)
		for body in riders:
			if carrying(body) and body is Player:
				var feet: float = (body as Player).hitbox_rect().end.y
				var top := global_position.y - size.y * 0.5
				if absf(feet-top) <= 3.0 and (body as Player).velocity.y >= 0.0:
					activated = true
					var sound := get_node_or_null("FeedbackSound") as AudioStreamPlayer2D
					if sound != null:sound.play()
					break
		if not activated:
			return
	var occupied := false
	for body in riders:
		if body is Player and carrying(body):
			occupied = true
			break
	if occupied:
		_return_left = -1.0
	elif _had_rider:
		_return_left = respawn_delay
	_had_rider = occupied
	if _return_left >= 0.0:
		_return_left -= delta
		if _return_left <= 0.00001:
			reset()
			return
	var old_pos := position
	_move_flight(delta)
	var carry := position - old_pos
	for body in riders:
		var riding := carrying(body)
		if riding and not carry.is_zero_approx():
			_carry_body(body as CharacterBody2D, carry)
		_settle_launch(body, riding)


## Drag `body` along by `carry` — the exact displacement the carpet (and its
## ZoneFloor child) just gave themselves two lines up in `_physics_process`.
##
## The exception with `_floor` here is load-bearing, not a style nicety. By
## the time this runs, `_move_flight(delta)` has already
## moved ZoneFloor's Node2D transform (a child's global transform updates the
## instant a parent's `position` changes) — but the PHYSICS SERVER's own copy
## of that StaticBody2D's transform does not catch up until the NEXT physics
## step, one full frame behind. That is the exact lag CLAUDE.md's note on
## `Area2D.overlaps_body()`'s monitoring cache already documents for the
## Level_v6 return door; it shows up here too, just surfacing through
## `move_and_collide`'s motion query instead of a `body_entered` signal.
##
## So without the exception, this call tests `carry` against the FLOOR'S
## STALE, LAST-FRAME POSITION even though `carry` was sized to land the rider
## exactly on the floor's brand-new one. Steering the carpet UP never showed
## it — catching up away from a stale, lower floor collides with nothing —
## but steering DOWN (or simply releasing UP after a run of it) drives the
## rider straight into that stale collider: the motion is stopped a fraction
## of a pixel in, leaving him hanging above where the real floor now is. The
## very next frame reads him as airborne, `carrying()` goes false, and
## `_settle_launch()` fires — launching him sideways at the carpet's own
## drift speed with no jump or dash involved, which is the "shakes and
## pushes him left/right just from steering up/down" this exists to fix.
##
## Scoped to just this one call (added, then removed right after) because
## ZoneFloor must stay an entirely ordinary solid for every OTHER
## interaction — walking onto the carpet from the side, landing on it from a
## jump, the rider's own move_and_slide(). Only this specific "follow the
## floor's own displacement" move must never be blocked by the floor it is
## following.
func _carry_body(body: CharacterBody2D, carry: Vector2) -> void:
	if _floor == null:
		body.move_and_collide(carry)
		return
	body.add_collision_exception_with(_floor)
	body.move_and_collide(carry)
	body.remove_collision_exception_with(_floor)


## Move each axis separately so a wall stops forward drift without preventing
## steering away. Integrate only actual travel; a blocked move never builds up
## an offset that would later teleport the carpet through an obstacle.
func _move_flight(delta: float) -> void:
	var steer := 0.0
	var riding_bodies: Array[Player] = []
	for body in riders:
		if body is Player and carrying(body):
			riding_bodies.append(body)
			steer = body.movement_input().y
	var footprint := Rect2(global_position - size * 0.5, size)
	for body in riding_bodies:
		footprint = footprint.merge(body.hitbox_rect())
	var bounds := Rect2()
	var ancestor := get_parent()
	while ancestor != null:
		if ancestor is LDTKLevel:
			bounds = Rect2(ancestor.global_position, Vector2(ancestor.size))
			break
		ancestor = ancestor.get_parent()
	var travel := Vector2.ZERO
	for motion in [Vector2(speed * delta, 0), Vector2(0, steer * steer_speed * delta)]:
		if bounds.has_area():
			motion.x = clampf(motion.x, minf(0, bounds.position.x - footprint.position.x), maxf(0, bounds.end.x - footprint.end.x))
			motion.y = clampf(motion.y, minf(0, bounds.position.y - footprint.position.y), maxf(0, bounds.end.y - footprint.end.y))
		var fraction := _clear_fraction(Rect2(global_position - size * 0.5 + travel, size), motion)
		for body in riding_bodies:
			var box := body.hitbox_rect()
			box.position += travel
			fraction = minf(fraction, _clear_fraction(box, motion))
		motion *= fraction
		travel += motion
		footprint.position += motion
	global_position += travel


## Sweep both the rug and the rider against world solids before moving either.
## Exclude our own floor: its physics transform lags the visual by one tick.
func _clear_fraction(box: Rect2, motion: Vector2) -> float:
	if motion.is_zero_approx():
		return 1.0
	var query := PhysicsShapeQueryParameters2D.new()
	var shape := RectangleShape2D.new()
	shape.size = box.size
	query.shape = shape
	query.transform = Transform2D(0.0, box.get_center())
	query.motion = motion
	# Leave more than CharacterBody2D's default 0.08px recovery margin,
	# otherwise the next player tick depenetrates away from the carpet.
	query.margin = 0.15
	query.collision_mask = 1
	query.exclude = [_floor.get_rid()]
	return get_world_2d().direct_space_state.cast_motion(query)[0]


## Hand the carpet's current horizontal drift over as real velocity the frame
## a rider LEAVES it in mid-air — same reasoning and same shape as
## ConveyorBelt._settle_launch, simplified: no "jumping with it" bonus, and
## Only horizontal drift is inherited when jumping off.
func _settle_launch(body: Node2D, riding: bool) -> void:
	var was: bool = _riding.get(body.get_instance_id(), false)
	_riding[body.get_instance_id()] = riding
	if riding or not was:
		return
	if not is_instance_valid(body) or body is not CharacterBody2D:
		return
	var mover := body as CharacterBody2D
	if mover.is_on_floor():
		return
	if body is Player:
		var who := body as Player
		if who.state == Player.State.DEAD or who.state == Player.State.DASH:
			return
	if mover.has_method("add_momentum"):
		mover.add_momentum(speed)
	else:
		mover.velocity.x += speed


func _on_body_entered(body: Node2D) -> void:
	if not riders.has(body):
		riders.append(body)


func _on_body_exited(body: Node2D) -> void:
	riders.erase(body)
	_riding.erase(body.get_instance_id())


## Put it back at the start of its cycle, at its placed point — same reasoning
## as DarkThought.reset(): a room is restored per visit, so a retry finds every
## moving carpet at the start of its cycle rather than whichever phase the
## clock happened to be at, and RIDE's drift starts back at zero instead of
## wherever it had travelled to.
func reset() -> void:
	_had_rider = false
	_return_left = -1.0
	activated = false
	position = _origin
	riders.clear()
	_riding.clear()


## Reset every magic carpet in the tree — same static-helper pattern
## CrumblingPlatform.reset_all/DarkThought.reset_all/MysteryBox.reset_all use,
## for the same reason: LdtkWorld calls this from a respawn and a room entry,
## and a group name copied into two files is a group name that gets renamed in
## one of them.
static func reset_all(tree: SceneTree) -> void:
	for node in tree.get_nodes_in_group("magic_carpet"):
		if node is MagicCarpet:
			(node as MagicCarpet).reset()


## The trigger box, grown UPWARD by rider_reach — same shape as
## ConveyorBelt._update_extents.
func _update_extents() -> void:
	if _shape == null or not is_inside_tree():
		return
	var box := Vector2(maxf(size.x, 1.0), maxf(size.y, 1.0) + rider_reach)
	(_shape.shape as RectangleShape2D).size = box
	_shape.position = Vector2(0.0, -rider_reach * 0.5)
	_fit_floor()
	_rebuild_visual()
	queue_redraw()


func _fit_floor() -> void:
	if _floor == null:
		_floor = ZONE_FLOOR_SCENE.instantiate()
		_floor.name = "Floor"
		add_child(_floor)
	_floor.fit(size)


## Lay the rug tiles end to end, same technique as platform.gd's _rebuild:
## whole copies of the pattern's 16x8 tile, the last one clipped rather than
## overhung so the art never promises more carpet than the collision gives.
func _rebuild_visual() -> void:
	if not is_inside_tree():
		return
	if _visual == null:
		_visual = Node2D.new()
		_visual.name = "Visual"
		add_child(_visual)
	for child in _visual.get_children():
		child.free()
	var tex: Texture2D = TILES[carpet_color]
	var count := int(ceilf(size.x / TILE.x))
	for i in count:
		var tile := Sprite2D.new()
		tile.texture = tex
		tile.centered = false
		tile.position = Vector2(i * TILE.x, 0.0) - size * 0.5
		var over := size.x - i * TILE.x
		if over < TILE.x:
			tile.region_enabled = true
			tile.region_rect = Rect2(0.0, 0.0, over, TILE.y)
		_visual.add_child(tile)
