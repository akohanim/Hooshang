@tool
class_name WallPattern
extends PointLight2D
## A Persian rosette that surfaces out of the office wall, drifts through a
## colour, and sinks back.
##
## IT IS A LIGHT, and it has to be. `CanvasModulate` is 0.05 across Act I and
## multiplies every CanvasItem, so a pattern painted onto the backdrop would come
## out at a twentieth of what was drawn -- the same reason SunShaft's beams are
## PointLight2Ds and not polygons (LIGHTING.md). The cookie is white with the
## ornament in its alpha (tools/gen_persian_glyph.py), so the colour is the
## light's own and one texture covers the whole palette.
##
## IT ONLY TOUCHES THE WALL. `range_item_cull_mask` is BACKDROP_MASK, which the
## room backdrop is the only thing carrying (LdtkWorld._add_backdrop), so the
## pattern cannot wash over the player, the brickwork or the props in front of
## it. Without that it reads as a coloured spotlight in the room rather than as
## something IN the wall, and it lights Hooshang magenta as he walks past.
##
## MINIMAL BY CONSTRUCTION, because it is scenery for a game about an office at
## night and not a lava lamp: it is dark for `rest_time` out of every cycle, so
## the wall is plain most of the time and the pattern is a thing you catch rather
## than a thing you watch. Turn it up by shortening rest_time before touching
## peak_energy -- energy is what makes it stop reading as a wall.
##
## Instance under `Backdrop` in ldtk/Act1World.tscn and give each one a
## different `phase` so no two rooms breathe together.

## The cull-mask bit the room backdrop carries in addition to the default, so a
## light can be aimed at the wall alone. Kept here rather than in LdtkWorld
## because this is the only thing that uses it as a FILTER; the backdrop just
## has to be a member.
const BACKDROP_MASK := 2

@export_group("Look")
## The palette it moves through, one hue per appearance, drifting toward the next
## while it is up. Two or more; a single colour still works and just stops
## drifting.
@export var hues: Array[Color] = [
	Color(0.78, 0.30, 0.95),   # violet
	Color(0.25, 0.85, 0.78),   # teal
	Color(0.95, 0.55, 0.20),   # saffron
	Color(0.35, 0.45, 0.98),   # lapis
]:
	set(v): hues = v; _apply()
## Brightness at the top of a cycle. Low on purpose -- see the note above.
@export var peak_energy := 0.62:
	set(v): peak_energy = v; _apply()
## Size of the rosette (PointLight2D.texture_scale). The cookie is 128px, so the
## pattern spans `128 * pattern_scale` pixels.
@export var pattern_scale := 1.1:
	set(v): pattern_scale = v; _apply()
## Degrees per second the whole figure turns. Slow: at eightfold symmetry it
## returns to itself every 45 degrees, so even a crawl reads as motion.
@export var spin_speed := 2.5

@export_group("Breathing")
## Seconds to rise from nothing to full.
@export var bloom_time := 3.4
## ...to sit at full...
@export var hold_time := 1.8
## ...and to sink back.
@export var fade_time := 4.0
## How long the wall stays plain before the next one. The knob that decides how
## often this is on screen at all.
@export var rest_time := 6.5
## Seconds to start this instance into its own cycle, so two patterns in
## neighbouring rooms are never in step. Set it per instance.
@export var phase := 0.0

var _t := 0.0


func _ready() -> void:
	add_to_group("lights")
	_t = phase
	_apply()
	if not Engine.is_editor_hint():
		energy = 0.0


func _apply() -> void:
	range_item_cull_mask = BACKDROP_MASK
	texture_scale = pattern_scale
	if not hues.is_empty():
		color = hues[0]
	if Engine.is_editor_hint():
		# Static, at full, so it can be placed against the actual wall. The
		# animation below never runs in the editor.
		energy = peak_energy


func _process(delta: float) -> void:
	if Engine.is_editor_hint() or hues.is_empty():
		return
	_t += delta
	rotation += deg_to_rad(spin_speed) * delta
	var cycle := maxf(bloom_time + hold_time + fade_time + rest_time, 0.01)
	var n := int(floorf(_t / cycle))
	var t := _t - float(n) * cycle
	energy = peak_energy * _envelope(t)
	# Drifts from this cycle's hue toward the next ACROSS the appearance, so the
	# rosette changes colour while you are looking at it rather than being a
	# different colour each time it comes back.
	var lit := maxf(bloom_time + hold_time + fade_time, 0.01)
	var k := clampf(t / lit, 0.0, 1.0)
	color = hues[n % hues.size()].lerp(hues[(n + 1) % hues.size()], k)


## 0 -> 1 -> 0 across the cycle, flat at the top, and flat at zero for the rest.
## Smoothstepped at both ends: a linear fade has a visible corner where it leaves
## and rejoins nothing, which on a slow effect is the only part you notice.
func _envelope(t: float) -> float:
	if t < bloom_time:
		return smoothstep(0.0, 1.0, t / maxf(bloom_time, 0.01))
	t -= bloom_time
	if t < hold_time:
		return 1.0
	t -= hold_time
	if t < fade_time:
		return 1.0 - smoothstep(0.0, 1.0, t / maxf(fade_time, 0.01))
	return 0.0
