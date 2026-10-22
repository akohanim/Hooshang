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

// The way home's earth (scenes/props/sea/land_backdrop.gd): darker the deeper
// it lies below the surface, in dithered steps, so the ground has body rather
// than reading as one flat cut-out. `ground` is the backdrop's ground line (one
// pixel per column, its row in red and green; row 0 as it is, row 1 smoothed)
// and `ground_origin` the world position of that texture's column 0, row 0.
// Depth is measured from the LOWER of the two lines, so a raised block shades
// like the ground beside it instead of as a darker pillar. 0 (every sea room)
// changes nothing.
uniform sampler2D ground : filter_nearest;
uniform vec2 ground_origin = vec2(0.0);
uniform float earth_depth = 0.0;
uniform float earth_span = 56.0;

const float BAYER[16] = {0.0, 8.0, 2.0, 10.0, 12.0, 4.0, 14.0, 6.0, 3.0, 11.0, 1.0, 9.0, 15.0, 7.0, 13.0, 5.0};

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
	vec3 rgb = mix(base, line, lum);
	if (earth_depth > 0.0) {
		int col = clamp(int(px.x - ground_origin.x), 0, textureSize(ground, 0).x - 1);
		vec4 g = texelFetch(ground, ivec2(col, 0), 0);
		vec4 smooth_g = texelFetch(ground, ivec2(col, 1), 0);
		float top = ground_origin.y + max(round(g.r * 255.0) + round(g.g * 255.0) * 256.0,
			round(smooth_g.r * 255.0) + round(smooth_g.g * 255.0) * 256.0);
		float k = clamp((px.y - top - 6.0) / earth_span, 0.0, 1.0);
		int b = int(mod(px.x, 4.0)) + int(mod(px.y, 4.0)) * 4;
		rgb *= 1.0 - earth_depth * floor(k * 3.0 + (BAYER[b] + 0.5) / 16.0) / 3.0;
	}
	COLOR = vec4(rgb, c.a * COLOR.a);
}
