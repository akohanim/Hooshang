class_name CollapseAmbience
extends Node2D
## The building coming down around him, for the whole length of the escape.
##
## Not the same thing as RoomCollapse. That is a one-off EVENT — the props in a
## room let go, once, on the frame he walks in. This is the ambience underneath
## it: a room that keeps shuddering and keeps shedding dust the entire time he is
## in it, getting worse the further he gets. RoomCollapse is the crash; this is
## the groaning either side of it.
##
## ONE INSTANCE, RE-TARGETED. Act1Beats keeps a single one of these and moves it
## to whichever room the player is in, rather than putting one in every room:
## twenty idle particle emitters all ticking in a world where every room is
## loaded at once is twenty emitters' worth of nothing, and the LDtk rooms are
## authored in the app where a Godot-side prefab cannot be placed anyway.
##
## EVERYTHING SCALES OFF `intensity`, 0..1. Act1Beats maps room number to it, so
## the ramp lives with the story rather than being spread across twenty tuned
## instances. 0 is silence; 1 is the last room before he is out.
##
## THREE LAYERS, because one was not enough. This started as a single decaying
## rattle fired on a jittered timer, ramped by raising its strength — and a ramp
## made only of "the same noise, louder" is not one you can feel. What is here
## now is:
##
##   1. THE BED — a constant low rattle that never stops, but only once the
##      building is far enough gone (`bed_from`). Early rooms are events with
##      real silence between them; the last few never sit still. That change of
##      TEXTURE is most of what reads as the collapse accelerating.
##   2. THE EVENTS — four distinct kinds (a distant SETTLE, a sharp near CRACK,
##      a long low ROLL, and the big one-off JOLT), picked by weights that cross
##      over as `intensity` rises, and free to OVERLAP: a crack landing inside a
##      roll is a different sound from either of them alone.
##   3. THE DEBRIS — the ceiling shedding constantly, plus a burst thrown loose
##      by each of the heavier hits, over the player rather than over the whole
##      room. Before, the shaking and the falling were two systems that merely
##      ran at the same time and nothing you saw fall was the thing you felt.
##
## ALL OF IT GOES THROUGH `Player.tremor()`, never `rumble()`. rumble() and
## shake() share one tween in juice.gd — a second call kills the first — so an
## ambience built on them would delete the jolt of a room actually giving way
## (Act1Beats._play_collapse) and be deleted by it in turn. The tremor channel is
## a level, summed here and handed over once a frame, and it stacks.

## The four things that can happen. Kinds, not strengths: see the header.
enum Kind { SETTLE, CRACK, ROLL, JOLT }

@export_group("The tremor")
## Peak camera offset of a full-strength (1.0) event at intensity 1, in px. Every
## event's own shake is a multiple of this, so it is the single knob that moves
## the whole ambience up or down.
@export var max_shake := 1.15
## Hard ceiling on the SUMMED tremor, per axis, in px. Events overlap, and
## without it a jolt landing inside a roll on top of the bed out-shakes a room
## actually coming down. Set to exactly Act1Beats.collapse_shake (1.6): at its
## very worst the background may match the rattle of a room giving way, and it
## can never reach the JOLT of one (collapse_jolt, 2.4), which stays the single
## biggest thing that has happened to him.
##
## Per axis and not as a distance, matching Juice.rumble — so the worst case is
## the corner of that box, 1.6 * sqrt(2), still comfortably under 2.4.
@export var shake_ceiling := 1.6
## The constant rattle under everything else at intensity 1, in px.
@export var bed_shake := 0.42
## Intensity below which there is no constant rattle at all. This is the line
## between "a building that shudders sometimes" and "a building that is coming
## down", and crossing it partway along the escape is deliberate.
@export var bed_from := 0.35
## How much the bed breathes, 0..1 — it swells and sinks instead of sitting at
## one level, so even the constant is not constant.
@export_range(0.0, 1.0) var bed_breath := 0.45
## How long one of those swells takes, in seconds. Deliberately not a round
## number and nothing else's period, so it never lines up with the events.
@export var bed_breath_time := 3.7

