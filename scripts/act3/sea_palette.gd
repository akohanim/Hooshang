class_name SeaPalette
extends RefCounted
## Act III's colour, as a function of WORLD DEPTH (absolute y in px).
##
## "The ocean brightens with depth" is the whole act's look (docs/act3/
## ACT3_DESIGN.md), so the colour is not per room but per pixel row of the
## world: the backdrop, the terrain's two tones, the water and the props all read
## the same ramps, keyed by the same y. That is what keeps a room seam invisible
## and lets the colour keep changing through a slide between two rooms.
##
## The surface is the September art direction exactly — pure black fill, pure
## white line (assets/act3/README.md). From there the fill climbs in luminance
## all the way down, and at the floor the two tones INVERT (pale gold fill, deep
## amber line), because a white line on a near-white sea reads as nothing.
##
## Shaders sample these as GradientTexture1D (see ramp_texture()), spread over
## [TOP_Y, BOTTOM_Y]; GDScript reads the same Gradients with at().

## World y of the first and last stop. Rooms below BOTTOM_Y clamp to the floor.
const TOP_Y := 0.0
const BOTTOM_Y := 2304.0

## Stops: [world y, colour]. Bands follow the chapter layout in
## tools/build_act3_world.py (Ch I surface 0-384, II 384-768, III 768-1152,
## IV 1152-1344, V 1344-2304).
const FILL := [
	[0.0, Color(0.0, 0.0, 0.0)],
	[230.0, Color(0.0, 0.0, 0.0)],
	[400.0, Color(0.035, 0.05, 0.16)],      # indigo: the first colour
	[740.0, Color(0.04, 0.09, 0.22)],
	[860.0, Color(0.05, 0.19, 0.2)],        # the wreck: teal-green
	[1120.0, Color(0.07, 0.22, 0.2)],
	[1230.0, Color(0.16, 0.12, 0.3)],       # reef: violet
	[1360.0, Color(0.22, 0.17, 0.36)],
	[1700.0, Color(0.52, 0.36, 0.3)],       # trench: warming
	[2050.0, Color(0.86, 0.7, 0.42)],       # floor: gold
	[2304.0, Color(0.95, 0.86, 0.62)],
]
const LINE := [
	[0.0, Color(1.0, 1.0, 1.0)],
	[230.0, Color(1.0, 1.0, 1.0)],
	[400.0, Color(0.62, 0.86, 1.0)],        # pale cyan
	[740.0, Color(0.52, 0.92, 0.96)],
	[860.0, Color(1.0, 0.78, 0.42)],        # sodium amber: his office lights
	[1120.0, Color(1.0, 0.72, 0.4)],
	[1230.0, Color(1.0, 0.56, 0.62)],       # coral / rose
	[1360.0, Color(1.0, 0.66, 0.58)],
	[1700.0, Color(1.0, 0.92, 0.66)],
	[2050.0, Color(0.5, 0.3, 0.12)],        # inverted: deep amber line on gold
	[2304.0, Color(0.44, 0.27, 0.1)],
]
## The water itself (the room backdrop): top of the room's column, then the
## colour it fades to toward the bottom. Two ramps so a single room can grade.
const SKY := [
	[0.0, Color(0.0, 0.0, 0.0)],
	[230.0, Color(0.02, 0.02, 0.02)],
	[400.0, Color(0.06, 0.1, 0.26)],
	[740.0, Color(0.05, 0.14, 0.32)],
	[860.0, Color(0.07, 0.25, 0.27)],
	[1120.0, Color(0.09, 0.3, 0.3)],
	[1230.0, Color(0.15, 0.3, 0.42)],
	[1360.0, Color(0.3, 0.36, 0.52)],
	[1700.0, Color(0.74, 0.6, 0.5)],
	[2050.0, Color(1.0, 0.93, 0.74)],
	[2304.0, Color(1.0, 0.98, 0.9)],
]
## Highlights: water surface lines, caustics, motes, current streaks.
const GLINT := [
	[0.0, Color(1.0, 1.0, 1.0)],
	[400.0, Color(0.6, 0.85, 1.0)],
	[860.0, Color(0.7, 1.0, 0.86)],
	[1230.0, Color(0.85, 0.75, 1.0)],
	[1700.0, Color(1.0, 0.95, 0.8)],
	[2304.0, Color(1.0, 1.0, 1.0)],
]
## How much colour the props keep (0 = forced to the surface's black and
## white). The ink shore's lemons and thoughts are line art like everything
## else there; colour arrives with the water.
const CHROMA := [
	[0.0, Color(0.0, 0.0, 0.0)],
	[230.0, Color(0.0, 0.0, 0.0)],
	[420.0, Color(1.0, 1.0, 1.0)],
	[2304.0, Color(1.0, 1.0, 1.0)],
]

static var _cache := {}


static func gradient(stops: Array) -> Gradient:
	var key := stops.hash()
	if _cache.has(key):
		return _cache[key]
	var g := Gradient.new()
	var offsets := PackedFloat32Array()
	var colors := PackedColorArray()
	for stop: Array in stops:
		offsets.append(clampf((float(stop[0]) - TOP_Y) / (BOTTOM_Y - TOP_Y), 0.0, 1.0))
		colors.append(stop[1])
	g.offsets = offsets
	g.colors = colors
	_cache[key] = g
	return g


## The same stops as a texture a shader can sample with (world_y - TOP_Y) /
## (BOTTOM_Y - TOP_Y). 512 texels over 2304px is a texel every 4.5px — the
## shader samples it LINEAR, so the grade is smooth.
static func ramp_texture(stops: Array) -> GradientTexture1D:
	var key := "tex" + str(stops.hash())
	if _cache.has(key):
		return _cache[key]
	var tex := GradientTexture1D.new()
	tex.gradient = gradient(stops)
	tex.width = 512
	_cache[key] = tex
	return tex


static func at(stops: Array, world_y: float) -> Color:
	return gradient(stops).sample(clampf((world_y - TOP_Y) / (BOTTOM_Y - TOP_Y), 0.0, 1.0))


## Feed every ramp a shader might use, under one naming convention.
static func bind(material: ShaderMaterial) -> void:
	material.set_shader_parameter("ramp_fill", ramp_texture(FILL))
	material.set_shader_parameter("ramp_line", ramp_texture(LINE))
	material.set_shader_parameter("ramp_sky", ramp_texture(SKY))
	material.set_shader_parameter("ramp_glint", ramp_texture(GLINT))
	material.set_shader_parameter("ramp_chroma", ramp_texture(CHROMA))
	material.set_shader_parameter("depth_top", TOP_Y)
	material.set_shader_parameter("depth_bottom", BOTTOM_Y)
