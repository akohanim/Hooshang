@tool
class_name SunShaft
extends Node2D
## Shafts of light falling from a window, with dust turning over in them.
##
## The third kind of light source in Act I, after LampFixture and MonitorGlow,
## and the only one you are meant to look AT rather than by. It exists for room
## 22: twenty rooms of an office at night end with the sun coming up, and the
## thing that says "sunrise" is not a brighter floor — it is being able to see
## the light itself hanging in the air.
##
## THE BEAMS ARE LIGHTS, not painted shapes. `CanvasModulate` is 0.05 across the
## Act and multiplies every CanvasItem, so a translucent polygon over the room
## would come out at a twentieth of what you drew. A PointLight2D with a beam
## texture is exempt from that for the same reason every lamp is, and it lights
## whatever it lands on into the bargain. See tools/gen_light_shaft.py.
##
## THE MOTES ARE NOT. They are an ordinary particle sprite, lit by the beams like
## any other sprite in the room — which is exactly what is wanted, because it
## means a mote is bright inside a beam and invisible between them, with nothing
## masking or clipping them. The emitter is therefore one plain box across the
## whole fan; the light does the shaping, and the motes that fall in the gaps
## simply are not there.
##
## MORE THAN ONE BEAM, because a window has mullions. A single shaft reads as a
## spotlight through a hole; the thing that reads as SUNLIGHT THROUGH A WINDOW is
## a set of parallel bars with dark between them, which is the shadow of the
## frame you can see beside them.
##
## Joins the "lights" group like the other two, so a future light-sweep finds it.

## Colour of the beams. Warm dawn by default — the first warm natural light in
## an Act lit entirely by fluorescent tubes and moonlight.
@export var beam_color := Color(1.0, 0.78, 0.5):
	set(v): beam_color = v; _apply()
## Brightness. This is doing two jobs — being visible as air, and lighting what
## it lands on — so it runs hotter than a room fixture.
@export var beam_energy := 1.9:
	set(v): beam_energy = v; _apply()
## Length and width of the beams together (PointLight2D.texture_scale). The
## texture's beam is 128px long, so a beam reaches `128 x beam_scale` px.
@export var beam_scale := 1.0:
	set(v): beam_scale = v; _apply()
## Which way they point, in degrees, measured from straight down and turning the
## way the sprite does — 0 falls vertically, positive tips them to the left.
##
## Set here rather than by rotating the node, so the node's own transform stays
## "where the window is" and can be read off the room without mental arithmetic.
@export_range(-180.0, 180.0) var angle_degrees := 0.0:
	set(v): angle_degrees = v; _apply()

@export_group("The fan")
## How many parallel beams, 1 to MAX_BEAMS. Match it to the window: the panes
## either side of a mullion make two.
@export_range(1, 3) var beam_count := 2:
	set(v): beam_count = v; _apply()
## Gap between them, in px, measured ACROSS the beams. Roughly the width of a
## pane — too tight and the fan merges back into one shaft.
@export var beam_spacing := 26.0:
	set(v): beam_spacing = v; _apply()
## How much dimmer each beam is than the one before it, working outward from the
## first. Beams of identical brightness read as a stencil rather than as light
## coming through a window at an angle.
@export_range(0.0, 1.0) var beam_falloff := 0.22:
	set(v): beam_falloff = v; _apply()

@export_group("Dust")
## Motes drifting in the beams. Only the ones that happen to be inside a beam
## are visible, so this is a count for the fan, not for the room.
@export var mote_count := 44:
	set(v): mote_count = v; _apply()
## How long a mote drifts before it is replaced, in seconds. Slow: dust in still
## air barely moves, and anything quick enough to track reads as rain.
@export var mote_lifetime := 7.0:
	set(v): mote_lifetime = v; _apply()
## How fast they drift, in px/sec. The beams' direction sets which way.
@export var mote_drift := 5.0:
	set(v): mote_drift = v; _apply()
## Sideways wander across the beams, in px/sec — the reason they never fall in
## formation.
@export var mote_wander := 3.5:
	set(v): mote_wander = v; _apply()

## How many PointLight2D children the scene carries. They are authored in the
## .tscn rather than made here so they stay visible in the editor's Scene dock —
## nodes a @tool script adds at runtime never appear there (see LIGHTING.md).
const MAX_BEAMS := 3
## The beam texture's own length, in px, before `beam_scale`.
const BEAM_LENGTH := 128.0

@onready var motes: CPUParticles2D = $Motes


func _ready() -> void:
	add_to_group("lights")
	_apply()


## Push the exports onto the children. Safe before _ready — guards on the node
## not being in the tree yet, the same way LampFixture does.
func _apply() -> void:
	if not is_inside_tree():
		return
	var beams := _beams()
	if beams.is_empty():
		return

	var axis := Vector2(-sin(deg_to_rad(angle_degrees)), cos(deg_to_rad(angle_degrees)))
	var across := Vector2(axis.y, -axis.x)
	var count := clampi(beam_count, 1, MAX_BEAMS)
	for i in beams.size():
		var beam := beams[i]
		beam.visible = i < count
		if not beam.visible:
			continue
		beam.color = beam_color
		beam.energy = beam_energy * pow(1.0 - beam_falloff, float(i))
		beam.texture_scale = beam_scale
		beam.rotation_degrees = angle_degrees
		# Spread about the node so the node's position stays "the window",
		# whatever the count is.
		beam.position = across * ((float(i) - (count - 1) * 0.5) * beam_spacing)

	var length := BEAM_LENGTH * beam_scale
	# Cover the fan, starting a little past the apex — motes right at the window
	# would spawn inside the wall the light comes through.
	motes.rotation_degrees = angle_degrees
	motes.position = axis * (length * 0.5)
	motes.amount = maxi(mote_count, 1)
	motes.lifetime = maxf(mote_lifetime, 0.1)
	motes.emission_rect_extents = Vector2(
		11.0 * beam_scale + (count - 1) * beam_spacing * 0.5,
		length * 0.42)
	motes.gravity = Vector2.ZERO
	motes.initial_velocity_min = mote_drift * 0.4
	motes.initial_velocity_max = mote_drift
	# Spread wide about the beams' axis: a mote in still air is not falling so
	# much as being pushed around, and half of them should drift back up.
	motes.spread = 55.0
	motes.linear_accel_min = -mote_wander
	motes.linear_accel_max = mote_wander
	motes.preprocess = motes.lifetime   # already drifting when the room loads


func _beams() -> Array[PointLight2D]:
	var out: Array[PointLight2D] = []
	for i in MAX_BEAMS:
		var beam := get_node_or_null("Beam%d" % (i + 1)) as PointLight2D
		if beam != null:
			out.append(beam)
	return out