@export_group("Timing")
## Gap between events at intensity 0 and at intensity 1, in seconds. They come
## much closer together as he goes, which — with events that now outlast the gap
## — is what turns discrete shudders into one continuous failure.
@export var quiet_gap := 5.8
@export var busy_gap := 1.15
## Random spread on that gap, as a fraction of it. A fraction rather than a fixed
## number of seconds so the early rooms (long gaps) are wildly irregular while
## the late ones stay dense — a perfectly periodic tremor reads as a mechanism.
@export_range(0.0, 1.0) var gap_jitter := 0.55
## Most events allowed to run at once. Overlap is the point, but past this the
## sum is clamped by shake_ceiling anyway and the extras cost work for nothing.
@export var max_events := 4

@export_group("Events")
@export_subgroup("Settle")
## Peak shake as a multiple of max_shake — low. This is distance, not force: a
## floor giving somewhere far below him. Not lower: the first rooms are made
## almost entirely of these, and under about 0.15px of actual offset the pixel
## snapping rounds a settle away to nothing and the ramp starts at silence.
@export var settle_shake := 0.55
## How long one lasts, in seconds. Long: it is a groan, not a hit.
@export var settle_time := 1.9
## Seconds to reach that peak. Slow, so it arrives rather than strikes.
@export var settle_attack := 0.6
## How sharply it falls away after the peak (higher = faster off).
@export var settle_decay := 1.2
## How often it is picked, at intensity 0 (x) and at intensity 1 (y). The early
## rooms are almost entirely this.
@export var settle_weight := Vector2(7.0, 1.5)

@export_subgroup("Crack")
## Peak shake ×max_shake — the reference event. Something structural letting go
## close enough to be startling.
@export var crack_shake := 1.0
## How long one lasts, in seconds. Over almost before you have placed it.
@export var crack_time := 0.5
## Seconds to reach that peak. Near zero: a crack has no approach.
@export var crack_attack := 0.03
## How sharply it falls away after the peak (higher = faster off).
@export var crack_decay := 2.2
## How often it is picked, at intensity 0 (x) and at intensity 1 (y).
@export var crack_weight := Vector2(2.0, 5.0)

@export_subgroup("Roll")
## Peak shake ×max_shake — a whole floor moving somewhere, felt more than heard.
@export var roll_shake := 0.68
## How long one lasts, in seconds. The longest of the four, so other events land
## on top of it rather than after it.
@export var roll_time := 2.8
## Seconds to reach that peak. A swell, not an edge.
@export var roll_attack := 1.0
## How sharply it falls away after the peak (higher = faster off).
@export var roll_decay := 0.9
## How often it is picked, at intensity 0 (x) and at intensity 1 (y).
@export var roll_weight := Vector2(1.0, 4.0)

@export_subgroup("Jolt")
## Peak shake ×max_shake — the big one-off. The only event that comes near the
## collapse's own rattle (Act1Beats.collapse_shake, 1.6), and it stays under it.
@export var jolt_shake := 1.3
## How long one lasts, in seconds. Short: all of it is the first quarter second.
@export var jolt_time := 0.85
## Seconds to reach that peak. Effectively instant — this one is an impact.
@export var jolt_attack := 0.02
## How sharply it falls away after the peak (higher = faster off).
@export var jolt_decay := 3.0
## How often it is picked, at intensity 0 (x) and at intensity 1 (y).
@export var jolt_weight := Vector2(0.0, 3.5)
## Intensity below which a jolt is never picked at all. The big hits have to
## START somewhere: one in room 12 would spend the whole ramp's headroom in the
## first room of it and leave room 21 with nothing new to do.
@export var jolt_from := 0.45

@export_group("Debris")
## Dust motes in the air at intensity 1, and paper scraps. Dust is the constant
## and paper is the punctuation, so there is far more of the former.
@export var max_dust := 34
@export var max_paper := 9
## Fraction of `intensity` below which nothing falls at all. Without it room 12
## has a visible drizzle from the first frame, and the ramp has nowhere to
## start from.
@export var debris_floor := 0.06
## How far above the room's ceiling the debris starts, in px. Off screen, so
## motes fade in from nothing rather than popping into existence mid-air.
@export var spawn_above := 10.0
## Extra fall speed at intensity 1, as a fraction of the base gravity. Late
## debris comes down harder as well as thicker — unlike `amount`, gravity can be
## changed on a live emitter without restarting it.
@export var debris_gravity_boost := 0.7
## Motes and scraps thrown loose by a single full-strength hit, at intensity 1.
@export var burst_dust := 16
@export var burst_paper := 5

