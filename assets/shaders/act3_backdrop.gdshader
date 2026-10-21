shader_type canvas_item;
// Act III room backdrop: the sea itself, behind everything in a room. Built per
// room by scenes/props/sea/sea_room.gd. Colour is the depth ramp at each
// pixel's WORLD y (scripts/act3/sea_palette.gd), so two rooms meet seamlessly.
//
// On the shore (no chroma yet) it is the September look: black, a field of
// white wave-dashes below the horizon, a few stars above it. Underwater, light
// shafts fall from the surface — ordered-dithered, so they stay pixel art —
// and marine snow drifts through them. In the trench the shafts turn round and
// rise from BELOW: the light is at the bottom of this sea.

uniform sampler2D ramp_sky : filter_linear, repeat_disable;
uniform sampler2D ramp_glint : filter_linear, repeat_disable;
uniform sampler2D ramp_chroma : filter_linear, repeat_disable;
uniform float depth_top = 0.0;
uniform float depth_bottom = 2304.0;
uniform float fixed_depth = -1.0;
// World y of the shore's horizon; < 0 for rooms with none.
uniform float horizon_y = -1.0;
// Room rect in world px, for the vignette.
uniform vec4 room_rect = vec4(0.0, 0.0, 320.0, 192.0);
uniform float rays = 1.0;
uniform float snow = 1.0;
// The epilogue: 1 = the real sea at sunrise, every colour (Act3_Level_25);
// `dawn` warms the black office from its window side (Act3_Level_24).
uniform float sunrise = 0.0;
uniform vec2 sun = vec2(232.0, 70.0);
uniform float dawn = 0.0;

varying vec2 world;

void vertex() {
	world = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
}

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float bayer4(vec2 p) {
	int x = int(mod(p.x, 4.0));
	int y = int(mod(p.y, 4.0));
	int i = x + y * 4;
	int m[16] = int[](0, 8, 2, 10, 12, 4, 14, 6, 3, 11, 1, 9, 15, 7, 13, 5);
	return (float(m[i]) + 0.5) / 16.0;
}

// The surface's sea of lines: short horizontal dashes on a perspective field,
// denser and longer toward the bottom, each shimmering on its own clock.
float wave_lines(vec2 px, float horizon) {
	float below = px.y - horizon;
	if (below < 2.0) {
		return 0.0;
	}
	float row_h = clamp(2.0 + below * 0.09, 2.0, 9.0);
	float row = floor(below / row_h);
	if (mod(below, row_h) >= 1.0) {
		return 0.0;
	}
	float seg_w = 6.0 + below * 0.35;
	float shift = TIME * (4.0 + hash(vec2(row, 3.0)) * 6.0) * (mod(row, 2.0) < 1.0 ? 1.0 : -1.0);
	float seg = floor((px.x + shift + row * 17.0) / seg_w);
	float on = step(0.62 - clamp(below / 400.0, 0.0, 0.25), hash(vec2(seg, row)));
	float twinkle = 0.55 + 0.45 * sin(TIME * 1.3 + hash(vec2(seg, row + 9.0)) * 6.28);
	return on * twinkle;
}

vec3 sunrise_sky(vec2 px, float horizon) {
	vec2 local = px - room_rect.xy;
	float above = clamp((horizon - px.y) / max(horizon - room_rect.y, 1.0), 0.0, 1.0);
	vec3 high = vec3(0.16, 0.2, 0.44);
	vec3 low = vec3(1.0, 0.6, 0.34);
	vec3 col = mix(low, high, pow(above, 0.7));
	float to_sun = distance(local, sun);
	col = mix(col, vec3(1.0, 0.86, 0.55), (1.0 - smoothstep(10.0, 60.0, to_sun)) * 0.55);
	if (to_sun < 9.0) {
		col = vec3(1.0, 0.95, 0.78);
	}
	if (px.y >= horizon) {
		float below = (px.y - horizon) / 96.0;
		col = mix(vec3(0.95, 0.58, 0.4), vec3(0.08, 0.26, 0.46), clamp(below * 1.6, 0.0, 1.0));
		// The sun's road on the water: broken horizontal glints under it.
		float road = 1.0 - smoothstep(4.0, 26.0 + below * 30.0, abs(local.x - sun.x));
		float glint = step(0.55, fract(sin(dot(floor(vec2((px.x + TIME * 6.0) / 3.0, px.y)), vec2(12.9, 78.2))) * 43758.5));
		col = mix(col, vec3(1.0, 0.9, 0.65), road * glint * 0.8);
		col = mix(col, vec3(1.0), wave_lines(px, horizon) * 0.18);
	}
	return col;
}

