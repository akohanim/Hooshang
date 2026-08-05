@tool
class_name ConveyorBelt
extends Area2D
## A stretch of floor that walks. While Hooshang is STANDING on it he is carried
## along at `speed`, left or right; jumping through the same box does nothing.
## That is the whole difference between a conveyor and a wind tunnel, and it is
## the one rule worth protecting — see carrying().
##
## Not a Hazard and not a SlideZone: nothing here kills, and nothing here takes
## his footing away. He keeps all of his usual control and the belt is added on
## top of it, so walking against it just makes him slow and walking with it
## makes him fast. It lives in props/zones/ with the other
## volumes-that-do-something rather than in props/hazards/, where everything is
## lethal.
##
## WHY THE CARRY IS A MOVE, NOT A WRITE TO velocity.x
##
## Player._apply_run() move_toward()s velocity.x at the target the INPUT asks
## for, every single frame. Anything a belt leaves in velocity.x is therefore
## somebody else's to spend: with no input it is decayed away at ground_decel
## (1600 px/s^2, gone in three frames), and re-adding it every frame to stop
## that compounds instead — decel eats 26px/frame while the belt hands back 60,
## and he accelerates off the screen. Clamping velocity.x to the belt speed
## instead fixes the runaway but breaks the other half of the contract: he can
## then never walk against the belt, because the clamp wins every frame.
##
## So the belt moves the SURFACE, which is what a belt is: move_and_collide()
## displaces the body, his velocity is never touched, and input keeps its full
## authority (90 px/s of run against a 60 px/s belt nets 30 px/s, exactly as it
## reads). Nothing the belt does can be eaten or amplified by the controller.
##
## The carry runs at process_physics_priority 1, i.e. AFTER the player's own
## _physics_process and its move_and_slide(), in the same frame, every frame,
## no matter where either node sits in the tree. Same reasoning as the note in
## slide_zone.gd: a push that lands on either side of the player's move
## depending on tree order is a bug that only shows up in one room.
##
## Drop one in LDtk as a `ConveyorBelt` entity and stretch it along the floor
## row it covers; `direction` and `speed` are fields on the entity.

## Which way it carries him. The sign lives here and nowhere else — `speed` is
## always positive, so flipping a belt in LDtk can never also change how fast it
## runs.
enum Direction { LEFT, RIGHT }

## Where the belt's own look comes from. Owned by the art side, NOT by this
## script, and deliberately loaded rather than preloaded: a preload of a missing
## file is a parse error, which would take the whole entity (and every level
## holding one) down with it while that scene is still being built. Missing, the
## belt is invisible and works exactly the same.
const VISUAL_SCENE := "res://scenes/props/zones/ConveyorBeltVisual.tscn"

## Full size of the belt in pixels. LDtk sets this from the box you drag; the
## entity is one cell tall and stretches sideways, so this is really a length.
@export var size := Vector2(16.0, 16.0):
	set(value):
		size = value
		_update_extents()
		_refresh_visual()

## Which way it carries him. Left/Right and nothing else — a belt at an angle is
## a SlideZone, and a belt you can steer out of the top is a wind tunnel.
@export var direction: Direction = Direction.RIGHT:
	set(value):
		direction = value
		_refresh_visual()
		queue_redraw()

## How fast it carries him, px/sec, ALWAYS POSITIVE — `direction` supplies the
## sign. 60 is two thirds of his run, so walking against the belt still gets him
## somewhere; past his 90 px/s run speed it becomes a wall he cannot cross.
@export var speed := 60.0:
	set(value):
		# absf, not maxf: a designer typing -60 means "60, the other way", and
		# silently becoming a belt that does nothing is the worse reading of it.
		speed = absf(value)
		_refresh_visual()

## How far ABOVE the drawn box a body still counts as riding, in px. The entity
## is placed on the floor row it replaces, so someone standing on the belt is
## entirely above it and would otherwise never overlap at all. 12 = the player's
## hitbox height; raise it and he gets carried while hovering over the belt.
@export var rider_reach := 12.0:
	set(value):
		rider_reach = maxf(value, 0.0)
		_update_extents()

## Whether the belt is a piece of floor in its own right. On, it carries its own
## walkable surface (ZoneFloor) and can be hung anywhere — which is what a belt
## laid across a gap has to be, and what the first version got wrong: it was a
## trigger volume and nothing else, so the player dropped straight through the
## machine that was supposed to be carrying him. Off only if you are laying a
## belt over floor tiles the room already has, where a second surface would be a
## phantom ledge.
@export var solid := true:
	set(value):
		solid = value
		_update_extents()