@export_subgroup("Masonry")
## Chunks of the wall itself. Driven by its OWN strength (see play_in's
## `masonry`), not by `intensity`, because brick starts a room later than dust
## does: room 12 is where he meets the shadow and the building only groans, and
## 13 is the first room that actually comes apart around him.
##
## Deliberately tiny numbers. Dust and paper are weather; a brick is an EVENT,
## and a steady rain of masonry reads as confetti rather than as a building
## failing. Most of the brick the player sees should arrive on a hit — see
## `burst_brick` — with this as the occasional loose piece between them.
@export var max_brick := 4
## Masonry strength below which no brick falls at all.
@export var brick_floor := 0.05
## Chunks knocked out by one full-strength hit at masonry 1.
@export var burst_brick := 5
## Event shake (×max_shake) above which a hit brings brick down. LOWER than
## `debris_burst_from`: a crack hard enough to be worth flinching at is hard
## enough to take a piece of wall with it, and holding brick back until the very
## biggest hits made it look like a bug when it did fire.
@export var brick_burst_from := 0.5
## Event shake (×max_shake) above which a hit knocks debris loose at all. Above
## settle, below roll: distant groaning drops nothing on your head.
@export var debris_burst_from := 0.6
## How wide that burst is, in px, centred on the player. Narrow on purpose — it
## fell because of the thing that just hit, so it falls where he is standing.
@export var burst_width := 90.0

const DUST_TEXTURE := preload("res://assets/props/debris_dust.png")
const PAPER_TEXTURE := preload("res://assets/props/debris_paper.png")
const BRICK_TEXTURE := preload("res://assets/props/debris_brick.png")

## Base fall speeds, held as constants because debris_gravity_boost scales them
## per room and the emitter's own value is no longer the original.
const DUST_GRAVITY := 26.0
const PAPER_GRAVITY := 44.0
## Brick falls like brick — more than three times paper's rate. This is most of
## what tells the eye which material it is looking at, well before it can make
## out an 8px sprite: dust hangs, paper flutters, masonry DROPS.
const BRICK_GRAVITY := 155.0
## How long a chunk lives. Tuned so it fades out around floor level rather than
## sailing on through it — a room is 192px tall and 0.5 x 155 x 1.5^2 is 174.
const BRICK_LIFETIME := 1.5

## Foreground band (STYLE_GUIDE z-index: -1 background, 0 playable, 1 fore).
## Debris falls IN FRONT of Hooshang — it is between the camera and the room,
## which is what sells it as being in the air rather than painted on the wall.
const DEBRIS_Z := 1

var intensity := 0.0

var _dust: CPUParticles2D
var _paper: CPUParticles2D
var _burst_dust: CPUParticles2D
var _burst_paper: CPUParticles2D
var _brick: CPUParticles2D
var _burst_brick: CPUParticles2D
## How much of the wall this room is shedding, 0..1. Set by play_in and kept
## apart from `intensity` — see the Masonry exports.
var _masonry := 0.0
var _rect := Rect2()
var _next_event := 0.0
## Everything currently shaking, as {kind, age, time, peak, attack, decay}. Their
## envelopes are summed each frame — see _process.
var _events: Array[Dictionary] = []
## Clock for the bed's breathing. Free-running; nothing resets it, because a bed
## that restarted its swell on every room change would announce the doorway.
var _breath := 0.0
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()
	_dust = _make_emitter(DUST_TEXTURE, 3.4, DUST_GRAVITY, 9.0, 0.55)
	_paper = _make_emitter(PAPER_TEXTURE, 2.6, PAPER_GRAVITY, 22.0, 1.0)
	_tumble(_paper)
	# The burst pair. Separate emitters rather than a spike in the steady ones,
	# because `amount` cannot be raised on a live system without restarting it and
	# visibly clearing everything already falling (see play_in). One-shot systems
	# are restarted every time by design, so they are free of that.
	_burst_dust = _make_emitter(DUST_TEXTURE, 2.2, DUST_GRAVITY * 2.2, 26.0, 0.6)
	_burst_paper = _make_emitter(PAPER_TEXTURE, 2.0, PAPER_GRAVITY * 1.6, 34.0, 1.0)
	_tumble(_burst_paper)
	_brick = _make_emitter(BRICK_TEXTURE, BRICK_LIFETIME, BRICK_GRAVITY, 6.0, 1.0)
	_burst_brick = _make_emitter(BRICK_TEXTURE, BRICK_LIFETIME * 0.9,
		BRICK_GRAVITY * 1.25, 30.0, 1.15)
	_tumble_heavy(_brick)
	_tumble_heavy(_burst_brick)
	for p in [_burst_dust, _burst_paper, _burst_brick]:
		p.one_shot = true
		p.explosiveness = 0.9
		p.preprocess = 0.0   # a burst begins when it is thrown, not mid-fall
	_arm_event()


