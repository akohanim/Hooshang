shader_type canvas_item;
// Act III terrain recolour (scenes/props/sea/sea_room.gd). The terrain atlas
// (assets/act3/terrain.png) is pure black and white; every texel is remapped
// to the depth ramp's FILL (black) and LINE (white) at the WORLD y it is drawn
// at, so the same tiles are line art on the shore and gold at the sea floor.
// See scripts/act3/sea_palette.gd for the ramps.

uniform sampler2D ramp_fill : filter_linear, repeat_disable;
uniform sampler2D ramp_line : filter_linear, repeat_disable;
uniform sampler2D ramp_chroma : filter_linear, repeat_disable;
uniform float depth_top = 0.0;
uniform float depth_bottom = 2304.0;
// >= 0 pins the whole layer to one depth (the epilogue rooms).
uniform float fixed_depth = -1.0;
// Interior texture once colour arrives: a 2px value grain, quantised to two
// steps, so a big block of rock reads as stone rather than a flat swatch.
uniform float grain = 0.09;
// >= 0 overrides the ramps with fixed colours (the real sea's sand).
uniform vec3 fixed_fill = vec3(-1.0);
uniform vec3 fixed_line = vec3(-1.0);

varying vec2 world;

void vertex() {
	world = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
}

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	vec2 px = floor(world);
	float d = fixed_depth >= 0.0 ? fixed_depth
		: clamp((px.y - depth_top) / (depth_bottom - depth_top), 0.0, 1.0);
	float lum = dot(c.rgb, vec3(0.299, 0.587, 0.114));
	vec3 fill = texture(ramp_fill, vec2(d, 0.5)).rgb;
	vec3 line = texture(ramp_line, vec2(d, 0.5)).rgb;
	float chroma = texture(ramp_chroma, vec2(d, 0.5)).r;
	if (fixed_fill.r >= 0.0) {
		fill = fixed_fill;
		line = fixed_line;
		chroma = 1.0;
	}
	// Two-pixel cells, two levels: stays pixel art, never a smooth noise.
	float n = hash(floor(px / 2.0));
	float g = (n > 0.62 ? 1.0 : (n < 0.2 ? -0.6 : 0.0)) * grain * chroma;
	vec3 base = fill * (1.0 + g);
	COLOR = vec4(mix(base, line, lum), c.a * COLOR.a);
}