## How much of the belt's speed a rider takes with him when he leaves it in the
## air, as a fraction. 1 = all of it, which is what a real moving floor does:
## jumping off a belt running at your back should throw you further than jumping
## off the ground beside it. 0 turns the belt back into something that only ever
## works on your feet.
##
## Worth knowing before you raise it past 1: his run tops out at 90 px/s, so a
## 60 px/s belt already launches him at 150 — two thirds again as far.
@export_range(0.0, 2.0) var launch_transfer := 1.0

## Extra handover, as a fraction, for leaving the belt in the direction it runs.
## Jumping WITH a belt is the move the belt exists to reward, so it pays a little
## over the odds — 0.2 turns a 60 px/s belt into 72 on the way out. Jumping
## against it is unaffected: it already costs the belt's full speed.
@export_range(0.0, 1.0) var with_the_belt := 0.2

## Colour of the editor-only overlay, drawn only until the real visual exists.
const EDITOR_TINT := Color(1.0, 0.72, 0.25, 0.22)

## Bodies inside the trigger box, standing on the belt or not. Public so a test
## (or a room script) can tell "not touching it" apart from "touching it but not
## being carried" — the two failure modes look identical from the outside.
var riders: Array[Node2D] = []

const ZONE_FLOOR_SCENE := preload("res://scenes/props/zones/ZoneFloor.tscn")

var _shape: CollisionShape2D
var _visual: Node2D
var _floor: ZoneFloor
## Who was being carried last frame, by instance id. Keyed by id rather than by
## the node so a body freed mid-flight cannot keep this dictionary alive.
var _riding := {}


func _ready() -> void:
	collision_layer = 8  # layer 4 "triggers"
	collision_mask = 2   # player only
	# After the player's own _physics_process, so the carry always lands on top
	# of a finished move_and_slide() rather than in front of one.
	process_physics_priority = 1
	_shape = CollisionShape2D.new()
	_shape.shape = RectangleShape2D.new()
	add_child(_shape)
	_update_extents()
	_attach_visual()
	if Engine.is_editor_hint():
		set_physics_process(false)
		return
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)


## Signed speed, px/sec: negative carries left, positive right. The one place
## `direction` turns into a number.
func drift() -> float:
	return speed * (-1.0 if direction == Direction.LEFT else 1.0)


## True when `body` is not merely inside the belt but STANDING on it. Everything
## the belt does hangs off this: airborne over a belt you are unaffected by it,
## so a jump across a room of belts flies straight, and a corpse waiting out its
## respawn is not walked into the next hazard.
func carrying(body: Node2D) -> bool:
	if not is_instance_valid(body) or not riders.has(body):
		return false
	# A DASH owns him outright, belt or no belt. Dash distance is tuned to clear
	# specific gaps (see Player.dash_speed), so a belt adding or subtracting its
	# own speed for the length of the dash makes the same dash a different move
	# depending on which way the floor happens to be running — 9px either side of
	# a 39px dash, which is the difference between clearing a gap and not.
	if body is Player:
		var who := body as Player
		if who.state == Player.State.DEAD or who.state == Player.State.DASH:
			return false
	return body is CharacterBody2D and (body as CharacterBody2D).is_on_floor()


func _physics_process(delta: float) -> void:
	var carry := drift() * delta
	# move_and_collide, not a position write: the belt must not be able to push
	# him through the wall at the end of it.
	for body in riders:
		var riding := carrying(body)
		if riding and not is_zero_approx(carry):
			(body as CharacterBody2D).move_and_collide(Vector2(carry, 0.0))
		_settle_launch(body, riding)