vec3 sea(vec2 px) {
	float d = fixed_depth >= 0.0 ? fixed_depth
		: clamp((px.y - depth_top) / (depth_bottom - depth_top), 0.0, 1.0);
	vec3 sky = texture(ramp_sky, vec2(d, 0.5)).rgb;
	vec3 glint = texture(ramp_glint, vec2(d, 0.5)).rgb;
	float chroma = texture(ramp_chroma, vec2(d, 0.5)).r;
	vec3 col = sky;

	// The distant sea fills only the band between the horizon and the shore's
	// waterline (80px); below that the room's own water takes over.
	if (horizon_y >= 0.0 && chroma < 0.5) {
		if (px.y > horizon_y && px.y < horizon_y + 80.0) {
			col = mix(col, vec3(1.0), wave_lines(px, horizon_y) * 0.85);
		} else if (hash(px) > 0.9965) {
			col = mix(col, vec3(1.0), 0.35 + 0.35 * sin(TIME * 0.7 + hash(px.yx) * 6.28));
		}
	}

	// Light shafts. Slanted bands drifting slowly; strength ordered-dithered
	// into whole pixels. Direction flips with depth: from the surface above,
	// then from the floor below.
	float up = smoothstep(0.6, 0.82, d);
	float slant = mix(0.38, -0.38, up);
	float coord = px.x + px.y * slant;
	float band = sin(coord * 0.043 + TIME * 0.21) * 0.5 + 0.5;
	band = band * 0.7 + (sin(coord * 0.117 - TIME * 0.13) * 0.5 + 0.5) * 0.3;
	// Strength is a function of WORLD depth only, never of where in the room
	// the pixel is: a room-relative falloff steps at every vertical seam.
	float shaft = smoothstep(0.64, 0.97, band) * chroma * rays * (0.18 + d * 0.22);
	col = mix(col, glint, step(bayer4(px), shaft) * 0.2 + shaft * 0.14);

	// Marine snow: one mote per 12px cell at most, drifting down and sideways.
	vec2 drift = vec2(sin(TIME * 0.31) * 6.0 + TIME * 2.0, TIME * mix(5.0, -4.0, up));
	vec2 sp = px + drift;
	vec2 cell = floor(sp / 12.0);
	vec2 at = floor(vec2(hash(cell), hash(cell + 7.1)) * 12.0);
	if (hash(cell + 3.3) > 0.72 && floor(mod(sp, 12.0)) == at) {
		col = mix(col, glint, (0.35 + 0.4 * hash(cell + 1.7)) * snow * max(chroma, 0.15));
	}

	if (dawn > 0.0) {
		float from_right = clamp((px.x - room_rect.x) / max(room_rect.z, 1.0), 0.0, 1.0);
		col = mix(col, vec3(0.07, 0.07, 0.1), dawn * 0.8);
		col += vec3(0.5, 0.27, 0.12) * pow(from_right, 3.0) * dawn * (0.6 + 0.4 * step(bayer4(px), pow(from_right, 2.0)));
	}
	return col;
}

void fragment() {
	vec2 px = floor(world);
	COLOR = vec4(sunrise_sky(px, horizon_y), 1.0);
	if (sunrise < 0.5) {
		COLOR = vec4(sea(px), 1.0);
	}
}
