@tool
class_name MoonWindow
extends Node2D
## The office window, and whatever the moon is doing tonight.
##
## Shared 16px emissive disc and steel sash. The paired LampFixture lights
## the office while CanvasModulate continues to determine its ambient mood.
## MoonVisibility assigns one fixed source to each room, never to camera pans.
## Eclipse exports retain the authored totality, blood moon, and dawn ramp.

@export var moon_color := Color(1, 1, 1):
	set(v): moon_color = v; _apply()
## The patch of sky behind it.
@export var sky_color := Color(0.05, 0.06, 0.13):
	set(v): sky_color = v; _apply()

@export_group("Eclipse")
## Colour of the umbra lying across the disc. Violet-blue is what sells a blood
## moon: the red is what gets through the Earth's atmosphere, and the cold edge
## is the part of the shadow that does not.
@export var shadow_color := Color(0.34, 0.2, 0.62):
	set(v): shadow_color = v; _apply()
## How much of it there is, 0..1. 0 is a clear moon.
@export_range(0.0, 1.0) var shadow_amount := 0.0:
	set(v): shadow_amount = v; _apply()
## Colour of the ring of lit air around the disc.
@export var halo_color := Color(0.55, 0.35, 0.95):
	set(v): halo_color = v; _apply()
## How strong that ring is, 0..1. 0 is no halo.
@export_range(0.0, 1.0) var halo_amount := 0.0:
	set(v): halo_amount = v; _apply()


@export_group("Turning")
## What this window BECOMES when eclipse() is called. The defaults are room 12's
## blood moon exactly, because the one thing that calls it is the Darkshang
## encounter in room 11 — the moon he watches turn is the moon he then runs the
## whole escape row underneath, and the two have to be the same object.
@export var blood_moon_color := Color(0.72, 0.17, 0.15)
@export var blood_sky_color := Color(0.055, 0.03, 0.105)
@export_range(0.0, 1.0) var blood_shadow_amount := 0.85
@export_range(0.0, 1.0) var blood_halo_amount := 0.75
## The disc at TOTALITY, before any red arrives. Cold and drained: an eclipse
## goes dark before it goes red, and skipping that is what makes a crossfade
## read as someone turning a dial rather than as something happening.
@export var totality_moon_color := Color(0.34, 0.36, 0.44)

## The paired light's blood values, and how far it dips at totality.
##
## The LIGHT's targets live on the WINDOW because they are one thing (LIGHTING.md
## — "two nodes that must stay together"), and because both have to ride a SINGLE
## tween: the whole effect is the room going dark a beat before the sky goes red,
## and two tweens racing to express that is two ways for it to desync.
@export var blood_glow_color := Color(0.86, 0.16, 0.26)
@export var blood_glow_energy := 1.7
@export var blood_glow_scale := 2.2
## Colour the moonlight drains to on its way out — slate, not black, so the room
## reads as losing its light rather than as a light being switched off.
@export var totality_glow_color := Color(0.42, 0.44, 0.55)
@export var totality_glow_energy := 0.3

## How the turn is divided. Crossing is the umbra coming over, then a held beat
## of totality, then the red blooming — as fractions of the duration passed to
## eclipse(). They must leave room for each other; the bloom gets the remainder.
@export_range(0.1, 0.8) var crossing_share := 0.5
@export_range(0.0, 0.4) var totality_share := 0.12

@export_range(0.0, 1.0) var night_progress := 0.0:
	set(v): night_progress = v; _apply()

var _turn: Tween
var _moon_selected := true

func moon_local_rect() -> Rect2:
	return $Moon.transform * $Moon.get_rect()

func set_moon_selected(selected: bool) -> void:
	_moon_selected = selected
	_apply()


func _ready() -> void:
	if not Engine.is_editor_hint():
		add_to_group("moon_candidates")
		_moon_selected = false
	$Stars.configure([Rect2(-19, -26, 38, 52)], str(get_path()))
	_apply()