## Hand the belt's speed over as real velocity the frame a rider LEAVES it in
## mid-air, and only then.
##
## Riding, the belt moves the surface under him rather than writing his velocity
## (see the header) — which is right while his feet are on it, and wrong the
## instant they are not. Without this, jumping off a belt running at his back
## dropped every pixel per second of it on the takeoff frame: he left a moving
## floor with only his own run in him, which feels like the belt switching off
## the moment you ask it for anything.
##
## Applied once per departure, on the transition, so a long jump over a belt
## cannot be topped up frame after frame — `_riding` is what makes it a
## transition rather than a state.
func _settle_launch(body: Node2D, riding: bool) -> void:
	var was: bool = _riding.get(body.get_instance_id(), false)
	_riding[body.get_instance_id()] = riding
	if riding or not was:
		return
	# He was on it last frame and is not now. Airborne = he jumped or ran off
	# the end, and the belt's speed goes with him. Still grounded = he simply
	# walked off the side onto ordinary floor, and it does not.
	if not is_instance_valid(body) or body is not CharacterBody2D:
		return
	var mover := body as CharacterBody2D
	if mover.is_on_floor():
		return
	if body is Player:
		var who := body as Player
		# A dash is not a departure — it is the dash taking over, and it is the
		# one move whose distance has to be the same everywhere.
		if who.state == Player.State.DEAD or who.state == Player.State.DASH:
			return
	# Leaving in the belt's own direction is the two of them agreeing, and that
	# gets the bonus (see with_the_belt). Leaving against it is already being
	# paid the belt's full speed as a tax on the jump.
	var handover := drift() * launch_transfer
	if not is_zero_approx(mover.velocity.x) \
			and signf(mover.velocity.x) == signf(drift()):
		handover *= 1.0 + with_the_belt
	# Asked for, not written: Player.add_momentum also marks the speed as GIVEN,
	# which is what stops his own deceleration scrubbing it off in three frames.
	# A plain CharacterBody2D rider (a crate, later) just takes the velocity.
	if mover.has_method("add_momentum"):
		mover.add_momentum(handover)
	else:
		mover.velocity.x += handover


func _on_body_entered(body: Node2D) -> void:
	if not riders.has(body):
		riders.append(body)


func _on_body_exited(body: Node2D) -> void:
	riders.erase(body)
	# NOT a launch site, deliberately. Leaving the box looks like a departure, but
	# it is also what a respawn, a room load and a debug teleport look like — and
	# handing a belt's speed to a player who is now two hundred pixels away is the
	# same class of bug the death counter had. A real jump goes airborne while
	# still inside the box (it reaches rider_reach above the belt), so
	# _physics_process has always already paid out by the time this fires.
	_riding.erase(body.get_instance_id())


## The trigger box is the drawn box grown UPWARD by rider_reach — the drawn box
## is the belt surface itself (the floor row), and nobody standing on a surface
## is inside it.
func _update_extents() -> void:
	if _shape == null:
		return
	var box := Vector2(maxf(size.x, 1.0), maxf(size.y, 1.0) + rider_reach)
	(_shape.shape as RectangleShape2D).size = box
	_shape.position = Vector2(0.0, -rider_reach * 0.5)
	_fit_floor()
	queue_redraw()


## Keep the walkable surface in step with the belt's box. The floor is a child
## node rather than a second shape on this Area2D, because an Area2D's shapes
## are all detection — nothing lands on them.
func _fit_floor() -> void:
	if not solid:
		if _floor != null:
			_floor.queue_free()
			_floor = null
		return
	if _floor == null:
		_floor = ZONE_FLOOR_SCENE.instantiate()
		_floor.name = "Floor"
		add_child(_floor)
	_floor.fit(size)


## Instance the art, if the art exists yet. Built here rather than saved into
## ConveyorBelt.tscn so the prefab stays a single node: the LDtk importer packs
## whatever it is handed, and an instanced sub-scene with children of its own
## gets serialised twice on the way in (see STYLE_GUIDE.md §9). _ready() does
## not run at import time, so this child is only ever built at runtime.
func _attach_visual() -> void:
	if _visual != null or not ResourceLoader.exists(VISUAL_SCENE):
		return
	var packed := load(VISUAL_SCENE) as PackedScene
	if packed == null:
		return
	_visual = packed.instantiate() as Node2D
	if _visual == null:
		return
	add_child(_visual)
	_refresh_visual()


## Hand the belt's state to the visual. It owns everything about how a belt
## looks — which way the tread scrolls and how fast is a consequence of the same
## two numbers the physics uses, so it is told rather than left to guess.
func _refresh_visual() -> void:
	if _visual != null and _visual.has_method("set_belt"):
		_visual.set_belt(direction, speed, size)


## Editor only, and only until the real visual exists: the box, plus arrows for
## which way it runs. `direction` is a dropdown, and a dropdown is very easy to
## leave on the wrong value.
func _draw() -> void:
	if not Engine.is_editor_hint() or _visual != null:
		return
	draw_rect(Rect2(-size * 0.5, size), EDITOR_TINT)
	var way := -1.0 if direction == Direction.LEFT else 1.0
	var line := Color(EDITOR_TINT, 0.9)
	var reach: float = minf(size.x, size.y) * 0.35 + 6.0
	var tip := Vector2(way * reach, 0.0)
	draw_line(-tip, tip, line, 1.0)
	for side in [140.0, -140.0]:
		draw_line(tip, tip + Vector2(way, 0.0).rotated(deg_to_rad(side)) * 5.0, line, 1.0)
