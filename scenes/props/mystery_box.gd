@tool
class_name MysteryBox
extends StaticBody2D
## A Mario-style "?" block: bump it from underneath — jumping or dashing into
## its underside — and a mushroom rises out of the top and walks off. See
## scenes/props/mushroom.gd for what comes out and Player.consume_mushroom()
## for what it does once caught.
##
## SOLID, ALWAYS — even once spent. Mario's blocks never stop being something
## you can stand on; only the face and what is inside them change.
##
## THE HIT IS DETECTED WITH A SENSOR, NOT A COLLISION QUERY. A StaticBody2D
## emits no contact signals of its own — the same fact CrumblingPlatform's
## own note explains — so BumpSensor is an Area2D standing PROUD of the solid
## box's underside, the same "skin" trick CrumblingPlatform uses to know he
## is on top of IT. Standing proud matters here for a sharper reason: the
## sensor has to see him while `velocity.y` is still cleanly negative, which
## means catching him BEFORE the solid collision gets a chance to resolve and
## zero it. A sensor flush with the solid's own face would overlap on the
## same frame the collision resolves, and by then move_and_slide may already
## have stopped him — a real hit read as a miss. Standing proud gives the
## sensor a few pixels of lead, so it fires while he is still rising into it.
##
## Only a genuine UPWARD hit counts (`velocity.y < 0`) — resting against the
## underside, or drifting up past it slowly, is not "jumping or dashing into
## it".
##
## One mushroom per life of the box. It comes back — the face and whether it
## can be bumped again — on the same two occasions everything else with
## persistent per-visit state does: a room entry and a respawn (see
## reset_all, called from ldtk_world.gd beside CrumblingPlatform's and
## DarkThought's).

const SHEET := preload("res://assets/props/mystery_box/mystery_box.png")
const CELL := 16.0
const MUSHROOM_SCENE := preload("res://scenes/props/Mushroom.tscn")

## How far the bump sensor reaches UP into the box's own footprint, and how
## far it stands PROUD below it — see the class doc for why proud matters.
const BUMP_INSET := 2.0
const BUMP_PROUD := 8.0
## Narrower than the box, so a body that merely brushes past a corner doesn't
## read as a hit under the middle of it.
const BUMP_WIDTH := 12.0

## Which mushroom a bump here gives up. Configurable per instance from LDtk
## (see tools/ldtk_add_mystery_box.py) so different boxes in the world can
## hand out different powers without being different scenes.
@export var mushroom_type: Mushroom.MushroomType = Mushroom.MushroomType.BLACK_WHITE

## The bump bounce: how far the face hops, and how long the hop takes each way.
@export var bump_hop := 3.0
@export var bump_hop_time := 0.09
@export var bump_settle_time := 0.14

var _spent := false
var _sprite: Sprite2D
var _bump_sensor: Area2D
var _bounce_tween: Tween


func _ready() -> void:
	add_to_group("mystery_box")
	collision_layer = 1  # layer 1 "world" — the same layer every solid uses
	collision_mask = 0
	var shape := CollisionShape2D.new()
	shape.shape = RectangleShape2D.new()
	(shape.shape as RectangleShape2D).size = Vector2(CELL, CELL)
	add_child(shape)

	_sprite = Sprite2D.new()
	_sprite.name = "Sprite"
	add_child(_sprite)
	_apply_frame()

	_bump_sensor = Area2D.new()
	_bump_sensor.name = "BumpSensor"
	_bump_sensor.collision_layer = 8  # layer 4 "triggers"
	_bump_sensor.collision_mask = 2   # player only
	var sensor_shape := CollisionShape2D.new()
	sensor_shape.shape = RectangleShape2D.new()
	var bump_h := BUMP_INSET + BUMP_PROUD
	(sensor_shape.shape as RectangleShape2D).size = Vector2(BUMP_WIDTH, bump_h)
	_bump_sensor.add_child(sensor_shape)
	# Centred on the underside, straddling it: BUMP_INSET up into the box's
	# own footprint, BUMP_PROUD standing clear below it.
	_bump_sensor.position = Vector2(0.0, CELL * 0.5 - BUMP_INSET + bump_h * 0.5)
	add_child(_bump_sensor)
	if not Engine.is_editor_hint():
		_bump_sensor.body_entered.connect(_on_bump_sensor_entered)


func _apply_frame() -> void:
	if _sprite == null:
		return
	var tex := AtlasTexture.new()
	tex.atlas = SHEET
	tex.region = Rect2(CELL if _spent else 0.0, 0.0, CELL, CELL)
	_sprite.texture = tex


func _on_bump_sensor_entered(body: Node2D) -> void:
	if _spent or body is not Player:
		return
	if (body as Player).velocity.y >= 0.0:
		return  # resting or falling against the underside: not a hit
	_bump()


func _bump() -> void:
	_spent = true
	_apply_frame()
	_spawn_mushroom()
	if _bounce_tween != null and _bounce_tween.is_valid():
		_bounce_tween.kill()
	_bounce_tween = create_tween()
	_bounce_tween.tween_property(_sprite, "position:y", -bump_hop, bump_hop_time) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_bounce_tween.tween_property(_sprite, "position:y", 0.0, bump_settle_time) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## Both steps here are DEFERRED, and both have to be. This always runs from
## inside BumpSensor's own body_entered callback — a physics query flush —
## and Mushroom's _ready() builds CollisionShape2Ds of its own, which the
## physics server refuses mid-flush ("Can't change this state while flushing
## queries") even for a node freshly added and not yet touched by anything
## else. begin_emerge() is deferred right along with it rather than called
## inline: it writes global_position, which is only meaningful once the node
## is actually inside the tree, and add_child() has not taken effect yet at
## the point a plain call would run. Godot's deferred queue is FIFO, so the
## add_child queued first is guaranteed to have completed before this one
## fires.
func _spawn_mushroom() -> void:
	var parent := get_parent()
	if parent == null:
		return
	var mushroom: Mushroom = MUSHROOM_SCENE.instantiate()
	mushroom.mushroom_type = mushroom_type
	var start := global_position
	var target := global_position.y - CELL * 0.5 - Mushroom.ART.y * 0.5
	parent.add_child.call_deferred(mushroom)
	mushroom.begin_emerge.call_deferred(start, target)


## Put it back exactly as it was placed: unspent, idle face, no bounce in
## flight. Does NOT free a mushroom already out in the world — one that has
## already emerged is its own creature, the same way a lemon already pending
## is left alone by a level reset.
func reset() -> void:
	_spent = false
	if _bounce_tween != null and _bounce_tween.is_valid():
		_bounce_tween.kill()
	if _sprite != null:
		_sprite.position = Vector2.ZERO
	_apply_frame()


## Reset every mystery box in the tree — the same static-helper pattern
## CrumblingPlatform.reset_all and DarkThought.reset_all use, for the same
## reason: LdtkWorld calls this from two places (a respawn and a room entry),
## and a group name copied into three files is a group name that gets renamed
## in two of them.
static func reset_all(tree: SceneTree) -> void:
	for node in tree.get_nodes_in_group("mystery_box"):
		if node is MysteryBox:
			(node as MysteryBox).reset()