## Turn this moon to blood over `duration` seconds, dragging its paired light
## with it. `duration` 0 snaps — which is what a save resumed after the encounter
## needs, since the turn already happened and replaying it would be a cutscene
## nobody asked for.
##
## THREE STAGES, and the middle one is the whole reason this is not a crossfade:
##
##   1. CROSSING — the umbra creeps over the disc and the room's light drains to
##      slate and dies down. The moon goes grey, not red. Ease-in, so it starts
##      as something you might not have noticed and ends as something you cannot
##      look away from.
##   2. TOTALITY — everything holds. The room is at its darkest and there is no
##      colour in the sky at all. This beat is what the red then arrives INTO.
##   3. BLOOMING — the red comes up in the disc, the violet halo opens around it,
##      and the light comes back wrong. Ease-out: it floods in and settles.
##
## Kills any turn already running, so calling it twice cannot leave two tweens
## fighting over the same six properties.
func eclipse(duration: float, glow: LampFixture = null) -> void:
	if _turn != null and _turn.is_valid():
		_turn.kill()
	if duration <= 0.0:
		_snap_to_blood(glow)
		return

	var crossing := duration * crossing_share
	var held := duration * totality_share
	var blooming := maxf(duration - crossing - held, 0.01)

	_turn = create_tween()
	_turn.set_parallel(true)

	# 1. the crossing
	_stage(_turn, 0.0, self, "shadow_amount", blood_shadow_amount, crossing,
		Tween.EASE_IN, Tween.TRANS_CUBIC)
	_stage(_turn, 0.0, self, "moon_color", totality_moon_color, crossing,
		Tween.EASE_IN, Tween.TRANS_SINE)
	_stage(_turn, 0.0, self, "sky_color", blood_sky_color, crossing,
		Tween.EASE_IN, Tween.TRANS_SINE)
	if glow != null:
		_stage(_turn, 0.0, glow, "light_color", totality_glow_color, crossing,
			Tween.EASE_IN, Tween.TRANS_SINE)
		_stage(_turn, 0.0, glow, "light_energy", totality_glow_energy, crossing,
			Tween.EASE_IN, Tween.TRANS_CUBIC)

	# 2. totality is the GAP — nothing is tweened across it, which is what makes
	#    it a held beat rather than a slow one.
	var after := crossing + held

	# 3. the bloom
	_stage(_turn, after, self, "moon_color", blood_moon_color, blooming,
		Tween.EASE_OUT, Tween.TRANS_QUAD)
	_stage(_turn, after, self, "halo_amount", blood_halo_amount, blooming,
		Tween.EASE_OUT, Tween.TRANS_SINE)
	if glow != null:
		_stage(_turn, after, glow, "light_color", blood_glow_color, blooming,
			Tween.EASE_OUT, Tween.TRANS_QUAD)
		# The light comes back LATE and fast — the sky is already red before the
		# room is lit by it, which is the order it would really happen in.
		_stage(_turn, after + blooming * 0.25, glow, "light_energy",
			blood_glow_energy, blooming * 0.75, Tween.EASE_OUT, Tween.TRANS_CUBIC)
		_stage(_turn, after, glow, "light_scale", blood_glow_scale, blooming,
			Tween.EASE_OUT, Tween.TRANS_SINE)


## One property, starting `delay` in. Parallel tweens all start at zero, so the
## staging is expressed as a delay per property rather than as chained steps —
## which is what lets stage 3 overlap itself (the light lags the sky).
func _stage(tween: Tween, delay: float, target: Object, property: String,
		to: Variant, time: float, ease_mode: Tween.EaseType,
		trans: Tween.TransitionType) -> void:
	tween.tween_property(target, property, to, time) \
		.set_delay(delay).set_ease(ease_mode).set_trans(trans)


## Already-turned, with no animation — a save resumed after the encounter.
func _snap_to_blood(glow: LampFixture) -> void:
	moon_color = blood_moon_color
	sky_color = blood_sky_color
	shadow_amount = blood_shadow_amount
	halo_amount = blood_halo_amount
	if glow != null:
		glow.light_color = blood_glow_color
		glow.light_energy = blood_glow_energy
		glow.light_scale = blood_glow_scale


## Push the exports onto the children. Guards on the node not being in the tree
## yet, so the setters above are safe to fire before _ready.
func _apply() -> void:
	if not is_inside_tree():
		return
	$Stars.visible = not _moon_selected
	var sky := get_node_or_null("SkyPatch") as ColorRect
	var moon := get_node_or_null("Moon") as Sprite2D
	var shadow := get_node_or_null("Shadow") as Sprite2D
	var halo := get_node_or_null("Halo") as Sprite2D
	if sky != null:
		sky.color = sky_color
	if moon != null:
		moon.position = Vector2(roundf(lerpf(-7.0, -11.0, night_progress)), -7)
		moon.scale = Vector2(16, 16) / moon.texture.get_size()
		moon.modulate = moon_color
		moon.visible = _moon_selected
	if shadow != null:
		shadow.position = moon.position
		shadow.scale = moon.scale
		shadow.modulate = Color(shadow_color, shadow_amount)
		shadow.visible = _moon_selected and shadow_amount > 0.0
	if halo != null:
		halo.position = moon.position
		halo.scale = moon.scale
		halo.modulate = Color(halo_color if halo_amount > 0 else Color(0.48, 0.7, 1), maxf(halo_amount, 0.22))
		halo.visible = _moon_selected

	# The sky opening is behind the sash. Neither atmosphere nor eclipse can
	# cover the wall even if a future moon is moved beyond the glass bounds.
	for layer in [moon, shadow, halo]:
		if layer != null:
			WindowAperture.apply(layer, [Rect2(-19, -26, 38, 52)])
