shader_type canvas_item;
// The way home's grass (scenes/props/sea/land_backdrop.gd): every blade bends
// with the wind from its own base, by whole pixels, so gusts run across a field
// as a wave. `ground` is one row of pixels, one per column of this layer, holding
// the layer row the ground is at (16 bits in red and green), painted alongside
// the grass by tools/gen_act3_land_backdrops.py.
#include "res://assets/shaders/act3_land_wind.gdshaderinc"

uniform sampler2D ground : filter_nearest;
// Pixels a blade's tip leans at the height of a gust.
uniform float sway = 1.0;
// Rows above the ground at which a blade leans fully.
uniform float blade = 7.0;
uniform float speed = 1.3;

varying vec2 world;
varying vec4 tint;

void vertex() {
	world = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
	tint = COLOR;
}

void fragment() {
	vec2 size = 1.0 / TEXTURE_PIXEL_SIZE;
	vec2 px = floor(UV * size);
	vec4 g = texelFetch(ground, ivec2(int(px.x), 0), 0);
	float row = round(g.r * 255.0) + round(g.g * 255.0) * 256.0;
	float k = clamp((row - px.y) / blade, 0.0, 1.0);
	float dx = round(sway * k * land_wind(floor(world.x), TIME * speed, 0.0));
	vec2 uv = (vec2(px.x - dx, px.y) + 0.5) * TEXTURE_PIXEL_SIZE;
	COLOR = (uv.x < 0.0 || uv.x > 1.0) ? vec4(0.0) : texture(TEXTURE, uv) * tint;
}
