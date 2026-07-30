class_name LdtkRumiTrigger
extends Area2D
## Built by scripts/ldtk_entities_post_import.gd for each LDtk `RumiTrigger`
## entity. Walking in fades a Rumi sprite in beside the trigger, plays her
## line, then fades her out — same beat as level1_office.gd's
## _rumi_appear/_rumi_vanish, just self-contained since there's no per-level
## cutscene script for LDtk levels yet.
##
## IMPORTANT: signals are connected here, in _ready(), not by the post-import
## script that builds this node. A connection made once at import time (a
## lambda, especially) doesn't survive being packed into the saved .scn and
## reloaded — _ready() re-runs fresh every time this node actually enters a
## live scene tree, which is the only place that matters.

## Fired the moment the player walks in, before anything else happens. A story
## script (see scripts/act1_beats.gd) connects to this to stage its own beat.
signal triggered(player: Player)

const RUMI_GOLD := Color(1.0, 0.82, 0.42, 1.0)

@export var dialogue_line: String = ""
## When a cutscene script owns this beat, it sets this so the trigger does NOT
## play its own one-line version — it just emits `triggered` and steps aside.
## Set from code (the script that takes over), not from LDtk: which beats are
## scripted is a story fact, not level data.
@export var defer_to_cutscene := false

@onready var _rumi: AnimatedSprite2D = $Rumi
@onready var _rumi_light: PointLight2D = $RumiLight

var _fired := false
var _breath: Tween


func _ready() -> void:
	collision_layer = 0
	collision_mask = 2  # player only
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node2D) -> void:
	if _fired or body is not Player:
		return
	_fired = true
	var player: Player = body
	triggered.emit(player)
	if defer_to_cutscene:
		return
	_play_beat(player)


func _play_beat(player: Player) -> void:
	player.input_locked = true
	await appear()
	await Dialogue.say("Rumi", dialogue_line, RUMI_GOLD)
	await vanish()
	player.input_locked = false
	arm_room_door()


# ------------------------------------------------------------- staging API ----
# Public so a cutscene script can direct Rumi without reaching into his sprite
# and light (STYLE_GUIDE §4). Each one awaits its own tween.

## Fade Rumi in with a small descend, and raise his warm gold light.
##
## `stand_x` offsets where he settles, in trigger-local pixels. The default 0
## puts him at the trigger itself, which is fine for a one-line drive-by — but a
## beat where he has to step TOWARD Hooshang needs him to start with some room to
## cross, and the player is standing on the trigger by definition.
func appear(stand_x := 0.0) -> void:
	_rumi.position = Vector2(stand_x, -10)
	_rumi_light.position.x = stand_x
	# Face back towards the trigger — i.e. towards whoever just walked into it.
	_rumi.flip_h = stand_x > 0.0
	var t := create_tween().set_parallel()
	t.tween_property(_rumi, "modulate:a", 1.0, 0.5)
	t.tween_property(_rumi, "position:y", 0.0, 0.5) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	t.tween_property(_rumi_light, "energy", 1.4, 0.5)
	await t.finished


func vanish() -> void:
	breathe(false)
	var t := create_tween().set_parallel()
	t.tween_property(_rumi, "modulate:a", 0.0, 0.5)
	t.tween_property(_rumi_light, "energy", 0.0, 0.5)
	await t.finished


## The light along his sleeves breathing slightly — a slow looping swell, so a
## silent Rumi still reads as present and alive rather than as a frozen sprite.
## Does not await: it runs until switched off.
func breathe(on: bool) -> void:
	if _breath != null and _breath.is_valid():
		_breath.kill()
		_breath = null
	if not on:
		return
	_breath = create_tween().set_loops()
	_breath.tween_property(_rumi_light, "energy", 1.9, 1.5) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_breath.tween_property(_rumi_light, "energy", 1.4, 1.5) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


## Glide Rumi toward a world x, stopping `stop_short` px away so he ends up at
## arm's length rather than standing inside Hooshang. The light travels with him
## — it's the light along his sleeves, so leaving it behind reads as a bug.
##
## Approaches from whichever side he is already on. If he is somehow closer than
## stop_short he holds position rather than backing away, which looked like him
## flinching.
func step_to(world_x: float, stop_short := 14.0, duration := 0.8) -> void:
	var here := global_position.x + _rumi.position.x
	var side := signf(here - world_x)
	if side == 0.0:
		side = 1.0
	_rumi.flip_h = side > 0.0  # keep looking at him while closing the gap
	if absf(here - world_x) <= stop_short:
		return
	var target_x := world_x + side * stop_short - global_position.x
	var t := create_tween().set_parallel()
	t.tween_property(_rumi, "position:x", target_x, duration) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	t.tween_property(_rumi_light, "position:x", target_x, duration) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await t.finished


## A swell of light, for the moment he reaches out.
func swell(to := 3.2, duration := 0.45) -> void:
	breathe(false)
	var t := create_tween()
	t.tween_property(_rumi_light, "energy", to, duration) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	await t.finished


## Rumi leaving is the cue for the story door to swing open onto the void.
## Scope to THIS room's doors only: LdtkWorld keeps every room in the Act loaded
## at once, so an unscoped group lookup would swing open doors in rooms the
## player hasn't reached yet. Same parent = same room's Entities layer.
func arm_room_door() -> void:
	for door in get_tree().get_nodes_in_group("story_door"):
		if door is LdtkDoor and door.get_parent() == get_parent():
			door.arm()
