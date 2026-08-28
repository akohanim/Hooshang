@tool
class_name DarkThought
extends Hazard
## A dark thought: a small black cloud with a red rim, drifting a repeating path
## through the air and lethal to touch. Same rules as every other Hazard — it IS
## a Hazard, so layer, mask and the kill itself are inherited and cannot drift
## apart from the red greybox boxes. All this adds is a path, a face and a light.
##
## THE ONE ENTITY WITH FIELDS, and deliberately not four like the spike strips.
## Those split per direction because direction there is a binary you can forget
## to set and the failure is silent — spikes growing out of a ceiling upside
## down. Here the motion is NUMBERS: amplitude, speed, phase. Tuning belongs on
## the instance (see _build_slide_zone), because two thoughts in one room can
## legitimately want different paths, which is exactly the case an
## entity-per-variant cannot serve — and a thought whose mode nobody set still
## visibly drifts, so there is no silent failure to protect against.
##
## Drop one in LDtk as a `DarkThought` and fill in Motion / Amplitude / Speed /
## Phase / Clockwise. The point you place is the CENTRE of the path in all three
## modes — see `_offset`.
##
## Art: tools/gen_dark_thought.py.

## Which path it walks. VERTICAL and HORIZONTAL swing +/- `amplitude` either side
## of where it was placed; CIRCLE orbits it at `amplitude` radius; LINEAR swings
## along an arbitrary `angle`.
enum Motion { VERTICAL, HORIZONTAL, CIRCLE, LINEAR }

## Which of the two it is. Same hazard, same path, same rim — the body is black
## or it is pale, and that is the whole difference. A field rather than a second
## class for exactly that reason: two scripts would be free to drift, and a
## thought that no longer moves like the other one is not a recolour any more.
enum Tone { DARK, LIGHT, GREY }

const SHEETS := {
	Tone.DARK: preload("res://assets/hazards/dark_thought.png"),
	Tone.LIGHT: preload("res://assets/hazards/light_thought.png"),
	Tone.GREY: preload("res://assets/hazards/grey_thought.png"),
}
const GLOW := preload("res://assets/light_radial.png")

## Frame size on the sheet, and how many there are.
const FRAME := Vector2(16.0, 16.0)
const FRAMES := 4
## Seconds per frame of the breath. Its own clock rather than a division of
## `speed`: the roil is the cloud being alive, and it should not slow to a stop
## because somebody wanted a lazy drift.
const FRAME_TIME := 0.14

## How the drawn cloud sits inside its 16px frame — 16 across, at most 13 down
## (see BREATH in tools/gen_dark_thought.py). This is the number DarkThought.tscn
## carries as `size`, written down here because it belongs to the art: Hazard's
## KILL_MARGIN then insets the lethal box 2px inside it on every side, so the
## thing that kills is smaller than the thing you can see, as everywhere else.
const ART := Vector2(16.0, 12.0)

@export var motion: Motion = Motion.VERTICAL
## Half the travel in px — the swing either side of the placed point, or the
## orbit radius when `motion` is CIRCLE.
@export var amplitude := 32.0
## Full cycles per second. One trip out and back, or one lap.
@export var speed := 1.0
## Where in the cycle it starts, 0..1. Set it per instance or two thoughts in
## one room move in lockstep and read as one object with a gap in it.
@export var phase := 0.0
## CIRCLE only: which way round it goes. On screen, where +Y points down.
@export var clockwise := true
## LINEAR only: the direction of travel in degrees. 0 = along +X (right),
## 90 = along +Y (down on screen). VERTICAL is LINEAR at 90, HORIZONTAL is
## LINEAR at 0 — those keep their own enum values for every already-placed
## thought.
@export var angle := 0.0

## Black cloud or pale one. Nothing else about the prop changes with it: the
## path, the speed, the glow and the kill box are all the same either way.
##
## BOTH TONES ARE DRAWN UNSHADED — see `_build_visual` for why the prop carries
## no light at all any more. What that buys here is that each sheet reaches the
## screen as painted: the pale body stays white instead of being turned red by a
## red light, and the black body stays black instead of being crushed to nothing
## by CanvasModulate 0.05. Measured in that exact setup, a white body renders
## (1.00, 0.32, 0.23) under a red light and (0.047, 0.047, 0.047) under none;
## neither is a thing a palette can fix.
@export var tone: Tone = Tone.DARK:
	set(value):
		tone = value
		_apply_tone()

## Whether it carries a halo at all. On by default, and on is what you want
## nearly always — a hazard you cannot see coming is not one a room can be built
## around. Turn it off for a thought that is meant to be found rather than
## avoided, or where several overlap and the room turns into one red smear.
##
## Settable from LDtk as `Glow` (1 on, 0 off — a number and not a checkbox, for
## the reason ldtk_add_dark_thought.py gives about `Clockwise`).
@export var glow := true:
	set(value):
		glow = value
		_apply_glow()

