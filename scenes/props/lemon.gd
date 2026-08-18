class_name Lemon
extends Area2D
## A collectable lemon — the game's "coin". Placed by hand in LDtk and
## turned into this node by scripts/ldtk_entities_post_import.gd.
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
## The copy on the token surface, if there is one. Null means no Screen (a test
## that built the world by hand), and then the world sprite is shown instead.
var _token: AnimatedSprite2D

@onready var _sprite: AnimatedSprite2D = $Sprite


func _ready() -> void:
	add_to_group("lemon")
	collision_layer = 8  # layer 4 "triggers"
	collision_mask = 2   # player only
	body_entered.connect(_on_body_entered)

	# Already picked up on a previous visit to this room (or a re-run of the
	# world)? Then it should not be here at all.
	if Collectibles.is_taken(collect_id()):
		queue_free()
		return

	_sprite.play("spin")
	_make_token()
	var bob := create_tween().set_loops()
	bob.tween_property(_sprite, "position:y", -bob_height, bob_time * 0.5) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	bob.tween_property(_sprite, "position:y", 0.0, bob_time * 0.5) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
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


## Keep the copy where the real fruit is — including the bob, which is tweened
## on the world sprite and read from it here rather than being run twice.
func _process(_delta: float) -> void:
	if _token != null and is_instance_valid(_token):
		_token.global_position = _sprite.global_position
		_token.modulate = _sprite.modulate * modulate


func _exit_tree() -> void:
	if _token != null and is_instance_valid(_token):
		_token.queue_free()


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
	# Handing `self` over is what lets the counter fly the fruit in from exactly
	# here — the two live on different render surfaces, so Collectibles converts
	# this position rather than reading it directly.
	Collectibles.collect(collect_id(), 1, self)
	set_deferred("monitoring", false)

	# Clear out. The HUD's copy takes over the motion from this same point, so
	# this one only has to get out of the way without a visible pop. Detached
	# from the bob loop so they can't fight.
	var t := create_tween().set_parallel()
	t.tween_property(self, "modulate:a", 0.0, pop_time)
	if has_node("Glow"):
		t.tween_property($Glow, "energy", 0.0, pop_time)
	await t.finished
	queue_free()
