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
const LIGHT_TEXTURE := preload("res://assets/light_radial.png")
## The mote's solid core. A PointLight2D alone is not enough to carry this beat:
## rooms lit for the diegetic pass sit close to clipping, and in room 1 the walls
## are already at 255 in the red channel — adding light there changes nothing you
## can see. A drawn sprite reads at any exposure.
const MOTE_TEXTURE := preload("res://assets/gift_mote.png")
## light_radial.png is 128px, so its untouched radius is 64 (see LIGHTING.md).
const TEXTURE_RADIUS := 64.0

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

@export_group("The gift")
## Radius of the travelling mote, in px — small and intense, so it reads as a
## thing being carried rather than as area lighting.
@export var gift_radius := 9.0
## How bright the mote burns while it crosses.
@export var gift_energy := 1.9
## How high the mote arcs above the straight line between them. A flat slide
## reads as a UI tween; a lob reads as something handed over.
@export var gift_arc := 3.0
## Size of the drawn core, as a multiple of gift_mote.png's 11px. Rumi stops at
## arm's length (14px), so a full-size orb fills most of the gap it is meant to
## be crossing.
@export var gift_core_scale := 0.65
## Seconds the mote takes to cross.
@export var gift_travel_time := 0.55
## What Rumi's own light drops to as the mote leaves him. Draining him is what
## sells it as a TRANSFER rather than two lights that happen to be on.
@export var gift_cost := 1.0
## The burst on impact: radius it blooms to, and how long the bloom takes to
## fade out. Runs detached, after `give_to` has already returned.
@export var gift_burst_radius := 46.0
@export var gift_burst_time := 0.32
## Where on the target the mote lands, relative to its origin. The player's
## origin is the middle of his 8x12 box, so a few px up is chest height.
@export var gift_target_offset := Vector2(0.0, -3.0)
## Where the mote leaves Rumi, relative to his sprite's centre. X is applied
## towards the target, so positive means "out in front of him".
##
## Deliberately NOT taken from `_rumi_light`: that light is his aura and sits at
## -19, which is above his head — sourcing the mote there sent it arcing up over
## the ceiling and down onto Hooshang, like something thrown rather than handed
## across.
##
## Kept small for a second reason. Rumi stops at arm's length, 14px, so every
## pixel of this offset is a pixel the gift does NOT visibly cross: at 8 the mote
## travelled 6px and read as a flicker rather than a journey.
@export var gift_source_offset := Vector2(2.0, -2.0)

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
	await Dialogue.say("Rumi", dialogue_line, RUMI_GOLD, null, portrait_side(player))
	await vanish()
	player.input_locked = false
	arm_room_door()


# ------------------------------------------------------------- staging API ----
# Public so a cutscene script can direct Rumi without reaching into his sprite
# and light (STYLE_GUIDE §4). Each one awaits its own tween.

## Which end of the dialogue banner Rumi's face belongs at, given who he is
## talking to: the side he is actually standing on.
##
## Read off the sprite rather than off whichever direction the beat asked him to
## appear in, so it cannot disagree with what is on screen — and so it stays
## right after step_to() has moved him.
func portrait_side(other: Node2D) -> int:
	if other == null:
		return DialogueBox.Side.RIGHT
	return DialogueBox.Side.RIGHT if _rumi.global_position.x >= other.global_position.x \
		else DialogueBox.Side.LEFT


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


## Hand the light over. A mote leaves Rumi's sleeve, arcs across the gap and
## lands on `target`; Rumi's own light drains by the same beat, so the glow
## visibly MOVES from one of them to the other instead of each just flaring in
## place.
##
## Awaits only the crossing, and returns on impact — the burst plays on
## afterwards under its own tween. That way the caller regains control at the
## exact frame the gift lands, which is when the ability and the player's flash
## belong. This node stays cosmetic and never reaches into the player.
func give_to(target: Node2D) -> void:
	if target == null:
		return
	var gift := _make_gift()
	var core: Sprite2D = gift.get_node("Core")
	var toward := signf(target.global_position.x - _rumi.global_position.x)
	if toward == 0.0:
		toward = 1.0
	var from := _rumi.global_position \
		+ Vector2(toward * gift_source_offset.x, gift_source_offset.y)
	var to := target.global_position + gift_target_offset
	gift.global_position = from

	var t := create_tween().set_parallel()
	# Straight lerp plus a sine lift — one sine hump over the crossing, so the
	# mote leaves and arrives level and is highest halfway.
	t.tween_method(func(k: float) -> void:
			var p := from.lerp(to, k)
			p.y -= sin(k * PI) * gift_arc
			gift.global_position = p,
		0.0, 1.0, gift_travel_time) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	t.tween_property(gift, "energy", gift_energy, gift_travel_time * 0.3)
	t.tween_property(core, "scale", Vector2.ONE * gift_core_scale, gift_travel_time * 0.3) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_property(_rumi_light, "energy", gift_cost, gift_travel_time) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	await t.finished

	# Impact: bloom outward and die. Not awaited — see the note above.
	var burst := create_tween().set_parallel()
	burst.tween_property(gift, "texture_scale", gift_burst_radius / TEXTURE_RADIUS,
		gift_burst_time).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	burst.tween_property(gift, "energy", 0.0, gift_burst_time) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	burst.tween_property(core, "scale", Vector2.ONE * gift_core_scale * 3.0, gift_burst_time) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	burst.tween_property(core, "modulate:a", 0.0, gift_burst_time) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	burst.chain().tween_callback(gift.queue_free)


## The mote itself: a light for the pool it throws, with a drawn core inside it
## so it stays visible in a bright room. Built per gift and freed with its burst,
## so nothing lingers in the scene between beats. A child of the trigger, so it
## can't outlive it.
func _make_gift() -> PointLight2D:
	var gift := PointLight2D.new()
	gift.name = "Gift"
	gift.texture = LIGHT_TEXTURE
	gift.texture_scale = gift_radius / TEXTURE_RADIUS
	gift.color = RUMI_GOLD
	gift.energy = 0.0
	var core := Sprite2D.new()
	core.name = "Core"
	core.texture = MOTE_TEXTURE
	core.z_index = 1  # the foreground band — over Rumi, the player and the tiles
	core.scale = Vector2.ZERO  # blooms open as it leaves his sleeve
	gift.add_child(core)
	add_child(gift)
	return gift


## Rumi leaving is the cue for the story door to swing open onto the void.
## Scope to THIS room's doors only: LdtkWorld keeps every room in the Act loaded
## at once, so an unscoped group lookup would swing open doors in rooms the
## player hasn't reached yet. Same parent = same room's Entities layer.
func arm_room_door() -> void:
	for door in get_tree().get_nodes_in_group("story_door"):
		if door is LdtkDoor and door.get_parent() == get_parent():
			door.arm()