## Point the ambience at a room, at a given strength. Called on every room
## change; `intensity` 0 stops everything and leaves the room clean.
##
## `masonry` is a SECOND strength, for brick and mortar only, because the wall
## starts coming apart a room later than the dust does — Act1Beats owns which
## room means what, and passing one number for both would force them to start
## together.
func play_in(rect: Rect2, strength: float, masonry := 0.0) -> void:
	_rect = rect
	intensity = clampf(strength, 0.0, 1.0)
	_masonry = clampf(masonry, 0.0, 1.0)
	global_position = Vector2(rect.get_center().x, rect.position.y - spawn_above)
	var live := intensity > debris_floor
	for p in [_dust, _paper]:
		# The emission box spans the room's full width, one flat line along the
		# ceiling — debris comes off the whole ceiling, not out of a point.
		p.emission_rect_extents = Vector2(rect.size.x * 0.5, 1.0)
		p.emitting = live
	if live:
		# `amount` cannot be changed while emitting without restarting the
		# system, which visibly clears every particle already in the air. Setting
		# it before `emitting` above would restart on every room change, so the
		# count is folded into the lifetime-scaled ratio instead.
		_dust.amount = maxi(int(round(max_dust * intensity)), 1)
		_paper.amount = maxi(int(round(max_paper * intensity)), 1)
		var faster := 1.0 + debris_gravity_boost * intensity
		_dust.gravity = Vector2(0.0, DUST_GRAVITY * faster)
		_paper.gravity = Vector2(0.0, PAPER_GRAVITY * faster)

	# Brick keeps its own emitting flag and its own strength: a room can be full
	# of dust and shedding nothing structural, which is exactly room 12.
	var shedding := _masonry > brick_floor
	_brick.emission_rect_extents = Vector2(rect.size.x * 0.5, 1.0)
	_brick.emitting = shedding
	if shedding:
		_brick.amount = maxi(int(round(max_brick * _masonry)), 1)

	# A doorway is a clean break: nothing shaking follows him into the next room,
	# and room 22 (intensity 0) goes still on the frame he arrives in it.
	_events.clear()
	_arm_event()
	set_process(intensity > 0.0)
	if intensity <= 0.0:
		_push_tremor(_player(), 0.0)


func _process(delta: float) -> void:
	if intensity <= 0.0:
		return
	var player := _player()
	# Never during a cutscene. A room's own collapse runs a much bigger jolt and
	# rattle of its own (Act1Beats._play_collapse), and this must not be arguing
	# underneath it — so the ambience does not duck, it STOPS, and starts again
	# from a fresh gap once he has his controls back. That also buys a beat of
	# stillness after a room has fallen, which is worth more than continuity.
	if player == null or player.input_locked:
		if not _events.is_empty():
			_events.clear()
			_arm_event()
		_push_tremor(player, 0.0)
		return

	_breath += delta
	_next_event -= delta
	if _next_event <= 0.0:
		_arm_event()
		_fire_event(player)

	# The bed, plus every event still running. Dictionaries are references, so
	# ageing the one pulled out of the array ages the one in it.
	var amount := _bed_amplitude()
	var i := 0
	while i < _events.size():
		var event := _events[i]
		event["age"] += delta
		if event["age"] >= float(event["time"]):
			_events.remove_at(i)
			continue
		amount += _envelope(event)
		i += 1
	_push_tremor(player, minf(amount, shake_ceiling))


