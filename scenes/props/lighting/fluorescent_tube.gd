@tool
class_name FluorescentTube
extends LampFixture
## A suspended office fluorescent: the drawn fixture, plus the tube as a light.
##
## EXTENDS LampFixture rather than copying it, the same way GlassSpikes extends
## Hazard — colour, energy, pool size, the group and the flicker all come from
## there and cannot drift. What this adds is a body you can look at: a housing
## sprite, two drop rods, and the tube itself.
##
## THE TUBE IS A LIGHT, NOT A SPRITE, and that is the whole reason this is not
## just LampFixture with a picture on it. `CanvasModulate` is 0.05 in Act I —
## it multiplies every CanvasItem — so a painted glowing tube comes out at 5% of
## what was drawn, which is to say black. Same trap SunShaft and WallPattern
## document. The tube is therefore a PointLight2D wearing `fluorescent_lit.png`
## as its texture: the shape is the art, the brightness is light, and nothing
## multiplies it away. The housing sprite underneath is ordinary paint, lit by
## its own tube — which is exactly how you would see it in a dark office.
##
## Because the tube is a light, the flicker reaches it for free: `_process`
## keeps it in step with the pool, so a stuttering fixture stutters where you
## are looking as well as on the floor. A fluorescent whose pool flickers while
## its tube burns steadily reads as a bug in the game rather than a fault in the
## building.
##
## `light_energy = 0` gives a DEAD fixture — housing, no tube, no pool — which is
## a thing this room uses on purpose. It still needs another light nearby or it
## is invisible, and that is the point of hanging one in the moonlight.

## How hard the tube itself reads, separate from the pool it throws. They are
## two different jobs: the pool is how far the light carries, this is how bright
## the thing looks. Turning the pool down without this leaves a dim room lit by
## a fixture that still looks brand new.
@export var tube_energy := 1.5:
	set(v): tube_energy = v; _apply()
## Distance out from the centre to each drop rod, in px. The housing is 40 wide,
## so 13 puts them where a real fixture carries its chains — inboard of the end
## caps rather than on them.
@export var stem_gap := 13.0:
	set(v): stem_gap = v; _apply()

@onready var housing: Sprite2D = $Housing
@onready var tube: PointLight2D = $Tube
@onready var stem_l: ColorRect = $StemL
@onready var stem_r: ColorRect = $StemR

## Half the housing art's height — where the rods meet the fixture.
const BODY_HALF := 5.0


func _ready() -> void:
	super()


func _apply() -> void:
	super()
	if housing == null:
		return
	# The inherited cable and bulb are the greybox lamp's body; this one has its
	# own. Hidden rather than removed so the parent can keep driving them.
	cable.visible = false
	bulb.visible = false
	housing.visible = show_body
	tube.energy = tube_energy
	for i in 2:
		var rod: ColorRect = stem_l if i == 0 else stem_r
		rod.visible = show_body and cable_length > BODY_HALF
		rod.position = Vector2((-stem_gap if i == 0 else stem_gap) - 1.0,
			-cable_length)
		rod.size = Vector2(2.0, maxf(cable_length - BODY_HALF, 0.0))


func _process(delta: float) -> void:
	super(delta)
	if Engine.is_editor_hint() or tube == null or glow == null:
		return
	# Keep the tube in step with the pool. Read back off the pool rather than
	# recomputing the flicker, so there is one waveform and they cannot drift.
	tube.energy = tube_energy * (glow.energy / maxf(light_energy, 0.0001))
