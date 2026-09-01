class_name Mushroom
extends CharacterBody2D
## A power-up mushroom: rises out of a bumped MysteryBox and walks off across
## the floor, Super Mario 3 style. See mystery_box.gd for the block that
## spawns one — this node only knows how to rise, walk, fall and be picked up.
##
## TWO PHASES, not one animation. EMERGING climbs straight up out of the
## block at a fixed rate with no gravity and cannot be touched yet — Mario's
## mushroom is inert while it is still "growing" out of the block. Clearing
## the block's top drops it into WALKING: gravity on, a constant speed in
## `walk_dir` (starting right), reversing off a wall and simply falling off a
## ledge rather than avoiding one — the classic SMB mushroom AI, not a
## smarter one.
##
## COLLISION: layer 0 (nothing sees it as an obstacle — the player must never
## be physically blocked by it, only pick it up) but MASKS layer 1 "world", so
## move_and_slide still reacts to floors and walls like any other body on the
## ground. A separate Pickup Area2D (layer 4 "triggers", masking the player
## only — the rule every trigger in the project follows) is what actually
## collects it; that Area2D is off (`monitoring = false`) until it has fully
## emerged, so brushing the block while it is still rising doesn't grab it.
##
## What a pickup DOES lives on the player, not here — see
## Player.consume_mushroom(). This node's whole job ends the moment it hands
## the type over.

enum MushroomType { BLACK_WHITE }

const SHEETS := {
	MushroomType.BLACK_WHITE: preload("res://assets/props/mushroom/mushroom_black_white.png"),
}
## The drawn art's size in px (tools/gen_mushroom.py's canvas). MysteryBox
## uses this to land the emerge at "standing on top of the block", not
## floating half a body above it.
const ART := Vector2(11.0, 12.0)

enum _Phase { EMERGING, WALKING }

@export var mushroom_type: MushroomType = MushroomType.BLACK_WHITE:
	set(value):
		mushroom_type = value
		_apply_type()

## How fast it climbs out of the block, px/s. A fixed rate and no gravity —
## Mario's mushroom doesn't accelerate out, it just rises.
@export var emerge_speed := 40.0
## Walking speed once fully emerged, px/s. Well under Hooshang's own run (72)
## so it reads as something you can catch up to, not something outrunning you.
@export var walk_speed := 30.0
@export var gravity := 900.0
@export var max_fall_speed := 220.0

var _phase := _Phase.EMERGING
var _emerge_target_y := 0.0
## 1 right, -1 left. Public because a test drives it; MysteryBox always
## starts a fresh mushroom walking right, per the brief.
var walk_dir := 1.0

var _sprite: Sprite2D
var _pickup: Area2D


func _ready() -> void:
	collision_layer = 0  # never an obstacle — the player must walk through it
	collision_mask = 1   # world only, for gravity/walls/floor

	# The body's OWN shape — move_and_slide has nothing to test the world
	# against without one, which is silent: gravity still integrates, so a
	# shapeless mushroom free-falls forever instead of landing, and reads as
	# "gravity works" right up until it should have hit a floor.
	var body_shape := CollisionShape2D.new()
	body_shape.shape = RectangleShape2D.new()
	(body_shape.shape as RectangleShape2D).size = ART
	add_child(body_shape)

	_sprite = Sprite2D.new()
	_sprite.name = "Sprite"
	add_child(_sprite)
	_apply_type()

	_pickup = Area2D.new()
	_pickup.name = "Pickup"
	_pickup.collision_layer = 8  # layer 4 "triggers"
	_pickup.collision_mask = 2   # player only
	var shape := CollisionShape2D.new()
	shape.shape = RectangleShape2D.new()
	(shape.shape as RectangleShape2D).size = ART + Vector2(2.0, 2.0)
	_pickup.add_child(shape)
	add_child(_pickup)
	# DEFERRED. _ready() here always runs inside MysteryBox's BumpSensor
	# body_entered callback (add_child() calls _ready() synchronously), which
	# is itself mid physics-query-flush — Godot refuses a direct write to
	# Area2D.monitoring at that point ("Can't change this state while
	# flushing queries") and the assignment would silently fail to apply.
	_pickup.set_deferred("monitoring", false)
	_pickup.body_entered.connect(_on_pickup)


## Start rising out of a mystery box from `at` (its world position, usually
## the block's own centre — the mushroom is meant to be hidden inside it at
## the start), up to `target_y` (the world y its own centre should reach,
## which is what leaves it standing on top of the block once it arrives).
func begin_emerge(at: Vector2, target_y: float) -> void:
	global_position = at
	_emerge_target_y = target_y
	walk_dir = 1.0
	velocity = Vector2.ZERO
	_phase = _Phase.EMERGING
	if _pickup != null:
		_pickup.set_deferred("monitoring", false)


func _physics_process(delta: float) -> void:
	if _phase == _Phase.EMERGING:
		global_position.y -= emerge_speed * delta
		if global_position.y <= _emerge_target_y:
			global_position.y = _emerge_target_y
			_phase = _Phase.WALKING
			_pickup.monitoring = true
		return
	velocity.y = minf(velocity.y + gravity * delta, max_fall_speed)
	velocity.x = walk_dir * walk_speed
	move_and_slide()
	# Bounce off a wall; a ledge is not a wall, so it walks straight off one
	# and keeps going — the rule every SMB mushroom follows.
	if is_on_wall():
		walk_dir = -walk_dir


func _apply_type() -> void:
	if _sprite == null:
		return
	_sprite.texture = SHEETS.get(mushroom_type, SHEETS[MushroomType.BLACK_WHITE])


func _on_pickup(body: Node2D) -> void:
	if not _pickup.monitoring or body is not Player:
		return
	(body as Player).consume_mushroom(mushroom_type)
	# Deferred — this runs inside the Pickup Area2D's own body_entered flush,
	# same restriction begin_emerge()'s note explains.
	_pickup.set_deferred("monitoring", false)
	set_physics_process(false)
	var t := create_tween()
	t.tween_property(_sprite, "scale", Vector2.ONE * 1.5, 0.08)
	t.parallel().tween_property(_sprite, "modulate:a", 0.0, 0.08)
	t.tween_callback(queue_free)