# --------------------------------------------------------------- the bed ----

## The constant rattle under everything, once the building is far enough gone.
## Fades UP from nothing at `bed_from` rather than switching on, so the room he
## first hears it in is not the room it announces itself in.
func _bed_amplitude() -> float:
	if intensity <= bed_from:
		return 0.0
	var t := (intensity - bed_from) / maxf(1.0 - bed_from, 0.001)
	var swell := 0.5 + 0.5 * sin(_breath * TAU / maxf(bed_breath_time, 0.01))
	return bed_shake * t * (1.0 - bed_breath * swell)


# ------------------------------------------------------------ the events ----

## Start one, and shed debris if it was heavy enough to knock any loose.
func _fire_event(player: Player) -> void:
	if _events.size() >= max_events:
		return
	var kind := _pick_kind()
	var shape := _shape(kind)
	var shake := float(shape["shake"])
	_events.append({
		"kind": kind,
		"age": 0.0,
		"time": shape["time"],
		"attack": shape["attack"],
		"decay": shape["decay"],
		# Scaled by intensity as well as by the kind: a crack in room 13 is the
		# same SHAPE as a crack in room 21 and a fraction of the size.
		"peak": shake * max_shake * intensity,
	})
	# The LOWEST of the material thresholds — _burst gates each one itself, and
	# gating here on the dust's alone would mean brick never fired below it.
	if shake >= minf(debris_burst_from, brick_burst_from):
		_burst(player, shake)


## Which KIND of thing happens next.
##
## The weights cross over as he goes: the early rooms are nearly all distant
## settling, the last few are cracks and rolls with jolts through them. Varying
## the kind is what the ramp was missing — a single event type at a rising volume
## is one sound getting louder, and the ear stops hearing it by the third room.
func _pick_kind() -> Kind:
	var weights := {
		Kind.SETTLE: _weight(settle_weight),
		Kind.CRACK: _weight(crack_weight),
		Kind.ROLL: _weight(roll_weight),
		Kind.JOLT: (0.0 if intensity < jolt_from else _weight(jolt_weight)),
	}
	var total := 0.0
	for w in weights.values():
		total += w
	if total <= 0.0:
		return Kind.SETTLE
	var roll := _rng.randf() * total
	for kind in weights:
		roll -= weights[kind]
		if roll <= 0.0:
			return kind
	return Kind.SETTLE


## A kind's weight right now: x at intensity 0, y at intensity 1. Floored at 0 so
## a pair that leans hard one way cannot go negative and eat another kind's share.
func _weight(pair: Vector2) -> float:
	return maxf(lerpf(pair.x, pair.y, intensity), 0.0)


## The four kinds' numbers, in one place. A dictionary rather than four branches
## spread through _fire_event, so adding a fifth kind is one entry and one weight.
func _shape(kind: Kind) -> Dictionary:
	match kind:
		Kind.CRACK:
			return {"shake": crack_shake, "time": crack_time,
				"attack": crack_attack, "decay": crack_decay}
		Kind.ROLL:
			return {"shake": roll_shake, "time": roll_time,
				"attack": roll_attack, "decay": roll_decay}
		Kind.JOLT:
			return {"shake": jolt_shake, "time": jolt_time,
				"attack": jolt_attack, "decay": jolt_decay}
		_:
			return {"shake": settle_shake, "time": settle_time,
				"attack": settle_attack, "decay": settle_decay}


## One event's contribution right now: up over `attack`, then away over whatever
## is left, shaped by `decay`. Nothing is ever cut off at full strength — a
## tremor that stops mid-swing reads as a bug in the effect rather than as the
## building settling, which is the same reason Juice.rumble decays.
func _envelope(event: Dictionary) -> float:
	var age := float(event["age"])
	var attack := float(event["attack"])
	var peak := float(event["peak"])
	if age < attack:
		# Eased even for the sharp kinds: a rise that lands inside one frame at
		# 320x180 reads as a dropped frame, not as an impact.
		return peak * smoothstep(0.0, 1.0, age / maxf(attack, 0.001))
	var u := (age - attack) / maxf(float(event["time"]) - attack, 0.001)
	return peak * pow(1.0 - clampf(u, 0.0, 1.0), float(event["decay"]))


