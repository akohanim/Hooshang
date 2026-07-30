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
## Stand Rumi on the floor beneath him rather than at the height the trigger
## happens to be placed at. Off = he stays exactly where the LDtk entity sits,
## for a beat that deliberately wants him hovering.
@export var snap_to_ground := true

@onready var _rumi: AnimatedSprite2D = $Rumi
@onready var _rumi_light: PointLight2D = $RumiLight

## How far down to look for a floor, in px. Comfortably more than a room's height.
const FLOOR_PROBE_DEPTH := 400.0

var _fired := false
var _breath: Tween
var _feet_row_cache := -1.0


func _ready() -> void:
	collision_layer = 8  # layer 4 "triggers"
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
	var rest_y := _ground_rest_y(stand_x) if snap_to_ground else 0.0
	_rumi.position = Vector2(stand_x, rest_y - 10.0)
	_rumi_light.position = Vector2(stand_x, rest_y - 19.0)
	# Face back towards the trigger — i.e. towards whoever just walked into it.
	_rumi.flip_h = stand_x > 0.0
	var t := create_tween().set_parallel()
	t.tween_property(_rumi, "modulate:a", 1.0, 0.5)
	t.tween_property(_rumi, "position:y", rest_y, 0.5) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	t.tween_property(_rumi_light, "energy", 1.4, 0.5)
	await t.finished


## Local y that puts Rumi's DRAWN FEET on the floor below `stand_x`.
##
## Two corrections, both needed, and the second is the one that actually made him
## hover: the trigger is placed wherever it reads well in LDtk rather than on the
## ground, AND his sprite frame has transparent padding under his feet — 96px
## frames whose lowest opaque row is 80, so at 0.5 scale there are 7.5px of empty
## pixels below him. Sitting the sprite's BOX on the floor therefore left him
## floating by exactly that much.
##
## Measured from the texture rather than hardcoded, so re-cutting Rumi's art
## can't silently reintroduce the hover.
func _ground_rest_y(stand_x: float) -> float:
	var floor_y := _floor_under(global_position.x + stand_x)
	if is_inf(floor_y):
		return 0.0  # nothing below (mid-air trigger) — leave him where he was placed
	var tex := _rumi.sprite_frames.get_frame_texture(_rumi.animation, 0)
	if tex == null:
		return floor_y - global_position.y
	# Sprite is centred, so its local top edge is -h/2; the feet sit at the last
	# opaque row, measured down from there.
	var feet_offset := (_feet_row(tex) - tex.get_height() * 0.5) * _rumi.scale.y
	return floor_y - feet_offset - global_position.y


## World y of the first world-layer surface below `world_x`.
func _floor_under(world_x: float) -> float:
	var from := Vector2(world_x, global_position.y - 8.0)
	var query := PhysicsRayQueryParameters2D.create(from, from + Vector2(0.0, FLOOR_PROBE_DEPTH))
	query.collision_mask = 1  # world
	var hit := get_world_2d().direct_space_state.intersect_ray(query)
	return hit.position.y if hit else INF


## Row just past the lowest non-transparent pixel of a frame. Cached: reading an
## imported texture back to an Image is not something to do every beat.
func _feet_row(tex: Texture2D) -> float:
	if _feet_row_cache >= 0.0:
		return _feet_row_cache
	_feet_row_cache = float(tex.get_height())  # fallback: the frame's bottom edge
	var img := tex.get_image()
	if img == null:
		return _feet_row_cache
	for y in range(img.get_height() - 1, -1, -1):
		for x in img.get_width():
			if img.get_pixel(x, y).a > 0.05:
				_feet_row_cache = float(y + 1)
				return _feet_row_cache
	return _feet_row_cache


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
