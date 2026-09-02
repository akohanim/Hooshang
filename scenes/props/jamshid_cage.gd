@tool
class_name JamshidCage
extends StaticBody2D
## The locked cage blocking the way to Jamshid — solid until all four Act 2
## keys are held, then it opens for good.
##
## A PLAIN PROP FOR NOW, DELIBERATELY. Jamshid himself (portraits, voice,
## dialogue) is a separate, later task — this only has to be the barrier that
## the keys open, so it stays a StaticBody2D with two frames and no character
## inside it. Wiring an actual reunion beat to `_on_quest_changed` later is a
## small addition to make, not a redesign of this node.
##
## NO STATE OF ITS OWN, on purpose. Whether it is open is fully DERIVED from
## Act2Quest.all_keys_collected() every time — read fresh in _ready() and again
## on every Act2Quest.changed signal — rather than a separate "opened" flag
## this node would have to save and load. Act2Quest's own held-keys set
## already persists (see systems/save_game.gd's "act2_quest" slice), so there
## is nothing here that could disagree with it: a save loaded with all four
## keys already held opens the cage the instant Act2Quest.load_state() fires
## `changed`, and one loaded with fewer keeps it shut, with no separate flag
## to keep in sync.

const CLOSED := preload("res://assets/props/jamshid_cage/closed.png")
const OPEN := preload("res://assets/props/jamshid_cage/open.png")

## Fixed art, like MysteryBox — a dragged handle could only ever promise a
## bigger cage than the one that is actually solid.
const SIZE := Vector2(16.0, 24.0)

var _sprite: Sprite2D
var _shape: CollisionShape2D
## Whether it was already open the LAST time _apply_open ran — so the "just
## opened" tween plays once, on the transition, not every time Act2Quest
## happens to emit `changed` (collecting key 1 of 4 must not replay it).
var _was_open := false
var _open_tween: Tween


func _ready() -> void:
	add_to_group("jamshid_cage")
	collision_layer = 1  # layer 1 "world"
	collision_mask = 0
	_shape = CollisionShape2D.new()
	_shape.shape = RectangleShape2D.new()
	(_shape.shape as RectangleShape2D).size = SIZE
	add_child(_shape)
	_sprite = Sprite2D.new()
	_sprite.name = "Sprite"
	add_child(_sprite)

	_was_open = false
	_apply_open(not Engine.is_editor_hint() and Act2Quest.all_keys_collected())
	if not Engine.is_editor_hint():
		Act2Quest.changed.connect(_on_quest_changed)


func _on_quest_changed(_held: int) -> void:
	_apply_open(Act2Quest.all_keys_collected())


func _apply_open(open: bool) -> void:
	var just_opened := open and not _was_open
	_was_open = open
	# Deferred: Act2Quest.changed can reach here synchronously from INSIDE a
	# Key's own body_entered handler, which is itself running inside the
	# physics server's query flush — the same "Can't change this state while
	# flushing queries" trap mystery_box.gd's _spawn_mushroom note documents,
	# just one signal hop further away.
	_shape.set_deferred("disabled", open)
	_sprite.texture = OPEN if open else CLOSED
	if not just_opened:
		return
	if _open_tween != null and _open_tween.is_valid():
		_open_tween.kill()
	_sprite.scale = Vector2(1.25, 0.8)
	_open_tween = create_tween()
	_open_tween.tween_property(_sprite, "scale", Vector2.ONE, 0.25) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