func _arm_event() -> void:
	var gap := lerpf(quiet_gap, busy_gap, intensity)
	_next_event = gap * _rng.randf_range(1.0 - gap_jitter, 1.0 + gap_jitter)


# ------------------------------------------------------------ the debris ----

## Debris shaken loose by one particular hit, over the player rather than over
## the whole ceiling. This is what ties the two halves of the effect together:
## the steady fall is weather, but a burst has a CAUSE you just felt.
## Each material gates ITSELF here rather than the caller gating all of them,
## because their thresholds differ — brick comes loose at a smaller hit than the
## one that raises paper. Called whenever a hit clears the lowest of them.
func _burst(player: Player, shake: float) -> void:
	# Kept off the room's own walls, so a hit taken in a doorway does not throw
	# half its dust through solid tiles.
	var here := clampf(player.global_position.x,
		_rect.position.x + burst_width * 0.5, _rect.end.x - burst_width * 0.5)
	for p in [_burst_dust, _burst_paper, _burst_brick]:
		p.emission_rect_extents = Vector2(burst_width * 0.5, 1.0)
		p.position = Vector2(here - global_position.x, 0.0)

	if shake >= debris_burst_from and intensity > debris_floor:
		var force := shake * intensity
		_burst_dust.amount = maxi(int(round(burst_dust * force)), 1)
		_burst_paper.amount = maxi(int(round(burst_paper * force)), 1)
		_burst_dust.restart()
		_burst_paper.restart()

	# Brick has its own threshold and its own strength, so a hit can raise dust
	# in a room that is not yet losing pieces of itself — which is room 12.
	if shake >= brick_burst_from and _masonry > brick_floor:
		_burst_brick.amount = maxi(int(round(burst_brick * shake * _masonry)), 1)
		_burst_brick.restart()


func _make_emitter(texture: Texture2D, lifetime: float, gravity: float,
		spread_x: float, scale_max: float) -> CPUParticles2D:
	var p := CPUParticles2D.new()
	p.texture = texture
	p.z_index = DEBRIS_Z
	p.lifetime = lifetime
	p.preprocess = lifetime          # already falling when a room is entered
	p.emitting = false
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	p.direction = Vector2.DOWN
	p.spread = 12.0
	p.gravity = Vector2(0.0, gravity)
	p.initial_velocity_min = 2.0
	p.initial_velocity_max = spread_x
	p.scale_amount_min = scale_max * 0.6
	p.scale_amount_max = scale_max
	# Fade out at the end of the fall rather than vanishing at a hard edge —
	# these land in the middle of a lit room as often as in the dark.
	var ramp := Gradient.new()
	ramp.set_color(0, Color(1, 1, 1, 0))
	ramp.set_color(1, Color(1, 1, 1, 0))
	ramp.add_point(0.12, Color(1, 1, 1, 1))
	ramp.add_point(0.75, Color(1, 1, 1, 1))
	p.color_ramp = ramp
	add_child(p)
	return p


## Paper tumbles; dust does not. A mote spinning is the one thing that makes it
## stop reading as dust.
func _tumble(p: CPUParticles2D) -> void:
	p.angular_velocity_min = -220.0
	p.angular_velocity_max = 220.0
	p.damping_min = 4.0
	p.damping_max = 12.0


## Brick tumbles too, but nothing like paper: slower, and it KEEPS turning.
## Paper's high damping is what makes it flutter and settle; a lump of masonry
## has momentum and nothing to catch the air with, so the damping is almost off.
func _tumble_heavy(p: CPUParticles2D) -> void:
	p.angular_velocity_min = -150.0
	p.angular_velocity_max = 150.0
	p.damping_min = 0.0
	p.damping_max = 1.5


# -------------------------------------------------------------- plumbing ----

func _player() -> Player:
	return get_tree().get_first_node_in_group("player") as Player


## Hand the summed amplitude to the camera. Deliberately Player.tremor() and not
## Player.rumble(): rumble shares one tween with shake(), so calling it twice
## kills the first — an ambience built on it would delete the jolt of a room
## giving way and be deleted by it in turn. tremor() is a level, held until it is
## set again, which is why this is safe to call every single frame.
func _push_tremor(player: Player, amount: float) -> void:
	if player != null:
		player.tremor(amount)