## Colour of the halo. Hot red, matching the rim the art is drawn with — the two
## are the same glow, and the SAME red for both tones, since "the same outline"
## is the point of the pale one.
@export var light_color := Color(1.0, 0.24, 0.16):
	set(value):
		light_color = value
		_apply_glow()
## Brightness of that halo. Low next to a room fixture (LIGHTING.md's recipes
## run 1.3-2.1) because this is a 16px prop and not a lamp: it has to be seen
## coming down a dark corridor without lighting the corridor.
@export var light_energy := 1.15:
	set(value):
		light_energy = value
		_apply_glow()
## Radius of the halo at 64px per 1.0, the whole project's scale (LIGHTING.md).
## 0.7 is a 45px pool — about three cells of warning either side of it. The
## texture is 128px, so this is its scale directly and the footprint is exactly
## what the PointLight2D this replaced threw.
@export var light_scale := 0.7:
	set(value):
		light_scale = value
		_apply_glow()

var _sprite: Sprite2D
var _halo: Sprite2D
## Where the importer put it. The path is measured from here and `reset()`
## returns to it, so nothing about this prop depends on where it currently is.
var _origin := Vector2.ZERO
## Seconds since it was placed or last reset. The path is a function of this and
## nothing else — see `_process`.
var _clock := 0.0


func _ready() -> void:
	super()
	add_to_group("dark_thought")
	_origin = position
	# @tool, so this runs in the editor too — where a prop that walked its own
	# path would drift away from the position the scene was saved with.
	set_process(not Engine.is_editor_hint())


## It does NOT come down when the room does.
##
## RoomCollapse.FALLS_UNDER is a list of TYPES and the check is `is`, so every
## Hazard subclass is dropped by default. A thought is not resting on anything —
## it is floating, which is the entire premise — so a collapse would sink it to
## the floor mid-beat and leave a hazard the room was built around sitting in the
## rubble on the only route through. The wall-mounted spike strips opt out of the
## same list for the same reason.
##
## Being anchored also means it goes on counting as ground for anything measuring
## a landing above it (see RoomCollapse._airborne_in) — harmless here, since it
## carries no collision on layer 1 for a ray to find.
func collapse_anchored() -> bool:
	return true


## The cloud, its halo, and nothing else.
##
## THE HALO IS PAINT, NOT A LIGHT — and it was a PointLight2D until the glows
## started blinking on and off from room to room. Both halves of that are worth
## writing down, because the rule it looks like it breaks is a real rule.
##
## WHY NOT A LIGHT. This renderer is gl_compatibility (project.godot; the web
## export needs it), and its 2D renderer lights any one canvas item from at most
## SIXTEEN lights. Measured by sweeping lights over a single item: 4 -> 4 lit,
## 8 -> 8, 12 -> 12, 16 -> 15, 20 -> 15, 24 -> 15, 32 -> 16. Past the cap the
## extra lights are dropped in silence — no warning, nothing in a log. A room
## with eight ceiling panels is already carrying sixteen lights (each panel
## spends two, a face and a pool), so every thought added to it was competing
## for a budget that had already run out, and WHICH lights lost changed as the
## thoughts travelled between tilemap chunks. That is the whole of "sometimes
## the glow is on, sometimes it is off": nothing about the prop was wrong.
##
## WHY PAINT IS ALLOWED HERE, when SunShaft, WallPattern and CeilingPanel each
## document that CanvasModulate 0.05 eats a painted glow. It eats a SHADED one.
## An UNSHADED CanvasItem is outside the modulate entirely — measured: the same
## white sprite renders 0.047 shaded and 1.000 unshaded under 0.05 — so an
## unshaded, additively blended halo arrives at full strength. It cannot be
## culled, it costs nothing from the room's light budget, and it hands that
## budget back to the fixtures that do need to be lights.
##
## What is given up is a light's one real advantage: a PointLight2D MULTIPLIES
## the surface under it, so its pool picks the brickwork out in red, while an
## additive halo lays red over whatever is there. At this size, on a 45px pool
## in a dark room, that is a difference you have to be looking for.
func _build_visual() -> void:
	# Behind the cloud, so the halo never washes over the rim it is meant to
	# be coming from.
	_halo = Sprite2D.new()
	_halo.name = "Glow"
	_halo.texture = GLOW
	_halo.z_index = -1
	_halo.material = _unshaded(true)
	add_child(_halo)
	_apply_glow()

	_sprite = Sprite2D.new()
	_sprite.name = "Cloud"
	_visual = _sprite
	add_child(_sprite)
	_apply_tone()


## An unshaded material, additive or not. Unshaded is what takes a CanvasItem
## out of CanvasModulate — see _build_visual.
func _unshaded(additive: bool) -> CanvasItemMaterial:
	var mat := CanvasItemMaterial.new()
	mat.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	if additive:
		mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	return mat


