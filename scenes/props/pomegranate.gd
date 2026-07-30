class_name Pomegranate
extends Area2D
## A collectable pomegranate — the game's "coin". Placed by hand in LDtk and
## turned into this node by scripts/ldtk_entities_post_import.gd.
##
## It only knows how to be picked up and look alive; the running total lives in
## the Collectibles autoload, so the count survives room changes, deaths and
## Act -> Act scene loads (STYLE_GUIDE §5: cross-level state is an autoload).
##
## Physics: layer 4 "triggers", masking the player ONLY — the same rule every
## other trigger follows, so a future enemy can never vacuum up the fruit.

## Bob height in px, and how long one up-down cycle takes.
@export var bob_height := 2.0
@export var bob_time := 1.6
## Pop-on-collect: how far it rises and how long the flourish lasts.
@export var pop_rise := 10.0
@export var pop_time := 0.28
## Small warm light so the fruit is findable in the dark rooms. 0 disables it.
@export var light_energy := 0.55

var _taken := false

@onready var _sprite: AnimatedSprite2D = $Sprite


func _ready() -> void:
	add_to_group("pomegranate")
	collision_layer = 8  # layer 4 "triggers"
	collision_mask = 2   # player only
	body_entered.connect(_on_body_entered)

	# Already picked up on a previous visit to this room (or a re-run of the
	# world)? Then it should not be here at all.
	if Collectibles.is_taken(collect_id()):
		queue_free()
		return

	_sprite.play("spin")
	var bob := create_tween().set_loops()
	bob.tween_property(_sprite, "position:y", -bob_height, bob_time * 0.5) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	bob.tween_property(_sprite, "position:y", 0.0, bob_time * 0.5) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	if light_energy <= 0.0 and has_node("Glow"):
		$Glow.queue_free()
	elif has_node("Glow"):
		$Glow.energy = light_energy


## Stable identity for "this particular fruit", so reloading the world cannot
## hand out the same one twice. World position is unique within an Act and is
## fixed by the LDtk placement, which makes it a better key than any runtime id.
func collect_id() -> String:
	return "%s@%d,%d" % [Collectibles.world_key(),
		roundi(global_position.x), roundi(global_position.y)]


func _on_body_entered(body: Node2D) -> void:
	if _taken or body is not Player:
		return
	_taken = true
	Collectibles.collect(collect_id())
	set_deferred("monitoring", false)

	# Flourish, then go. Detached from the bob loop so they can't fight.
	var t := create_tween().set_parallel()
	t.tween_property(_sprite, "position:y", _sprite.position.y - pop_rise, pop_time) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	t.tween_property(_sprite, "scale", Vector2(1.4, 1.4), pop_time * 0.4)
	t.tween_property(self, "modulate:a", 0.0, pop_time)
	if has_node("Glow"):
		t.tween_property($Glow, "energy", 0.0, pop_time)
	await t.finished
	queue_free()
