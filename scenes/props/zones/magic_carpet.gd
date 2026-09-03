@tool
class_name MagicCarpet
extends Area2D
## A rideable moving platform: stand on it and it carries you, the same
## "carries a rider, lets go the instant they're airborne" contract
## conveyor_belt.gd documents and proves (layer 4 trigger, mask the player
## only, process_physics_priority AFTER the player's own move_and_slide, the
## surface is MOVED rather than his velocity written).
##
## GENERALIZES THE BELT'S TRICK TO 2D. A belt moves nothing itself — it stays
## put and displaces the RIDER by `drift() * delta` every frame. A carpet has
## to move itself too (it is the platform doing the flying), so instead this
## computes its own planned displacement for the frame from `pattern`, moves
## ITSELF by it, and then move_and_collide()s every current rider by that same
## vector. One code path covers both the carpet's own autonomous motion and a
## rider steering it — the rider is just along for whatever displacement the
## carpet decided on this frame, exactly the way ConveyorBelt's rider is along
## for whatever the belt decided.
##
## ONE ENTITY WITH A PATTERN FIELD, not four entities — same call as
## DarkThought.Motion: which pattern is chosen is a thing two placed carpets
## can legitimately disagree about, and a carpet whose Pattern nobody set
## still visibly does something (RIDE, the default) rather than silently being
## an unused fourth entity type. Each pattern gets its own rug art
## (tools/gen_magic_carpet.py) so the function reads from the art, not a
## tooltip — the same rule this project's other hazards already follow.
##
## Position is recomputed from `_clock` every frame for the autonomous
## patterns (BOB/SWEEP/BOUNCE), never integrated — same reasoning
## dark_thought.gd's _process gives: a velocity added up frame to frame drifts,
## and a repeating path that does not actually repeat is a path a room cannot
## be built around. RIDE's vertical steering is the one genuinely stateful
## piece here (it depends on live input history, not just elapsed time), kept
## in `_steer_y` and clamped to `steer_range`.

enum CarpetPattern {
	RIDE,    ## Default: drifts right at `speed`; a rider steers it vertically.
	BOB,     ## Autonomous vertical sine around its placed point.
	SWEEP,   ## Autonomous horizontal sine around its placed point.
	BOUNCE,  ## Drifts right at `speed` while pulsing in a springy vertical hop.
}

const TILES := {
	CarpetPattern.RIDE: preload("res://assets/props/magic_carpet/ride.png"),
	CarpetPattern.BOB: preload("res://assets/props/magic_carpet/bob.png"),
	CarpetPattern.SWEEP: preload("res://assets/props/magic_carpet/sweep.png"),
	CarpetPattern.BOUNCE: preload("res://assets/props/magic_carpet/bounce.png"),
}
const TILE := Vector2(16.0, 8.0)

## Full size of the carpet in pixels. LDtk sets this from the box dragged in
## the editor; the carpet is one cell tall and stretches sideways, matching
## Platform/ConveyorBelt's own convention.
@export var size := Vector2(32.0, 8.0):
	set(value):
		size = value
		_update_extents()

## Which path it flies. See the CarpetPattern doc above.
@export var pattern: CarpetPattern = CarpetPattern.RIDE:
	set(value):
		pattern = value
		_rebuild_visual()

## RIDE/BOUNCE: how fast it drifts right, px/s. BOB/SWEEP: 0 by default (a
## stationary lift / sweep); set it above 0 to also drift while oscillating.
@export var speed := 40.0
## BOB/SWEEP/BOUNCE: how far the oscillation swings — half the travel either
## side of the placed point for BOB/SWEEP, or the pulse height for BOUNCE.
@export var amplitude := 20.0
## BOB/SWEEP/BOUNCE: full cycles per second.
@export var cycle_speed := 0.4
## Where in the cycle it starts, 0..1 — same job as DarkThought.phase: two
## carpets in one room should be able to disagree about where they start.
@export var phase := 0.0
## RIDE only: how far a rider may steer it, in px, above or below its placed y.
@export var steer_range := 20.0
## RIDE only: how fast up/down input moves it, px/s.
@export var steer_speed := 36.0
## How far ABOVE the drawn box a body still counts as riding — same job as
## ConveyorBelt.rider_reach, same default (the player's hitbox height).
@export var rider_reach := 12.0

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
var _clock := 0.0
## RIDE only: accumulated vertical steer offset from `_origin`, clamped to
## +/- steer_range.
var _steer_y := 0.0


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
	_clock += delta
	var old_pos := position
	position = _origin + _offset(delta)
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
## the time this runs, `position = _origin + _offset(delta)` has already
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


## Where the carpet sits relative to `_origin`, this frame. RIDE/BOUNCE drift
## right without bound (a level places one only as long as the room needs it
## to travel, same as ConveyorBelt places no bound of its own on how far a
## belt runs); BOB/SWEEP orbit the placed point and never drift away from it.
func _offset(delta: float) -> Vector2:
	var theta := TAU * (_clock * cycle_speed + phase)
	match pattern:
		CarpetPattern.BOB:
			return Vector2(speed * _clock, sin(theta) * amplitude)
		CarpetPattern.SWEEP:
			return Vector2(sin(theta) * amplitude, 0.0)
		CarpetPattern.BOUNCE:
			return Vector2(speed * _clock, -absf(sin(theta)) * amplitude)
		_:  # RIDE
			var steer := 0.0
			if not riders.is_empty() and not Engine.is_editor_hint():
				steer = Input.get_axis("move_up", "move_down")
			_steer_y = clampf(_steer_y + steer * steer_speed * delta,
				-steer_range, steer_range)
			return Vector2(speed * _clock, _steer_y)


## Hand the carpet's current horizontal drift over as real velocity the frame
## a rider LEAVES it in mid-air — same reasoning and same shape as
## ConveyorBelt._settle_launch, simplified: no "jumping with it" bonus, and
## HORIZONTAL ONLY (a deliberate scope limit — a vertical launch bonus off a
## bobbing or bouncing carpet is a feel decision, not a mechanical
## requirement, and player-feel tuning is out of scope for this task).
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
	_clock = 0.0
	_steer_y = 0.0
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
	var tex: Texture2D = TILES[pattern]
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