## What a painted halo has to be scaled by to land where the light it replaced
## landed, and the one number in this file that is a calibration rather than a
## choice.
##
## A Light2D adds `colour * energy * ALBEDO` — it multiplies whatever surface it
## falls on, so its pool is dimmer on a dark wall than on a pale one and it
## picks the brickwork out as it goes. An additive sprite adds `colour * energy`
## flat, with no surface in the term at all, so at the same energy it lands
## roughly 1/albedo too bright: the first pass came back a saturated red disc
## with the cloud's own rim lost inside it. 0.35 is the office brick's albedo,
## which is the surface this pool is nearly always on.
##
## Keeping it as a separate constant rather than folding it into the default
## `light_energy` means the exported number still reads on LIGHTING.md's scale,
## where the room fixtures run 1.3-2.1 and this deliberately sits under them.
const PAINT_GAIN := 0.35

## Size, colour and brightness of the halo, and whether it is there at all.
##
## The brightness goes into the RGB rather than into alpha: the blend is
## additive, so scaling the colour is what scales the light it appears to throw,
## and an alpha above 1 is not a thing a Color carries into a modulate.
func _apply_glow() -> void:
	if _halo == null:
		return
	_halo.visible = glow
	_halo.scale = Vector2.ONE * light_scale
	var gain := light_energy * PAINT_GAIN
	_halo.modulate = Color(light_color.r * gain, light_color.g * gain,
		light_color.b * gain, 1.0)


## Point the sprite at this tone's sheet, and shade it or don't.
##
## Guarded on the sprite existing because `tone` is an @export: the scene sets it
## on load, which is before _build_visual has run. `_build_visual` calls this
## again on the way out, so the order the two happen in does not matter.
func _apply_tone() -> void:
	if _sprite == null:
		return
	_sprite.texture = _frame(0)
	# Unshaded either way — see `tone`. The sheet is the finished picture in both
	# tones now, which is also what makes the two comparable: neither one's
	# appearance depends on what the room it was dropped into happens to be
	# carrying for light.
	if _sprite.material == null:
		_sprite.material = _unshaded(false)


## The kill box, inside the art. Hazard's own version writes to a ColorRect and
## quietly does nothing for a Sprite2D, so the shape is set here and the sprite
## is left centred on the prop's origin, where its own frame already centres it.
func _update_extents() -> void:
	if _shape == null:
		return
	_shape.shape.size = (size - Vector2(KILL_MARGIN, KILL_MARGIN)).max(Vector2.ONE)
	_shape.position = Vector2.ZERO


func _process(delta: float) -> void:
	_clock += delta
	# Recomputed from _clock every frame, never integrated. A velocity added up
	# frame to frame accumulates error, and a hazard that has wandered off its
	# path by the twentieth attempt at a room is one the room cannot be built
	# around — the whole point of a repeating path is that it repeats.
	position = _origin + _offset(_clock)
	if _sprite != null:
		_sprite.texture = _frame(int(_clock / FRAME_TIME) % FRAMES)


## Where the cloud is, `t` seconds in.
##
## THE PLACED POINT IS THE CENTRE OF THE PATH in all three modes — a vertical
## thought swings `amplitude` above and below it, and a circling one orbits it.
## The alternative (start ON the placed point and circle away from it) makes the
## same number mean two different things depending on the mode, and leaves the
## LDtk icon sitting somewhere the cloud only passes through.
func _offset(t: float) -> Vector2:
	var theta := TAU * (t * speed + phase)
	match motion:
		Motion.HORIZONTAL:
			return Vector2(sin(theta) * amplitude, 0.0)
		Motion.CIRCLE:
			# +Y is down, so an increasing angle sweeps right, then DOWN — which
			# on screen is clockwise. Anticlockwise is that mirrored in y.
			var y := sin(theta) if clockwise else -sin(theta)
			return Vector2(cos(theta), y) * amplitude
		Motion.LINEAR:
			var rad := deg_to_rad(angle)
			return Vector2(cos(rad), sin(rad)) * sin(theta) * amplitude
		_:
			return Vector2(0.0, sin(theta) * amplitude)


func _frame(i: int) -> AtlasTexture:
	var tex := AtlasTexture.new()
	tex.atlas = SHEETS[tone]
	tex.region = Rect2(Vector2(i * FRAME.x, 0.0), FRAME)
	return tex


## Put it back at the start of its cycle, where it was placed.
##
## Because a cycle that kept running across a death means every retry of a room
## presents a different pattern — the same "harder every time you fail it"
## problem CrumblingPlatform.reset() exists to prevent, and worse here, because
## a crumbled floor is at least visibly missing while a thought half a lap out of
## step just looks like bad luck.
func reset() -> void:
	_clock = 0.0
	position = _origin
	if _sprite != null:
		_sprite.texture = _frame(0)


## Reset every dark thought in the tree.
##
## A static helper on the class rather than a loop written out at each call site,
## for the reason CrumblingPlatform.reset_all gives: LdtkWorld calls it from two
## places (a respawn and a room entry), and a group name copied into two files is
## a group name that gets renamed in one of them.
static func reset_all(tree: SceneTree) -> void:
	for node in tree.get_nodes_in_group("dark_thought"):
		if node is DarkThought:
			(node as DarkThought).reset()
